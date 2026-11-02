source("scripts/load_project.R")

for (state in names(reservation_cycles)) {
  transitions <- readr::read_csv(file.path(table_dir, paste0(state, "_transitions.csv")), show_col_types = FALSE)
  benchmarks <- readr::read_csv(file.path(table_dir, paste0(state, "_benchmarks.csv")), show_col_types = FALSE)
  write_report(
    state, transitions, benchmarks, file.path(table_dir, paste0(state, "_report.md")),
    file.exists(model_table_file(state, "contrasts.csv"))
  )
}

benchmarks <- purrr::map_dfr(names(reservation_cycles), function(state) {
  readr::read_csv(file.path(table_dir, paste0(state, "_benchmarks.csv")), show_col_types = FALSE) |>
    dplyr::mutate(state = state)
})
write_readme_findings(benchmarks, project_file("README.md"))

if (all(file.exists(file.path(table_dir, c("caste_population_coverage.csv", "caste_link_coverage.csv"))))) {
  coverage <- readr::read_csv(file.path(table_dir, "caste_population_coverage.csv"), show_col_types = FALSE)
  links <- readr::read_csv(file.path(table_dir, "caste_link_coverage.csv"), show_col_types = FALSE)
  write_caste_summary(coverage, links, file.path(table_dir, "caste_summary.md"), project_file("README.md"))
} else {
  message("Caste tables require make caste; no saved coverage tables found.")
}
if (all(file.exists(file.path(table_dir, c("assignment_disagreements.csv", "assignment_residual_benchmarks.csv"))))) {
  summary <- readr::read_csv(file.path(table_dir, "assignment_disagreements.csv"), show_col_types = FALSE)
  benchmarks <- readr::read_csv(file.path(table_dir, "assignment_residual_benchmarks.csv"), show_col_types = FALSE)
  write_assignment_report(summary, benchmarks, file.path(table_dir, "assignment_residuals.md"))
  write_assignment_findings(summary, benchmarks, project_file("README.md"))
} else {
  message("Assignment tables require make assignment; no saved disagreement tables found.")
}

for (stage in c("caste", "assignment_residuals")) {
  manifest <- file.path(build_dir, stage, "output_hashes.csv")
  report_name <- if (stage == "caste") "caste_summary.md" else "assignment_residuals.md"
  report_path <- file.path("tabs", report_name)
  if (file.exists(manifest) && file.exists(project_file(report_path))) {
    hashes <- readr::read_csv(manifest, show_col_types = FALSE)
    hashes$sha256[hashes$path == report_path] <- digest::digest(file = project_file(report_path), algo = "sha256")
    readr::write_csv(hashes, manifest)
  }
}
