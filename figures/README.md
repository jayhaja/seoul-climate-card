# figures

| Folder | Contents |
|---|---|
| `thesis/main_text/` | Thesis main-text figures (Chapters 4–6) |
| `thesis/appendixA-1_roadNN_*`, `thesis/appendixA-2_yeouido_transit/` | Appendix A: road-link and Yeouido transit SCM figures |
| `thesis/appendixB_gsynth_diagnostics/` | Appendix B: gsynth diagnostics |
| `heterogeneity/` | Chapter 6 heterogeneity figures on the counterfactual-relative scale (current) |
| `road_scm/NN/` | Road SCM diagnostics per link (`*_tau5.jpg` = manuscript placebo-gap figures; p-values use all placebos) |
| `yeouido_transit_scm/` | Yeouido transit SCM diagnostics |
| `seoul_road_gsynth/` | Seoul-wide road gsynth diagnostics (descriptive only; not shown on the website) |

## Chapter 6: current vs earlier-generation figures

Chapter 6 of the manuscript now reports heterogeneity as the **increase relative to the counterfactual (%)**. The figures below use that scale and are current:

| File | Figure |
|---|---|
| `heterogeneity/fig_hetero_hm_main_wide_cf_en.png` | Weekly effects by transfer burden, waiting time and planning region |
| `heterogeneity/fig_hetero_hm_all7_wide_cf_en.png` | Weekly effects for all seven characteristics |
| `heterogeneity/transfer_walking_waiting_time_en.png` | Fig. 6-4: transfer walking + waiting time (June–August 2023) |

Data behind the weekly figures: `results/02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103/fig_hetero_weekly_cf_all_en_data.csv`. Script: `code/02_heterogeneity/fig_heterogeneity_weekly_hmstyle_cf_20261103.R`.

**Earlier generation (per-1,000-residents indicator; superseded, kept for reference):**
- `thesis/main_text/fig6-1_district_map_r4.png`
- `thesis/main_text/fig6-2_transfer_tertiles_r4.png`
- `thesis/main_text/fig6-2_transfer_quintiles_r4_per1000.png`
- `thesis/main_text/fig6-3_transfer_tertiles_weekly_r4_basic.png`

Do not cite these for the current manuscript; use the `heterogeneity/` figures and the counterfactual-relative tables in `results/02_heterogeneity/`.
