# 6장 이질성 주별 그림 — 반사실 대비 증가율(%) 판, Hainmueller et al. (2026) Fig. 2 스타일 (2026-11-03)
#  기존 fig_heterogeneity_weekly_hmstyle_daily_20261102.R 과 같은 형식(집단별 주별 선 + 95% CI 띠 + 처치 후 평균 가로선),
#  세로축만 인구 대비 일평균 지표(%p) → 반사실 대비 증가율(%)로 바꾸고 대기시간 축을 추가(7개 특성).
#  주별 값 = 100 × Σ(관측 − 반사실) / Σ반사실 (그 주, 그 집단의 출발지 합). 처치 전 주는 적합 잔차(in-sample).
#  처치 후 평균선 = 46주 전체의 비율의 합(group_cf_pct.csv, window = full) → 표 6-1 값과 같음.
#  집단·표본: hetero_cf_tertiles_timepath_20261103.R 과 동일(사전 3분위, 인구 1,000명 이상 출발지, 3분위 경계 고정).
#  CI: 기존 1,000회 OD 쌍 부트스트랩(5개 chunk) 재집계, 정규근사. 모형 재추정 없음.
#  실행: cd ~/Documents/thesis_summary && Rscript fig_heterogeneity_weekly_hmstyle_cf_20261103.R   (chunk 읽기 때문에 수 분)
suppressMessages({ library(ggplot2); library(patchwork) })
invisible(Sys.setlocale("LC_TIME", "C"))
ts  <- path.expand("~/Documents/thesis_summary"); figd <- file.path(ts, "figures")
eng <- "PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155"
f <- readRDS(file.path("/Users/maeg/Thesis/0614/public.transportation/0702/scm_results/R2_r4_Xu권고진단_20261010", eng, "point.rds"))$fit
chunks <- file.path(ts, "scm_results/R2_r4_환승5분위_사전CI_20261011", eng, sprintf("chunk_%02d.rds", 1:5))
src <- file.path(ts, "scm_results/R2_r4_반사실_3분위_시간경로_20261103")
mem <- read.csv(file.path(src, "membership.csv")); full <- read.csv(file.path(src, "group_cf_pct.csv")); full <- full[full$window == "full", ]
keep_ids <- mem$unit_id[mem$pre_population >= 1000]
axes <- c("transfer", "wait", "access", "distance", "youth", "elderly", "region")
tr <- which(colSums(f$D.dat) > 0); ids_tr <- f$id[tr]; nW <- nrow(f$Y.dat)
Yobs <- f$Y.dat[, tr, drop = FALSE]; colnames(Yobs) <- as.character(ids_tr)
## 주 날짜: 기존 주별 그림 자료와 같은 99주(처치 전 53, 후 46), rawtime 순서
dd <- read.csv(file.path(figd, "fig_hetero_weekly_transfer_en_data.csv")); wk <- sort(unique(as.Date(dd$date)))
stopifnot(length(wk) == nW, length(f$rawtime) == nW); t0 <- as.Date("2024-01-29"); stopifnot(sum(wk >= t0) == 46)

weekly <- function(ids, gap) {                   # 집단별 주별 반사실 대비 % (행렬: 주 × 집단 라벨 "axis|group")
  ob <- Yobs[, as.character(ids), drop = FALSE]; stopifnot(!anyNA(ob), ncol(gap) == length(ids))
  out <- list()
  for (ax in axes) { g <- mem[[paste0(ax, "_group")]][match(ids, mem$unit_id)]; k0 <- ids %in% keep_ids
    for (l in sort(unique(na.omit(g)))) { k <- !is.na(g) & g == l & k0
      gs <- rowSums(gap[, k, drop = FALSE]); cf <- rowSums(ob[, k, drop = FALSE]) - gs
      out[[paste(ax, l, sep = "|")]] <- ifelse(cf > 0, 100 * gs / cf, NA_real_) } }
  do.call(cbind, out)
}
theta <- weekly(ids_tr, f$Y.dat[, tr] - f$Y.ct[, tr])
sims <- array(NA_real_, c(nW, ncol(theta), 1000))
for (j in 1:5) { a <- readRDS(chunks[j]); stopifnot(identical(a$all_week_index, f$rawtime), length(a$od_draws) == 200)
  for (i in 1:200) { d <- a$od_draws[[i]]; sims[, , (j - 1) * 200 + i] <- weekly(d$unit_id, d$gap_all_weeks) }
  rm(a); gc(FALSE); cat("chunk", j, "/5\n") }
se <- apply(sims, c(1, 2), sd, na.rm = TRUE)
D <- do.call(rbind, lapply(seq_len(ncol(theta)), function(c) { z <- strsplit(colnames(theta)[c], "|", fixed = TRUE)[[1]]
  data.frame(axis = z[1], group = z[2], date = wk, relative = seq_len(nW) - (nW - 46) - 1, est = theta[, c], lo = theta[, c] - 1.96 * se[, c], hi = theta[, c] + 1.96 * se[, c]) }))
write.csv(D, file.path(figd, "fig_hetero_weekly_cf_all_en_data.csv"), row.names = FALSE)
## 확인: 처치 후 46주 비율의 합(주별 값의 평균이 아님)은 group_cf_pct.csv와 같아야 하므로 그 값을 평균선으로 사용
cat("주별 값 범위(처치 후):", paste(round(range(D$est[D$date >= t0], na.rm = TRUE), 2), collapse = " ~ "), "%\n")

## 그림
YL <- as.numeric(strsplit(Sys.getenv("YL", "-4,8"), ",")[[1]])
cols <- c(transfer = "#0072B2", wait = "#1B9E77", region = "#D55E00", access = "#6A3D9A", distance = "#8C6D31", youth = "#4D7F17", elderly = "#B5446E")
titles <- c(transfer = "Transfer burden", wait = "Waiting time per transfer", region = "Planning region", access = "Accessibility",
            distance = "Trip distance", youth = "Youth share", elderly = "Elderly (65+) share")
lab3 <- list(transfer = c("Low", "Middle", "High"), wait = c("Short", "Middle", "Long"), access = c("Low", "Middle", "High"),
             distance = c("Short", "Middle", "Long"), youth = c("Low", "Middle", "High"), elderly = c("Low", "Middle", "High"))
reg_ord <- c("Downtown", "Northeast", "Northwest", "Southwest", "Southeast")
relabel <- function(ax, g) if (ax == "region") factor(g, levels = reg_ord) else factor(lab3[[ax]][as.integer(sub("Q", "", g))], levels = lab3[[ax]])
block <- function(ax, show_y = TRUE) {
  d <- D[D$axis == ax, ]; d$group <- relabel(ax, d$group)
  pm <- full[full$axis == ax, c("group", "est")]; pm$group <- relabel(ax, pm$group)
  ggplot(d, aes(date, est)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = cols[[ax]], alpha = 0.25) +
    geom_hline(yintercept = 0, colour = "black", linewidth = 0.4) +
    geom_vline(xintercept = t0, colour = "grey45", linetype = "42", linewidth = 0.6) +
    geom_line(colour = cols[[ax]], linewidth = 0.55) + geom_point(colour = cols[[ax]], size = 0.55) +
    geom_segment(data = pm, aes(x = t0, xend = max(d$date), y = est, yend = est), colour = "grey15", linewidth = 0.7) +
    geom_label(data = pm, aes(x = as.Date("2023-01-10"), y = YL[2], label = sprintf("Post mean %.2f%%", est)),
               hjust = 0, vjust = 1, size = 2.3, label.size = 0, fill = "white", colour = "grey15") +
    facet_wrap(~ group, nrow = 1) + coord_cartesian(ylim = YL) +
    scale_x_date(breaks = as.Date(c("2023-01-01", "2024-01-01")), date_labels = "%Y") +
    labs(title = paste("Grouping:", titles[[ax]]), x = NULL, y = if (show_y) "Increase vs counterfactual (%)" else NULL) +
    theme_minimal(base_size = 7) +
    theme(plot.title = element_text(face = "bold", size = 8, hjust = 0), strip.text = element_text(face = "bold", size = 7),
          panel.grid.minor = element_line(colour = "grey93"), panel.grid.major = element_line(colour = "grey88"),
          axis.title.y = element_text(face = "bold"), panel.spacing.y = unit(4, "pt"))
}
note <- paste0("Estimated effect = 100 x (observed - counterfactual) / counterfactual, summed over origins in each group (ratio of sums).\n",
               "Solid horizontal line = post-treatment effect over all 46 weeks (ratio of sums; equals Table 6-1). Dashed line: 29 January 2024.\n",
               "Bands: pointwise normal 95% CIs (1,000 OD-pair bootstrap replications); pretreatment values are in-sample fit residuals.\n",
               sprintf("y-axis limited to [%g, %g]; values outside are truncated. Pretreatment tertiles; origins with at least 1,000 residents.", YL[1], YL[2]))
cap <- function(g) g + plot_annotation(caption = note, theme = theme(plot.caption = element_text(size = 6, hjust = 0)))
row3 <- function(ax) block(ax) + plot_spacer() + plot_layout(widths = c(3, 2))
ggsave(file.path(figd, "fig_hetero_hm_all7_wide_cf_en.png"),
       cap(row3("transfer") / row3("wait") / row3("access") / row3("distance") / row3("youth") / row3("elderly") / block("region")),
       width = 9, height = 14.5, dpi = 300, bg = "white")
ggsave(file.path(figd, "fig_hetero_hm_main_wide_cf_en.png"), cap(row3("transfer") / row3("wait") / block("region")), width = 9, height = 6.4, dpi = 300, bg = "white")
cat("saved figures/fig_hetero_hm_{all7,main}_wide_cf_en.png, fig_hetero_weekly_cf_all_en_data.csv\n")
