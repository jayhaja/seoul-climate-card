# 서울 전역 도로 gsynth — 지점 유형별 따로 적합 + 유형별 진단 (2026-11-03)
#  유형: A 도심, B 시계, C 한강교량, D 간선, F 도시고속도로. 각 유형의 서울 지점만 처치로, 도너 53개는 공통 통제.
#  유형마다 (1) rolling CV(1se, GMSPE)로 r 선택 + GMSPE 최소 r 기록 (2) 그 r로 부트스트랩 ATT (3) 위약검정(처치 전 마지막 4주) (4) 처치 전 F·동등성 검정
#  결과변수 OUTCOME: level(대/시, 기본) 또는 index(지점별 처치 전 평균 = 100인 지수 → 효과가 처치 전 대비 %p로 읽힘)
#  R_MODE: cv(기본, 1se 적용 r) / min(GMSPE 최소 r) / 숫자(고정 r)
# 실행(직렬): cd ~/Documents/thesis_summary && Rscript _review/seoul_road_gsynth_bytype_20261103.R
#        지수:  OUTCOME=index Rscript _review/seoul_road_gsynth_bytype_20261103.R
#        GMSPE 최소 r: R_MODE=min Rscript ...      유형 일부만: TYPES=C,D Rscript ...
suppressPackageStartupMessages({ library(fect); library(dplyr) })
base <- path.expand('~/Documents/thesis_summary'); out <- file.path(base, 'scm_results/서울전역_도로_gsynth_20261103/bytype'); dir.create(out, showWarnings = FALSE, recursive = TRUE)
NB <- as.integer(Sys.getenv('NB', '200')); OUTCOME <- Sys.getenv('OUTCOME', 'level'); R_MODE <- Sys.getenv('R_MODE', 'cv')
TYPES <- strsplit(Sys.getenv('TYPES', 'A,B,C,D,F'), ',')[[1]]
PRE_F <- as.integer(Sys.getenv('PRE_F', '12'))   # F·동등성 검정 구간: 처치 직전 PRE_F주 (fect는 처치 지점 수 > 검정 주 수여야 F 계산)
P0 <- read.csv(file.path(dirname(out), 'panel_seoul176_donor53_6to9.csv'), fileEncoding = 'UTF-8-BOM') %>%
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
R <- do.call(rbind, lapply(TYPES, function(ty) { cat('\n--- 유형', ty, '---\n'); r <- one_type(ty); print(r, row.names = FALSE); r }))
num <- c('ATT', 'lo', 'hi', 'pct_vs_cf', 'placebo_ATT'); R[num] <- round(R[num], 2); R[c('p', 'placebo_p', 'pre_F_p', 'equiv_p')] <- signif(R[c('p', 'placebo_p', 'pre_F_p', 'equiv_p')], 3)
R$diag_pass <- R$placebo_p > .10 & (is.na(R$pre_F_p) | R$pre_F_p > .05)
names(R)[names(R) == 'pre_F_p'] <- paste0('preF', PRE_F, 'wk_p'); names(R)[names(R) == 'equiv_p'] <- paste0('equiv', PRE_F, 'wk_p')
cat('\n== 유형별 요약 ==\n'); print(R, row.names = FALSE)
write.csv(R, file.path(out, sprintf('bytype_%s_%s.csv', OUTCOME, R_MODE)), row.names = FALSE, fileEncoding = 'UTF-8')
cat('saved', out, '\n')
