## SCM_여의도_nested_excl_exposed.R — 여의도 대중교통 SCM 민감도: 기후동행카드 직접 노출 도너 제외 (2026-11-03)
## 제외 도너(2024년 지하철로 기후동행카드 승하차 가능 역 인접):
##   54 성남 중원구 금광동→경기, 55 금광동→서울, 56 상대원동→경기  : 8호선 성남 구간(남위례~모란), 2024-01-27부터 승하차
##   22 광명 하안동→경기, 23 하안동→서울                           : 7호선 철산역(온수~장암 범위 안), 2024-01-27부터
## 그 밖의 사양은 주사양과 동일: Rmd의 setup·data·fit-fn 그대로(nested V·W, 사전 49주, 예측변수 tranfer·pop_dong + 결과 5구간 평균).
## 진단: (1) 공간 위약 — Abadie et al.(2015): 위약 대상만 빼고 처치 OD를 도너에 포함, 사전 적합도 필터 없음(5배 제외는 민감도)
##       (2) LOO — 양의 가중치 도너를 하나씩 빼고 V·W 재추정  (3) 시점 위약 — Rmd와 같은 가짜 시점(사전 기간 55·70·85% 분위)
## 최적화: 모든 적합에서 기본(Nelder-Mead) 실패 시 optimxmethod = "All", 그다음 genoud = TRUE (실패·사용 방법 기록)
## 출력: ~/Thesis/0614/public.transportation/0702/SCM_여의도_nested/excl_direct_exposure/
## 실행: cd ~/Documents/thesis_summary && caffeinate -i Rscript SCM_여의도_nested_excl_exposed.R
EXCL <- as.integer(strsplit(Sys.getenv("EXCL", "22,23,54,55,56"), ",")[[1]])   # 예: EXCL=23,55 (서울행만)
rmd <- path.expand("~/Documents/thesis_summary/SCM_여의도_nested_사전전체.Rmd")
L <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) {
  s <- grep(sprintf("^```\\{r %s[,}]", label), L); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", L[(s + 1):length(L)]))[1]
  L[(s + 1):(e - 1)]
}
for (lab in c("setup", "data", "fit-fn")) eval(parse(text = chunk(lab), encoding = "UTF-8"), envir = globalenv())
ff <- chunk("fit-fn"); target <- "Synth::synth(data.prep.obj = dp, verbose = FALSE)"
stopifnot(sum(grepl(target, ff, fixed = TRUE)) == 1)
ff <- gsub(target, "do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE), SYNTH_OPT))", ff, fixed = TRUE)
ff <- gsub("fit_nested <- function", "fit_nested_opt <- function", ff, fixed = TRUE)
eval(parse(text = ff, encoding = "UTF-8"), envir = globalenv())
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
fit_try <- function(tid, ctrl, ...) {           # 기본 → All → genoud
  for (nm in names(OPTS)) { SYNTH_OPT <<- OPTS[[nm]]
    f <- tryCatch(fit_nested_opt(tid, ctrl, ...), error = function(e) NULL)
    if (!is.null(f)) { f$optimizer <- nm; return(f) } }
  NULL
}
cf_pct <- function(f, idx) { q <- f$t %in% idx; 100 * sum(f$gap[q]) / sum(f$Y0[q]) }

OUT <- file.path(HERE, paste0("excl_direct_exposure", if (setequal(EXCL, c(22, 23, 54, 55, 56))) "" else paste0("_", paste(EXCL, collapse = "_")))); dir.create(OUT, showWarnings = FALSE)
logf <- file.path(OUT, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }
donors <- setdiff(donor_ids, EXCL)
logmsg(sprintf("도너 %d → %d (제외 %s; 실제 제외 %d개)", length(donor_ids), length(donors), paste(EXCL, collapse = ","), length(intersect(donor_ids, EXCL))))

## 본추정
M0 <- fit_try(treat_id, donor_ids); M <- fit_try(treat_id, donors)
logmsg(sprintf("주사양(도너 %d): ATT %.1f | 반사실 대비 %.2f%% | pre RMSPE %.1f | ratio %.3f", length(donor_ids), M0$att, cf_pct(M0, post_idx), M0$pre, M0$ratio))
logmsg(sprintf("제외 사양(도너 %d): ATT %.1f | 반사실 대비 %.2f%% | pre RMSPE %.1f | ratio %.3f | 최적화 %s", length(donors), M$att, cf_pct(M, post_idx), M$pre, M$ratio, M$optimizer))
w_tbl <- data.frame(unit_id_num = sort(as.integer(donors)), weight = as.numeric(M$so$solution.w)) %>%
  left_join(df_scm %>% distinct(unit_id_num, unit_name), by = "unit_id_num") %>% arrange(desc(weight))
write.csv(w_tbl, file.path(OUT, "weights.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(data.frame(week_index = M$t, period = ifelse(M$t %in% final_pre_idx, "pre", "post"), actual = M$Y1, synthetic = M$Y0, gap = M$gap),
          file.path(OUT, "path.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(head(w_tbl, 8))

## (1) 공간 위약
res <- list(); fails <- c(); t0 <- Sys.time()
for (pid in donors) {
  ctrl <- c(setdiff(donors, pid), treat_id); f <- fit_try(pid, ctrl)
  if (is.null(f)) { fails <- c(fails, pid); logmsg("  위약 실패 ", pid); next }
  w <- as.numeric(f$so$solution.w); names(w) <- sort(as.integer(ctrl))
  res[[as.character(pid)]] <- data.frame(placebo_unit = pid, pre = f$pre, post = f$post, ratio = f$ratio, att_abs = f$att, att_pct = f$att_pct,
                                         w_on_treated = unname(w[as.character(treat_id)]), optimizer = f$optimizer)
  logmsg(sprintf("  %3d done (%s, %.0fs)", pid, f$optimizer, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
res <- do.call(rbind, res); write.csv(res, file.path(OUT, "placebo_summary.csv"), row.names = FALSE, fileEncoding = "UTF-8")
n <- nrow(res); c_ge <- sum(res$ratio >= M$ratio); sub5 <- res[res$pre <= 5 * M$pre, ]
pv <- data.frame(rule = c("all (Abadie 2015)", "pre RMSPE <= 5x"), n_attempted = length(donors), n_placebo = c(n, nrow(sub5)), n_failed = length(fails),
                 n_alt_optimizer = sum(res$optimizer != "default"), rank = c(1 + c_ge, 1 + sum(sub5$ratio >= M$ratio)),
                 p_ratio = c((1 + c_ge) / (1 + n), (1 + sum(sub5$ratio >= M$ratio)) / (1 + nrow(sub5))))
write.csv(pv, file.path(OUT, "placebo_pvals.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(pv)

## (2) LOO — V·W 재추정
targets <- w_tbl$unit_id_num[w_tbl$weight > 0.001]
lo <- do.call(rbind, lapply(targets, function(d) { f <- fit_try(treat_id, setdiff(donors, d)); if (is.null(f)) return(NULL)
  data.frame(omitted = d, w_omitted = w_tbl$weight[w_tbl$unit_id_num == d], pre = f$pre, ratio = f$ratio, att = f$att, cf_pct = cf_pct(f, post_idx), optimizer = f$optimizer) }))
write.csv(lo, file.path(OUT, "loo_refitV.csv"), row.names = FALSE, fileEncoding = "UTF-8")
logmsg(sprintf("LOO %d개: 반사실 대비 %.2f ~ %.2f%%", nrow(lo), min(lo$cf_pct), max(lo$cf_pct)))

## (3) 시점 위약
fakes <- as.integer(round(quantile(final_pre_idx, c(0.55, 0.70, 0.85))))
it <- do.call(rbind, lapply(fakes, function(fs) { fp <- final_pre_idx[final_pre_idx < fs]; fq <- setdiff(final_pre_idx, fp)
  f <- fit_try(treat_id, donors, pre_idx = fp, eval_post_idx = fq); if (is.null(f)) return(NULL)
  data.frame(fake_start = fs, n_fake_pre = length(fp), pre_rmspe = f$pre, ratio = f$ratio, fake_att_pct = f$att_pct) }))
write.csv(it, file.path(OUT, "in_time.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(it)

summ <- data.frame(spec = c("main (81 donors)", "excl. direct exposure"), n_donors = c(length(donor_ids), length(donors)),
                   att = c(M0$att, M$att), cf_pct = c(cf_pct(M0, post_idx), cf_pct(M, post_idx)), pre_rmspe = c(M0$pre, M$pre), ratio = c(M0$ratio, M$ratio),
                   p_all = c(NA, pv$p_ratio[1]), loo_min = c(NA, min(lo$cf_pct)), loo_max = c(NA, max(lo$cf_pct)))
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(summ)
logmsg("[done] ", OUT)
