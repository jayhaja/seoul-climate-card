# 02_heterogeneity — Heterogeneity of effects (% relative to the counterfactual)

## Purpose
Re-aggregates the saved point estimates and bootstrap draws of the citywide gsynth main model (r = 4) by origin characteristics — transfer burden, transfer walk + wait time, accessibility, trip distance, youth share, elderly share and planning region — and reports effects as a percentage of the counterfactual. No model is refitted. A district-level effect map is also drawn.

## Inputs
Most inputs are restricted (derived from smart-card OD data) and must be placed under `RAW_DIR` (default `data/restricted`). Korean file/folder names of restricted inputs are kept as delivered; English glosses are given in brackets.

| File (relative to `RAW_DIR`) | Used by | Notes |
|---|---|---|
| `R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_01.rds`–`chunk_05.rds` [r4 transfer quintiles, pre-computed CI] | hetero_cf_* | **Restricted.** 1,000 bootstrap draws per OD pair. Producing script not in this repo. |
| `R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv` [r4 additional use per population] | hetero_cf_* | **Restricted**, OD level. Producing script not in this repo. |
| `규모통제_거리환승_20261011/OD_analysis_data.csv` [size-controlled distance/transfer] | hetero_cf_* | **Restricted**, OD level. |
| `AI_uc_보정_20261101.csv` [adjusted accessibility index], `youth_region_20261101.csv`, `elderly_ratio_unit_20261102.csv`, `환승시간_unit매칭_20261101.csv` [transfer time, unit-matched] | hetero_cf_* | Covariates matched on `unit_id` (treated as restricted because they are OD-level). Producing scripts not in this repo. |
| `R2_r4_자치구_지도데이터_20261011/district_effects.csv` [r4 district map data] | maps_r4_district | **Aggregated from restricted data.** Producing script not in this repo. |
| `읍면동/emd.shp` (+ .shx/.dbf/.prj) [eup/myeon/dong boundaries], `집중지수_0727/공시지가_법정동_2023.csv` [official land price by legal dong, 2023] | maps_r4_district | Public data, but not included in this repo. |

Intermediate outputs of other scripts in this repo:
- `point.rds` ← output of `code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R`, default location `output/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010/<eng>/point.rds` (override with env var `XU_DIR`), where `<eng>` = `PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155`.
- The `plot_*.R` scripts read `group_cf_pct.csv` written by `hetero_cf_tertiles_timepath_20261103.R`.

## Outputs
Written to `OUT_DIR` (default `output/02_heterogeneity/<run_name>`); published copies are in `results/02_heterogeneity/`.

| Script | Default OUT_DIR (`output/02_heterogeneity/…`) | Published copy |
|---|---|---|
| hetero_cf_pct_20261102.R | `R2_r4_cf_pct_20261102/` (group_cf_pct.csv, contrast_cf_pct.csv) | — |
| hetero_cf_quintiles_20261103.R | `R2_r4_cf_quintiles_20261103/` | `results/02_heterogeneity/R2_r4_cf_quintiles_20261103/` |
| hetero_cf_tertiles_timepath_20261103.R | `R2_r4_cf_tertiles_timepath_20261103/` | `results/02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103/` |
| hetero_cf_transfer_wait_cross_20261103.R | `R2_r4_transfer_wait_cross_20261103/` | `results/02_heterogeneity/R2_r4_transfer_wait_cross_20261103/` |
| plot_cf_early_late_20261103.R, plot_transfer_cf_timepath_20261103.R | `R2_r4_cf_tertiles_timepath_20261103/` (fig6_5_cf_early_late.png, transfer_timepath_cf.png) | the tertiles folder above |
| maps_r4_district_20261011.py | `maps_r4_district_20261011/` (fig_map_r4_district_{KO,EN}.png) | — |

`membership.csv` and `bootstrap_aggregates.rds` contain OD/origin-level information and are not included in the published copies. The KO map is intentionally a Korean-language figure; use the EN map for English text.

## Run order
Run from the repository root. Paths can be overridden with `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`, `XU_DIR` (Python: `BASE` is accepted as an alias for `RAW_DIR`).

```sh
# 0) Prerequisite: code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R  (writes point.rds)
Rscript code/02_heterogeneity/hetero_cf_pct_20261102.R
Rscript code/02_heterogeneity/hetero_cf_quintiles_20261103.R
Rscript code/02_heterogeneity/hetero_cf_tertiles_timepath_20261103.R
Rscript code/02_heterogeneity/hetero_cf_transfer_wait_cross_20261103.R
Rscript code/02_heterogeneity/plot_cf_early_late_20261103.R
Rscript code/02_heterogeneity/plot_transfer_cf_timepath_20261103.R
python3 code/02_heterogeneity/maps_r4_district_20261011.py
```

The R scripts contain Korean names (input file names and planning-region values), so run them in a UTF-8 locale (e.g. `LC_ALL=C.UTF-8`).

## Dependencies
- R ≥ 4: base R, `ggplot2` (`fect` recommended so the object class in `point.rds` loads cleanly)
- Python 3: `pandas`, `geopandas`, `matplotlib`
- A CJK font (Noto Sans CJK or Apple SD Gothic Neo) for the Korean map

### Missing dependencies
The following are read but not produced by any script in this repo:
- The scripts that built `R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_*.rds`, `dong_population_effects.csv`, `OD_analysis_data.csv`, the four covariate CSVs, and `district_effects.csv`.
- `maps_EN.py` (mentioned in a comment as the reference for boundary handling; not needed to run).
- The "Source script: _review/…" line inside the output README.txt files refers to the original working folder and was left unchanged so that the outputs are unchanged.
