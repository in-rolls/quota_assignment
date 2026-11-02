# Design and interpretation

The study describes women's reservation transitions for GP heads in Rajasthan
(2005, 2010, 2015, 2020) and Uttar Pradesh (2005, 2010, 2015, 2021). Existing
observations motivated the design; this is not a blinded preregistration.

## Data and linkage

Inputs are the two state master Parquet files in `local_elections`, verified
against committed SHA-256 hashes. Source columns and row/page provenance remain
in the constructed records. A panel row joins a GP in adjacent scheduled cycles.
The key is district, block and GP name after NFC normalization, Unicode case
folding and whitespace normalization. Punctuation is preserved. Standardized-name
fallbacks and fuzzy matching are not used. JSON geographic tuples form stable
within-build identifiers; they are not official administrative codes.

Duplicate year/key groups, absent geography, explicit by-elections and missing
reservation labels are excluded. Unknown reservation never becomes zero. Off-cycle
years are excluded. Historical scheduled-cycle rows with unstated election type
are retained. Each join is one-to-one and retains unmatched rows in the linkage
audit; no missing cycle is bridged. Names alone cannot establish unchanged boundaries.

The primary population is uniquely matched GPs with known reservation status,
not every GP in a state. Rajasthan's early linkage is especially incomplete.
`records.rds`, `links.rds`, `coverage.csv`, `exclusions.csv`, `histories.rds` and
`provenance.csv` preserve the construction audit. `previous_reserved`,
`current_reserved` and `initial_reserved` are binary reservation indicators;
initial status is the first observed lag status for the linked GP.

## Estimands

For each district and each block, estimate the reservation probability among
previously reserved GPs minus that among previously unreserved GPs. Negative
values indicate avoidance of immediate repetition. Zero does not establish
random assignment; a negative value does not establish rotation-rule compliance.

The raw version is a difference of observed rates. The smoothed version averages
posterior fitted probabilities over actual GP observations within each lag group.
GP effects and initial history remain attached to those observations. This does
not predict unsupported combinations by toggling lag while fixing initial history.
Both lag groups must be observed. District contrasts are computed directly from
GPs in each district, separately from block contrasts.

Within each posterior draw, calculate the variance of block contrasts and apply
the law of total variance to separate between-district and within-district block
components. Equal block weights are primary; linked-seat weighting is secondary.
District weights in this decomposition are the sums of their block weights.
The district-only distribution uses equal districts as its primary weighting.
The two standalone geographic spreads must not be added together. The district
share concerns geographic variation, not total variation in individual outcomes.
A near-zero denominator makes that share uninformative.

The equal-transition summary averages draw-wise contrasts for units supported in
every intended transition. It must never silently drop an unsupported cycle.
Intervals are equal-tailed 95% Bayesian credible intervals. The spread of posterior
means is not used to estimate underlying heterogeneity.

## Model

The brms Bernoulli-logit model has transition-specific baselines and lag
associations, independent district-by-transition and block-by-transition random
intercepts and lag slopes, and GP random intercepts shared across observations.
Geographic scales are shared across cycles, while geographic realizations are
independent conditional on those scales. Stable cross-cycle geographic effects
are not separately identified. The model includes initial reservation status;
this is a parametric initial-condition adjustment, not a solution to arbitrary
dynamic-panel bias.

Fixed effects have Normal(0, 1.5) priors, initial status has Normal(0, 1), and
random-effect SDs have half-Normal(0, 0.5) priors. The optional composition model
adds nonreference caste-transition indicators and their lag interactions, with
Normal(0, 1) priors. Explicit numeric columns preserve the independent
transition-slope priors; the first sorted caste transition is the reference. It standardizes
category-specific conditional contrasts to the statewide caste-transition
composition, only where every category has both lag groups locally. Empty adjusted
results are legitimate. They do not justify relaxing support requirements.

The working likelihood does not enforce fixed reservation quotas. Simulations
include homogeneous and heterogeneous transitions, unequal and small block sizes,
persistent GP heterogeneity, and a fixed-quota stress scenario. Quota draws follow
conditional Bernoulli sampling. Quota-generating logits are not marginal transition
truth, so quota coverage is not claimed. At homogeneous variance zero, central
credible-interval coverage is likewise not treated as a valid boundary test.

## Verification

Compare R and historical Python linkage keys and binary outcomes, not just row
counts. Check variance identities and preserve observed histories when computing
contrasts. Validate district and block outputs separately. Every simulation failure
is retained. Coverage targets use the same supported blocks as the estimates.

The sampling gate requires four chains, finite R-hat at most 1.01, bulk and tail
ESS at least 400, zero divergences and no maximum-tree-depth hits. Examine prior
and posterior predictive checks, variance-prior sensitivities, complete-history
linkage sensitivity, and empirical simulation coverage before reporting findings.
Passing sampling diagnostics alone does not validate the model or the linkage.

The simple noise benchmark fixes observed lag groups and unit sample sizes and
simulates from common state-transition probabilities. It is not randomization
inference under an official assignment mechanism. Eligibility, category composition,
quotas, longer history and boundary changes remain rival explanations for geographic
variation. Causal attribution to discretion is outside this descriptive stage.
