make_caste_population <- function() {
  list(
    lgd = tibble::tibble(
      lgd_village_id = c("v1", "v2", "v3"), village_id = c("1", "2", "3"),
      gp_code = c("a", "a", "b"), gp_name = c("A", "A", "B"), district_code = "d", district_name = "D"
    ),
    keys = tibble::tibble(village_id = c("1", "2", "3"), shrid2 = c("s1", "s1", "s2")),
    population = tibble::tibble(
      shrid2 = c("s1", "s2"), population = c(100, 900),
      sc_population = c(40, 90), st_population = c(10, 90), passes_population_screen = TRUE,
      census_year = 2011L
    )
  )
}

testthat::test_that("GP aggregation conserves counts and withholds incomplete geography", {
  data <- make_caste_population()
  build <- function() build_gp_population(data$lgd, data$keys, data$population)
  gps <- build()$gps
  testthat::expect_equal(sum(gps$population), 1000)
  testthat::expect_equal(gps$sc_share, c(0.4, 0.1))
  data$lgd$gp_code[2] <- "b"
  data$lgd$gp_name[2] <- "B"
  testthat::expect_true(all(is.na(build()$gps$population)))
  data <- make_caste_population()
  data$lgd$village_id[2] <- NA_character_
  testthat::expect_true(is.na(build()$gps$population[1]))
  data <- make_caste_population()
  data$population$passes_population_screen[1] <- FALSE
  testthat::expect_true(is.na(build()$gps$population[1]))
  data <- make_caste_population()
  gps <- build_gp_population(data$lgd, data$keys, data$population, urban_shrids = "s1")$gps
  testthat::expect_true(is.na(gps$population[1]))
})

testthat::test_that("catalog ranks retain missing competitors and ties", {
  gps <- tibble::tibble(district_code = "d", sc_share = c(0.4, 0.2, 0.2, NA))
  ranked <- rank_catalog(gps, "sc")
  testthat::expect_equal(ranked$rank_lower, c(1L, 2L, 2L, NA_integer_))
  testthat::expect_equal(ranked$rank_upper, c(2L, 4L, 4L, NA_integer_))
})

testthat::test_that("share ordering counts all untied cross-status pairs", {
  testthat::expect_equal(share_order_pairs(c(0.1, 0.2, 0.3), c(0, 0, 1))$discordant_share, 0)
  testthat::expect_equal(share_order_pairs(c(0.1, 0.2, 0.3), c(1, 0, 0))$discordant_share, 1)
  testthat::expect_equal(share_order_pairs(c(0.1, 0.1, 0.3), c(1, 0, 0))$comparable_pairs, 1)
  testthat::expect_true(is.na(share_order_pairs(c(0.1, 0.2), c(1, 1))$discordant_share))
  set.seed(12)
  for (i in seq_len(10)) {
    x <- sample(seq(0, 1, 0.1), 30, replace = TRUE)
    y <- stats::rbinom(30, 1, 0.5)
    pairs <- outer(x[y == 1], x[y == 0], "-")
    testthat::expect_equal(share_order_pairs(x, y)$discordant_pairs, sum(pairs < 0))
  }
})

testthat::test_that("verified rules preserve ranks when observed assignments are missing", {
  evidence <- stats::setNames(
    rep("fixture source", 7),
    c("rule", "roster", "census_vintage", "boundaries", "eligibility", "rotation", "quota")
  )
  evidence <- as.list(evidence)
  evidence$rule_form <- "top_share_among_eligible"
  evidence$category <- "SC"
  evidence$allocation_pool <- "test block, 2010"
  roster <- tibble::tibble(
    gp_id = letters[1:5], population_share = c(0.5, 0.4, 0.3, 0.2, 0.1),
    eligible = c(FALSE, TRUE, TRUE, TRUE, TRUE), reserved = c(0, 1, 1, 0, 0)
  )
  score <- function(x) score_top_share_assignment(x, 2L, 5L, evidence)
  testthat::expect_true(all(score(roster)$assignment_status == "agrees"))
  wrong_form <- evidence
  wrong_form$rule_form <- "rotation_with_wraparound"
  testthat::expect_error(score_top_share_assignment(roster, 2L, 5L, wrong_form), "rule form")
  before <- score(roster)
  roster$reserved[2] <- NA_integer_
  testthat::expect_identical(score(roster)$expected_reserved, before$expected_reserved)
  roster$reserved[3:4] <- c(0, 1)
  testthat::expect_equal(sum(score(roster)$assignment_status == "disagrees"), 2)
  roster$population_share[4] <- 0.3
  testthat::expect_equal(sum(score(roster)$assignment_status == "unresolved_cutoff_tie"), 2)
  testthat::expect_error(score(roster[-1, ]), "Complete")
  roster$eligible[1] <- NA
  testthat::expect_error(score(roster), "Known eligibility")
  testthat::expect_error(score_top_share_assignment(roster, 2L, 5L, list()), "Verified source")
})

testthat::test_that("conflicting catalog districts are retained and never ranked as complete", {
  data <- make_caste_population()
  data$lgd$district_code[2] <- "other"
  data$lgd$district_name[2] <- "Other"
  built <- build_gp_population(data$lgd, data$keys, data$population)
  testthat::expect_equal(nrow(built$gps), 2L)
  testthat::expect_equal(nrow(built$catalog_entries), 3L)
  testthat::expect_equal(built$gps$population_status[1], "ambiguous_catalog")
  testthat::expect_true(all(is.na(rank_catalog(built$gps, "sc")$rank_upper)))
})

testthat::test_that("exact-name joins conserve election rows and refuse ambiguous matches", {
  data <- make_caste_population()
  gps <- build_gp_population(data$lgd, data$keys, data$population)$gps
  seats <- make_seats() |>
    dplyr::mutate(
      row_id = as.character(dplyr::row_number()), reserved_caste = "SC",
      district_latin = NA_character_, gram_panchayat_latin = NA_character_
    )
  linked <- link_caste_elections(seats, gps, c(2005L, 2010L, 2015L, 2020L))
  testthat::expect_equal(nrow(linked), nrow(seats))
  testthat::expect_true(all(linked$link_status == "linked"))
  seats$row_id[1] <- "duplicate"
  seats <- dplyr::bind_rows(seats, dplyr::mutate(seats[1, ], row_id = "another"))
  linked <- link_caste_elections(seats, gps, c(2005L, 2010L, 2015L, 2020L))
  testthat::expect_equal(sum(linked$link_status == "ambiguous_election_name"), 2L)
  testthat::expect_equal(nrow(linked), nrow(seats))
  gps$gp_name[2] <- "A"
  linked <- link_caste_elections(seats, gps, c(2005L, 2010L, 2015L, 2020L))
  testthat::expect_equal(sum(linked$link_status == "ambiguous_catalog_name"), 3L)
})

testthat::test_that("Weaver source years and missing crosswalks remain explicit", {
  data <- make_caste_population()
  gps <- build_gp_population(data$lgd, data$keys, data$population)$gps
  wide <- tibble::tibble(gp_id = c("1", "2"))
  for (year in c(2010L, 2015L, 2020L)) {
    wide[[paste0("source_election_code_", year)]] <- match(year, c(2010, 2015, 2020)) - 2
    wide[[paste0("gp_code_lgd21_", year)]] <- if (year == 2010) c(NA_character_, NA_character_) else c("a", "b")
    wide[[paste0("district_code_ele15_", year)]] <- "d"
    wide[[paste0("block_code_ele15_", year)]] <- "b"
    wide[[paste0("shrid_", year)]] <- "old-version"
    wide[[paste0("reservation_sc_", year)]] <- c(0, 1)
    wide[[paste0("reservation_st_", year)]] <- 0
  }
  path <- tempfile(fileext = ".parquet")
  on.exit(unlink(path))
  arrow::write_parquet(wide, path)
  linked <- read_weaver_links(path, gps)
  testthat::expect_equal(nrow(linked), 6L)
  testthat::expect_true(all(linked$link_status[linked$year == 2010] == "missing_lgd_code"))
  testthat::expect_false(any(linked$election_year_verified[linked$year == 2020]))
  testthat::expect_false(any(linked$year == 2021L))
})
