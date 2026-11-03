## run_nested53_abadie2015_placebo.R — 도로 SCM 위약·LOO 재실행 (2026-11-03)
## 본추정: run_nested53_full.R과 같은 nested(method = "stdv", Abadie et al. 2010) 사양, 도너 53(−107·201). 본추정은 재현 확인용으로만 다시 적합.
## 바뀐 점(원본 스크립트·함수는 수정하지 않음)
##   (1) 공간 위약: Abadie et al.(2015) 원저자 구현처럼 위약 대상 d만 도너에서 빼고, 지금 검정하는 처치 지점 1개를 도너에 포함
##       → 위약 도너 = setdiff(53개, d) ∪ {처치 지점}. 다른 처치 지점 11개는 넣지 않음.
##   (2) p값: 사전 적합도 필터 없이 성공한 위약 전체로 (1 + #{R_j ≥ R_1}) / (1 + n). 실패한 위약은 1회 재시도 후 사유를 기록.
##   (3) LOO: loo_mode = "twostep" → 양의 가중치 도너를 하나씩 빼고 nested로 V·W 모두 재추정 (method = "stdv" 유지, CV 아님)
##   (4) 사후 창: 일반 지점 51–96주, 공사 지점(1·2·10) 51–72주. 직렬 실행(병렬 없음).
##   시점 위약은 기존 결과가 이미 nested V·W 재추정이므로 다시 돌리지 않음. 플롯도 만들지 않음(결과 확정 후 별도).
## 실행: cd ~/Thesis/0614/0628/road_scm_v4 && caffeinate -i Rscript run_nested53_abadie2015_placebo.R          # 12지점
##       caffeinate -i Rscript run_nested53_abadie2015_placebo.R 4,6,8,12                                      # 일부
suppressMessages({ library(dplyr); library(readr); library(jsonlite) })
HERE <- path.expand("~/Thesis/0614/0628/road_scm_v4"); setwd(HERE)
source("config_v4.R"); source("scm_v4_functions.R")
SRC <- file.path(HERE, "runs", "v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6")
old <- fromJSON(file.path(SRC, "run_info.json"), simplifyVector = FALSE)$config
for (k in names(old)) { v <- old[[k]]; CFG[[k]] <- if (k == "predictors") v else if (is.list(v)) unlist(v) else v }
CFG$placebo_tau <- as.numeric(CFG$placebo_tau)
CFG$method <- "stdv"; CFG$loo_mode <- "twostep"; CFG$run_tag <- "v4_stdv_ex107_201_nested53_abadie2015pl"
CFG$post_main <- 51:72; CFG$post_full <- 51:96
EXCL <- c(107L, 201L); SHORT_UNITS <- c(1L, 2L, 10L)
units <- 1:12
args <- commandArgs(trailingOnly = TRUE); if (length(args)) units <- as.integer(strsplit(args[1], ",")[[1]])
out <- file.path(HERE, "runs", paste0(CFG$run_tag, "_", format(Sys.time(), "%Y%m%d-%H%M%S"))); dir.create(out, recursive = TRUE)
logf <- file.path(out, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }
write_json(list(config = CFG, units = units, exclude = EXCL, short_units = SHORT_UNITS, started = format(Sys.time()),
                note = "placebo donors = setdiff(pool, d) + treated; p without pre-fit filter; LOO twostep (nested V,W refit); post 51-96 / 51-72"),
           file.path(out, "run_info.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
df <- load_panel(CFG, logmsg); preds <- active_predictors(CFG, df)
pool <- lapply(c(main = "main", full = "full"), function(w)
  setdiff(read_csv(file.path(SRC, sprintf("donor_pool_%s.csv", w)), show_col_types = FALSE)$unit_id_num, EXCL))
logmsg(sprintf("[donors] main %d, full %d", length(pool$main), length(pool$full)))

try_fit <- function(...) {                       # 실패 시 1회 재시도, 사유 반환
  err <- NULL
  for (k in 1:2) { f <- tryCatch(fit_two_step(...), error = function(e) { err <<- conditionMessage(e); NULL }); if (!is.null(f)) return(list(fit = f, err = NA_character_, tries = k)) }
  list(fit = NULL, err = err, tries = 2)
}
rows <- list()
for (u in units) {
  short <- u %in% SHORT_UNITS; pw <- if (short) "main" else "full"
  post_idx <- if (short) CFG$post_main else CFG$post_full; donors <- pool[[pw]]
  u_dir <- file.path(out, sprintf("unit_%02d", u)); dir.create(u_dir)
  fit <- fit_two_step(CFG, df, preds, u, donors, post_idx = post_idx); m <- fit$metrics
  logmsg(sprintf("===== unit %d (%d–%d주, 도너 %d): ATT %+.2f%% | pre %.1f | ratio %.3f", u, min(post_idx), max(post_idx), length(donors), m$att_pct, m$final_pre_rmspe, m$rmspe_ratio))
  write_csv(fit$path, file.path(u_dir, "path.csv"))
  ## (1) 공간 위약 — 직렬
  res <- list(); paths <- list(); fails <- list()
  for (d in donors) {
    r <- try_fit(CFG, df, preds, treated = d, donors = c(setdiff(donors, d), u), post_idx = post_idx)
    if (is.null(r$fit)) { fails[[as.character(d)]] <- data.frame(placebo_unit = d, error = r$err); logmsg("  위약 실패 ", d, ": ", r$err); next }
    f <- r$fit$metrics
    res[[as.character(d)]] <- data.frame(placebo_unit = d, pre_rmspe = f$final_pre_rmspe, post_rmspe = f$post_rmspe, ratio = f$rmspe_ratio,
                                         att_abs = f$att_abs, att_pct = f$att_pct, w_on_treated = r$fit$w2[r$fit$donors == u], tries = r$tries)
    paths[[as.character(d)]] <- r$fit$path %>% mutate(placebo_unit = d)
  }
  res <- bind_rows(res); write_csv(res, file.path(u_dir, "placebo_results.csv")); write_csv(bind_rows(paths), file.path(u_dir, "placebo_paths.csv"))
  fails <- bind_rows(fails); if (nrow(fails)) write_csv(fails, file.path(u_dir, "placebo_failures.csv"))
  n <- nrow(res); c_ge <- sum(res$ratio >= m$rmspe_ratio)
  p_all <- (1 + c_ge) / (1 + n)
  sub5 <- res[res$pre_rmspe <= 5 * m$final_pre_rmspe, ]; p5 <- (1 + sum(sub5$ratio >= m$rmspe_ratio)) / (1 + nrow(sub5))
  logmsg(sprintf("  위약 %d/%d 성공 | 순위 %d/%d | p(전체) %.3f | p(5배 제외, 민감도) %.3f (n=%d) | 처치 지점에 준 가중치 중앙값 %.3f",
                 n, length(donors), 1 + c_ge, 1 + n, p_all, p5, nrow(sub5), median(res$w_on_treated)))
  ## (3) LOO — nested V·W 재추정
  lo <- loo_refit(CFG, df, preds, fit, post_idx = post_idx)
  if (nrow(lo$res)) { write_csv(lo$res, file.path(u_dir, "loo_twostep.csv")); write_csv(lo$paths, file.path(u_dir, "loo_paths_twostep.csv"))
    logmsg(sprintf("  LOO(V·W 재추정) %d개, ATT%% [%+.2f, %+.2f]", nrow(lo$res), min(lo$res$att_pct), max(lo$res$att_pct))) }
  rows[[length(rows) + 1]] <- data.frame(treated_unit = u, post_window = pw, post_from = min(post_idx), post_to = max(post_idx), n_donors = length(donors),
    att_abs = m$att_abs, att_pct_pre = m$att_pct, pre_rmspe = m$final_pre_rmspe, ratio = m$rmspe_ratio,
    n_placebo_ok = n, n_placebo_fail = nrow(fails), rank = 1 + c_ge, p_all = p_all, p_tau5 = p5, n_tau5 = nrow(sub5),
    loo_n = nrow(lo$res), loo_min_pct_pre = if (nrow(lo$res)) min(lo$res$att_pct) else NA, loo_max_pct_pre = if (nrow(lo$res)) max(lo$res$att_pct) else NA)
  write_csv(bind_rows(rows), file.path(out, "all_units_summary.csv"))
}
logmsg("[done] ", out)
