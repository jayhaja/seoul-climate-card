# 05_seoul_road_gsynth — Seoul-wide road traffic gsynth

## Purpose
Estimates the change in road traffic after the introduction of the Climate Card (2024-01-29, week 51). Treated units are Seoul permanent traffic-count sites (TOPIS; 149 sites with at least 90% coverage); controls are the 53 non-Seoul donor links from the road SCM. The outcome is the weekly median of weekday 06–09h hourly volume, and the estimator is gsynth (fect). The folder also includes fits by site type; placebo, pre-trend and equivalence diagnostics; and a re-analysis following the Liu, Wang & Xu (2024) guide.

## Inputs
The TOPIS road panel is published in `data/road/` and read from there.

- `panel_seoul176_donor53_6to9.csv` — **included in `data/road/`**. Weekly panel of TOPIS sites and donor links. It was built in Python; the build script is not in this repo (see Missing dependencies). All four scripts read only this file.

## Outputs
Written to `OUT_DIR` (default under `output/05_seoul_road_gsynth/seoul_road_gsynth_20261103/`); published tables are in `results/05_seoul_road_gsynth/`, figures in `figures/seoul_road_gsynth/`.

| Script | Default OUT_DIR (`output/05_seoul_road_gsynth/…`) | Main outputs | Published copy |
|---|---|---|---|
| seoul_road_gsynth_20261103.R | `seoul_road_gsynth_20261103/` | seoul_road_effects_cv{CRIT}.csv, seoul_road_site_gaps_cv{CRIT}.csv, fit_cv_{CRIT}.rds, README.txt | `results/05_seoul_road_gsynth/` |
| seoul_road_gsynth_diag_20261103.R | `seoul_road_gsynth_20261103/` | diag_placebo_r*.csv, diag_event_att_r*.csv, diag_fits_r*.rds, diag_{gap,equiv,placebo}_r*.png | csv: `results/05_seoul_road_gsynth/`, png: `figures/seoul_road_gsynth/` |
| seoul_road_gsynth_bytype_20261103.R | `seoul_road_gsynth_20261103/bytype/` | bytype_{OUTCOME}_{R_MODE}.csv, gap_*.png | csv: `results/05_seoul_road_gsynth/bytype/`, png: `figures/seoul_road_gsynth/bytype/` |
| seoul_road_lwx_20261103.R | `seoul_road_gsynth_20261103/lwx/` | lwx_summary_<timestamp>.csv, gap_/equiv_*.png, fit_*.rds | (not published) |

The `group` column of `seoul_road_effects_cv{CRIT}.csv` uses the labels `All`, `Excluding Yeouido sites` and `Type A`…`Type F`. The published CSVs in `results/05_seoul_road_gsynth/` use the same English labels, and their road and path names were romanised after the run (see `results/place_names_ko_en.csv`); a fresh run writes the road names as they appear in the input panel.

`.rds` fit objects contain the non-public panel and are not published.

## Run order
Run from the repository root; override paths with `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`. Other env vars: NB, CORES, CRIT, R_FIX, OUTCOME, R_MODE, TYPES, PRE_F, METHODS, GROUPS, LOO.

```sh
Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_20261103.R                 # point estimates (bootstrap with NB=200 CORES=2)
CRIT=mspe Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_20261103.R       # MSPE criterion for comparison
Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_diag_20261103.R            # r = CV-selected
R_FIX=3 Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_diag_20261103.R
Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
R_MODE=min Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
OUTCOME=index R_MODE=min Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
NB=100 GROUPS=all Rscript code/05_seoul_road_gsynth/seoul_road_lwx_20261103.R
python3 code/05_seoul_road_gsynth/plot_fig_section2_4_road.py                 # manuscript Fig. 4 from results/05_seoul_road_gsynth/ (needs pandas, matplotlib)
ARCH=/path/to/Thesis_Materials Rscript code/05_seoul_road_gsynth/expressway_allday_rerun_20261103.R   # SI Appendix D rerun; needs the original Rmds and data (not in repo)
```

- `plot_fig_section2_4_road.py` reads only published CSVs (`diag_event_att_r3.csv`, `bytype/bytype_level_min.csv`) and writes `output/05_seoul_road_gsynth/fig_section2_4_road.png`; the published copy is `figures/seoul_road_gsynth/fig4_section2_4_road.png`. The pooled CI and p-value in the figure text are typed in from the fitted model (`diag_fits_r3.rds`, not in the repo).
- `expressway_allday_rerun_20261103.R` reruns the original all-day SCM R Markdown analyses for nine urban expressways. Its outputs are in `results/05_seoul_road_gsynth/expressway_allday_scm/`; they do not exactly reproduce the manuscript values (see the README there).

Each script is independent (they all read the same panel); the order above is recommended. When changing `OUT_DIR`, set it per script (the bytype and lwx defaults are subfolders).

## Dependencies
- R with `fect` (tested with 2.4.x) and `dplyr`. `seoul_road_lwx_20261103.R` adds sensitivity intervals if `fect_sens` is available.

### Missing dependencies
- The Python script that builds `panel_seoul176_donor53_6to9.csv` (raw TOPIS data + the 53 donors from the `road6to9_new_try` spec). See `code/03_road_scm/` for how the road SCM panel is constructed.
