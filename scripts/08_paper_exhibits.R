source("scripts/load_project.R")

paper_dir <- project_file("paper", "build")
dir.create(paper_dir, recursive = TRUE, showWarnings = FALSE)
read_table <- function(name) readr::read_csv(file.path(table_dir, name), show_col_types = FALSE)
state_labels <- c(rajasthan = "Rajasthan", uttar_pradesh = "Uttar Pradesh")
outcome_labels <- c(
  women_instrument = "Women: instrument", women_prediction = "Women: alternative",
  sc = "Scheduled Castes", st = "Scheduled Tribes"
)
benchmarks <- purrr::map_dfr(names(reservation_cycles), function(state) {
  read_table(paste0(state, "_benchmarks.csv")) |>
    dplyr::mutate(state = state)
}) |>
  dplyr::group_by(state, transition, level) |>
  dplyr::summarise(
    observed = dplyr::first(observed_sd), benchmark = mean(simulated_sd),
    lower = stats::quantile(simulated_sd, 0.025), upper = stats::quantile(simulated_sd, 0.975),
    groups = dplyr::first(groups), .groups = "drop"
  ) |>
  dplyr::arrange(state, transition, match(level, c("district", "block")))
assignment <- read_table("assignment_disagreements.csv") |>
  dplyr::arrange(match(outcome, names(outcome_labels)))
assignment_benchmarks <- read_table("assignment_residual_benchmarks.csv") |>
  dplyr::filter(statistic %in% c("equal_unit:district_sd", "equal_unit:block_sd")) |>
  dplyr::mutate(
    level = factor(ifelse(grepl("district", statistic), "District", "Block"), levels = c("District", "Block")),
    label = factor(outcome_labels[outcome], levels = unname(outcome_labels))
  )
stopifnot(all(is.finite(benchmarks$observed)), all(is.finite(assignment$mismatch_rate)))
latest <- benchmarks |>
  dplyr::group_by(state) |>
  dplyr::filter(transition == max(transition)) |>
  dplyr::ungroup()
macro_values <- c()
for (state in names(state_labels)) {
  for (level in c("district", "block")) {
    row <- dplyr::filter(latest, .data$state == .env$state, .data$level == .env$level)
    prefix <- paste0(if (state == "rajasthan") "Raj" else "Up", stringr::str_to_title(level))
    macro_values[paste0(prefix, "Observed")] <- sprintf("%.1f", 100 * row$observed)
    macro_values[paste0(prefix, "Benchmark")] <- sprintf("%.1f", 100 * row$benchmark)
  }
}
for (outcome in c("women_instrument", "sc", "st")) {
  row <- dplyr::filter(assignment, .data$outcome == .env$outcome)
  macro_name <- c(women_instrument = "WomenMismatchRate", sc = "ScMismatchRate", st = "StMismatchRate")[[outcome]]
  macro_values[macro_name] <- sprintf("%.2f", 100 * row$mismatch_rate)
}
stopifnot(dplyr::n_distinct(assignment$seats) == 1L)
macro_values["AuditN"] <- format(assignment$seats[1], big.mark = ",", scientific = FALSE, trim = TRUE)
writeLines(sprintf("\\newcommand{\\%s}{%s}", names(macro_values), macro_values), file.path(paper_dir, "numbers.tex"))

transition_table <- benchmarks |>
  dplyr::transmute(
    State = state_labels[state], Cycle = transition, Level = stringr::str_to_title(level),
    Units = groups, Observed = 100 * observed, Benchmark = 100 * benchmark,
    Range = sprintf("%.1f--%.1f", 100 * lower, 100 * upper)
  )
rendered_table <- knitr::kable(transition_table,
  format = "latex", booktabs = TRUE, digits = 1, row.names = FALSE,
  col.names = c("State", "Transition", "Level", "Units", "SD (pp)", "Ref. mean", "Ref. 95\\% range"),
  escape = FALSE
)
writeLines(rendered_table, file.path(paper_dir, "transition_table.tex"))
assignment_table <- assignment |>
  dplyr::transmute(
    Assignment = outcome_labels[outcome], GPs = seats, Disagreements = mismatches,
    Rate = 100 * mismatch_rate, Either = 100 * mismatch_among_either
  )
rendered_table <- knitr::kable(assignment_table,
  format = "latex", booktabs = TRUE, digits = 2,
  row.names = FALSE, format.args = list(big.mark = ","),
  col.names = c("Assignment", "GPs", "Disagreements", "All GPs (\\%)", "Either reserved (\\%)"), escape = FALSE
)
writeLines(rendered_table, file.path(paper_dir, "assignment_table.tex"))
coverage <- read_table("caste_population_coverage.csv") |>
  dplyr::group_by(state, census_year) |>
  dplyr::summarise(
    total = sum(gps), available = sum(gps[population_status == "available"]), .groups = "drop"
  ) |>
  dplyr::transmute(
    State = state_labels[state], Census = as.character(census_year), Catalog = total,
    Available = available, Share = 100 * available / total
  )
rendered_table <- knitr::kable(coverage,
  format = "latex", booktabs = TRUE, digits = 1,
  row.names = FALSE, format.args = list(big.mark = ","),
  col.names = c("State", "Census", "Catalog GPs", "Pass checks", "Share (\\%)"), escape = FALSE
)
writeLines(rendered_table, file.path(paper_dir, "coverage_table.tex"))

paper_theme <- theme_paper() + ggplot2::theme(
  text = ggplot2::element_text(size = 10), legend.position = "bottom",
  axis.text = ggplot2::element_text(colour = "black"), panel.grid.minor = ggplot2::element_blank()
)
transition_plot <- benchmarks |>
  dplyr::mutate(
    state = state_labels[state], level = factor(stringr::str_to_title(level), levels = c("District", "Block"))
  ) |>
  ggplot2::ggplot(ggplot2::aes(x = transition, y = 100 * observed)) +
  ggplot2::geom_linerange(ggplot2::aes(ymin = 100 * lower, ymax = 100 * upper),
    linewidth = 1.3, colour = "grey65"
  ) +
  ggplot2::geom_point(ggplot2::aes(y = 100 * benchmark, colour = "Reference mean"), shape = 1, size = 2.5) +
  ggplot2::geom_point(ggplot2::aes(colour = "Observed"), size = 2.5) +
  ggplot2::scale_colour_manual(values = c(Observed = "#08519c", "Reference mean" = "black"), name = NULL) +
  ggplot2::facet_grid(level ~ state, scales = "free_x") +
  ggplot2::scale_y_continuous(limits = c(0, NA)) +
  ggplot2::labs(x = "Election transition", y = "SD of transition contrasts (pp)") +
  paper_theme +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
ggplot2::ggsave(file.path(paper_dir, "transition_spread.pdf"), transition_plot, width = 6.2, height = 4.8)
assignment_plot <- ggplot2::ggplot(assignment_benchmarks, ggplot2::aes(x = level, y = 100 * observed)) +
  ggplot2::geom_linerange(ggplot2::aes(ymin = 100 * benchmark_lower, ymax = 100 * benchmark_upper),
    linewidth = 1.3, colour = "grey65"
  ) +
  ggplot2::geom_point(ggplot2::aes(y = 100 * benchmark_mean, colour = "Reference mean"), shape = 1, size = 2.5) +
  ggplot2::geom_point(ggplot2::aes(colour = "Observed"), size = 2.5) +
  ggplot2::scale_colour_manual(values = c(Observed = "#08519c", "Reference mean" = "black"), name = NULL) +
  ggplot2::facet_wrap(~label, ncol = 2) +
  ggplot2::scale_y_continuous(limits = c(0, NA)) +
  ggplot2::labs(x = NULL, y = "SD of disagreement rates (pp)") +
  paper_theme
ggplot2::ggsave(file.path(paper_dir, "assignment_spread.pdf"), assignment_plot, width = 6.2, height = 4.8)
geography <- read_table("assignment_residual_geography.csv") |>
  dplyr::filter(outcome %in% c("women_instrument", "sc", "st")) |>
  dplyr::mutate(
    label = factor(outcome_labels[outcome], levels = unname(outcome_labels[c("women_instrument", "sc", "st")])),
    level = factor(stringr::str_to_title(level), levels = c("District", "Block"))
  )
stopifnot(all(geography$seats > 0), all(is.finite(geography$mismatch_rate)))
geography_plot <- ggplot2::ggplot(geography, ggplot2::aes(x = seats, y = 100 * mismatch_rate)) +
  ggplot2::geom_point(size = 1.2, alpha = 0.45, colour = "#08519c") +
  ggplot2::scale_x_log10(labels = scales::label_comma()) +
  ggplot2::facet_grid(level ~ label) +
  ggplot2::labs(x = "Observed GPs in administrative unit (log scale)", y = "Prediction disagreements (%)") +
  paper_theme
ggplot2::ggsave(file.path(paper_dir, "geographic_distribution.pdf"), geography_plot, width = 6.2, height = 4.8)

concentration <- readr::read_csv(file.path(table_dir, "note_audit", "assignment_concentration.csv"),
  show_col_types = FALSE
)
sc_row <- dplyr::filter(concentration, outcome == "sc")
write(c(
  paste0("\\newcommand{\\ScBalancedBlocks}{", sc_row$balanced_blocks_with_disagreement, "}"),
  paste0("\\newcommand{\\ScAffectedBlocks}{", sc_row$blocks_with_disagreement, "}")
), file.path(paper_dir, "numbers.tex"), append = TRUE)
assignment_benchmarks |>
  dplyr::transmute(
    Assignment = label, Level = level, `Observed (pp)` = 100 * observed,
    `Reference mean` = 100 * benchmark_mean,
    `Reference range` = sprintf("%.2f--%.2f", 100 * benchmark_lower, 100 * benchmark_upper)
  ) |>
  knitr::kable(format = "latex", booktabs = TRUE, row.names = FALSE, digits = 2) |>
  writeLines(file.path(paper_dir, "assignment_benchmark_table.tex"))
