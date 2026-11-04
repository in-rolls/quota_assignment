source("scripts/load_project.R")
claim_dir <- project_file("data", "reference", "assignment_claims")
files <- list.files(claim_dir, pattern = "[.]json$", full.names = TRUE)
if (length(files) != 3L) stop("Expected three source extraction files")
records <- lapply(files, jsonlite::read_json, simplifyVector = TRUE)
sources <- dplyr::bind_rows(lapply(records, `[[`, "sources"))
claims <- dplyr::bind_rows(lapply(records, `[[`, "claims"))
stopifnot(!anyDuplicated(sources$source_id), !anyDuplicated(claims$claim_id))
if (!all(claims$source_id %in% sources$source_id)) stop("Unknown claim source")
readiness <- c(
  "testable_with_current_data", "requires_additional_inputs", "outside_current_coverage",
  "insufficiently_specified"
)
if (!all(claims$readiness %in% readiness)) stop("Unknown test readiness")
required <- c(
  "state", "years", "office", "category", "pool", "procedure", "claim_kind", "paraphrase",
  "qualification", "evidence_basis", "implication", "contradiction", "required_inputs", "section"
)
for (field in required) {
  if (any(is.na(claims[[field]]) | !nzchar(claims[[field]]))) stop("Missing claim field: ", field)
}
in_rolls <- Sys.getenv("IN_ROLLS", dirname(project_root))
pdfs <- list.files(file.path(in_rolls, "quota_spending", "lit", "papers"), pattern = "[.]pdf$", full.names = FALSE)
if (!length(pdfs)) stop("Upstream quota_spending literature corpus not found")
if (!all(pdfs %in% basename(sources$path))) stop("Unscreened corpus PDFs")
study_files <- list.files(file.path(in_rolls, "quota_spending", "lit", "studies"),
  pattern = "[.]yaml$", full.names = TRUE
)
study_pdfs <- vapply(study_files, function(file) {
  line <- grep("^pdf:", readLines(file, warn = FALSE), value = TRUE)
  if (length(line) != 1L) stop("Missing or ambiguous PDF in ", file)
  trimws(sub("^pdf:", "", line))
}, character(1))
if (!all(study_pdfs %in% basename(sources$path))) stop("Unscreened study entry")
if (!all(sources$screening_status %in% c("claims_found", "no_assignment_claim", "inaccessible"))) {
  stop("Unknown screening status")
}
for (i in seq_len(nrow(sources))) {
  path <- file.path(in_rolls, sources$path[i])
  if (nzchar(sources$path[i]) && file.exists(path)) {
    if (digest::digest(file = path, algo = "sha256") != sources$sha256[i]) stop("Source changed: ", path)
  }
}
joined <- dplyr::left_join(claims, sources, by = "source_id", relationship = "many-to-one")
bib_files <- project_file("paper", c("references.bib", "claims_a.bib", "claims_b.bib", "claims_external.bib"))
bib_text <- paste(unlist(lapply(bib_files[file.exists(bib_files)], readLines)), collapse = "\n")
keys <- stringr::str_match_all(bib_text, "@[A-Za-z]+\\{([^,]+),")[[1]][, 2]
if (anyDuplicated(keys)) stop("Duplicate bibliography keys")
if (!all(sources$bib_key %in% keys)) {
  stop("Missing bibliography keys: ", paste(setdiff(sources$bib_key, keys), collapse = ", "))
}
build <- project_file("paper", "build")
dir.create(build, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(sources, file.path(build, "claim_sources.csv"))
readr::write_csv(joined, file.path(build, "assignment_claims.csv"))
citation_token <- function(key) paste0("CITATIONTOKEN", match(key, keys), "END")
render_table <- function(data, file, widths) {
  output <- knitr::kable(data,
    format = "latex", booktabs = TRUE, longtable = TRUE,
    row.names = FALSE, align = paste0("p{", widths, "cm}")
  )
  output <- kableExtra::kable_styling(output, latex_options = "repeat_header")
  for (i in seq_along(keys)) {
    output <- gsub(paste0("CITATIONTOKEN", i, "END"), paste0("\\citealp{", keys[i], "}"), output, fixed = TRUE)
  }
  writeLines(output, file.path(build, file))
}
# Selected contrasts keep scope and qualifications visible in the research note.
main_ids <- c(
  "a_027", "a_029", "e_chauchard_rank", "e_dunning_rank", "e_dunning_balance",
  "a_021", "a_022", "e_das_sc_st_rank", "e_das_obc_lottery", "a_037", "a_038",
  "b_010", "b_011", "b_041", "b_045", "b_046", "e_sood_no_repeat"
)
stopifnot(all(main_ids %in% joined$claim_id))
main <- joined |>
  dplyr::filter(claim_id %in% main_ids) |>
  dplyr::arrange(match(claim_id, main_ids)) |>
  dplyr::transmute(
    Source = paste0(citation_token(bib_key), "; ", version, " [", claim_id, "]"),
    Scope = paste(state, years, office, category, sep = "; "),
    `Claim and qualification` = paste(paraphrase, "Qualification:", qualification)
  )
render_table(main, "claims_comparison.tex", c(3.1, 4.1, 7.5))
legal <- joined |>
  dplyr::filter(grepl("legal|prescri|constitutional", claim_kind, ignore.case = TRUE)) |>
  dplyr::transmute(
    Source = paste(citation_token(bib_key), section, sep = ": "),
    `Provision and scope` = paste(paraphrase, state, years, sep = " "),
    `Applicability and qualifications` = qualification
  )
render_table(legal, "legal_comparison.tex", c(3.1, 6.1, 5.5))
render_table(
  sources |>
    dplyr::transmute(
      Source = citation_token(bib_key), Version = version,
      Status = gsub("_", " ", screening_status), Note = screening_note
    ),
  "claims_screening.tex", c(3, 3.2, 2.5, 6)
)
lines <- c(
  "\\section{Located claim records}",
  "Each record preserves the source's scope and qualifications. Readiness describes a future comparison, not a verdict."
)
fields <- c(
  "quote", "paraphrase", "state", "years", "office", "category", "pool", "procedure", "claim_kind",
  "qualification", "evidence_basis", "cited_origin", "implication", "contradiction", "required_inputs", "readiness"
)
for (i in seq_len(nrow(joined))) {
  row <- joined[i, ]
  labels <- stringr::str_to_sentence(gsub("_", " ", fields))
  data <- tibble::tibble(Field = labels, Record = vapply(fields, function(name) row[[name]], character(1)))
  fragment <- knitr::kable(data,
    format = "latex", booktabs = TRUE, longtable = TRUE,
    row.names = FALSE, align = c("p{3cm}", "p{11.7cm}")
  )
  fragment <- kableExtra::kable_styling(fragment, latex_options = "repeat_header")
  lines <- c(
    lines, paste0("\\subsection{Claim ", gsub("_", "-", row$claim_id), "}"),
    paste0("Source: \\citet{", row$bib_key, "}. "),
    knitr::kable(tibble::tibble(
      Version = row$version, `PDF page` = row$pdf_page, `Printed page` = row$printed_page, Section = row$section
    ), format = "latex", booktabs = TRUE, row.names = FALSE, align = c("p{4.1cm}", "p{2.2cm}", "p{2.2cm}", "p{6.2cm}")),
    "", fragment, ""
  )
}
writeLines(lines, file.path(build, "claims_records.tex"))
cat(nrow(sources), "sources screened;", nrow(claims), "claims rendered\n")

priority <- joined |>
  dplyr::filter(readiness == "testable_with_current_data") |>
  dplyr::transmute(
    Claim = gsub("_", "-", claim_id), Source = citation_token(bib_key), Implication = implication,
    `Contradictory observation` = contradiction, `Required inputs` = required_inputs
  )
render_table(priority, "claims_next_tests.tex", c(2, 2.3, 3.3, 3.3, 3.3))
writeLines(c(
  "# Assignment-claim inventory", "",
  paste(nrow(sources), "source versions screened;", nrow(claims), "distinct claim records."), "",
  "The source of truth is data/reference/assignment_claims/*.json. PDFs remain in the upstream collections.",
  "Run make claims to validate corpus coverage, source hashes, keys and claim fields; make paper compiles it.",
  "The note's comparison, official-provision table and claim appendix share these records.", "",
  "Readiness is a proposed comparison, not a finding that the claim is wrong. State, period, office and category",
  "must match; absent historical rosters or rules remain explicit requirements.", "",
  "Some conference drafts have no verified public URL or request noncirculation. Their screening notes",
  "retain that status; they are not used in the main comparison and have no reproduced quotations.", "",
  "## Source coverage", "",
  as.character(knitr::kable(dplyr::count(sources, screening_status), format = "pipe")), "",
  "## Candidate next tests", "", as.character(knitr::kable(
    dplyr::mutate(priority, Source = joined$bib_key[match(Claim, gsub("_", "-", joined$claim_id))]),
    format = "pipe"
  ))
), project_file("docs", "assignment_claims.md"))
