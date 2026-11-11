# 6장 이질성 그림 — 처치 전 평균 대비 효과율(%) 판, Hainmueller et al. Fig. 2 스타일 (2026-11-04)
#  레이아웃은 fig_heterogeneity_weekly_hmstyle_cf_20261103.R(ggplot + patchwork)과 동일. 입력만 처치 전 평균 대비 값으로 교체.
#  재추정·부트스트랩 재집계 없음: scm_results/R2_r4_수준값_처치전대비_20261103/{weekly_level.csv, group_level_prepct.csv}만 읽음(수 초).
#  주별 값 = 주별 OD쌍당 추정효과(수준값) ÷ 집단 처치 전 53주 평균 이용량 × 100. 띠 = 주별 수준값 CI를 같은 처치 전 평균으로 나눈 값.
#  처치 후 평균선 = 46주 효과율(group_level_prepct.csv, window=full, stat=pct) → 표 6-1 값과 같음.
#  그림 6-5(초기·후기)도 같은 입력(window=early/late, stat=pct)으로 ggplot 판 생성.
#  실행(repo): Rscript code/02_heterogeneity/fig_heterogeneity_weekly_hmstyle_prepct_20261104.R   (needs ggplot2, patchwork)
suppressMessages({ library(ggplot2); library(patchwork) })
invisible(Sys.setlocale("LC_TIME", "C"))
## [repo copy] SRC_DIR = output of hetero_level_prepct_20261103.R (published copy: results/02_heterogeneity/R2_r4_prepct_level_20261103/);
##   FIG_DIR = where figures go; BODY_DIR = optional second copy with manuscript file names.
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")
src  <- Sys.getenv("SRC_DIR", file.path(REPO_ROOT, "results/02_heterogeneity/R2_r4_prepct_level_20261103"))
figd <- Sys.getenv("FIG_DIR", file.path(REPO_ROOT, "output/02_heterogeneity/figures_prepct_20261104")); dir.create(figd, recursive = TRUE, showWarnings = FALSE)
body <- Sys.getenv("BODY_DIR", figd)
W <- read.csv(file.path(src, "weekly_level.csv")); W$date <- as.Date(W$date)
G <- read.csv(file.path(src, "group_level_prepct.csv")); P <- G[G$stat == "pct", ]
full <- P[P$window == "full", ]
axes <- c("transfer", "wait", "access", "distance", "youth", "elderly", "region")
t0 <- as.Date("2024-01-29")

## 주별 % = 수준값 ÷ 집단 처치 전 평균(점추정) × 100
pm <- setNames(full$pre_mean, paste(full$axis, full$group, sep = "|"))
W <- W[W$axis %in% axes, ]; k <- pm[paste(W$axis, W$group, sep = "|")]; stopifnot(!anyNA(k))
D <- data.frame(axis = W$axis, group = W$group, date = W$date, est = 100 * W$est / k, lo = 100 * W$lo / k, hi = 100 * W$hi / k)
stopifnot(sum(D$date >= t0 & D$axis == "transfer" & D$group == "Q1") == 46)
write.csv(D, file.path(figd, "fig_hetero_weekly_prepct_all_en_data.csv"), row.names = FALSE)

## 그림 (fig_heterogeneity_weekly_hmstyle_cf_20261103.R과 동일 설정)
YL <- as.numeric(strsplit(Sys.getenv("YL", "-4,8"), ",")[[1]])
cols <- c(transfer = "#0072B2", wait = "#1B9E77", region = "#D55E00", access = "#6A3D9A", distance = "#8C6D31", youth = "#4D7F17", elderly = "#B5446E")
titles <- c(transfer = "Transfer burden", wait = "Waiting time per transfer", region = "Planning region", access = "Accessibility",
            distance = "Travel distance", youth = "Youth share", elderly = "Elderly (65+) share")
lab3 <- list(transfer = c("Low", "Middle", "High"), wait = c("Short", "Middle", "Long"), access = c("Low", "Middle", "High"),
             distance = c("Short", "Middle", "Long"), youth = c("Low", "Middle", "High"), elderly = c("Low", "Middle", "High"))
reg_ord <- c("Downtown", "Northeast", "Northwest", "Southwest", "Southeast")
relabel <- function(ax, g) if (ax == "region") factor(g, levels = reg_ord) else factor(lab3[[ax]][as.integer(sub("Q", "", g))], levels = lab3[[ax]])
block <- function(ax, show_y = TRUE) {
  d <- D[D$axis == ax, ]; d$group <- relabel(ax, d$group)
  m <- full[full$axis == ax, c("group", "est", "lo", "hi")]; m$group <- relabel(ax, m$group)
  ggplot(d, aes(date, est)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = cols[[ax]], alpha = 0.25) +
    geom_hline(yintercept = 0, colour = "black", linewidth = 0.4) +
    geom_vline(xintercept = t0, colour = "grey45", linetype = "42", linewidth = 0.6) +
    geom_line(colour = cols[[ax]], linewidth = 0.55) + geom_point(colour = cols[[ax]], size = 0.55) +
    geom_segment(data = m, aes(x = t0, xend = max(d$date), y = est, yend = est), colour = "grey15", linewidth = 0.7) +
    ## Hainmueller et al. (2026) Fig. 1 방식: 텍스트 상자에 "ATT = 점추정 [95% CI]" (처치 후 전체 기간 평균)
    geom_label(data = m, aes(x = as.Date("2023-01-10"), y = YL[2], label = sprintf("ATT = %.2f%% [%.2f, %.2f]", est, lo, hi)),
               hjust = 0, vjust = 1, size = 2.1, label.size = 0, fill = "white", colour = "grey15") +
    facet_wrap(~ group, nrow = 1) + coord_cartesian(ylim = YL) +
    scale_x_date(breaks = as.Date(c("2023-01-01", "2024-01-01")), date_labels = "%Y") +
    labs(title = paste("Grouping:", titles[[ax]]), x = NULL, y = if (show_y) "Estimated ATT, % of pretreatment mean" else NULL) +
    theme_minimal(base_size = 7) +
    theme(plot.title = element_text(face = "bold", size = 8, hjust = 0), strip.text = element_text(face = "bold", size = 7),
          panel.grid.minor = element_line(colour = "grey93"), panel.grid.major = element_line(colour = "grey88"),
          axis.title.y = element_text(face = "bold"), panel.spacing.y = unit(4, "pt"))
}
note <- paste0("Weekly effect = (observed - counterfactual) weekly ridership per OD pair / group pretreatment mean weekly ridership per OD x 100.\n",
               "The ATT reported in each text box is the average treatment effect on the treated over the full 46-week posttreatment period with its 95% CI (equals Table 6-1). Dashed line: 29 January 2024.\n",
               "Bands: pointwise normal 95% CIs of the weekly level effect (1,000 OD-pair bootstrap replications) divided by the same pretreatment mean; pretreatment values are in-sample fit residuals.\n",
               sprintf("y-axis limited to [%g, %g]%%; values outside are truncated. Pretreatment tertiles; origins with at least 1,000 residents.", YL[1], YL[2]))
cap <- function(g) g + plot_annotation(caption = note, theme = theme(plot.caption = element_text(size = 6, hjust = 0)))
row3 <- function(ax) block(ax) + plot_spacer() + plot_layout(widths = c(3, 2))
f_all <- file.path(figd, "fig_hetero_hm_all7_wide_prepct_en.png"); f_main <- file.path(figd, "fig_hetero_hm_main_wide_prepct_en.png")
ggsave(f_all, cap(row3("transfer") / row3("wait") / row3("access") / row3("distance") / row3("youth") / row3("elderly") / block("region")),
       width = 9, height = 14.5, dpi = 300, bg = "white")
ggsave(f_main, cap(row3("transfer") / row3("wait") / block("region")), width = 9, height = 6.4, dpi = 300, bg = "white")
file.copy(f_all, file.path(body, "그림6-x_hetero_weekly_prepct_all7_EN.png"), overwrite = TRUE)
file.copy(f_main, file.path(body, "그림6-x_hetero_weekly_prepct_main_EN.png"), overwrite = TRUE)

## 그림 6-5 — 초기(1–12주)·후기(13–46주) 효과율, ggplot 판
##  2026-11-04 결정: 패널별 자유 y축(절별로 잘라 따로 넣으므로 패널 간 공통 축 불필요), 점 옆에 추정치 표기, 권역 패널은 아랫줄 전체 폭, 축별 실제 집단 라벨.
E <- P[P$window %in% c("early", "late"), ]
E$glab <- unlist(Map(function(a, g) as.character(relabel(a, g)), E$axis, E$group))
E$window <- factor(E$window, levels = c("early", "late"), labels = c("Weeks 1-12", "Weeks 13-46"))
pr <- function(d, lv) {
  d$glab <- factor(d$glab, levels = lv)
  ggplot(d, aes(glab, est, shape = window)) +
    geom_hline(yintercept = 0, colour = "grey65", linetype = 2) +
    geom_pointrange(aes(ymin = lo, ymax = hi), position = position_dodge(.5), linewidth = .35, size = .4) +
    geom_text(aes(label = sprintf("%.2f", est)), position = position_dodge(.5), hjust = -0.35, size = 2.5, colour = "grey25") +
    scale_shape_manual(values = c(1, 16)) + scale_x_discrete(expand = expansion(add = c(0.4, 0.7))) +
    labs(x = NULL, y = NULL, shape = NULL) +
    theme_minimal(base_size = 10) + theme(strip.text = element_text(face = "bold"), axis.text.x = element_text(size = 8),
                                           panel.grid.minor = element_blank(), legend.position = "none")
}
six <- lapply(axes[axes != "region"], function(a) pr(E[E$axis == a, ], lab3[[a]]) + ggtitle(titles[[a]]) + theme(plot.title = element_text(size = 10, face = "bold", hjust = 0.5)))
reg <- pr(E[E$axis == "region", ], reg_ord) + ggtitle(titles[["region"]]) +
  theme(plot.title = element_text(size = 10, face = "bold", hjust = 0.5), legend.position = "bottom")
ylab65 <- "Estimated ATT, % of pretreatment mean"
six[[1]] <- six[[1]] + labs(y = ylab65); six[[4]] <- six[[4]] + labs(y = ylab65); reg <- reg + labs(y = ylab65)
p65 <- (wrap_plots(six, ncol = 3) / reg) + plot_layout(heights = c(2, 1)) +
  plot_annotation(caption = paste0("Points: ATT as % of the group's pretreatment mean weekly ridership per OD pair, for weeks 1-12 (open) and 13-46 (filled) after 29 January 2024; bars: 95% normal CIs from 1,000 OD-pair bootstrap replications\n",
                                   "(numerator and denominator re-computed in each). y-axis differs across panels. Pretreatment tertiles; origins with at least 1,000 residents."),
                  theme = theme(plot.caption = element_text(size = 7, hjust = 0)))
f65 <- file.path(figd, "fig6_5_prepct_early_late_en.png")
ggsave(f65, p65, width = 11, height = 9, dpi = 300, bg = "white")
file.copy(f65, file.path(body, "그림6-5_초기후기_처치전대비_효과율_EN.png"), overwrite = TRUE)
cat("saved", f_all, f_main, f65, "+ copies in 논문그림_본문_20261103\n")
