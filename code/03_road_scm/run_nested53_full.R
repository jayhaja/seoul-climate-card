## run_nested53_full.R — nested(stdv, ADH 2010) 사양을 도너 53(−107·201, C1과 동일)으로 전체 재실행
## 설정: runs/v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6/run_info.json 복원 (공통 예측변수 lanes_mean+speed median, 50주 nested V·W)
## 도너: 그 실행의 donor_pool_{full|main}.csv에서 107·201 제외
##   107: 군포 기후동행카드 협약(2024-01-31) 간접 노출 / 201: 송도 연결로·2024-03 이후 +20% 구조 변화
## 사후 창: 1·2·10번(경인로 남·북행, 여의대방로 북행) 51–72주, 나머지 51–100주
## 산출: 처치 적합, 공간 위약(병렬, 위약마다 V·W 재추정), p(τ=2,3,5,Inf), LOO(고정 V), 시점 위약(27·34·40), 플롯 전부
## Run (from repo root): Rscript code/03_road_scm/run_nested53_full.R                         # 12지점
##       Rscript code/03_road_scm/run_nested53_full.R 4,6,8,12                                       # 일부
##       NESTED_EXCL=none Rscript code/03_road_scm/run_nested53_full.R                               # 도너 55(원 실행과 동일)
##   (macOS only, optional: prefix with `caffeinate -i` to keep the machine awake during long runs)
## RESTRICTED DATA REQUIRED (restricted data required): road detector inputs (Seoul TOPIS sites and national ITS link counts) are not redistributed (licence pending).
## Required input files (place under RAW_DIR):
##   - 77_units/0628_6to10_df_with_new_covariates_fixed.csv   (analysis panel; path set in config_v4.R)
## Also required: the earlier v4 run whose settings/donor pools are restored (produced by run_scm_v4.R, not in this repo):
##   - OUT_DIR/runs/v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6/{run_info.json, donor_pool_main.csv, donor_pool_full.csv}
##     (override the folder with env var SRC_RUN)
suppressMessages({ library(dplyr); library(readr); library(jsonlite); library(parallel) })
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # non-redistributed road inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "03_road_scm"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "03_road_scm")
source(file.path(CODE_DIR, "config_v4.R")); source(file.path(CODE_DIR, "scm_v4_functions.R")); source(file.path(CODE_DIR, "scm_v4_plots.R"))
SRC <- Sys.getenv("SRC_RUN", file.path(OUT_DIR, "runs", "v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6"))
.portable <- CFG[c("panel_csv", "out_root")]
old <- fromJSON(file.path(SRC, "run_info.json"), simplifyVector = FALSE)$config
for (k in names(old)) { v <- old[[k]]; CFG[[k]] <- if (k == "predictors") v else if (is.list(v)) unlist(v) else v }
CFG$panel_csv <- .portable$panel_csv; CFG$out_root <- .portable$out_root   # restored run_info.json holds the original machine's paths → keep portable paths (path only, no settings change)
CFG$placebo_tau <- as.numeric(CFG$placebo_tau)   # JSON에서 "Inf"가 문자로 들어옴 → 수치 변환
CFG$method <- "stdv"; CFG$loo_mode <- "fixedV"; CFG$run_tag <- "v4_stdv_ex107_201_nested53"
EXCL <- if (Sys.getenv("NESTED_EXCL") == "none") integer(0) else c(107L, 201L)
if (!length(EXCL)) CFG$run_tag <- "v4_stdv_nested55_full"
SHORT_UNITS <- c(1L, 2L, 10L); CORES <- 7
units <- 1:12
args <- commandArgs(trailingOnly = TRUE); if (length(args)) units <- as.integer(strsplit(args[1], ",")[[1]])
out <- file.path(OUT_DIR, "runs", paste0(CFG$run_tag, "_", format(Sys.time(), "%Y%m%d-%H%M%S")))
dir.create(out, recursive = TRUE)
logf <- file.path(out, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }
logmsg("[src cfg] ", SRC); logmsg("[exclude] ", paste(EXCL, collapse = ","))
write_json(list(config = CFG, units = units, exclude = EXCL, short_units = SHORT_UNITS, started = format(Sys.time())),
           file.path(out, "run_info.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
df <- load_panel(CFG, logmsg)
preds <- active_predictors(CFG, df)
pool <- lapply(c(main = "main", full = "full"), function(w)
  setdiff(read_csv(file.path(SRC, sprintf("donor_pool_%s.csv", w)), show_col_types = FALSE)$unit_id_num, EXCL))
logmsg(sprintf("[donors] main %d, full %d", length(pool$main), length(pool$full)))
placebo_par <- function(u, donors, post_idx) {
  rs <- mclapply(donors, function(d) tryCatch(fit_two_step(CFG, df, preds, treated = d, donors = setdiff(donors, d), post_idx = post_idx),
                                             error = function(e) NULL), mc.cores = CORES)
  ok <- !vapply(rs, is.null, logical(1))
  res <- bind_rows(lapply(which(ok), function(i) data.frame(placebo_unit = donors[i], pre_rmspe = rs[[i]]$metrics$final_pre_rmspe,
         post_rmspe = rs[[i]]$metrics$post_rmspe, ratio = rs[[i]]$metrics$rmspe_ratio, att_abs = rs[[i]]$metrics$att_abs, att_pct = rs[[i]]$metrics$att_pct))) %>%
    left_join(df %>% distinct(placebo_unit = unit_id_num, unit_name = unit_name_en), by = "placebo_unit")
  if (any(!ok)) logmsg("  위약 실패: ", paste(donors[!ok], collapse = ","))
  list(res = res, paths = bind_rows(lapply(which(ok), function(i) rs[[i]]$path %>% mutate(placebo_unit = donors[i]))))
}
rows <- list()
for (u in units) {
  short <- u %in% SHORT_UNITS; pw <- if (short) "main" else "full"
  post_idx <- if (short) CFG$post_main else CFG$post_full; donors <- pool[[pw]]
  u_dir <- file.path(out, sprintf("unit_%02d", u)); dir.create(u_dir); pdir <- file.path(out, "plots", sprintf("%02d", u)); dir.create(pdir, recursive = TRUE)
  r1 <- df[df$unit_id_num == u, ][1, ]; rl <- paste0(r1$road_en, " ", ifelse(as.integer(r1$direction) == 1, "NB", "SB"))
  fit <- fit_two_step(CFG, df, preds, u, donors, post_idx = post_idx); m <- fit$metrics
  logmsg(sprintf("===== unit %d (%s, %d–%d주, 도너 %d): ATT %+.2f%% | pre %.1f | ratio %.2f | max w %.2f",
                 u, pw, min(post_idx), max(post_idx), length(donors), m$att_pct, m$final_pre_rmspe, m$rmspe_ratio, m$max_w))
  write_csv(fit$path, file.path(u_dir, sprintf("path_%s.csv", pw)))
  write_csv(data.frame(donor = fit$donors, w = fit$w2), file.path(u_dir, "weights.csv"))
  write_csv(data.frame(predictor = rownames(fit$dp2$X1), v_weight = fit$v), file.path(u_dir, "v_weights.csv"))
  pl <- placebo_par(u, donors, post_idx)
  write_csv(pl$res, file.path(u_dir, sprintf("placebo_results_%s.csv", pw))); write_csv(pl$paths, file.path(u_dir, sprintf("placebo_paths_%s.csv", pw)))
  pv <- placebo_pvals(CFG, pl$res, m); write_csv(pv, file.path(u_dir, sprintf("placebo_pvals_%s.csv", pw)))
  logmsg(sprintf("  p(ratio) τ5 %.3f (n=%d) | τ2 %.3f", pv$p_ratio[pv$tau == 5], pv$n_placebo[pv$tau == 5], pv$p_ratio[pv$tau == 2]))
  lo <- loo_refit(CFG, df, preds, fit, post_idx = post_idx)
  if (nrow(lo$res)) { write_csv(lo$res, file.path(u_dir, sprintf("loo_%s.csv", pw))); write_csv(lo$paths, file.path(u_dir, sprintf("loo_paths_%s.csv", pw)))
    logmsg(sprintf("  LOO %d, ATT%% [%+.2f, %+.2f]", nrow(lo$res), min(lo$res$att_pct), max(lo$res$att_pct))) }
  it <- in_time_placebo(CFG, df, preds, u, donors)
  if (nrow(it$res)) { write_csv(it$res, file.path(u_dir, "in_time.csv")); write_csv(it$paths, file.path(u_dir, "in_time_paths.csv"))
    logmsg("  in-time ratios: ", paste(sprintf("%.2f", it$res$fake_ratio), collapse = ", ")) }
  make_unit_plots(CFG, u, rl, fit, pl = pl, lo_paths = lo$paths, it_paths = it$paths, pdir = pdir)
  rows[[length(rows) + 1]] <- data.frame(treated_unit = u, name = r1$unit_name_en, post_window = pw, n_post = length(post_idx), n_donors = length(donors),
                                         as.data.frame(m), p_ratio_tau5 = pv$p_ratio[pv$tau == 5], n_placebo_tau5 = pv$n_placebo[pv$tau == 5],
                                         p_ratio_tau2 = pv$p_ratio[pv$tau == 2])
  write_csv(bind_rows(rows), file.path(out, "all_units_summary.csv"))
}
logmsg("[done] ", out)
