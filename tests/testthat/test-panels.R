testthat::test_that("adjacent linkage conserves rows and never bridges missing cycles", {
  seats <- make_seats()
  prepared <- build_panel(seats, c(2005L, 2010L, 2015L, 2020L))
  testthat::expect_equal(nrow(prepared$panel), 6L)
  testthat::expect_equal(nrow(prepared$records), 8L)
  seats$reserved_woman[seats$year == 2010 & seats$gram_panchayat == "A"] <- NA
  seats <- dplyr::bind_rows(seats, seats[1, ])
  prepared <- build_panel(seats, c(2005L, 2010L, 2015L, 2020L))
  testthat::expect_equal(sum(prepared$records$exclusion == "ambiguous_key"), 2L)
  testthat::expect_equal(sum(prepared$records$exclusion == "missing_reservation"), 1L)
  testthat::expect_equal(sum(prepared$panel$gram_panchayat == "a"), 1L)
})

testthat::test_that("invalid reservation labels fail and names retain distinctions", {
  seats <- make_seats()
  seats$reserved_woman[1] <- 2
  testthat::expect_error(build_panel(seats, c(2005L, 2010L)), "Reservation")
  testthat::expect_equal(normalize_name("  DAULATPURA-II  "), "daulatpura-ii")
  testthat::expect_false(normalize_name("DAULATPURA-I") == normalize_name("DAULATPURA-II"))
})
