# Seoul-wide road traffic gsynth (2026-11-03)
#  Treated: Seoul permanent traffic-count sites (TOPIS; 149 of 176 with >=90% coverage). Controls: 53 non-Seoul donor links from the road SCM main spec.
#  Outcome: daily median of weekday (non-holiday) 06:00–09:59 hourly volume → weekly median (same definition as the road SCM, road6to9_new_try basis)
#  Treatment starts at week_index 51 (2024-01-29); post weeks 51–96 (46 weeks, through 2024-12-16). Weeks 97+ (year-end holidays, 2025) excluded.
#  Panel: RAW_DIR/panel_seoul176_donor53_6to9.csv (built in Python; zeros treated as missing)
#  Spec: traffic ~ D, two-way, gsynth. r chosen by (1) CV (0–5) and (2) fixed 1–4 as sensitivity. No weights. Missing values: fect default.
#  Outputs: overall effect (veh/h, % vs counterfactual), re-aggregation by site type (A downtown, B city boundary, C Han River bridges, D arterials, F urban expressways), results excluding Yeouido-linked sites, site-level gaps
# Run (from repo root): Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_20261103.R
#       Bootstrap: NB=200 CORES=2 Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_20261103.R  (applied only to the CV-selected r)
## INPUT DATA REQUIRED: TOPIS road detector traffic volumes. Redistributable, but the panel is not yet in this repository.
## Required input files (place under RAW_DIR):
##   - panel_seoul176_donor53_6to9.csv   (weekly panel: 176 TOPIS Seoul sites + 53 non-Seoul donor links; built in Python, the build script is not in this repo)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # inputs not in the repository (restricted OD panel or not-yet-uploaded files)
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "05_seoul_road_gsynth/seoul_road_gsynth_20261103"))
suppressPackageStartupMessages({ library(fect); library(dplyr) })
out <- OUT_DIR; dir.create(out, showWarnings = FALSE, recursive = TRUE)
NB <- as.integer(Sys.getenv('NB', '0')); CORES <- as.integer(Sys.getenv('CORES', '2'))
P <- read.csv(file.path(RAW_DIR, 'panel_seoul176_donor53_6to9.csv'), fileEncoding = 'UTF-8-BOM')
P <- P %>% filter(week_index <= 96) %>% mutate(D = as.integer(is_treat == 1 & week_index >= 51))
yeo <- c('C-06_0','C-06_1','C-07_0','C-07_1','C-08_0','C-08_1','D-29_0','D-41_0','D-41_1','F-10_0','F-10_1')   # Yeouido-linked sites
meta <- P %>% filter(is_treat == 1) %>% distinct(unit_id, site, type, roadName, path) %>% mutate(yeouido = site %in% yeo)
cat('treated', n_distinct(P$unit_id[P$is_treat == 1]), '| control', n_distinct(P$unit_id[P$is_treat == 0]), '| weeks', n_distinct(P$week_index), '| missing', round(mean(is.na(P$traffic)), 4), '\n')

CRIT <- Sys.getenv('CRIT', 'gmspe')   # rolling CV, 1se rule, GMSPE as in the transit main spec (MSPE comparison: CRIT=mspe)
fitone <- function(r, cv = FALSE, se = FALSE) {
  set.seed(20260731L)
  if (cv) { set.seed(1234)
    return(fect(traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way',
                CV = TRUE, r = c(0, 5), cv.method = 'rolling', cv.rule = '1se', cv.buffer = 1, cv.nobs = 3, k = 20, cv.prop = 0.1,
                criterion = CRIT, se = se, nboots = max(NB, 1), parallel = se && CORES > 1, cores = CORES, vartype = 'bootstrap')) }
  fect(traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way',
       CV = FALSE, r = r, se = se, nboots = max(NB, 1), parallel = se && CORES > 1, cores = CORES, vartype = 'bootstrap')
}
summ <- function(f, label) {
  idx <- which(colSums(f$D.dat, na.rm = TRUE) > 0); post <- f$rawtime >= 51
  ids <- as.integer(f$id[idx]); Y <- f$Y.dat[post, idx]; C <- f$Y.ct[post, idx]; G <- Y - C
  pre <- !post; pre_rmse <- sqrt(colMeans((f$Y.dat[pre, idx] - f$Y.ct[pre, idx])^2, na.rm = TRUE))
  site <- data.frame(unit_id = ids, gap = colMeans(G, na.rm = TRUE), cf = colMeans(C, na.rm = TRUE), pre_rmse = pre_rmse) %>% left_join(meta, by = 'unit_id')
  agg <- function(s, grp) s %>% summarise(n = n(), ATT = mean(gap), pct = 100 * sum(gap) / sum(cf), pre_rmse = mean(pre_rmse)) %>% mutate(group = grp, .before = 1)
  res <- bind_rows(agg(site, 'All'), agg(filter(site, !yeouido), 'Excluding Yeouido sites'),
                   bind_rows(lapply(split(site, site$type), function(s) agg(s, paste0('Type ', s$type[1])))))
  res$model <- label; res$r <- f$r.cv; list(res = res, site = site)
}
R <- list(); S <- NULL
f_cv <- fitone(NA, cv = TRUE, se = NB > 0); o <- summ(f_cv, paste0('CV rolling 1se ', CRIT)); R[[1]] <- o$res; S <- o$site
cat('CV-selected r =', f_cv$r.cv, '\n')
if (NB > 0) { e <- f_cv$est.avg; cat('Bootstrap ATT (veh/h):', round(e[1, 'ATT.avg'], 1), '[', round(e[1, 'CI.lower'], 1), ',', round(e[1, 'CI.upper'], 1), '] p =', signif(e[1, 'p.value'], 3), '\n') }
for (r in 1:4) if (r != f_cv$r.cv) R[[length(R) + 1]] <- summ(fitone(r), paste0('r = ', r))$res
R <- bind_rows(R); R[c('ATT', 'pct', 'pre_rmse')] <- round(R[c('ATT', 'pct', 'pre_rmse')], 2)
print(as.data.frame(R), row.names = FALSE)
write.csv(R, file.path(out, paste0('seoul_road_effects_cv', CRIT, '.csv')), row.names = FALSE, fileEncoding = 'UTF-8')
write.csv(S %>% mutate(pct = 100 * gap / cf) %>% arrange(pct), file.path(out, paste0('seoul_road_site_gaps_cv', CRIT, '.csv')), row.names = FALSE, fileEncoding = 'UTF-8')
saveRDS(f_cv, file.path(out, paste0('fit_cv_', CRIT, '.rds')))
writeLines(c('Seoul-wide road gsynth: 149 TOPIS sites (>=90% weekly coverage) treated from week 51 (2024-01-29), 53 non-Seoul donor links from the road SCM main spec.',
             'Outcome: weekday non-holiday 06-09h hourly volume, daily median -> weekly median (vehicles/hour). Post weeks 51-96.',
             'Effects: mean gap (veh/h) and 100*sum(gap)/sum(counterfactual). Groups by site type (A downtown, B city boundary, C Han bridges, D arterials, F urban expressways); Yeouido-linked sites flagged.',
             'Point estimates for r=1..4 and CV; bootstrap only with NB>0 (fect internal, CV-selected r).'), file.path(out, 'README.txt'))
cat('saved', out, '\n')
