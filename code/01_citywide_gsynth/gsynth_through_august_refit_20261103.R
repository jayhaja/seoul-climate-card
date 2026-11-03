# Citywide Seoul gsynth: refit on the panel truncated at August 2024 (30th post-treatment week) (2026-11-03)
#  The earlier "1.444% through August" aggregates, over 30 weeks only, the gaps of a model fitted on all 46 post weeks (no refit).
#  Here the September-December data are dropped from the panel and the model itself is refitted, so factors/loadings may change.
#  Same specification as the main model: users ~ D + log_pop, two-way, r = 4 fixed (no CV), unweighted, installed fect (method = "gsynth").
#    (As noted in ife_vs_gsynth_point_20261102.R: unweighted, no-CV fits match the patched engine, so first check that the full 46 weeks reproduce 288.41 / 1.568%.)
#  Options: CV=1 reselects r with fect's default CV instead of rolling CV (reference only). NB>0 adds an OD block bootstrap (fect built-in, normal-approximation CI).
# Run (from repo root): Rscript code/01_citywide_gsynth/gsynth_through_august_refit_20261103.R
#        With bootstrap: NB=200 CORES=2 Rscript code/01_citywide_gsynth/gsynth_through_august_refit_20261103.R
## INPUT DATA: the smart-card OD panels are published in data/transit/ (export approved). Inputs below that are
## not in the repository yet are marked as such.
## Required input files (place under RAW_DIR):
##   - data/transit/d_w30_no과천.rds (included in the repo; TRANSIT_DIR)                 (OD x week panel; builder script not in this repo)
##     (file name kept as delivered by the data holder; no과천 = excluding Gwacheon)
##   - data/transit/od_with_pop_sum_without_holiday.csv.gz (included; read as gzip)     (OD-level weekly users + population, holiday weeks removed)
##     (column 이용자수_주총합 = weekly total users; Korean column names are kept as in the data)
suppressPackageStartupMessages({ library(fect); library(dplyr); library(readr) })
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
TRANSIT_DIR <- Sys.getenv("TRANSIT_DIR", file.path(REPO_ROOT, "data/transit"))   # published transit panels (data/transit/)
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth/gsynth_through_august_refit_20261103"))
root <- path.expand(RAW_DIR)
out <- path.expand(OUT_DIR); dir.create(out, recursive = TRUE, showWarnings = FALSE)
NB <- as.integer(Sys.getenv('NB', '0')); CORES <- as.integer(Sys.getenv('CORES', '2')); DO_CV <- Sys.getenv('CV', '0') == '1'

## Panel (same construction as ife_vs_gsynth_point_20261102.R)
d <- readRDS(file.path(TRANSIT_DIR, 'd_w30_no과천.rds')); tr <- unique(d$unit_id[d$D == 1])
needed <- c('unit_id', 'week_index', 'week', 'ym', 'origin_region', 'origin_sigungu', 'origin_dong', 'pop_total', '이용자수_주총합')
raw <- read_csv(file.path(TRANSIT_DIR, 'od_with_pop_sum_without_holiday.csv.gz'), col_select = all_of(needed), show_col_types = FALSE)
sg <- raw %>% distinct(origin_region, origin_sigungu, origin_dong, ym, pop_total) %>% group_by(origin_region, origin_sigungu, ym) %>%
  summarise(pop_total_sg = sum(pop_total, na.rm = TRUE), .groups = 'drop')
key <- function(x) paste(x$unit_id, x$week_index, sep = ':'); raw <- raw[key(raw) %in% key(d), ]
raw <- raw %>% left_join(sg, by = c('origin_region', 'origin_sigungu', 'ym')) %>% mutate(pop_total = if_else(pop_total < 100, pop_total_sg, pop_total))
raw <- raw[match(key(d), key(raw)), ]; stopifnot(identical(key(d), key(raw)), length(tr) == 409)
d$users <- raw$이용자수_주총합; d$log_pop <- log(raw$pop_total); d$week <- as.Date(raw$week)
t0 <- min(d$week_index[d$D == 1]); post_all <- sort(unique(d$week_index[d$week_index >= t0])); stopifnot(length(post_all) == 46)
cut_wi <- post_all[30]; cat('Treatment start', format(min(d$week[d$week_index == t0])), '| last week of truncated panel', format(unique(d$week[d$week_index == cut_wi])), '\n')

fit <- function(dd, label) {
  set.seed(20260731L)
  f <- fect(users ~ D + log_pop, data = as.data.frame(dd), index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way',
            CV = DO_CV, r = if (DO_CV) c(0, 6) else 4, se = NB > 0, nboots = max(NB, 1), parallel = NB > 0, cores = CORES,
            vartype = 'bootstrap', tol = 1e-4, max.iteration = 2000)
  idx <- which(colSums(f$D.dat) > 0); post <- f$rawtime >= t0
  g <- f$Y.dat[post, idx] - f$Y.ct[post, idx]; cf <- f$Y.ct[post, idx]
  res <- data.frame(model = label, r = f$r.cv, post_weeks = sum(post), ATT_count = mean(g), weekly_total_gap = sum(g) / sum(post),
                    effect_pct = 100 * sum(g) / sum(cf))
  if (NB > 0 && !is.null(f$est.avg)) { se <- f$est.avg[1, 'S.E.']; res$ATT_count_lo <- res$ATT_count - 1.96 * se; res$ATT_count_hi <- res$ATT_count + 1.96 * se
    wk_cf <- sum(cf) / sum(post)   # weekly counterfactual total
    res$pct_lo <- 100 * res$ATT_count_lo * ncol(g) / wk_cf; res$pct_hi <- 100 * res$ATT_count_hi * ncol(g) / wk_cf }
  print(res, row.names = FALSE); res
}
R <- rbind(fit(d, 'full 46wk (reproduction check: 288.41 / 1.568%)'),
           fit(d[d$week_index <= cut_wi, ], 'through Aug: refit on truncated panel'))
## Comparison: 30-week aggregate of the full-panel model (manuscript value)
R <- rbind(R[, c('model', 'r', 'post_weeks', 'ATT_count', 'weekly_total_gap', 'effect_pct')],
           data.frame(model = 'through Aug: full-fit window (manuscript)', r = 4, post_weeks = 30, ATT_count = 267.944, weekly_total_gap = 109589.2, effect_pct = 1.444))
print(R, row.names = FALSE); write.csv(R, file.path(out, 'through_august_refit.csv'), row.names = FALSE)
writeLines(c('Refit of main gsynth spec (users ~ D + log_pop, r=4 fixed, unweighted, installed fect) on panel truncated at the 30th post-treatment week (end of Aug 2024).',
             'Compare with the full-46-week fit aggregated over the same 30 weeks (manuscript 1.444%). Bootstrap CI only if NB>0 (fect internal, pct CI approximated with fixed counterfactual denominator).'),
           file.path(out, 'README.txt'))
