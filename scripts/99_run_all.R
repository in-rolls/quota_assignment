source("scripts/load_project.R")
mode <- commandArgs(trailingOnly = TRUE)
if (length(mode) == 0L) mode <- "descriptive"
if (!mode %in% c("descriptive", "models")) stop("Use descriptive or models")
stages <- c(
  "01_prepare_data.R", "02_estimate.R",
  if (mode == "models") "03_fit_models.R", "04_figures.R", "05_tables.R"
)
for (stage in stages) {
  sys.source(project_file("scripts", stage), envir = new.env(parent = globalenv()))
}
