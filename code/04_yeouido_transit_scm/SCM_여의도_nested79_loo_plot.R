## SCM_여의도_nested79_loo_plot.R — 여의도 주사양(도너 79) LOO 그림 다시 그리기 (2026-11-03)
## 기존 Rmd LOO 그림은 범례가 없고 글씨가 작음 → 본추정 경로 그림(1.scm_path)과 같은 장치·글꼴·여백으로 다시 그림.
## LOO 경로는 저장돼 있지 않아 양의 가중치 도너 5개(w > 0.001)를 하나씩 빼고 nested V·W를 다시 추정(약 1분). 수치는 loo_sensitivity_D79_nested.csv와 같아야 함.
## 출력: 0702/SCM_여의도_nested79/plots/5.loo_D79_nested_v2.jpg, loo_paths_D79_nested.csv
## 실행: cd ~/Documents/thesis_summary && Rscript SCM_여의도_nested79_loo_plot.R
EXCL <- c(23L, 55L)
rmd <- path.expand("~/Documents/thesis_summary/SCM_여의도_nested_사전전체.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; RMD_LINES[(s + 1):(e - 1)] }
su <- gsub('"SCM_여의도_nested")', '"SCM_여의도_nested79")', chunk("setup"), fixed = TRUE)
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
cat("LOO 반사실 대비 %:", paste(sprintf("%d: %.2f", targets, sapply(LO, `[[`, "cf")), collapse = ", "), "\n")

## 그림: 1.scm_path와 같은 장치(10in, 300dpi, ragg)·여백·글꼴·글자 크기(scale_factor 0.9)
fn <- file.path(PLOT, "5.loo_D79_nested_v2.jpg")
if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_jpeg(fn, width = 10, height = 10, units = "in", res = 300) else jpeg(fn, width = 10, height = 10, units = "in", res = 300)
family <- if (grepl("darwin", R.version$os)) "AppleGothic" else "NanumGothic"
par(family = family, mai = c(1.8, 2.0, 1.2, 0.8), cex = 0.9, cex.axis = 0.9, cex.lab = 1, mgp = c(1.5, 0.5, 0))
yr <- range(c(M$Y1, M$Y0, paths$synthetic)); yr <- yr + c(-0.25, 0.05) * diff(yr)       # 아래쪽에 범례 자리
plot(M$t, M$Y1, type = "n", ylim = yr, xlab = "Week", ylab = "Weekly users (holidays excl.)", las = 0)
for (d in targets) { s <- paths[paths$omitted == d, ]; lines(s$week_index, s$synthetic, col = "grey65", lwd = 1.2) }
lines(M$t, M$Y0, lty = 2, lwd = 2)
lines(M$t, M$Y1, lwd = 2)
abline(v = min(post_idx), lty = 3, lwd = 1.5)
title(main = paste0("Leave-One-Out - ", legend_lbl2), cex.main = 2, line = 1)   # 1.scm_path 호출과 같은 cex_main = 2
legend("bottomleft", legend = c("Treated", "Synthetic (all donors)", "Synthetic (one donor removed)"),
       lty = c(1, 2, 1), lwd = c(2, 2, 1.2), col = c("black", "black", "grey65"), bty = "o", bg = "white", cex = 1, seg.len = 3, inset = 0.01)
dev.off(); cat("saved", fn, "\n")
