# Seoul-wide roads — re-analysis following the Liu, Wang & Xu (2024) guide (2026-11-03)
#  Estimators: gsynth (factors from controls only) / ife (IFEct: factors also use treated sites' pre-treatment data) / mc (matrix completion)
#  Diagnostics (guide, Section 3): (1) placebo test — last 3 pre weeks (−2 to 0) (2) pre-trend F test (last PRE_F weeks) + equivalence (TOST, bound ±0.36σε)
#                    (3) minimum range = max absolute 90% CI bound of pre-treatment weekly ATTs (4) optional: leave-one-period-out (LOO=1)
#  Sensitivity (APSR 2026): M̄=0 debiased estimate (ATT − placebo last-week gap) + relative-magnitude robust CIs if fect_sens is installed
#  Groups: all (149 sites) and types A (downtown) B (city boundary) C (bridges) D (arterials) F (urban expressways). 53 common donors.
#  Outcome: daily median of weekday 06–09h hourly volume → weekly median (veh/h). Treatment from week 51; weeks 51–96.
# Run (from repo root, serial, "all" group first):  NB=100 GROUPS=all Rscript code/05_seoul_road_gsynth/seoul_road_lwx_20261103.R
#        Including types:     NB=100 Rscript code/05_seoul_road_gsynth/seoul_road_lwx_20261103.R
#        Subset of estimators: METHODS=ife,mc ...    GMSPE-min r: R_MODE=min ...    Add LOO: LOO=1 (slow)
## RESTRICTED DATA REQUIRED: TOPIS road detector traffic volumes — not redistributed (licence pending).
## Required input files (place under RAW_DIR):
##   - panel_seoul176_donor53_6to9.csv   (weekly panel: 176 TOPIS Seoul sites + 53 non-Seoul donor links; built in Python, the build script is not in this repo)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted / non-redistributed inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "05_seoul_road_gsynth/seoul_road_gsynth_20261103/lwx"))
suppressPackageStartupMessages({ library(fect); library(dplyr) })
out <- OUT_DIR; dir.create(out, showWarnings = FALSE, recursive = TRUE)
NB <- as.integer(Sys.getenv('NB', '100')); METHODS <- strsplit(Sys.getenv('METHODS', 'gsynth,ife,mc'), ',')[[1]]
GROUPS <- strsplit(Sys.getenv('GROUPS', 'all,A,B,C,D,F'), ',')[[1]]; R_MODE <- Sys.getenv('R_MODE', 'cv')
PRE_F <- as.integer(Sys.getenv('PRE_F', '12')); LOO <- Sys.getenv('LOO', '0') == '1'
P0 <- read.csv(file.path(RAW_DIR, 'panel_seoul176_donor53_6to9.csv'), fileEncoding = 'UTF-8-BOM') %>%
  filter(week_index <= 96) %>% mutate(D = as.integer(is_treat == 1 & week_index >= 51))
cat('fect', as.character(packageVersion('fect')), '| methods', METHODS, '| groups', GROUPS, '| nboots', NB, '| r mode', R_MODE, '| LOO', LOO, '\n')
has_sens <- exists('fect_sens', envir = asNamespace('fect'))
cat('fect_sens available:', has_sens, '\n')

cv_pick <- function(P, m) {
  set.seed(1234)
  common <- list(formula = traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = m, force = 'two-way', CV = TRUE,
                 cv.method = 'rolling', cv.rule = '1se', cv.buffer = 1, cv.nobs = 3, k = 20, cv.prop = 0.1, criterion = 'gmspe', se = FALSE)
  if (m == 'mc') common$nlambda <- 10 else common$r <- c(0, 5)
  f <- do.call(fect, common)
  if (m == 'mc') return(list(par = f$lambda.cv, label = sprintf('lambda=%.3g', f$lambda.cv)))
  r_min <- tryCatch({ co <- as.data.frame(f$CV.out); as.integer(co$r[which.min(co$GMSPE)]) }, error = function(e) NA_integer_)
  r <- if (R_MODE == 'min' && !is.na(r_min)) r_min else f$r.cv
  list(par = r, label = sprintf('r=%d (1se %d, GMSPE-min %s)', r, f$r.cv, r_min))
}
fit <- function(P, m, par, placebo = FALSE, loo = FALSE) {
  set.seed(20260731L)
  a <- list(formula = traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = m, force = 'two-way', CV = FALSE,
            se = TRUE, nboots = NB, parallel = FALSE, vartype = 'bootstrap', pre.periods = c(-(PRE_F - 1), 0))
  if (m == 'mc') a$lambda <- par else a$r <- par
  if (placebo) { a$placeboTest <- TRUE; a$placebo.period <- c(-2, 0) }
  if (loo) a$loo <- TRUE
  do.call(fect, a)
}
one <- function(g, m) {
  P <- if (g == 'all') P0 else P0 %>% filter(is_treat == 0 | type == g)
  n_tr <- n_distinct(P$unit_id[P$is_treat == 1]); cat(sprintf('\n--- %s / %s (treated %d) ---\n', g, m, n_tr))
  cv <- cv_pick(P, m); cat('Selected:', cv$label, '\n')
  f <- fit(P, m, cv$par); fp <- fit(P, m, cv$par, placebo = TRUE)
  idx <- which(colSums(f$D.dat, na.rm = TRUE) > 0); post <- f$rawtime >= 51
  pct <- 100 * sum(f$Y.dat[post, idx] - f$Y.ct[post, idx], na.rm = TRUE) / sum(f$Y.ct[post, idx], na.rm = TRUE)
  att <- as.data.frame(f$est.att); att$rel <- as.integer(rownames(att)); pre <- att[att$rel <= 0 & is.finite(att$S.E.), ]
  min_range <- max(abs(c(pre$ATT - 1.645 * pre$S.E., pre$ATT + 1.645 * pre$S.E.)))      # guide's minimum range (based on 90% CI)
  e <- f$est.avg; pl <- fp$est.placebo; to <- f$test.out
  thr <- if (!is.null(to$tost.threshold)) to$tost.threshold else if (!is.null(to$f.threshold)) to$f.threshold else NA
  d0 <- tryCatch(as.data.frame(fp$est.att)[as.character(0), 'ATT'], error = function(e) NA)   # placebo last-week gap δ0
  row <- data.frame(group = g, method = m, n_sites = n_tr, tuning = cv$label,
                    ATT = e[1, 'ATT.avg'], lo = e[1, 'CI.lower'], hi = e[1, 'CI.upper'], p = e[1, 'p.value'], pct_vs_cf = pct,
                    placebo_ATT = pl[1, 'ATT.placebo'], placebo_p = pl[1, 'p.value'],
                    placebo_tost_p = if (!is.null(fp$test.out$tost.equiv.p)) fp$test.out$tost.equiv.p else NA,
                    preF_p = if (!is.null(to$f.p)) to$f.p else NA, pre_tost_p = if (!is.null(to$tost.equiv.p)) to$tost.equiv.p else NA,
                    equiv_threshold = thr, min_range = min_range, delta0 = d0, ATT_debiased_M0 = e[1, 'ATT.avg'] - d0)
  if (LOO) { fl <- tryCatch(fit(P, m, cv$par, loo = TRUE), error = function(e) NULL)
    if (!is.null(fl)) { row$loo_preF_p <- fl$test.out$f.p; row$loo_tost_p <- fl$test.out$tost.equiv.p } }
  if (has_sens) row$sens <- tryCatch({ s <- fect::fect_sens(fp, Mbarvec = c(0, 0.5, 1)); paste(capture.output(print(s))[1:min(8, length(capture.output(print(s))))], collapse = ' | ') },
                                     error = function(e) paste('fect_sens error:', conditionMessage(e)))
  png(file.path(out, sprintf('gap_%s_%s.png', g, m)), width = 1600, height = 900, res = 160)
  print(plot(f, main = sprintf('%s / %s (%d sites), %s', g, m, n_tr, cv$label))); dev.off()
  png(file.path(out, sprintf('equiv_%s_%s.png', g, m)), width = 1600, height = 900, res = 160)
  print(tryCatch(plot(f, type = 'equiv'), error = function(e) plot.new())); dev.off()
  saveRDS(list(main = f, placebo = fp), file.path(out, sprintf('fit_%s_%s.rds', g, m)))
  print(row, row.names = FALSE); row
}
R <- list()
for (g in GROUPS) for (m in METHODS) R[[paste(g, m)]] <- tryCatch(one(g, m), error = function(e) { cat('Error', g, m, conditionMessage(e), '\n'); NULL })
R <- bind_rows(R)
num <- intersect(c('ATT', 'lo', 'hi', 'pct_vs_cf', 'placebo_ATT', 'equiv_threshold', 'min_range', 'delta0', 'ATT_debiased_M0'), names(R)); R[num] <- round(R[num], 2)
pc <- intersect(c('p', 'placebo_p', 'placebo_tost_p', 'preF_p', 'pre_tost_p', 'loo_preF_p', 'loo_tost_p'), names(R)); R[pc] <- signif(R[pc], 3)
# Pass rules (per the guide): placebo p > .10; minimum range < equivalence bound (or 50 veh/h ≈ 2%)
R$pass_placebo <- R$placebo_p > .10
R$pass_equiv <- !is.na(R$min_range) & R$min_range < pmin(R$equiv_threshold, 50, na.rm = TRUE)
cat('\n== Summary ==\n'); print(as.data.frame(R[, setdiff(names(R), 'sens')]), row.names = FALSE)
write.csv(R, file.path(out, sprintf('lwx_summary_%s.csv', format(Sys.time(), '%Y%m%d_%H%M'))), row.names = FALSE, fileEncoding = 'UTF-8')
cat('saved', out, '\n')
