source("scripts/00_config.R")
for (module in c("sources", "panels", "transitions", "models", "simulations", "paper")) {
  source(project_file("R", paste0(module, ".R")))
}
