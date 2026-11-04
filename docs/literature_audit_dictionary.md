# Literature audit data dictionary

CSV schemas are enforced by schema.json: character IDs/labels, integer counts/years and double probabilities.
Blank fields are missing, never zero. Election bounds and diagnostic numbers may be unresolved or inapplicable.

|table                   |column                |type      |meaning                                                                                      | missing|
|:-----------------------|:---------------------|:---------|:--------------------------------------------------------------------------------------------|-------:|
|studies                 |study_id              |character |Unique underlying-study identifier; primary legal sources also receive an identifier.        |       0|
|studies                 |title                 |character |Display title of the selected source version.                                                |       0|
|studies                 |inclusion             |character |Empirical local-assignment denominator: included, excluded, pending.                         |       0|
|studies                 |inclusion_reason      |character |Evidence and reason for the scope decision.                                                  |       0|
|studies                 |primary_source_id     |character |Preferred source version; source_id in the extraction inventory.                             |       0|
|studies                 |family_status         |character |provisional or verified; provisional grouping is not a final paper denominator.              |       0|
|studies                 |family_note           |character |Reason for grouping versions; historical estimates remain version-specific.                  |       0|
|source_studies          |source_id             |character |Unique source version in the extraction inventory.                                           |       0|
|source_studies          |study_id              |character |Study family foreign key.                                                                    |       0|
|source_studies          |version_role          |character |primary, linked_supplement, earlier_version; primary source selected in studies.             |       0|
|source_studies          |mapping_basis         |character |Explicit version-link rationale; no fuzzy matching at build time.                            |       0|
|reviews                 |study_id              |character |One current review decision per study family.                                                |       0|
|reviews                 |review_status         |character |not_started, in_progress, complete.                                                          |       0|
|reviews                 |main_text_status      |character |extracted, checked, unavailable.                                                             |       0|
|reviews                 |supplement_status     |character |not_checked, checked, none_verified, unavailable.                                            |       0|
|reviews                 |no_check_status       |character |not_assessed, check_reported, no_check_reported.                                             |       0|
|reviews                 |reviewer              |character |Person or system responsible for the coding decision.                                        |       0|
|reviews                 |reviewed_on           |character |ISO date of annotation.                                                                      |       0|
|reviews                 |review_note           |character |Scope of completed work and outstanding document checks.                                     |       0|
|diagnostics             |diagnostic_id         |character |Unique positive diagnostic record; one claim may support several diagnostics.                |       0|
|diagnostics             |claim_id              |character |Foreign key to exact passage and source version.                                             |       0|
|diagnostics             |diagnostic_type       |character |Controlled method key in diagnostic_capabilities.                                            |       0|
|diagnostics             |geographic_resolution |character |Reported resolution or not_coded; does not imply statewide coverage.                         |       0|
|diagnostics             |coding_status         |character |extracted or rechecked; rechecked means source passage checked, not replication.             |       0|
|diagnostics             |coding_note           |character |What was inspected and what this record establishes.                                         |       0|
|diagnostics             |reviewer              |character |Coder identifier.                                                                            |       0|
|diagnostics             |reviewed_on           |character |ISO coding date.                                                                             |       0|
|diagnostics             |sample_size           |integer   |Number of units in this diagnostic; blank means not yet coded or not reported.               |      35|
|diagnostics             |n_groups              |integer   |Number of geographic groups used by this diagnostic; blank means unresolved or inapplicable. |      35|
|diagnostics             |statistic             |character |Reported statistic or descriptive measure; not_coded until inspected.                        |       0|
|diagnostics             |null_hypothesis       |character |Authors’ tested null, not_coded, or not_applicable_descriptive.                              |       0|
|diagnostics             |reported_p_value      |double    |Reported p-value on [0,1]; blank means unresolved or inapplicable.                           |      36|
|diagnostics             |rejection_level       |double    |Authors’ stated rejection threshold on (0,1); blank means unresolved or inapplicable.        |      37|
|diagnostics             |replication_status    |character |not_attempted, reproduced, or discrepancy; source inspection is not reproduction.            |       0|
|diagnostic_capabilities |diagnostic_type       |character |Method key; combined with target forms the primary key.                                      |       0|
|diagnostic_capabilities |label                 |character |Reader-facing method name.                                                                   |       0|
|diagnostic_capabilities |target                |character |geographic_heterogeneity, serial_dependence, algorithm_agreement.                            |       0|
|diagnostic_capabilities |coverage              |character |direct, partial, not_targeted; logical scope, not a power estimate.                          |       0|
|diagnostic_capabilities |rationale             |character |Reason for scope judgment; paper-specific design can alter this judgment.                    |       0|
|accounts                |account_id            |character |Unique scoped procedural proposition.                                                        |       0|
|accounts                |claim_id              |character |Source passage foreign key.                                                                  |       0|
|accounts                |state                 |character |Normalized state identifier; one state per row.                                              |       0|
|accounts                |cycle_start           |integer   |First election year explicitly covered; blank means unresolved.                              |       3|
|accounts                |cycle_end             |integer   |Last election year explicitly covered; blank means unresolved, not current year.             |       5|
|accounts                |office                |character |Office being allocated; gp_head in current coding.                                           |       0|
|accounts                |category              |character |Exact reservation category; combined categories not silently split.                          |       0|
|accounts                |pool                  |character |Allocation pool; not_resolved means scope cannot be confirmed.                               |       0|
|accounts                |component             |character |Aspect being compared, such as ranking_measure or selection.                                 |       0|
|accounts                |value                 |character |Normalized substantive description, retained alongside original wording.                     |       0|
|accounts                |scope_status          |character |provisional or verified; verified requires source/version and scope checking.                |       0|
|accounts                |scope_note            |character |Evidence and unresolved scope conditions.                                                    |       0|
|adjudications           |account_left          |character |First account ID; pair order is canonicalized by pipeline.                                   |       0|
|adjudications           |account_right         |character |Second account ID.                                                                           |       0|
|adjudications           |status                |character |candidate, resolved_difference, confirmed_disagreement.                                      |       0|
|adjudications           |scope_review          |character |pending or complete; complete required for confirmation.                                     |       0|
|adjudications           |reason                |character |Evidence for resolution, including period, pool, version and conditional rules.              |       0|
|adjudications           |reviewer              |character |Reviewer identifier.                                                                         |       0|
|adjudications           |reviewed_on           |character |ISO date.                                                                                    |       0|
|claim_support           |claim_id              |character |Assignment or identifying claim being supported.                                             |       0|
|claim_support           |supporting_claim_id   |character |Claim recording the supporting evidence or cited account.                                    |       0|
|claim_support           |support_type          |character |own_diagnostic, prior_study, legal_text, institutional_argument.                             |       0|
|claim_support           |target                |character |procedure or identification; balance does not validate a literal allocation algorithm.       |       0|
|claim_support           |coding_status         |character |extracted or rechecked.                                                                      |       0|
|claim_support           |note                  |character |Scope of the evidentiary link; unlinked claims remain unassessed, not unsupported.           |       0|
