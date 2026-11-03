# results/03_road_scm/summary — current vs earlier-run files

This folder mixes outputs from two runs. The headline results come from the **Abadie et al. (2015) run**: the treated link joins each placebo's donor pool, and p is computed with no pre-fit filter.

## Current — headline

| File | Contents |
|---|---|
| `road_abadie2015_placebo_loo_cf.csv` | Effect vs counterfactual (`cf_pct`), p over all placebos (`p_all`), rank, LOO range, RMSPE ratio |
| `../all_units_summary.csv` | Raw summary of the same run, including the effect relative to the pre-period mean |
| `../unit_XX/placebo_results.csv`, `../unit_XX/loo_twostep.csv` | Per-link placebo results and two-step LOO (V and W re-estimated) from the same run |
| `road_cf.csv` | Point estimates vs counterfactual; identical in both runs, still valid |
| `road_windows_cf.csv` | Point estimates by window (early, late, first 22 weeks); point estimates only, still valid |

The test statistic is `rmspe_ratio` (post/pre RMSPE). `road_abadie2015_placebo_loo_cf.csv` also carries `p_tau5` and `n_tau5` (sensitivity using placebos with pre-RMSPE ≤ 5× the treated link) and placebo success/failure counts (`n_placebo_ok`, `n_placebo_fail`) from the same run.

## Earlier run — reference only

From the earlier run (`code/03_road_scm/run_nested53_full.R`), in which the treated link was not in the placebo donor pools and LOO kept V fixed. Ranks, p-values and LOO ranges differ from the headline run; do not cite them.

| File | Use instead |
|---|---|
| `road_placebo_p_all_vs_tau5.csv` | `road_abadie2015_placebo_loo_cf.csv` (`p_all`, `p_tau5`, `n_tau5`) |
| `road_loo_cf.csv` | `road_abadie2015_placebo_loo_cf.csv` (`loo_cf_min`, `loo_cf_max`) |

Example: link 01 (Gyeongin-ro outbound) has p = .093 (rank 5) in the earlier run and .111 (rank 6 of 54) in the headline run.
