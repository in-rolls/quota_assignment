source("scripts/load_project.R")
smoke <- "--smoke" %in% commandArgs(trailingOnly = TRUE)
settings <- model_settings
if (smoke) {
  settings$iter <- 200L
  settings$warmup <- 100L
}
validation <- validate_models(file.path(build_dir, if (smoke) "validation_smoke" else "validation"), settings,
  replicates = if (smoke) 1L else 20L, district_count = if (smoke) 2L else 6L,
  blocks_per_district = if (smoke) 2L else 5L
)

if (any(nzchar(validation$error))) stop("Some simulation fits failed; inspect validation.csv")
