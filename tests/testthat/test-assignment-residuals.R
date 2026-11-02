testthat::test_that("nested variance distinguishes district and block concentration", {
  data <- tibble::tibble(district = rep(c("a", "b"), each = 4), block_id = rep(letters[1:4], each = 2))
  statistic <- make_spread_statistic(data)
  between <- statistic(c(1, 1, 1, 1, 0, 0, 0, 0))
  testthat::expect_equal(unname(between["equal_unit:district_sd"]), 0.5)
  testthat::expect_equal(unname(between["equal_unit:between_district_share"]), 1)
  within <- statistic(c(1, 1, 0, 0, 1, 1, 0, 0))
  testthat::expect_equal(unname(within["equal_unit:district_sd"]), 0)
  testthat::expect_equal(unname(within["equal_unit:within_district_sd"]), 0.5)
  for (weight in c("equal_unit", "seat")) {
    testthat::expect_equal(
      unname(within[paste0(weight, ":block_sd")]^2),
      unname(within[paste0(weight, ":between_district_sd")]^2 + within[paste0(weight, ":within_district_sd")]^2)
    )
  }
})

testthat::test_that("source blanks never become unreserved observations", {
  data <- tibble::tibble(
    eleid = 1:2, district = 1, block = 1, districtname = "d", blockname = "b",
    caste_reserved = c("SC", ""), caste_reserved_pred = c("ST", "SC"),
    womenreservation = c(1, NA), femaleinstrument = c(0, 1), women_reserv_pred = c(0, 1)
  )
  records <- prepare_supplied_assignments(data)
  testthat::expect_equal(nrow(records), 8L)
  testthat::expect_true(all(is.na(records$mismatch[records$gp_id == "2"])))
  testthat::expect_equal(records$mismatch[records$outcome == "sc" & records$gp_id == "1"], 1L)
  testthat::expect_equal(sum(records$status == "available"), 4L)
})

testthat::test_that("concentration benchmark is deterministic and handles zero disagreements", {
  data <- tibble::tibble(
    district = rep(c("a", "b"), each = 4), block_id = rep(letters[1:4], each = 2),
    mismatch = c(1L, 1L, rep(0L, 6)), stratum = rep(c("one", "two"), 4),
    outcome = "sc", status = "available"
  )
  result <- benchmark_residual_spread(data, repetitions = 20L)
  testthat::expect_identical(result, benchmark_residual_spread(data, repetitions = 20L))
  data$mismatch <- 0L
  result <- benchmark_residual_spread(data, repetitions = 20L)
  testthat::expect_true(all(result$benchmark_mean[grepl("_sd$", result$statistic)] == 0))
})

testthat::test_that("seat weights preserve the variance decomposition with unequal blocks", {
  data <- tibble::tibble(
    district = rep(c("a", "b"), each = 4),
    block_id = c("a", "b", "b", "b", "c", "c", "d", "d")
  )
  result <- make_spread_statistic(data)(c(1, 0, 0, 0, 1, 1, 0, 0))
  testthat::expect_equal(unname(result["seat:block_sd"]^2), 0.234375)
  testthat::expect_equal(unname(result["seat:between_district_sd"]^2), 0.015625)
  testthat::expect_equal(unname(result["seat:within_district_sd"]^2), 0.21875)
})
