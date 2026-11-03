# 서울 전역 도로 gsynth 진단 (2026-11-03): 위약검정 + 처치 전 추세 + 동등성 검정
#  패널·사양은 seoul_road_gsynth_20261103.R 과 동일(149개 서울 지점 vs 도너 53개, 06–09시 주간 중앙값, 처치 51주, 51–96주).
#  (1) 위약검정: 처치 전 마지막 4주(상대 주 −3~0)를 가짜 처치 기간으로 두고 fect placeboTest → 가짜 기간 ATT와 p
#  (2) 처치 전 추세: 본 적합의 상대 주별 ATT(처치 전 구간)와 F 검정, 동등성 검정(fect 내장)
#  (3) 그림: 상대 주별 격차(gap), 동등성(equiv) 그림 png
#  r은 R_FIX(기본 0 = CV 선택값). 부트스트랩 NB(기본 200), 직렬 기본(CORES=1).
# 실행: cd ~/Documents/thesis_summary && Rscript _review/seoul_road_gsynth_diag_20261103.R
#       r=4 비교:  R_FIX=4 Rscript _review/seoul_road_gsynth_diag_20261103.R
suppressPackageStartupMessages({ library(fect); library(dplyr) })
base <- path.expand('~/Documents/thesis_summary'); out <- file.path(base, 'scm_results/서울전역_도로_gsynth_20261103')
R_FIX <- as.integer(Sys.getenv('R_FIX', '0')); NB <- as.integer(Sys.getenv('NB', '200')); CORES <- as.integer(Sys.getenv('CORES', '1'))
P <- read.csv(file.path(out, 'panel_seoul176_donor53_6to9.csv'), fileEncoding = 'UTF-8-BOM') %>%
  filter(week_index <= 96) %>% mutate(D = as.integer(is_treat == 1 & week_index >= 51))
tag <- paste0('r', R_FIX); cat('r =', R_FIX, '| nboots =', NB, '| cores =', CORES, '\n')
par_on <- CORES > 1

## (1) 위약검정
set.seed(20260731L)
fp <- fect(traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way', CV = FALSE, r = R_FIX,
           se = TRUE, nboots = NB, parallel = par_on, cores = CORES, vartype = 'bootstrap',
           placeboTest = TRUE, placebo.period = c(-3, 0))
pl <- fp$est.placebo
cat('\n== 위약검정 (처치 전 마지막 4주를 가짜 처치) ==\n'); print(pl)
write.csv(as.data.frame(pl), file.path(out, sprintf('diag_placebo_%s.csv', tag)))

## (2) 본 적합 + 처치 전 추세·동등성
set.seed(20260731L)
f <- fect(traffic ~ D, data = P, index = c('unit_id', 'week_index'), method = 'gsynth', force = 'two-way', CV = FALSE, r = R_FIX,
          se = TRUE, nboots = NB, parallel = par_on, cores = CORES, vartype = 'bootstrap')
cat('\n== 전체 ATT (대/시, 부트스트랩) ==\n'); print(f$est.avg)
att <- as.data.frame(f$est.att); att$rel_week <- as.integer(rownames(att))
write.csv(att, file.path(out, sprintf('diag_event_att_%s.csv', tag)), row.names = FALSE)
pre <- att[att$rel_week <= 0, ]
cat(sprintf('\n처치 전 상대 주별 ATT: 평균 %.1f, |ATT| 최대 %.1f, 95%% CI가 0을 벗어난 주 %d/%d\n',
            mean(pre$ATT), max(abs(pre$ATT)), sum(pre$CI.lower > 0 | pre$CI.upper < 0, na.rm = TRUE), nrow(pre)))
if (!is.null(f$test.out)) { cat('\n== 처치 전 추세 검정 (fect test.out) ==\n'); print(f$test.out[intersect(c('f.stat', 'f.p', 'f.equiv.p', 'tost.equiv.p'), names(f$test.out))]) }
saveRDS(list(placebo = fp, main = f), file.path(out, sprintf('diag_fits_%s.rds', tag)))

## (3) 그림
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
