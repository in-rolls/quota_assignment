testthat::test_that("quota sampler preserves totals and model data retain repeated seats", {
  generated <- simulate_panel(district_count = 2, blocks_per_district = 2, fixed_quota = TRUE)
  counts <- generated$panel |>
    dplyr::group_by(transition, block_id) |>
    dplyr::summarise(reserved = sum(current_reserved), quota = round(dplyr::n() * 0.4), .groups = "drop")
  testthat::expect_equal(counts$reserved, counts$quota)
  panel <- prepare_model_data(generated$panel)
  testthat::expect_equal(dplyr::n_distinct(panel$gp_id), nrow(panel) / 3)
  stan_data <- brms::make_standata(reservation_formula(), data = panel, family = brms::bernoulli())
  testthat::expect_equal(stan_data$N, nrow(panel))
})

testthat::test_that("simulation failures remain reviewable", {
  validate <- validate_models
  environment(validate) <- list2env(
    list(fit_reservation_model = function(...) stop("deliberate failure")),
    parent = environment(validate_models)
  )
  directory <- tempfile()
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  result <- validate(directory, list(seed = 1L), replicates = 1L, district_count = 2L, blocks_per_district = 2L)
  testthat::expect_equal(nrow(result), 4L)
  testthat::expect_true(all(grepl("deliberate failure", result$error)))
})

testthat::test_that("posterior summaries assemble rows at both geographic levels", {
  testthat::local_mocked_bindings(
    posterior_epred = function(object, newdata, ...) {
      matrix(rep(0.2 + 0.4 * newdata$previous_reserved, each = 4L), nrow = 4L)
    },
    .package = "brms"
  )
  panel <- prepare_model_data(simulate_panel(district_count = 2L, blocks_per_district = 2L)$panel)
  district <- estimate_geography(list(), panel, "district")
  block <- estimate_geography(list(), panel, "block")
  testthat::expect_equal(nrow(district$estimates), 6L)
  testthat::expect_equal(nrow(block$estimates), 12L)
  testthat::expect_equal(district$estimates$estimate, rep(0.4, 6L))
  averaged <- average_transitions(block, levels(panel$transition))
  testthat::expect_equal(nrow(averaged$estimates), 16L)
  testthat::expect_equal(nrow(summarize_geography(averaged)), 32L)
})

testthat::test_that("adjustment preserves the transition slope design", {
  panel <- simulate_panel(district_count = 2L, blocks_per_district = 2L)$panel
  panel$reserved_caste[seq(1L, nrow(panel), by = 2L)] <- "SC"
  primary <- prepare_model_data(panel)
  adjusted <- prepare_model_data(panel, adjusted = TRUE)
  columns <- grep("^category_[0-9]+", names(adjusted), value = TRUE)
  primary_design <- brms::make_standata(reservation_formula(), primary, family = brms::bernoulli())$X
  adjusted_design <- brms::make_standata(reservation_formula(columns), adjusted, family = brms::bernoulli())$X
  testthat::expect_equal(as.vector(adjusted_design[, colnames(primary_design)]), as.vector(primary_design))
})
