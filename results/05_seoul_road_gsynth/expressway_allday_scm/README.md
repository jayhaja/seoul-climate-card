# Nine urban expressways — all-day traffic SCM (SI Appendix D)

| File | Contents |
|---|---|
| `table_SI_expressways_manuscript.csv` | SI table values exactly as reported in the manuscript: average daily traffic (both directions), pre-RMSPE, RMSPE ratio, placebo p. **Use this file for reported numbers.** All nine routes are not significant. Gangbyeonbuk-ro, Gyeongbu and Olympic-daero use indexed specifications. |
| `path_<spec>.csv` | Treated vs synthetic weekly paths (`week_index`, `treated`, `synthetic`, `gap`, `indexed`) from a 2026-11-03 **rerun** of the original 2025-06 analyses. |
| `summary.csv` | Rerun summary per specification: pre-RMSPE, RMSPE ratio and effect as % of synthetic, next to the manuscript values (`D1_pre_rmspe`, `D1_ratio`). |

**Caution — rerun does not reproduce the manuscript exactly.** The `match` column in `summary.csv` is FALSE for every specification: the rerun pre-RMSPE and ratios differ from the reported values. Use the `path_*.csv` files for figures only, labelled "rerun". Placebo p-values come from the original runs and are not in the rerun outputs.

Notes:
- Some routes have more than one specification file (e.g. `bundang` and `bundang_2`, `inner` and `inner_f`); `summary.csv` maps each file to its route through `treat_id`.
- In `summary.csv`, `gangbyeon_2.Rmd` carries `treat_id` 6 (Gyeongbu), as written by the rerun script; there is no rerun path labelled for Gangbyeonbuk-ro (treat 4).
- Script: `code/05_seoul_road_gsynth/expressway_allday_rerun_20261103.R`. It runs the original R Markdown analyses, which are not in this repository, on the input `all_combined_with_info.csv` (all-day weekly traffic by road, both directions, 2023-02-04 to 2025-03-29; treated units 1–9, donors 10–74), which is also not included.
