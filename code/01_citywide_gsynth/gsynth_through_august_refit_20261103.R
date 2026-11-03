# 서울 전역 gsynth: 패널을 2024년 8월(처치 후 30주)까지 잘라 다시 추정 (2026-11-03)
#  기존 "8월까지 1.444%"는 46주 전체로 적합한 모형의 격차를 30주만 집계한 값(재추정 없음).
#  여기서는 9~12월 자료를 패널에서 빼고 모형 자체를 다시 적합 → 요인·적재값이 달라질 수 있음.
#  사양은 주사양과 동일: users ~ D + log_pop, two-way, r = 4 고정(CV 없음), 가중 없음, 설치된 fect(method = "gsynth").
#    (ife_vs_gsynth_point_20261102.R 주석: 비가중·CV 없음에서는 패치 엔진과 같은 결과 → 먼저 전체 46주로 288.41 / 1.568% 재현 확인)
#  선택: CV=1 이면 롤링 CV 대신 fect 기본 CV로 r 재선택(참고용). NB>0 이면 OD 블록 부트스트랩(fect 내장, 정규근사 CI).
# Run (from repo root): Rscript code/01_citywide_gsynth/gsynth_through_august_refit_20261103.R
#        부트스트랩까지: NB=200 CORES=2 Rscript code/01_citywide_gsynth/gsynth_through_august_refit_20261103.R
## RESTRICTED DATA REQUIRED (restricted data required): this script needs files that are not
## distributed (smart-card OD data, Data Safety Center export-restricted).
## Required input files (place under RAW_DIR):
##   - panels/d_w30_no과천.rds                 (OD x week panel; builder script not in this repo)
##   - od_with_pop_sum_without_holiday.csv     (OD-level weekly users + population, holiday weeks removed)
suppressPackageStartupMessages({ library(fect); library(dplyr); library(readr) })
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth/gsynth_8월절단_재추정_20261103"))
root <- path.expand(RAW_DIR)
out <- path.expand(OUT_DIR); dir.create(out, recursive = TRUE, showWarnings = FALSE)
NB <- as.integer(Sys.getenv('NB', '0')); CORES <- as.integer(Sys.getenv('CORES', '2')); DO_CV <- Sys.getenv('CV', '0') == '1'

## 패널 (ife_vs_gsynth_point_20261102.R 와 동일 구성)
d <- readRDS(file.path(root, 'panels/d_w30_no과천.rds')); tr <- unique(d$unit_id[d$D == 1])
needed <- c('unit_id', 'week_index', 'week', 'ym', 'origin_region', 'origin_sigungu', 'origin_dong', 'pop_total', '이용자수_주총합')
raw <- read_csv(file.path(root, 'od_with_pop_sum_without_holiday.csv'), col_select = all_of(needed), show_col_types = FALSE)
sg <- raw %>% distinct(origin_region, origin_sigungu, origin_dong, ym, pop_total) %>% group_by(origin_region, origin_sigungu, ym) %>%
  summarise(pop_total_sg = sum(pop_total, na.rm = TRUE), .groups = 'drop')
key <- function(x) paste(x$unit_id, x$week_index, sep = ':'); raw <- raw[key(raw) %in% key(d), ]
raw <- raw %>% left_join(sg, by = c('origin_region', 'origin_sigungu', 'ym')) %>% mutate(pop_total = if_else(pop_total < 100, pop_total_sg, pop_total))
raw <- raw[match(key(d), key(raw)), ]; stopifnot(identical(key(d), key(raw)), length(tr) == 409)
d$users <- raw$이용자수_주총합; d$log_pop <- log(raw$pop_total); d$week <- as.Date(raw$week)
t0 <- min(d$week_index[d$D == 1]); post_all <- sort(unique(d$week_index[d$week_index >= t0])); stopifnot(length(post_all) == 46)
cut_wi <- post_all[30]; cat('처치 시작', format(min(d$week[d$week_index == t0])), '| 절단 마지막 주', format(unique(d$week[d$week_index == cut_wi])), '\n')

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
    wk_cf <- sum(cf) / sum(post)   # 주당 반사실 합계
    res$pct_lo <- 100 * res$ATT_count_lo * ncol(g) / wk_cf; res$pct_hi <- 100 * res$ATT_count_hi * ncol(g) / wk_cf }
  print(res, row.names = FALSE); res
}
R <- rbind(fit(d, 'full 46wk (재현 확인: 288.41 / 1.568%)'),
           fit(d[d$week_index <= cut_wi, ], 'through Aug: refit on truncated panel'))
## 비교: 전체 모형의 30주 집계 (원고 값)
R <- rbind(R[, c('model', 'r', 'post_weeks', 'ATT_count', 'weekly_total_gap', 'effect_pct')],
           data.frame(model = 'through Aug: full-fit window (원고)', r = 4, post_weeks = 30, ATT_count = 267.944, weekly_total_gap = 109589.2, effect_pct = 1.444))
print(R, row.names = FALSE); write.csv(R, file.path(out, 'through_august_refit.csv'), row.names = FALSE)
writeLines(c('Refit of main gsynth spec (users ~ D + log_pop, r=4 fixed, unweighted, installed fect) on panel truncated at the 30th post-treatment week (end of Aug 2024).',
             'Compare with the full-46-week fit aggregated over the same 30 weeks (manuscript 1.444%). Bootstrap CI only if NB>0 (fect internal, pct CI approximated with fixed counterfactual denominator).'),
           file.path(out, 'README.txt'))
