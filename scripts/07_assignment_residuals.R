source("scripts/load_project.R")
input_root <- Sys.getenv("IN_ROLLS", dirname(project_root))
lock <- jsonlite::read_json(project_file("docs", "assignment_source_lock.json"))
path <- file.path(input_root, lock$path)
if (digest::digest(file = path, algo = "sha256") != lock$sha256) stop("Assignment source hash changed")
data <- haven::read_dta(path, col_select = c(
  eleid, district, block, districtname, blockname, caste_reserved, caste_reserved_pred,
  womenreservation, femaleinstrument, women_reserv_pred
))
records <- prepare_supplied_assignments(data)
output_dir <- file.path(build_dir, "assignment_residuals")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
arrow::write_parquet(records, file.path(output_dir, "gp_predictions.parquet"))
coverage <- records |>
  dplyr::count(outcome, status, name = "seats")
readr::write_csv(coverage, file.path(table_dir, "assignment_coverage.csv"))
geography <- residual_geography(records)
readr::write_csv(geography, file.path(table_dir, "assignment_residual_geography.csv"))
summary <- records |>
  dplyr::filter(status == "available") |>
  dplyr::group_by(outcome) |>
  dplyr::summarise(
    seats = dplyr::n(), mismatches = sum(mismatch), mismatch_rate = mean(mismatch),
    districts = dplyr::n_distinct(district), blocks = dplyr::n_distinct(block_id),
    observed_reserved = sum(actual), predicted_reserved = sum(expected),
    false_positive = sum(expected == 1 & actual == 0), false_negative = sum(expected == 0 & actual == 1),
    either_reserved = sum(actual == 1 | expected == 1),
    mismatch_among_either = sum(mismatch) / sum(actual == 1 | expected == 1), .groups = "drop"
  )
readr::write_csv(summary, file.path(table_dir, "assignment_disagreements.csv"))
benchmarks <- records |>
  dplyr::filter(status == "available") |>
  dplyr::group_split(outcome) |>
  purrr::map(benchmark_residual_spread) |>
  dplyr::bind_rows()
readr::write_csv(benchmarks, file.path(table_dir, "assignment_residual_benchmarks.csv"))
labels <- c(
  women_instrument = "Women: RD instrument", women_prediction = "Women: prediction sensitivity",
  sc = "Scheduled Castes", st = "Scheduled Tribes"
)
plot_data <- benchmarks |>
  dplyr::filter(statistic %in% c("equal_unit:district_sd", "equal_unit:block_sd")) |>
  dplyr::mutate(label = labels[outcome], level = ifelse(grepl("district", statistic), "District", "Block"))
plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = level, y = 100 * observed)) +
  ggplot2::geom_linerange(ggplot2::aes(ymin = 100 * benchmark_lower, ymax = 100 * benchmark_upper),
    linewidth = 2, colour = "grey65"
  ) +
  ggplot2::geom_point(ggplot2::aes(y = 100 * benchmark_mean), shape = 1, size = 3) +
  ggplot2::geom_point(colour = "#08519c", size = 3) +
  ggplot2::facet_wrap(~label) +
  theme_paper() +
  ggplot2::labs(
    x = NULL, y = "SD of disagreement rates (percentage points)",
    title = "UP 2015: geographic concentration of prediction disagreements",
    caption = paste("Blue: observed spread. Open circles/grey bars: benchmark mean/middle 95% (999 permutations).",
      "Equal unit weights. Supplied author predictions; benchmark preserves stratum totals, not local legal quotas.",
      sep = "\n"
    )
  )
save_figure(plot, "assignment_residual_spread", figure_dir, figure_width, figure_height + 1, figure_dpi)
lines <- c(
  "# UP 2015: disagreements with supplied assignment predictions", "",
  "These statistics audit the authors' supplied predictions, not an independently reconstructed legal rule.", "",
  "| Assignment | Observed GPs | Disagreements | Rate among all GPs | Rate among observed/predicted reserved GPs |",
  "|---|---:|---:|---:|---:|"
)
for (i in seq_len(nrow(summary))) {
  row <- summary[i, ]
  lines <- c(lines, sprintf(
    "| %s | %s | %s | %.2f%% | %.2f%% |", labels[[row$outcome]],
    format(row$seats, big.mark = ","), format(row$mismatches, big.mark = ","),
    100 * row$mismatch_rate, 100 * row$mismatch_among_either
  ))
}
lines <- c(
  lines, "", "| Assignment | Geography | Observed SD (pp) | Benchmark SD (pp) | 95% benchmark range (pp) |",
  "|---|---|---:|---:|---:|"
)
for (i in seq_len(nrow(plot_data))) {
  row <- plot_data[i, ]
  lines <- c(lines, sprintf(
    "| %s | %s | %.2f | %.2f | %.2f to %.2f |", row$label, row$level,
    100 * row$observed, 100 * row$benchmark_mean, 100 * row$benchmark_lower, 100 * row$benchmark_upper
  ))
}
lines <- c(
  lines, "",
  "The benchmark moves a fixed number of prediction disagreements among GPs within strata.",
  "For women, strata are observed caste category and predicted female assignment; for SC/ST they are predicted caste.",
  "It describes concentration relative to exchangeable disagreements. It is not a test of lawful random allocation.",
  "Departures can reflect author prediction error, data error, exceptions or administrative decisions.",
  "The between-district share in the CSV decomposes observed block-rate variance, including finite-group noise.",
  "It is not the noise-adjusted share of underlying heterogeneity. Benchmark intervals are not confidence intervals.",
  "SC and ST are separate benchmarks, not jointly valid caste-allocation simulations.",
  "All four outcomes use observed geography and assignment; missing records remain in the coverage table.",
  "The separate caste build uses modern LGD/SHRUG aggregates; it is not substituted for the authors' population inputs."
)
writeLines(lines, file.path(table_dir, "assignment_residuals.md"))
print(summary)
print(plot_data |> dplyr::select(outcome, level, observed, benchmark_mean, benchmark_lower, benchmark_upper))

write_assignment_findings(summary, benchmarks, project_file("README.md"))
artifacts <- c(
  list.files(output_dir, full.names = TRUE),
  list.files(table_dir, pattern = "^assignment_", full.names = TRUE),
  list.files(figure_dir, pattern = "^assignment_", full.names = TRUE)
)
artifacts <- artifacts[basename(artifacts) != "output_hashes.csv"]
tibble::tibble(
  path = sub(paste0(project_root, "/"), "", artifacts, fixed = TRUE),
  sha256 = vapply(artifacts, function(path) digest::digest(file = path, algo = "sha256"), character(1))
) |>
  readr::write_csv(file.path(output_dir, "output_hashes.csv"))
