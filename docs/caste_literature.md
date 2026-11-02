# Evidence on allocation rules

Earlier studies test aspects of assignment. The extension asks how much variation
remains after reconstructing the applicable rules, and how that variation is
concentrated by district and block across cycles. The distinction is the estimand
and coverage, not a claim that previous authors ignored implementation.

Read on 1 November 2026. Page references below use the printed paper or appendix
pages. The ledger concerns assignment sections; it is not a replication or an
audit of these papers' outcome estimates.

| Study and source | Universe and allocation mechanism | Assignment checks read | Implication for this project |
|---|---|---|---|
| [Chauchard, APSR 2014](https://www.simonchauchard.com/wp-content/uploads/2014/02/APSR2014.pdf), pp. 7–8, Table 1; [Appendix B](https://static.cambridge.org/content/id/urn%3Acambridge.org%3Aid%3Aarticle%3AS0003055414000033/resource/name/S0003055414000033sup001.pdf), pp. 5–11 | Rajasthan SC sarpanch reservation. Survey: 64 GPs, 32 matched pairs, 16 samitis in four districts; Jalore illustrates the rule. Descending SC shares with rotation from 1995. | Appendix B examines timing disagreements against Census 2001 rankings and a second measure more than one percentage point from the local threshold. It discusses alternative Census vintages, household versus person counts, rounding and redistricting. | Compare many pools and cycles, retaining these sources of uncertainty. The appendix already recognizes implementation ambiguity; a modern population-rank inversion alone does not contradict its findings. |
| [Dunning and Nilekani, APSR author copy](https://www.thaddunning.com/wp-content/uploads/2012/12/Dunning-and-Nilekani_APSR_Dec-2012_For-Web.pdf), pp. 20–22, Table 2 | 512 selected councils across Karnataka, Rajasthan and Bihar; 148 in Rajasthan. Selection follows state-specific SC/ST ranking and reservation thresholds using Census 2001. | Pooled and state-specific covariate balance; discussion of varying implementation imperfections across subdistricts and balance in subsets with different implementation quality. | The text describes population totals for Rajasthan/Bihar, whereas Chauchard describes shares. Resolve the applicable orders and operational practice before selecting a ranking variable. Do not collapse the three states' mechanisms into one. |
| [Das, Mukhopadhyay and Saroy, JEBO 2023](https://sabyasachidas.in/wp-content/uploads/2023/08/1-s2.0-s0167268123002925-main.pdf), identification section, Tables 1–2 and D1 | Rajasthan 2010 OBC reservation, after SC/ST allocation; the analytical sample has 5,002 GPs. The paper describes a lottery among the remaining GPs. | Balance with block fixed effects, including interactions and subsamples by non-SC/ST population share. | This is a sizeable study, not a tiny sample. Balance conditional on blocks does not estimate the distribution of departures from reconstructed assignment across blocks and cycles. OBC lotteries are a separate mechanism from SC population ranking. |
| [Chaturvedi, Das and Mahajan, EDCC 2025](https://doi.org/10.1086/729342), pp. 760–763, Figure 1; local published PDF in `quota_spending/lit/papers/` | UP 2015, roughly 59,000 GPs; caste and female allocation reconstructed using SEC caste population inputs. Allocation resets after delimitation. | Reports almost 98% prediction of female assignment, an RD first stage, density test, covariate balance and pre-period outcome checks. | A direct comparison: use the locally available [replication archive](https://doi.org/10.7910/DVN/Z6RRUE) to measure geographic concentration of disagreements with supplied predictions. The near-cutoff outcome sample is smaller than the statewide assignment universe; do not conflate them. |
| [Narasimhan and Weaver, working paper](https://fass.nus.edu.sg/ecs/wp-content/uploads/sites/4/2023/11/Polity-size-and-local-government-performance-evidence-from-India.pdf), Appendix OA.2, pp. 80–81; [published AER 2024](https://doi.org/10.1257/aer.20221712) | UP GP delimitation in 1995 and 2015 using a 1,000-person village threshold; not a caste-reservation threshold. | District-specific first stages, classification of weak/noncompliant districts, changes across delimitation rounds, and explanations involving population viability and contiguity. | It already examines geographic implementation differences at scale. Our contribution must concern reservation assignment and residual magnitude beyond documented constraints, not novelty of district heterogeneity itself. |

The local published Chaturvedi–Das–Mahajan paper was read alongside the records
in `quota_spending/lit/`. Its public replication inputs are available locally in
`quota_sanitation`, enabling the [supplied-prediction audit](assignment_residuals.md).

The 2017 [IZA version of Das and coauthors](https://docs.iza.org/dp11093.pdf) was
consulted first; the ledger uses the published 2023 paper. Weaver's local files
were supplied directly in March 2025 and are not the published replication
archive. The March 17 vintage supplies the Census identifiers; the March 2
vintage is not merged into it.

## Official provisions and historical gaps

| Source | Provision read | What is still needed |
|---|---|---|
| [Rajasthan Panchayati Raj (Election) Rules, 1994, IndiaCode copy](https://upload.indiacode.nic.in/showfile?actid=AC_RJ_83_1129_00001_00001_1563516015325&filename=the_rajasthan_panchayati_raj_%28election%29_rules%29%2C_1994.pdf&type=rule), Rules 7–9 | Rule 7 uses descending SC/ST population percentages, excludes shares below 5%, and continues and restarts rotating lists. Rule 8 addresses overlapping SC/ST claims. Rule 9 determines sarpanch quotas within a samiti and refers allocation to Rule 7. | Election-specific amendments/orders, quota rounding, applicable population roster, tie handling, category overlap, scheduled areas, historical boundaries and reset history. This compilation is not established as the operative text for every year in our panel. |
| [UP reservation rules, IndiaCode extract](https://upload.indiacode.nic.in/showfile?actid=AC_UP_88_486_00001_00001_1594709414384&filename=ilovepdf_merged-1.pdf&type=rule), Rules 2–3 | The readable extract supplies definitions and quota rounding; it is insufficient to reconstruct the full Rule 5 office-allocation procedure. | Obtain the full applicable Rule 5 and historical amendments, block rosters and reservation orders. |
| [UP Twelfth Amendment, 17 March 2021](https://upprd.in/ShashnadeshDocuments/%E0%A4%85%E0%A4%A8%E0%A5%81%E0%A4%AD%E0%A4%BE%E0%A4%97-3/17-03--2021.pdf) | Defines the previous election as the 2015 general election and subsequent general elections. | Establish which preceding orders were superseded and apply the final election-year rules. Do not carry a 1995 baseline mechanically into 2021. |

## Population and geography

[SHRUG's key documentation](https://docs.devdatalab.org/Using-the-SHRUG/how-to-use-shrug-keys/)
explains that several Census villages can map to one SHRID. We require every
constituent to resolve to a single GP and also check every official GP village in
the reverse direction. Urban constituents prevent rural-only aggregation.
[SHRUG's construction documentation](https://docs.devdatalab.org/SHRUG-Construction-Details/imputing-and-aggregating-data/)
describes upstream imputation. Our screen on the supplied missingness and weight
fields is conservative, but does not certify original, unimputed administrative
population counts. The installed data are version 2.0; the current online
explanations identify themselves as version 2.2.

The official LGD files dated 2024 are held in the Rajasthan and UP collection
repositories. Reusing the approach in `quota_spending` does not inherit historical
boundary validation. That project also limits its analysis to an observed
Census-2001 universe; here the entire available GP catalog is retained, with
unresolved populations explicitly missing.
