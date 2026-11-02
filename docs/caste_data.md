# Caste data and joins

Inputs are fixed by SHA-256 in `caste_source_lock.json`. `IN_ROLLS` locates the
collection repositories; `SHRUG` locates version 2.0. Election masters use the
existing `source_lock.json` and `LOCAL_ELECTIONS`. Source files are read only.
Upstream repository URLs and commits are recorded alongside the hashes. See
[input setup](inputs.md) for public source links and checkout commands.
Generated analysis outputs go under `data/build/caste/`, `tabs/` and `figs/`.

## Row definitions and fields

| Output | Row and key | Important fields |
|---|---|---|
| `*_gps.parquet` | One official 2024 GP code, including unresolved GPs | `gp_code`, source names and district code; counts `population`, `sc_population`, `st_population`; proportions `sc_share`, `st_share`; `census_year`, `geography_year`; completeness/status fields |
| `*_catalog_entries.parquet` | Distinct GP/name/district source combinations | Retains conflicting catalog memberships rather than selecting one |
| `*_geography.parquet` | Census village–SHRID–candidate GP relation | `geography_status`; deliberately allows multiple mappings to diagnose ambiguity |
| `*_villages.parquet` | Official LGD source relation, with a Census key if found | `has_census_key`; includes villages with missing Census codes and missing GPs |
| `*_constituents.parquet` | One SHRID per geographically resolved GP | Unmasked SHRUG counts and population-screen flags; use `gps`, not these partial components, for analysis |
| `*_links.parquet` | One source election row per wave | `link_status`, source reservation indicators, method, provenance and unresolved historical-continuity flag |
| `*_catalog_ranks.parquet` | One GP in the full modern catalog | Within-district `rank_lower` and `rank_upper`, including missing competitors/ties; never historical policy ranks |
| `*_geography.csv` | One observed district or nested block, cycle and category | Valid linked seats; reserved seats; dependent cross-status pair counts and unadjusted share-order discrepancy fraction |
| `*_bins.csv` | One five-percentage-point population-share bin and source cycle | Mean share, reservation fraction and number of observed linked seats |

Counts are persons and may be fractional after SHRUG processing. Shares lie
between zero and one. Missing counts stay missing, never zero. Source GP and
village codes remain strings. A Census village code of `000000` or an empty
field is missing. A zero-population GP has no defined population share.

## Join contract

1. The full official GP catalog is the population universe. A village key must
   identify one SHRID. A SHRID can contain several villages; each must map to the
   same GP, with no missing or urban constituents. Every listed GP village must
   have a Census key. Any violation withholds the GP population. A GP with
   conflicting catalog names or districts is retained with unavailable population.
2. Each geographically resolved SHRID is counted once. Its population record
   must be unique. All constituent records must have finite nonnegative counts,
   SC plus ST no larger than total population, zero supplied mean/core missingness
   and target weight share equal to one. The GP must have positive total population.
   These screens do not reverse upstream imputation.
3. Master elections are filtered to GP heads and the configured general-election
   cycles. Matching uses normalized district and GP names. Where present, master
   Latin transliterations are used and labeled as such. Both sides must be unique
   within the cycle; block names must be present. Exact normalized strings are not
   manually validated historical identity. All rejected election rows are retained.
4. Weaver is a separate source sensitivity, never stacked with master elections.
   Use only the March 17, 2025 wide release and its supplied LGD21 GP code against
   LGD24. Duplicate GP codes within a wave are rejected. Source district/block
   codes define descriptive groups. Missing group codes remain excluded.
   The original SHRID is retained but not joined to SHRID2: their versions differ.
   The source-labeled 2020 wave is explicitly unverified and not renamed 2021.

Caste is coded from the seat's `reserved_caste`: SC→SC indicator 1, ST→ST
indicator 1, other observed categories→0; missing categories→missing. Weaver's
supplied SC/ST indicators are used directly and checked as binary. Candidate or
winner caste is never substituted for seat reservation. Ambiguous names, missing
reservation and unresolved populations are not repaired to increase coverage.

Coverage tables are written by cycle, district, block, reservation status and
exclusion reason. The population catalog also retains GPs that never match an
election. Regional linkage differences must be assessed before comparing regional
assignment patterns. Failed exact-name linkage is not evidence that the GP did
not exist. Changes in Rajasthan's district boundaries make this particularly
important.

## Validation and publication

Tests cover count conservation, shared and urban SHRIDs, missing constituent
villages, incomplete populations, ties and missing competitors, and rule scores
under compliant, deliberately changed and missing assignments. The actual build
checks input hashes and join cardinality and writes audit relations for inspection.
The separate [UP 2015 audit](assignment_residuals.md) uses supplied author
predictions without independently rebuilding their allocation roster.
No empirical allocation roster in the modern LGD build currently passes the historical identification
requirements; the top-share scorer is exercised on synthetic fixtures only.

The independent review requested explicit provenance on standalone summaries,
a narrowly named top-share scorer, and a warning that pair counts are dependent.
Those points are incorporated. Full simulation coverage validation of a residual
hierarchical model remains future work.

The Weaver source files and shared wide panels are published in
[local_elections_up](https://github.com/in-rolls/local_elections_up/tree/main/data/reference/weaver).
This build reads that upstream repository and keeps analysis-specific linked
records under `data/build/`. SHRUG inputs retain their CC BY-NC-SA terms and
source-sharing requirements; the repository's code license does not relicense
its inputs.
