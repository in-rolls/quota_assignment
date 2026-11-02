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
  table <- summary |>
    dplyr::transmute(
      level, transition,
      observed_sd = 100 * observed_sd, noise_sd = 100 * noise_sd,
      interval = sprintf("%.1f to %.1f", 100 * noise_lower, 100 * noise_upper)
    )
  lines <- c(
    paste("# Reservation patterns:", state), "",
    "Raw district and block transition rates are descriptive associations in the linked sample.",
    "The benchmark assumes common transition probabilities and preserves observed lag-group sizes.",
    "It does not enforce quotas or eligibility and is not a test of the official allocation mechanism.", "",
    paste("Bayesian model output available:", has_model), "",
    knitr::kable(table,
      format = "pipe", digits = 1, row.names = FALSE,
      col.names = c("Level", "Transition", "Observed SD (pp)", "Mean noise SD (pp)", "95% noise interval (pp)"),
      align = c("l", "l", "r", "r", "r")
    )
  )
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
  table <- summary |>
    dplyr::transmute(
      state = labels[state], transition = gsub("-", " to ", transition),
      level = paste0(level, "s"), observed_sd = 100 * observed_sd, noise_sd = 100 * noise_sd,
      interval = sprintf("%.1f to %.1f", 100 * noise_lower, 100 * noise_upper)
    ) |>
    knitr::kable(
      format = "pipe", digits = 1, row.names = FALSE,
      col.names = c(
        "State", "Transition", "Variation across", "Observed spread", "Benchmark mean", "95% simulated range"
      ),
      align = c("l", "l", "l", "r", "r", "r")
    )
  lines <- readLines(file)
  start <- which(lines == "<!-- findings:start -->")
  end <- which(lines == "<!-- findings:end -->")
  if (length(start) != 1L || length(end) != 1L || start >= end) {
    stop("README must have one ordered pair of findings markers")
  }
  writeLines(c(lines[seq_len(start)], "", table, "", lines[seq.int(end, length(lines))]), file)
}

write_caste_summary <- function(coverage, link_coverage, report_file, readme_file) {
  labels <- c(rajasthan = "Rajasthan", uttar_pradesh = "Uttar Pradesh")
  population <- coverage |>
    dplyr::filter(census_year == 2011L) |>
    dplyr::group_by(state) |>
    dplyr::summarise(total = sum(gps), available = sum(gps[population_status == "available"]), .groups = "drop")
  population_table <- population |>
    dplyr::transmute(
      state = labels[state], total, available, share = sprintf("%.1f%%", 100 * available / total)
    ) |>
    knitr::kable(
      format = "pipe", row.names = FALSE, format.args = list(big.mark = ","),
      col.names = c("State", "GPs in catalog", "Population passes checks", "Share of catalog"),
      align = c("l", "r", "r", "r")
    )
  links <- link_coverage |>
    dplyr::filter(census_year == 2011L) |>
    dplyr::group_by(state, source) |>
    dplyr::filter(year == max(year)) |>
    dplyr::summarise(
      year = dplyr::first(year), records = sum(seats),
      linked = sum(seats[link_status == "linked"]), .groups = "drop"
    )
  link_table <- links |>
    dplyr::transmute(
      state = labels[state], source,
      year = ifelse(source == "weaver", paste(year, "(unverified)"), as.character(year)),
      linked, records
    ) |>
    knitr::kable(
      format = "pipe", row.names = FALSE, format.args = list(big.mark = ","),
      col.names = c("State", "Election source", "Source year", "Linked records", "Source records"),
      align = c("l", "l", "l", "r", "r")
    )
  table <- c(
    "Census 2011 population on the 2024 GP mapping:", "", population_table, "",
    "Latest source wave linked to those population aggregates:", "", link_table
  )
  table <- c(
    table, "",
    "Name matching selects a small subset, especially in Rajasthan. Weaver's supplied LGD codes",
    "give broader UP coverage. These are linkage results, not estimates of rule compliance."
  )
  writeLines(c(
    "# Caste assignment: build results", "",
    "Unexplained geographic variation in caste assignment has not yet been estimated.",
    "The population/linkage build is complete; historical allocation inputs remain unresolved.", "", table, "",
    "Detailed SC and ST share-order tables are separate by district and block, source and Census vintage.",
    "They are unadjusted matched-sample diagnostics. Rotation can generate ordering discrepancies.",
    "Pair counts are dependent; do not interpret them as binomial sample sizes.",
    "The 2010 Weaver wave has no accepted diagnostic links: election geography is missing or GP codes are ambiguous."
  ), report_file)
  lines <- readLines(readme_file)
  start <- which(lines == "<!-- caste_findings:start -->")
  end <- which(lines == "<!-- caste_findings:end -->")
  if (length(start) != 1L || length(end) != 1L || start >= end) stop("Missing ordered caste findings markers")
  writeLines(c(lines[seq_len(start)], "", table, "", lines[seq.int(end, length(lines))]), readme_file)
}

write_assignment_findings <- function(summary, benchmarks, file) {
  labels <- c(women_instrument = "Women", sc = "SC", st = "ST")
  table <- purrr::map_dfr(names(labels), function(outcome) {
    row <- dplyr::filter(summary, .data$outcome == .env$outcome)
    district <- dplyr::filter(benchmarks, .data$outcome == .env$outcome, statistic == "equal_unit:district_sd")
    block <- dplyr::filter(benchmarks, .data$outcome == .env$outcome, statistic == "equal_unit:block_sd")
    tibble::tibble(
      assignment = labels[[outcome]],
      disagreements = sprintf(
        "%s / %s (%.2f%%)",
        format(row$mismatches, big.mark = ","), format(row$seats, big.mark = ","), 100 * row$mismatch_rate
      ),
      district = sprintf("%.2f / %.2f", 100 * district$observed, 100 * district$benchmark_mean),
      block = sprintf("%.2f / %.2f", 100 * block$observed, 100 * block$benchmark_mean)
    )
  }) |>
    knitr::kable(
      format = "pipe", row.names = FALSE,
      col.names = c(
        "Assignment", "Disagreements among all observed GPs",
        "District spread: observed / benchmark (pp)", "Block spread: observed / benchmark (pp)"
      ),
      align = c("l", "r", "r", "r")
    )
  lines <- readLines(file)
  start <- which(lines == "<!-- assignment_findings:start -->")
  end <- which(lines == "<!-- assignment_findings:end -->")
  if (length(start) != 1L || length(end) != 1L || start >= end) stop("Missing ordered assignment findings markers")
  writeLines(c(lines[seq_len(start)], "", table, "", lines[seq.int(end, length(lines))]), file)
}

write_assignment_report <- function(summary, benchmarks, file) {
  labels <- c(
    women_instrument = "Women: RD instrument", women_prediction = "Women: prediction sensitivity",
    sc = "Scheduled Castes", st = "Scheduled Tribes"
  )
  disagreement_table <- summary |>
    dplyr::transmute(
      assignment = labels[outcome], seats, mismatches,
      rate = sprintf("%.2f%%", 100 * mismatch_rate),
      rate_either = sprintf("%.2f%%", 100 * mismatch_among_either)
    ) |>
    knitr::kable(
      format = "pipe", row.names = FALSE, format.args = list(big.mark = ","),
      col.names = c(
        "Assignment", "Observed GPs", "Disagreements", "Rate among all GPs",
        "Rate among observed/predicted reserved GPs"
      ),
      align = c("l", "r", "r", "r", "r")
    )
  spread_table <- benchmarks |>
    dplyr::filter(statistic %in% c("equal_unit:district_sd", "equal_unit:block_sd")) |>
    dplyr::transmute(
      assignment = labels[outcome], geography = ifelse(grepl("district", statistic), "District", "Block"),
      observed = 100 * observed, benchmark_mean = 100 * benchmark_mean,
      interval = sprintf("%.2f to %.2f", 100 * benchmark_lower, 100 * benchmark_upper)
    ) |>
    knitr::kable(
      format = "pipe", digits = 2, row.names = FALSE,
      col.names = c("Assignment", "Geography", "Observed SD (pp)", "Benchmark SD (pp)", "95% benchmark range (pp)"),
      align = c("l", "l", "r", "r", "r")
    )
  lines <- c(
    "# UP 2015: disagreements with supplied assignment predictions", "",
    "These statistics audit the authors' supplied predictions, not an independently reconstructed legal rule.", "",
    disagreement_table, "", spread_table
  )
  lines <- c(
    lines, "",
    "The benchmark moves a fixed number of prediction disagreements among GPs within strata.",
    paste("For women, strata are observed caste category and predicted female assignment;",
      "for SC/ST they are predicted caste."
    ),
    "It describes concentration relative to exchangeable disagreements. It is not a test of lawful random allocation.",
    "Departures can reflect author prediction error, data error, exceptions or administrative decisions.",
    "The between-district share in the CSV decomposes observed block-rate variance, including finite-group noise.",
    "It is not the noise-adjusted share of underlying heterogeneity. Benchmark intervals are not confidence intervals.",
    "SC and ST are separate benchmarks, not jointly valid caste-allocation simulations.",
    "All four outcomes use observed geography and assignment; missing records remain in the coverage table.",
    paste("The separate caste build uses modern LGD/SHRUG aggregates;",
      "it is not substituted for the authors' population inputs."
    )
  )
  writeLines(lines, file)
}
