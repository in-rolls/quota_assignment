project_root <- rprojroot::find_root(rprojroot::has_file("DESCRIPTION"))
project_file <- function(...) file.path(project_root, ...)
source_root <- Sys.getenv("LOCAL_ELECTIONS", file.path(dirname(project_root), "local_elections"))
build_dir <- project_file("data", "build")
table_dir <- project_file("tabs")
figure_dir <- project_file("figs")
source_lock <- project_file("docs", "source_lock.json")
reservation_cycles <- list(
  rajasthan = c(2005L, 2010L, 2015L, 2020L),
  uttar_pradesh = c(2005L, 2010L, 2015L, 2021L)
)
analysis_seed <- 20261101L
model_settings <- list(
  chains = 4L, iter = 2000L, warmup = 1000L, seed = analysis_seed,
  prior_scale = 0.5, adjusted = FALSE, complete_history = FALSE
)
model_name <- Sys.getenv("RESERVATION_MODEL", "primary")
if (!model_name %in% c("primary", "prior_narrow", "prior_wide", "composition", "complete_history")) {
  stop("Unknown RESERVATION_MODEL")
}
if (model_name == "prior_narrow") model_settings$prior_scale <- 0.25
if (model_name == "prior_wide") model_settings$prior_scale <- 1
if (model_name == "composition") model_settings$adjusted <- TRUE
if (model_name == "complete_history") model_settings$complete_history <- TRUE
model_table_file <- function(state, name) {
  file.path(table_dir, paste(state, model_name, name, sep = "_"))
}
figure_width <- 8
figure_height <- 5
figure_dpi <- 180
level_colours <- c(district = "#08519c", block = "#a63603")
theme_paper <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0),
      plot.title.position = "plot"
    )
}
for (path in c(build_dir, table_dir, figure_dir)) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
