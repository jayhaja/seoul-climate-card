# 서울 전역 도로 교통량 gsynth (2026-11-03)
#  처치: 서울시 상시 교통량 조사 지점(TOPIS, 176개 중 관측률 90% 이상 149개), 통제: 도로 SCM 주사양 도너 53개(서울 밖)
#  결과변수: 평일(공휴일 제외) 06:00–09:59 시간당 교통량의 일별 중앙값 → 주간 중앙값 (도로 SCM과 같은 정의, road6to9_new_try 기준)
#  처치 시작 week_index 51(2024-01-29), 처치 후 51–96주(46주, 2024-12-16까지). 97주 이후(연말 연휴·2025)는 제외.
#  패널: scm_results/서울전역_도로_gsynth_20261103/panel_seoul176_donor53_6to9.csv (파이썬으로 구성; 0은 결측 처리)
#  사양: traffic ~ D, two-way, gsynth. r은 (1) CV(0–5) (2) 고정 1–4 민감도. 가중 없음. 결측은 fect 기본 처리.
#  출력: 전체 효과(대/시, 반사실 대비 %), 지점 유형별(A 도심, B 시계, C 한강교량, D 간선, F 도시고속도로) 재집계, 여의도 관련 지점 제외 결과, 지점별 격차
# 실행: cd ~/Documents/thesis_summary && Rscript _review/seoul_road_gsynth_20261103.R
#       부트스트랩: NB=200 CORES=2 Rscript _review/seoul_road_gsynth_20261103.R  (CV로 고른 r에만 적용)
suppressPackageStartupMessages({ library(fect); library(dplyr) })
base <- path.expand('~/Documents/thesis_summary'); out <- file.path(base, 'scm_results/서울전역_도로_gsynth_20261103')
NB <- as.integer(Sys.getenv('NB', '0')); CORES <- as.integer(Sys.getenv('CORES', '2'))
P <- read.csv(file.path(out, 'panel_seoul176_donor53_6to9.csv'), fileEncoding = 'UTF-8-BOM')
P <- P %>% filter(week_index <= 96) %>% mutate(D = as.integer(is_treat == 1 & week_index >= 51))
yeo <- c('C-06_0','C-06_1','C-07_0','C-07_1','C-08_0','C-08_1','D-29_0','D-41_0','D-41_1','F-10_0','F-10_1')   # 여의도 연결 지점
meta <- P %>% filter(is_treat == 1) %>% distinct(unit_id, site, type, roadName, path) %>% mutate(yeouido = site %in% yeo)
cat('처치', n_distinct(P$unit_id[P$is_treat == 1]), '| 통제', n_distinct(P$unit_id[P$is_treat == 0]), '| 주', n_distinct(P$week_index), '| 결측', round(mean(is.na(P$traffic)), 4), '\n')

CRIT <- Sys.getenv('CRIT', 'gmspe')   # 대중교통 주사양과 같은 rolling CV·1se·GMSPE (MSPE 비교: CRIT=mspe)
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
  res <- bind_rows(agg(site, '전체'), agg(filter(site, !yeouido), '여의도 지점 제외'),
                   bind_rows(lapply(split(site, site$type), function(s) agg(s, paste0('유형 ', s$type[1])))))
  res$model <- label; res$r <- f$r.cv; list(res = res, site = site)
}
R <- list(); S <- NULL
f_cv <- fitone(NA, cv = TRUE, se = NB > 0); o <- summ(f_cv, paste0('CV rolling 1se ', CRIT)); R[[1]] <- o$res; S <- o$site
cat('CV 선택 r =', f_cv$r.cv, '\n')
if (NB > 0) { e <- f_cv$est.avg; cat('부트스트랩 ATT(대/시):', round(e[1, 'ATT.avg'], 1), '[', round(e[1, 'CI.lower'], 1), ',', round(e[1, 'CI.upper'], 1), '] p =', signif(e[1, 'p.value'], 3), '\n') }
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
