# Chapter 6 weekly heterogeneity figure — increase relative to the counterfactual (%), styled after Hainmueller et al. (2026) Fig. 2 (2026-11-03)
#  Same layout as the earlier fig_heterogeneity_weekly_hmstyle_daily_20261102.R (weekly line per group + 95% CI band + post-treatment mean line);
#  only the y-axis changes from the population-scaled daily indicator (pp) to the increase vs counterfactual (%), and a waiting-time axis is added (7 characteristics).
#  Weekly value = 100 × Σ(observed − counterfactual) / Σcounterfactual over the group's origins in that week. Pre-treatment weeks are in-sample fit residuals.
#  Post-treatment mean line = ratio of sums over all 46 weeks (group_cf_pct.csv, window = full) → equals Table 6-1.
#  Groups and sample: identical to hetero_cf_tertiles_timepath_20261103.R (pre-period tertiles, origins with ≥ 1,000 residents, fixed tertile boundaries).
#  CI: re-aggregation of the existing 1,000 OD-pair bootstrap draws (5 chunks), normal approximation. No model refit.
## INPUT DATA (not yet in the repository): files derived from the smart-card OD panel, listed below.
## Required input files:
##   - point.rds: produced by code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R
##       → XU_DIR/<eng>/point.rds (default output/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010)
##   - RAW_DIR/R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_01.rds ... chunk_05.rds   [folder = "r4 transfer quintiles, pre-computed CI"; producing script not in this repo]
##   - TT_DIR/membership.csv, TT_DIR/group_cf_pct.csv: produced by code/02_heterogeneity/hetero_cf_tertiles_timepath_20261103.R
##       (default output/02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103)
##   - RAW_DIR/fig_hetero_weekly_transfer_en_data.csv: data file of the earlier weekly figure, used only for the 99 week dates
##       (written by fig_heterogeneity_weekly_hmstyle_daily_20261102.R, not in this repo)
## Run (from repo root): Rscript code/02_heterogeneity/fig_heterogeneity_weekly_hmstyle_cf_20261103.R   (a few minutes: reads the bootstrap chunks)
suppressMessages({ library(ggplot2); library(patchwork) })
invisible(Sys.setlocale("LC_TIME", "C"))
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "02_heterogeneity", "fig_heterogeneity_weekly_cf_20261103"))
XU_DIR    <- Sys.getenv("XU_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth", "R2_r4_xu_diagnostics_20261010"))   # location of point.rds
TT_DIR    <- Sys.getenv("TT_DIR", file.path(REPO_ROOT, "output", "02_heterogeneity", "R2_r4_cf_tertiles_timepath_20261103"))
figd <- OUT_DIR; dir.create(figd, recursive = TRUE, showWarnings = FALSE)
eng <- "PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155"
f <- readRDS(file.path(XU_DIR, eng, "point.rds"))$fit
chunks <- file.path(RAW_DIR, "R2_r4_환승5분위_사전CI_20261011", eng, sprintf("chunk_%02d.rds", 1:5))
src <- TT_DIR
mem <- read.csv(file.path(src, "membership.csv")); full <- read.csv(file.path(src, "group_cf_pct.csv")); full <- full[full$window == "full", ]
keep_ids <- mem$unit_id[mem$pre_population >= 1000]
axes <- c("transfer", "wait", "access", "distance", "youth", "elderly", "region")
tr <- which(colSums(f$D.dat) > 0); ids_tr <- f$id[tr]; nW <- nrow(f$Y.dat)
Yobs <- f$Y.dat[, tr, drop = FALSE]; colnames(Yobs) <- as.character(ids_tr)
## Week dates: the same 99 weeks as the earlier weekly figure data (53 pre, 46 post), in rawtime order
dd <- read.csv(file.path(RAW_DIR, "fig_hetero_weekly_transfer_en_data.csv")); wk <- sort(unique(as.Date(dd$date)))
stopifnot(length(wk) == nW, length(f$rawtime) == nW); t0 <- as.Date("2024-01-29"); stopifnot(sum(wk >= t0) == 46)

weekly <- function(ids, gap) {                   # weekly % vs counterfactual by group (matrix: week × group label "axis|group")
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
## Check: the post-treatment 46-week ratio of sums (not the mean of weekly values) must equal group_cf_pct.csv, so that value is used as the mean line
cat("Range of weekly values (post-treatment):", paste(round(range(D$est[D$date >= t0], na.rm = TRUE), 2), collapse = " ~ "), "%\n")

## Figures
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
cat("saved", file.path(figd, "fig_hetero_hm_{all7,main}_wide_cf_en.png"), "and fig_hetero_weekly_cf_all_en_data.csv\n")
