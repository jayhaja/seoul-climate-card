## run_nested53_abadie2015_placebo.R — re-run of road SCM placebo · LOO (2026-11-03)
## Main estimate: same specification as run_nested53_full.R (method = "stdv", Abadie et al. 2010), 53 donors (−107·201). The main estimate is refitted only to confirm reproduction.
## What changed (the original scripts/functions are not modified)
##   (1) In-space placebo: as in Abadie et al.'s (2015) original implementation, only the placebo unit d is removed from the donors, and the one treated site currently being tested is included as a donor
##       → placebo donors = setdiff(53, d) ∪ {treated site}. The other 11 treated sites are not included.
##   (2) p-value: (1 + #{R_j ≥ R_1}) / (1 + n) over all successful placebos, without a pre-fit filter. Failed placebos are retried once and the reason is recorded.
##   (3) LOO: loo_mode = "twostep" → drop positive-weight donors one at a time and re-estimate both V and W (method = "stdv" kept, not CV)
##   (4) Post window: regular sites weeks 51–96, construction-affected sites (1·2·10) weeks 51–72. Serial execution (no parallelism).
##   In-time placebos are not re-run, since the existing results already re-estimate V and W. No plots are made either (done separately once results are final).
## Run (from repo root): Rscript code/03_road_scm/run_nested53_abadie2015_placebo.R           # 12 sites
##       Rscript code/03_road_scm/run_nested53_abadie2015_placebo.R 4,6,8,12                         # subset
##   (macOS only, optional: prefix with `caffeinate -i` to keep the machine awake during long runs)
## INPUT DATA REQUIRED: road detector inputs (Seoul TOPIS sites and national ITS link counts). Published in data/road/ (see data/README.md).
## Required input files (place under RAW_DIR):
##   - 77_units/0628_6to10_df_with_new_covariates_fixed.csv   (analysis panel; path set in config_v4.R)
## Also required: the earlier v4 run whose settings/donor pools are restored (produced by run_scm_v4.R, not in this repo):
##   - OUT_DIR/runs/v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6/{run_info.json, donor_pool_main.csv, donor_pool_full.csv}
##     (override the folder with env var SRC_RUN)
suppressMessages({ library(dplyr); library(readr); library(jsonlite) })
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # road inputs not yet in the repository
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "03_road_scm"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "03_road_scm")
source(file.path(CODE_DIR, "config_v4.R")); source(file.path(CODE_DIR, "scm_v4_functions.R"))
SRC <- Sys.getenv("SRC_RUN", file.path(OUT_DIR, "runs", "v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6"))
.portable <- CFG[c("panel_csv", "out_root")]
old <- fromJSON(file.path(SRC, "run_info.json"), simplifyVector = FALSE)$config
for (k in names(old)) { v <- old[[k]]; CFG[[k]] <- if (k == "predictors") v else if (is.list(v)) unlist(v) else v }
CFG$panel_csv <- .portable$panel_csv; CFG$out_root <- .portable$out_root   # restored run_info.json holds the original machine's paths → keep portable paths (path only, no settings change)
CFG$placebo_tau <- as.numeric(CFG$placebo_tau)
CFG$method <- "stdv"; CFG$loo_mode <- "twostep"; CFG$run_tag <- "v4_stdv_ex107_201_nested53_abadie2015pl"
CFG$post_main <- 51:72; CFG$post_full <- 51:96
EXCL <- c(107L, 201L); SHORT_UNITS <- c(1L, 2L, 10L)
units <- 1:12
args <- commandArgs(trailingOnly = TRUE); if (length(args)) units <- as.integer(strsplit(args[1], ",")[[1]])
out <- file.path(OUT_DIR, "runs", paste0(CFG$run_tag, "_", format(Sys.time(), "%Y%m%d-%H%M%S"))); dir.create(out, recursive = TRUE)
logf <- file.path(out, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }
write_json(list(config = CFG, units = units, exclude = EXCL, short_units = SHORT_UNITS, started = format(Sys.time()),
                note = "placebo donors = setdiff(pool, d) + treated; p without pre-fit filter; LOO twostep (V and W refit); post 51-96 / 51-72"),
           file.path(out, "run_info.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
df <- load_panel(CFG, logmsg); preds <- active_predictors(CFG, df)
pool <- lapply(c(main = "main", full = "full"), function(w)
  setdiff(read_csv(file.path(SRC, sprintf("donor_pool_%s.csv", w)), show_col_types = FALSE)$unit_id_num, EXCL))
logmsg(sprintf("[donors] main %d, full %d", length(pool$main), length(pool$full)))

try_fit <- function(...) {                       # retry once on failure; return the reason
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
  logmsg(sprintf("===== unit %d (weeks %d–%d, donors %d): ATT %+.2f%% | pre %.1f | ratio %.3f", u, min(post_idx), max(post_idx), length(donors), m$att_pct, m$final_pre_rmspe, m$rmspe_ratio))
  write_csv(fit$path, file.path(u_dir, "path.csv"))
  ## (1) In-space placebo — serial
  res <- list(); paths <- list(); fails <- list()
  for (d in donors) {
    r <- try_fit(CFG, df, preds, treated = d, donors = c(setdiff(donors, d), u), post_idx = post_idx)
    if (is.null(r$fit)) { fails[[as.character(d)]] <- data.frame(placebo_unit = d, error = r$err); logmsg("  placebo failed ", d, ": ", r$err); next }
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
  logmsg(sprintf("  placebos %d/%d succeeded | rank %d/%d | p(all) %.3f | p(excl. >5x, sensitivity) %.3f (n=%d) | median weight on treated site %.3f",
                 n, length(donors), 1 + c_ge, 1 + n, p_all, p5, nrow(sub5), median(res$w_on_treated)))
  ## (3) LOO — V·W re-estimation
  lo <- loo_refit(CFG, df, preds, fit, post_idx = post_idx)
  if (nrow(lo$res)) { write_csv(lo$res, file.path(u_dir, "loo_twostep.csv")); write_csv(lo$paths, file.path(u_dir, "loo_paths_twostep.csv"))
    logmsg(sprintf("  LOO (V·W re-estimated) %d, ATT%% [%+.2f, %+.2f]", nrow(lo$res), min(lo$res$att_pct), max(lo$res$att_pct))) }
  rows[[length(rows) + 1]] <- data.frame(treated_unit = u, post_window = pw, post_from = min(post_idx), post_to = max(post_idx), n_donors = length(donors),
    att_abs = m$att_abs, att_pct_pre = m$att_pct, pre_rmspe = m$final_pre_rmspe, ratio = m$rmspe_ratio,
    n_placebo_ok = n, n_placebo_fail = nrow(fails), rank = 1 + c_ge, p_all = p_all, p_tau5 = p5, n_tau5 = nrow(sub5),
    loo_n = nrow(lo$res), loo_min_pct_pre = if (nrow(lo$res)) min(lo$res$att_pct) else NA, loo_max_pct_pre = if (nrow(lo$res)) max(lo$res$att_pct) else NA)
  write_csv(bind_rows(rows), file.path(out, "all_units_summary.csv"))
}
logmsg("[done] ", out)
