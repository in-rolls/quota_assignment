for (state in names(reservation_cycles)) {
  transitions <- readr::read_csv(file.path(table_dir, paste0(state, "_transitions.csv")), show_col_types = FALSE)
  plot <- plot_transitions(transitions, level_colours, theme_paper())
  save_figure(plot, paste0(state, "_transitions"), figure_dir, figure_width, figure_height, figure_dpi)
  path <- model_table_file(state, "contrasts.csv")
  if (file.exists(path)) {
    estimates <- readr::read_csv(path, show_col_types = FALSE)
    if (nrow(estimates) > 0L) {
      plot <- plot_contrasts(estimates, level_colours, theme_paper())
      save_figure(
        plot, paste(state, model_name, "contrasts", sep = "_"),
        figure_dir, figure_width, figure_height, figure_dpi
      )
    }
  }
}
