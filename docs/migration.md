# R migration

The project follows `finite-sample/know_hidden`: reusable R modules, numbered
execution stages, shared configuration, figures/tables, `renv`, and `testthat`.
The prior Python implementation is preserved in commit `7767c44`.

| Previous | Current |
|---|---|
| `reservation_patterns/*.py` | `R/*.R` and `scripts/*.R` |
| `pyproject.toml`, `uv.lock` | `DESCRIPTION`, `renv.lock` |
| `tests/test_analysis.py` | `tests/testthat/test-*.R` |
| `source-lock.json` | `docs/source_lock.json` |
| `outputs/data/` | `data/build/` |
| `previous`, `current`, `initial` | `previous_reserved`, `current_reserved`, `initial_reserved` |

The R panels were compared row for row on district, block, GP, transition and
both reservation indicators. All 11,832 Rajasthan and 105,907 UP observations
matched. This checks implementation parity, not the substantive accuracy of name
linkage. Both engines read identical pinned source files.

The R implementation adds district-level raw and posterior contrasts alongside
block-level outputs. The unadjusted model preserves the previous prior families
and nested random-effect structure. The optional adjusted model uses explicit nonreference category
indicators rather than redundant category coefficients; its coefficient priors
are explicit in the design and it is not claimed to be numerically identical.
Random draws differ between engines. Existing local Python results and its
virtual environment are preserved but are not required by the R workflow.

## Local verification

On R 4.6.0, `make restore` found the library synchronized with `renv.lock`.
`make check` passed linting and all 30 testthat assertions, without warnings or
skips. The descriptive pipeline ran on both pinned source files, and both figures
were rendered and reviewed. Separate synthetic posterior and prior-predictive
runs compiled and sampled with Stan. All four `make smoke` scenarios completed
and produced three transition estimates each. These short runs failed the strict
sampling-diagnostics gate; they verify execution, not inferential calibration.
Full simulation coverage validation and empirical Bayesian fits remain separate
from this software migration. Generated tables, figures and model output remain local.
