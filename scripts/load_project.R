source("scripts/00_config.R")
modules <- c(
  "sources", "panels", "transitions", "models", "simulations", "paper",
  "caste_population", "caste_assignment", "assignment_residuals", "literature_audit"
)
for (module in modules) {
  source(project_file("R", paste0(module, ".R")))
}
