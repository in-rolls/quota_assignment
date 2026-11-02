source("scripts/load_project.R")

roots <- list(
  in_rolls = Sys.getenv("IN_ROLLS", dirname(project_root)),
  shrug = Sys.getenv("SHRUG", path.expand("~/data/shrug/2.0"))
)
lock <- jsonlite::read_json(project_file("docs", "caste_source_lock.json"), simplifyVector = TRUE)
paths <- vapply(seq_len(nrow(lock)), function(i) {
  path <- file.path(roots[[lock$root[i]]], lock$path[i])
  if (!file.exists(path)) stop("Missing input: ", path)
  if (digest::digest(file = path, algo = "sha256") != lock$sha256[i]) stop("Source hash changed: ", path)
  path
}, character(1))
names(paths) <- lock$name
caste_dir <- file.path(build_dir, "caste")
dir.create(caste_dir, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(lock, file.path(caste_dir, "source_provenance.csv"))
keys <- readr::read_csv(paths[["rural_keys"]],
  col_types = readr::cols(.default = readr::col_character()), progress = FALSE
) |>
  dplyr::select(shrid2, pc11_state_id, village_id = pc11_village_id)
urban_shrids <- readr::read_csv(paths[["urban_keys"]],
  col_types = readr::cols(.default = readr::col_character()), progress = FALSE
) |>
  dplyr::pull(shrid2)
populations <- list(
  `2001` = read_census_population(paths[["census_2001"]], 2001L),
  `2011` = read_census_population(paths[["census_2011"]], 2011L)
)
coverage <- list()
link_coverage <- list()
for (state in names(reservation_cycles)) {
  state_code <- if (state == "rajasthan") "08" else "09"
  state_shrids <- keys$shrid2[keys$pc11_state_id == state_code]
  state_keys <- keys |>
    dplyr::filter(shrid2 %in% state_shrids) |>
    dplyr::select(shrid2, village_id)
  lgd <- read_lgd_villages(paths[[paste0(state, "_lgd")]])
  seats <- read_source(source_root, state, source_lock)$seats
  for (census_year in names(populations)) {
    built <- build_gp_population(lgd, state_keys, populations[[census_year]], urban_shrids)
    prefix <- paste(state, census_year, sep = "_")
    for (name in names(built)) {
      arrow::write_parquet(built[[name]], file.path(caste_dir, paste0(prefix, "_", name, ".parquet")))
    }
    coverage[[prefix]] <- built$gps |>
      dplyr::count(population_status, name = "gps") |>
      dplyr::mutate(state = state, census_year = as.integer(census_year))
    links <- list(master = link_caste_elections(seats, built$gps, reservation_cycles[[state]]))
    if (state == "uttar_pradesh") links$weaver <- read_weaver_links(paths[["weaver_wide"]], built$gps)
    for (source in names(links)) {
      linked <- links[[source]]
      label <- paste(prefix, source, sep = "_")
      arrow::write_parquet(linked, file.path(caste_dir, paste0(label, "_links.parquet")))
      link_coverage[[label]] <- linked |>
        dplyr::count(year, link_status, name = "seats") |>
        dplyr::mutate(state = state, census_year = as.integer(census_year), source = source)
      linked |>
        dplyr::count(year, district_key, block_key, link_status, sc_reserved, st_reserved, name = "seats") |>
        readr::write_csv(file.path(table_dir, paste0(label, "_link_coverage.csv")))
      for (category in c("sc", "st")) {
        add_metadata <- function(data, diagnostic = "unadjusted_share_order") {
          data |>
            dplyr::mutate(
              state = state, source = source, census_year = as.integer(census_year), geography_year = 2024L,
              diagnostic = diagnostic, historical_continuity_verified = FALSE,
              election_year_verified = source != "weaver" | year != 2020L,
              link_method = paste(sort(unique(linked$link_method[linked$link_status == "linked"])), collapse = ";")
            )
        }
        summary <- summarize_caste_geography(linked, category) |> add_metadata()
        readr::write_csv(summary, file.path(table_dir, paste0(label, "_", category, "_geography.csv")))
        bins <- linked |>
          dplyr::filter(link_status == "linked", !is.na(.data[[paste0(category, "_reserved")]])) |>
          dplyr::mutate(share_bin = pmin(floor(.data[[paste0(category, "_share")]] * 20), 19L)) |>
          dplyr::group_by(year, share_bin) |>
          dplyr::summarise(
            seats = dplyr::n(), share = mean(.data[[paste0(category, "_share")]]),
            reserved_share = mean(.data[[paste0(category, "_reserved")]]), .groups = "drop"
          )
        readr::write_csv(
          add_metadata(bins, "unadjusted_population_share"),
          file.path(table_dir, paste0(label, "_", category, "_bins.csv"))
        )
        plot <- ggplot2::ggplot(bins, ggplot2::aes(share * 100, reserved_share * 100, size = seats)) +
          ggplot2::geom_point(alpha = 0.7, colour = "#08519c") +
          ggplot2::facet_wrap(~year) +
          theme_paper() +
          ggplot2::labs(
            x = paste(toupper(category), "population (%)"), y = "Reserved seats (%)", size = "Seats",
            title = paste(stringr::str_to_title(gsub("_", " ", state)), toupper(category), "reservation"),
            subtitle = paste("Census", census_year, "on 2024 GP boundaries;", source, "election labels"),
            caption = paste("Matched sample; 5 percentage point bins. No historical eligibility adjustment.",
              if (source == "weaver") "Source-labeled 2020 is retained pending year verification." else "",
              sep = "\n"
            )
          )
        ggplot2::ggsave(file.path(figure_dir, paste0(label, "_", category, "_share.png")), plot,
          width = figure_width, height = figure_height, dpi = figure_dpi
        )
      }
    }
    for (category in c("sc", "st")) {
      arrow::write_parquet(
        rank_catalog(built$gps, category),
        file.path(caste_dir, paste0(prefix, "_", category, "_catalog_ranks.parquet"))
      )
    }
  }
}
coverage <- dplyr::bind_rows(coverage)
link_coverage <- dplyr::bind_rows(link_coverage)
readr::write_csv(coverage, file.path(table_dir, "caste_population_coverage.csv"))
readr::write_csv(link_coverage, file.path(table_dir, "caste_link_coverage.csv"))
print(coverage, n = Inf)
print(dplyr::filter(link_coverage, link_status == "linked"), n = Inf)

write_caste_summary(coverage, link_coverage, file.path(table_dir, "caste_summary.md"), project_file("README.md"))

artifacts <- c(
  list.files(caste_dir, full.names = TRUE),
  list.files(table_dir, pattern = "^(caste_|(rajasthan|uttar_pradesh)_20(01|11)_)", full.names = TRUE),
  list.files(figure_dir, pattern = "^(rajasthan|uttar_pradesh)_20(01|11)_", full.names = TRUE)
)
artifacts <- artifacts[basename(artifacts) != "output_hashes.csv"]
tibble::tibble(
  path = sub(paste0(project_root, "/"), "", artifacts, fixed = TRUE),
  sha256 = vapply(artifacts, function(path) digest::digest(file = path, algo = "sha256"), character(1))
) |>
  readr::write_csv(file.path(caste_dir, "output_hashes.csv"))
