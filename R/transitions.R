count_transitions <- function(panel, level) {
  if (!level %in% c("district", "block")) stop("Unknown geographic level")
  groups <- c("transition", "district", if (level == "block") "block_id")
  panel |>
    dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
    dplyr::summarise(
      previous_unreserved_n = sum(previous_reserved == 0L),
      previous_reserved_n = sum(previous_reserved == 1L),
      reserved_after_unreserved_n = sum(current_reserved[previous_reserved == 0L]),
      reserved_after_reserved_n = sum(current_reserved[previous_reserved == 1L]),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      reservation_after_unreserved = reserved_after_unreserved_n / previous_unreserved_n,
      reservation_after_reserved = reserved_after_reserved_n / previous_reserved_n,
      contrast = reservation_after_reserved - reservation_after_unreserved,
      level = level
    )
}

partition_variance <- function(contrasts, districts, weights = rep(1, length(districts))) {
  contrasts <- as.matrix(contrasts)
  stopifnot(ncol(contrasts) == length(districts), length(weights) == length(districts), all(weights > 0))
  weights <- weights / sum(weights)
  mean_contrast <- drop(contrasts %*% weights)
  total <- drop((contrasts - mean_contrast)^2 %*% weights)
  between <- rep(0, nrow(contrasts))
  for (district in unique(districts)) {
    selected <- districts == district
    mass <- sum(weights[selected])
    district_mean <- drop(contrasts[, selected, drop = FALSE] %*% weights[selected]) / mass
    between <- between + mass * (district_mean - mean_contrast)^2
  }
  tibble::tibble(
    total_sd = sqrt(total), between_district_sd = sqrt(between),
    within_district_sd = sqrt(pmax(0, total - between)),
    district_share = ifelse(total > 1e-12, between / total, NA_real_)
  )
}

summarize_draws <- function(draws) {
  finite <- draws[is.finite(draws)]
  if (length(finite) == 0L) {
    return(tibble::tibble(lower = NA_real_, estimate = NA_real_, upper = NA_real_))
  }
  interval <- stats::quantile(finite, c(0.025, 0.5, 0.975), names = FALSE)
  tibble::tibble(lower = interval[1], estimate = interval[2], upper = interval[3])
}

simulate_benchmark <- function(panel, level, replicates = 1000L, seed = 20261101L) {
  set.seed(seed)
  counts <- count_transitions(panel, level)
  purrr::map_dfr(unique(panel$transition), function(cycle) {
    seats <- dplyr::filter(panel, transition == cycle)
    groups <- counts |>
      dplyr::filter(transition == cycle, previous_reserved_n > 0L, previous_unreserved_n > 0L)
    if (nrow(groups) < 2L) {
      return(tibble::tibble())
    }
    probability_zero <- mean(seats$current_reserved[seats$previous_reserved == 0L])
    probability_one <- mean(seats$current_reserved[seats$previous_reserved == 1L])
    noise_sd <- replicate(replicates, {
      reserved_rate <- stats::rbinom(nrow(groups), groups$previous_reserved_n, probability_one) /
        groups$previous_reserved_n
      unreserved_rate <- stats::rbinom(nrow(groups), groups$previous_unreserved_n, probability_zero) /
        groups$previous_unreserved_n
      contrast <- reserved_rate - unreserved_rate
      sqrt(mean((contrast - mean(contrast))^2))
    })
    tibble::tibble(
      transition = cycle, level = level, replicate = seq_len(replicates),
      observed_sd = sqrt(mean((groups$contrast - mean(groups$contrast))^2)),
      simulated_sd = noise_sd, groups = nrow(groups)
    )
  })
}
