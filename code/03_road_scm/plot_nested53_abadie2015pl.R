## plot_nested53_abadie2015pl.R — redraws the manuscript figures from the run_nested53_abadie2015_placebo.R results (2026-11-03)
## No estimation. Uses only the saved CSVs in the latest runs/v4_stdv_ex107_201_nested53_abadie2015pl_* folder. Style from scm_v4_plots.R (same as the existing manuscript figures).
## Figures: 1 path, 2 gap, 3 RMSPE ratio ranking, 4 placebo gaps, 10 ratio histogram → placebo figures in two sets: all (tau=Inf, main test) and excluding >5x (sensitivity)
##       5 LOO (V·W re-estimated). In-time placebo figures are not redrawn, since the existing nested53 results remain valid.
## Post window: as saved (regular sites weeks 51–96; construction-affected sites 1·2·10 weeks 51–72).
## Run (from repo root): Rscript code/03_road_scm/plot_nested53_abadie2015pl.R
## RESTRICTED DATA REQUIRED (restricted data required): road detector inputs (Seoul TOPIS sites and national ITS link counts) are not redistributed (licence pending).
## Required input files (place under RAW_DIR):
##   - 77_units/0628_6to10_df_with_new_covariates_fixed.csv   (analysis panel, for unit/road names; path set in config_v4.R)
## Also reads the latest OUT_DIR/runs/v4_stdv_ex107_201_nested53_abadie2015pl_* folder written by run_nested53_abadie2015_placebo.R.
suppressMessages({ library(dplyr); library(readr); library(ggplot2) })
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # non-redistributed road inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "03_road_scm"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "03_road_scm")
source(file.path(CODE_DIR, "config_v4.R")); source(file.path(CODE_DIR, "scm_v4_functions.R")); source(file.path(CODE_DIR, "scm_v4_plots.R"))
## [2026-11-03] The test statistic remains the RMSPE ratio (Abadie et al. 2015). The original scm_v4_plots.R is left untouched; only the histogram title ("limitInf") is tidied within this script.
relabel <- function(f, pairs) { s <- paste(deparse(f, width.cutoff = 500L), collapse = "\n"); for (p in pairs) { stopifnot(any(grepl(p[1], s, fixed = TRUE))); s <- gsub(p[1], p[2], s, fixed = TRUE) }
  g <- eval(parse(text = s)); environment(g) <- globalenv(); g }
plot_placebo_ratio_hist <- relabel(plot_placebo_ratio_hist, list(c("sprintf(\"Placebo RMSPE Ratio Histogram (limit%g)\", tau)",
    "sprintf(\"Placebo RMSPE Ratio Histogram (%s)\", if (is.infinite(tau)) \"all placebos\" else paste0(\"pre RMSPE <= \", tau, \"x treated\"))")))
RUN <- sort(Sys.glob(file.path(OUT_DIR, "runs", "v4_stdv_ex107_201_nested53_abadie2015pl_*")), decreasing = TRUE)[1]
stopifnot(!is.na(RUN)); cat("run:", RUN, "\n")
OUT <- file.path(RUN, "plots"); TAUS <- c(Inf, 5); T0 <- 51; N_PRE <- 50
df <- load_panel(CFG, function(...) invisible(NULL))
names_df <- df %>% distinct(unit_id_num, unit_name_en)
S <- read_csv(file.path(RUN, "all_units_summary.csv"), show_col_types = FALSE)
.showtext_on()
for (u in S$treated_unit) {
  ud <- file.path(RUN, sprintf("unit_%02d", u)); s <- S[S$treated_unit == u, ]
  r1 <- df[df$unit_id_num == u, ][1, ]; rl <- paste0(r1$road_en, " ", ifelse(as.integer(r1$direction) == 1, "NB", "SB"))
  P  <- read_csv(file.path(ud, "path.csv"), show_col_types = FALSE)
  PL <- read_csv(file.path(ud, "placebo_paths.csv"), show_col_types = FALSE)
  RS <- read_csv(file.path(ud, "placebo_results.csv"), show_col_types = FALSE) %>%
    left_join(names_df, by = c("placebo_unit" = "unit_id_num")) %>% rename(unit_name = unit_name_en)
  pdir <- file.path(OUT, sprintf("%02d", u)); tag <- sprintf("nested53_%dw", s$post_to - T0 + 1)
  plot_path_legacy(P, file.path(pdir, sprintf("1.scm_path_%d_%s.jpg", u, tag)), paste0("SCM Path Plot - ", rl), "Weekly traffic", T0, "path")
  plot_path_legacy(P, file.path(pdir, sprintf("2.scm_gap_%d_%s.jpg", u, tag)), paste0("Gap Plot - ", rl), "Gap (Treated - Synthetic)", T0, "gap")
  for (tau in TAUS) {
    lab <- if (is.infinite(tau)) "all" else sprintf("tau%g", tau)
    plot_mspe_ratio_ranked(RS, s$pre_rmspe, s$ratio, rl, tau, file.path(pdir, sprintf("3.rmspe_ratio_%d_%s_%s.jpg", u, tag, lab)))
    plot_placebo_gaps_limit(PL, RS, P, s$pre_rmspe, N_PRE, tau, rl, file.path(pdir, sprintf("4.placebo_gaps_%d_%s_%s.jpg", u, tag, lab)))
    plot_placebo_ratio_hist(RS, s$pre_rmspe, s$ratio, tau, file.path(pdir, sprintf("10.placebo_hist_%d_%s_%s.jpg", u, tag, lab)))
  }
  lp <- file.path(ud, "loo_paths_twostep.csv")
  if (file.exists(lp)) plot_loo_synthstyle(P, read_csv(lp, show_col_types = FALSE), paste0("Leave-One-Out Path Plot - ", rl, " (V re-selected)"), T0,
                                           file.path(pdir, sprintf("5.loo_%d_%s_twostep.jpg", u, tag)))
  cat(sprintf("unit %d done: p(all) %.3f, placebos %d\n", u, s$p_all, nrow(RS)))
}
cat("saved", OUT, "\n")
