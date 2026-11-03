# Seoul Climate Card: effects on public transport use and car traffic

Replication package (code, aggregated results, figures) for a master's thesis evaluating Seoul's Climate Companion Card (*Gihu Donghaeng* Card), launched on 27 January 2024.

- Website: `docs/` (GitHub Pages: results explorer and figure gallery) — <https://jayhaja.github.io/seoul-climate-card/>
- Citation: [`CITATION.cff`](CITATION.cff) · Licence: [below](#licence)

> **Raw data not included.** The raw smart-card origin–destination (OD) records are export-restricted (secure data centre) and are not, and will not be, in this repository. Everything in `results/` and `figures/` is processed output within the data centre's export approval.

---

## 1. Research questions

1. How much did within-Seoul public transport use increase relative to a no-card counterfactual?
2. Did the effect differ by transfer burden, waiting time, accessibility, trip distance and age structure?
3. Did car traffic fall — on the road links around Yeouido and across Seoul?
4. Did public transport trips from Yeouido-dong rise relative to a synthetic control?

## 2. Data

| Source | Used for | In repo |
|---|---|---|
| MOLIT smart-card OD records (secure data centre) | outcome for analyses 1, 2, 4 | No — raw records restricted |
| Seoul TOPIS detector counts; national ITS link counts | outcome for analyses 3, 5 | No — licence pending |
| Resident registration population (Ministry of the Interior and Safety) | covariate | No — public source |
| KTDB accessibility indicators; Seoul Institute report 2019-BR-26 | heterogeneity | No — public source |

Details: [`data/README.md`](data/README.md).

## 3. Methods

| # | Analysis | Treated | Controls | Method | Code |
|---|---|---|---|---|---|
| 1 | Within-Seoul transit | 409 within-Seoul OD pairs | 941 donor ODs | gsynth (fect, r = 4, OD and week fixed effects, log population covariate) | [`code/01_citywide_gsynth`](code/01_citywide_gsynth) |
| 2 | Heterogeneity | the 409 ODs of analysis 1 | — | re-aggregation of the analysis 1 fit (no refits), 1,000 paired bootstrap draws | [`code/02_heterogeneity`](code/02_heterogeneity) |
| 3 | Yeouido road links | 12 directional links | 53 non-Seoul donor links | SCM (nested V), one fit per link | [`code/03_road_scm`](code/03_road_scm) |
| 4 | Transit from Yeouido-dong | 1 OD unit | 79 donor ODs | SCM (nested V) | [`code/04_yeouido_transit_scm`](code/04_yeouido_transit_scm) |
| 5 | Seoul-wide roads | 149 TOPIS sites | 53 non-Seoul donor links | gsynth (CV-selected r, r = 1–4 sensitivity) | [`code/05_seoul_road_gsynth`](code/05_seoul_road_gsynth) |

**Effect in %.** Effect relative to the counterfactual = 100 × Σ(observed − counterfactual) / Σ counterfactual — a ratio of sums, not a mean of unit percentages.

**SCM inference (analyses 3 and 4).**
- Test statistic: post-/pre-treatment RMSPE ratio (Abadie, Diamond & Hainmueller 2015).
- The treated unit is **included** in each placebo's donor pool and in the placebo distribution: p = (1 + #placebos with ratio ≥ treated) / (1 + #placebos).
- **No pre-fit filter** in the headline result. Restricting to placebos with pre-RMSPE ≤ 5× the treated unit is a sensitivity check only.
- The manuscript placebo-gap figures (`*_tau5.jpg`) draw only the ≤ 5× placebos, but the p-value reported with them uses all placebos.

**gsynth inference (analyses 1 and 2).** 1,000 OD bootstrap draws; normal-approximation 95% intervals (estimate ± 1.96 × bootstrap SD). See [`results/01_citywide_gsynth/R2_normal_final_20261011/README.txt`](results/01_citywide_gsynth/R2_normal_final_20261011/README.txt).

## 4. Main results

All numbers are read directly from the CSV files cited.

### 4.1 Within-Seoul transit (analysis 1)

| Window | Weeks | vs counterfactual | 95% CI (normal) |
|---|---|---|---|
| Full, 2024-01-29 to 2024-12-30 | 46 | **+1.568%** | 0.823 – 2.313 |
| Through August | 30 | +1.444% | 0.741 – 2.148 |
| Excluding December | 42 | +1.478% | 0.759 – 2.198 |

Source: [`results/01_citywide_gsynth/R2_normal_final_20261011/windows.csv`](results/01_citywide_gsynth/R2_normal_final_20261011/windows.csv) (`metric = effect_pct`, `normal_lo`, `normal_hi`). Same file: ATT 288.4 trips per OD-week; +117,959 trips per week summed over the 409 ODs (≈ 5.43 million over 46 weeks).

### 4.2 Heterogeneity (analysis 2)

- Trip distance: the longest-distance tertile has a 1.55 pp smaller effect than the shortest (95% CI −2.59 to −0.51).
- Waiting time: the longest-wait tertile is 0.97 pp lower than the shortest (CI −1.75 to −0.19).
- Transfer burden: no full-period difference (+0.23 pp, CI −0.55 to 1.02), but the late-minus-early change is +1.37 pp.

Source: [`results/02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103/contrast_cf_pct.csv`](results/02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103/contrast_cf_pct.csv) (`window = full`, `late_minus_early`). Unadjusted p-values; descriptive heterogeneity, not causal effects of the characteristics.

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

### 4.5 Seoul-wide road gsynth (analysis 5)

- 149 TOPIS sites, CV-selected r = 0: −1.37% (−1.25% without Yeouido-linked sites); −2.15% to −0.65% across r = 1–4.
- The pre-period placebo test rejects (r = 0: p < .001; r = 3: p = .043). The diagnostics fail, so treat these numbers as **descriptive**.

Sources: [`results/05_seoul_road_gsynth/seoul_road_effects.csv`](results/05_seoul_road_gsynth/seoul_road_effects.csv), [`diag_placebo_r0.csv`](results/05_seoul_road_gsynth/diag_placebo_r0.csv), [`diag_placebo_r3.csv`](results/05_seoul_road_gsynth/diag_placebo_r3.csv), by type: [`bytype/`](results/05_seoul_road_gsynth/bytype).

## 5. Repository layout

```
code/      analysis scripts, one README per folder (purpose, inputs, outputs, run order)
  01_citywide_gsynth/      within-Seoul OD gsynth (409 ODs)
  02_heterogeneity/        counterfactual-relative heterogeneity re-aggregation
  03_road_scm/             SCM for the 12 Yeouido road links
  04_yeouido_transit_scm/  SCM for transit from Yeouido-dong (79 donors)
  05_seoul_road_gsynth/    Seoul-wide TOPIS road gsynth
  utils/                   shared helpers
results/   aggregated CSV results, numbered like code/
figures/   thesis figures (thesis/) and per-analysis diagnostic plots
data/      data sources and access notes (no raw data)
docs/      GitHub Pages site
scripts/   sync_docs_assets.py — copies figures/ and results/ into docs/assets/
```

Korean place names in `results/` were romanised (Revised Romanization, with English terms for Bridge, Station, Intersection, etc.). The original Korean names are listed in [`results/place_names_ko_en.csv`](results/place_names_ko_en.csv). Some figures carry Korean text inside the image.

## 6. How to reproduce

1. Obtain access to the restricted OD data and the road counts.
2. Place inputs under `data/restricted/` (or set `RAW_DIR`). Each script lists the files it needs in a `RESTRICTED DATA REQUIRED` header. Input file names are kept exactly as the data holder's files, so some are in Korean; each has an English gloss in the script.
3. Run from the repository root. Outputs go to `output/` (git-ignored). Override paths with `REPO_ROOT`, `RAW_DIR` and `OUT_DIR`. Some R scripts contain Korean column names and need a UTF-8 locale (e.g. `LC_ALL=C.UTF-8`).
   ```bash
   Rscript code/03_road_scm/run_nested53_abadie2015_placebo.R
   ```
4. Follow the run order in each `code/*/README.md`.
5. Compare with the CSVs in `results/`.

Without the raw data you can still inspect all aggregated results and figures.

## 7. Limitations

- **Raw data restricted:** analyses 1, 2 and 4 cannot be rerun without the restricted OD records.
- **Rank sensitivity (analysis 1):** +1.568% with r = 4 (GMSPE 1-SE rule) but +0.27% with r = 1 (MSPE 1-SE rule) — [`results/01_citywide_gsynth/R2_r4_submission_20261010/rank_sensitivity.csv`](results/01_citywide_gsynth/R2_r4_submission_20261010/rank_sensitivity.csv).
- **Road SCM:** 12 links are tested separately (multiple testing); the minimum attainable p is 1/54 ≈ .019; donors outside Seoul may face different shocks.
- **Yeouido transit SCM:** single treated unit; in-time placebos show +1.6–2.4% gaps, so read the magnitude cautiously. With cross-validated V (adhcv) the effect is +5.53%, p = .038 ([`results/04_yeouido_transit_scm/adhcv79/summary_D79_adhcv.csv`](results/04_yeouido_transit_scm/adhcv79/summary_D79_adhcv.csv)).
- **Seoul-wide road gsynth:** pre-trend diagnostics fail; descriptive only.
- **Road count data:** TOPIS/ITS panels are withheld until licence terms are confirmed.
- **Upstream scripts not included:** panel and covariate builders and some original pipeline files; see each folder README.

## 8. Website

`docs/` is a static site with no build step. GitHub Pages: **Settings → Pages → Source: Deploy from a branch → Branch `main`, folder `/docs`**. After changing `figures/` or `results/`, refresh the site assets:

```bash
python3 scripts/sync_docs_assets.py
```

## Licence

| Content | Licence |
|---|---|
| Code: `code/`, `scripts/`, HTML/CSS/JS in `docs/` | [MIT](LICENSE) |
| Results and figures: `results/`, `figures/`, `docs/assets/results/`, `docs/assets/figures/` | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

See [`LICENSE`](LICENSE); cite via [`CITATION.cff`](CITATION.cff).
