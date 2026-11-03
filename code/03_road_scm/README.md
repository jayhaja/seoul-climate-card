# 03_road_scm — Synthetic control (SCM) for roads around Yeouido

## Purpose
Synthetic control for 12 directional road links around Yeouido with 53 donors, V and W estimated jointly on the pre-period, and Abadie et al. (2015)-style placebo inference on the RMSPE ratio.

- Treated units: 12 directional road links around Yeouido (units 1–12). Post window: weeks 51–96 for regular sites and weeks 51–72 for the construction-affected sites (units 1, 2 and 10). Treatment starts in week 51 (pre-period = weeks 1–50).
- Donors: 77-unit panel (12 treated + 65 candidates) → 10 qualitative exclusions (`donor_exclude` in `config_v4.R`, Appendix C) → from the earlier run's donor pool (55 units), 107 and 201 are additionally excluded → **53 donors**.
- Estimation: `method = "stdv"` — V (predictor weights) and W (donor weights) are **jointly optimised** with Synth over the full 50-week pre-period (ADH 2010). Predictors: mean number of lanes (`lanes_mean`), median speed (`speed`), and 5 block averages of traffic volume.
- Inference (`run_nested53_abadie2015_placebo.R`): in-space placebos, re-estimating V·W with each donor d treated as the treated unit. As in Abadie et al.'s (2015) original implementation, placebo donors = (53 − d) ∪ {current treated site} — **the treated site is included in the placebo donor pool** (the other 11 treated sites are excluded).
- Test statistic: post/pre RMSPE ratio. Main p-value = (1 + #{placebo ratio ≥ treated ratio}) / (1 + n), **with no pre-fit filter** (all successful placebos; the treated site enters the distribution as the "1" in the numerator and denominator).
- Sensitivity: p-value using only placebos whose pre-period RMSPE is **at most 5×** that of the treated site (`p_tau5`).
- LOO: donors with positive weight (> 0.001) are dropped one at a time and both V and W are re-estimated (`loo_mode = "twostep"`).
- `run_nested53_full.R` is the earlier version of the same specification (treated site not included among placebo donors, p-values for τ = 2, 3, 5, Inf, LOO with fixed V, in-time placebos at weeks 27, 34 and 40).

## Inputs
Road detector data are restricted and must be placed under `RAW_DIR` (default `data/restricted/`).

**Input data required**: Seoul TOPIS site counts and national ITS link traffic counts. They are redistributable but the full panel is not yet in this repository; place it under `RAW_DIR`. The per-link SCM paths are published in `results/03_road_scm/unit_XX/`.

| File | Used by |
|---|---|
| `RAW_DIR/77_units/0628_6to10_df_with_new_covariates_fixed.csv` — 06:00–09:59, daily median → weekly median panel (columns: unit_id, week_index, traffic, speed, lanes_mean, region_kr, month_date, vehicle_count, is_treat, unit_name_en …) | `config_v4.R` (`panel_csv`) → all run and plot scripts |
| `run_info.json`, `donor_pool_main.csv`, `donor_pool_full.csv` in `OUT_DIR/runs/v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6/` — the earlier run (output of `run_scm_v4.R`) from which settings and donor pools are restored. The path can be set with the env var `SRC_RUN` | `run_nested53_full.R`, `run_nested53_abadie2015_placebo.R` |
| `RAW_DIR/0629_roads_6to9_day.median_week.median.Rmd`, `RAW_DIR/scm_analysis_6to10_day.median_week.median_without_pre_traffic_cov.Rmd` and the raw data these Rmds read — the original pipeline (not in this repo) | `build_panel_6to9_sum.R` (sum sensitivity panel only) |

Paths are changed in the `## ---- Paths` block at the top of each script or via the env vars `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`. `config_v4.R` does not overwrite path variables that are already defined.

## Outputs
Runs go to `OUT_DIR/runs/`; the published copies are in `results/03_road_scm/` and `figures/road_scm/NN/`.

- Run folder: `OUT_DIR/runs/v4_stdv_ex107_201_nested53_abadie2015pl_<YYYYmmdd-HHMMSS>/` — `run_info.json`, `run.log`, `all_units_summary.csv`, `unit_XX/{path.csv, placebo_results.csv, placebo_paths.csv, placebo_failures.csv (on failure), loo_twostep.csv, loo_paths_twostep.csv}`, `plots/NN/*.jpg`.
- Published `results/03_road_scm/`: `all_units_summary.csv`, `run_info.json` (record of the original run — original paths left as is), `unit_XX/{placebo_results.csv, loo_twostep.csv}`, `summary/*.csv` (post-processed tables such as % relative to the counterfactual; some from `code/utils/cf_denominator_20261102.py`).
- Published `figures/road_scm/NN/` (NN = treated site 01–12, `<tag>` = `nested53_<number of post weeks>w`, i.e. 22w or 46w):
  - `1.scm_path_<u>_<tag>.jpg` — treated vs synthetic path
  - `2.scm_gap_<u>_<tag>.jpg` — gap (treated − synthetic)
  - `3.rmspe_ratio_<u>_<tag>_{all,tau5}.jpg` — ranked post/pre RMSPE ratios (treated = red triangle)
  - `4.placebo_gaps_<u>_<tag>_{all,tau5}.jpg` — bundle of placebo gaps (grey) + treated gap (black), dashed line at week 51
  - `10.placebo_hist_<u>_<tag>_{all,tau5}.jpg` — RMSPE ratio histogram (subtitle gives the treated ratio, number of placebos and p)
  - `5.loo_<u>_<tag>_twostep.jpg` — LOO (V·W re-estimated) synthetic paths
- `*_all` = all successful placebos (main test, no filter). `*_tau5` = only placebos with pre RMSPE ≤ 5 × the treated site's pre RMSPE (sensitivity subset). The placebo-gap figure in the manuscript is `4.placebo_gaps_<u>_<tag>_tau5.jpg`, which plots this subset's placebo gap paths (grey) and the treated gap (black) from week 1 to the end of the post window. The main p-value (`p_all`) is based on all placebos without a filter, so it can differ from the number of placebos shown in the figure (`n_tau5`).

## Run order
Run from the repository root.

```sh
# (optional) build the sum sensitivity panel — requires the original pipeline Rmds
Rscript code/03_road_scm/build_panel_6to9_sum.R 2>&1 | tee build_panel_6to9_sum.log
# 0. Base v4 run — produces the settings (run_info.json) and donor pools. The new folder name is set by the run time and hash,
#    so point the two scripts below to it with SRC_RUN=output/03_road_scm/runs/<new folder>.
Rscript code/03_road_scm/run_scm_v4.R
# (earlier version) nested53, parallel placebos + in-time placebos + plots
Rscript code/03_road_scm/run_nested53_full.R            # or ... 4,6,8,12 / NESTED_EXCL=none ...
# Main results: Abadie et al. (2015) placebos + LOO (twostep), serial execution
Rscript code/03_road_scm/run_nested53_abadie2015_placebo.R
# Manuscript figures (uses the latest abadie2015pl run folder)
Rscript code/03_road_scm/plot_nested53_abadie2015pl.R
```
On macOS you may prefix long runs with `caffeinate -i` (optional). `config_v4.R`, `scm_v4_functions.R` and `scm_v4_plots.R` are the settings and function files `source()`d by the scripts above.

## Dependencies
R packages below; the original median-panel pipeline is not in this repo.

- R packages: `Synth`, `dplyr`, `readr`, `tidyr`, `jsonlite`, `ggplot2`, `parallel` (`mclapply`; no parallelism on Windows); optional `LowRankQP`, `digest`, `ragg`, `showtext`·`sysfonts` (same text size as the manuscript; downloads Noto Sans KR). `build_panel_6to9_sum.R` additionally needs `knitr`, `readxl`, `stringr`, `lubridate`, `purrr`, `tibble`.
- Not in this repo: the two Rmds of the original 06–09 median pipeline.
