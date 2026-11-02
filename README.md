# Reservation patterns

How much do women's reservation transitions vary between districts and between
blocks within districts? This repository studies GP heads in Rajasthan
(2005, 2010, 2015, 2020) and Uttar Pradesh (2005, 2010, 2015, 2021), using the
pooled releases in the sibling `local_elections` repository.

The analysis is descriptive. A negative transition contrast indicates less
immediate repetition, not demonstrated rotation-rule compliance. Neither zero
serial association nor geographic heterogeneity establishes randomization or
bureaucratic discretion. Existing findings in these states motivated this study;
this is not a blinded preregistration.

## Run

Install [uv](https://docs.astral.sh/uv/), then:

```sh
uv sync --group dev
make check
uv run reservation-patterns build --source ../local_elections
uv run reservation-patterns benchmark outputs/data/rajasthan/panel.parquet --out outputs/rajasthan_benchmark.csv
uv run reservation-patterns validate --replicates 20
uv run reservation-patterns fit outputs/data/rajasthan/panel.parquet --out outputs/rajasthan
uv run reservation-patterns report outputs/rajasthan
uv run reservation-patterns fit outputs/data/uttar_pradesh/panel.parquet --out outputs/uttar_pradesh
uv run reservation-patterns report outputs/uttar_pradesh
```

Run linkage sensitivity with `fit --complete-history`, restricting to GPs with
all adjacent transitions. Compare sample coverage before comparing estimates.

Run prior sensitivities with `fit --scale 0.25` and `--scale 1`, writing each to
a separate output directory. Run composition adjustment with `--adjusted`.
The latter uses caste-category transitions and requires both lag groups for every
statewide category in each reported block. It can legitimately produce no eligible
blocks. Do not relax support requirements silently.

The build reads only the two relevant master files. It never scrapes, rebuilds,
or changes `local_elections`. Outputs are ignored by Git. `uv.lock` pins the
software environment. `outputs/data/manifest.json` records the source commit,
working-tree state, exact input hashes, and constructed panel hashes. Fit settings
record the input panel hash. Hashes, rather than a clean source checkout alone,
identify the actual analyzed data. The committed `source-lock.json` pins the two
input hashes; a changed source requires explicit review and updating that file.

## Data contract

One panel row is a GP observed in two adjacent scheduled cycles. Keys are NFC
Unicode-normalized, case-folded, whitespace-normalized district, block, and GP
names. Punctuation and substantive name components are preserved. Names are not
administrative identifiers: unchanged names do not prove unchanged boundaries.
No fuzzy linkage or standardized-name fallback is used. All duplicate year/key
records are excluded, not arbitrarily deduplicated. Geographic renaming or moves
cause nonmatches. Historical cycles with unstated election type are retained;
explicit by-elections and off-cycle records are excluded.

`records.parquet` retains source columns, original names in `*_raw`, and an
`exclusion` field. `linkage.parquet` is the one-to-one outer join ledger with
`left_only`, `right_only`, or `both`; no gap is bridged. Both source rows and their
provenance survive through `_previous` suffixes. `coverage.csv` counts linkage
outcomes by district and transition; `exclusions.csv` counts excluded records.
`transitions.csv` contains block-level 2×2 tables. `histories.parquet` preserves
available four-cycle histories without requiring a balanced panel;
`history_patterns.csv` counts sequences with `?` for missing years.

`previous` and `current` are binary women-reserved indicators; missing status is
excluded, never set to zero. `initial` is the first observed lag status in the
linked GP history. `gp_id` and `block_id` are JSON-encoded geographic tuples.
`transition` identifies the actual year pair. The primary population is uniquely
matched seats with known status, not all seats in the state.

## Model and estimands

The Bayesian logistic model includes transition-specific intercepts and lag
associations, district and nested block deviations for both coefficients in each
transition, and a GP random intercept shared over observations. A coefficient on
initial observed status addresses association with the starting condition under
a parametric specification; it does not solve arbitrary dynamic-panel bias.
Geographic deviations share scale parameters but are independent across cycles
conditional on those scales. Persistent cross-cycle geographic effects are not
separately identified in this specification.

Base coefficients have Normal(0, 1.5) priors, geographic and GP scales have
HalfNormal(0.5) priors, and initial-status and optional category coefficients have
Normal(0, 1) priors. Random effects are noncentered. Independent Bernoulli
likelihoods conditional on effects do not enforce fixed reservation quotas;
fixed-quota simulations stress-test this working likelihood.

Primary block contrasts average fitted reservation probabilities over actual GP
observations in each observed lag group, then subtract the lag-zero mean from the
lag-one mean. Initial history and GP effects stay attached to their observations;
no unsupported initial/lag combinations are created. Both lag groups must be
observed. These are smoothed conditional associations, not causal effects. The
optional adjusted version averages category-specific conditional contrasts over
the statewide category-transition distribution. Raw 2×2 tables remain separate.

The equal-transition summary averages contrasts within blocks observed in every
transition; its population is explicitly the common-block sample.

Within every posterior draw, total variance of block contrasts is partitioned
using the law of total variance. District weights equal the sum of constituent
block weights. Equal blocks is primary; seat weighting uses linked transition
counts. The district share divides between-district variance by total geographic
variance; it is not a share of individual reservation outcomes explained. Near-zero
total variation makes this ratio uninformative. Credible intervals are equal-tailed
95% intervals. The spread of posterior block means is never substituted for this
calculation.

## Validation and interpretation gates

Unit tests cover missing labels, duplicate keys, adjacent-cycle restrictions,
variance identities, quota simulation, and finite model density. Simulation runs
retain every replicate and failures. A separate scenario includes persistent GP heterogeneity. Homogeneous truth lies on the variance
boundary: central credible intervals need not include exactly zero, so coverage
is not reported for that boundary. Fixed-quota generating-logit contrasts are not
the quota-conditioned marginal truth; that scenario is a stress test, not a
coverage claim. Heterogeneous unconstrained simulations report interval coverage.

Fits save posterior and prior draws, predictive checks, diagnostics, settings,
block estimates and variance components. The diagnostics gate requires four
chains, R-hat ≤1.01, bulk and tail ESS ≥400 for all sampled parameters and saved effects, and zero
divergences. That gate alone does not validate the model. Review all latent-effect
diagnostics, predictive checks, simulation recovery, prior sensitivity, and
linkage sensitivity before substantive conclusions. Sparse or unsupported blocks
may be predominantly informed by the model. No rankings or discretion claims are
warranted from their point estimates.

The homogeneous benchmark conditions on observed lag groups and simulates from
state-transition-specific probabilities with actual block sample sizes. It is
not a randomization test and does not reproduce an official assignment mechanism.

## References

- [Gelman and Pardoe, explained variance and pooling](https://stat.columbia.edu/~gelman/research/published/rsquared.pdf)
- [PyMC sampling documentation](https://www.pymc.io/projects/docs/en/stable/api/generated/pymc.sample.html)
- [Source data](https://github.com/in-rolls/local_elections)
