## SCM_여의도_adhcv79.R — 여의도 대중교통 SCM 대안 사양: 학습·검증으로 V 선택(Abadie et al. 2015), 도너 79 (2026-11-03)
## V 선택 절차는 기존 대안 사양 스크립트(storage/…/SCM_여의도_ADHCV_정렬수정_20260813.R, 읽기만 함)와 동일:
##   처치 전 49주를 앞 25주(학습)·뒤 24주(검증)로 나눔 → 1단계: 학습 구간 예측변수(공변량 + 학습 구간 5구간 평균)로 합성통제를 만들고
##   검증 구간 결과변수 예측오차가 최소인 V* 선택 → 2단계: V* 고정, 처치 전 전체 49주 예측변수(5구간 평균)로 최종 W.
## 바뀐 점: (1) 도너 79(55 금광동→서울, 23 하안동→서울 제외 — 주사양과 동일)
##          (2) 위약: Abadie et al.(2015) — 위약 대상만 빼고 처치 OD를 도너에 포함, 각 위약도 같은 2단계 절차, 필터 없음(5배 제외는 민감도)
##          (3) LOO: 양의 가중치 도너를 하나씩 빼고 2단계 절차 전체(V*·W) 재추정
##          (4) 최적화: 각 단계에서 기본 실패 시 optimxmethod = "All" → genoud (사용 방법 기록)
## 패널: 주사양 Rmd의 setup·data 청크 그대로(같은 자료·같은 주).
## 출력: ~/Thesis/0614/public.transportation/0702/SCM_여의도_adhcv79/
## 실행: cd ~/Documents/thesis_summary && caffeinate -i Rscript SCM_여의도_adhcv79.R   (약 30분)
EXCL <- c(23L, 55L)
rmd <- path.expand("~/Documents/thesis_summary/SCM_여의도_nested_사전전체.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; RMD_LINES[(s + 1):(e - 1)] }
su <- gsub('"SCM_여의도_nested")', '"SCM_여의도_adhcv79")', chunk("setup"), fixed = TRUE)
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv()); eval(parse(text = chunk("data"), encoding = "UTF-8"), envir = globalenv())
donor_ids <- setdiff(donor_ids, EXCL); stopifnot(length(donor_ids) == 79)
logf <- file.path(HERE, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }

n_fit <- ceiling(n_pre / 2); fit_idx <- final_pre_idx[seq_len(n_fit)]; valid_idx <- setdiff(final_pre_idx, fit_idx)
logmsg(sprintf("도너 %d | 학습 %d주(%d~%d) / 검증 %d주(%d~%d)", length(donor_ids), length(fit_idx), min(fit_idx), max(fit_idx), length(valid_idx), min(valid_idx), max(valid_idx)))
sp_make <- function(idx, n_blocks = N_SP_BLOCK, dep = "users") { ed <- round(seq(0, length(idx), length.out = n_blocks + 1))
  lapply(seq_len(n_blocks), function(b) list(dep, as.integer(idx[(ed[b] + 1):ed[b + 1]]), "mean")) }
sp_fit <- sp_make(fit_idx); sp_full <- sp_make(final_pre_idx)
.dp <- function(tid, ctrl, sp, prior, ssr, tplot) Synth::dataprep(foo = df_scm, predictors = PREDS, predictors.op = "mean",
  special.predictors = sp, dependent = "users", unit.variable = "unit_id_num", unit.names.variable = "unit_name_en", time.variable = "week_index",
  treatment.identifier = as.integer(tid), controls.identifier = sort(as.integer(ctrl)), time.predictors.prior = prior, time.optimize.ssr = ssr, time.plot = tplot)
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
synth_try <- function(dp, ...) { for (nm in names(OPTS)) {
  so <- tryCatch({ invisible(utils::capture.output(o <- do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE, ...), OPTS[[nm]])))); o }, error = function(e) NULL)
  if (!is.null(so)) { so$optimizer <- nm; return(so) } }; stop("synth 실패(모든 최적화 방법)") }
fit_cv <- function(tid, ctrl) {
  so1 <- synth_try(.dp(tid, ctrl, sp_fit, fit_idx, valid_idx, c(fit_idx, valid_idx))); v <- as.numeric(so1$solution.v)
  dp2 <- .dp(tid, ctrl, sp_full, final_pre_idx, final_pre_idx, all_idx); so2 <- synth_try(dp2, custom.v = v)
  Y1 <- as.numeric(dp2$Y1plot); Y0 <- as.numeric(dp2$Y0plot %*% so2$solution.w); g <- Y1 - Y0; tt <- dp2$tag$time.plot
  pm <- tt %in% final_pre_idx; qm <- tt %in% post_idx
  list(dp = dp2, so = so2, v = v, Y1 = Y1, Y0 = Y0, gap = g, t = tt, optimizer = paste(so1$optimizer, so2$optimizer, sep = "/"),
       pre = sqrt(mean(g[pm]^2)), post = sqrt(mean(g[qm]^2)), ratio = sqrt(mean(g[qm]^2)) / sqrt(mean(g[pm]^2)),
       att = mean(g[qm]), cf_pct = 100 * sum(g[qm]) / sum(Y0[qm]), att_pct = mean(g[qm]) / mean(Y1[pm]) * 100,
       valid_rmspe = sqrt(mean(g[tt %in% valid_idx]^2)))
}

## 본추정
M <- fit_cv(treat_id, donor_ids)
logmsg(sprintf("학습·검증 V (도너 79): ATT %.1f | 반사실 대비 %.2f%% | pre RMSPE %.1f | ratio %.3f | 최적화 %s", M$att, M$cf_pct, M$pre, M$ratio, M$optimizer))
w_tbl <- data.frame(unit_id_num = sort(as.integer(donor_ids)), weight = as.numeric(M$so$solution.w)) %>%
  left_join(df_scm %>% distinct(unit_id_num, unit_name), by = "unit_id_num") %>% arrange(desc(weight))
write.csv(w_tbl, file.path(HERE, "weights_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(head(w_tbl, 8))
write.csv(data.frame(predictor = rownames(M$dp$X1), V = M$v), file.path(HERE, "vweights_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(data.frame(week_index = M$t, period = ifelse(M$t %in% final_pre_idx, "pre", "post"), actual = M$Y1, synthetic = M$Y0, gap = M$gap),
          file.path(HERE, "path_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")

## 위약 — Abadie et al.(2015)
plc <- list(); paths <- list(); fails <- c(); t0 <- Sys.time()
for (pid in donor_ids) {
  ctrl <- c(setdiff(donor_ids, pid), treat_id); f <- tryCatch(fit_cv(pid, ctrl), error = function(e) NULL)
  if (is.null(f)) { fails <- c(fails, pid); logmsg("  위약 실패 ", pid); next }
  ww <- setNames(as.numeric(f$so$solution.w), sort(as.integer(ctrl)))
  plc[[as.character(pid)]] <- data.frame(placebo_unit = pid, pre = f$pre, post = f$post, ratio = f$ratio, att_abs = f$att, cf_pct = f$cf_pct,
                                         w_on_treated = unname(ww[as.character(treat_id)]), optimizer = f$optimizer)
  paths[[as.character(pid)]] <- data.frame(placebo_unit = pid, week_index = f$t, placebo_gap = f$gap)
  logmsg(sprintf("  %3d done (%s, %.0fs)", pid, f$optimizer, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
plc <- do.call(rbind, plc); write.csv(plc, file.path(HERE, "placebo_summary_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(do.call(rbind, paths), file.path(HERE, "placebo_paths_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")
pv <- do.call(rbind, lapply(c(Inf, 5), function(tau) { s <- plc[plc$pre <= tau * M$pre, ]
  data.frame(rule = if (is.infinite(tau)) "all (Abadie 2015)" else "pre RMSPE <= 5x", n_attempted = length(donor_ids), n_placebo = nrow(s), n_failed = length(fails),
             n_alt_optimizer = sum(plc$optimizer != "default/default"), rank = 1 + sum(s$ratio >= M$ratio), p_ratio = (1 + sum(s$ratio >= M$ratio)) / (1 + nrow(s))) }))
write.csv(pv, file.path(HERE, "placebo_pvals_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(pv)

## LOO — 2단계 절차 전체 재추정
targets <- w_tbl$unit_id_num[w_tbl$weight > 0.001]
lo <- do.call(rbind, lapply(targets, function(d) { f <- tryCatch(fit_cv(treat_id, setdiff(donor_ids, d)), error = function(e) NULL); if (is.null(f)) return(NULL)
  data.frame(omitted = d, w_omitted = w_tbl$weight[w_tbl$unit_id_num == d], pre = f$pre, ratio = f$ratio, att = f$att, cf_pct = f$cf_pct, optimizer = f$optimizer) }))
write.csv(lo, file.path(HERE, "loo_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")

summ <- data.frame(spec = "adhcv, 79 donors", att = M$att, cf_pct = M$cf_pct, pre_rmspe = M$pre, valid_rmspe = M$valid_rmspe, ratio = M$ratio,
                   rank_all = pv$rank[1], p_all = pv$p_ratio[1], p_tau5 = pv$p_ratio[2], loo_n = nrow(lo), loo_min = min(lo$cf_pct), loo_max = max(lo$cf_pct))
write.csv(summ, file.path(HERE, "summary_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(summ)
logmsg("[done] ", HERE)
