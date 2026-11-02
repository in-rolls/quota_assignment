# Descriptive analysis audit

The independently recomputed descriptive counts, geographic spreads and variance identities agree with the saved outputs.
The audit identifies interpretation and support limitations rather than a numerical correction to those outputs.
Run `Rscript scripts/audit_note.R` after building the descriptive and assignment outputs.

## Claims and estimands

The transition contrast is the reserved-after-reserved rate minus the reserved-after-unreserved rate within a geographic unit.
Its spread describes linked GPs in units with both lag groups; it does not describe every GP in the state.
The prediction audit describes observed-versus-supplied-predicted reservation disagreement among complete records.
Its district/block spreads and block-variance decomposition are observed quantities that include finite-group variation.
Equal-unit and seat-weighted summaries answer different questions.
Neither weighting identifies a bureaucratic effect.

## Transition sensitivity

Each restriction requires the indicated minimum in each lag group. The table reports the changed support alongside the spread.
Leave-one ranges remove a district, including all its blocks, and recompute the descriptive spread.
These are influence ranges, not confidence intervals. Missing spreads indicate fewer than two eligible units.

|state         |cycle     |level    | minimum_lag_group| units| seats| spread_pp| leave_one_min_pp| leave_one_max_pp|
|:-------------|:---------|:--------|-----------------:|-----:|-----:|---------:|----------------:|----------------:|
|rajasthan     |2015-2020 |district |                 1|    27|  5189|     30.08|            28.20|            30.65|
|rajasthan     |2015-2020 |district |                20|    27|  5189|     30.08|            28.20|            30.65|
|rajasthan     |2015-2020 |district |                50|    24|  4945|     27.89|            25.80|            28.49|
|rajasthan     |2015-2020 |block    |                 1|   207|  5186|     39.97|            38.13|            40.65|
|rajasthan     |2015-2020 |block    |                20|     3|   138|      3.69|             4.26|             4.26|
|rajasthan     |2015-2020 |block    |                50|     0|     0|        NA|               NA|               NA|
|uttar_pradesh |2015-2021 |district |                 1|    67| 46864|      5.46|             5.20|             5.50|
|uttar_pradesh |2015-2021 |district |                20|    66| 46811|      5.26|             4.97|             5.30|
|uttar_pradesh |2015-2021 |district |                50|    66| 46811|      5.26|             4.97|             5.30|
|uttar_pradesh |2015-2021 |block    |                 1|   708| 46864|     11.66|            11.53|            11.74|
|uttar_pradesh |2015-2021 |block    |                20|   446| 34772|     10.47|            10.29|            10.58|
|uttar_pradesh |2015-2021 |block    |                50|     1|   186|        NA|               NA|               NA|

The Rajasthan district result persists under the support restrictions and single-district exclusions shown.
The Rajasthan block restriction removes almost the entire sample; its reduced spread cannot be interpreted as a correction
to the full linked-sample statistic. No robustness claim should conceal this loss of support.
Restricted-sample and leave-one spreads must not be compared to the original-sample benchmark as a formal test.

## Assignment prediction sensitivity

|outcome          |level    |weighting  | units| spread_pp| leave_one_min_pp| leave_one_max_pp|
|:----------------|:--------|:----------|-----:|---------:|----------------:|----------------:|
|women_instrument |district |equal_unit |    75|      2.35|             1.68|             2.37|
|women_instrument |district |seat       |    75|      1.64|             1.15|             1.66|
|women_instrument |block    |equal_unit |   823|      3.07|             2.70|             3.10|
|women_instrument |block    |seat       |   823|      2.73|             2.45|             2.76|
|women_prediction |district |equal_unit |    75|      2.73|             1.69|             2.75|
|women_prediction |district |seat       |    75|      1.72|             1.21|             1.75|
|women_prediction |block    |equal_unit |   823|      3.26|             2.82|             3.29|
|women_prediction |block    |seat       |   823|      2.84|             2.55|             2.87|
|sc               |district |equal_unit |    75|      0.77|             0.53|             0.77|
|sc               |district |seat       |    75|      0.66|             0.55|             0.67|
|sc               |block    |equal_unit |   823|      2.07|             1.72|             2.09|
|sc               |block    |seat       |   823|      2.11|             1.64|             2.14|
|st               |district |equal_unit |    75|      0.11|             0.09|             0.11|
|st               |district |seat       |    75|      0.11|             0.09|             0.12|
|st               |block    |equal_unit |   823|      0.25|             0.20|             0.26|
|st               |block    |seat       |   823|      0.24|             0.20|             0.24|

The alternative women's prediction changes disagreement totals and spreads; both variants remain in the audit CSVs.
The ST series contains few disagreements and should not carry a strong geographical heterogeneity conclusion.

## Checks and scope

- Tier 1 denominators: independently reconstruct counts, both transition rates, mismatch totals, and union-reserved denominators.
- Tier 1 missingness: binary inputs retain missing values; district/status exclusions and geographical linkage loss are exported.
- Tier 1 row loss: GP-transition and GP-outcome keys are unique; exclusion and unmatched-link counts remain explicit.
- Tier 1 provenance: the original Stata input is SHA-256 verified, and its assignments match the saved analytical records.
- Tier 1 internal consistency: observed spreads and between/within identities agree to numerical tolerance.
- Tier 2 EDA and skew: minimum-cell and leave-district-out sensitivities expose weak support and geographic influence.
- Tier 2 joins: normalized-name matching and changing boundaries remain measurement limitations; duplicate checks do not validate identity.
- Tier 2 construction: inputs are seat reservations, not winner attributes; SC and ST indicators are separate outcomes.
- Tier 2 inference: the homogeneous benchmark's expected squared spread is independently derived and matches saved Monte Carlo draws.
- Tier 3 design: no actual legal assignment mechanism has been reconstructed; exchangeability is a reference assumption.
- Tier 3 calibration: synthetic homogeneous and heterogeneous cases reproduce analytically known mean variances.
- Tier 4 descriptive branch: no causal coefficient, regression standard error or latent geographic variance is claimed.
- Tier 4 dependence: GPs recur across transitions and block assignments can be dependent; no pooled independent-GP test is reported.
- Tier 4 selection: the matched samples need not represent their states; coverage and exclusion CSVs describe observed selection.
- Inapplicable branches: outcome RD, IV, DiD, psychometric scales and causal machine learning are not estimated in this note.
- Untestable here: historical boundary identity, lawful allocation universes, authoritative quota/rank reconstruction and causal attribution.
- The generic audit_data.py sweep finds no duplicate GP-outcome keys; its differing missingness across prediction fields is retained,
  not repaired by treating missing assignments as unreserved.
  Its heuristic causal warnings are not independent findings.

## Reproducibility

Outputs are under `tabs/note_audit/`: transition and assignment sensitivities, coverage/exclusions, variance partitions,
analytic benchmark checks and synthetic benchmark checks. The CSVs retain full numerical precision.
Manuscript numbers and citations require their own generated-artifact and rendered-page checks after composition.

## Checks prompted by independent review

The production benchmark estimates common probabilities using all linked GPs in a transition,
while spread requires units with both lag groups. The following diagnostic recomputes probabilities
on the latter support and reports the largest absolute difference. It does not change the benchmark estimand.

|state         |check                                             |  value|
|:-------------|:-------------------------------------------------|------:|
|rajasthan     |ambiguous_regular_rows_with_same_year_by_election | 0.0000|
|rajasthan     |maximum_probability_difference_pp                 | 0.1473|
|uttar_pradesh |ambiguous_regular_rows_with_same_year_by_election | 0.0000|
|uttar_pradesh |maximum_probability_difference_pp                 | 0.0226|

The suspected by-election/duplicate collision occurs in neither state's retained source records.
This is a potential behavior of the parser, not a demonstrated number-changing defect in these data.

Prediction disagreements are also described by how many blocks contain them, the share in the ten
highest-count blocks, overlap with caste prediction disagreements, and blocks with equal false positives
and false negatives. These are descriptive diagnostic counts, not evidence of a particular mechanism.

|outcome          | blocks| blocks_with_disagreement| disagreements| top_ten_share| disagreements_in_caste_disagreement| balanced_blocks_with_disagreement|
|:----------------|------:|------------------------:|-------------:|-------------:|-----------------------------------:|---------------------------------:|
|sc               |    823|                      109|           273|        0.3956|                                 273|                                51|
|st               |    823|                       16|            18|        0.6667|                                  18|                                 2|
|women_instrument |    823|                      606|          1214|        0.1079|                                  94|                                83|
|women_prediction |    823|                      627|          1185|        0.1139|                                 174|                               101|
