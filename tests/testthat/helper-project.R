root <- rprojroot::find_root(rprojroot::has_file("DESCRIPTION"))
modules <- c(
  "sources", "panels", "transitions", "models", "simulations", "paper",
  "caste_population", "caste_assignment", "assignment_residuals", "literature_audit"
)
for (module in modules) {
  source(file.path(root, "R", paste0(module, ".R")))
}

make_seats <- function() {
  tidyr::expand_grid(year = c(2005L, 2010L, 2015L, 2020L), gram_panchayat = c("A", "B")) |>
    dplyr::mutate(
      district = "D", block = "B", tier = "gp_head", election_type = NA_character_,
      reserved_woman = as.integer(gram_panchayat == "A"), reserved_caste = "NONE"
    )
}
