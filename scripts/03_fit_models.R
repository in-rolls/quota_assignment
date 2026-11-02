for (state in names(reservation_cycles)) {
  panel_file <- file.path(build_dir, state, "panel.rds")
  panel <- readRDS(panel_file)
  directory <- file.path(build_dir, state, model_name)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  fit <- fit_reservation_model(panel, model_settings, file.path(directory, "model"))
  model_data <- prepare_model_data(panel, model_settings$adjusted, model_settings$complete_history)
  diagnostics <- check_sampling(fit)
  readr::write_csv(diagnostics$diagnostics, model_table_file(state, "diagnostics.csv"))
  saveRDS(
    list(
      settings = model_settings, diagnostics = diagnostics,
      panel_sha256 = digest::digest(file = panel_file, algo = "sha256")
    ),
    file.path(directory, "model_settings.rds")
  )
  geographies <- purrr::map(c("district", "block"), function(level) {
    estimate_geography(fit, model_data, level, model_settings$adjusted) |>
      average_transitions(levels(model_data$transition))
  })
  saveRDS(geographies, file.path(directory, "geography_draws.rds"))
  purrr::map_dfr(geographies, "estimates") |>
    readr::write_csv(model_table_file(state, "contrasts.csv"))
  purrr::map_dfr(geographies, summarize_geography) |>
    readr::write_csv(model_table_file(state, "heterogeneity.csv"))
  prior_settings <- model_settings
  prior_settings$iter <- 400L
  prior_settings$warmup <- 200L
  prior_settings$chains <- 2L
  prior_fit <- fit_reservation_model(panel, prior_settings, file.path(directory, "prior_model"), prior_only = TRUE)
  check_predictions(prior_fit, model_data, kind = "prior") |>
    readr::write_csv(model_table_file(state, "prior_checks.csv"))
  check_predictions(fit, model_data) |>
    readr::write_csv(model_table_file(state, "predictive_checks.csv"))
}
