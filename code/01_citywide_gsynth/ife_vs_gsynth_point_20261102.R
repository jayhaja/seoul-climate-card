# IFE 대체 추정량(method = "ife", Liu·Wang·Xu 2024; Hainmueller 2026이 쓴 방식) vs 주사양 gsynth(method = "gsynth", Xu 2017) — 점추정 비교
#  - 같은 패널(d_w30_no과천: 처치 409, 통제 941, 99주), 같은 식 users ~ D + log_pop, 같은 r = 4, 가중 없음, CV 없음, se = FALSE.
#  - 차이: gsynth는 요인을 통제 단위만으로 추정 후 처치 단위 적재값을 처치 전 기간에 회귀; ife는 처치받지 않은 모든 관측치(통제 전체 + 처치 단위 처치 전)로 요인·적재값을 EM으로 동시 추정.
#  - 엔진: 설치된 fect 그대로(패치 없음). gsynth 재현값이 주결과 ATT 288.41 / 1.568%와 맞는지 먼저 확인(패치는 가중·CV 경로만 건드렸으므로 비가중·CV 없음에서는 일치해야 함).
#  - 출력: 두 방법의 ATT(건수·반사실 대비 %·처치 전 대비 %), 처치 전 RMSE, OD별 격차 csv, 6장 축별 집단 per1000 비교(점추정).
# Run (from repo root): Rscript code/01_citywide_gsynth/ife_vs_gsynth_point_20261102.R   (env: METHODS, MAXIT, TOL)
## RESTRICTED DATA REQUIRED (restricted data required): this script needs files that are not
## distributed (smart-card OD data, Data Safety Center export-restricted).
## Required input files (place under RAW_DIR):
##   - panels/d_w30_no과천.rds                 (OD x week panel; builder script not in this repo)
##   - od_with_pop_sum_without_holiday.csv     (OD-level weekly users + population, holiday weeks removed)
##   - R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv   (unit-level; producer script not in this repo)
##   - 규모통제_거리환승_20261011/OD_analysis_data.csv                 (OD-level covariates; producer not in this repo)
##   - AI_uc_보정_20261101.csv, youth_region_20261101.csv,
##     elderly_ratio_unit_20261102.csv, 환승시간_unit매칭_20261101.csv  (unit-level covariates; producers not in this repo)
## Also reads an intermediate output of another script in this repo (OD-level, restricted):
##   - SUBMIT_DIR/OD_point_effects.csv  <- produced by code/01_citywide_gsynth/R2_r4_제출용집계_20261010.R
suppressPackageStartupMessages({ library(fect); library(dplyr); library(readr) })
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth/R2_ife_vs_gsynth_20261102"))
# OUT_DIR of R2_r4_제출용집계_20261010.R (source of OD_point_effects.csv)
SUBMIT_DIR <- Sys.getenv("SUBMIT_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth/R2_r4_제출용_20261010"))
root <- path.expand(RAW_DIR)
out <- path.expand(OUT_DIR); dir.create(out, recursive = TRUE, showWarnings = FALSE)
METHODS <- strsplit(Sys.getenv('METHODS', 'gsynth,ife'), ',')[[1]]; MAXIT <- as.integer(Sys.getenv('MAXIT', '2000')); TOL <- as.numeric(Sys.getenv('TOL', '1e-4'))
cat('methods:', METHODS, '| max.iteration', MAXIT, '| tol', TOL, '\n')

## 자료: R2_r4_도로기간일치_20261010.R 과 동일 구성
d <- readRDS(file.path(root, 'panels/d_w30_no과천.rds')); tr <- unique(d$unit_id[d$D == 1])
needed <- c('unit_id', 'week_index', 'week', 'ym', 'origin_region', 'origin_sigungu', 'origin_dong', 'pop_total', 'pop_youth', 'youth_ratio', '이용자수_주총합')
raw <- read_csv(file.path(root, 'od_with_pop_sum_without_holiday.csv'), col_select = all_of(needed), show_col_types = FALSE)
sg <- raw %>% distinct(origin_region, origin_sigungu, origin_dong, ym, pop_total) %>% group_by(origin_region, origin_sigungu, ym) %>%
  summarise(pop_total_sg = sum(pop_total, na.rm = TRUE), .groups = 'drop')
key <- function(x) paste(x$unit_id, x$week_index, sep = ':'); raw <- raw[key(raw) %in% key(d), ]
raw <- raw %>% left_join(sg, by = c('origin_region', 'origin_sigungu', 'ym')) %>% mutate(pop_total = if_else(pop_total < 100, pop_total_sg, pop_total))
raw <- raw[match(key(d), key(raw)), ]; stopifnot(identical(key(d), key(raw)), length(tr) == 409)
d$users <- raw$이용자수_주총합; d$log_pop <- log(raw$pop_total); stopifnot(all(is.finite(d$users)), all(is.finite(d$log_pop)))
t0 <- min(d$week_index[d$D == 1]); post_w <- sort(unique(d$week_index[d$week_index >= t0])); stopifnot(length(post_w) == 46)

fit1 <- function(method) {
  fn <- file.path(out, sprintf('fit_%s.rds', method))
  if (file.exists(fn)) { cat('[REUSE]', basename(fn), '\n'); return(readRDS(fn)) }
  set.seed(20260731L); t1 <- Sys.time(); cat(sprintf('[%s] fitting...\n', method))
  f <- fect(users ~ D + log_pop, data = d, index = c('unit_id', 'week_index'), method = method, force = 'two-way',
            CV = FALSE, r = 4, se = FALSE, parallel = FALSE, tol = TOL, max.iteration = MAXIT)
  cat(sprintf('[%s] %.1f min, niter = %s\n', method, as.numeric(difftime(Sys.time(), t1, units = 'mins')), paste(f$niter, collapse = ',')))
  f$call <- NULL; saveRDS(f, fn); f
}
odgap <- function(f) {   # 처치 OD별 처치 후 주평균 격차·반사실·관측
  idx <- which(colSums(f$D.dat) > 0); ids <- f$id[idx]; wk <- f$rawtime
  g <- f$Y.dat[, idx] - f$Y.ct[, idx]; post <- wk %in% post_w; pre <- !post
  data.frame(unit_id = ids, gap = colMeans(g[post, , drop = FALSE]), counterfactual = colMeans(f$Y.ct[post, idx, drop = FALSE]),
             observed = colMeans(f$Y.dat[post, idx, drop = FALSE]), pre_rmse = sqrt(colMeans(g[pre, , drop = FALSE]^2)))
}
fits <- setNames(lapply(METHODS, fit1), METHODS)
use_pre <- read.csv(file.path(path.expand(SUBMIT_DIR), 'OD_point_effects.csv'))[, c('unit_id', 'use_pre')]
S <- do.call(rbind, lapply(names(fits), function(m) { o <- odgap(fits[[m]]); o <- merge(o, use_pre, by = 'unit_id')
  write.csv(o, file.path(out, sprintf('od_gaps_%s.csv', m)), row.names = FALSE)
  data.frame(method = m, r = 4, ATT_count = mean(o$gap), weekly_total_gap = sum(o$gap),
             pct_vs_counterfactual = 100 * sum(o$gap) / sum(o$counterfactual), pct_vs_pre = 100 * sum(o$gap) / sum(o$use_pre),
             pre_RMSE_treated = sqrt(mean(o$pre_rmse^2)), beta_log_pop = unname(fits[[m]]$beta[1]), niter = if (length(fits[[m]]$niter) == 1) fits[[m]]$niter else NA) }))
cat('\n== 주결과 비교 (참고: 주사양 gsynth ATT 288.41, 1.568%) ==\n'); print(S, row.names = FALSE, digits = 5)
write.csv(S, file.path(out, 'summary.csv'), row.names = FALSE)

## 6장 축별 집단 per1000 (인구 1,000명 이상) — 두 방법 점추정 비교
p <- read.csv(file.path(root, 'R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv'))[, c('unit_id', 'pre_population')]
x <- read.csv(file.path(root, '규모통제_거리환승_20261011/OD_analysis_data.csv'))
ai <- read.csv(file.path(root, 'AI_uc_보정_20261101.csv')); yr <- read.csv(file.path(root, 'youth_region_20261101.csv'))
el <- read.csv(file.path(root, 'elderly_ratio_unit_20261102.csv')); wt <- read.csv(file.path(root, '환승시간_unit매칭_20261101.csv'))
m <- function(df, v) df[[v]][match(p$unit_id, df$unit_id)]
tert <- function(v) { ok <- is.finite(v); o <- rep(NA_integer_, length(v)); q <- quantile(v[ok], c(0, 1/3, 2/3, 1), type = 7); o[ok] <- cut(v[ok], q, include.lowest = TRUE, labels = FALSE); o }
axes <- list(transfer = tert(m(x, 'transfer')), wait = tert(m(wt, 'minutes_per_trip')), access = tert(m(ai, 'AI_uc')),
             distance = tert(m(x, 'distance_km')), youth = tert(m(yr, 'youth_ratio')), elderly = tert(m(el, 'elderly_ratio')))
keep <- p$pre_population >= 1000
H <- do.call(rbind, lapply(names(fits), function(mt) { o <- read.csv(file.path(out, sprintf('od_gaps_%s.csv', mt))); gap <- o$gap[match(p$unit_id, o$unit_id)]
  do.call(rbind, lapply(names(axes), function(a) { g <- axes[[a]]
    v <- sapply(1:3, function(k) { z <- keep & g %in% k; 1000 * sum(gap[z]) / sum(p$pre_population[z]) })
    data.frame(method = mt, axis = a, low = v[1], mid = v[2], high = v[3], high_minus_low = v[3] - v[1]) })) }))
cat('\n== 6장 축별 per1000 (인구≥1000) ==\n'); print(H, row.names = FALSE, digits = 4)
write.csv(H, file.path(out, 'hetero_per1000_by_method.csv'), row.names = FALSE)
writeLines(c('Point estimates only (no bootstrap). Same panel/formula/r=4 as main; CRAN/installed fect without patch.',
             'gsynth row should reproduce main ATT 288.41 (1.568%); ife = Liu-Wang-Xu counterfactual IFE estimator (all untreated obs).',
             'hetero_per1000_by_method.csv: group per1000 by 6 axes under each method; use to judge whether heterogeneity conclusions depend on estimator.'),
           file.path(out, 'README.txt'))
