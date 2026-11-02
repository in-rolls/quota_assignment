link_caste_elections <- function(seats, gps, cycles) {
  keys <- c("district_key", "gp_key")
  catalog <- gps |>
    dplyr::mutate(district_key = normalize_name(district_name), gp_key = normalize_name(gp_name)) |>
    dplyr::add_count(district_key, gp_key, name = "catalog_matches")
  records <- seats |>
    dplyr::filter(tier == "gp_head", year %in% cycles) |>
    dplyr::mutate(
      district_key = normalize_name(dplyr::coalesce(district_latin, district)),
      gp_key = normalize_name(dplyr::coalesce(gram_panchayat_latin, gram_panchayat)),
      block_key = normalize_name(block),
      is_by_election = stringr::str_detect(
        dplyr::coalesce(election_type, ""),
        stringr::regex("by", ignore_case = TRUE)
      ),
      sc_reserved = dplyr::if_else(is.na(reserved_caste), NA_integer_, as.integer(reserved_caste == "SC")),
      st_reserved = dplyr::if_else(is.na(reserved_caste), NA_integer_, as.integer(reserved_caste == "ST"))
    ) |>
    dplyr::add_count(year, district_key, gp_key, name = "election_matches")
  if (anyDuplicated(records$row_id)) stop("Election row IDs are not unique")
  catalog_counts <- catalog |>
    dplyr::distinct(district_key, gp_key, catalog_matches)
  unique_catalog <- catalog |>
    dplyr::filter(catalog_matches == 1L) |>
    dplyr::select(-catalog_matches)
  records |>
    dplyr::left_join(catalog_counts, by = keys, relationship = "many-to-one") |>
    dplyr::left_join(unique_catalog, by = keys, relationship = "many-to-one") |>
    dplyr::mutate(
      link_status = dplyr::case_when(
        is_by_election ~ "by_election",
        district_key == "" | gp_key == "" | block_key == "" ~ "missing_name",
        election_matches > 1L ~ "ambiguous_election_name",
        is.na(catalog_matches) ~ "unmatched_name",
        catalog_matches > 1L ~ "ambiguous_catalog_name",
        population_status != "available" ~ population_status,
        TRUE ~ "linked"
      ),
      link_method = dplyr::if_else(is.na(gram_panchayat_latin), "exact_source_name", "exact_transliterated_name"),
      historical_continuity_verified = FALSE, election_year_verified = TRUE
    )
}

read_weaver_links <- function(path, gps) {
  wide <- arrow::read_parquet(path) |> tibble::as_tibble()
  if (anyDuplicated(wide$gp_id)) stop("Nonunique Weaver GP ID")
  purrr::map(c(2010L, 2015L, 2020L), function(year) {
    column <- function(name) wide[[paste0(name, "_", year)]]
    tibble::tibble(
      row_id = wide$gp_id, year = year, source_vintage = "20250317",
      source_election_code = column("source_election_code"),
      gp_code = as.character(column("gp_code_lgd21")),
      district_key = as.character(column("district_code_ele15")),
      block_key = as.character(column("block_code_ele15")),
      source_shrid = column("shrid"),
      sc_reserved = column("reservation_sc"), st_reserved = column("reservation_st")
    ) |>
      dplyr::filter(!is.na(source_election_code))
  }) |>
    dplyr::bind_rows() |>
    dplyr::mutate(dplyr::across(c(gp_code, district_key, block_key), ~ dplyr::na_if(trimws(.x), ""))) |>
    dplyr::add_count(year, gp_code, name = "election_matches") |>
    dplyr::left_join(gps, by = "gp_code", relationship = "many-to-one", na_matches = "never") |>
    dplyr::mutate(
      link_status = dplyr::case_when(
        is.na(gp_code) ~ "missing_lgd_code",
        election_matches > 1L ~ "ambiguous_lgd_code",
        is.na(district_key) | is.na(block_key) ~ "missing_election_geography",
        is.na(population_status) ~ "unmatched_lgd_code",
        population_status != "available" ~ population_status,
        TRUE ~ "linked"
      ),
      link_method = "supplied_lgd21_code_to_lgd24",
      historical_continuity_verified = FALSE,
      election_year_verified = year != 2020L
    )
}

share_order_pairs <- function(share, reserved) {
  valid <- is.finite(share) & !is.na(reserved)
  share <- share[valid]
  reserved <- reserved[valid]
  if (any(!reserved %in% 0:1)) stop("Reservation must be binary")
  counts <- tibble::tibble(share = share, reserved = reserved) |>
    dplyr::group_by(share) |>
    dplyr::summarise(reserved = sum(reserved), unreserved = dplyr::n() - sum(reserved), .groups = "drop") |>
    dplyr::arrange(share)
  discordant <- sum(counts$reserved * (sum(counts$unreserved) - cumsum(counts$unreserved)))
  comparable <- sum(reserved) * sum(1 - reserved) - sum(counts$reserved * counts$unreserved)
  tibble::tibble(
    seats = length(reserved), reserved_seats = sum(reserved),
    discordant_pairs = discordant, comparable_pairs = comparable,
    discordant_share = if (comparable > 0) discordant / comparable else NA_real_
  )
}

summarize_caste_geography <- function(links, category) {
  usable <- links |>
    dplyr::filter(link_status == "linked")
  purrr::map(c("district", "block"), function(level) {
    keys <- c("year", "district_key", if (level == "block") "block_key")
    usable |>
      dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
      dplyr::group_modify(~ share_order_pairs(
        .x[[paste0(category, "_share")]],
        .x[[paste0(category, "_reserved")]]
      )) |>
      dplyr::ungroup() |>
      dplyr::mutate(level = level, category = category)
  }) |>
    dplyr::bind_rows()
}

score_top_share_assignment <- function(roster, quota, expected_roster_size, evidence) {
  columns <- c("gp_id", "population_share", "eligible", "reserved")
  if (!all(columns %in% names(roster))) stop("Required roster columns missing")
  required <- c(
    "rule", "roster", "census_vintage", "boundaries", "eligibility", "rotation", "quota",
    "category", "allocation_pool", "rule_form"
  )
  if (!all(required %in% names(evidence)) ||
        any(vapply(evidence[required], function(x) length(x) != 1L || is.na(x) || !nzchar(x), logical(1)))) {
    stop("Verified source references required: rule, roster, census, boundaries, eligibility, rotation, quota")
  }
  if (!identical(evidence$rule_form, "top_share_among_eligible") || !evidence$category %in% c("SC", "ST")) {
    stop("Scorer requires SC/ST top_share_among_eligible rule form")
  }
  if (length(expected_roster_size) != 1L || is.na(expected_roster_size) ||
        nrow(roster) != expected_roster_size || anyDuplicated(roster$gp_id) || anyNA(roster$gp_id)) {
    stop("Complete, unique allocation roster required")
  }
  if (!is.logical(roster$eligible) || anyNA(roster$eligible) ||
        any(!is.finite(roster$population_share)) || any(roster$population_share < 0 | roster$population_share > 1)) {
    stop("Known eligibility and population shares required for the full roster")
  }
  if (length(quota) != 1L || is.na(quota) || quota < 0 || quota != as.integer(quota) ||
        quota > sum(roster$eligible)) {
    stop("Invalid externally supplied quota")
  }
  share <- ifelse(roster$eligible, roster$population_share, NA_real_)
  lower <- rank(-share, ties.method = "min", na.last = "keep")
  upper <- rank(-share, ties.method = "max", na.last = "keep")
  expected <- ifelse(!roster$eligible, 0L, ifelse(upper <= quota, 1L, ifelse(lower > quota, 0L, NA_integer_)))
  if (any(!is.na(roster$reserved) & !roster$reserved %in% 0:1)) stop("Reservation must be binary")
  roster |>
    dplyr::mutate(
      category = evidence$category, allocation_pool = evidence$allocation_pool,
      rule_reference = evidence$rule, quota = quota,
      rank_lower = lower, rank_upper = upper, expected_reserved = expected,
      assignment_status = dplyr::case_when(
        is.na(expected_reserved) ~ "unresolved_cutoff_tie",
        is.na(reserved) ~ "missing_observed_reservation",
        reserved == expected_reserved ~ "agrees",
        TRUE ~ "disagrees"
      )
    )
}
