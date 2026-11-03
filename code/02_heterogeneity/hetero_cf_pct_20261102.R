# Chapter 6 bracketed percentages, re-expressed relative to the counterfactual (2026-11-02). No refitting; re-aggregates saved bootstrap draws.
#  Group % = 100 × Σ_OD Σ_post-weeks gap / Σ_OD Σ_post-weeks counterfactual, counterfactual = observed − gap (gap varies by draw, so the counterfactual is per draw)
#  The number of observed days cancels (numerator and denominator cover the same post period) → no daily/weekly distinction needed. Same definition as the 1.568% in Chapter 5.
#  Output: OUT_DIR (default output/02_heterogeneity/R2_r4_cf_pct_20261102)/{group_cf_pct.csv, contrast_cf_pct.csv}
## RESTRICTED DATA REQUIRED: model fits and bootstrap draws derived from the smart-card OD panel, plus OD/origin-level covariates.
## Required input files (place under RAW_DIR unless noted):
##   - R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_01.rds ... chunk_05.rds   [folder = "r4 transfer quintiles, pre-computed CI"]
##       (1,000 bootstrap draws per OD pair; the script that produced them is not in this repo)
##   - R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv           [folder = "r4 additional use per population"]
##       (unit_id, pre_population; the script that produced it is not in this repo)
##   - 규모통제_거리환승_20261011/OD_analysis_data.csv                          [folder = "size-controlled distance/transfer"]
##       (transfer, distance_km per OD pair)
##   - AI_uc_보정_20261101.csv, youth_region_20261101.csv, elderly_ratio_unit_20261102.csv, 환승시간_unit매칭_20261101.csv
##       (covariates matched on unit_id; 보정 = "adjusted", 환승시간_unit매칭 = "transfer time, unit-matched")
##   - point.rds: produced by code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R
##       → REPO_ROOT/output/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010/<eng>/point.rds (override: XU_DIR)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted / non-redistributed inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "02_heterogeneity/R2_r4_cf_pct_20261102"))
XU_DIR    <- Sys.getenv("XU_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth", "R2_r4_xu_diagnostics_20261010"))   # location of point.rds
## Run (from repo root): Rscript code/02_heterogeneity/hetero_cf_pct_20261102.R
##   (takes a few minutes)
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
# reg maps Korean planning-region values in the input (도심권 = Downtown, 동북권 = Northeast, 서북권 = Northwest, 서남권 = Southwest, 동남권 = Southeast)
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
obs_sum <- setNames(colSums(f$Y.dat[post, tr, drop = FALSE]), f$id[tr])     # post-treatment observed total per OD pair

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
