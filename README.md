# Geographic variation in reservation allocation

**Women's reservation patterns vary sharply across Rajasthan's districts and
blocks in later election cycles, beyond what our simple sampling-noise benchmark
produces.** In 2015 to 2020, the observed spread was about four times the
benchmark mean across districts and twice the benchmark mean across blocks.
Uttar Pradesh shows smaller departures: in its latest transition, block-level
spread is consistent with the benchmark, although district-level spread is larger.

We compare a seat's probability of reservation after a reserved cycle with its
probability after an unreserved cycle. A negative difference means less immediate
repetition. The table shows how much that difference varies across districts and
across blocks, separately. Larger standard deviations mean greater geographic
variation; all values are in percentage points.

<!-- findings:start -->

| State | Transition | Variation across | Observed spread | Benchmark mean | 95% simulated range |
|---|---|---|---:|---:|---:|
| Rajasthan | 2015 to 2020 | districts | 30.1 | 7.5 | 5.3 to 10.0 |
| Rajasthan | 2015 to 2020 | blocks | 40.0 | 20.6 | 18.5 to 22.8 |
| Uttar Pradesh | 2015 to 2021 | districts | 5.5 | 3.9 | 3.1 to 4.9 |
| Uttar Pradesh | 2015 to 2021 | blocks | 11.7 | 11.4 | 10.7 to 12.1 |

<!-- findings:end -->

Rajasthan's 2010 to 2015 transition shows similarly large departures. Its earliest linked
transition does not. UP's departures are smaller and vary by cycle and geographic
level. The benchmark gives every unit the same transition probabilities within
each state and cycle, while retaining its observed sample sizes. The intervals
show the middle 95% of simulated spreads, not confidence intervals for the
observed spread.

**We have evidence of variation beyond this noise benchmark, but have not yet
estimated how much remains unexplained by the allocation rules.** Eligibility,
quotas, caste composition, earlier reservation history and boundary changes may
account for the differences. Nor have we estimated the share of block variation
that lies between districts rather than within them. The hierarchical models are
implemented; full empirical fits and simulation coverage validation are pending.
These results do not identify bureaucratic discretion.

The analysis covers uniquely matched gram panchayat heads in
[in-rolls/local_elections](https://github.com/in-rolls/local_elections). Matches
use district, block and panchayat names; they do not establish unchanged
boundaries. Rajasthan's early linkage is especially incomplete, so these are
findings about the linked sample. See [methods](docs/design.md).

The table is rebuilt from the saved benchmarks by `scripts/05_tables.R`.
Detailed reports and figures are generated locally in `tabs/` and `figs/`.

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
