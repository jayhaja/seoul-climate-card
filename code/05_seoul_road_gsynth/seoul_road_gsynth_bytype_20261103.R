# Seoul-wide road gsynth — separate fits by site type + per-type diagnostics (2026-11-03)
#  Types: A downtown, B city boundary, C Han River bridges, D arterials, F urban expressways. Only that type's Seoul sites are treated; the 53 donors are common controls.
#  For each type: (1) choose r by rolling CV (1se, GMSPE) and record the GMSPE-minimising r (2) bootstrap ATT at that r (3) placebo test (last 4 pre weeks) (4) pre-treatment F and equivalence tests
#  OUTCOME: level (veh/h, default) or index (site pre-treatment mean = 100 → effects read as percentage points vs pre-treatment)
#  R_MODE: cv (default, r after 1se rule) / min (GMSPE-minimising r) / a number (fixed r)
# Run (from repo root, serial): Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
#        Index outcome:  OUTCOME=index Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
#        GMSPE-min r: R_MODE=min Rscript ...      Subset of types: TYPES=C,D Rscript ...
## INPUT DATA REQUIRED: TOPIS road detector traffic volumes. Redistributable, but the panel is not yet in this repository.
## Required input files (place under RAW_DIR):
##   - panel_seoul176_donor53_6to9.csv   (weekly panel: 176 TOPIS Seoul sites + 53 non-Seoul donor links; built in Python, the build script is not in this repo)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # inputs not in the repository (restricted OD panel or not-yet-uploaded files)
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "05_seoul_road_gsynth/seoul_road_gsynth_20261103/bytype"))
suppressPackageStartupMessages({ library(fect); library(dplyr) })
out <- OUT_DIR; dir.create(out, showWarnings = FALSE, recursive = TRUE)
NB <- as.integer(Sys.getenv('NB', '200')); OUTCOME <- Sys.getenv('OUTCOME', 'level'); R_MODE <- Sys.getenv('R_MODE', 'cv')
TYPES <- strsplit(Sys.getenv('TYPES', 'A,B,C,D,F'), ',')[[1]]
PRE_F <- as.integer(Sys.getenv('PRE_F', '12'))   # window for F and equivalence tests: last PRE_F pre-treatment weeks (fect computes F only if #treated sites > #test weeks)
P0 <- read.csv(file.path(RAW_DIR, 'panel_seoul176_donor53_6to9.csv'), fileEncoding = 'UTF-8-BOM') %>%
  filter(week_index <= 96) %>% mutate(D = as.integer(is_treat == 1 & week_index >= 51))
if (OUTCOME == 'index') P0 <- P0 %>% group_by(unit_id) %>% mutate(y = 100 * traffic / mean(traffic[week_index < 51], na.rm = TRUE)) %>% ungroup() else P0$y <- P0$traffic
cat('outcome =', OUTCOME, '| r mode =', R_MODE, '| nboots =', NB, '\n')

one_type <- function(ty) {
  P <- P0 %>% filter(is_treat == 0 | type == ty); n_tr <- n_distinct(P$unit_id[P$is_treat == 1])
  set.seed(1234)
  cvf <- fect(y ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way', CV = TRUE, r = c(0, 5),
              cv.method = 'rolling', cv.rule = '1se', cv.buffer = 1, cv.nobs = 3, k = 20, cv.prop = 0.1, criterion = 'gmspe', se = FALSE)
  r_cv <- cvf$r.cv
  r_min <- tryCatch({ cr <- cvf$CV.out[, 'GMSPE']; as.integer(cvf$CV.out[which.min(cr), 'r']) }, error = function(e) NA_integer_)
  r_use <- switch(R_MODE, cv = r_cv, min = ifelse(is.na(r_min), r_cv, r_min), as.integer(R_MODE))
  set.seed(20260731L)
  f <- fect(y ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way', CV = FALSE, r = r_use,
            se = TRUE, nboots = NB, parallel = FALSE, vartype = 'bootstrap', pre.periods = c(-(PRE_F - 1), 0))
  set.seed(20260731L)
  fp <- fect(y ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way', CV = FALSE, r = r_use,
             se = TRUE, nboots = NB, parallel = FALSE, vartype = 'bootstrap', placeboTest = TRUE, placebo.period = c(-3, 0))
  idx <- which(colSums(f$D.dat, na.rm = TRUE) > 0); post <- f$rawtime >= 51
  pct <- 100 * sum(f$Y.dat[post, idx] - f$Y.ct[post, idx], na.rm = TRUE) / sum(f$Y.ct[post, idx], na.rm = TRUE)
  att <- as.data.frame(f$est.att); att$rel <- as.integer(rownames(att)); pre <- att[att$rel <= 0, ]
  e <- f$est.avg; pl <- fp$est.placebo; to <- f$test.out
  png(file.path(out, sprintf('gap_%s_%s_r%d.png', ty, OUTCOME, r_use)), width = 1600, height = 900, res = 160)
  print(plot(f, main = sprintf('Type %s (%d sites), %s, r = %d', ty, n_tr, OUTCOME, r_use))); dev.off()
  data.frame(type = ty, n_sites = n_tr, outcome = OUTCOME, r_cv_1se = r_cv, r_gmspe_min = r_min, r_used = r_use,
             ATT = e[1, 'ATT.avg'], lo = e[1, 'CI.lower'], hi = e[1, 'CI.upper'], p = e[1, 'p.value'], pct_vs_cf = pct,
             placebo_ATT = pl[1, 'ATT.placebo'], placebo_p = pl[1, 'p.value'],
             pre_F_p = if (!is.null(to$f.p)) to$f.p else NA, equiv_p = if (!is.null(to$f.equiv.p)) to$f.equiv.p else NA,
             pre_weeks_off = sum(pre$CI.lower > 0 | pre$CI.upper < 0, na.rm = TRUE), pre_weeks = nrow(pre))
}
R <- do.call(rbind, lapply(TYPES, function(ty) { cat('\n--- Type', ty, '---\n'); r <- one_type(ty); print(r, row.names = FALSE); r }))
num <- c('ATT', 'lo', 'hi', 'pct_vs_cf', 'placebo_ATT'); R[num] <- round(R[num], 2); R[c('p', 'placebo_p', 'pre_F_p', 'equiv_p')] <- signif(R[c('p', 'placebo_p', 'pre_F_p', 'equiv_p')], 3)
R$diag_pass <- R$placebo_p > .10 & (is.na(R$pre_F_p) | R$pre_F_p > .05)
names(R)[names(R) == 'pre_F_p'] <- paste0('preF', PRE_F, 'wk_p'); names(R)[names(R) == 'equiv_p'] <- paste0('equiv', PRE_F, 'wk_p')
cat('\n== Summary by type ==\n'); print(R, row.names = FALSE)
write.csv(R, file.path(out, sprintf('bytype_%s_%s.csv', OUTCOME, R_MODE)), row.names = FALSE, fileEncoding = 'UTF-8')
cat('saved', out, '\n')
