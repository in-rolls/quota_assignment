for (state in names(reservation_cycles)) {
  transitions <- readr::read_csv(file.path(table_dir, paste0(state, "_transitions.csv")), show_col_types = FALSE)
  benchmarks <- readr::read_csv(file.path(table_dir, paste0(state, "_benchmarks.csv")), show_col_types = FALSE)
  write_report(
    state, transitions, benchmarks, file.path(table_dir, paste0(state, "_report.md")),
    file.exists(model_table_file(state, "contrasts.csv"))
  )
}
