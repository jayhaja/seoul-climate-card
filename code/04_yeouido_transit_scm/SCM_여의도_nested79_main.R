## SCM_여의도_nested79_main.R — 여의도 대중교통 SCM 주사양(도너 79) 전체 산출물 (2026-11-03)
## 주사양 변경: 도너 81 → 79. 제외: 55 성남 중원구 금광동→서울(8호선 성남 구간, 2024-01-27부터 승하차),
##                              23 광명 하안동→서울(7호선 철산역, 온수~장암 범위). 경기행 OD(54, 56, 22)는 노출이 약해 유지.
## 방법: Rmd(SCM_여의도_nested_사전전체.Rmd)의 setup·data·fit-fn·main-fit·plot-helpers·plot-path-gap·loo-plots·intime-plots 청크를
##   그대로 실행하되, donor_ids에서 두 OD를 빼고 저장 폴더·파일 이름을 D79로 바꾼다(원본 Rmd 수정 없음).
##   공간 위약은 Abadie et al.(2015) 방식으로 따로 실행: 위약 대상만 빼고 처치 OD를 도너에 포함, 필터 없음(5배 제외는 민감도),
##   기본 최적화 실패 시 optimxmethod = "All" → genoud. 위약 경로까지 저장해 그림을 그린다.
## 출력: OUT_DIR (기본 output/04_yeouido_transit_scm/SCM_여의도_nested79/, + plots/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_여의도_nested79_main.R   (약 25분; macOS는 앞에 caffeinate -i 선택)
## RESTRICTED DATA REQUIRED (restricted data required): smart-card OD data (Data Safety Center, export-restricted) are not in this repository.
## Required input files (place under RAW_DIR):
##   - od_with_pop_sum_without_holiday.csv
##   - df_scm_g.csv
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_여의도_nested79"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## Rmd setup 청크는 위 REPO_ROOT·RAW_DIR·OUT_DIR가 이미 있으면 그대로 사용(HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- c(23L, 55L)
rmd <- file.path(CODE_DIR, "SCM_여의도_nested_사전전체.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")   # 이름을 L로 두면 loo-plots 청크의 L 변수에 덮어써짐
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; x <- RMD_LINES[(s + 1):(e - 1)]
  x <- gsub("D81_nested", "D79_nested", x, fixed = TRUE); x }            # 파일 이름의 라벨을 D79로
run <- function(label) eval(parse(text = chunk(label), encoding = "UTF-8"), envir = globalenv())
## setup: 저장 폴더는 위 OUT_DIR (아래 gsub은 Rmd 기본 폴더 이름도 nested79로 맞춤)
su <- chunk("setup"); su <- gsub('"SCM_여의도_nested")', '"SCM_여의도_nested79")', su, fixed = TRUE); stopifnot(any(grepl("SCM_여의도_nested79", su)))   # OUT_DIR가 이미 정의돼 있어 실제 저장 폴더는 OUT_DIR; 이 치환은 Rmd 기본값(OUT_DIR 미정의 시)용으로 유지
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv())
run("data")
donor_ids <- setdiff(donor_ids, EXCL); stopifnot(length(donor_ids) == 79)
cat("도너", length(donor_ids), "| 제외", paste(EXCL, collapse = ","), "| 저장", HERE, "\n")
## fit 함수: 원본 + 최적화 옵션을 넘길 수 있게(SYNTH_OPT 빈 목록이면 원본과 동일)
ff <- chunk("fit-fn"); target <- "Synth::synth(data.prep.obj = dp, verbose = FALSE)"; stopifnot(sum(grepl(target, ff, fixed = TRUE)) == 1)
ff <- gsub(target, "do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE), SYNTH_OPT))", ff, fixed = TRUE)
SYNTH_OPT <- list(); eval(parse(text = ff, encoding = "UTF-8"), envir = globalenv())
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
fit_try <- function(tid, ctrl, ...) { for (nm in names(OPTS)) { SYNTH_OPT <<- OPTS[[nm]]
  f <- tryCatch(fit_nested(tid, ctrl, ...), error = function(e) NULL); if (!is.null(f)) { SYNTH_OPT <<- list(); f$optimizer <- nm; return(f) } }
  SYNTH_OPT <<- list(); NULL }

run("main-fit")                                     # M, w_tbl, v_tbl, path_tbl, M_nested.rds (D79 이름으로 저장)
cf <- function(f, idx = post_idx) { q <- f$t %in% idx; 100 * sum(f$gap[q]) / sum(f$Y0[q]) }
cat(sprintf("주사양(도너 79): ATT %.1f | 반사실 대비 %.2f%% | pre RMSPE %.1f | ratio %.3f\n", M$att, cf(M), M$pre, M$ratio))
## 예측변수 균형표(표 4-2·4-3용): 처치, 합성통제, 도너 단순평균
X1 <- as.numeric(M$dp$X1); X0 <- M$dp$X0; w <- as.numeric(M$so$solution.w)
bal <- data.frame(predictor = rownames(M$dp$X1), treated = X1, synthetic = as.numeric(X0 %*% w), donor_mean = rowMeans(X0), V = M$v)
write.csv(bal, file.path(HERE, "predictor_means_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(bal, digits = 4)

run("plot-helpers"); run("plot-path-gap")

## 공간 위약 — Abadie et al.(2015)
plc <- list(); plc_paths <- list(); fails <- c(); t0 <- Sys.time()
for (pid in donor_ids) {
  ctrl <- c(setdiff(donor_ids, pid), treat_id); f <- fit_try(pid, ctrl)
  if (is.null(f)) { fails <- c(fails, pid); message("  위약 실패 ", pid); next }
  ww <- setNames(as.numeric(f$so$solution.w), sort(as.integer(ctrl)))
  plc[[as.character(pid)]] <- data.frame(placebo_unit = pid, pre = f$pre, post = f$post, ratio = f$ratio, att_abs = f$att, att_pct = f$att_pct,
                                         w_on_treated = unname(ww[as.character(treat_id)]), optimizer = f$optimizer)
  plc_paths[[as.character(pid)]] <- data.frame(placebo_unit = pid, week_index = f$t, placebo_gap = f$gap)
  cat(sprintf("  %3d done (%s, %.0fs)\n", pid, f$optimizer, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
plc <- do.call(rbind, plc); plc_paths <- do.call(rbind, plc_paths)
write.csv(plc, file.path(HERE, "placebo_summary_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(plc_paths, file.path(HERE, "placebo_paths_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8")
n <- nrow(plc); pv <- do.call(rbind, lapply(c(Inf, 5), function(tau) { s <- plc[plc$pre <= tau * M$pre, ]
  data.frame(rule = if (is.infinite(tau)) "all (Abadie 2015)" else "pre RMSPE <= 5x", n_attempted = length(donor_ids), n_placebo = nrow(s),
             n_failed = length(fails), n_alt_optimizer = sum(plc$optimizer != "default"), rank = 1 + sum(s$ratio >= M$ratio),
             p_ratio = (1 + sum(s$ratio >= M$ratio)) / (1 + nrow(s))) }))
write.csv(pv, file.path(HERE, "placebo_pvals_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(pv)
## 위약 그림: 제목의 "(tau = %d)"를 Inf에서도 쓰도록
ph <- chunk("plot-helpers")
ph <- gsub("(tau = %d)\", tau)", "(%s)\", if (is.infinite(tau)) \"all placebos\" else paste0(\"tau = \", tau))", ph, fixed = TRUE)
ph <- gsub("(tau = %d)\", legend_lbl2, tau)", "(%s)\", legend_lbl2, if (is.infinite(tau)) \"all placebos\" else paste0(\"tau = \", tau))", ph, fixed = TRUE)
ph <- gsub("MSPE", "RMSPE", gsub("RMSPE", "MSPE", ph, fixed = TRUE), fixed = TRUE)      # 통계량 이름을 RMSPE로(값은 RMSPE 비율)
eval(parse(text = ph, encoding = "UTF-8"), envir = globalenv())
paths_pl <- plc_paths %>% transmute(treated = placebo_unit, t = week_index, gap = placebo_gap)
res_pl <- plc %>% transmute(treated = placebo_unit, pre, ratio)
lookup <- bind_rows(w_tbl %>% transmute(unit_id_num, unit_name_en = unit_name), tibble(unit_id_num = treat_id, unit_name_en = legend_lbl2))
for (tau in c(Inf, 5)) { lab <- if (is.infinite(tau)) "all" else "tau5"
  plot_placebo_gaps_limit(paths_pl = paths_pl, res_pl = res_pl, gaps_main = M$gap, pre_rmspe = M$pre, n_pre = n_pre, tau = tau, base_size = 7.2,
    filename = file.path(PLOT, sprintf("4.placebo_gaps_D79_nested_%s.jpg", lab)), legend_lbl2 = legend_lbl2)
  plot_mspe_ratio_ranked(res_pl = res_pl, pre_rmspe = M$pre, ratio_main = M$ratio, lookup_tbl = lookup, treat_id = treat_id, tau = tau, base_size = 7.2,
    filename = file.path(PLOT, sprintf("3.rmspe_ratio_D79_nested_%s.jpg", lab)), legend_lbl2 = legend_lbl2)
  plot_placebo_ratio_hist(res_pl = res_pl, pre_rmspe = M$pre, ratio_main = M$ratio, tau = tau, base_size = 7.2,
    filename = file.path(PLOT, sprintf("10.placebo_hist_D79_nested_%s.jpg", lab))) }

run("loo-plots")      # V·W 재추정(revise, 본문용)과 V 고정(참고) 둘 다 저장
lo <- read.csv(file.path(HERE, "loo_sensitivity_D79_nested.csv")); A <- mean(M$Y1[M$t %in% post_idx])
lo$cf_pct <- 100 * lo$ATT / (A - lo$ATT); write.csv(lo, file.path(HERE, "loo_sensitivity_D79_nested_cf.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("LOO(V·W 재추정) %d개: 반사실 대비 %.2f ~ %.2f%%\n", nrow(lo), min(lo$cf_pct), max(lo$cf_pct)))
run("intime-plots")
cat("[done]", HERE, "\n")
