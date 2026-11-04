# Coding the literature evidence audit

The audit answers three questions: which studies offer empirical evidence for their assignment premise; which departures their diagnostics address; and which accounts of the same procedure disagree. It describes evidence and assumptions, not authors' motives. No missing record is interpreted as an absent test.

Run `make literature` to validate inputs and rebuild the data and report. The build uses committed extraction records and coding sheets; it does not download sources, call an LLM, rerun the election analysis, or require the original PDF collection. The original source URLs, local upstream paths, document hashes, quotations and page locators travel with the derived claims and diagnostics.

## Data and units

- `assignment_claims/*.json`: preserved source-version metadata and passage-level extraction. These are raw evidence for this coding stage, not final judgments about studies.
- `literature_audit/studies.csv`: one underlying study/source family, its preferred source, inclusion decision and grouping rationale. Legal and contextual sources remain traceable but do not enter the empirical-study denominator.
- `source_studies.csv`: exactly one family and version role for each source. A preferred article, its linked supplements and earlier drafts are separate roles. Shared bibliography keys and explicit version correspondences seed the map; provisional families require verification.
- `reviews.csv`: one current completeness and evidence decision per family. This records an accountable review decision, not an automatic keyword classification.
- `diagnostics.csv`: one positive record per source claim and diagnostic type. Several types may be reported by a study. Sample size, number of groups, statistic, null hypothesis, p-value, rejection level and replication status have explicit fields. Uncoded numbers remain blank; descriptive diagnostics use an inapplicable-null label, not a fabricated p-value. Duplicate versions remain visible but never count as separate studies.
- `claim_support.csv`: directed links from an assignment or identification claim to the evidence offered for it. Procedure and identification are different targets. Unlinked claims are unassessed. Own diagnostics must belong to the same family; inherited evidence uses `prior_study` and preserves its source scope.
- `diagnostic_capabilities.csv`: one method-by-target judgment about logical coverage. These are review guidelines, not measured power or judgments that an author's design fails.
- `accounts.csv`: one normalized procedural proposition for a state, election interval, office, category, allocation pool and procedural component. The original passage remains linked. Combined caste categories are not split without evidence. Unknown years stay blank.
- `adjudications.csv`: one decision for a pair of accounts. Candidate differences are distinct from confirmed disagreements and differences resolved by scope or version.

The [generated dictionary](literature_audit_dictionary.md) describes every input column, type and missing count. `schema.json` is the machine-readable schema. CSV files are hand-editable annotations and read with explicit types. Analysis outputs are Parquet and are round-trip checked after writing.

## Denominators and review completion

The main empirical denominator is studies whose own designs use local reservation assignment. It includes different states, municipal and rural offices, and different reservation categories; scope travels with each claim. Studies that only cite reservation research, literature reviews, laws, state policy-rollout designs and other identification designs remain available for account comparisons but are excluded from this denominator. Unclear inclusion stays `pending`. This is a corpus-based review of the collected literature, not a claim to cover every published paper.

For each included family:

1. Verify the family grouping and preferred publication version. Compare earlier drafts when their claims or checks differ; record those differences rather than silently importing an earlier test into the preferred version.
2. Inspect the full article and all relevant supplements, including appendices linked by the publisher. Record unavailable supplements explicitly. `none_verified` means the absence of a relevant supplement was checked, not that the local folder lacked one.
3. Record each identifying premise, its scope, the authors' supporting argument or citation, and every reported diagnostic with page/table locators. Link supporting claims. A legal prescription, institutional argument and cited prior reconstruction are different forms of support.
4. Check the actual diagnostic's sample, period, allocation pool, statistic, covariates, geography and outcome. Update the positive diagnostic record; `rechecked` means checked against the passage, not replicated from data.
5. Set `complete` only after the family, article, supplements and evidence decision are verified. A `no_check_reported` decision requires this completed review and cannot coexist with a positive diagnostic in the preferred source or its linked supplement.

The no-check numerator counts eligible completed reviews with an explicit negative decision. Its reviewed denominator contains only completed eligible reviews. The whole-corpus rate remains missing until every included review is complete and all pending inclusion decisions are resolved. Both denominators and the unknown count are exported. Positive evidence can be reported before a study's exhaustive review is complete; it does not establish absence of other checks.

Earlier-version evidence is counted separately. A claim about a publication cannot be supported silently by a working-paper appendix. A preferred source can itself be a working paper when that is the available source; the version remains explicit.

## Diagnostic coverage and statistical power

Code several diagnostics when appropriate. Pooled balance, transition tests, reconstruction, RD validity checks, quota counts and geographic discrepancy summaries address different questions. The method-target matrix distinguishes direct, partial and untargeted coverage. The derived study-target table combines the diagnostics located so far and records review completeness.

Do not classify an entire paper as unable to detect a departure because one of its tests is untargeted. Other tests may address it. A test can target geographic variation but still have low power. Conversely, an RD validity check can be relevant to the paper's local estimand without testing statewide procedural uniformity.

Estimating detection probabilities is a subsequent empirical task: obtain the exact study sample, allocation constraints, statistic and rejection rule; specify a departure; simulate both the stated null and alternatives; estimate size and power with Monte Carlo uncertainty. Use matched departures and sample sizes, not the method label alone. The current pipeline does not fabricate power values or a prevalence estimate of inadequate diagnostics.

## Comparing procedural accounts

Candidates must concern different study families and agree on state, office, reservation category and procedural component. Known election intervals must overlap. Missing intervals and mismatched or unresolved pools stay candidates for reconciliation. Population shares versus totals is an initial Rajasthan candidate, not an adjudicated legal finding.

Before marking `confirmed_disagreement`, verify both scopes, publication versions, the overlapping period, pool and conditional wording. Determine whether a rule changed, whether a passage describes selection versus an identifying approximation, and whether caste eligibility explains apparent differences. Record the resolution and reviewer. Confirmation is blocked for unmatched pools, unknown dates or provisional scope. Legal comparisons and same-study version changes can be reviewed separately; the cross-study candidate generator deliberately excludes within-family pairs.

Normalized-account coding is currently partial. Counts of candidate pairs are not counts of disagreeing papers or a disagreement rate. Uncoded claim scopes cannot be treated as agreement.

## Joins, missingness and provenance

Sources are the left-hand universe for the source-to-study mapping: every source appears exactly once. Claims join sources and families many-to-one without changing row counts. Diagnostic rows join claims many-to-one. Diagnostic-target expansion deliberately has three rows per diagnostic. Study summaries use distinct family identifiers. Candidate account pairs are unordered, unique pairs; duplicate reversed adjudications are rejected.

Missing diagnostic counts are filled with zero only as counts of coded records. `has_reported_check` remains missing unless a positive check is located or a complete review explicitly finds none. Blank election endpoints mean unresolved coverage, not zero, an open-ended claim through today, or permission to declare overlapping scope verified. No substantive source values are inferred to complete a join.

Each build writes `input_manifest.csv` with SHA-256 hashes of the extraction, annotations, schema and producing R code. Generated data are in `data/build/literature_audit/`; the review queue and comparisons also have CSV views. Edit committed reference inputs rather than generated files. Existing parser/hash validation of original literature PDFs remains available through `make claims` when the upstream collection is present.

The claim-level coding queue includes all extracted claims, including claims in excluded contextual sources. Its flags describe coding coverage only; some diagnostic or legal records do not need an assignment-account row. The comparison-evidence output puts both sides of each candidate alongside quotations, paraphrases, page numbers, scope, document version and source URL. These are review datasets, not an appendix dump for the paper.
