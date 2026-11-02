prepare_model_data <- function(panel, adjusted = FALSE, complete_history = FALSE) {
  panel <- panel |>
    dplyr::mutate(
      reserved_caste = as.character(reserved_caste),
      reserved_caste_previous = as.character(reserved_caste_previous)
    )
  if (complete_history) {
    transitions <- dplyr::n_distinct(panel$transition)
    panel <- panel |>
      dplyr::group_by(gp_id) |>
      dplyr::filter(dplyr::n_distinct(transition) == transitions) |>
      dplyr::ungroup()
  }
  if (adjusted) {
    panel <- panel |>
      dplyr::filter(!is.na(reserved_caste), !is.na(reserved_caste_previous))
  }
  if (nrow(panel) == 0L) stop("No observations meet model restrictions")
  panel <- panel |>
    dplyr::mutate(
      transition = factor(transition),
      district_transition = interaction(district, transition, drop = TRUE),
      block_transition = interaction(block_id, transition, drop = TRUE),
      caste_transition = factor(paste(reserved_caste_previous, reserved_caste, sep = " -> "))
    )
  if (adjusted) {
    categories <- levels(panel$caste_transition)[-1]
    for (index in seq_along(categories)) {
      name <- sprintf("category_%03d", index)
      panel[[name]] <- as.integer(panel$caste_transition == categories[index])
      panel[[paste0(name, "_lag")]] <- panel[[name]] * panel$previous_reserved
    }
  }
  panel
}

reservation_formula <- function(category_columns = character()) {
  terms <- paste(
    "current_reserved ~ 0 + transition + transition:previous_reserved + initial_reserved",
    "+ (1 + previous_reserved || district_transition)",
    "+ (1 + previous_reserved || block_transition) + (1 | gp_id)"
  )
  if (length(category_columns) > 0L) terms <- paste(terms, "+", paste(category_columns, collapse = " + "))
  brms::bf(stats::as.formula(terms))
}

fit_reservation_model <- function(panel, settings, file, prior_only = FALSE) {
  panel <- prepare_model_data(panel, settings$adjusted, settings$complete_history)
  priors <- c(
    brms::set_prior("normal(0, 1.5)", class = "b"),
    brms::set_prior("normal(0, 1)", class = "b", coef = "initial_reserved"),
    brms::set_prior(paste0("normal(0, ", settings$prior_scale, ")"), class = "sd")
  )
  category_columns <- grep("^category_[0-9]+", names(panel), value = TRUE)
  for (column in category_columns) {
    priors <- c(priors, brms::set_prior("normal(0, 1)", class = "b", coef = column))
  }
  brms::brm(
    formula = reservation_formula(category_columns), data = panel,
    family = brms::bernoulli(), prior = priors,
    chains = settings$chains, cores = min(settings$chains, 4L),
    iter = settings$iter, warmup = settings$warmup, seed = settings$seed,
    sample_prior = if (prior_only) "only" else "yes", backend = "rstan",
    control = list(adapt_delta = 0.95, max_treedepth = 12L),
    file = file, file_refit = "always", refresh = 0
  )
}

check_sampling <- function(fit) {
  diagnostics <- posterior::summarise_draws(posterior::as_draws_array(fit))
  sampler <- brms::nuts_params(fit)
  divergences <- sum(sampler$Value[sampler$Parameter == "divergent__"])
  tree_depth <- sum(sampler$Value[sampler$Parameter == "treedepth__"] >= 12)
  parameters <- diagnostics |> dplyr::filter(variable != "lp__", !grepl("^prior_", variable))
  passed <- posterior::nchains(posterior::as_draws_array(fit)) >= 4L &&
    all(is.finite(parameters$rhat) & parameters$rhat <= 1.01) &&
    all(parameters$ess_bulk >= 400 & parameters$ess_tail >= 400) &&
    divergences == 0L && tree_depth == 0L
  list(diagnostics = diagnostics, passed = passed, divergences = divergences, tree_depth = tree_depth)
}

compute_contrast <- function(probabilities, seats, category_weights = NULL) {
  if (length(unique(seats$previous_reserved)) < 2L) {
    return(NULL)
  }
  if (is.null(category_weights)) {
    return(
      rowMeans(probabilities[, seats$previous_reserved == 1L, drop = FALSE]) -
        rowMeans(probabilities[, seats$previous_reserved == 0L, drop = FALSE])
    )
  }
  categories <- as.character(seats$caste_transition)
  contrast <- rep(0, nrow(probabilities))
  for (category in names(category_weights)) {
    zero <- categories == category & seats$previous_reserved == 0L
    one <- categories == category & seats$previous_reserved == 1L
    if (!any(zero) || !any(one)) {
      return(NULL)
    }
    contrast <- contrast + category_weights[[category]] *
      (rowMeans(probabilities[, one, drop = FALSE]) - rowMeans(probabilities[, zero, drop = FALSE]))
  }
  contrast
}

estimate_geography <- function(fit, panel, level, adjusted = FALSE) {
  group_columns <- c("transition", "district", if (level == "block") "block_id")
  groups <- panel |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_columns))) |>
    dplyr::group_split()
  estimates <- list()
  draws <- list()
  for (seats in groups) {
    weights <- NULL
    if (adjusted) {
      population <- panel[panel$transition == seats$transition[1], ]
      weights <- prop.table(table(as.character(population$caste_transition)))
    }
    probabilities <- brms::posterior_epred(fit, newdata = seats)
    contrast <- compute_contrast(probabilities, seats, weights)
    if (is.null(contrast)) next
    group <- paste(as.character(seats$transition[1]), seats$district[1],
      if (level == "block") seats$block_id[1] else "",
      sep = "\t"
    )
    estimates[[group]] <- tibble::tibble(
      transition = as.character(seats$transition[1]), district = seats$district[1],
      block_id = if (level == "block") seats$block_id[1] else NA_character_,
      level = level, group = group, seat_count = nrow(seats),
      previous_unreserved_n = sum(seats$previous_reserved == 0L),
      previous_reserved_n = sum(seats$previous_reserved == 1L)
    ) |> dplyr::bind_cols(summarize_draws(contrast))
    draws[[group]] <- contrast
  }
  schema <- tibble::tibble(
    transition = character(), district = character(), block_id = character(),
    level = character(), group = character(), seat_count = integer(),
    previous_unreserved_n = integer(), previous_reserved_n = integer(),
    lower = double(), estimate = double(), upper = double()
  )
  list(estimates = dplyr::bind_rows(c(list(schema), unname(estimates))), draws = draws)
}

summarize_geography <- function(geography) {
  estimates <- geography$estimates
  if (nrow(estimates) == 0L) {
    return(tibble::tibble())
  }
  purrr::map_dfr(unique(estimates$transition), function(cycle) {
    groups <- dplyr::filter(estimates, transition == cycle)
    contrasts <- do.call(cbind, geography$draws[groups$group])
    purrr::map_dfr(c("equal_units", "equal_seats"), function(weighting) {
      weights <- if (weighting == "equal_units") rep(1, nrow(groups)) else groups$seat_count
      spread <- partition_variance(contrasts, groups$district, weights)
      summaries <- purrr::map_dfr(names(spread), function(metric) {
        summarize_draws(spread[[metric]]) |> dplyr::mutate(metric = metric)
      })
      summaries |>
        dplyr::mutate(transition = cycle, level = groups$level[1], weighting = weighting, units = nrow(groups))
    })
  })
}

average_transitions <- function(geography, required_transitions) {
  estimates <- geography$estimates
  if (nrow(estimates) == 0L) {
    return(geography)
  }
  estimates$unit <- if (estimates$level[1] == "block") estimates$block_id else estimates$district
  required <- length(unique(required_transitions))
  eligible <- estimates |>
    dplyr::group_by(unit) |>
    dplyr::filter(dplyr::n() == required, all(required_transitions %in% transition)) |>
    dplyr::group_split()
  averaged <- list()
  for (units in eligible) {
    group <- paste0("average\t", units$unit[1])
    geography$draws[[group]] <- rowMeans(do.call(cbind, geography$draws[units$group]))
    averaged[[group]] <- units[1, ] |>
      dplyr::mutate(
        transition = "equal_transition_average_common_units", group = group,
        seat_count = sum(units$seat_count), previous_unreserved_n = sum(units$previous_unreserved_n),
        previous_reserved_n = sum(units$previous_reserved_n)
      ) |>
      dplyr::select(-lower, -estimate, -upper, -unit) |>
      dplyr::bind_cols(summarize_draws(geography$draws[[group]]))
  }
  geography$estimates <- dplyr::bind_rows(c(list(geography$estimates), unname(averaged)))
  geography
}

check_predictions <- function(fit, panel, kind = "posterior") {
  predictions <- brms::posterior_predict(fit, ndraws = 100L)
  panel$row <- seq_len(nrow(panel))
  panel |>
    dplyr::group_by(transition, previous_reserved) |>
    dplyr::group_split() |>
    purrr::map_dfr(function(seats) {
      summarize_draws(rowMeans(predictions[, seats$row, drop = FALSE])) |>
        dplyr::mutate(
          transition = as.character(seats$transition[1]),
          previous_reserved = seats$previous_reserved[1], observed = mean(seats$current_reserved), kind = kind
        )
    })
}
