# figures

| Folder | Contents |
|---|---|
| `thesis/main_text/` | Thesis main-text figures (Chapters 4–6) |
| `thesis/appendixA-1_roadNN_*`, `thesis/appendixA-2_yeouido_transit/` | Appendix A: road-link and Yeouido transit SCM figures |
| `thesis/appendixB_gsynth_diagnostics/` | Appendix B: gsynth diagnostics |
| `heterogeneity/` | Chapter 6 heterogeneity figures: `*_prepct_*` = % of pretreatment mean (current); `*_cf_*` = counterfactual-relative (earlier generation) |
| `road_scm/NN/` | Road SCM diagnostics per link (`*_tau5.jpg` = manuscript placebo-gap figures; p-values use all placebos) |
| `yeouido_transit_scm/` | Yeouido transit SCM diagnostics |
| `seoul_road_gsynth/` | Seoul-wide road gsynth diagnostics (descriptive only; not shown on the website) |

## Chapter 6: current vs earlier-generation figures

Chapter 6 of the manuscript (2026-11-04) reports heterogeneity as the **effect as % of the group's pretreatment mean weekly ridership** (level effect in weekly person-days per OD pair ÷ the same ODs' 53-week pretreatment mean). Current figures:

| File | Figure |
|---|---|
| `heterogeneity/fig6_5_prepct_early_late_en.png` (= `thesis/main_text/fig6-5_early_late_prepct.png`) | Fig. 6-5: group effects for weeks 1–12 and 13–46 with 95% CIs (y-axis differs across panels) |
| `heterogeneity/fig_hetero_hm_main_wide_prepct_en.png` (= `thesis/main_text/fig6-x_weekly_prepct_main.png`) | Weekly effects by transfer burden, waiting time and planning region; text box = ATT over the 46 posttreatment weeks with 95% CI |
| `heterogeneity/fig_hetero_hm_all7_wide_prepct_en.png` | Weekly effects for all seven characteristics |
| `heterogeneity/fig6_4_transfer_wait_minimal_en.png` (= `thesis/main_text/fig6-4_transfer_walking_waiting_time.png`) | Fig. 6-4: walking + waiting time per transfer trip, one vs two-or-more transfers (June–August 2023) |

Data: `results/02_heterogeneity/R2_r4_prepct_level_20261103/` (`group_level_prepct.csv`, `contrast_level_prepct.csv`, `weekly_level.csv`, `fig_hetero_weekly_prepct_all_en_data.csv`). Scripts: `code/02_heterogeneity/hetero_level_prepct_20261103.R` (re-aggregation), `fig_heterogeneity_weekly_hmstyle_prepct_20261104.R` (Figs 6-5 and weekly), `plot_transfer_wait_minimal_20261104.py` (Fig. 6-4).

**Earlier generation 2 — counterfactual-relative % (superseded 2026-11-04, kept for reference):** `heterogeneity/fig_hetero_hm_main_wide_cf_en.png`, `heterogeneity/fig_hetero_hm_all7_wide_cf_en.png`, `heterogeneity/transfer_walking_waiting_time_en.png`; data `results/02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103/fig_hetero_weekly_cf_all_en_data.csv`.

**Earlier generation 1 (per-1,000-residents indicator; superseded, kept for reference):**
- `thesis/main_text/fig6-1_district_map_r4.png`
- `thesis/main_text/fig6-2_transfer_tertiles_r4.png`
- `thesis/main_text/fig6-2_transfer_quintiles_r4_per1000.png`
- `thesis/main_text/fig6-3_transfer_tertiles_weekly_r4_basic.png`

Do not cite these for the current manuscript; use the `*_prepct_*` figures and `results/02_heterogeneity/R2_r4_prepct_level_20261103/`.
