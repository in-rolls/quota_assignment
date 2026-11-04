# Literature evidence audit

This is an initial coding dataset, not a completed review of the literature.

65 source versions map to 50 study/source families; 131 claims are retained without dropping context.
37 families are included, 11 excluded, and 2 await a scope decision.
37 positive diagnostic records are coded. 19 eligible study families have a located check in the preferred source or its linked supplements.
0 eligible studies have completed reviews. The no-check rate for the corpus is not yet estimable.

0 of 50 family mappings are verified; the remaining groupings are provisional.

Evidence in an earlier draft is retained separately. Missing diagnostic records mean unknown, not no test.
The preferred version may itself be a working paper; publication/version checks remain part of the review.

## Scope and denominators

|inclusion | study_families|
|:---------|--------------:|
|excluded  |             11|
|included  |             37|
|pending   |              2|

The empirical denominator concerns designs using local reservation assignment. Legal provisions, reviews,
state implementation timing and unrelated identification designs remain in the claims data but are excluded
from that denominator. Family decisions and exclusions are explicit in the editable inputs.

## Diagnostics located

These counts describe positive extraction records, not exhaustive classifications. Methods overlap.
A rechecked passage is not an independently reproduced empirical result.

|Diagnostic                | Studies with extracted evidence| Studies with rechecked passages|
|:-------------------------|-------------------------------:|-------------------------------:|
|Assignment reconstruction |                               5|                               1|
|Covariate balance         |                              12|                               1|
|Geographic discrepancies  |                               1|                               1|
|Quota counts              |                               1|                               0|
|RD covariate continuity   |                               1|                               0|
|RD density                |                               1|                               0|
|Transition dependence     |                               4|                               0|

## Procedural comparisons

12 scoped accounts generate 3 candidate pairs and 0 recorded confirmed disagreements.
Account coding is incomplete. Zero confirmed disagreements is not evidence that the literature agrees.
Differences are matched on state, office, category and procedural component. Nonoverlapping known election
periods are excluded. Unknown periods or different pools remain candidates requiring scope reconciliation.
Confirmation requires verified overlapping periods, matching pools, checked versions and a written adjudication.

## What the diagnostics can detect

The capability matrix records logical targets, not power or proof of validity. A paper can have several methods.
The study-target output combines located methods without treating an unreviewed paper as having no other test.
Paper-specific power against geographic heterogeneity requires its sample, statistic and assignment benchmark;
no detection probability or fraction of inadequate papers is imputed from a method label.

## Reproduce and extend

Run `make literature`. Inputs are in `data/reference/literature_audit/`; original quotations and locators remain
in `data/reference/assignment_claims/`. [Coding protocol and dictionary](literature_audit_protocol.md).

Typed Parquet files, an input SHA-256 manifest, and editable-view CSV review queues are written to
`data/build/literature_audit/`. Edit the reference coding sheets, never generated outputs.
The manuscript's illustrative quotations are separate from this corpus-wide audit; no final prevalence
estimate is inserted into the paper before the required reviews are completed.
