# Geographic variation in reservation allocation

How much do women's reservation patterns differ across districts and blocks
covered by the same statewide policy? This project examines gram panchayat heads
in Rajasthan and Uttar Pradesh using pinned inputs from
[in-rolls/local_elections](https://github.com/in-rolls/local_elections).

The presentation separates district differences, block differences, and block
differences within districts. The question is descriptive: geographic variation
does not by itself establish different rules, bureaucratic discretion, or a
failure of random assignment.

The generated transition figures show each administrative unit as a point. The horizontal axis gives reservation
following an unreserved cycle; the vertical axis gives reservation following a
reserved cycle. Points below the diagonal indicate less immediate repetition.
These are raw rates with unequal precision, not estimates of noise-adjusted
heterogeneity. The descriptive reports are generated in `tabs/`; figures are generated in
`figs/`. These derived outputs stay local. See [methods](docs/design.md).

## Reproduce

Use R 4.6 and a C++ toolchain for Stan.

```sh
make restore
make check
make analysis
```

`make analysis` builds the matched panels, district/block transition tables,
noise benchmarks, figures, and descriptive reports. It does not fit the Bayesian
models. Point to a different source checkout with `LOCAL_ELECTIONS=/path/to/local_elections`;
the two input hashes must match `docs/source_lock.json`.

Model fitting and simulation validation are explicit:

```sh
make smoke
make validate
make models
```

`make smoke` checks all four simulation scenarios with short chains. It is an
execution check, not a coverage study. `make validate` runs the longer repeated
simulation study. `make models` runs both states, produces separate district and
block posterior contrasts, and partitions block variation into between-district
and within-district components. It also generates prior and posterior predictive
checks. Sampling diagnostics and simulations must support substantive interpretation.

Settings, paths, seeds, figure dimensions and the shared ggplot theme live in
`scripts/00_config.R`. The reference settings use four chains, 1,000 warmup and
1,000 retained draws per chain. Run sensitivities with `RESERVATION_MODEL=prior_narrow make models`,
`prior_wide`, `composition`, or `complete_history`. Fits and model tables use
separate names for each specification; primary outputs are preserved.

## Organization

The structure follows [finite-sample/know_hidden](https://github.com/finite-sample/know_hidden):
reusable functions in `R/`, numbered stages in `scripts/`, explicit file handoffs,
`renv` dependencies, `testthat` tests, and centralized presentation settings.
Code uses native pipes, snake_case names and tidyverse conventions.

| Path | Contents |
|---|---|
| `R/` | Source verification, linkage, transitions, models, simulations, figures and reports |
| `scripts/00_config.R` | Paths, cycles, model settings and figure style |
| `scripts/01_prepare_data.R` | Verify inputs and build audited panels |
| `scripts/02_estimate.R` | District/block raw rates and homogeneous-process benchmarks |
| `scripts/03_fit_models.R` | Bayesian fits, diagnostics and geographic decomposition |
| `scripts/04_figures.R` | PDF and PNG figures |
| `scripts/05_tables.R` | Generated descriptive reports |
| `scripts/99_run_all.R` | Ordered stages in separate environments |
| `data/build/` | Generated panels, linkage audits, fits and draws; ignored by Git |
| `tabs/`, `figs/` | Reviewable tables, reports and figures |
| `docs/` | Design, source pin and migration record |
| `tests/testthat/` | Linkage, estimand, model-interface and failure-handling tests |

No Python installation is needed. The previous implementation remains in Git
history; its local generated artifacts are preserved outside the active pipeline.
The R migration reproduces its matched panels exactly. Numerical posterior draws
are not expected to match across PyMC and Stan. See [migration notes](docs/migration.md).
