audit_inputs <- function() read_literature_inputs(file.path(root, "data", "reference"))

testthat::test_that("every source and claim survives the study mapping", {
  input <- audit_inputs()
  testthat::expect_silent(validate_literature_inputs(input))
  mapped <- dplyr::left_join(input$claims, input$source_studies, by = "source_id", relationship = "many-to-one")
  testthat::expect_equal(nrow(mapped), nrow(input$claims))
  testthat::expect_false(anyNA(mapped$study_id))
  input$source_studies <- input$source_studies[-1, ]
  testthat::expect_error(validate_literature_inputs(input), "Source mapping is incomplete")
})

testthat::test_that("duplicate versions do not become independent studies or negative evidence", {
  input <- audit_inputs()
  studies <- build_study_audit(input)
  testthat::expect_equal(nrow(studies), dplyr::n_distinct(input$source_studies$study_id))
  testthat::expect_true(all(is.na(studies$has_reported_check[studies$diagnostic_records_primary == 0])))
  earlier_only <- studies$diagnostic_records_all_versions > 0 & studies$diagnostic_records_primary == 0
  testthat::expect_true(any(earlier_only))
  testthat::expect_true(all(is.na(studies$has_reported_check[earlier_only])))
  summary <- summarise_literature_audit(studies, compare_assignment_accounts(input))
  testthat::expect_true(is.na(summary$no_check_share_all))
  testthat::expect_true(is.na(summary$no_check_share_reviewed))
})

testthat::test_that("an absence finding requires complete article and supplement review", {
  input <- audit_inputs()
  study <- build_study_audit(input)
  id <- study$study_id[which(study$diagnostic_records_primary == 0 & study$inclusion == "included")[1]]
  index <- match(id, input$reviews$study_id)
  input$reviews$no_check_status[index] <- "no_check_reported"
  testthat::expect_error(validate_literature_inputs(input), "Negative finding requires complete review")
  input$reviews$review_status[index] <- "complete"
  input$reviews$main_text_status[index] <- "checked"
  input$studies$family_status[input$studies$study_id == id] <- "verified"
  testthat::expect_error(validate_literature_inputs(input), "Completed review lacks")
  input$reviews$supplement_status[index] <- "none_verified"
  testthat::expect_silent(validate_literature_inputs(input))
  study <- build_study_audit(input)
  testthat::expect_identical(study$has_reported_check[study$study_id == id], FALSE)
  summary <- summarise_literature_audit(study, compare_assignment_accounts(input))
  testthat::expect_equal(summary$no_check_share_reviewed, 1)
  testthat::expect_true(is.na(summary$no_check_share_all))
})

testthat::test_that("existing diagnostic evidence prevents an absence finding", {
  input <- audit_inputs()
  id <- input$source_studies$study_id[input$source_studies$source_id == "e_chauchard2014"]
  index <- match(id, input$reviews$study_id)
  input$reviews$review_status[index] <- "complete"
  input$reviews$main_text_status[index] <- "checked"
  input$reviews$supplement_status[index] <- "checked"
  input$reviews$no_check_status[index] <- "no_check_reported"
  input$studies$family_status[input$studies$study_id == id] <- "verified"
  testthat::expect_error(validate_literature_inputs(input), "Negative finding conflicts")
})

testthat::test_that("different categories and nonoverlapping periods are not disagreements", {
  input <- audit_inputs()
  first <- match(input$adjudications$account_left[1], input$accounts$account_id)
  second <- match(input$adjudications$account_right[1], input$accounts$account_id)
  input$adjudications <- input$adjudications[0, ]
  input$accounts <- input$accounts[c(first, second), ]
  testthat::expect_equal(nrow(compare_assignment_accounts(input)), 1L)
  input$accounts$category[2] <- "women"
  testthat::expect_equal(nrow(compare_assignment_accounts(input)), 0L)
  input$accounts$category[2] <- "sc"
  input$accounts$cycle_start[2] <- 2020L
  input$accounts$cycle_end[2] <- 2020L
  testthat::expect_equal(nrow(compare_assignment_accounts(input)), 0L)
  input$accounts$cycle_start[2] <- NA_integer_
  input$accounts$cycle_end[2] <- NA_integer_
  pairs <- compare_assignment_accounts(input)
  testthat::expect_equal(nrow(pairs), 1L)
  testthat::expect_false(pairs$scope_matches)
})

testthat::test_that("scope must be verified before a difference becomes confirmed", {
  input <- audit_inputs()
  input$adjudications$status <- "confirmed_disagreement"
  input$adjudications$scope_review <- "complete"
  testthat::expect_error(validate_literature_inputs(input), "Confirmed disagreement lacks")
  ids <- c(input$adjudications$account_left, input$adjudications$account_right)
  input$accounts$scope_status[input$accounts$account_id %in% ids] <- "verified"
  testthat::expect_silent(validate_literature_inputs(input))
  input$accounts$cycle_start[input$accounts$account_id == ids[1]] <- NA_integer_
  testthat::expect_error(validate_literature_inputs(input), "Confirmed disagreement lacks")
})

testthat::test_that("support links distinguish inherited evidence and compatible versions", {
  input <- audit_inputs()
  testthat::expect_silent(validate_literature_inputs(input))
  row <- which(input$claim_support$support_type == "prior_study")[1]
  input$claim_support$support_type[row] <- "own_diagnostic"
  testthat::expect_error(validate_literature_inputs(input), "same study and compatible version")
  input <- audit_inputs()
  row <- which(input$claim_support$claim_id == "a_037")
  input$claim_support$supporting_claim_id[row] <- "a_033"
  testthat::expect_error(validate_literature_inputs(input), "same study and compatible version")
})

testthat::test_that("reversed adjudication duplicates are rejected", {
  input <- audit_inputs()
  duplicate <- input$adjudications[1, ]
  duplicate$account_left <- input$adjudications$account_right[1]
  duplicate$account_right <- input$adjudications$account_left[1]
  input$adjudications <- dplyr::bind_rows(input$adjudications, duplicate)
  testthat::expect_error(validate_literature_inputs(input), "duplicate key in adjudication pairs")
})

testthat::test_that("pending inclusion prevents a whole-corpus no-check rate", {
  studies <- tibble::tibble(
    inclusion = c("included", "pending"), review_status = c("complete", "in_progress"),
    family_status = c("verified", "provisional"), has_reported_check = c(FALSE, NA)
  )
  result <- summarise_literature_audit(studies, tibble::tibble(status = character()))
  testthat::expect_equal(result$no_check_share_reviewed, 1)
  testthat::expect_true(is.na(result$no_check_share_all))
})

testthat::test_that("diagnostic numbers preserve unknowns and reject invalid values", {
  input <- audit_inputs()
  testthat::expect_true(anyNA(input$diagnostics$sample_size))
  checked <- input$diagnostics[input$diagnostics$claim_id == "e_chauchard_validation", ]
  testthat::expect_true(all(checked$sample_size == 570L))
  testthat::expect_true(all(checked$n_groups == 16L))
  input$diagnostics$reported_p_value[1] <- 68
  testthat::expect_error(validate_literature_inputs(input), "p-value must be between")
})
