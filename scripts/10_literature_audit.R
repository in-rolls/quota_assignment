source("scripts/load_project.R")
input <- read_literature_inputs(project_file("data", "reference"))
validate_literature_inputs(input)
studies <- build_study_audit(input)
pairs <- compare_assignment_accounts(input)
evidence <- enrich_diagnostics(input)
summary <- summarise_literature_audit(studies, pairs)
claims <- input$claims |>
  dplyr::left_join(input$source_studies, by = "source_id", relationship = "many-to-one") |>
  dplyr::left_join(input$sources, by = "source_id", relationship = "many-to-one")
accounts <- input$accounts |>
  dplyr::left_join(claims, by = "claim_id", suffix = c("_coded", "_source"), relationship = "many-to-one")
capabilities <- evidence |>
  dplyr::left_join(input$diagnostic_capabilities, by = "diagnostic_type", relationship = "many-to-many")
stopifnot(nrow(capabilities) == nrow(evidence) * 3L)
queue <- studies |>
  dplyr::filter(inclusion != "excluded", review_status != "complete") |>
  dplyr::select(
    study_id, title, inclusion, family_status, primary_source_id, main_text_status,
    supplement_status, diagnostic_records_primary, review_note
  )
methods <- evidence |>
  dplyr::filter(version_role != "earlier_version", study_id %in% studies$study_id[studies$inclusion == "included"]) |>
  dplyr::group_by(diagnostic_type) |>
  dplyr::summarise(
    studies_with_extracted_evidence = dplyr::n_distinct(study_id),
    studies_with_rechecked_evidence = dplyr::n_distinct(study_id[coding_status == "rechecked"]),
    .groups = "drop"
  ) |>
  dplyr::left_join(dplyr::distinct(input$diagnostic_capabilities, diagnostic_type, label),
    by = "diagnostic_type", relationship = "one-to-one"
  )
targets <- capabilities |>
  dplyr::filter(version_role != "earlier_version") |>
  dplyr::group_by(study_id, target) |>
  dplyr::summarise(
    located_coverage = dplyr::case_when(
      any(coverage == "direct") ~ "direct", any(coverage == "partial") ~ "partial", TRUE ~ "not_targeted"
    ),
    diagnostic_types = paste(sort(unique(diagnostic_type)), collapse = "; "), .groups = "drop"
  )
targets <- tidyr::expand_grid(study_id = studies$study_id, target = unique(input$diagnostic_capabilities$target)) |>
  dplyr::left_join(targets, by = c("study_id", "target"), relationship = "one-to-one") |>
  dplyr::mutate(located_coverage = tidyr::replace_na(located_coverage, "not_coded")) |>
  dplyr::left_join(dplyr::select(studies, study_id, inclusion, review_status),
    by = "study_id", relationship = "many-to-one"
  )
claim_queue <- claims |>
  dplyr::mutate(
    has_scoped_account = claim_id %in% input$accounts$claim_id,
    has_support_link = claim_id %in% input$claim_support$claim_id,
    has_diagnostic_record = claim_id %in% input$diagnostics$claim_id
  ) |>
  dplyr::select(
    study_id, source_id, claim_id, title, version, claim_kind, state, years, office, category,
    printed_page, pdf_page, has_scoped_account, has_support_link, has_diagnostic_record
  )
comparison_evidence <- dplyr::bind_rows(
  dplyr::mutate(pairs, side = "left", account_id = account_left),
  dplyr::mutate(pairs, side = "right", account_id = account_right)
) |>
  dplyr::left_join(accounts, by = "account_id", relationship = "many-to-one") |>
  dplyr::select(
    account_left, account_right, status, scope_review, side, study_id, source_id, claim_id,
    state_coded, cycle_start, cycle_end, office_coded, category_coded, pool_coded, component, value,
    title, version, quote, paraphrase, printed_page, pdf_page, url, reason
  )
output <- project_file("data", "build", "literature_audit")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(input, file.path(output, "filled_data.json"),
  pretty = TRUE, auto_unbox = TRUE, dataframe = "rows", na = "null", null = "null", digits = NA
)
products <- list(
  studies = studies, claims = claims, claim_support = input$claim_support, diagnostics = evidence, accounts = accounts,
  comparisons = pairs, diagnostic_targets = capabilities, study_targets = targets,
  review_queue = queue, claim_queue = claim_queue, comparison_evidence = comparison_evidence,
  methods = methods, summary = summary
)
for (name in names(products)) {
  path <- file.path(output, paste0(name, ".parquet"))
  arrow::write_parquet(products[[name]], path)
  stopifnot(isTRUE(all.equal(products[[name]], arrow::read_parquet(path), check.attributes = FALSE)))
}
readr::write_csv(queue, file.path(output, "review_queue.csv"), na = "")
readr::write_csv(pairs, file.path(output, "comparisons.csv"), na = "")
readr::write_csv(claim_queue, file.path(output, "claim_queue.csv"), na = "")
readr::write_csv(comparison_evidence, file.path(output, "comparison_evidence.csv"), na = "")
files <- c(
  list.files(project_file("data", "reference", "assignment_claims"), "[.]json$", full.names = TRUE),
  list.files(project_file("data", "reference", "literature_audit"), full.names = TRUE),
  project_file("R", "literature_audit.R"), project_file("scripts", "10_literature_audit.R")
)
manifest <- tibble::tibble(
  path = substring(files, nchar(project_root) + 2L),
  sha256 = vapply(files, function(path) digest::digest(file = path, algo = "sha256"), character(1))
)
readr::write_csv(manifest, file.path(output, "input_manifest.csv"))
flow <- dplyr::count(studies, inclusion, name = "study_families")
schema <- jsonlite::read_json(project_file("data", "reference", "literature_audit", "schema.json"))
dictionary <- dplyr::bind_rows(lapply(names(schema), function(table) {
  dplyr::bind_rows(lapply(names(schema[[table]]), function(column) {
    tibble::tibble(
      table = table, column = column, type = schema[[table]][[column]]$type,
      meaning = schema[[table]][[column]]$description, missing = sum(is.na(input[[table]][[column]]))
    )
  }))
}))
writeLines(c(
  "# Literature audit data dictionary", "",
  "CSV schemas are enforced by schema.json: character IDs/labels, integer counts/years and double probabilities.",
  "Blank fields are missing, never zero. Election bounds and diagnostic numbers may be unresolved or inapplicable.", "",
  as.character(knitr::kable(dictionary, format = "pipe"))
), project_file("docs", "literature_audit_dictionary.md"))
rate_note <- if (is.na(summary$no_check_share_all)) {
  "The no-check rate for the corpus is not yet estimable."
} else {
  sprintf("The completed-review no-check rate is %.1f percent.", 100 * summary$no_check_share_all)
}
methods_display <- dplyr::select(methods,
  Diagnostic = label, `Studies with extracted evidence` = studies_with_extracted_evidence,
  `Studies with rechecked passages` = studies_with_rechecked_evidence
)
report <- c(
  "# Literature evidence audit", "",
  "This is an initial coding dataset, not a completed review of the literature.", "",
  sprintf(
    "%s source versions map to %s study/source families; %s claims are retained without dropping context.",
    nrow(input$sources), nrow(studies), nrow(claims)
  ),
  sprintf(
    "%s families are included, %s excluded, and %s await a scope decision.",
    sum(studies$inclusion == "included"), sum(studies$inclusion == "excluded"), sum(studies$inclusion == "pending")
  ),
  sprintf(
    paste("%s positive diagnostic records are coded. %s eligible study families have a located check",
          "in the preferred source or its linked supplements."),
    nrow(evidence), summary$studies_with_located_checks
  ),
  sprintf("%s eligible studies have completed reviews. %s", summary$completed_reviews, rate_note), "",
  sprintf("%s of %s family mappings are verified; the remaining groupings are provisional.",
    sum(studies$family_status == "verified"), nrow(studies)
  ), "",
  "Evidence in an earlier draft is retained separately. Missing diagnostic records mean unknown, not no test.",
  "The preferred version may itself be a working paper; publication/version checks remain part of the review.", "",
  "## Scope and denominators", "", as.character(knitr::kable(flow, format = "pipe")), "",
  "The empirical denominator concerns designs using local reservation assignment. Legal provisions, reviews,",
  "state implementation timing and unrelated identification designs remain in the claims data but are excluded",
  "from that denominator. Family decisions and exclusions are explicit in the editable inputs.", "",
  "## Diagnostics located", "",
  "These counts describe positive extraction records, not exhaustive classifications. Methods overlap.",
  "A rechecked passage is not an independently reproduced empirical result.", "",
  as.character(knitr::kable(methods_display, format = "pipe")), "",
  "## Procedural comparisons", "",
  sprintf(
    "%s scoped accounts generate %s candidate pairs and %s recorded confirmed disagreements.",
    nrow(accounts), sum(pairs$status == "candidate"), sum(pairs$status == "confirmed_disagreement")
  ),
  "Account coding is incomplete. Zero confirmed disagreements is not evidence that the literature agrees.",
  "Differences are matched on state, office, category and procedural component. Nonoverlapping known election",
  "periods are excluded. Unknown periods or different pools remain candidates requiring scope reconciliation.",
  "Confirmation requires verified overlapping periods, matching pools, checked versions and a written adjudication.",
  "",
  "## What the diagnostics can detect", "",
  "The capability matrix records logical targets, not power or proof of validity. A paper can have several methods.",
  "The study-target output combines located methods without treating an unreviewed paper as having no other test.",
  "Paper-specific power against geographic heterogeneity requires its sample, statistic and assignment benchmark;",
  "no detection probability or fraction of inadequate papers is imputed from a method label.", "",
  "## Reproduce and extend", "",
  "Run `make literature`. Inputs are in `data/reference/literature_audit/`; original quotations and locators remain",
  "in `data/reference/assignment_claims/`. [Coding protocol and dictionary](literature_audit_protocol.md).", "",
  "Typed Parquet files, an input SHA-256 manifest, and editable-view CSV review queues are written to",
  "`data/build/literature_audit/`. Edit the reference coding sheets, never generated outputs.",
  "The manuscript's illustrative quotations are separate from this corpus-wide audit; no final prevalence",
  "estimate is inserted into the paper before the required reviews are completed."
)
writeLines(report, project_file("docs", "literature_audit.md"))
tex_data <- dplyr::select(methods,
  Diagnostic = label, `Studies with located evidence` = studies_with_extracted_evidence
)
tex <- knitr::kable(tex_data, format = "latex", booktabs = TRUE,
  caption = "Diagnostics located in the initial extraction; methods overlap."
)
dir.create(project_file("paper", "build"), recursive = TRUE, showWarnings = FALSE)
writeLines(kableExtra::kable_styling(tex), project_file("paper", "build", "literature_diagnostics.tex"))
print(summary, width = Inf)
