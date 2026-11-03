# 6장 괄호 % 를 반사실 대비로 (2026-11-02). 재추정 없음, 저장 부트스트랩 재집계.
#  집단 % = 100 × Σ_OD Σ_처치후주 gap / Σ_OD Σ_처치후주 반사실,  반사실 = 관측 − gap (draw마다 gap이 다르므로 반사실도 draw별)
#  관측일 수는 분자·분모가 같은 처치 후 기간이라 상쇄 → 일평균/주간 구분 불필요. 5장 1.568%와 같은 정의.
#  출력: OUT_DIR (기본 output/02_heterogeneity/R2_r4_일평균_100명당_20261102)/{group_cf_pct.csv, contrast_cf_pct.csv}
## RESTRICTED DATA REQUIRED (restricted data required): 스마트카드 OD 패널에서 나온 적합·부트스트랩 결과와 OD/출발 단위 공변량.
## Required input files (place under RAW_DIR unless noted):
##   - R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_01.rds ... chunk_05.rds   (OD별 부트스트랩 draw 1,000개; 생성 스크립트는 저장소에 없음)
##   - R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv           (unit_id, pre_population; 생성 스크립트는 저장소에 없음)
##   - 규모통제_거리환승_20261011/OD_analysis_data.csv                          (OD별 transfer, distance_km)
##   - AI_uc_보정_20261101.csv, youth_region_20261101.csv, elderly_ratio_unit_20261102.csv, 환승시간_unit매칭_20261101.csv  (unit_id 매칭 공변량)
##   - point.rds: produced by code/01_citywide_gsynth/R2_r4_Xu권고진단_20261010.R
##       → REPO_ROOT/output/01_citywide_gsynth/R2_r4_Xu권고진단_20261010/<eng>/point.rds (override: XU_DIR)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted / non-redistributed inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "02_heterogeneity/R2_r4_일평균_100명당_20261102"))
XU_DIR    <- Sys.getenv("XU_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth", "R2_r4_Xu권고진단_20261010"))   # point.rds 위치
## Run (from repo root): Rscript code/02_heterogeneity/hetero_cf_pct_20261102.R
##   (수 분)
eng <- "PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155"
f <- readRDS(file.path(XU_DIR, eng, "point.rds"))$fit
chunks <- file.path(RAW_DIR, "R2_r4_환승5분위_사전CI_20261011", eng, sprintf("chunk_%02d.rds", 1:5))
out <- OUT_DIR; dir.create(out, recursive = TRUE, showWarnings = FALSE)
p  <- read.csv(file.path(RAW_DIR, "R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv"))
x  <- read.csv(file.path(RAW_DIR, "규모통제_거리환승_20261011/OD_analysis_data.csv"))
ai <- read.csv(file.path(RAW_DIR, "AI_uc_보정_20261101.csv")); yr <- read.csv(file.path(RAW_DIR, "youth_region_20261101.csv"))
el <- read.csv(file.path(RAW_DIR, "elderly_ratio_unit_20261102.csv")); wt <- read.csv(file.path(RAW_DIR, "환승시간_unit매칭_20261101.csv"))
m <- function(d, v) d[[v]][match(p$unit_id, d$unit_id)]
tert <- function(v) { ok <- is.finite(v); o <- rep(NA_integer_, length(v)); q <- quantile(v[ok], c(0, 1/3, 2/3, 1), type = 7); o[ok] <- cut(v[ok], q, include.lowest = TRUE, labels = FALSE); o }
lab3 <- c("Low", "Middle", "High"); reg <- c(도심권 = "Downtown", 동북권 = "Northeast", 서북권 = "Northwest", 서남권 = "Southwest", 동남권 = "Southeast")
axes <- list(transfer = list(title = "Transfer burden", g = lab3[tert(m(x, "transfer"))]),
  wait = list(title = "Transfer walk+wait time", g = c("Short", "Middle", "Long")[tert(m(wt, "minutes_per_trip"))]),
  access = list(title = "Accessibility", g = lab3[tert(m(ai, "AI_uc"))]),
  distance = list(title = "Trip distance", g = c("Short", "Middle", "Long")[tert(m(x, "distance_km"))]),
  youth = list(title = "Youth share", g = lab3[tert(m(yr, "youth_ratio"))]),
  elderly = list(title = "Elderly (65+) share", g = lab3[tert(m(el, "elderly_ratio"))]),
  region = list(title = "Planning region", g = unname(reg[m(yr, "region")])))
lo_hi <- list(transfer = c("Low", "High"), wait = c("Short", "Long"), access = c("Low", "High"), distance = c("Short", "Long"), youth = c("Low", "High"), elderly = c("Low", "High"))
keep <- p$pre_population >= 1000
tr <- which(colSums(f$D.dat) > 0); rel <- seq_len(nrow(f$D.dat)) - min(which(rowSums(f$D.dat) > 0)); post <- which(rel >= 0); stopifnot(length(post) == 46)
obs_sum <- setNames(colSums(f$Y.dat[post, tr, drop = FALSE]), f$id[tr])     # OD별 처치 후 관측 합

gw <- function(ids, gapmat, g) {
  ix <- match(ids, p$unit_id); stopifnot(!anyNA(ix)); labs <- sort(unique(na.omit(g))); v <- c()
  ob <- obs_sum[as.character(ids)]; stopifnot(!anyNA(ob))
  for (l in labs) { k <- g[ix] == l & keep[ix]; k[is.na(k)] <- FALSE
    gs <- sum(gapmat[post, k, drop = FALSE]); v[l] <- 100 * gs / (sum(ob[k]) - gs) }
  v
}
theta <- lapply(axes, function(a) gw(f$id[tr], f$Y.dat[, tr] - f$Y.ct[, tr], a$g))
sims <- lapply(theta, function(t) matrix(NA_real_, length(t), 1000, dimnames = list(names(t), NULL)))
for (j in 1:5) { a <- readRDS(chunks[j]); stopifnot(identical(a$all_week_index, f$rawtime))
  for (i in 1:200) { d <- a$od_draws[[i]]; for (nm in names(axes)) sims[[nm]][, (j - 1) * 200 + i] <- gw(d$unit_id, d$gap_all_weeks, axes[[nm]]$g) }
  rm(a); gc(FALSE); cat("chunk", j, "/5\n") }
ci <- function(t, s) { se <- sd(s); c(est = unname(t), lo = unname(t) - 1.96 * se, hi = unname(t) + 1.96 * se, p = 2 * pnorm(-abs(unname(t) / se))) }
G <- do.call(rbind, lapply(names(axes), function(nm) do.call(rbind, lapply(names(theta[[nm]]), function(l)
  data.frame(axis = axes[[nm]]$title, group = l, t(ci(theta[[nm]][l], sims[[nm]][l, ])))))))
C <- do.call(rbind, lapply(names(lo_hi), function(nm) { L <- lo_hi[[nm]][1]; H <- lo_hi[[nm]][2]
  data.frame(axis = axes[[nm]]$title, contrast = paste(H, "-", L), t(ci(theta[[nm]][H] - theta[[nm]][L], sims[[nm]][H, ] - sims[[nm]][L, ]))) }))
G[c("est", "lo", "hi")] <- round(G[c("est", "lo", "hi")], 2); C[c("est", "lo", "hi")] <- round(C[c("est", "lo", "hi")], 2); G$p <- signif(G$p, 3); C$p <- signif(C$p, 3)
write.csv(G, file.path(out, "group_cf_pct.csv"), row.names = FALSE); write.csv(C, file.path(out, "contrast_cf_pct.csv"), row.names = FALSE)
print(G, row.names = FALSE); print(C, row.names = FALSE)
