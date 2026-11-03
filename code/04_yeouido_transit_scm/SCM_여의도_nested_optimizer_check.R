## SCM_여의도_nested_optimizer_check.R — nested V·W 추정의 최적화 방법 점검 (2026-11-03)
## 목적: 직접 노출 5개 제외(도너 76) 시 사전 RMSPE가 389 → 459로 나빠진 것이 도너 제외 때문인지, V 최적화의 국소해 때문인지 확인.
##   V는 고정하지 않는다. nested 목적함수(처치 전 결과변수 MSPE 최소)를 그대로 두고 Synth의 최적화 방법만 바꿔 다시 푼다.
##   default(Nelder-Mead) / optimxmethod = "All"(여러 optimx 방법 중 손실 최소) / genoud = TRUE(유전 알고리즘 후 국소 최적화)
##   도너 81(주사양)과 76(제외) 모두. 사전 RMSPE가 가장 낮은 해가 nested 기준에서 더 좋은 해.
## 출력: OUT_DIR/excl_direct_exposure/optimizer_check_excl_<EXCL>.csv (폴더는 SCM_여의도_nested_excl_exposed.R가 만듦; OUT_DIR 기본 output/04_yeouido_transit_scm/SCM_여의도_nested/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_여의도_nested_optimizer_check.R   (genoud 때문에 수 분~십여 분; macOS는 앞에 caffeinate -i 선택)
## RESTRICTED DATA REQUIRED (restricted data required): smart-card OD data (Data Safety Center, export-restricted) are not in this repository.
## Required input files (place under RAW_DIR):
##   - od_with_pop_sum_without_holiday.csv
##   - df_scm_g.csv
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_여의도_nested"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## Rmd setup 청크는 위 REPO_ROOT·RAW_DIR·OUT_DIR가 이미 있으면 그대로 사용(HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- as.integer(strsplit(Sys.getenv("EXCL", "22,23,54,55,56"), ",")[[1]])   # 예: EXCL=23,55 (서울행만)
rmd <- file.path(CODE_DIR, "SCM_여의도_nested_사전전체.Rmd"); L <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), L); e <- s + which(grepl("^```\\s*$", L[(s + 1):length(L)]))[1]; L[(s + 1):(e - 1)] }
for (lab in c("setup", "data")) eval(parse(text = chunk(lab), encoding = "UTF-8"), envir = globalenv())
ff <- chunk("fit-fn"); target <- "Synth::synth(data.prep.obj = dp, verbose = FALSE)"; stopifnot(sum(grepl(target, ff, fixed = TRUE)) == 1)
ff <- gsub(target, "do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE), SYNTH_OPT))", ff, fixed = TRUE)
eval(parse(text = ff, encoding = "UTF-8"), envir = globalenv())
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
cf_pct <- function(f) { q <- f$t %in% post_idx; 100 * sum(f$gap[q]) / sum(f$Y0[q]) }
rows <- list()
for (sp in c("81", "excl")) {
  dn <- if (sp == "81") donor_ids else setdiff(donor_ids, EXCL)
  for (nm in names(OPTS)) {
    SYNTH_OPT <- OPTS[[nm]]; set.seed(20261103); t0 <- Sys.time()
    f <- tryCatch(fit_nested(treat_id, dn), error = function(e) { cat(sp, nm, "실패:", conditionMessage(e), "\n"); NULL })
    if (is.null(f)) next
    w <- sort(setNames(as.numeric(f$so$solution.w), sort(as.integer(dn))), decreasing = TRUE)[1:3]
    rows[[length(rows) + 1]] <- data.frame(donors = sp, optimizer = nm, pre_rmspe = f$pre, loss_v = f$so$loss.v, ratio = f$ratio, cf_pct = cf_pct(f),
      top_w = paste(sprintf("%s:%.2f", names(w), w), collapse = " "), secs = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
    print(tail(rows, 1)[[1]], row.names = FALSE)
  }
}
R <- do.call(rbind, rows); print(R, row.names = FALSE)
write.csv(R, file.path(HERE, "excl_direct_exposure", sprintf("optimizer_check_excl_%s.csv", paste(EXCL, collapse = "_"))), row.names = FALSE, fileEncoding = "UTF-8")
