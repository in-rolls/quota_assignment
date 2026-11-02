# High agreement and geographic disagreement

UP's 2015 assignments can agree with the authors' predictions about 98% of the
time while the remaining disagreements concentrate geographically. This audit
measures that concentration in the Chaturvedi, Das and Mahajan replication file.
It is a descriptive residual analysis relative to supplied predictions. It does
not establish that those predictions perfectly encode the operative legal rules.

## Source and variables

The [published paper](https://doi.org/10.1086/729342), pp. 760–763, describes
block-specific caste and women's reservation algorithms, reports almost 98%
predictability of female reservation, and checks the RD first stage, density and
covariate balance. Its caste population inputs came from the UP State Election
Commission. The [replication archive](https://doi.org/10.7910/DVN/Z6RRUE) supplies
the local file `quota_sanitation/data/final election caste sbm.dta`, pinned in
`assignment_source_lock.json`. No modern village-GP matching is used in this audit.

| Construct | Source column | Treatment |
|---|---|---|
| GP | `eleid` | Must be unique and nonmissing |
| Geography | `district`, `block` | Numeric election codes; block identity is nested in district |
| Women's observed reservation | `womenreservation` | Binary; missing retained |
| Women's primary predicted assignment | `femaleinstrument` | Supplied RD instrument; never replaced with winner gender |
| Women's alternative predicted assignment | `women_reserv_pred` | Separate supplied-prediction sensitivity |
| Observed caste reservation | `caste_reserved` | SC, ST, OBC, Unreserved; blank is missing |
| Predicted caste reservation | `caste_reserved_pred` | Same categories; SC and ST indicators evaluated separately |

There are 59,162 source rows. All four comparisons have 57,555 observed GP
assignments with geography in 75 districts and 823 nested blocks. The 1,607 rows
without observed assignment/geography remain in the coverage output. The file
has several prediction fields. Their construction has not been independently
reproduced; agreement with them is not independent evidence that the historical
algorithm was correctly specified. The primary women's variable is the instrument
used in the authors' analysis, with the named prediction field as a sensitivity.

## Quantities reported

The mismatch indicator is one when observed and predicted binary reservation
differ. Its mean uses all observed GPs as the denominator, including those that
both measures classify as unreserved. The local report also gives a rate among
the union of observed-reserved and predicted-reserved GPs. This matters for ST:
its low statewide mismatch rate partly reflects how rare ST reservation is.
False-positive and false-negative counts are saved separately.

District rates are calculated directly. Block rates are calculated within each
nested block. Their spread uses the population weighted-variance formula, with
both equal-unit and GP-count weights. Each weight convention is a different
estimand; neither weight convention makes a small unit as informative as a large
one. The block variance is partitioned into variation between district averages
of block rates and variation among blocks within districts. Under equal-block
weights, the between-district component weights each district by its number of
blocks; it is distinct from the separately reported equal-district spread.

These are observed rate variances. In particular, `between_district_share` is not
a noise-adjusted estimate of the fraction of latent heterogeneity explained by
districts. No fitted posterior means or R-squared are substituted for that
quantity.

## Concentration benchmark

The reference distribution randomly reallocates the observed number of mismatch
indicators within strata, preserving GP geography and stratum totals. Women's
strata are observed caste category crossed with the predicted female indicator.
SC and ST strata are the supplied predicted caste category. This controls the
reference comparison for different observed category/prediction compositions
across administrative units. The seed is fixed and there are 999 permutations.

This is a benchmark for exchangeable prediction errors, not the null of correct
legal assignment. It does not preserve local reservation quotas, model spatially
correlated measurement error, or simulate a joint allocation of mutually exclusive
caste categories. SC and ST are evaluated separately. Its middle 95% is a
reference interval, not a confidence interval for observed spread. A larger
observed spread establishes concentration relative to that reference; it does
not identify deliberate manipulation or bureaucratic discretion. Correlated
prediction errors, data construction and administrative exceptions can produce
the same finding.

The generated report contains both predictor variants, both caste categories,
raw counts, geographic rates and the reference spreads. The README draws its
table directly from these outputs. `make assignment` reproduces the audit;
`IN_ROLLS` can point to another source checkout with the same pinned file.
No spending or sanitation outcomes enter the analysis.

## Relation to the multi-cycle analysis

The supplied 2015 predictions make a useful first residual audit possible now.
They do not resolve the historical population rosters, category priority, resets
and rotation histories for all Rajasthan and UP cycles. The separate
[Census/GP build](caste_data.md) and [rule reconstruction design](caste_design.md)
address those requirements. Claiming unexplained variation after all documented
rules would require that reconstruction and validation, plus sensitivity to
source and linkage errors.
