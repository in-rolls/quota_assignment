.PHONY: restore analysis models validate smoke format lint test check
restore:
	Rscript --vanilla -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org"); renv::load(project = getwd()); renv::restore(prompt = FALSE)'
analysis:
	Rscript scripts/99_run_all.R descriptive
models:
	Rscript scripts/99_run_all.R models
validate:
	Rscript scripts/validate_models.R
smoke:
	Rscript scripts/validate_models.R --smoke
format:
	Rscript -e 'styler::style_dir("R"); styler::style_dir("scripts"); styler::style_dir("tests/testthat")'
lint:
	Rscript -e 'l <- unlist(lapply(c("R", "scripts", "tests/testthat"), lintr::lint_dir), recursive = FALSE); print(l); quit(status = as.integer(length(l) > 0))'
test:
	Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'
check: lint test

.PHONY: caste
caste:
	Rscript scripts/06_caste_assignment.R

.PHONY: assignment
assignment:
	Rscript scripts/07_assignment_residuals.R

.PHONY: tables
tables:
	Rscript scripts/05_tables.R
