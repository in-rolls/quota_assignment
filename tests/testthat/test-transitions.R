testthat::test_that("variance partition uses district masses implied by unit weights", {
  contrast <- matrix(c(0, 1, 3), nrow = 1)
  partition <- partition_variance(contrast, c("a", "a", "b"))
  testthat::expect_equal(partition$total_sd^2, mean((c(0, 1, 3) - 4 / 3)^2))
  testthat::expect_equal(partition$within_district_sd^2, 1 / 6)
  testthat::expect_equal(
    partition$total_sd^2,
    partition$between_district_sd^2 + partition$within_district_sd^2
  )
  zero <- partition_variance(matrix(0, 2, 3), c("a", "a", "b"))
  testthat::expect_true(all(is.na(zero$district_share)))
})

testthat::test_that("district and block counts are separate and conserve seats", {
  panel <- simulate_panel(district_count = 2, blocks_per_district = 2)$panel
  district <- count_transitions(panel, "district")
  block <- count_transitions(panel, "block")
  testthat::expect_equal(nrow(district), 6L)
  testthat::expect_equal(nrow(block), 12L)
  testthat::expect_equal(sum(district$previous_reserved_n), sum(block$previous_reserved_n))
  benchmark <- simulate_benchmark(panel, "district", replicates = 10)
  testthat::expect_equal(nrow(benchmark), 30L)
})

testthat::test_that("contrasts preserve observed histories and reject unsupported groups", {
  seats <- tibble::tibble(
    previous_reserved = c(0L, 1L), initial_reserved = c(0L, 1L),
    caste_transition = c("NONE", "NONE")
  )
  probabilities <- matrix(c(0.5, stats::plogis(2)), nrow = 1)
  testthat::expect_equal(compute_contrast(probabilities, seats), stats::plogis(2) - 0.5)
  seats$previous_reserved <- 0L
  testthat::expect_null(compute_contrast(probabilities, seats))
})

testthat::test_that("cycle averaging requires every intended cycle", {
  geography <- list(
    estimates = tibble::tibble(
      transition = "0", district = "d", block_id = "b",
      level = "block", group = "g", seat_count = 10L, previous_unreserved_n = 5L,
      previous_reserved_n = 5L, lower = 0, estimate = 0, upper = 0
    ),
    draws = list(g = c(0, 0))
  )
  result <- average_transitions(geography, c("0", "1", "2"))
  testthat::expect_equal(nrow(result$estimates), 1L)
})
