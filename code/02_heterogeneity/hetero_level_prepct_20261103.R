# Chapter 6 heterogeneity — main metric: additional weekly ridership per OD pair (person-days, level) + % of the pretreatment mean (Hainmueller et al. 2026 approach) (2026-11-03)
#  Level effect = Σ(observed − counterfactual) / (weeks × ODs in the group)   → same unit as the gsynth ATT (weekly person-days per OD pair)
#  % of pretreatment mean = 100 × level effect / group mean weekly ridership per OD pair (observed, 53 pretreatment weeks)
#  Groups and sample: identical to hetero_cf_tertiles_timepath_20261103.R (membership.csv: pretreatment tertiles, origins with ≥ 1,000 residents, fixed boundaries)
#  Windows: full (46 weeks), early (first 12), late (remaining 34), 12-week blocks. Contrasts = Q3 − Q1 (not for region), late − early.
#  CI: re-aggregation of the existing 1,000 OD-pair bootstrap draws (5 chunks), normal approximation. ODs duplicated in a draw count in numerator and denominator. No model refit.
#  Output: OUT_DIR (default output/02_heterogeneity/R2_r4_prepct_level_20261103/): group_level_prepct.csv, contrast_level_prepct.csv, overall.csv, weekly_level.csv, README.txt
#  Figures: OUT_DIR/fig_hetero_hm_{main,all7}_wide_level_en.png (weekly level effect per OD pair + post-treatment mean line; labels give % of pretreatment mean)
#  Run (from repo root): Rscript code/02_heterogeneity/hetero_level_prepct_20261103.R   (a few minutes: reads the bootstrap chunks)
suppressMessages({ library(ggplot2); library(patchwork) })
invisible(Sys.setlocale("LC_TIME", "C"))
## [repo copy] Paths follow the other scripts in code/02_heterogeneity: run from the repo root.
##   RAW_DIR  (inputs not yet in the repository): R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_*.rds [folder = "r4 transfer quintiles, pre-computed CI"], fig_hetero_weekly_transfer_en_data.csv (week dates)
##   XU_DIR   point.rds from code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R
##   TT_DIR   membership.csv written by hetero_cf_tertiles_timepath_20261103.R
##   OUT_DIR  outputs (published copy: results/02_heterogeneity/R2_r4_prepct_level_20261103/)
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))
eng <- "PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155"
XU_DIR    <- Sys.getenv("XU_DIR", file.path(REPO_ROOT, "output/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010", eng))
src       <- Sys.getenv("TT_DIR", file.path(REPO_ROOT, "output/02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103"))
out       <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output/02_heterogeneity/R2_r4_prepct_level_20261103")); dir.create(out, recursive = TRUE, showWarnings = FALSE)
figd      <- Sys.getenv("FIG_DIR", out)
f <- readRDS(file.path(XU_DIR, "point.rds"))$fit
chunks <- file.path(RAW_DIR, "R2_r4_환승5분위_사전CI_20261011", eng, sprintf("chunk_%02d.rds", 1:5))
mem <- read.csv(file.path(src, "membership.csv")); keep_ids <- mem$unit_id[mem$pre_population >= 1000]
axes <- c("transfer", "wait", "access", "distance", "youth", "elderly", "region")
tr <- which(colSums(f$D.dat) > 0); ids_tr <- f$id[tr]; nW <- nrow(f$Y.dat)
Yobs <- f$Y.dat[, tr, drop = FALSE]; colnames(Yobs) <- as.character(ids_tr)
post <- which(seq_len(nW) >= min(which(rowSums(f$D.dat) > 0))); pre <- setdiff(seq_len(nW), post); stopifnot(length(post) == 46, length(pre) == 53)
win <- list(full = post, early = post[1:12], late = post[13:46], w01_12 = post[1:12], w13_24 = post[13:24], w25_36 = post[25:36], w37_46 = post[37:46])
dd <- read.csv(file.path(RAW_DIR, "fig_hetero_weekly_transfer_en_data.csv")); wk <- sort(unique(as.Date(dd$date))); stopifnot(length(wk) == nW)
t0 <- wk[min(post)]

## Group labels ("all" = every treated OD whose origin has ≥ 1,000 residents)
grp_of <- function(ids) { G <- list(all = rep("all", length(ids)))
  for (ax in axes) G[[ax]] <- mem[[paste0(ax, "_group")]][match(ids, mem$unit_id)]; G }
stat <- function(ids, gap) {     # returns: vector named "axis|group|window|{lvl,pct}" + matrix of weekly level effects
  ob <- Yobs[, as.character(ids), drop = FALSE]; stopifnot(!anyNA(ob), ncol(gap) == length(ids))
  k0 <- ids %in% keep_ids; G <- grp_of(ids); v <- c(); wkm <- list()
  for (ax in names(G)) for (l in sort(unique(na.omit(G[[ax]])))) { k <- !is.na(G[[ax]]) & G[[ax]] == l & k0; n <- sum(k)
    pm <- sum(ob[pre, k]) / (length(pre) * n)                                  # pretreatment mean weekly ridership per OD pair
    for (w in names(win)) { lvl <- sum(gap[win[[w]], k]) / (length(win[[w]]) * n)
      v[paste(ax, l, w, "lvl", sep = "|")] <- lvl; v[paste(ax, l, w, "pct", sep = "|")] <- 100 * lvl / pm }
    v[paste(ax, l, "pre", "mean", sep = "|")] <- pm; v[paste(ax, l, "n", "od", sep = "|")] <- n
    wkm[[paste(ax, l, sep = "|")]] <- rowSums(gap[, k, drop = FALSE]) / n }
  list(v = v, wk = do.call(cbind, wkm))
}
P <- stat(ids_tr, f$Y.dat[, tr] - f$Y.ct[, tr])
S <- matrix(NA_real_, length(P$v), 1000, dimnames = list(names(P$v), NULL)); SW <- array(NA_real_, c(nW, ncol(P$wk), 1000))
for (j in 1:5) { a <- readRDS(chunks[j]); stopifnot(identical(a$all_week_index, f$rawtime), length(a$od_draws) == 200)
  for (i in 1:200) { d <- a$od_draws[[i]]; r <- stat(d$unit_id, d$gap_all_weeks); b <- (j - 1) * 200 + i
    S[, b] <- r$v[rownames(S)]; SW[, , b] <- r$wk[, colnames(P$wk)] }
  rm(a); gc(FALSE); cat("chunk", j, "/5\n") }
ci <- function(t, s) { ok <- is.finite(s); se <- sd(s[ok]); c(est = unname(t), SE = se, lo = unname(t) - 1.96 * se, hi = unname(t) + 1.96 * se, p = 2 * pnorm(-abs(unname(t) / se)), n_valid = sum(ok)) }
key <- do.call(rbind, strsplit(names(P$v), "|", fixed = TRUE)); colnames(key) <- c("axis", "group", "window", "stat")
ix <- key[, "stat"] %in% c("lvl", "pct")
G <- data.frame(key[ix, ], t(sapply(which(ix), function(i) ci(P$v[i], S[i, ]))), row.names = NULL)
info <- data.frame(key[key[, "window"] == "pre", c("axis", "group")], pre_mean = P$v[key[, "window"] == "pre"], n_od = P$v[key[, "window"] == "n"], row.names = NULL)
G <- merge(G, info, by = c("axis", "group")); G <- G[order(G$axis, G$group, G$window, G$stat), ]
write.csv(G[G$axis != "all", ], file.path(out, "group_level_prepct.csv"), row.names = FALSE)
write.csv(G[G$axis == "all", ], file.path(out, "overall.csv"), row.names = FALSE)
nm <- function(ax, g, w, s) paste(ax, g, w, s, sep = "|")
C <- do.call(rbind, lapply(setdiff(axes, "region"), function(ax) do.call(rbind, lapply(c("lvl", "pct"), function(s) {
  dfun <- function(w, src) { if (is.null(src)) P$v[nm(ax, "Q3", w, s)] - P$v[nm(ax, "Q1", w, s)] else S[nm(ax, "Q3", w, s), ] - S[nm(ax, "Q1", w, s), ] }
  rbind(do.call(rbind, lapply(names(win), function(w) data.frame(axis = ax, stat = s, contrast = "Q3-Q1", window = w, t(ci(dfun(w, NULL), dfun(w, 1)))))),
        data.frame(axis = ax, stat = s, contrast = "Q3-Q1", window = "late_minus_early", t(ci(dfun("late", NULL) - dfun("early", NULL), dfun("late", 1) - dfun("early", 1))))) }))))
write.csv(C, file.path(out, "contrast_level_prepct.csv"), row.names = FALSE)
se_w <- apply(SW, c(1, 2), sd, na.rm = TRUE)
W <- do.call(rbind, lapply(seq_len(ncol(P$wk)), function(c) { z <- strsplit(colnames(P$wk)[c], "|", fixed = TRUE)[[1]]
  data.frame(axis = z[1], group = z[2], date = wk, est = P$wk[, c], lo = P$wk[, c] - 1.96 * se_w[, c], hi = P$wk[, c] + 1.96 * se_w[, c]) }))
write.csv(W, file.path(out, "weekly_level.csv"), row.names = FALSE)
writeLines(c("Chapter 6 heterogeneity, Hainmueller-style metric (2026-11-03).",
  "Level effect = sum(observed - counterfactual) / (weeks x ODs in group): additional weekly ridership per OD pair (person-days), same unit as the gsynth ATT.",
  "Pre-treatment % = 100 x level effect / group mean weekly ridership per OD over the 53 pretreatment weeks (observed).",
  "Groups: pretreatment tertiles (membership.csv of R2_r4_cf_tertiles_timepath_20261103), origins with >= 1,000 residents, boundaries fixed in bootstrap.",
  "CIs: 1,000 paired OD bootstrap draws re-aggregated (no refit); normal approximation; duplicated ODs in a draw count in numerator and denominator.",
  "Level effects scale with group size of ODs; compare groups on the % column, report level for the original unit."), file.path(out, "README.txt"))
print(G[G$window == "full" & G$axis %in% c("all", "transfer", "wait", "distance", "elderly"), c("axis", "group", "stat", "est", "lo", "hi", "pre_mean", "n_od")], row.names = FALSE)

## Weekly figures (level; post-treatment mean line = full-window level effect, labels give % of pretreatment mean)
YL <- as.numeric(strsplit(Sys.getenv("YL", "-300,900"), ",")[[1]])
cols <- c(transfer = "#0072B2", wait = "#1B9E77", region = "#D55E00", access = "#6A3D9A", distance = "#8C6D31", youth = "#4D7F17", elderly = "#B5446E")
titles <- c(transfer = "Transfer burden", wait = "Waiting time per transfer", region = "Planning region", access = "Accessibility",
            distance = "Trip distance", youth = "Youth share", elderly = "Elderly (65+) share")
lab3 <- list(transfer = c("Low", "Middle", "High"), wait = c("Short", "Middle", "Long"), access = c("Low", "Middle", "High"),
             distance = c("Short", "Middle", "Long"), youth = c("Low", "Middle", "High"), elderly = c("Low", "Middle", "High"))
reg_ord <- c("Downtown", "Northeast", "Northwest", "Southwest", "Southeast")
relabel <- function(ax, g) if (ax == "region") factor(g, levels = reg_ord) else factor(lab3[[ax]][as.integer(sub("Q", "", g))], levels = lab3[[ax]])
block <- function(ax) {
  d <- W[W$axis == ax, ]; d$group <- relabel(ax, d$group)
  pm <- merge(G[G$axis == ax & G$window == "full" & G$stat == "lvl", c("group", "est")], G[G$axis == ax & G$window == "full" & G$stat == "pct", c("group", "est")], by = "group", suffixes = c("", "_pct"))
  pm$group <- relabel(ax, pm$group)
  ggplot(d, aes(date, est)) + geom_ribbon(aes(ymin = lo, ymax = hi), fill = cols[[ax]], alpha = 0.25) +
    geom_hline(yintercept = 0, colour = "black", linewidth = 0.4) + geom_vline(xintercept = t0, colour = "grey45", linetype = "42", linewidth = 0.6) +
    geom_line(colour = cols[[ax]], linewidth = 0.55) + geom_point(colour = cols[[ax]], size = 0.55) +
    geom_segment(data = pm, aes(x = t0, xend = max(d$date), y = est, yend = est), colour = "grey15", linewidth = 0.7) +
    geom_label(data = pm, aes(x = as.Date("2023-01-10"), y = YL[2], label = sprintf("Post mean %.0f (%.1f%% of pre)", est, est_pct)),
               hjust = 0, vjust = 1, size = 2.3, label.size = 0, fill = "white", colour = "grey15") +
    facet_wrap(~ group, nrow = 1) + coord_cartesian(ylim = YL) +
    scale_x_date(breaks = as.Date(c("2023-01-01", "2024-01-01")), date_labels = "%Y") +
    labs(title = paste("Grouping:", titles[[ax]]), x = NULL, y = "Additional weekly trips per OD") + theme_minimal(base_size = 7) +
    theme(plot.title = element_text(face = "bold", size = 8, hjust = 0), strip.text = element_text(face = "bold", size = 7),
          panel.grid.minor = element_line(colour = "grey93"), panel.grid.major = element_line(colour = "grey88"), axis.title.y = element_text(face = "bold"))
}
note <- paste0("Estimated effect = observed minus counterfactual weekly ridership per OD pair (person-days), averaged over ODs in each group.\n",
               "Solid horizontal line = post-treatment mean over 46 weeks; label adds the effect as % of the group's pretreatment mean weekly ridership per OD. Dashed line: 29 January 2024.\n",
               "Bands: pointwise normal 95% CIs (1,000 OD-pair bootstrap replications); pretreatment values are in-sample fit residuals.\n",
               sprintf("y-axis limited to [%g, %g]; values outside are truncated. Pretreatment tertiles; origins with at least 1,000 residents.", YL[1], YL[2]))
cap <- function(g) g + plot_annotation(caption = note, theme = theme(plot.caption = element_text(size = 6, hjust = 0)))
row3 <- function(ax) block(ax) + plot_spacer() + plot_layout(widths = c(3, 2))
ggsave(file.path(figd, "fig_hetero_hm_all7_wide_level_en.png"), cap(row3("transfer") / row3("wait") / row3("access") / row3("distance") / row3("youth") / row3("elderly") / block("region")),
       width = 9, height = 14.5, dpi = 300, bg = "white")
ggsave(file.path(figd, "fig_hetero_hm_main_wide_level_en.png"), cap(row3("transfer") / row3("wait") / block("region")), width = 9, height = 6.4, dpi = 300, bg = "white")
cat("Range of weekly values (post-treatment):", paste(round(range(W$est[W$date >= t0 & W$axis != "all"], na.rm = TRUE)), collapse = " ~ "), "\n")
cat("saved", out, "and figures/fig_hetero_hm_{all7,main}_wide_level_en.png\n")
