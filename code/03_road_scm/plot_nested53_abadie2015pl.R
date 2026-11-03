## plot_nested53_abadie2015pl.R — run_nested53_abadie2015_placebo.R 결과로 원고용 그림 다시 그리기 (2026-11-03)
## 추정 없음. 가장 최근 runs/v4_stdv_ex107_201_nested53_abadie2015pl_* 폴더의 저장 CSV만 사용. 스타일은 scm_v4_plots.R(기존 원고 그림과 동일).
## 그림: 1 경로, 2 격차, 3 RMSPE 비율 순위, 4 위약 격차, 10 비율 히스토그램 → 위약은 전체(tau=Inf, 주검정)와 5배 제외(민감도) 두 벌
##       5 LOO(V·W 재추정). 시점 위약 그림은 기존 nested53 결과가 그대로 유효하므로 다시 그리지 않음.
## 사후 창: 저장된 그대로(일반 51–96주, 공사 지점 1·2·10은 51–72주).
## 실행: cd ~/Thesis/0614/0628/road_scm_v4 && Rscript plot_nested53_abadie2015pl.R
suppressMessages({ library(dplyr); library(readr); library(ggplot2) })
HERE <- path.expand("~/Thesis/0614/0628/road_scm_v4"); setwd(HERE)
source("config_v4.R"); source("scm_v4_functions.R"); source("scm_v4_plots.R")
## [2026-11-03] 검정통계량은 RMSPE 비율(Abadie et al. 2015) 그대로. 원본 scm_v4_plots.R은 건드리지 않고 히스토그램 제목("limitInf")만 이 스크립트 안에서 정리.
relabel <- function(f, pairs) { s <- paste(deparse(f, width.cutoff = 500L), collapse = "\n"); for (p in pairs) { stopifnot(any(grepl(p[1], s, fixed = TRUE))); s <- gsub(p[1], p[2], s, fixed = TRUE) }
  g <- eval(parse(text = s)); environment(g) <- globalenv(); g }
plot_placebo_ratio_hist <- relabel(plot_placebo_ratio_hist, list(c("sprintf(\"Placebo RMSPE Ratio Histogram (limit%g)\", tau)",
    "sprintf(\"Placebo RMSPE Ratio Histogram (%s)\", if (is.infinite(tau)) \"all placebos\" else paste0(\"pre RMSPE <= \", tau, \"x treated\"))")))
RUN <- sort(Sys.glob(file.path(HERE, "runs", "v4_stdv_ex107_201_nested53_abadie2015pl_*")), decreasing = TRUE)[1]
stopifnot(!is.na(RUN)); cat("run:", RUN, "\n")
OUT <- file.path(RUN, "plots"); TAUS <- c(Inf, 5); T0 <- 51; N_PRE <- 50
df <- load_panel(CFG, function(...) invisible(NULL))
names_df <- df %>% distinct(unit_id_num, unit_name_en)
S <- read_csv(file.path(RUN, "all_units_summary.csv"), show_col_types = FALSE)
.showtext_on()
for (u in S$treated_unit) {
  ud <- file.path(RUN, sprintf("unit_%02d", u)); s <- S[S$treated_unit == u, ]
  r1 <- df[df$unit_id_num == u, ][1, ]; rl <- paste0(r1$road_en, " ", ifelse(as.integer(r1$direction) == 1, "NB", "SB"))
  P  <- read_csv(file.path(ud, "path.csv"), show_col_types = FALSE)
  PL <- read_csv(file.path(ud, "placebo_paths.csv"), show_col_types = FALSE)
  RS <- read_csv(file.path(ud, "placebo_results.csv"), show_col_types = FALSE) %>%
    left_join(names_df, by = c("placebo_unit" = "unit_id_num")) %>% rename(unit_name = unit_name_en)
  pdir <- file.path(OUT, sprintf("%02d", u)); tag <- sprintf("nested53_%dw", s$post_to - T0 + 1)
  plot_path_legacy(P, file.path(pdir, sprintf("1.scm_path_%d_%s.jpg", u, tag)), paste0("SCM Path Plot - ", rl), "Weekly traffic", T0, "path")
  plot_path_legacy(P, file.path(pdir, sprintf("2.scm_gap_%d_%s.jpg", u, tag)), paste0("Gap Plot - ", rl), "Gap (Treated - Synthetic)", T0, "gap")
  for (tau in TAUS) {
    lab <- if (is.infinite(tau)) "all" else sprintf("tau%g", tau)
    plot_mspe_ratio_ranked(RS, s$pre_rmspe, s$ratio, rl, tau, file.path(pdir, sprintf("3.rmspe_ratio_%d_%s_%s.jpg", u, tag, lab)))
    plot_placebo_gaps_limit(PL, RS, P, s$pre_rmspe, N_PRE, tau, rl, file.path(pdir, sprintf("4.placebo_gaps_%d_%s_%s.jpg", u, tag, lab)))
    plot_placebo_ratio_hist(RS, s$pre_rmspe, s$ratio, tau, file.path(pdir, sprintf("10.placebo_hist_%d_%s_%s.jpg", u, tag, lab)))
  }
  lp <- file.path(ud, "loo_paths_twostep.csv")
  if (file.exists(lp)) plot_loo_synthstyle(P, read_csv(lp, show_col_types = FALSE), paste0("Leave-One-Out Path Plot - ", rl, " (V re-selected)"), T0,
                                           file.path(pdir, sprintf("5.loo_%d_%s_twostep.jpg", u, tag)))
  cat(sprintf("unit %d 완료: p(전체) %.3f, 위약 %d\n", u, s$p_all, nrow(RS)))
}
cat("saved", OUT, "\n")
