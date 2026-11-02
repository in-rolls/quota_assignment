for (state in names(reservation_cycles)) {
  panel <- readRDS(file.path(build_dir, state, "panel.rds"))
  transitions <- purrr::map_dfr(c("district", "block"), ~ count_transitions(panel, .x))
  benchmarks <- purrr::map_dfr(c("district", "block"), ~ simulate_benchmark(panel, .x, seed = analysis_seed))
  readr::write_csv(transitions, file.path(table_dir, paste0(state, "_transitions.csv")))
  readr::write_csv(benchmarks, file.path(table_dir, paste0(state, "_benchmarks.csv")))
}
