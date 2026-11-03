# 04 Yeouido transit synthetic control (SCM)

## Purpose
*Synthetic control for public-transport flows from Yeouido-dong, 79 donors; V and W estimated jointly on the pre-period.*

- Treated unit: the Yeouido-dong -> Seoul public-transport OD flow (weekly users, holiday weeks excluded). Policy date 2024-01-29; 49 pre-treatment weeks (from 2023-02-13); post-period through 2024-12-30.
- Main specification (`nested79`): 79 donors (the Rmd's 81 minus 23 Haan-dong -> Seoul and 55 Geumgwang-dong -> Seoul). Predictors `tranfer`, `pop_dong` + 5 block means of the pre-period outcome. V and W are chosen jointly by minimising the prediction error over all 49 pre-treatment weeks (Synth). If the default optimiser fails: `optimxmethod = "All"` -> `genoud = TRUE`.
- Alternative specification (`adhcv79`): the 49 pre weeks are split into 25 training and 24 validation weeks to choose V, then W is fitted on the full pre-period (Abadie et al. 2015).
- In-space placebos (as implemented in the code): test statistic = post/pre **RMSPE ratio** (Abadie et al. 2015). Each placebo removes only the placebo unit from the donor pool and **includes the treated unit as a donor**, then runs the same procedure. p = (1 + #{placebo ratio >= treated ratio}) / (1 + number of placebos), i.e. the rank of the treated unit within a distribution that includes it. The main result uses **no pre-fit filter** (`all (Abadie 2015)`); keeping only placebos with pre RMSPE <= 5x the treated one is a sensitivity check (`pre RMSPE <= 5x`).
  - Note: the Rmd's own `placebo`/`pvals` chunks (81 donors, τ = 2, 3, 5, Inf, treated unit excluded from placebo donor pools) belong to the earlier specification; the 79-donor scripts do not use them.
- Effect size (% of counterfactual): `cf_pct = 100 × Σ_post gap / Σ_post synthetic = ATT / mean(synthetic_post) × 100`. In LOO the same quantity is computed as `100 × ATT / (mean(actual_post) − ATT)`. The Rmd's `att_pct` uses a different definition (ATT / mean pre-period actual × 100); do not confuse the two.

## Inputs
*Restricted smart-card OD data; not included in this repository.*

Input data: the smart-card OD panels are published in `data/transit/` (export approved) and read from there (`TRANSIT_DIR`).
- `od_with_pop_sum_without_holiday.csv` — columns `flow`, `week`, `이용자수_주총합` (weekly total users; the Korean column name is kept as in the source data)
- `df_scm_g.csv` — columns `unit_id`, `unit_name`, `week`, `is_treat`, `tranfer`, `pop_dong`, etc.

Paths are set in the Paths block at the top of each script (or via the environment variables `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`). The Rmd setup chunk takes each path from an already-defined R object, then an environment variable, then a default; the default `REPO_ROOT` is `"../.."` when knitting directly (working directory = this folder) and `"."` when eval-ed from the repository root.

The R scripts read the Rmd, extract chunks by label and eval them, applying `sub`/`gsub` to the chunk text first. When editing the Rmd, keep the strings the scripts substitute: `"SCM_yeouido_nested")` (setup), `D81_nested` (setup `LAB` and file names), `Synth::synth(data.prep.obj = dp, verbose = FALSE)` and `fit_nested <- function` (fit-fn), and `(tau = %d)` and `MSPE` in the plot titles (plot-helpers). The scripts stop with an error (`stopifnot`) if some of these are missing.

## Outputs
*Written to OUT_DIR (default `output/04_yeouido_transit_scm/<run>/`); published copies under `results/` and `figures/`.*

| Script | Default OUT_DIR | Main outputs |
|---|---|---|
| `SCM_yeouido_nested79_main.R` | `SCM_yeouido_nested79/` | `M_nested.rds`, `weights_/vweights_/path_D79_nested.csv`, `predictor_means_D79_nested.csv`, `placebo_summary_/placebo_paths_/placebo_pvals_D79_nested.csv`, `loo_sensitivity_D79_nested{,_vfix,_cf}.csv`, `in_time_summary_D79_nested.csv`, `spec_comparison_nested.csv`, `plots/` |
| `SCM_yeouido_nested79_intime.R` | `SCM_yeouido_nested79/` | `in_time_summary_D79_nested.csv` (with `mspe_ratio`), `plots/6.in_time_path_*` |
| `SCM_yeouido_nested79_plots_rmspe.R` | `SCM_yeouido_nested79/` | `plots/3.rmspe_ratio_*`, `plots/4.placebo_gaps_*`, `plots/10.placebo_hist_*` |
| `SCM_yeouido_nested79_loo_plot.R` | `SCM_yeouido_nested79/` | `loo_paths_D79_nested.csv`, `plots/5.loo_D79_nested_v2.jpg` |
| `SCM_yeouido_adhcv79.R` | `SCM_yeouido_adhcv79/` | `weights_/vweights_/path_/placebo_summary_/placebo_paths_/placebo_pvals_/loo_/summary_D79_adhcv.csv`, `run.log` |
| `SCM_yeouido_nested_excl_exposed.R` | `SCM_yeouido_nested/excl_direct_exposure[_<EXCL>]/` | `weights.csv`, `path.csv`, `placebo_*.csv`, `loo_refitV.csv`, `in_time.csv`, `summary.csv` |
| `SCM_yeouido_nested_optimizer_check.R` | `SCM_yeouido_nested/excl_direct_exposure/` | `optimizer_check_excl_<EXCL>.csv` |

Published copies: `results/04_yeouido_transit_scm/nested79/`, `results/04_yeouido_transit_scm/adhcv79/`; figures under `figures/yeouido_transit_scm/`.

**Main summary:** [`results/04_yeouido_transit_scm/nested79/summary_D79_nested.csv`](../../results/04_yeouido_transit_scm/nested79/summary_D79_nested.csv) — one row for the main specification with `att_weekly`, `cf_pct`, `pre_baseline_pct`, `pre_rmspe`, `post_rmspe`, `rmspe_ratio`, placebo counts and p-values (`p_all`, `p_tau5`), the LOO range (`loo_cf_min`, `loo_cf_max`) and the in-time RMSPE ratios. This file is compiled from the outputs of the nested79 scripts listed above (main estimate, `placebo_pvals_D79_nested.csv`, `loo_sensitivity_D79_nested_cf.csv`, `in_time_summary_D79_nested.csv`); none of the scripts in this folder writes it directly. The main ATT also appears in the console output, `M_nested.rds` and `path_D79_nested.csv`, and can be recovered from `loo_sensitivity_D79_nested.csv` as `ATT − delta_ATT` (≈ 1154.0). `spec_comparison_nested.csv` uses the `att_pct` definition. For adhcv79, `summary_D79_adhcv.csv` holds `att` and `cf_pct`.

## Run order
*Run from the repository root.*

```sh
Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested79_main.R          # main specification (~25 min)
Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested79_intime.R        # only if main stopped before the in-time placebos
Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested79_plots_rmspe.R   # redraw placebo figures (RMSPE ratio)
Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested79_loo_plot.R      # LOO figure v2
Rscript code/04_yeouido_transit_scm/SCM_yeouido_adhcv79.R                # alternative specification (~30 min)
Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested_excl_exposed.R    # sensitivity: exclude directly exposed donors (default EXCL=22,23,54,55,56)
Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested_optimizer_check.R # optimiser check (run after excl_exposed)
```
`intime`, `plots_rmspe` and `loo_plot` read `M_nested.rds` (and the placebo CSVs) written by `main`. On macOS you may prefix the commands with `caffeinate -i`. The Rmd (`SCM_yeouido_nested_full_pre.Rmd`) holds the source chunks (earlier 81-donor specification) and can also be knitted directly.

## Dependencies
*R packages.*

R >= 4.1, `Synth` (+ `optimx` and `rgenoud` when `optimxmethod = "All"` or `genoud = TRUE` is used), `dplyr`, `tidyr`, `readr`, `purrr`, `tibble`, `ggplot2`, `lubridate`; optional `ragg` (graphics device) and `knitr`/`rmarkdown` (to knit the Rmd). Plot font (needed for Korean unit names from the input data): AppleGothic on macOS, otherwise NanumGothic. Run in a UTF-8 locale (needed to parse the Korean input column name `이용자수_주총합`).
