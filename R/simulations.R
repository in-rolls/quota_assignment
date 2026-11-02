sample_quota <- function(probability, quota) {
  size <- length(probability)
  odds <- probability / (1 - probability)
  sums <- matrix(0, size + 1L, quota + 1L)
  sums[, 1L] <- 1
  for (seat in seq_len(size)) {
    for (count in seq_len(min(seat, quota))) {
      sums[seat + 1L, count + 1L] <- sums[seat, count + 1L] + odds[seat] * sums[seat, count]
    }
  }
  reserved <- integer(size)
  left <- quota
  for (seat in rev(seq_len(size))) {
    if (left > 0L && stats::runif(1) < odds[seat] * sums[seat, left] / sums[seat + 1L, left + 1L]) {
      reserved[seat] <- 1L
      left <- left - 1L
    }
  }
  reserved
}

simulate_panel <- function(seed = 1L, heterogeneous = TRUE, fixed_quota = FALSE,
                           district_count = 6L, blocks_per_district = 5L, gp_scale = 0) {
  set.seed(seed)
  rows <- list()
  truth <- list()
  district_slopes <- if (heterogeneous) stats::rnorm(district_count, 0, 0.6) else rep(0, district_count)
  for (district in seq_len(district_count)) {
    for (block in seq_len(blocks_per_district)) {
      block_id <- paste(district, block, sep = "/")
      size <- sample(12:100, 1)
      slope <- -0.8 + district_slopes[district] + if (heterogeneous) stats::rnorm(1, 0, 0.5) else 0
      previous <- stats::rbinom(size, 1, 0.4)
      initial <- previous
      gp_effect <- stats::rnorm(size, 0, gp_scale)
      for (cycle in 0:2) {
        probability <- stats::plogis(-0.2 + 0.15 * cycle + slope * previous + gp_effect)
        current <- if (fixed_quota) {
          sample_quota(probability, round(size * 0.4))
        } else {
          stats::rbinom(size, 1, probability)
        }
        group <- paste(block_id, cycle, sep = ":")
        rows[[group]] <- tibble::tibble(
          transition = as.character(cycle), district = as.character(district), block_id = block_id,
          gp_id = paste(block_id, seq_len(size), sep = "/"), previous_reserved = previous,
          current_reserved = current, initial_reserved = initial,
          reserved_caste = "NONE", reserved_caste_previous = "NONE"
        )
        truth[[group]] <- tibble::tibble(
          transition = as.character(cycle), district = as.character(district), block_id = block_id,
          contrast = mean(probability[previous == 1L]) - mean(probability[previous == 0L])
        )
        previous <- current
      }
    }
  }
  list(panel = dplyr::bind_rows(rows), truth = dplyr::bind_rows(truth))
}

validate_models <- function(directory, settings, replicates = 20L, district_count = 6L, blocks_per_district = 5L) {
  scenarios <- tibble::tribble(
    ~scenario, ~heterogeneous, ~fixed_quota, ~gp_scale,
    "homogeneous", FALSE, FALSE, 0,
    "heterogeneous", TRUE, FALSE, 0,
    "fixed_quota", TRUE, TRUE, 0,
    "persistent_gp", TRUE, FALSE, 0.6
  )
  results <- list()
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  for (scenario in seq_len(nrow(scenarios))) {
    for (replicate in seq_len(replicates)) {
      specification <- scenarios[scenario, ]
      key <- paste(specification$scenario, replicate, sep = "_")
      generated <- simulate_panel(
        settings$seed + replicate, specification$heterogeneous,
        specification$fixed_quota, district_count, blocks_per_district, specification$gp_scale
      )
      outcome <- tryCatch(
        {
          fit <- fit_reservation_model(generated$panel, settings, file.path(directory, key))
          panel <- prepare_model_data(generated$panel)
          geography <- estimate_geography(fit, panel, "block")
          estimates <- summarize_geography(geography) |>
            dplyr::filter(weighting == "equal_units", metric == "total_sd")
          truth <- generated$truth |>
            dplyr::semi_join(geography$estimates, by = c("transition", "district", "block_id")) |>
            dplyr::group_by(transition) |>
            dplyr::summarise(target = sqrt(mean((contrast - mean(contrast))^2)), .groups = "drop")
          dplyr::left_join(estimates, truth, by = "transition") |>
            dplyr::mutate(
              coverage = if (specification$fixed_quota || !specification$heterogeneous) {
                NA
              } else {
                lower <= target & upper >= target
              },
              diagnostics_passed = check_sampling(fit)$passed, error = ""
            )
        },
        error = function(error) tibble::tibble(error = conditionMessage(error))
      )
      results[[key]] <- outcome |>
        dplyr::mutate(scenario = specification$scenario, replicate = replicate)
      readr::write_csv(dplyr::bind_rows(results), file.path(directory, "validation.csv"))
    }
  }
  dplyr::bind_rows(results)
}
