# Assignment-claim review

Reviewed on 3 November 2026. The note's claim appendix contains 130 claim records from 64
source versions, including dispositions for all 48 upstream literature PDFs and
all 23 study entries. Thirty-nine records contain short verified excerpts; the
other records paraphrase located passages or document inaccessible sources.

The extraction review checked source pages, source hashes, version identity,
scope, qualifications, and the distinction between identification assumptions
and implementation evidence. An independent agent review prompted five fixes:

- The main comparison now selects explicit claim IDs and retains versions and
  qualifications, including the qualifications in Green–Singh–Sood's body and SI.
- Empty qualifications and generic contradiction fields were replaced with
  scoped limitations and prospective falsifying observations.
- Two claims requiring historical inputs were removed from the ready category.
  Supplied-prediction agreement and independent legal reconstruction are separate.
- Locally supplied drafts retain their access/noncirculation status, reproduce
  no quotations, and do not enter the main comparison.
- Deininger and coauthors' 2020 and 2022 evidence is attached to separate versions.

`make check` passed lint and 88 assertions. `make paper` passed the numerical audit,
source-coverage and hash checks, claim-schema and citation-key checks, and both
LaTeX builds. Rendered pages were inspected; final logs contain no undefined
citations or overfull boxes. Tables use knitr and kableExtra.

Biber parsed and checked all four bibliography files together. The only remaining
data-model warning is the missing year for the undated Karekurve-Ramachandra–Sood
working paper. Its note explicitly says it is undated; no year was inferred.
Version-specific metadata and source locations remain in the inventory even when
multiple versions share a published-paper bibliography key.

A read-only Claude review was attempted. The sandboxed attempt reported no login;
the escalated attempt could not reach its API server (`ENOTFOUND`). No substantive
Claude review was completed. The independent agent review above was completed.

The inventory does not establish that a claim is empirically false. Ten records
support a current-data comparison, 54 need additional inputs, 60 are outside the
current geographic or temporal coverage, and six do not specify a unique test.
Three source documents remain inaccessible for the relevant evidence. The next
stage should begin with the scoped comparisons in `assignment_claims.md`, then
reconstruct historical allocation pools and inputs before interpreting residuals
as departures from a legal procedure.

On 4 November 2026, the full claim inventory was incorporated into the paper as
an appendix. The build now produces one manuscript PDF, including all claim
records and one shared bibliography.

The reader-facing revision on 4 November replaces the full record appendix with
28 study/version quotation entries and a separate table of official provisions.
Internal identifiers, extraction notes and repository details remain in the
machine-readable audit. Printed and PDF page numbers appear with excerpts;
links distinguish direct PDFs from article or source pages. The J-PAL copy of
Chattopadhyay–Duflo was checked against its published pagination (1414, PDF 6).

The final presentation consolidates the literature comparison and quotation
appendix into one main-text table with ten study/version entries. Selection
covers distinct assignment mechanisms, reconstruction evidence, documented
discrepancies and qualifications. The official-provision table remains in the
appendix, and the full extraction inventory remains in the repository.
The Das–Mukhopadhyay–Saroy lottery setting is Rajasthan, 2010; this corrects an
incorrect Uttar Pradesh display label in the earlier comparison table.

The subsequent Chauchard correction incorporates Online Appendix B, omitted from
the earlier extraction. Table B.2 (p. 9) checks 570 GPs in 16 Samitis, reports 61
period discrepancies (10.70%) and 21 discrepancies more than one percentage point
from the predicted SC-share cutoff (3.68%). Page 10 reports that none of the survey
GPs meet the latter definition. The main table now distinguishes the 64-GP survey
sample from this reconstruction sample and reports the Samiti-level range. These
are SC assignment results. The publisher supplement's SHA-256 is recorded in the
inventory; Table B.2 was visually checked. Appendix district labels include Jalore,
whereas main-text footnote 19 names Barmer; that source inconsistency is recorded
without inferring a reconciliation. The table separates citation and setting,
uses landscape pages, removes inline source-link labels, and replaces editorial
judgments with reported evidence. Document links appear in the references.
