# 01_citywide_gsynth — Citywide Seoul OD gsynth/fect

## Purpose
Estimates the effect of the Climate Card by applying the generalized synthetic control method (gsynth, via `fect`) to a 99-week panel of 409 treated within-Seoul OD pairs and 941 control OD pairs. Main specification: `users ~ D + log_pop`, two-way FE, r = 4 fixed, no weights. The folder covers the main fit, the OD bootstrap (B = 1000), Xu-recommended diagnostics, post-processing, and robustness refits.

## Inputs
All paths can be changed in the path block at the top of each script (`REPO_ROOT`, `RAW_DIR`, `OUT_DIR`, etc.) or through environment variables of the same name. Defaults, relative to the repo root, are `data/restricted/` (raw data) and `output/01_citywide_gsynth/` (intermediate outputs).

Restricted input file names are kept exactly as delivered by the data holder (some contain Korean); an English gloss is given below.

| File (under `RAW_DIR`) | Notes | Used by |
|---|---|---|
| `panels/d_w30_no과천.rds` | **RESTRICTED** — smart-card OD × week panel; `no과천` = excluding Gwacheon (builder script not in this repo) | all scripts |
| `od_with_pop_sum_without_holiday.csv` | **RESTRICTED** — OD-level weekly users + population, holiday weeks removed (column `이용자수_주총합` = weekly total users) | BOOT, xu_diagnostics, through_august_refit, ife_vs_gsynth |
| `R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv` | **RESTRICTED** — unit-level output; `인구대비_추가이용` = additional use relative to population (producer script not in this repo) | ife_vs_gsynth |
| `규모통제_거리환승_20261011/OD_analysis_data.csv` | **RESTRICTED** — OD-level covariates; `규모통제_거리환승` = size-controlled distance/transfer (producer not in this repo) | ife_vs_gsynth |
| `AI_uc_보정_20261101.csv`, `youth_region_20261101.csv`, `elderly_ratio_unit_20261102.csv`, `환승시간_unit매칭_20261101.csv` | **RESTRICTED** — unit-level covariates; `AI_uc_보정` = adjusted accessibility index, `환승시간_unit매칭` = transfer time matched to units (producers not in this repo) | ife_vs_gsynth |

Intermediate outputs of other scripts (OD-level, therefore not distributed):

| Path (env var) | Producing script |
|---|---|
| `BOOT_DIR/<engine_id>/point_r4.rds`, `chunk_01.rds`–`chunk_05.rds`, `engine_provenance.csv`, `INFERENCE_NOTES.txt`, `sessionInfo.txt` | `R2_levels_pop_unweighted_r4_BOOT_20261010.R` |
| `DIAG_DIR/<engine_id>/pre_validation.csv`, `policy_r1.rds` (BOOT optionally cross-checks `policy_r4.rds`) | main-model diagnostic run `R2_levels_pop_unweighted_main_diagnostics_20261010` — **not in this repo** |
| `SUBMIT_DIR/OD_point_effects.csv` | `R2_r4_submission_aggregation_20261010.R` |

## Outputs
Default output location is `output/01_citywide_gsynth/<run_name>/`. Published (aggregated) versions are in `results/01_citywide_gsynth/`.

| Script | Output folder (`OUT_DIR` default) | Published |
|---|---|---|
| `R2_levels_pop_unweighted_r4_BOOT_20261010.R` | `R2_levels_pop_unweighted_r4_BOOT_20261010/<engine_id>/` (summary_B1000.csv, weekly_CI_B1000.csv, chunk_*.rds, …) | some metadata (engine_provenance.csv, INFERENCE_NOTES.txt, sessionInfo.txt) is copied to `results/01_citywide_gsynth/R2_r4_submission_20261010/` |
| `R2_r4_xu_diagnostics_20261010.R` | `R2_r4_xu_diagnostics_20261010/<engine_id>/` | not published |
| `R2_r4_submission_aggregation_20261010.R` | `R2_r4_submission_20261010/` | `results/01_citywide_gsynth/R2_r4_submission_20261010/` (except OD_point_effects.csv) |
| `gsynth_through_august_refit_20261103.R` | `gsynth_through_august_refit_20261103/` | `results/01_citywide_gsynth/gsynth_through_august_refit_20261103/` |
| `ife_vs_gsynth_point_20261102.R` | `R2_ife_vs_gsynth_20261102/` | not published |

Note: in `results/01_citywide_gsynth/R2_r4_submission_20261010/`, the files `r4_fect_counterfactual.*`, `r4_*road_window*`, `yeouido_SCM_GSC_sameperiod.csv`, `r4_economics_conditional_20261010.json`, `r4_submission_results.html`, as well as the folders `R2_economics_20261011/` and `R2_normal_final_20261011/`, are not produced by the scripts in this folder (their producing scripts are not in this repo).

## Run order
Run from the repo root. Place the raw data in `data/restricted/` or set `RAW_DIR` (or the legacy `ROOT`).

1. `Rscript code/01_citywide_gsynth/R2_levels_pop_unweighted_r4_BOOT_20261010.R` — point estimate + bootstrap, 200 × 5 chunks (choose a stage with the `POINT` / `BOOT` argument; long run)
2. `Rscript code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R` — native fect diagnostics (`ALL|POINT|PLACEBO|LOO`; LOO takes several hours)
3. `Rscript code/01_citywide_gsynth/R2_r4_submission_aggregation_20261010.R` — aggregates the results of step 1 (no refitting); requires the main-model diagnostic outputs (`DIAG_DIR`)
4. `Rscript code/01_citywide_gsynth/ife_vs_gsynth_point_20261102.R` — IFE vs gsynth point-estimate comparison (needs `OD_point_effects.csv` from step 3; env `METHODS`, `MAXIT`, `TOL`)
5. `Rscript code/01_citywide_gsynth/gsynth_through_august_refit_20261103.R` — refit on the panel truncated at August 2024 (bootstrap: `NB=200 CORES=2 Rscript ...`; fect CV: `CV=1`)

Note: steps 1–2 record the script and helper md5 in `manifest.rds`, so checkpoints created before the path/translation edits will not match the manifest (run into a fresh output folder).

## Dependencies
- R ≥ 4.5 (published sessionInfo: R 4.5.0)
- `fect` **2.4.7** (engine_id `..._fect2.4.7_...`, per sessionInfo), `dplyr`, `readr`
- `R2_fect_weighted_cv_tools_20261010.R` — patched-engine helper that steps 1–2 `source()` from the same folder (defines `r2_engine()`, `r2_args()`, `r2_fit()`, etc.). It only defines functions and is not run directly.
- Step 3 uses base R only. Steps 4–5 use the installed (unpatched) `fect`.
