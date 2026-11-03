## config_v4.R — Road SCM v4 settings (v3 + method choice) (variable definitions · periods · donor criteria · output)
## Changes are tracked via run_info.json (settings hash) and the run log. Changing the settings invalidates the cache.
## ---- Paths (edit here or set env vars) -------------------------------
## Guarded so this file can be sourced by other scripts (which may already define these) in any order.
if (!exists("REPO_ROOT")) REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                                    # run from repo root
if (!exists("RAW_DIR"))   RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # non-redistributed road inputs
if (!exists("OUT_DIR"))   OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "03_road_scm"))
if (!exists("CODE_DIR"))  CODE_DIR  <- file.path(REPO_ROOT, "code", "03_road_scm")
## RESTRICTED DATA REQUIRED (restricted data required): road detector inputs (Seoul TOPIS sites and national ITS link counts) are not redistributed (licence pending).
## Required input files (place under RAW_DIR):
##   - 77_units/0628_6to10_df_with_new_covariates_fixed.csv   (analysis panel, 77 units; built by the original 06–09 median pipeline, not in this repo)
CFG <- list(
  ## ── Input ────────────────────────────────────────────────────────────────
  panel_csv = file.path(RAW_DIR, "77_units", "0628_6to10_df_with_new_covariates_fixed.csv"),
  ##   06:00–09:59 window, daily median → weekly median, 77 units (12 treated + 65 donor candidates). Columns: unit_id, week_index, traffic, speed,
  ##   lanes_mean, region_kr, month_date, vehicle_count (monthly registered vehicles by province/metropolitan city), is_treat, unit_name_en …
  pop_csv   = NULL,   # For registered vehicles per 1,000 population. Columns: region_kr, month_date (YYYY-MM-01), population. If NULL, the vehicle variable is not used.
  ##   Note: vehicle_count is at the province/metropolitan-city level (5 regions), so donors in the same region share identical values → effectively a region dummy. Replacing it with city/county/district-level data is recommended.

  ## ── Analysis units ───────────────────────────────────────────────────────
  treated_ids = 1:12,
  donor_exclude = c(114, 304, 126, 129, 131, 202, 102, 101, 404, 305),   # Qualitative exclusions (Appendix C, Table C-1). Reasons in donor_exclude_reason.
  donor_exclude_reason = c(
    "114" = "Tongil-ro IC–Yangju TG: data quality / structural change (Appendix C)", "304" = "Seodaejeon IC–Seodaejeon JC (Appendix C)", "126" = "Maseong IC–Singal JC (Appendix C)",
    "129" = "Cheonjinamgyo–Sangok JC (Appendix C)", "131" = "Gamgok IC–Yeoju JC (Appendix C)", "202" = "Incheon TG–Bupyeong IC (Appendix C)", "102" = "Mokgam IC–Gwangmyeong Station IC (Appendix C)",
    "101" = "Namyangju TG–Hwado IC (Appendix C)", "404" = "Gijang IC–Haeundae IC (Appendix C)", "305" = "Cheonbyeon Urban Expressway, downbound → upbound (Appendix C)"),

  ## ── Estimation method ───────────────────────────────────────────────────
  ## "stdv"    : standard SCM (ADH 2010). One nested optimisation of V·W on the predictors and outcome over the full 50-week pre-period (pre_idx).
  ##             fit_idx/valid_idx/final_w_idx are not used for fitting (only to report the early/late RMSPE windows in the metrics).
  ## "adh2015" : two-step, as in v3 (train weeks 1–25 → choose V on validation weeks 26–50 → final W on final_w_idx).
  method = "stdv",
  ## "cv"      : version that corrects the specification choice of the old main table (cv2550) to an out-of-sample criterion. For each treated
  ##             unit, a grid of (covariate combination × number of donors K) is scored by fitting on weeks 1–25 and the prediction error on
  ##             weeks 26–50 (stage-1 W); the minimising pair is chosen, then W is fitted on weeks 1–50 with that V fixed and the top-K donors.
  ##             Placebos keep the selected specification (combination · pool) fixed. Settings in the cv entry below.
  cv = list(
    candidates = list(                       # Covariate candidates (all subsets = combination candidates; empty combination = outcome blocks only)
      list(var = "lanes_mean",     op = "mean",   label = "Mean number of lanes"),
      list(var = "speed",          op = "median", label = "Median speed"),
      list(var = "speed",          op = "min",    label = "Minimum speed"),
      list(var = "vehicle_change", op = "mean",   label = "Change in registered vehicles")),
    K_grid   = 55:40,                        # Top-K donors by distance (truncated automatically if larger than the pool)
    final_v  = "fixed",                      # "fixed": fix V from the selection step, then W on weeks 1–50 (old approach) / "nested": re-optimise V·W with the selected combination · pool (stdv)
    placebo_v = "own"                        # "own": each placebo re-selects its own V (same as the old Rmd) / "treated": also fix the treated unit's V (fully fixed specification)
    ## Limitation (by design): placebo and in-time runs only inherit the combination · pool selected for the treated unit; they do not repeat the (combination × K) selection itself → inference conditional on the selection.
  ),

  ## ── Donor pre-screening (pre-treatment data only; thresholds fixed before fitting — not tuned after seeing results) ──
  ## Applied per treated unit. Main estimate, placebo, LOO and in-time all use the same screened pool. Output in unit_XX/donor_screen.csv.
  donor_screen = list(
    enabled       = FALSE,       # 2026-10-05: oracle screening put on hold (Jay). Set to TRUE to apply per-treated-unit screening
    level_ratio   = c(1/3, 3),   # Allowed range of donor pre-period mean traffic / treated pre-period mean traffic
    trend_cor_min = 0.3,         # Lower bound of the Pearson correlation of weekly traffic over the 50 pre-weeks (pre-treatment outcome, not a fit)
    min_donors    = 15           # If fewer donors pass, relax to the min_donors level-passing donors with the highest correlation (flag recorded)
  ),

  ## ── Periods (week_index) ────────────────────────────────────────────────
  fit_idx   = 1:25,      # Stage 1: predictor aggregation + W fit (training)
  valid_idx = 26:50,     # Stage 1: V selection criterion (validation outcome)
  final_w_idx = 26:50,   # Stage 2: window for predictor aggregation + final W fit (ADH 2015 = validation window). Sensitivity: 1:50 (training/validation unchanged)
  pre_idx   = 1:50,
  post_main = 51:72,     # Main-table post window (through 2024-06-24)
  post_full = 51:100,    # Reference (full)
  n_blocks  = 5,         # Number of outcome (traffic) block averages (each window split into n equal parts)
  ## Observation completeness is checked per analysis window: main table = pre_idx ∪ post_main, full = pre_idx ∪ post_full. Applied per window to treated and donors alike.

  ## ── Predictors (common default set; no per-road automatic selection) ────
  ## Each entry: var = panel column, op = aggregation within the window. The window (fit_idx / valid_idx) is applied automatically per stage.
  predictors = list(
    list(var = "lanes_mean",        op = "mean",   label = "Mean number of lanes"),
    list(var = "speed",             op = "median", label = "Median speed")
    ## Vehicle-registration variable excluded (decision 2026-10-03): vehicle_count is a monthly total at the province/metropolitan-city level (5 regions), so donors in the same region share identical values →
    ## merely a region dummy with no matching information. If city/county/district-level data are obtained, restore the line below and use it as a sensitivity check.
    ## , list(var = "vehicles_per_1000", op = "mean", label = "Registered vehicles per 1,000 population", requires_pop = TRUE)
  ),

  ## ── Inference · diagnostics ─────────────────────────────────────────────
  placebo_tau   = c(2, 3, 5, Inf),   # Placebo pool filter: pre RMSPE ≤ tau × treated pre RMSPE
  loo_min_w     = 0.001,             # LOO targets: final weight > loo_min_w
  loo_mode      = "fixedV",          # "fixedV": V fixed, refit W only (canonical Appendix A-1 LOO = vfix) / "twostep": re-optimise both V·W for each omission
  intime_starts = c(27, 34, 40),     # In-time placebo fake treatment start (week)
  diag_max_w_warn    = 0.5,          # Warning threshold for the maximum donor weight
  diag_rmspe_worsen  = 1.5,          # Warn if the final W's RMSPE on weeks 26–50 exceeds this multiple of the stage-1 validation RMSPE

  ## ── Output ──────────────────────────────────────────────────────────────
  out_root = file.path(OUT_DIR, "runs"),   # Per-run subfolder (timestamp_hash) created automatically
  run_tag  = "v4_stdv_lanes_speed"
)
