prepare_supplied_assignments <- function(data) {
  if (anyDuplicated(data$eleid) || anyNA(data$eleid)) stop("Source GP identifiers must be unique")
  categories <- c("SC", "ST", "OBC", "Unreserved")
  observed <- dplyr::na_if(trimws(data$caste_reserved), "")
  predicted <- dplyr::na_if(trimws(data$caste_reserved_pred), "")
  if (any(!is.na(observed) & !observed %in% categories) ||
        any(!is.na(predicted) & !predicted %in% categories)) {
    stop("Unknown source caste category")
  }
  records <- tibble::tibble(
    gp_id = as.character(data$eleid), district = as.character(data$district), block = as.character(data$block),
    district_name = data$districtname, block_name = data$blockname,
    observed_caste = observed, predicted_caste = predicted,
    women_observed = as.numeric(data$womenreservation), women_predicted = as.numeric(data$femaleinstrument),
    women_alternative = as.numeric(data$women_reserv_pred)
  )
  records$block_id <- encode_places(records, c("district", "block"))
  purrr::map(c("women_instrument", "women_prediction", "sc", "st"), function(outcome) {
    if (outcome %in% c("sc", "st")) {
      actual <- as.integer(observed == toupper(outcome))
      expected <- as.integer(predicted == toupper(outcome))
      stratum <- predicted
    } else {
      actual <- records$women_observed
      expected <- if (outcome == "women_instrument") records$women_predicted else records$women_alternative
      stratum <- paste(observed, expected, sep = ":")
    }
    if (any(!is.na(actual) & !actual %in% 0:1) || any(!is.na(expected) & !expected %in% 0:1)) {
      stop("Invalid binary assignment")
    }
    records |>
      dplyr::mutate(
        outcome = outcome, actual = actual, expected = expected, mismatch = as.integer(actual != expected),
        stratum = stratum,
        status = dplyr::case_when(
          is.na(actual) ~ "missing_observed_assignment", is.na(expected) ~ "missing_supplied_prediction",
          is.na(district) | is.na(block) ~ "missing_geography",
          is.na(observed_caste) ~ "missing_caste_stratum",
          TRUE ~ "available"
        ),
        year = 2015L, prediction_source = "cdm_replication", independently_reconstructed = FALSE
      )
  }) |>
    dplyr::bind_rows()
}

residual_geography <- function(data) {
  purrr::map(c("district", "block"), function(level) {
    keys <- c("outcome", "district", if (level == "block") "block_id")
    data |>
      dplyr::filter(status == "available") |>
      dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
      dplyr::summarise(
        seats = dplyr::n(), mismatches = sum(mismatch), mismatch_rate = mean(mismatch),
        district_name = dplyr::first(district_name),
        block_name = if (level == "block") dplyr::first(block_name) else NA_character_, .groups = "drop"
      ) |>
      dplyr::mutate(level = level)
  }) |>
    dplyr::bind_rows()
}

make_spread_statistic <- function(data) {
  district <- match(data$district, sort(unique(data$district)))
  block <- match(data$block_id, sort(unique(data$block_id)))
  block_district <- district[match(seq_len(max(block)), block)]
  district_n <- tabulate(district)
  block_n <- tabulate(block)
  weighted_variance <- function(x, weight) sum(weight * (x - stats::weighted.mean(x, weight))^2) / sum(weight)
  function(errors) {
    district_rates <- as.numeric(rowsum(errors, district)) / district_n
    block_rates <- as.numeric(rowsum(errors, block)) / block_n
    unlist(lapply(c("equal_unit", "seat"), function(weighting) {
      district_weights <- if (weighting == "seat") district_n else rep(1, length(district_n))
      block_weights <- if (weighting == "seat") block_n else rep(1, length(block_n))
      between_weights <- as.numeric(rowsum(block_weights, block_district))
      district_block_rates <- as.numeric(rowsum(block_rates * block_weights, block_district)) / between_weights
      total <- weighted_variance(block_rates, block_weights)
      between <- weighted_variance(district_block_rates, between_weights)
      stats::setNames(c(
        district_sd = sqrt(weighted_variance(district_rates, district_weights)),
        block_sd = sqrt(total), between_district_sd = sqrt(between),
        within_district_sd = sqrt(max(0, total - between)),
        between_district_share = if (total > 0) between / total else NA_real_
      ), paste(weighting, c(
        "district_sd", "block_sd", "between_district_sd",
        "within_district_sd", "between_district_share"
      ), sep = ":"))
    }))
  }
}

benchmark_residual_spread <- function(data, repetitions = 999L, seed = 20261101L) {
  if (dplyr::n_distinct(data$outcome) != 1L || any(data$status != "available")) stop("One complete outcome required")
  statistic <- make_spread_statistic(data)
  observed <- statistic(data$mismatch)
  strata <- split(seq_len(nrow(data)), data$stratum)
  set.seed(seed)
  simulations <- replicate(repetitions, {
    errors <- data$mismatch
    for (indices in strata) errors[indices] <- data$mismatch[indices[sample.int(length(indices))]]
    statistic(errors)
  })
  tibble::tibble(
    outcome = unique(data$outcome), statistic = names(observed), observed = unname(observed),
    benchmark_mean = rowMeans(simulations),
    benchmark_lower = apply(simulations, 1, function(x) {
      if (all(is.na(x))) NA_real_ else stats::quantile(x, 0.025, na.rm = TRUE)
    }),
    benchmark_upper = apply(simulations, 1, function(x) {
      if (all(is.na(x))) NA_real_ else stats::quantile(x, 0.975, na.rm = TRUE)
    }),
    repetitions = repetitions, seed = seed,
    reference = "exchangeable_prediction_disagreements_within_strata",
    independently_reconstructed = FALSE
  )
}
