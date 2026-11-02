read_census_population <- function(path, census_year) {
  if (length(census_year) != 1L || !census_year %in% c(2001L, 2011L)) stop("Unsupported Census vintage")
  prefix <- if (census_year == 2001L) "pc01_pca_" else "pc11_pca_"
  fields <- c("tot_p", "p_sc", "p_st")
  columns <- c("shrid2", paste0(prefix, fields), "_mean_p_miss", "_core_p_miss", "_target_weight_share")
  input <- path
  if (grepl("[.]zip$", path)) {
    member <- paste0(prefix, "clean_shrid.csv")
    input <- unz(path, member)
  }
  population <- readr::read_csv(input,
    col_select = dplyr::all_of(columns),
    col_types = readr::cols(.default = readr::col_double(), shrid2 = readr::col_character()),
    progress = FALSE
  )
  names(population) <- c(
    "shrid2", "population", "sc_population", "st_population",
    "mean_missing_share", "core_missing_share", "target_weight_share"
  )
  if (anyDuplicated(population$shrid2) || anyNA(population$shrid2)) stop("Nonunique Census SHRID")
  population |>
    dplyr::mutate(
      census_year = census_year,
      passes_population_screen = dplyr::coalesce(
        is.finite(population) & population >= 0 &
          is.finite(sc_population) & sc_population >= 0 & sc_population <= population &
          is.finite(st_population) & st_population >= 0 & sc_population + st_population <= population &
          mean_missing_share == 0 & core_missing_share == 0 & abs(target_weight_share - 1) < 1e-8,
        FALSE
      )
    )
}

read_lgd_villages <- function(path) {
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), progress = FALSE) |>
    dplyr::transmute(
      lgd_village_id = .data[["Village Code"]],
      village_id = dplyr::na_if(.data[["Village Census 2011 Code"]], "000000"),
      gp_code = .data[["Local Body Code"]], gp_name = .data[["Local Body Name"]],
      district_code = .data[["District Code"]], district_name = .data[["District Name"]]
    ) |>
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ dplyr::na_if(trimws(.x), ""))) |>
    dplyr::distinct()
}

build_gp_population <- function(lgd, census_keys, population, urban_shrids = character()) {
  census_year_value <- unique(population$census_year)
  if (length(census_year_value) != 1L) stop("One Census vintage required")
  if (anyDuplicated(census_keys$village_id) || anyNA(census_keys$village_id)) {
    stop("Nonunique Census village key")
  }
  if (anyDuplicated(population$shrid2)) stop("Nonunique population key")
  catalog_entries <- lgd |>
    dplyr::filter(!is.na(gp_code)) |>
    dplyr::distinct(gp_code, gp_name, district_code, district_name)
  catalog <- catalog_entries |>
    dplyr::group_by(gp_code) |>
    dplyr::summarise(
      catalog_ambiguous = dplyr::n() != 1L,
      dplyr::across(
        c(gp_name, district_code, district_name),
        ~ if (dplyr::n_distinct(.x) == 1L) dplyr::first(.x) else NA_character_
      ), .groups = "drop"
    )
  affected_districts <- catalog_entries |>
    dplyr::filter(gp_code %in% catalog$gp_code[catalog$catalog_ambiguous]) |>
    dplyr::pull(district_code)
  catalog <- catalog |>
    dplyr::mutate(district_membership_complete = !is.na(district_code) & !district_code %in% affected_districts)
  village_gps <- lgd |>
    dplyr::filter(!is.na(village_id)) |>
    dplyr::distinct(village_id, gp_code)
  geography <- census_keys |>
    dplyr::left_join(village_gps, by = "village_id", relationship = "one-to-many", na_matches = "never") |>
    dplyr::group_by(shrid2) |>
    dplyr::mutate(
      geography_status = dplyr::case_when(
        shrid2 %in% urban_shrids ~ "contains_urban_constituent",
        any(is.na(gp_code)) ~ "missing_constituent_gp",
        dplyr::n_distinct(gp_code) > 1L ~ "multiple_constituent_gps",
        TRUE ~ "resolved"
      )
    ) |>
    dplyr::ungroup()
  unresolved <- geography |>
    dplyr::filter(geography_status != "resolved", !is.na(gp_code)) |>
    dplyr::pull(gp_code)
  # Check both directions: every SHRID constituent and every official GP village.
  village_audit <- lgd |>
    dplyr::left_join(census_keys, by = "village_id", relationship = "many-to-one", na_matches = "never") |>
    dplyr::mutate(has_census_key = !is.na(shrid2))
  gp_audit <- village_audit |>
    dplyr::filter(!is.na(gp_code)) |>
    dplyr::group_by(gp_code) |>
    dplyr::summarise(
      villages = dplyr::n_distinct(lgd_village_id),
      villages_without_key = dplyr::n_distinct(lgd_village_id[!has_census_key]),
      geography_complete = all(has_census_key) & !any(gp_code %in% unresolved), .groups = "drop"
    )
  constituents <- geography |>
    dplyr::filter(geography_status == "resolved") |>
    dplyr::distinct(gp_code, shrid2) |>
    dplyr::semi_join(dplyr::filter(gp_audit, geography_complete), by = "gp_code") |>
    dplyr::left_join(population, by = "shrid2", relationship = "one-to-one")
  totals <- constituents |>
    dplyr::group_by(gp_code) |>
    dplyr::summarise(
      shrids = dplyr::n(),
      population_complete = all(dplyr::coalesce(passes_population_screen, FALSE)),
      dplyr::across(c(population, sc_population, st_population), ~ sum(.x)), .groups = "drop"
    )
  gps <- catalog |>
    dplyr::left_join(gp_audit, by = "gp_code", relationship = "one-to-one") |>
    dplyr::left_join(totals, by = "gp_code", relationship = "one-to-one") |>
    dplyr::mutate(
      population_status = dplyr::case_when(
        catalog_ambiguous ~ "ambiguous_catalog",
        !geography_complete ~ "incomplete_geography",
        !dplyr::coalesce(population_complete, FALSE) ~ "incomplete_population",
        population <= 0 ~ "zero_population",
        TRUE ~ "available"
      ),
      dplyr::across(
        c(population, sc_population, st_population),
        ~ dplyr::if_else(population_status == "available", .x, NA_real_)
      ),
      sc_share = sc_population / population, st_share = st_population / population,
      census_year = census_year_value, geography_year = 2024L
    )
  list(
    gps = gps, constituents = constituents, geography = geography, villages = village_audit,
    catalog_entries = catalog_entries
  )
}

rank_catalog <- function(gps, category) {
  # Bounds refer to the contemporary district catalog, never historical policy ranks.
  if (!"district_membership_complete" %in% names(gps)) gps$district_membership_complete <- TRUE
  gps |>
    dplyr::group_by(district_code) |>
    dplyr::mutate(
      rank_lower = dplyr::min_rank(-.data[[paste0(category, "_share")]]),
      rank_upper = rank(-.data[[paste0(category, "_share")]], ties.method = "max", na.last = "keep") +
        sum(is.na(.data[[paste0(category, "_share")]])),
      catalog_size = dplyr::n(), population_missing = sum(is.na(.data[[paste0(category, "_share")]]))
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(dplyr::across(
      c(rank_lower, rank_upper, catalog_size, population_missing),
      ~ dplyr::if_else(district_membership_complete, .x, NA_integer_)
    ))
}
