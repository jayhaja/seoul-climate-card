# Seoul Climate Card: effects on public transport use and car traffic

Replication package (code, aggregated results, figures) for a master's thesis evaluating Seoul's Climate Companion Card (*Gihu Donghaeng* Card), launched on 27 January 2024.

- Website: `docs/` (GitHub Pages: results explorer and figure gallery) — <https://jayhaja.github.io/seoul-climate-card/>
- Citation: [`CITATION.cff`](CITATION.cff) · Licence: [below](#licence)

> **Data included.** The weekly smart-card OD panel and the analysis panels (`data/transit/`, `data/road/`) are approved for publication by the secure data centre and are in this repository, so the main estimates can be rerun without restricted access. See [`data/README.md`](data/README.md) for variables, periods and units.

---

## 1. Research questions

1. How much did within-Seoul public transport use increase relative to a no-card counterfactual?
2. Did the effect differ by transfer burden, waiting time, accessibility, trip distance and age structure?
3. Did car traffic fall — on the road links around Yeouido and across Seoul?
4. Did public transport trips from Yeouido-dong rise relative to a synthetic control?

## 2. Data

| Source | Used for | In repo |
|---|---|---|
| MOLIT smart-card OD records (secure data centre; export approved) | outcome for analyses 1, 2, 4 | Yes — weekly OD panel and analysis panels in `data/transit/` |
| Seoul TOPIS detector counts; national ITS link counts | outcome for analyses 3, 5 | Yes — analysis panels in `data/road/` |
| Resident registration population (Ministry of the Interior and Safety) | covariate | No — public source |
| KTDB accessibility indicators; Seoul Institute report 2019-BR-26 | heterogeneity | No — public source |

Details: [`data/README.md`](data/README.md).

## 3. Methods

| # | Analysis | Treated | Controls | Method | Code |
|---|---|---|---|---|---|
| 1 | Within-Seoul transit | 409 within-Seoul OD pairs | 942 donor ODs (941 + Mangwol-dong, Hanam → Seoul) | gsynth (fect, r = 4, OD and week fixed effects, log population covariate) | [`code/01_citywide_gsynth`](code/01_citywide_gsynth) |
| 2 | Heterogeneity | the 409 ODs of analysis 1 | — | re-aggregation of the analysis 1 fit (no refits), 1,000 paired bootstrap draws | [`code/02_heterogeneity`](code/02_heterogeneity) |
| 3 | Yeouido road links | 12 directional links | 53 non-Seoul donor links | SCM, one fit per link | [`code/03_road_scm`](code/03_road_scm) |
| 4 | Transit from Yeouido-dong | 1 OD unit | 79 donor ODs | SCM | [`code/04_yeouido_transit_scm`](code/04_yeouido_transit_scm) |
| 5 | Seoul-wide roads | 149 TOPIS sites | 53 non-Seoul donor links | GSC with three factors (by road type; all-day SCM for nine expressways) | [`code/05_seoul_road_gsynth`](code/05_seoul_road_gsynth) |

**Effect in %.** Two denominators are used, as in the manuscript:
- gsynth (analyses 1 and 2): effect relative to the **pretreatment mean** = 100 × ATT / mean pretreatment weekly use of the same OD pairs (53 weeks).
- SCM (analyses 3 and 4): effect relative to the **counterfactual** = 100 × Σ(observed − counterfactual) / Σ counterfactual.

Both are ratios of averages, not means of unit percentages. Where useful, the other basis is given in brackets.

**SCM inference (analyses 3 and 4).**
- Test statistic: post-/pre-treatment RMSPE ratio (Abadie, Diamond & Hainmueller 2015).
- The treated unit is **included** in each placebo's donor pool and in the placebo distribution: p = (1 + #placebos with ratio ≥ treated) / (1 + #placebos).
- **No pre-fit filter** in the headline result. Restricting to placebos with pre-RMSPE ≤ 5× the treated unit is a sensitivity check only.
- The manuscript placebo-gap figures (`*_tau5.jpg`) draw only the ≤ 5× placebos, but the p-value reported with them uses all placebos.

**gsynth inference (analyses 1 and 2).** 1,000 OD bootstrap draws (complete OD histories resampled within treated and control groups); normal-approximation 95% intervals (estimate ± 1.96 × bootstrap SD), conditional on r = 4. An origin-clustered bootstrap is reported as a robustness check (section 4.1).

## 4. Main results

All numbers are read directly from the CSV files cited.

### 4.1 Within-Seoul transit (analysis 1)

409 treated OD pairs, 942 controls, r = 4.

| Window | Weeks | vs pretreatment mean | 95% CI (normal) |
|---|---|---|---|
| Full, 2024-01-29 to 2024-12-30 | 46 | **+1.87%** | 0.93 – 2.81 |
| First 12 weeks | 12 | +1.52% | 0.83 – 2.21 |
| Later 34 weeks | 34 | +1.99% | 0.95 – 3.04 |
| Later minus first | — | +0.47 pp | −0.03 – 0.98 (p = .065) |
| Through August | 30 | +1.72% | 0.87 – 2.57 |
| Excluding December | 42 | +1.85% | 0.90 – 2.79 |

- Level: ATT **362.7 person-days per OD pair per week** (95% CI 171.7–553.6); **148,327 person-days per week** summed over the 409 OD pairs (≈ 6.82 million over 46 weeks). Pretreatment mean: 19,380.9 person-days per OD pair per week. Relative to the counterfactual the full-period effect is +1.98%.
- Units are **person-days** (daily unique card users summed over weekdays), not trips.
- Origin-clustered bootstrap (origins resampled within Seoul / non-Seoul strata, all OD pairs of an origin drawn together, 1,000 draws): SE rises from 0.47 to 0.55 pp (ratio 1.16); 95% CI 0.80–2.94 (normal), 0.71–2.83 (percentile), 0.91–3.03 (basic). With r = 2: 2.04%, 1.27–2.82.

Sources: [`results/01_citywide_gsynth/manuscript_942_20261104/overall_period_estimates_CI.csv`](results/01_citywide_gsynth/manuscript_942_20261104/overall_period_estimates_CI.csv) (`key = all409`, `metric = pre_pct` / `ATT`), [`contrasts_CI.csv`](results/01_citywide_gsynth/manuscript_942_20261104/contrasts_CI.csv) (`all409:late_minus_early`), weekly paths in [`weekly_estimates_CI_manuscript.csv`](results/01_citywide_gsynth/weekly_estimates_CI_manuscript.csv), origin-cluster results in [`origin_cluster_boot_20261117/summary_CI.csv`](results/01_citywide_gsynth/origin_cluster_boot_20261117/summary_CI.csv) (code: [`code/01_citywide_gsynth/origin_cluster_boot_20261117.R`](code/01_citywide_gsynth/origin_cluster_boot_20261117.R)).

*Superseded:* the earlier 941-donor specification (+1.568% vs counterfactual; 117,959 person-days per week) remains in `results/01_citywide_gsynth/R2_normal_final_20261011/` for reference only.

### 4.2 Heterogeneity (analysis 2)

Groups are compared on the effect as % of the group's pretreatment mean weekly use (311 OD pairs from origins with ≥ 1,000 residents; overall 1.88%, 95% CI 0.93–2.82).

- Trip distance: the longest-distance tertile has a 1.43 pp smaller effect than the shortest (95% CI −2.45 to −0.41; p = .006).
- Waiting time: the longest-wait tertile is 0.94 pp lower than the shortest (CI −1.69 to −0.18; p = .015).
- Transfer burden: no full-period difference (+0.16 pp, CI −0.61 to 0.93), but the late-minus-early change is +1.26 pp (CI 0.63–1.88).

Source: [`results/01_citywide_gsynth/manuscript_942_20261104/contrasts_CI.csv`](results/01_citywide_gsynth/manuscript_942_20261104/contrasts_CI.csv) (`metric = pre_pct`, `window = full` / `late_minus_early`); group-level effects in [`group_period_estimates_CI.csv`](results/01_citywide_gsynth/manuscript_942_20261104/group_period_estimates_CI.csv). The earlier 941-donor versions remain in `results/02_heterogeneity/`. Unadjusted p-values; descriptive heterogeneity, not causal effects of the characteristics.

### 4.3 Yeouido road-link SCM (analysis 3)

**Four of the 12 links** are significant at p = .019 (rank 1 among 53 placebos plus the treated link).

| Link | vs counterfactual | p (all placebos) | LOO range |
|---|---|---|---|
| Nodeul-ro southbound | −10.03% | .019 | −13.85 to −9.85 |
| Mapo Bridge northbound | −4.85% | .019 | −5.40 to −3.65 |
| Seogang Bridge northbound | −2.18% | .019 | −2.79 to −0.78 |
| Wonhyo Bridge northbound | −4.23% | .019 | −4.60 to −3.51 |

The other eight links have p ≥ .093. Source: [`results/03_road_scm/summary/road_abadie2015_placebo_loo_cf.csv`](results/03_road_scm/summary/road_abadie2015_placebo_loo_cf.csv), which also carries the ≤ 5× sensitivity p (`p_tau5`, .019–.033 for the same four links). `summary/road_placebo_p_all_vs_tau5.csv` and `summary/road_loo_cf.csv` come from an earlier specification (treated link not in the placebo donor pools); see [`results/03_road_scm/summary/README.md`](results/03_road_scm/summary/README.md).

### 4.4 Transit from Yeouido-dong (analysis 4)

- **+4.98%** relative to the synthetic control; placebo rank 1 of 80, **p = .0125** (79 placebos plus the treated unit, no filter); ≤ 5× sensitivity p = .0127. Relative to the pre-period mean: +4.83%.
- Leave-one-out over the five positive-weight donors: +3.81% to +5.52%.
- In-time placebos (fake start weeks 27, 35, 42): +1.6% to +2.4%.

Source: [`results/04_yeouido_transit_scm/nested79/summary_D79_nested.csv`](results/04_yeouido_transit_scm/nested79/summary_D79_nested.csv). Details: [`placebo_pvals_D79_nested.csv`](results/04_yeouido_transit_scm/nested79/placebo_pvals_D79_nested.csv), [`loo_sensitivity_D79_nested_cf.csv`](results/04_yeouido_transit_scm/nested79/loo_sensitivity_D79_nested_cf.csv), [`in_time_summary_D79_nested.csv`](results/04_yeouido_transit_scm/nested79/in_time_summary_D79_nested.csv).

### 4.5 Road traffic across Seoul (analysis 5)

- 149 TOPIS sites vs 53 outside-Seoul sites, three-factor GSC: **−35.9 veh/h** (95% CI −80.8 to 9.0; p = .117), i.e. −1.49% of the pretreatment mean of 2,404.8 veh/h (95% CI −3.36 to 0.37) — no consistent reduction across the network. An equivalence test rules out the reductions expected if 80% or more of the additional transit use had replaced car trips (margin ±3.47%, p = .019) but not those at 70% or less (±3.04%, p = .052). The point estimate is the count-weighted mean of the 44 posttreatment weekly ATTs in [`diag_event_att_r3.csv`](results/05_seoul_road_gsynth/diag_event_att_r3.csv) (−35.914); the CI and p-value come from the fitted model object, which is not in the repository.
- By road type, only arterial roads (38 sites) decrease significantly: −58.3 veh/h, −3.16% vs counterfactual (−3.21% of the pretreatment mean; 95% CI −111.7 to −5.0 veh/h; p = .032) — [`bytype/bytype_level_min.csv`](results/05_seoul_road_gsynth/bytype/bytype_level_min.csv). A separate all-day analysis of the arterial sites gives about −2.3%, not significant (manuscript).
- Nine urban expressways, all-day SCM: none significant — [`expressway_allday_scm/table_SI_expressways_manuscript.csv`](results/05_seoul_road_gsynth/expressway_allday_scm/table_SI_expressways_manuscript.csv). The path files in that folder come from a rerun that does not exactly reproduce the reported values.
- Caveat: arterial traffic ran above the model's predictions in the four to six weeks before launch (final-four-week placebo for the pooled model: +49.8, p = .043, [`diag_placebo_r3.csv`](results/05_seoul_road_gsynth/diag_placebo_r3.csv)).

## 5. Repository layout

```
code/      analysis scripts, one README per folder (purpose, inputs, outputs, run order)
  01_citywide_gsynth/      within-Seoul OD gsynth (409 ODs)
  02_heterogeneity/        heterogeneity re-aggregation (% of pretreatment mean; earlier counterfactual-relative scripts kept)
  03_road_scm/             SCM for the 12 Yeouido road links
  04_yeouido_transit_scm/  SCM for transit from Yeouido-dong (79 donors)
  05_seoul_road_gsynth/    Seoul-wide TOPIS road gsynth
  utils/                   shared helpers
results/   aggregated CSV results, numbered like code/
figures/   thesis figures (thesis/) and per-analysis diagnostic plots
data/      transit/ and road/ panels, with variable documentation
docs/      GitHub Pages site
scripts/   sync_docs_assets.py (copies figures/ and results/ into docs/assets/), build_map_data.py (map data)
```

Korean place names in `results/` were romanised (Revised Romanization, with English terms for Bridge, Station, Intersection, etc.). The original Korean names are listed in [`results/place_names_ko_en.csv`](results/place_names_ko_en.csv). Some figures carry Korean text inside the image.

## 6. How to reproduce

The panels in `data/transit/` and `data/road/` are read directly by the scripts (`TRANSIT_DIR`, default `data/transit`; the gzip panel is read as is), so no restricted access is needed.

1. Install R (≥ 4.3) with `fect` 2.4.7, `Synth`, `dplyr`, `readr`, `ggplot2` (see each folder README).
2. A few scripts also read intermediate files that are not uploaded yet (bootstrap chunks and covariate tables for analysis 2, the original road pipeline Rmds); they list them in their header and look for them under `data/restricted/` (or `RAW_DIR`).
3. Run from the repository root. Outputs go to `output/` (git-ignored). Override paths with `REPO_ROOT`, `RAW_DIR` and `OUT_DIR`. Some R scripts contain Korean column names and need a UTF-8 locale (e.g. `LC_ALL=C.UTF-8`).
   ```bash
   LC_ALL=C.UTF-8 NB=0 Rscript code/01_citywide_gsynth/gsynth_through_august_refit_20261103.R
   ```
4. Follow the run order in each `code/*/README.md`.
5. Compare with the CSVs in `results/`.

**Reproduction checks (this repository, R 4.3.3, fect 2.4.7 from GitHub, Synth 1.1-10):**
- Analysis 1, manuscript specification (942 controls, r = 4 fixed, no bootstrap): ATT 362.6574, +1.871213% of the pretreatment mean — matches the manuscript; r = 2 gives 2.0448%.
- Analysis 1, earlier 941-donor specification: ATT 288.41, +1.5678% vs counterfactual; the through-August refit gives 1.4368%.
- Analysis 4, main fit (79 donors): +4.95%, pre-RMSPE 389.3, RMSPE ratio 3.202, versus the published +4.98%, 383.8 and 3.267. The same five donors receive almost the same weights (0.325/0.205/0.188/0.149/0.115 vs 0.328/0.205/0.195/0.161/0.111); the predictor weights V differ, i.e. the Synth optimiser reaches a slightly different solution on this platform. The published path file (`path_D79_nested.csv`) reproduces +4.98% exactly.

## 7. Limitations

- **Analysis 2 inputs:** the bootstrap chunks and covariate tables used by the heterogeneity scripts are not uploaded yet.
- **SCM optimiser sensitivity:** Synth results can differ slightly across platforms and package versions (see the reproduction checks above).
- **Rank sensitivity (analysis 1):** with 942 controls the effect is +1.87% at r = 4 (rolling CV, GMSPE 1-SE rule) but 0.42% (r = 1), 2.04% (r = 2), 0.89% (r = 3), 1.49% (r = 5) and −3.06% (r = 0) — [`results/01_citywide_gsynth/manuscript_942_20261104/robustness_points.csv`](results/01_citywide_gsynth/manuscript_942_20261104/robustness_points.csv) (`pre_pct`).
- **Pretreatment diagnostics (analysis 1):** mixed; the default equivalence margin (±1.98%) is wider than the estimated effect.
- **Road SCM:** 12 links are tested separately (multiple testing); the minimum attainable p is 1/54 ≈ .019; donors outside Seoul may face different shocks.
- **Yeouido transit SCM:** single treated unit; in-time placebos show +1.6–2.4% gaps, so read the magnitude cautiously. With cross-validated V (adhcv) the effect is +5.53%, p = .038 ([`results/04_yeouido_transit_scm/adhcv79/summary_D79_adhcv.csv`](results/04_yeouido_transit_scm/adhcv79/summary_D79_adhcv.csv)).
- **Seoul-wide roads:** the arterial model runs above its predictions in the weeks before launch; p-values across road types are not adjusted for multiple testing.
- **Upstream scripts not included:** panel and covariate builders and some original pipeline files; see each folder README.

## 8. Website

`docs/` is a static site with no build step. GitHub Pages: **Settings → Pages → Source: Deploy from a branch → Branch `main`, folder `/docs`**. After changing `figures/` or `results/`, refresh the site assets:

```bash
python3 scripts/sync_docs_assets.py
python3 scripts/build_map_data.py   # front-page map: per-dong effects joined to data/geo/ boundaries
```

The front-page map uses Seoul legal-dong and district boundaries from [southkorea/seoul-maps](https://github.com/southkorea/seoul-maps) (JUSO 2015, Apache License 2.0); see [`data/geo/README.md`](data/geo/README.md).

## Licence

| Content | Licence |
|---|---|
| Code: `code/`, `scripts/`, HTML/CSS/JS in `docs/` | [MIT](LICENSE) |
| Results and figures: `results/`, `figures/`, `docs/assets/results/`, `docs/assets/figures/` | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

See [`LICENSE`](LICENSE); cite via [`CITATION.cff`](CITATION.cff).
