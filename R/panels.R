normalize_name <- function(value) {
  value <- as.character(value)
  value[is.na(value)] <- ""
  stringi::stri_trans_nfc(value) |>
    stringi::stri_trans_casefold() |>
    stringr::str_squish()
}

encode_places <- function(seats, columns) {
  apply(as.data.frame(seats[columns]), 1, function(row) {
    as.character(jsonlite::toJSON(unname(as.list(row)), auto_unbox = TRUE))
  })
}

build_panel <- function(seats, cycles) {
  key <- c("district", "block", "gram_panchayat")
  records <- seats |>
    dplyr::mutate(year = as.integer(as.character(year))) |>
    dplyr::filter(tier == "gp_head", year %in% cycles) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(key), as.character, .names = "{.col}_raw")) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(key), normalize_name)) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(key, "year")))) |>
    dplyr::mutate(is_ambiguous = dplyr::n() > 1L) |>
    dplyr::ungroup()
  status <- suppressWarnings(as.numeric(as.character(records$reserved_woman)))
  if (any(!is.na(records$reserved_woman) & is.na(status)) || any(!is.na(status) & !status %in% 0:1)) {
    stop("Reservation must be 0, 1, or missing")
  }
  records$reserved_woman <- status
  records <- records |>
    dplyr::mutate(
      exclusion = dplyr::case_when(
        stringr::str_detect(
          dplyr::coalesce(as.character(election_type), ""),
          stringr::regex("by", ignore_case = TRUE)
        ) ~ "by_election",
        is_ambiguous ~ "ambiguous_key",
        dplyr::if_any(dplyr::all_of(key), ~ .x == "") ~ "missing_geography",
        is.na(reserved_woman) ~ "missing_reservation",
        TRUE ~ ""
      )
    )
  records$gp_id <- encode_places(records, key)
  records$block_id <- encode_places(records, key[1:2])
  eligible <- dplyr::filter(records, exclusion == "")
  links <- purrr::map2(cycles[-length(cycles)], cycles[-1], function(before, after) {
    previous <- eligible |>
      dplyr::filter(year == before) |>
      dplyr::mutate(has_previous = TRUE)
    current <- eligible |>
      dplyr::filter(year == after) |>
      dplyr::mutate(has_current = TRUE)
    dplyr::full_join(previous, current, by = key, suffix = c("_previous", ""), relationship = "one-to-one") |>
      dplyr::mutate(
        transition = paste(before, after, sep = "-"),
        match_status = dplyr::case_when(
          !is.na(has_previous) & !is.na(has_current) ~ "both",
          !is.na(has_previous) ~ "previous_only",
          TRUE ~ "current_only"
        )
      )
  }) |>
    dplyr::bind_rows()
  panel <- links |>
    dplyr::filter(match_status == "both") |>
    dplyr::mutate(
      previous_reserved = as.integer(reserved_woman_previous),
      current_reserved = as.integer(reserved_woman)
    ) |>
    dplyr::arrange(transition, district, block, gram_panchayat) |>
    dplyr::group_by(gp_id) |>
    dplyr::mutate(initial_reserved = dplyr::first(previous_reserved)) |>
    dplyr::ungroup()
  if (nrow(panel) == 0L) stop("No unique adjacent-cycle matches")
  histories <- eligible |>
    dplyr::select(gp_id, year, reserved_woman) |>
    tidyr::pivot_wider(names_from = year, values_from = reserved_woman, names_prefix = "year_")
  list(panel = panel, records = records, links = links, histories = histories)
}
