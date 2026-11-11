# Road results handoff for seoul-climate-card (2026-11-11)

## 1. seoul_road_pooled/ — pooled 149-site estimate (manuscript Sec. 2.4)
- `diag_event_att_r3.csv`: weekly ATT for the pooled model (GSC, r = 3, 53 outside-Seoul controls, 200 bootstrap draws, seed 20260731).
- The manuscript value is the **count-weighted** mean over posttreatment weeks (rel_week >= 1, 44 weeks): sum(ATT × count) / sum(count) = **−35.914 veh/h**. The unweighted mean is −36.09.
- The CI [−80.82, 8.99] and p = .117 come from the fect overall ATT stored in `scm_results/서울전역_도로_gsynth_20261103/diag_fits_r3.rds`. That file is not copied here (it is large); copy it if needed.
- `diag_placebo_r3.csv`: final-four-week placebo for the same model (+49.83, p = .043).
- `plot_fig_section2_4_road.py`: manuscript Fig. 4 script, for reference.

## 2. expressway_allday_scm/ — nine urban expressways, all-day SCM (SI Section D)
- `table_SI_expressways_manuscript.csv`: the SI table values exactly as reported (average daily traffic, pre RMSPE, RMSPE ratio, placebo p). All nine routes are not significant. Gangbyeonbuk-ro, Gyeongbu and Olympic-daero are indexed specifications.
- `path_*.csv` and `summary.csv`: treated vs synthetic paths from a 2026-11-03 rerun of the original 2025-06 Rmd analyses.
  - The originals are on the external drive: `/Volumes/Mac OS 확장/thesis/Downloads/Thesis_Materials/scm/final/*.Rmd`.
  - The rerun script `expressway_allday_rerun_20261103.R` is included.
- **Caution:** the `match` column in `summary.csv` is FALSE for all routes. The rerun paths do not exactly reproduce the manuscript's pre RMSPE and ratios.
  - Use them for figures only, labelled "rerun".
  - Use `table_SI_expressways_manuscript.csv` for reported numbers.
- Placebo p-values are not in the rerun outputs. They come from the original Rmd runs.
- Raw input: `Thesis_Materials/pre_processed/all_combined_with_info.csv` (external drive). It is not included.
