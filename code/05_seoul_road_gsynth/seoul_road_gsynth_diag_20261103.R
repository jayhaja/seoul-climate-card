# Seoul-wide road gsynth diagnostics (2026-11-03): placebo test + pre-treatment trends + equivalence test
#  Panel and spec as in seoul_road_gsynth_20261103.R (149 Seoul sites vs 53 donors, 06–09h weekly median, treatment at week 51, weeks 51–96).
#  (1) Placebo test: last 4 pre weeks (relative weeks −3 to 0) as a fake treatment period via fect placeboTest → placebo ATT and p
#  (2) Pre-treatment trends: relative-week ATTs of the main fit (pre period), F test and equivalence test (built into fect)
#  (3) Figures: relative-week gap and equivalence plots (png)
#  r = R_FIX (default 0 = the CV-selected value). Bootstrap NB (default 200), serial by default (CORES=1).
# Run (from repo root): Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_diag_20261103.R
#       Compare r=4:  R_FIX=4 Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_diag_20261103.R
## RESTRICTED DATA REQUIRED: TOPIS road detector traffic volumes — not redistributed (licence pending).
## Required input files (place under RAW_DIR):
##   - panel_seoul176_donor53_6to9.csv   (weekly panel: 176 TOPIS Seoul sites + 53 non-Seoul donor links; built in Python, the build script is not in this repo)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted / non-redistributed inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "05_seoul_road_gsynth/seoul_road_gsynth_20261103"))
suppressPackageStartupMessages({ library(fect); library(dplyr) })
out <- OUT_DIR; dir.create(out, showWarnings = FALSE, recursive = TRUE)
R_FIX <- as.integer(Sys.getenv('R_FIX', '0')); NB <- as.integer(Sys.getenv('NB', '200')); CORES <- as.integer(Sys.getenv('CORES', '1'))
P <- read.csv(file.path(RAW_DIR, 'panel_seoul176_donor53_6to9.csv'), fileEncoding = 'UTF-8-BOM') %>%
  filter(week_index <= 96) %>% mutate(D = as.integer(is_treat == 1 & week_index >= 51))
tag <- paste0('r', R_FIX); cat('r =', R_FIX, '| nboots =', NB, '| cores =', CORES, '\n')
par_on <- CORES > 1

## (1) Placebo test
set.seed(20260731L)
fp <- fect(traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way', CV = FALSE, r = R_FIX,
           se = TRUE, nboots = NB, parallel = par_on, cores = CORES, vartype = 'bootstrap',
           placeboTest = TRUE, placebo.period = c(-3, 0))
pl <- fp$est.placebo
cat('\n== Placebo test (last 4 pre weeks as fake treatment) ==\n'); print(pl)
write.csv(as.data.frame(pl), file.path(out, sprintf('diag_placebo_%s.csv', tag)))

## (2) Main fit + pre-treatment trends and equivalence
set.seed(20260731L)
f <- fect(traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way', CV = FALSE, r = R_FIX,
          se = TRUE, nboots = NB, parallel = par_on, cores = CORES, vartype = 'bootstrap')
cat('\n== Overall ATT (veh/h, bootstrap) ==\n'); print(f$est.avg)
att <- as.data.frame(f$est.att); att$rel_week <- as.integer(rownames(att))
write.csv(att, file.path(out, sprintf('diag_event_att_%s.csv', tag)), row.names = FALSE)
pre <- att[att$rel_week <= 0, ]
cat(sprintf('\nPre-treatment relative-week ATT: mean %.1f, max |ATT| %.1f, weeks with 95%% CI excluding 0: %d/%d\n',
            mean(pre$ATT), max(abs(pre$ATT)), sum(pre$CI.lower > 0 | pre$CI.upper < 0, na.rm = TRUE), nrow(pre)))
if (!is.null(f$test.out)) { cat('\n== Pre-treatment trend tests (fect test.out) ==\n'); print(f$test.out[intersect(c('f.stat', 'f.p', 'f.equiv.p', 'tost.equiv.p'), names(f$test.out))]) }
saveRDS(list(placebo = fp, main = f), file.path(out, sprintf('diag_fits_%s.rds', tag)))

## (3) Figures
png(file.path(out, sprintf('diag_gap_%s.png', tag)), width = 1600, height = 900, res = 160)
print(plot(f, main = sprintf('Seoul road sites vs donors (r = %d): weekly gap, veh/h', R_FIX), xlab = 'Weeks relative to 2024-01-29', ylab = 'Gap (veh/h)'))
dev.off()
png(file.path(out, sprintf('diag_equiv_%s.png', tag)), width = 1600, height = 900, res = 160)
print(plot(f, type = 'equiv', main = sprintf('Pretreatment equivalence (r = %d)', R_FIX)))
dev.off()
png(file.path(out, sprintf('diag_placebo_%s.png', tag)), width = 1600, height = 900, res = 160)
print(plot(fp, main = sprintf('Placebo: last 4 pre weeks as fake treatment (r = %d)', R_FIX)))
dev.off()
cat('saved', out, '\n')
