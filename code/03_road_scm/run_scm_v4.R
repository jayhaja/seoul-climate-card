## run_scm_v4.R — runs road SCM v4. CFG$method: "stdv" (joint V·W over 50 pre-weeks, ADH 2010) | "adh2015" (v3 two-step)
## Run (from repo root): Rscript code/03_road_scm/run_scm_v4.R            # all 12 sites
##       Rscript code/03_road_scm/run_scm_v4.R 1,4,6                         # selected sites
##       Rscript code/03_road_scm/run_scm_v4.R 1 --no-placebo                                  # skip placebo · LOO · in-time (quick check)
## Output: OUT_DIR/runs/<run_tag>_<YYYYmmdd-HHMMSS>_<hash(settings+input+code+sites+options)>_<random>/  — always a new folder; stops if it already exists
## RESTRICTED DATA REQUIRED (restricted data required): road detector inputs (Seoul TOPIS sites and national ITS link counts) are not redistributed (licence pending).
## Required input files (place under RAW_DIR):
##   - 77_units/0628_6to10_df_with_new_covariates_fixed.csv   (analysis panel; path set in config_v4.R, override with SCM_PANEL)
suppressMessages({ library(dplyr); library(readr); library(jsonlite) })
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # non-redistributed road inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "03_road_scm"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "03_road_scm")
HERE <- CODE_DIR
source(file.path(HERE, "config_v4.R")); source(file.path(HERE, "scm_v4_functions.R")); source(file.path(HERE, "scm_v4_plots.R"))
## Sensitivity runs by changing only the panel/tag via env vars (without editing config_v4.R): SCM_PANEL=<path to fixed.csv> SCM_TAG=<run_tag>
if (nzchar(Sys.getenv("SCM_PANEL"))) CFG$panel_csv <- Sys.getenv("SCM_PANEL")
if (nzchar(Sys.getenv("SCM_TAG")))   CFG$run_tag   <- Sys.getenv("SCM_TAG")
if (nzchar(Sys.getenv("SCM_METHOD"))) CFG$method   <- Sys.getenv("SCM_METHOD")
if (nzchar(Sys.getenv("SCM_EXCLUDE"))) {                       # "none" = all 65 with no qualitative exclusions / a list such as "114,304"
  CFG$donor_exclude <- if (Sys.getenv("SCM_EXCLUDE") == "none") integer(0) else as.integer(strsplit(Sys.getenv("SCM_EXCLUDE"), ",")[[1]])
  CFG$donor_exclude_reason <- CFG$donor_exclude_reason[as.character(CFG$donor_exclude)]
}
if (identical(CFG$method, "cv")) { CFG$final_w_idx <- CFG$pre_idx; if (identical(CFG$cv$final_v, "nested")) CFG$method_fit <- "stdv" }
args <- commandArgs(trailingOnly = TRUE)
units <- if (length(args) && !grepl("^--", args[1])) as.integer(trimws(unlist(strsplit(args[1], ",")))) else CFG$treated_ids
DO_INFER <- !any(args == "--no-placebo")

## ── Run folder (unique ID: time to the second + settings/input/code hash + random suffix; stops if it exists) ───────────
code_files <- file.path(HERE, c("config_v4.R", "scm_v4_functions.R", "scm_v4_plots.R", "run_scm_v4.R"))
hash <- cfg_hash(CFG, code_files, units, DO_INFER)
run_id <- sprintf("%s_%s_%s_%s", CFG$run_tag, format(Sys.time(), "%Y%m%d-%H%M%S"), hash, paste(sample(c(letters, 0:9), 4, TRUE), collapse = ""))
run_dir <- file.path(path.expand(CFG$out_root), run_id)
if (dir.exists(run_dir)) stop("Run folder already exists: ", run_dir)
dir.create(run_dir, recursive = TRUE)
logf <- file.path(run_dir, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }
logmsg("[run] ", run_dir); logmsg("[method] ", CFG$method)

## ── Data ───────────────────────────────────────────────────────────────
df <- load_panel(CFG, logmsg)
preds <- active_predictors(CFG, df)
logmsg("[pred] Common predictors: ", CFG$n_blocks, " traffic blocks + ", paste(vapply(preds, function(p) sprintf("%s(%s)", p$var, p$op), ""), collapse = ", "))
write_json(list(run_id = run_id, config = CFG, hash = hash, started = format(Sys.time()), units = units, infer = DO_INFER,
                predictors_used = vapply(preds, function(p) sprintf("%s(%s)", p$var, p$op), ""),
                input_md5 = list(panel = file_md5(CFG$panel_csv), pop = file_md5(CFG$pop_csv)),
                code_md5 = setNames(as.list(vapply(code_files, file_md5, "")), basename(code_files)),
                r_version = R.version.string, synth_version = as.character(packageVersion("Synth"))),
           file.path(run_dir, "run_info.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
t_policy <- min(CFG$post_main)
all_treated <- df %>% filter(is_treat %in% c(TRUE, "TRUE")) %>% distinct(unit_id_num) %>% pull(unit_id_num)
## Observation completeness per analysis window: main table (pre ∪ post_main) / full (pre ∪ post_full) — donor pool also per window
need_idx <- list(main = c(CFG$pre_idx, CFG$post_main), full = c(CFG$pre_idx, CFG$post_full))
donors_by <- lapply(need_idx, function(ix) donor_pool(CFG, df, all_treated, ix, logmsg))
for (pw in names(donors_by))
  write_csv(data.frame(unit_id_num = donors_by[[pw]]) %>% left_join(df %>% distinct(unit_id_num, unit_name_en, region_kr), by = "unit_id_num"),
            file.path(run_dir, sprintf("donor_pool_%s.csv", pw)))
donors <- donors_by$main
write_csv(data.frame(unit_id_num = CFG$donor_exclude, reason = CFG$donor_exclude_reason[as.character(CFG$donor_exclude)]),
          file.path(run_dir, "donor_excluded.csv"))

## ── Estimation by site ─────────────────────────────────────────────────
summary_rows <- list()
for (u in units) {
  u_dir <- file.path(run_dir, sprintf("unit_%02d", u)); dir.create(u_dir, showWarnings = FALSE)
  nm <- df$unit_name_en[df$unit_id_num == u][1]
  r1 <- df[df$unit_id_num == u, ][1, ]; rl <- paste0(r1$road_en, " ", ifelse(as.integer(r1$direction) == 1, "NB", "SB"))   # plot title (canonical convention)
  pdir <- file.path(run_dir, "plots", sprintf("%02d", u))
  logmsg(sprintf("===== unit %d: %s =====", u, nm))
  tr_ok <- vapply(need_idx, function(ix) { x <- df$traffic[df$unit_id_num == u & df$week_index %in% ix]; length(x) == length(ix) && all(is.finite(x)) }, logical(1))
  if (!tr_ok[["main"]]) { logmsg("  Treated outcome incomplete in the main-table window (weeks 1–", max(CFG$post_main), ") → skipped"); next }
  if (!tr_ok[["full"]]) logmsg("  Treated outcome incomplete in the full window (weeks 1–", max(CFG$post_full), ") → only the full-period analysis is skipped")
  main_fit <- NULL; full_fit <- NULL
  ## Donor pre-screening (pre-treatment data only). Same rule applied to each window's pool
  scr <- screen_donors(CFG, df, u, donors_by$main)
  write_csv(scr$table, file.path(u_dir, "donor_screen.csv"))
  donors_u <- list(main = scr$keep, full = intersect(scr$keep, donors_by$full))
  logmsg(sprintf("  Donor screening: %d → %d (%d pass level, %d pass trend%s)", nrow(scr$table), length(scr$keep),
                 sum(scr$table$pass_level), sum(scr$table$pass_trend), if (any(scr$table$relaxed)) ", relaxation applied" else ""))
  preds_u <- preds; v_fixed_u <- NULL; cv_sel <- NULL
  if (identical(CFG$method, "cv")) {                           # (combination × K) out-of-sample selection → specification fixed
    cv_sel <- cv_select(CFG, df, u, donors_u$main, logmsg)
    write_csv(cv_sel$grid, file.path(u_dir, "cv_grid.csv"))
    write_csv(data.frame(treated_unit = u, combo = cv_sel$combo, K = cv_sel$K, final_v = CFG$cv$final_v,
                         donors = paste(cv_sel$donors, collapse = ",")), file.path(u_dir, "cv_selection.csv"))
    preds_u <- cv_sel$preds; donors_u <- list(main = cv_sel$donors, full = intersect(cv_sel$donors, donors_by$full))
    if (identical(CFG$cv$final_v, "fixed")) v_fixed_u <- cv_sel$v
  }

  for (pw in c("main", "full")) {
    if (!tr_ok[[pw]]) next
    post_idx <- if (pw == "main") CFG$post_main else CFG$post_full
    fit <- fit_two_step(CFG, df, preds_u, u, donors_u[[pw]], post_idx = post_idx, v_fixed = v_fixed_u)
    m <- fit$metrics
    logmsg(sprintf("  [%s] ATT %+.1f (%+.2f%%) | ratio %.2f | V-sel RMSPE %.1f | final late %.1f / early %.1f / pre %.1f | max w %.2f",
                pw, m$att_abs, m$att_pct, m$rmspe_ratio, m$v_selection_rmspe, m$final_pre_late_rmspe, m$final_pre_early_rmspe, m$final_pre_rmspe, m$max_w))
    write_csv(fit$path, file.path(u_dir, sprintf("path_%s.csv", pw)))
    write_csv(data.frame(treated_unit = u, post_window = pw, n_post = length(post_idx), as.data.frame(m)), file.path(u_dir, sprintf("summary_%s.csv", pw)))
    if (pw == "main") {
      dg <- diagnostics(CFG, fit, df, preds_u)
      write_csv(dg$weights, file.path(u_dir, if (identical(CFG$method, "stdv")) "weights.csv" else "weights_stage1_vs_final.csv"))
      write_csv(data.frame(predictor = rownames(fit$dp2$X1), v_weight = fit$v), file.path(u_dir, "v_weights.csv"))   # names taken from the X matrix
      write_csv(dg$balance, file.path(u_dir, "covariate_balance.csv"))
      if (nrow(dg$cov_change)) write_csv(dg$cov_change, file.path(u_dir, "covariate_window_change.csv"))
      write_csv(dg$flags, file.path(u_dir, "diagnostic_flags.csv"))
      if (any(dg$flags$triggered)) logmsg("  [diagnostic warning] ", paste(dg$flags$flag[dg$flags$triggered], collapse = ", "), " — model not changed; cause needs review")
      main_fit <- fit; main_row <- length(summary_rows) + 1
    } else full_fit <- fit
    summary_rows[[length(summary_rows) + 1]] <- data.frame(treated_unit = u, name = nm, post_window = pw, n_donors = length(donors_u[[pw]]), predictors = paste(vapply(preds_u, function(p) sprintf("%s(%s)", p$var, p$op), ""), collapse = ";"), cv_combo = if (is.null(cv_sel)) NA else cv_sel$combo, cv_K = if (is.null(cv_sel)) NA else cv_sel$K, as.data.frame(m))
  }

  if (DO_INFER && !is.null(main_fit)) {
    logmsg("  placebo in space (", length(donors_u$main), ") …")
    pl <- placebo_in_space(CFG, df, preds_u, u, donors_u$main, v_fixed = if (identical(CFG$method, "cv") && identical(CFG$cv$placebo_v, "treated")) v_fixed_u else NULL)
    write_csv(pl$res, file.path(u_dir, "placebo_results.csv")); write_csv(pl$paths, file.path(u_dir, "placebo_paths.csv"))
    pv <- placebo_pvals(CFG, pl$res, main_fit$metrics); write_csv(pv, file.path(u_dir, "placebo_pvals.csv"))
    logmsg("  p(ratio) tau=5: ", sprintf("%.3f (n=%d)", pv$p_ratio[pv$tau == 5], pv$n_placebo[pv$tau == 5]))
    if (tr_ok[["full"]] && !is.null(full_fit)) {                       # full 50-week window placebo (donor pool = full)
      logmsg("  placebo in space, full window (", length(donors_u$full), ") …")
      plf <- placebo_in_space(CFG, df, preds_u, u, donors_u$full, post_idx = CFG$post_full, v_fixed = if (identical(CFG$method, "cv") && identical(CFG$cv$placebo_v, "treated")) v_fixed_u else NULL)
      write_csv(plf$res, file.path(u_dir, "placebo_results_full.csv"))
      pvf <- placebo_pvals(CFG, plf$res, full_fit$metrics); write_csv(pvf, file.path(u_dir, "placebo_pvals_full.csv"))
      logmsg("  p(ratio) tau=5, full: ", sprintf("%.3f (n=%d)", pvf$p_ratio[pvf$tau == 5], pvf$n_placebo[pvf$tau == 5]))
      summary_rows[[main_row + 1]]$p_ratio_tau5 <- pvf$p_ratio[pvf$tau == 5]; summary_rows[[main_row + 1]]$n_placebo_tau5 <- pvf$n_placebo[pvf$tau == 5]
    }
    logmsg("  LOO (", sum(main_fit$w2 > CFG$loo_min_w), " donors, ", CFG$loo_mode, ") …")
    lo <- loo_refit(CFG, df, preds_u, main_fit)
    if (nrow(lo$res)) { write_csv(lo$res, file.path(u_dir, "loo.csv")); write_csv(lo$paths, file.path(u_dir, "loo_paths.csv"))
      logmsg(sprintf("  LOO ATT%% range [%+.2f, %+.2f]", min(lo$res$att_pct), max(lo$res$att_pct))) }
    logmsg("  in-time placebo …")
    it <- in_time_placebo(CFG, df, preds_u, u, donors_u$main)
    if (nrow(it$res)) { write_csv(it$res, file.path(u_dir, "in_time.csv")); write_csv(it$paths, file.path(u_dir, "in_time_paths.csv"))
      logmsg("  in-time ratios: ", paste(sprintf("%.2f", it$res$fake_ratio), collapse = ", "), " (actual ", sprintf("%.2f", main_fit$metrics$rmspe_ratio), ")") }
    make_unit_plots(CFG, u, rl, main_fit, pl = pl, lo_paths = lo$paths, it_paths = it$paths, pdir = pdir)
    summary_rows[[main_row]]$p_ratio_tau5 <- pv$p_ratio[pv$tau == 5]
    summary_rows[[main_row]]$n_placebo_tau5 <- pv$n_placebo[pv$tau == 5]
  } else if (!is.null(main_fit)) make_unit_plots(CFG, u, rl, main_fit, pdir = pdir)   # --no-placebo: path · gap only
}
summ <- bind_rows(summary_rows)
write_csv(summ, file.path(run_dir, "all_units_summary.csv"))
logmsg("[done] ", nrow(summ), " rows → ", file.path(run_dir, "all_units_summary.csv"))
