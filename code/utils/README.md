# utils — Auxiliary calculations

## Purpose
`cf_denominator_20261102.py` recomputes the percentage effects of the road SCM (12 directional links) and the Yeouido transit SCM with a unified denominator: the counterfactual (synthetic) mean instead of the pre-treatment mean of the actual series. It reads saved path files only; there is no refitting.

## Inputs
The script does not read raw data directly; it reads intermediate outputs of other scripts in this repo. Paths are set in the block at the top of the script or through environment variables.

| Env var (default) | Files | Producing script |
|---|---|---|
| `ROAD_RUN_DIR` (`output/03_road_scm/runs/v4_stdv_ex107_201_nested53_20261031-131153`) | `unit_XX/path_main.csv` or `path_full.csv`, `unit_XX/loo_paths_main.csv` / `loo_paths_full.csv` | `code/03_road_scm/run_nested53_full.R` |
| `YEOUIDO_DIR` (`output/04_yeouido_transit_scm/SCM_yeouido_nested`) | `path_D81_nested.csv`, `loo_sensitivity_D81_nested_vfix.csv`, `V선택_비교.csv` (V-selection comparison; file name kept as saved) | `code/04_yeouido_transit_scm/SCM_yeouido_nested_full_pre.Rmd` |

The Yeouido path files (observed and synthetic weekly paths) are OD-level results cleared for export and may be published; the road path files are published in `results/03_road_scm/unit_XX/` (see `data/README.md`).

## Outputs
`OUT_DIR` default `output/utils/cf_denominator_unified_20261102/`: `road_cf.csv`, `road_windows_cf.csv`, `road_loo_cf.csv`, `yeouido_cf.csv`.

Published copies: `road_cf.csv`, `road_windows_cf.csv`, `road_loo_cf.csv` → `results/03_road_scm/summary/`; `yeouido_cf.csv` (81-donor archive) → `results/04_yeouido_transit_scm/yeouido_cf_81donor_archive.csv`.

## Run order
1. Run the producing scripts in `03_road_scm` and `04_yeouido_transit_scm` first.
2. `python3 code/utils/cf_denominator_20261102.py` (from the repo root)

## Dependencies
Python 3, `numpy`, `pandas`.
