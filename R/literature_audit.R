read_literature_inputs <- function(reference_dir) {
  schema <- jsonlite::read_json(file.path(reference_dir, "literature_audit", "schema.json"))
  tables <- lapply(names(schema), function(name) {
    fields <- schema[[name]]
    types <- lapply(fields, function(field) {
      switch(field$type,
        character = readr::col_character(),
        integer = readr::col_integer(),
        double = readr::col_double(),
        stop("Unknown schema type")
      )
    })
    data <- readr::read_csv(file.path(reference_dir, "literature_audit", paste0(name, ".csv")),
      col_types = do.call(readr::cols, types), na = "", show_col_types = FALSE
    )
    if (!identical(names(data), names(fields)) || nrow(readr::problems(data))) stop("Schema mismatch: ", name)
    data
  })
  names(tables) <- names(schema)
  files <- sort(list.files(file.path(reference_dir, "assignment_claims"), "[.]json$", full.names = TRUE))
  records <- lapply(files, jsonlite::read_json, simplifyVector = TRUE)
  tables$sources <- dplyr::bind_rows(lapply(records, `[[`, "sources"))
  tables$claims <- dplyr::bind_rows(lapply(records, `[[`, "claims"))
  tables
}

require_unique_key <- function(data, columns, name) {
  key <- data[columns]
  if (anyNA(key) || anyDuplicated(key)) stop("Missing or duplicate key in ", name)
}

require_values <- function(values, choices, name) {
  if (anyNA(values) || !all(values %in% choices)) stop("Invalid values in ", name)
}

validate_literature_inputs <- function(input) {
  keys <- list(
    studies = "study_id", source_studies = "source_id", reviews = "study_id",
    diagnostics = "diagnostic_id", accounts = "account_id", sources = "source_id", claims = "claim_id",
    diagnostic_capabilities = c("diagnostic_type", "target"),
    claim_support = c("claim_id", "supporting_claim_id", "support_type")
  )
  for (name in names(keys)) require_unique_key(input[[name]], keys[[name]], name)
  if (!setequal(input$sources$source_id, input$source_studies$source_id)) stop("Source mapping is incomplete")
  if (!setequal(input$studies$study_id, input$reviews$study_id)) stop("Study reviews are incomplete")
  if (!setequal(input$studies$study_id, input$source_studies$study_id)) stop("Study mapping is incomplete")
  if (!all(input$claims$source_id %in% input$sources$source_id)) stop("Unknown claim source")
  if (!all(c(input$diagnostics$claim_id, input$accounts$claim_id) %in% input$claims$claim_id)) {
    stop("Unknown evidence claim")
  }
  if (!all(input$diagnostics$diagnostic_type %in% input$diagnostic_capabilities$diagnostic_type)) {
    stop("Unknown diagnostic type")
  }
  if (!all(c(input$claim_support$claim_id, input$claim_support$supporting_claim_id) %in% input$claims$claim_id)) {
    stop("Unknown support claim")
  }
  require_values(
    input$claim_support$support_type,
    c("own_diagnostic", "prior_study", "legal_text", "institutional_argument"), "support type"
  )
  require_values(input$claim_support$target, c("procedure", "identification"), "support target")
  claim_studies <- input$claims |>
    dplyr::left_join(input$source_studies, by = "source_id", relationship = "many-to-one")
  own <- input$claim_support[input$claim_support$support_type == "own_diagnostic", ]
  own_left <- claim_studies[match(own$claim_id, claim_studies$claim_id), ]
  own_right <- claim_studies[match(own$supporting_claim_id, claim_studies$claim_id), ]
  same_version <- own_left$source_id == own_right$source_id |
    (own_left$version_role != "earlier_version" & own_right$version_role != "earlier_version")
  invalid_own <- !own$supporting_claim_id %in% input$diagnostics$claim_id |
    own_left$study_id != own_right$study_id | !same_version
  if (any(invalid_own)) stop("Own diagnostic must reference the same study and compatible version")
  require_values(input$claim_support$coding_status, c("extracted", "rechecked"), "support coding status")
  require_unique_key(input$diagnostics, c("claim_id", "diagnostic_type"), "claim diagnostic")
  require_values(input$studies$inclusion, c("included", "excluded", "pending"), "inclusion")
  require_values(input$studies$family_status, c("provisional", "verified"), "family status")
  require_values(input$source_studies$version_role,
    c("primary", "linked_supplement", "earlier_version"), "version role"
  )
  primary <- input$source_studies |>
    dplyr::filter(version_role == "primary")
  require_unique_key(primary, "study_id", "primary sources")
  if (!setequal(primary$source_id, input$studies$primary_source_id)) stop("Primary source mismatch")
  if (any(primary$study_id != input$studies$study_id[match(primary$source_id, input$studies$primary_source_id)])) {
    stop("Primary source belongs to another study")
  }
  require_values(input$reviews$review_status, c("not_started", "in_progress", "complete"), "review status")
  require_values(input$reviews$main_text_status, c("extracted", "checked", "unavailable"), "main text status")
  require_values(
    input$reviews$supplement_status,
    c("not_checked", "checked", "none_verified", "unavailable"), "supplement status"
  )
  require_values(
    input$reviews$no_check_status,
    c("not_assessed", "check_reported", "no_check_reported"), "no-check status"
  )
  require_values(input$diagnostics$coding_status, c("extracted", "rechecked"), "diagnostic coding status")
  require_values(input$diagnostics$replication_status,
    c("not_attempted", "reproduced", "discrepancy"), "replication status"
  )
  if (any(input$diagnostics$sample_size < 1L | input$diagnostics$n_groups < 1L, na.rm = TRUE)) {
    stop("Diagnostic sample counts must be positive when known")
  }
  if (any(input$diagnostics$n_groups > input$diagnostics$sample_size, na.rm = TRUE)) {
    stop("Diagnostic groups exceed sample size")
  }
  if (any(input$diagnostics$reported_p_value < 0 | input$diagnostics$reported_p_value > 1, na.rm = TRUE)) {
    stop("Reported p-value must be between zero and one")
  }
  if (any(input$diagnostics$rejection_level <= 0 | input$diagnostics$rejection_level >= 1, na.rm = TRUE)) {
    stop("Rejection level must be strictly between zero and one")
  }
  require_values(input$diagnostic_capabilities$coverage, c("direct", "partial", "not_targeted"), "coverage")
  require_values(
    input$diagnostic_capabilities$target,
    c("geographic_heterogeneity", "serial_dependence", "algorithm_agreement"), "diagnostic target"
  )
  require_values(input$accounts$scope_status, c("provisional", "verified"), "account scope")
  if (any(input$accounts$cycle_start > input$accounts$cycle_end, na.rm = TRUE)) stop("Reversed election interval")
  review <- dplyr::left_join(input$reviews, input$studies, by = "study_id", relationship = "one-to-one")
  complete <- review$review_status == "complete"
  complete_documentation <- review$main_text_status == "checked" &
    review$supplement_status %in% c("checked", "none_verified") &
    review$family_status == "verified" & review$no_check_status != "not_assessed"
  if (any(complete & !complete_documentation)) {
    stop("Completed review lacks verified family, article, supplements or evidence decision")
  }
  if (any(review$no_check_status == "no_check_reported" & !complete)) stop("Negative finding requires complete review")
  evidence <- enrich_diagnostics(input)
  positive <- unique(evidence$study_id[evidence$version_role != "earlier_version"])
  if (any(review$study_id[review$no_check_status == "no_check_reported"] %in% positive)) {
    stop("Negative finding conflicts with a reported diagnostic")
  }
  if (!all(review$study_id[review$no_check_status == "check_reported"] %in% positive)) {
    stop("Positive review decision lacks a diagnostic record")
  }
  adjudications <- input$adjudications
  require_values(adjudications$status, c("candidate", "resolved_difference", "confirmed_disagreement"), "adjudication")
  require_values(adjudications$scope_review, c("pending", "complete"), "scope review")
  if (!all(c(adjudications$account_left, adjudications$account_right) %in% input$accounts$account_id)) {
    stop("Unknown adjudication account")
  }
  require_unique_key(canonicalize_pairs(adjudications), c("account_left", "account_right"), "adjudication pairs")
  pairs <- compare_assignment_accounts(input)
  confirmed <- pairs$status == "confirmed_disagreement"
  confirmed_scope <- pairs$scope_matches & pairs$scope_left == "verified" &
    pairs$scope_right == "verified" & pairs$scope_review == "complete"
  if (any(confirmed & !confirmed_scope)) stop("Confirmed disagreement lacks matching verified scope")
  for (name in c("studies", "reviews", "diagnostics", "accounts", "adjudications", "claim_support")) {
    data <- input[[name]]
    optional <- intersect(names(data), c(
      "cycle_start", "cycle_end", "sample_size", "n_groups", "reported_p_value", "rejection_level"
    ))
    if (anyNA(data[setdiff(names(data), optional)])) stop("Missing required annotation in ", name)
  }
  invisible(input)
}

canonicalize_pairs <- function(data) {
  left <- data$account_left
  data$account_left <- pmin(left, data$account_right)
  data$account_right <- pmax(left, data$account_right)
  data
}

enrich_diagnostics <- function(input) {
  input$diagnostics |>
    dplyr::left_join(input$claims, by = "claim_id", relationship = "many-to-one") |>
    dplyr::left_join(input$source_studies, by = "source_id", relationship = "many-to-one") |>
    dplyr::left_join(input$sources, by = "source_id", relationship = "many-to-one")
}

build_study_audit <- function(input) {
  evidence <- enrich_diagnostics(input)
  counts <- evidence |>
    dplyr::group_by(study_id) |>
    dplyr::summarise(
      diagnostic_records_all_versions = dplyr::n(),
      diagnostic_types_all_versions = dplyr::n_distinct(diagnostic_type),
      diagnostic_records_primary = sum(version_role != "earlier_version"),
      rechecked_records_primary = sum(version_role != "earlier_version" & coding_status == "rechecked"),
      .groups = "drop"
    )
  input$studies |>
    dplyr::left_join(input$reviews, by = "study_id", relationship = "one-to-one") |>
    dplyr::left_join(counts, by = "study_id", relationship = "one-to-one") |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(c(
        "diagnostic_records_all_versions", "diagnostic_types_all_versions",
        "diagnostic_records_primary", "rechecked_records_primary"
      )), ~ tidyr::replace_na(.x, 0L)),
      has_reported_check = dplyr::case_when(
        diagnostic_records_primary > 0 ~ TRUE,
        review_status == "complete" & no_check_status == "no_check_reported" ~ FALSE,
        TRUE ~ NA
      ),
      finding = dplyr::case_when(
        inclusion != "included" ~ paste0("scope_", inclusion),
        has_reported_check %in% TRUE ~ "reported_check_located",
        has_reported_check %in% FALSE ~ "no_check_reported_after_review",
        TRUE ~ "evidence_review_pending"
      )
    )
}

compare_assignment_accounts <- function(input, validate_adjudications = TRUE) {
  accounts <- input$accounts |>
    dplyr::left_join(dplyr::select(input$claims, claim_id, source_id), by = "claim_id", relationship = "many-to-one") |>
    dplyr::left_join(input$source_studies, by = "source_id", relationship = "many-to-one")
  if (nrow(accounts) < 2L) {
    return(tibble::tibble())
  }
  indices <- utils::combn(seq_len(nrow(accounts)), 2)
  left <- accounts[indices[1, ], ]
  right <- accounts[indices[2, ], ]
  same <- c("state", "office", "category", "component")
  comparable <- Reduce(`&`, lapply(same, function(field) left[[field]] == right[[field]])) &
    left$study_id != right$study_id & left$value != right$value
  known_years <- !is.na(left$cycle_start) & !is.na(left$cycle_end) &
    !is.na(right$cycle_start) & !is.na(right$cycle_end)
  overlaps <- !known_years | (left$cycle_start <= right$cycle_end & right$cycle_start <= left$cycle_end)
  pool_matches <- left$pool == right$pool & left$pool != "not_resolved"
  pairs <- tibble::tibble(
    account_left = left$account_id, account_right = right$account_id,
    scope_matches = known_years & overlaps & pool_matches,
    scope_left = left$scope_status, scope_right = right$scope_status
  )[comparable & overlaps, ]
  pairs <- canonicalize_pairs(pairs)
  # Scope status follows the canonical account order.
  pairs$scope_left <- accounts$scope_status[match(pairs$account_left, accounts$account_id)]
  pairs$scope_right <- accounts$scope_status[match(pairs$account_right, accounts$account_id)]
  judgments <- canonicalize_pairs(input$adjudications)
  if (validate_adjudications && nrow(dplyr::anti_join(judgments, pairs, by = c("account_left", "account_right")))) {
    stop("Adjudication does not reference a candidate comparison")
  }
  dplyr::left_join(pairs, judgments, by = c("account_left", "account_right"), relationship = "one-to-one") |>
    dplyr::mutate(
      status = tidyr::replace_na(status, "candidate"),
      scope_review = tidyr::replace_na(scope_review, "pending"),
      reason = tidyr::replace_na(reason, "Different accounts; scope and version reconciliation required.")
    )
}

summarise_literature_audit <- function(studies, pairs) {
  eligible <- studies[studies$inclusion == "included", ]
  reviewed <- eligible$review_status == "complete"
  negative <- sum(eligible$has_reported_check %in% FALSE)
  denominator <- sum(reviewed)
  corpus_complete <- denominator == nrow(eligible) && !any(studies$inclusion == "pending")
  tibble::tibble(
    included_families = nrow(eligible),
    verified_included_families = sum(eligible$family_status == "verified"),
    completed_reviews = denominator,
    studies_with_located_checks = sum(eligible$has_reported_check %in% TRUE),
    studies_with_no_reported_check = negative,
    studies_with_unknown_check_status = sum(is.na(eligible$has_reported_check)),
    no_check_share_reviewed = if (denominator > 0L) negative / denominator else NA_real_,
    no_check_share_all = if (corpus_complete && denominator > 0L) negative / denominator else NA_real_,
    candidate_pairs = sum(pairs$status == "candidate"),
    confirmed_disagreement_pairs = sum(pairs$status == "confirmed_disagreement")
  )
}
