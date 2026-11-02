plot_transitions <- function(transitions, colours, theme) {
  transitions |>
    dplyr::filter(is.finite(reservation_after_unreserved), is.finite(reservation_after_reserved)) |>
    ggplot2::ggplot(ggplot2::aes(reservation_after_unreserved, reservation_after_reserved, colour = level)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey70") +
    ggplot2::geom_point(alpha = 0.5, size = 1.4) +
    ggplot2::facet_grid(level ~ transition) +
    ggplot2::scale_colour_manual(values = colours, guide = "none") +
    ggplot2::scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
    ggplot2::labs(
      x = "Reservation after an unreserved cycle", y = "Reservation after a reserved cycle",
      caption = paste(
        "Raw linked-sample rates. Points below the diagonal indicate less immediate repetition;",
        "they do not establish rotation-rule compliance."
      )
    ) +
    theme
}

plot_contrasts <- function(estimates, colours, theme) {
  estimates |>
    dplyr::filter(transition != "equal_transition_average_common_units") |>
    dplyr::group_by(level, transition) |>
    dplyr::arrange(district, block_id, .by_group = TRUE) |>
    dplyr::mutate(unit_order = dplyr::row_number()) |>
    ggplot2::ggplot(ggplot2::aes(unit_order, estimate, ymin = lower, ymax = upper, colour = level)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey70") +
    ggplot2::geom_linerange(alpha = 0.4, linewidth = 0.25) +
    ggplot2::geom_point(size = 0.6) +
    ggplot2::facet_grid(level ~ transition, scales = "free_x") +
    ggplot2::scale_colour_manual(values = colours, guide = "none") +
    ggplot2::scale_y_continuous(labels = scales::label_percent()) +
    ggplot2::labs(
      x = "Administrative units in geographic order", y = "Reservation transition contrast",
      caption = "Posterior medians and 95% credible intervals. District and block contrasts are computed separately."
    ) +
    theme
}

save_figure <- function(plot, name, directory, width, height, dpi) {
  for (extension in c("pdf", "png")) {
    ggplot2::ggsave(file.path(directory, paste0(name, ".", extension)), plot, width = width, height = height, dpi = dpi)
  }
}

write_report <- function(state, transitions, benchmarks, file, has_model = FALSE) {
  summary <- benchmarks |>
    dplyr::group_by(level, transition) |>
    dplyr::summarise(
      observed_sd = dplyr::first(observed_sd), noise_sd = mean(simulated_sd),
      noise_lower = stats::quantile(simulated_sd, 0.025),
      noise_upper = stats::quantile(simulated_sd, 0.975), .groups = "drop"
    )
  lines <- c(
    paste("# Reservation patterns:", state), "",
    "Raw district and block transition rates are descriptive associations in the linked sample.",
    "The benchmark assumes common transition probabilities and preserves observed lag-group sizes.",
    "It does not enforce quotas or eligibility and is not a test of the official allocation mechanism.", "",
    paste("Bayesian model output available:", has_model), "",
    "| Level | Transition | Observed SD (pp) | Mean noise SD (pp) | 95% noise interval (pp) |",
    "|---|---|---:|---:|---:|"
  )
  for (row in seq_len(nrow(summary))) {
    value <- summary[row, ]
    lines <- c(lines, sprintf(
      "| %s | %s | %.1f | %.1f | %.1f–%.1f |", value$level, value$transition,
      100 * value$observed_sd, 100 * value$noise_sd, 100 * value$noise_lower, 100 * value$noise_upper
    ))
  }
  lines <- c(
    lines, "", paste(
      "Sampling diagnostics, simulation coverage and linkage sensitivity",
      "must be reviewed before interpreting model results."
    ),
    "Geographic variation does not identify bureaucratic discretion. Early Rajasthan linkage is especially incomplete."
  )
  writeLines(lines, file)
}

write_readme_findings <- function(benchmarks, file) {
  summary <- benchmarks |>
    dplyr::group_by(state) |>
    dplyr::filter(transition == max(transition)) |>
    dplyr::group_by(state, transition, level) |>
    dplyr::summarise(
      observed_sd = dplyr::first(observed_sd), noise_sd = mean(simulated_sd),
      noise_lower = stats::quantile(simulated_sd, 0.025),
      noise_upper = stats::quantile(simulated_sd, 0.975), .groups = "drop"
    ) |>
    dplyr::arrange(state, match(level, c("district", "block")))
  labels <- c(rajasthan = "Rajasthan", uttar_pradesh = "Uttar Pradesh")
  table <- c(
    "| State | Transition | Variation across | Observed spread | Benchmark mean | 95% simulated range |",
    "|---|---|---|---:|---:|---:|"
  )
  for (row in seq_len(nrow(summary))) {
    value <- summary[row, ]
    table <- c(table, sprintf(
      "| %s | %s | %s | %.1f | %.1f | %.1f to %.1f |",
      labels[[value$state]], gsub("-", " to ", value$transition),
      paste0(value$level, "s"), 100 * value$observed_sd, 100 * value$noise_sd,
      100 * value$noise_lower, 100 * value$noise_upper
    ))
  }
  lines <- readLines(file)
  start <- which(lines == "<!-- findings:start -->")
  end <- which(lines == "<!-- findings:end -->")
  if (length(start) != 1L || length(end) != 1L || start >= end) {
    stop("README must have one ordered pair of findings markers")
  }
  writeLines(c(lines[seq_len(start)], "", table, "", lines[seq.int(end, length(lines))]), file)
}
