## SCM_여의도_nested79_plots_rmspe.R — 여의도 주사양(도너 79) 위약 그림을 RMSPE 비율로 다시 그리기 (2026-11-03)
## 전제: SCM_여의도_nested79_main.R 실행 완료(0702/SCM_여의도_nested79/ 에 M_nested.rds, weights·placebo CSV 존재). 추정 없음.
## 통계량은 RMSPE 비율(Abadie et al. 2015). helper 문구의 "MSPE"를 "RMSPE"로 바꿔 그림. MSPE로 덮어쓴 히스토그램을 되돌리는 용도.
## 실행: cd ~/Documents/thesis_summary && Rscript SCM_여의도_nested79_plots_rmspe.R
rmd <- path.expand("~/Documents/thesis_summary/SCM_여의도_nested_사전전체.Rmd"); L <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), L); e <- s + which(grepl("^```\\s*$", L[(s + 1):length(L)]))[1]; L[(s + 1):(e - 1)] }
su <- gsub('"SCM_여의도_nested")', '"SCM_여의도_nested79")', chunk("setup"), fixed = TRUE)
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv()); eval(parse(text = chunk("data"), encoding = "UTF-8"), envir = globalenv())
ph <- chunk("plot-helpers")
ph <- gsub("(tau = %d)\", tau)", "(%s)\", if (is.infinite(tau)) \"all placebos\" else paste0(\"pre RMSPE <= \", tau, \"x\"))", ph, fixed = TRUE)
ph <- gsub("(tau = %d)\", legend_lbl2, tau)", "(%s)\", legend_lbl2, if (is.infinite(tau)) \"all placebos\" else paste0(\"pre RMSPE <= \", tau, \"x\"))", ph, fixed = TRUE)
ph <- gsub("MSPE", "RMSPE", gsub("RMSPE", "MSPE", ph, fixed = TRUE), fixed = TRUE)
eval(parse(text = ph, encoding = "UTF-8"), envir = globalenv())
M <- readRDS(file.path(HERE, "M_nested.rds")); stopifnot(abs(M$ratio - 3.267) < 0.01)
w_tbl <- read.csv(file.path(HERE, "weights_D79_nested.csv"))
plc <- read.csv(file.path(HERE, "placebo_summary_D79_nested.csv")); plc_paths <- read.csv(file.path(HERE, "placebo_paths_D79_nested.csv"))
paths_pl <- plc_paths %>% transmute(treated = placebo_unit, t = week_index, gap = placebo_gap)
res_pl <- plc %>% transmute(treated = placebo_unit, pre, ratio)
lookup <- bind_rows(w_tbl %>% transmute(unit_id_num, unit_name_en = unit_name), tibble(unit_id_num = treat_id, unit_name_en = legend_lbl2))
cat(sprintf("RMSPE 비율: 처치 %.3f | 위약 %d개 | p(전체) %.4f\n", M$ratio, nrow(plc), (1 + sum(res_pl$ratio >= M$ratio)) / (1 + nrow(plc))))
for (tau in c(Inf, 5)) { lab <- if (is.infinite(tau)) "all" else "tau5"
  plot_placebo_gaps_limit(paths_pl = paths_pl, res_pl = res_pl, gaps_main = M$gap, pre_rmspe = M$pre, n_pre = n_pre, tau = tau, base_size = 7.2,
    filename = file.path(PLOT, sprintf("4.placebo_gaps_D79_nested_%s.jpg", lab)), legend_lbl2 = legend_lbl2)
  plot_mspe_ratio_ranked(res_pl = res_pl, pre_rmspe = M$pre, ratio_main = M$ratio, lookup_tbl = lookup, treat_id = treat_id, tau = tau, base_size = 7.2,
    filename = file.path(PLOT, sprintf("3.rmspe_ratio_D79_nested_%s.jpg", lab)), legend_lbl2 = legend_lbl2)
  plot_placebo_ratio_hist(res_pl = res_pl, pre_rmspe = M$pre, ratio_main = M$ratio, tau = tau, base_size = 7.2,
    filename = file.path(PLOT, sprintf("10.placebo_hist_D79_nested_%s.jpg", lab))) }
cat("saved", PLOT, "\n")
