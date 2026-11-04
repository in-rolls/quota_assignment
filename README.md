# Quota assignment: geographic variation in reservation allocation

**Women's reservation patterns vary sharply across Rajasthan's districts and
blocks in later election cycles, beyond what our simple sampling-noise benchmark
produces.** In 2015 to 2020, the observed spread was about four times the
benchmark mean across districts and twice the benchmark mean across blocks.
Uttar Pradesh shows smaller departures: in its latest transition, block-level
spread is consistent with the benchmark, although district-level spread is larger.

**High statewide agreement with assignment predictions can still hide geographic
concentration of the disagreements.** A separate audit of Chaturvedi, Das and
Mahajan's UP 2015 replication compares observed reservations with the authors'
supplied predictions. It uses 57,555 GPs with observed assignments and geography;
1,607 source records lack those fields.

<!-- assignment_findings:start -->

|Assignment | Disagreements among all observed GPs| District spread: observed / benchmark (pp)| Block spread: observed / benchmark (pp)|
|:----------|------------------------------------:|------------------------------------------:|---------------------------------------:|
|Women      |               1,214 / 57,555 (2.11%)|                                2.35 / 0.59|                             3.07 / 1.81|
|SC         |                 273 / 57,555 (0.47%)|                                0.77 / 0.28|                             2.07 / 0.86|
|ST         |                  18 / 57,555 (0.03%)|                                0.11 / 0.08|                             0.25 / 0.23|

<!-- assignment_findings:end -->

The concentration benchmark redistributes the same prediction disagreements
within caste/prediction groups, retaining geographic sample sizes. It tests an
exchangeable-error reference, not the legal allocation mechanism. Prediction
errors, source errors and documented exceptions remain possible explanations.
ST has only 18 disagreements, so its geographic pattern is weakly informed.
See [the assignment audit](docs/assignment_residuals.md).

For the cross-cycle analysis, we compare a seat's reservation probability after
a reserved cycle with its probability after an unreserved cycle. A negative difference means less immediate
repetition. The table shows how much that difference varies across districts and
across blocks, separately. Larger standard deviations mean greater geographic
variation; all values are in percentage points.

<!-- findings:start -->

|State         |Transition   |Variation across | Observed spread| Benchmark mean| 95% simulated range|
|:-------------|:------------|:----------------|---------------:|--------------:|-------------------:|
|Rajasthan     |2015 to 2020 |districts        |            30.1|            7.5|         5.3 to 10.0|
|Rajasthan     |2015 to 2020 |blocks           |            40.0|           20.6|        18.5 to 22.8|
|Uttar Pradesh |2015 to 2021 |districts        |             5.5|            3.9|          3.1 to 4.9|
|Uttar Pradesh |2015 to 2021 |blocks           |            11.7|           11.4|        10.7 to 12.1|

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
account for the differences. For these transitions, the noise-adjusted partition of block variation
between and within districts also remains pending. The hierarchical models are
implemented; full empirical fits and simulation coverage validation are pending.
These results do not identify bureaucratic discretion.

The cross-cycle analysis covers uniquely matched gram panchayat heads in
[in-rolls/local_elections](https://github.com/in-rolls/local_elections). Matches
use district, block and panchayat names; they do not establish unchanged
boundaries. Rajasthan's early linkage is especially incomplete, so these are
findings about the linked sample. See [methods](docs/design.md).

The table is rebuilt from the saved benchmarks by `scripts/05_tables.R`.
Detailed reports and figures are generated locally in `tabs/` and `figs/`.

## Caste reservation

The question is how much variation remains after accounting for the allocation
rules, and how much of that residual variation lies between districts and between
blocks within districts. Earlier studies do test assignment: Chauchard audits
selected samitis, Das and coauthors examine OBC balance in a sizeable Rajasthan
sample, Chaturvedi and coauthors check UP allocation predictions, and Weaver and Narasimhan study district differences in delimitation
compliance. Our [evidence ledger](docs/caste_literature.md) records what each checks.

**The SC/ST extension runs; independently verified rule departures remain unresolved.**
It links elections to Census population aggregates on the official 2024 GP
mapping and produces separate district/block diagnostics. Historical allocation
rosters, population vintages, quotas and rotation eligibility still need to be
established. An apparent inversion in population ranks can be entirely consistent
with rotation.

<!-- caste_findings:start -->

Census 2011 population on the 2024 GP mapping:

|State         | GPs in catalog| Population passes checks| Share of catalog|
|:-------------|--------------:|------------------------:|----------------:|
|Rajasthan     |         11,207|                    7,773|            69.4%|
|Uttar Pradesh |         57,691|                   50,172|            87.0%|

Latest source wave linked to those population aggregates:

|State         |Election source |Source year       | Linked records| Source records|
|:-------------|:---------------|:-----------------|--------------:|--------------:|
|Rajasthan     |master          |2020              |          2,448|         11,304|
|Uttar Pradesh |master          |2021              |          7,636|         49,772|
|Uttar Pradesh |weaver          |2020 (unverified) |         42,286|         59,004|

Name matching selects a small subset, especially in Rajasthan. Weaver's supplied LGD codes
give broader UP coverage. These are linkage results, not estimates of rule compliance.

<!-- caste_findings:end -->

Run `make assignment` for the UP 2015 author-prediction audit and `make caste` with the inputs in `docs/caste_source_lock.json`. Set `IN_ROLLS`
and `SHRUG` if those source directories are elsewhere. The build retains the
full modern GP catalog, audits incomplete village mappings, sums population
counts before computing shares, and keeps SC and ST separate. Weaver's March 17
vintage is a separate source sensitivity; its source-labeled 2020 wave is retained
as unverified rather than silently renamed 2021. Both Weaver vintages and their
prepared panels are published upstream in
[local_elections_up](https://github.com/in-rolls/local_elections_up/tree/main/data/reference/weaver).
This repository reads the pinned March 17 panel from that checkout.
See the [analysis design](docs/caste_design.md), [join contract](docs/caste_data.md)
and local report `tabs/caste_summary.md`.

## Reproduce

Use R 4.6 and a C++ toolchain for Stan. Follow the [input setup](docs/inputs.md)
to obtain the pinned upstream repositories and SHRUG files. Data collection and
shared preparation belong in those upstream repositories; this repository owns
the assignment analysis.

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

Results tables use `knitr::kable()` and figures use `ggplot2`. Run `make tables`
to regenerate reports and README result tables from saved analysis CSVs. This
rerenders available results without rerunning the estimates or simulations.

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
| `scripts/06_caste_assignment.R` | Audited Census/GP linkage and exploratory SC/ST assignment diagnostics |
| `scripts/07_assignment_residuals.R` | Supplied-prediction disagreements and district/block concentration benchmarks |
| `scripts/99_run_all.R` | Ordered stages in separate environments |
| `data/build/` | Generated panels, linkage audits, fits and draws; ignored by Git |
| `tabs/`, `figs/` | Reviewable tables, reports and figures |
| `docs/` | Design, source pin and migration record |
| `tests/testthat/` | Linkage, estimand, model-interface and failure-handling tests |

No Python installation is needed. The previous implementation remains in Git
history; its local generated artifacts are preserved outside the active pipeline.
The R migration reproduces its matched panels exactly. Numerical posterior draws
are not expected to match across PyMC and Stan. See [migration notes](docs/migration.md).

## Research note

The LaTeX manuscript is in [paper/main.tex](paper/main.tex), with a source-verified
[bibliography](paper/references.bib) and generated assignment-claim and legal-provision tables.
Run `make analysis`, `make assignment`, and `make caste` to rebuild analysis
outputs from the pinned upstream inputs, then `make paper` to audit the numbers,
generate LaTeX tables, macros and figures, and compile the paper and all appendices into `paper/main.pdf`.
`make audit` runs the independent numerical checks and sensitivity analyses.
The paper target uses saved estimates and does not fit the Bayesian models.

The note describes geographic patterns and prediction disagreements. It does not
estimate the causal contribution of bureaucratic discretion or certify historical
rule compliance. Small-cell and linkage sensitivity, including the loss of most
Rajasthan blocks under minimum-denominator restrictions, are part of its findings.

## Assignment claims

`make paper` includes a compact quotation appendix in `paper/main.pdf`,
using [paper/assignment_appendix.tex](paper/assignment_appendix.tex). The records
distinguish asserted lotteries, ranking,
rotation, legal prescriptions, identifying assumptions and implementation checks.
The [machine-readable inventory](data/reference/assignment_claims/) retains source
versions, hashes, exact locations, short verified quotations, scope, qualifications,
and the data needed to test each assertion. The note's main comparison table and
legal appendix are generated from this inventory. The full inventory retains
screening dispositions for every PDF in the upstream literature corpus.

The inventory covers all 48 PDFs and all 23 study entries in `quota_spending/lit`,
plus the note's external and official sources. It exposes differences in what was
actually checked: reconstructing one district's list, finding average balance,
and predicting nearly all assignments are different claims. The tables retain
qualifications, including papers that already report assignment errors.
See the generated [coverage and next-test report](docs/assignment_claims.md).
Historical UP rules and one damaged order remain unverified; source access and
version limitations are recorded rather than silently filled in.
