# How much do reservation rules explain?

The target is the size and geographic concentration of departures from documented
reservation rules across election cycles. A statewide balance test or a visible
assignment discontinuity can coexist with considerable district and block
variation. Earlier studies have examined assignment, sometimes at those levels;
our comparison must specify the rule, universe and diagnostic each study used.
See the [evidence ledger](caste_literature.md).

SC is the primary category; ST is a separate secondary analysis. The outcome is
reservation of the GP head's office, not the caste of the winner. This stage
studies assignment and does not estimate effects on spending or other outcomes.
The women's results and all exploration already conducted are known. This is a
retrospective analysis plan, not a blinded preregistration.

## What is implemented

`make caste` verifies pinned input hashes, constructs Census 2001 and 2011
population aggregates on the official 2024 GP mapping, joins elections, and writes
SC and ST population-share plots and district/block ordering diagnostics. Both
Census vintages are exploratory measurements; neither is automatically designated
the administrative population used in an election. GP totals sum constituent
population counts before dividing. They are never averages of village shares.

A share-order discrepancy occurs when a reserved GP has a lower category
population share than an unreserved GP in the same observed district or block.
The denominator is all such cross-status pairs with unequal shares. Ties are
excluded. A rotating rule can produce many discrepancies while being followed
perfectly. These are unadjusted descriptive statistics, not misallocation rates.
A large pair count is not a large independent sample: each GP enters many pairs.
No binomial standard errors or significance classifications are attached to them.

The full contemporary GP catalog is retained before matching elections. Its
within-district rank bounds allow for ties and missing population. Ranks are
withheld where conflicting district membership makes even that catalog uncertain.
These ranks describe the modern catalog. They are not historical assignment ranks.
The LGD files contain subdistrict identifiers but no complete block roster;
subdistricts are not substituted for blocks. No block policy ranks are constructed
from the selected matched sample.

## What a rule reconstruction must establish

For each state, election, category and allocation pool, obtain the complete
historical GP roster, constituent villages, administrative population vintage,
quota, category priority, eligibility exclusions, earlier reservations since the
applicable reset, and rounding/tie procedures. Preserve the actual orders and
source references. Scheduled-area provisions and boundary changes require their
own checks. Neither an observed reservation count nor a best-fitting cutoff is an
independently verified quota.

`score_top_share_assignment()` implements only a descending-share top-K rule among
an externally established eligible pool. It requires a complete roster size,
quota and source references, plus category and allocation-pool metadata. It does
not reconstruct eligibility, handle list wraparound automatically, or certify a
rule merely because a source string was supplied. Use it only after establishing
that this rule form applies to that pool and cycle. Its output distinguishes
agreement, disagreement, missing observed assignment and unresolved cutoff ties.
Unknown observations remain in the ranking universe. Ties at the cutoff remain
unclassified rather than being resolved by row order.

For rotating lists with wraparound, sequential SC/ST allocation, or other rule
forms, a separate verified reconstruction is required. We do not yet have the
historical rosters and orders needed to run a defensible empirical compliance
analysis. The evidence ledger records the known rule provisions and unresolved
historical applicability. In particular, neither the 2024 LGD mapping nor a stable
GP name proves unchanged election-year boundaries.

## Residual variation, once assignment is reconstructed

Report the fraction of observed assignments inconsistent with the verified rule,
with the fraction unclassifiable beside it. Separate reserved-when-ineligible and
eligible-but-skipped cases. Report absolute distances from externally established
cutoffs, not just counts. When several administrative reconstructions remain
plausible, report lower and upper disagreement bounds across them; an ambiguous
case is not evidence of discretion.

Estimate district variation directly and block variation nested within district.
Use the same GP/cycle support to compare a rule-only prediction with one that
adds geography. For a probabilistic allocation rule, the residual is observed
reservation minus its rule-implied probability. Simulate allocations using the
actual pool sizes, quotas, exclusions, rotation and lottery dependence. Compare
the observed geographic spread with this reference distribution; independently
permuting seat labels would discard those constraints.

For a deterministic rule, a complete enumeration's mismatch rate is a descriptive
population quantity. There is no assignment-sampling error under perfect
compliance. A hierarchical binomial model of disagreement would instead describe
a hypothetical repeated implementation process. State that estimand explicitly,
allow district and nested block effects, and examine GP dependence across cycles.
Report posterior probability-scale spreads and their intervals, alongside raw
rates and denominators. Partition block variance into between-district and
within-district components within each draw, under both equal-block and seat
weights. Do not report the variance of posterior means as the latent variance.

Evaluate partial pooling and interval coverage in simulations with homogeneous
compliance, district departures, block departures, rare ST reservations, and
linkage loss correlated with both geography and reservation. Compare fits across
population vintages and credible linkage/boundary restrictions. The current
unit tests check construction and scoring; they are not that coverage study.
No independently reconstructed multi-cycle residual-variation estimate is available yet.
The separate [UP 2015 audit](assignment_residuals.md) measures disagreements with
the authors' supplied predictions, including geographic concentration benchmarks.

## Assignment discontinuities

Plot observed assignment against rule-based rank or population distance within
the actual eligible pool, using independently reconstructed cutoffs. Display pool
sizes, missing assignments and ties. A population cutoff that changes with quota
or rotation must be defined separately by pool and cycle. Discrete ranks require
attention to their limited support. A fitted jump alone neither proves random
assignment nor identifies deliberate manipulation. Any later outcome RD needs
additional continuity and exclusion assumptions beyond this assignment audit.
