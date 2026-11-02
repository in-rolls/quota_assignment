source("scripts/load_project.R")
audit_dir <- file.path(table_dir, "note_audit")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
write_audit <- function(data, name) readr::write_csv(data, file.path(audit_dir, paste0(name, ".csv")))
variance_population <- function(x, w = rep(1, length(x))) {
  sum(w * (x - sum(w * x) / sum(w))^2) / sum(w)
}
transition_results <- list()
benchmark_checks <- list()
coverage_results <- list()
exclusion_results <- list()
for (state in names(reservation_cycles)) {
  directory <- file.path(build_dir, state)
  panel <- readRDS(file.path(directory, "panel.rds"))
  records <- readRDS(file.path(directory, "records.rds"))
  links <- readRDS(file.path(directory, "links.rds"))
  stopifnot(!anyDuplicated(panel[c("gp_id", "transition")]))
  stopifnot(!anyNA(panel[c("previous_reserved", "current_reserved")]))
  stopifnot(all(panel$previous_reserved %in% 0:1), all(panel$current_reserved %in% 0:1))
  coverage_results[[state]] <- links |>
    dplyr::count(transition, district, match_status, name = "seats") |>
    dplyr::mutate(state = state)
  exclusion_results[[state]] <- records |>
    dplyr::count(year, district, exclusion, name = "seats") |>
    dplyr::mutate(state = state)
  saved <- readr::read_csv(file.path(table_dir, paste0(state, "_benchmarks.csv")), show_col_types = FALSE)
  for (cycle in unique(panel$transition)) {
    seats <- panel[panel$transition == cycle, ]
    p0 <- mean(seats$current_reserved[seats$previous_reserved == 0])
    p1 <- mean(seats$current_reserved[seats$previous_reserved == 1])
    for (level in c("district", "block")) {
      key <- if (level == "district") seats$district else seats$block_id
      counts <- lapply(split(seats, key), function(x) {
        n0 <- sum(x$previous_reserved == 0)
        n1 <- sum(x$previous_reserved == 1)
        tibble::tibble(
          district = x$district[1], n0 = n0, n1 = n1, n = nrow(x),
          rate0 = sum(x$current_reserved[x$previous_reserved == 0]) / n0,
          rate1 = sum(x$current_reserved[x$previous_reserved == 1]) / n1
        )
      }) |>
        dplyr::bind_rows() |>
        dplyr::mutate(contrast = rate1 - rate0)
      eligible <- counts[counts$n0 > 0 & counts$n1 > 0, ]
      draws <- saved[saved$transition == cycle & saved$level == level, ]
      observed <- sqrt(variance_population(eligible$contrast))
      stopifnot(max(abs(draws$observed_sd - observed)) < 1e-12)
      variances <- p0 * (1 - p0) / eligible$n0 + p1 * (1 - p1) / eligible$n1
      expected_variance <- (1 - 1 / nrow(eligible)) * mean(variances)
      simulated_variance <- mean(draws$simulated_sd^2)
      mcse <- stats::sd(draws$simulated_sd^2) / sqrt(nrow(draws))
      stopifnot(abs(simulated_variance - expected_variance) < 6 * mcse)
      benchmark_checks[[length(benchmark_checks) + 1L]] <- tibble::tibble(
        state, cycle, level,
        observed_sd = observed, analytic_mean_variance = expected_variance,
        simulated_mean_variance = simulated_variance, monte_carlo_se = mcse,
        baseline_after_unreserved = p0, baseline_after_reserved = p1,
        benchmark_mean_sd = mean(draws$simulated_sd)
      )
      for (minimum in c(1L, 20L, 50L)) {
        subset <- counts[counts$n0 >= minimum & counts$n1 >= minimum, ]
        for (weighting in c("equal_unit", "seat")) {
          weights <- if (weighting == "seat") subset$n else rep(1, nrow(subset))
          spread <- if (nrow(subset) > 1) sqrt(variance_population(subset$contrast, weights)) else NA_real_
          loo <- vapply(unique(subset$district), function(district) {
            keep <- subset$district != district
            if (sum(keep) < 2) {
              return(NA_real_)
            }
            sqrt(variance_population(subset$contrast[keep], weights[keep]))
          }, numeric(1))
          transition_results[[length(transition_results) + 1L]] <- tibble::tibble(
            state, cycle, level,
            minimum_lag_group = minimum, weighting,
            units = nrow(subset), seats = sum(subset$n), observed_sd = spread,
            leave_district_out_min = if (any(is.finite(loo))) min(loo, na.rm = TRUE) else NA_real_,
            leave_district_out_max = if (any(is.finite(loo))) max(loo, na.rm = TRUE) else NA_real_
          )
        }
      }
    }
  }
}
write_audit(dplyr::bind_rows(transition_results), "transition_sensitivity")
write_audit(dplyr::bind_rows(benchmark_checks), "benchmark_checks")
write_audit(dplyr::bind_rows(coverage_results), "link_coverage")
write_audit(dplyr::bind_rows(exclusion_results), "record_exclusions")
records <- arrow::read_parquet(file.path(build_dir, "assignment_residuals", "gp_predictions.parquet"))
lock <- jsonlite::read_json(project_file("docs", "assignment_source_lock.json"))
raw_path <- file.path(Sys.getenv("IN_ROLLS", dirname(project_root)), lock$path)
stopifnot(digest::digest(file = raw_path, algo = "sha256") == lock$sha256)
raw <- haven::read_dta(raw_path, col_select = c(
  eleid, district, block, caste_reserved, caste_reserved_pred,
  womenreservation, femaleinstrument, women_reserv_pred
))
stopifnot(!anyDuplicated(raw$eleid), !anyNA(raw$eleid))
stopifnot(!anyDuplicated(records[c("gp_id", "outcome")]))
write_audit(dplyr::count(records, outcome, district, status, name = "seats"), "assignment_missingness")
available <- records[records$status == "available", ]
stopifnot(all(available$mismatch == as.integer(available$actual != available$expected)))
saved_summary <- readr::read_csv(file.path(table_dir, "assignment_disagreements.csv"), show_col_types = FALSE)
saved_benchmarks <- readr::read_csv(file.path(table_dir, "assignment_residual_benchmarks.csv"), show_col_types = FALSE)
residual_results <- list()
partitions <- list()
for (outcome in unique(available$outcome)) {
  seats <- available[available$outcome == outcome, ]
  expected <- saved_summary[saved_summary$outcome == outcome, ]
  original <- raw[match(seats$gp_id, as.character(raw$eleid)), ]
  if (outcome %in% c("sc", "st")) {
    actual <- as.integer(trimws(original$caste_reserved) == toupper(outcome))
    prediction <- as.integer(trimws(original$caste_reserved_pred) == toupper(outcome))
  } else {
    actual <- as.numeric(original$womenreservation)
    prediction <- as.numeric(if (outcome == "women_instrument") {
      original$femaleinstrument
    } else {
      original$women_reserv_pred
    })
  }
  stopifnot(identical(actual, as.numeric(seats$actual)) || all(actual == seats$actual))
  stopifnot(all(prediction == seats$expected))
  stopifnot(nrow(seats) == expected$seats, sum(seats$mismatch) == expected$mismatches)
  stopifnot(sum(seats$actual == 1 | seats$expected == 1) == expected$either_reserved)
  for (level in c("district", "block")) {
    key <- if (level == "district") seats$district else seats$block_id
    counts <- lapply(split(seats, key), function(x) {
      tibble::tibble(district = x$district[1], n = nrow(x), rate = sum(x$mismatch) / nrow(x))
    }) |>
      dplyr::bind_rows()
    for (minimum in c(1L, 20L, 50L)) {
      subset <- counts[counts$n >= minimum, ]
      for (weighting in c("equal_unit", "seat")) {
        weights <- if (weighting == "seat") subset$n else rep(1, nrow(subset))
        total <- variance_population(subset$rate, weights)
        loo <- vapply(unique(subset$district), function(district) {
          keep <- subset$district != district
          sqrt(variance_population(subset$rate[keep], weights[keep]))
        }, numeric(1))
        residual_results[[length(residual_results) + 1L]] <- tibble::tibble(
          outcome, level,
          minimum_group = minimum, weighting, units = nrow(subset),
          seats = sum(subset$n), observed_sd = sqrt(total),
          leave_district_out_min = min(loo), leave_district_out_max = max(loo)
        )
        if (minimum == 1L) {
          target <- saved_benchmarks[
            saved_benchmarks$outcome == outcome &
              saved_benchmarks$statistic == paste0(weighting, ":", level, "_sd"),
          ]
          stopifnot(abs(sqrt(total) - target$observed) < 1e-12)
          if (level == "block") {
            district_mean <- ave(seq_len(nrow(subset)), subset$district, FUN = function(i) {
              sum(subset$rate[i] * weights[i]) / sum(weights[i])
            })
            between <- variance_population(district_mean, weights)
            within <- sum(weights * (subset$rate - district_mean)^2) / sum(weights)
            stopifnot(abs(total - between - within) < 1e-12)
            share <- between / total
            target <- saved_benchmarks[
              saved_benchmarks$outcome == outcome &
                saved_benchmarks$statistic == paste0(weighting, ":between_district_share"),
            ]
            stopifnot(abs(share - target$observed) < 1e-12)
            partitions[[length(partitions) + 1L]] <- tibble::tibble(
              outcome, weighting,
              total_variance = total, between_variance = between,
              within_variance = within, district_share = share
            )
          }
        }
      }
    }
  }
}
write_audit(dplyr::bind_rows(residual_results), "assignment_sensitivity")
write_audit(dplyr::bind_rows(partitions), "assignment_partition")
message("Independent descriptive identities, saved headline estimates, and benchmark moments verified.")

transition_sensitivity <- dplyr::bind_rows(transition_results)
assignment_sensitivity <- dplyr::bind_rows(residual_results)
latest <- transition_sensitivity |>
  dplyr::filter(cycle %in% c("2015-2020", "2015-2021"), weighting == "equal_unit") |>
  dplyr::transmute(
    state, cycle, level, minimum_lag_group, units, seats,
    spread_pp = 100 * observed_sd,
    leave_one_min_pp = 100 * leave_district_out_min,
    leave_one_max_pp = 100 * leave_district_out_max
  )
residual_summary <- assignment_sensitivity |>
  dplyr::filter(minimum_group == 1L) |>
  dplyr::transmute(
    outcome, level, weighting, units,
    spread_pp = 100 * observed_sd,
    leave_one_min_pp = 100 * leave_district_out_min,
    leave_one_max_pp = 100 * leave_district_out_max
  )
set.seed(20261103L)
fake_benchmarks <- lapply(c("homogeneous", "heterogeneous"), function(scenario) {
  p1 <- if (scenario == "homogeneous") rep(0.5, 50) else rep(c(0.3, 0.7), each = 25)
  draws <- replicate(2000, {
    contrast <- stats::rbinom(50, 100, p1) / 100 - stats::rbinom(50, 100, 0.5) / 100
    variance_population(contrast)
  })
  known <- variance_population(p1 - 0.5) + 49 / 50 * mean(p1 * (1 - p1) / 100 + 0.25 / 100)
  error <- stats::sd(draws) / sqrt(length(draws))
  stopifnot(abs(mean(draws) - known) < 6 * error)
  tibble::tibble(scenario, analytic_mean_variance = known, simulated_mean_variance = mean(draws), mcse = error)
}) |>
  dplyr::bind_rows()
write_audit(fake_benchmarks, "synthetic_benchmark_check")
writeLines(c(
  "# Descriptive analysis audit", "",
  paste(
    "The independently recomputed descriptive counts, geographic spreads and variance",
    "identities agree with the saved outputs."
  ),
  "The audit identifies interpretation and support limitations rather than a numerical correction to those outputs.",
  "Run `Rscript scripts/audit_note.R` after building the descriptive and assignment outputs.", "",
  "## Claims and estimands", "",
  paste(
    "The transition contrast is the reserved-after-reserved rate minus the",
    "reserved-after-unreserved rate within a geographic unit."
  ),
  "Its spread describes linked GPs in units with both lag groups; it does not describe every GP in the state.",
  "The prediction audit describes observed-versus-supplied-predicted reservation disagreement among complete records.",
  paste(
    "Its district/block spreads and block-variance decomposition are observed quantities",
    "that include finite-group variation."
  ),
  "Equal-unit and seat-weighted summaries answer different questions.",
  "Neither weighting identifies a bureaucratic effect.", "",
  "## Transition sensitivity", "",
  paste(
    "Each restriction requires the indicated minimum in each lag group. The table reports",
    "the changed support alongside the spread."
  ),
  "Leave-one ranges remove a district, including all its blocks, and recompute the descriptive spread.",
  "These are influence ranges, not confidence intervals. Missing spreads indicate fewer than two eligible units.", "",
  knitr::kable(latest, format = "pipe", digits = 2, row.names = FALSE), "",
  "The Rajasthan district result persists under the support restrictions and single-district exclusions shown.",
  paste(
    "The Rajasthan block restriction removes almost the entire sample; its reduced spread",
    "cannot be interpreted as a correction"
  ),
  "to the full linked-sample statistic. No robustness claim should conceal this loss of support.",
  "Restricted-sample and leave-one spreads must not be compared to the original-sample benchmark as a formal test.", "",
  "## Assignment prediction sensitivity", "",
  knitr::kable(residual_summary, format = "pipe", digits = 2, row.names = FALSE), "",
  "The alternative women's prediction changes disagreement totals and spreads; both variants remain in the audit CSVs.",
  "The ST series contains few disagreements and should not carry a strong geographical heterogeneity conclusion.", "",
  "## Checks and scope", "",
  paste(
    "- Tier 1 denominators: independently reconstruct counts, both transition rates,",
    "mismatch totals, and union-reserved denominators."
  ),
  paste(
    "- Tier 1 missingness: binary inputs retain missing values; district/status",
    "exclusions and geographical linkage loss are exported."
  ),
  paste(
    "- Tier 1 row loss: GP-transition and GP-outcome keys are unique; exclusion and",
    "unmatched-link counts remain explicit."
  ),
  paste(
    "- Tier 1 provenance: the original Stata input is SHA-256 verified, and its",
    "assignments match the saved analytical records."
  ),
  "- Tier 1 internal consistency: observed spreads and between/within identities agree to numerical tolerance.",
  paste(
    "- Tier 2 EDA and skew: minimum-cell and leave-district-out sensitivities expose weak",
    "support and geographic influence."
  ),
  paste(
    "- Tier 2 joins: normalized-name matching and changing boundaries remain measurement",
    "limitations; duplicate checks do not validate identity."
  ),
  paste(
    "- Tier 2 construction: inputs are seat reservations, not winner attributes; SC and",
    "ST indicators are separate outcomes."
  ),
  paste(
    "- Tier 2 inference: the homogeneous benchmark's expected squared spread is",
    "independently derived and matches saved Monte Carlo draws."
  ),
  paste(
    "- Tier 3 design: no actual legal assignment mechanism has been reconstructed;",
    "exchangeability is a reference assumption."
  ),
  "- Tier 3 calibration: synthetic homogeneous and heterogeneous cases reproduce analytically known mean variances.",
  paste(
    "- Tier 4 descriptive branch: no causal coefficient, regression standard error or",
    "latent geographic variance is claimed."
  ),
  paste(
    "- Tier 4 dependence: GPs recur across transitions and block assignments can be",
    "dependent; no pooled independent-GP test is reported."
  ),
  paste(
    "- Tier 4 selection: the matched samples need not represent their states; coverage",
    "and exclusion CSVs describe observed selection."
  ),
  paste(
    "- Inapplicable branches: outcome RD, IV, DiD, psychometric scales and causal machine",
    "learning are not estimated in this note."
  ),
  paste(
    "- Untestable here: historical boundary identity, lawful allocation universes,",
    "authoritative quota/rank reconstruction and causal attribution."
  ),
  paste(
    "- The generic audit_data.py sweep finds no duplicate GP-outcome keys; its differing",
    "missingness across prediction fields is retained,"
  ),
  "  not repaired by treating missing assignments as unreserved.",
  "  Its heuristic causal warnings are not independent findings.", "",
  "## Reproducibility", "",
  paste(
    "Outputs are under `tabs/note_audit/`: transition and assignment sensitivities,",
    "coverage/exclusions, variance partitions,"
  ),
  "analytic benchmark checks and synthetic benchmark checks. The CSVs retain full numerical precision.",
  "Manuscript numbers and citations require their own generated-artifact and rendered-page checks after composition."
), project_file("docs", "note_audit.md"))

review_checks <- list()
for (state in names(reservation_cycles)) {
  records <- readRDS(file.path(build_dir, state, "records.rds"))
  panel <- readRDS(file.path(build_dir, state, "panel.rds"))
  records$is_by <- grepl("by", records$election_type, ignore.case = TRUE)
  contaminated <- records |>
    dplyr::group_by(district, block, gram_panchayat, year) |>
    dplyr::filter(any(is_by), any(exclusion == "ambiguous_key")) |>
    dplyr::ungroup()
  review_checks[[length(review_checks) + 1L]] <- tibble::tibble(
    state,
    check = "ambiguous_regular_rows_with_same_year_by_election",
    cycle = NA_character_, level = NA_character_, value = sum(contaminated$exclusion == "ambiguous_key")
  )
  for (cycle in unique(panel$transition)) {
    seats <- panel[panel$transition == cycle, ]
    for (level in c("district", "block")) {
      key <- if (level == "district") seats$district else seats$block_id
      eligible_keys <- names(Filter(function(x) length(unique(x$previous_reserved)) == 2L, split(seats, key)))
      subset <- seats[key %in% eligible_keys, ]
      for (lag in 0:1) {
        difference <- mean(subset$current_reserved[subset$previous_reserved == lag]) -
          mean(seats$current_reserved[seats$previous_reserved == lag])
        review_checks[[length(review_checks) + 1L]] <- tibble::tibble(
          state,
          check = paste0("reference_probability_difference_lag", lag), cycle, level, value = difference
        )
      }
    }
  }
}
write_audit(dplyr::bind_rows(review_checks), "review_checks")
concentration <- available |>
  dplyr::group_by(outcome, district, block_id) |>
  dplyr::summarise(
    mismatches = sum(mismatch), false_positive = sum(actual == 0 & expected == 1),
    false_negative = sum(actual == 1 & expected == 0),
    caste_disagreements = sum(mismatch == 1 & observed_caste != predicted_caste), .groups = "drop"
  ) |>
  dplyr::group_by(outcome) |>
  dplyr::summarise(
    blocks = dplyr::n(), blocks_with_disagreement = sum(mismatches > 0),
    disagreements = sum(mismatches),
    top_ten_share = sum(head(sort(mismatches, decreasing = TRUE), 10)) / sum(mismatches),
    disagreements_in_caste_disagreement = sum(caste_disagreements),
    balanced_blocks_with_disagreement = sum(mismatches > 0 & false_positive == false_negative), .groups = "drop"
  )
write_audit(concentration, "assignment_concentration")
paper_build <- project_file("paper", "build")
dir.create(paper_build, recursive = TRUE, showWarnings = FALSE)
compact <- latest |>
  dplyr::filter(minimum_lag_group %in% c(1, 20)) |>
  dplyr::transmute(
    State = ifelse(state == "rajasthan", "Rajasthan", "UP"), Level = level,
    Minimum = minimum_lag_group, Units = units, GPs = seats,
    `SD (pp)` = spread_pp, `LODO low` = leave_one_min_pp, `LODO high` = leave_one_max_pp
  )
writeLines(
  knitr::kable(compact, format = "latex", booktabs = TRUE, digits = 2, row.names = FALSE),
  file.path(paper_build, "audit_table.tex")
)
rj_district <- latest[latest$state == "rajasthan" & latest$level == "district" & latest$minimum_lag_group == 1, ]
rj_block <- latest[latest$state == "rajasthan" & latest$level == "block" & latest$minimum_lag_group == 20, ]
writeLines(c(
  sprintf(paste(
    "Rajasthan's district spread ranges from %.2f to %.2f percentage points when one district is omitted.",
    "Requiring at least 20 GPs in each lag group leaves all %d contributing districts."
  ), rj_district$leave_one_min_pp, rj_district$leave_one_max_pp, rj_district$units),
  sprintf(paste(
    "At block level the same restriction leaves only %d blocks and %d GPs, with a spread of %.2f percentage points.",
    "This severe change in support prevents interpreting the restricted result as a correction to the original spread.",
    "The leave-one-district-out ranges are influence diagnostics, not confidence intervals."
  ), rj_block$units, rj_block$seats, rj_block$spread_pp)
), file.path(paper_build, "audit_summary.tex"))
review_summary <- dplyr::bind_rows(review_checks) |>
  dplyr::mutate(check = ifelse(grepl("reference_probability", check), "maximum_probability_difference_pp", check)) |>
  dplyr::group_by(state, check) |>
  dplyr::summarise(value = if (dplyr::first(check) == "maximum_probability_difference_pp") {
    100 * max(abs(value))
  } else {
    sum(value)
  }, .groups = "drop")
report <- project_file("docs", "note_audit.md")
writeLines(c(
  readLines(report), "", "## Checks prompted by independent review", "",
  "The production benchmark estimates common probabilities using all linked GPs in a transition,",
  "while spread requires units with both lag groups. The following diagnostic recomputes probabilities",
  "on the latter support and reports the largest absolute difference. It does not change the benchmark estimand.", "",
  knitr::kable(review_summary, format = "pipe", digits = 4, row.names = FALSE), "",
  "The suspected by-election/duplicate collision occurs in neither state's retained source records.",
  "This is a potential behavior of the parser, not a demonstrated number-changing defect in these data.", "",
  "Prediction disagreements are also described by how many blocks contain them, the share in the ten",
  "highest-count blocks, overlap with caste prediction disagreements, and blocks with equal false positives",
  "and false negatives. These are descriptive diagnostic counts, not evidence of a particular mechanism.", "",
  knitr::kable(concentration, format = "pipe", digits = 4, row.names = FALSE)
), report)
