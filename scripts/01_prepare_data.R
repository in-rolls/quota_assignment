for (state in names(reservation_cycles)) {
  input <- read_source(source_root, state, source_lock)
  prepared <- build_panel(input$seats, reservation_cycles[[state]])
  directory <- file.path(build_dir, state)
  for (name in names(prepared)) write_build(prepared[[name]], directory, name)
  input$provenance$panel_sha256 <- digest::digest(file = file.path(directory, "panel.rds"), algo = "sha256")
  readr::write_csv(input$provenance, file.path(directory, "provenance.csv"))
  prepared$links |>
    dplyr::count(transition, district, match_status, name = "seats") |>
    readr::write_csv(file.path(directory, "coverage.csv"))
  prepared$records |>
    dplyr::count(year, district, exclusion, name = "seats") |>
    readr::write_csv(file.path(directory, "exclusions.csv"))
}
