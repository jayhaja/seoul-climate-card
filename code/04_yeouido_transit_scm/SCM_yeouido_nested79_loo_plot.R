## SCM_yeouido_nested79_loo_plot.R — Yeouido main specification (79 donors): redraw the LOO figure (2026-11-03)
## The original Rmd LOO figure has no legend and small text -> redrawn with the same device, font and margins as the main path figure (1.scm_path).
## LOO paths were not saved, so each of the 5 positive-weight donors (w > 0.001) is dropped in turn and V·W re-estimated (about 1 min).
##   The numbers should match loo_sensitivity_D79_nested.csv.
## Output: OUT_DIR/plots/5.loo_D79_nested_v2.jpg, OUT_DIR/loo_paths_D79_nested.csv (OUT_DIR default output/04_yeouido_transit_scm/SCM_yeouido_nested79/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested79_loo_plot.R
## INPUT DATA: smart-card OD panels published in data/transit/ (export approved).
## Required input files (place under RAW_DIR):
##   - data/transit/od_with_pop_sum_without_holiday.csv.gz (included in the repo)
##   - data/transit/df_scm_g.csv (included in the repo)
##   - (from SCM_yeouido_nested79_main.R, in OUT_DIR) M_nested.rds
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_yeouido_nested79"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## The Rmd setup chunk keeps REPO_ROOT, RAW_DIR and OUT_DIR above if they are already defined (HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- c(23L, 55L)
rmd <- file.path(CODE_DIR, "SCM_yeouido_nested_full_pre.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; RMD_LINES[(s + 1):(e - 1)] }
su <- gsub('"SCM_yeouido_nested")', '"SCM_yeouido_nested79")', chunk("setup"), fixed = TRUE)   # OUT_DIR is already defined, so files are actually written to OUT_DIR; this substitution is kept for the Rmd default (used when OUT_DIR is undefined)
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv())
for (lab in c("data", "fit-fn")) eval(parse(text = chunk(lab), encoding = "UTF-8"), envir = globalenv())
donor_ids <- setdiff(donor_ids, EXCL); stopifnot(length(donor_ids) == 79)
M <- readRDS(file.path(HERE, "M_nested.rds")); stopifnot(abs(M$ratio - 3.267) < 0.01)
w <- setNames(as.numeric(M$so$solution.w), sort(as.integer(donor_ids))); targets <- as.integer(names(w)[w > 0.001])
A <- mean(M$Y1[M$t %in% post_idx])
LO <- lapply(targets, function(d) { f <- fit_nested(treat_id, setdiff(donor_ids, d))
  list(path = data.frame(omitted = d, week_index = f$t, synthetic = f$Y0), cf = 100 * f$att / (A - f$att), pre = f$pre) })
paths <- do.call(rbind, lapply(LO, `[[`, "path"))
write.csv(paths, file.path(HERE, "loo_paths_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat("LOO % vs counterfactual:", paste(sprintf("%d: %.2f", targets, sapply(LO, `[[`, "cf")), collapse = ", "), "\n")

## Figure: same device (10in, 300dpi, ragg), margins, font and text size (scale_factor 0.9) as 1.scm_path
fn <- file.path(PLOT, "5.loo_D79_nested_v2.jpg")
if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_jpeg(fn, width = 10, height = 10, units = "in", res = 300) else jpeg(fn, width = 10, height = 10, units = "in", res = 300)
family <- if (grepl("darwin", R.version$os)) "AppleGothic" else "NanumGothic"
par(family = family, mai = c(1.8, 2.0, 1.2, 0.8), cex = 0.9, cex.axis = 0.9, cex.lab = 1, mgp = c(1.5, 0.5, 0))
yr <- range(c(M$Y1, M$Y0, paths$synthetic)); yr <- yr + c(-0.25, 0.05) * diff(yr)       # leave room for the legend at the bottom
plot(M$t, M$Y1, type = "n", ylim = yr, xlab = "Week", ylab = "Weekly users (holidays excl.)", las = 0)
for (d in targets) { s <- paths[paths$omitted == d, ]; lines(s$week_index, s$synthetic, col = "grey65", lwd = 1.2) }
lines(M$t, M$Y0, lty = 2, lwd = 2)
lines(M$t, M$Y1, lwd = 2)
abline(v = min(post_idx), lty = 3, lwd = 1.5)
title(main = paste0("Leave-One-Out - ", legend_lbl2), cex.main = 2, line = 1)   # same cex_main = 2 as the 1.scm_path call
legend("bottomleft", legend = c("Treated", "Synthetic (all donors)", "Synthetic (one donor removed)"),
       lty = c(1, 2, 1), lwd = c(2, 2, 1.2), col = c("black", "black", "grey65"), bty = "o", bg = "white", cex = 1, seg.len = 3, inset = 0.01)
dev.off(); cat("saved", fn, "\n")
