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
version_labels <- c(
  e_dunning2013 = "2012 manuscript", e_weaver2024 = "2023 working paper",
  e_soodquota = "Undated manuscript", quota_spending_ms = "2026 manuscript",
  quota_spending_si = "2026 supplement", beaman_duflo_pande_topalova_2012_science_som = "Supplement",
  ban_rao_2007_wp = "2007 working paper", bose_das_2014_draft = "2014 working paper",
  deininger_jin_nagarajan_singh_2020_wb_wps9350 = "2020 working paper",
  deininger_jin_nagarajan_singh_2022_jds_manuscript = "2022 manuscript"
)
joined$paper_version <- unname(version_labels[joined$source_id])
joined$paper_version[is.na(joined$paper_version)] <- ""
page_locator <- function(printed, pdf, section) {
  printed <- stringr::str_extract(printed, "^[0-9]+(?:[–,-]+[0-9]+)*")
  pdf <- stringr::str_extract(pdf, "^[0-9]+(?:[–,-]+[0-9]+)*")
  dplyr::case_when(
    !is.na(printed) & !is.na(pdf) & printed != pdf ~ paste0("p. ", printed, " (PDF p. ", pdf, ")"),
    !is.na(printed) ~ paste0("p. ", printed),
    !is.na(pdf) ~ paste0("PDF p. ", pdf),
    TRUE ~ section
  )
}
joined$locator <- page_locator(joined$printed_page, joined$pdf_page, joined$section)
link_urls <- ifelse(!is.na(joined$pdf_url) & nzchar(joined$pdf_url), joined$pdf_url, joined$url)
link_labels <- ifelse(grepl("[.]pdf|type=pdf", link_urls, ignore.case = TRUE), "PDF", "Source")
link_labels[grepl("doi.org", link_urls)] <- "Article"
link_labels[joined$source_id %in% c("ban_rao_2007_wp", "deininger_jin_nagarajan_singh_2022_jds_manuscript")] <-
  "Published version"
no_public_source <- c(
  "quota_spending_ms", "quota_spending_si", "goyal_mohapatra_2026_draft",
  "huidobro_prillaman_singhania_2026_draft"
)
link_urls[!grepl("^https://", link_urls) | joined$source_id %in% no_public_source] <- ""
pdf_start <- stringr::str_extract(joined$pdf_page, "^[0-9]+")
has_page <- nzchar(link_urls) & link_labels == "PDF" & !is.na(pdf_start)
link_urls[has_page] <- paste0(sub("#.*$", "", link_urls[has_page]), "#page=", pdf_start[has_page])
link_tokens <- ifelse(nzchar(link_urls), paste0("SOURCELINKTOKEN", seq_len(nrow(joined)), "END"), "")
joined$source_link <- link_tokens
latex_url <- function(url) {
  for (character in c("%", "#", "&", "_")) url <- gsub(character, paste0("\\", character), url, fixed = TRUE)
  url
}
resolve_tokens <- function(output) {
  for (i in seq_along(keys)) {
    output <- gsub(paste0("CITATIONTOKEN", i, "END"), paste0("\\citet{", keys[i], "}"), output, fixed = TRUE)
  }
  for (i in which(nzchar(link_urls))) {
    output <- gsub(link_tokens[i], paste0("\\href{", latex_url(link_urls[i]), "}{", link_labels[i], "}"),
      output,
      fixed = TRUE
    )
  }
  output
}
render_table <- function(data, file, widths, caption = NULL, label = NULL) {
  output <- knitr::kable(data,
    format = "latex", booktabs = TRUE, longtable = TRUE,
    row.names = FALSE, align = paste0("p{", widths, "cm}"), caption = caption, label = label
  )
  output <- kableExtra::kable_styling(output, latex_options = "repeat_header")
  writeLines(resolve_tokens(output), file.path(build, file))
}
# The paper shows substantive descriptions; the full provenance remains in the inventory.
joined$paper_qualification <- joined$qualification
joined$paper_qualification[joined$claim_id == "a_038"] <- paste(
  "Agreement can be checked against the authors' predictions. An independent reconstruction also needs",
  "the historical population inputs, eligible pools, rounding rules and boundary definitions."
)
joined$paper_qualification <- gsub(
  "source-to-panel identity", "district identity", joined$paper_qualification,
  fixed = TRUE
)
main_ids <- c(
  "a_028", "a_029", "e_chauchard_rank", "e_dunning_rank", "e_das_obc_lottery",
  "e_beaman_systematic", "e_beaman_repeat", "a_021", "e_sood_no_repeat", "e_sood_qualification",
  "a_038", "b_010", "b_027"
)
stopifnot(all(main_ids %in% joined$claim_id))
selected <- joined |>
  dplyr::filter(claim_id %in% main_ids) |>
  dplyr::arrange(match(claim_id, main_ids))
stopifnot(all(nzchar(selected$quote)), all(nzchar(selected$locator)))
main_settings <- c(
  chattopadhyay_duflo_2004_ecta = "West Bengal and Rajasthan; women",
  e_chauchard2014 = "Rajasthan, 2005; SC",
  e_dunning2013 = "Rajasthan, 1995–2010, and Bihar; SC",
  e_das2023 = "Rajasthan, 2010; OBC",
  e_beaman2009 = "West Bengal, 1998 and 2003; women",
  bose_das_2018_rde = "Uttar Pradesh, 2005 and 2010; women",
  e_soodquota = "Rajasthan and Uttar Pradesh; women",
  chaturvedi_das_mahajan_2025_edcc = "Uttar Pradesh, 2015; women",
  gajwani_zhang_2008_ifpri_dp807 = "Tamil Nadu, 1996–2006; women and SC",
  nilekani_2010_yale_senior_essay = "Karnataka, through 2009; general-category women"
)
main_context <- c(
  chattopadhyay_duflo_2004_ecta = paste(
    "The first passage concerns reconstruction of the West Bengal list; the second concerns missing inputs",
    "for Rajasthan. Successful reconstruction in one state does not verify implementation in the other."
  ),
  e_chauchard2014 = paste(
    "SC reservation follows a rotating population-share ranking. The study covers 64 GPs in 16 Samitis",
    "across four districts; it does not audit implementation statewide."
  ),
  e_dunning2013 = paste(
    "The inspected 2012 manuscript describes population totals, whereas Chauchard describes shares.",
    "The applicable input must be established for the election being studied."
  ),
  e_das2023 = paste(
    "The lottery operates among GPs remaining after SC/ST allocation. Its eligible pool differs from",
    "all GPs; the random-assignment argument is conditional on that prior allocation."
  ),
  e_beaman2009 = paste(
    "The authors report exact reconstruction of the 2003 list. Their rule also permits consecutive",
    "women's reservation when caste-specific lists change. Repetition alone need not violate rotation."
  ),
  bose_das_2018_rde = paste(
    "Changes between unreserved and caste-reserved lists can produce consecutive women's reservations",
    "under the described serial-number procedure. A categorical no-repeat test would miss this qualification."
  ),
  e_soodquota = paste(
    "The manuscript states a no-repeat premise but also cautions against treating district-level",
    "nonrejection as proof of random assignment. Neither statement independently establishes the legal procedure."
  ),
  chaturvedi_das_mahajan_2025_edcc = paste(
    "The authors report predicting female reservation in almost 98% of GPs. High overall agreement leaves",
    "the location and concentration of disagreements open; prediction errors need not be administrative departures."
  ),
  gajwani_zhang_2008_ifpri_dp807 = paste(
    "Reported block-average errors are 27.3% for women and 39.1% for SC reservation. The denominator is",
    "reserved GPs failing a rank threshold, rather than all GPs."
  ),
  nilekani_2010_yale_senior_essay = paste(
    "Discrepant allocation lists are excluded from the analysis. Results for the retained RD sample",
    "cannot establish the extent or consequences of excluded deviations; lobbying is considered but not established."
  )
)
stopifnot(all(selected$source_id %in% names(main_settings)), all(selected$source_id %in% names(main_context)))
main <- selected |>
  dplyr::group_by(source_id) |>
  dplyr::summarise(
    order = min(match(claim_id, main_ids)),
    Study = paste(
      citation_token(dplyr::first(bib_key)), dplyr::first(paper_version),
      main_settings[dplyr::first(source_id)],
      sep = ". "
    ),
    Passage = paste(paste0("“", quote, "” (", locator, "). ", source_link), collapse = " "),
    Context = unname(main_context[dplyr::first(source_id)]),
    .groups = "drop"
  ) |>
  dplyr::arrange(order) |>
  dplyr::mutate(Study = gsub(". . ", ". ", Study, fixed = TRUE)) |>
  dplyr::select(`Study and setting` = Study, `Quoted passage` = Passage, `Evidence and qualification` = Context)
render_table(main, "claims_comparison.tex", c(3.4, 4.9, 6.4),
  caption = "Claims about reservation assignment", label = "assignment_claims"
)
legal <- joined |>
  dplyr::filter(grepl("legal|prescri|constitutional", claim_kind, ignore.case = TRUE)) |>
  dplyr::transmute(
    Provision = paste(citation_token(bib_key), section, locator, source_link, sep = "; "),
    `Quoted wording and scope` = ifelse(nzchar(quote), paste0("“", quote, "” ", paraphrase), paraphrase),
    `Applicability and qualifications` = paper_qualification
  )
render_table(legal, "legal_comparison.tex", c(3.8, 5.4, 5.5))
cat(nrow(sources), "sources screened;", nrow(claims), "claims retained;", nrow(main), "main-table entries rendered\n")
priority <- joined |>
  dplyr::filter(readiness == "testable_with_current_data") |>
  dplyr::transmute(
    Claim = gsub("_", "-", claim_id), Source = bib_key, Implication = implication,
    `Contradictory observation` = contradiction, `Required inputs` = required_inputs
  )
writeLines(c(
  "# Assignment-claim inventory", "",
  paste(nrow(sources), "source versions screened;", nrow(claims), "distinct claim records."), "",
  "The source of truth is data/reference/assignment_claims/*.json. PDFs remain in the upstream collections.",
  "Run make claims to validate corpus coverage, source hashes, keys and claim fields; make paper compiles it.",
  "The main quotation table and official-provision appendix share these records.", "",
  paste(nrow(main), "study/version entries appear in the main quotation table."),
  "Official quotations appear in the legal-provision table. The full audit remains here, outside the paper.",
  "Selection covers lottery, ranking, rotation, reconstruction and documented discrepancies, with qualifications.",
  "The full extraction inventory remains available here; there is no overlapping literature table in the appendix.",
  "Printed page numbers and PDF page numbers are distinguished; direct document links include PDF page anchors.", "",
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
