## SCM_yeouido_adhcv79.R — Yeouido transit SCM, alternative specification: V chosen by training/validation (Abadie et al. 2015), 79 donors (2026-11-03)
## The V-selection procedure is the same as in the earlier alternative-specification script (an archived, read-only script not included here):
##   the 49 pre-treatment weeks are split into the first 25 (training) and last 24 (validation) -> step 1: build the synthetic control from
##   training-window predictors (covariates + 5 block means over the training window) and pick the V* that minimises the outcome
##   prediction error over the validation window -> step 2: fix V* and fit the final W on predictors over all 49 pre weeks (5 block means).
## Changes: (1) 79 donors (excluding 55 Geumgwang-dong -> Seoul and 23 Haan-dong -> Seoul, same as the main specification)
##          (2) placebos: Abadie et al. (2015) — only the placebo unit is removed and the treated OD is included as a donor; each placebo
##              uses the same two-step procedure; no filter (excluding > 5x pre-RMSPE is a sensitivity check)
##          (3) LOO: drop each positive-weight donor in turn and re-estimate the whole two-step procedure (V* and W)
##          (4) optimiser: at each step, if the default fails, optimxmethod = "All" -> genoud (the method used is recorded)
## Panel: the setup and data chunks of the main-specification Rmd as they are (same data, same weeks).
## Output: OUT_DIR (default output/04_yeouido_transit_scm/SCM_yeouido_adhcv79/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_yeouido_adhcv79.R   (about 30 min; on macOS optionally prefix with caffeinate -i)
## RESTRICTED DATA REQUIRED (restricted data required): smart-card OD data (Data Safety Center, export-restricted) are not in this repository.
## Required input files (place under RAW_DIR):
##   - od_with_pop_sum_without_holiday.csv
##   - df_scm_g.csv
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_yeouido_adhcv79"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## The Rmd setup chunk keeps REPO_ROOT, RAW_DIR and OUT_DIR above if they are already defined (HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- c(23L, 55L)
rmd <- file.path(CODE_DIR, "SCM_yeouido_nested_full_pre.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; RMD_LINES[(s + 1):(e - 1)] }
su <- gsub('"SCM_yeouido_nested")', '"SCM_yeouido_adhcv79")', chunk("setup"), fixed = TRUE)   # OUT_DIR is already defined, so files are actually written to OUT_DIR; this substitution is kept for the Rmd default (used when OUT_DIR is undefined)
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv()); eval(parse(text = chunk("data"), encoding = "UTF-8"), envir = globalenv())
donor_ids <- setdiff(donor_ids, EXCL); stopifnot(length(donor_ids) == 79)
logf <- file.path(HERE, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }

n_fit <- ceiling(n_pre / 2); fit_idx <- final_pre_idx[seq_len(n_fit)]; valid_idx <- setdiff(final_pre_idx, fit_idx)
logmsg(sprintf("donors %d | training %d weeks (%d-%d) / validation %d weeks (%d-%d)", length(donor_ids), length(fit_idx), min(fit_idx), max(fit_idx), length(valid_idx), min(valid_idx), max(valid_idx)))
sp_make <- function(idx, n_blocks = N_SP_BLOCK, dep = "users") { ed <- round(seq(0, length(idx), length.out = n_blocks + 1))
  lapply(seq_len(n_blocks), function(b) list(dep, as.integer(idx[(ed[b] + 1):ed[b + 1]]), "mean")) }
sp_fit <- sp_make(fit_idx); sp_full <- sp_make(final_pre_idx)
.dp <- function(tid, ctrl, sp, prior, ssr, tplot) Synth::dataprep(foo = df_scm, predictors = PREDS, predictors.op = "mean",
  special.predictors = sp, dependent = "users", unit.variable = "unit_id_num", unit.names.variable = "unit_name_en", time.variable = "week_index",
  treatment.identifier = as.integer(tid), controls.identifier = sort(as.integer(ctrl)), time.predictors.prior = prior, time.optimize.ssr = ssr, time.plot = tplot)
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
synth_try <- function(dp, ...) { for (nm in names(OPTS)) {
  so <- tryCatch({ invisible(utils::capture.output(o <- do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE, ...), OPTS[[nm]])))); o }, error = function(e) NULL)
  if (!is.null(so)) { so$optimizer <- nm; return(so) } }; stop("synth failed (all optimiser methods)") }
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

## Main estimate
M <- fit_cv(treat_id, donor_ids)
logmsg(sprintf("training/validation V (79 donors): ATT %.1f | vs counterfactual %.2f%% | pre RMSPE %.1f | ratio %.3f | optimiser %s", M$att, M$cf_pct, M$pre, M$ratio, M$optimizer))
w_tbl <- data.frame(unit_id_num = sort(as.integer(donor_ids)), weight = as.numeric(M$so$solution.w)) %>%
  left_join(df_scm %>% distinct(unit_id_num, unit_name), by = "unit_id_num") %>% arrange(desc(weight))
write.csv(w_tbl, file.path(HERE, "weights_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(head(w_tbl, 8))
write.csv(data.frame(predictor = rownames(M$dp$X1), V = M$v), file.path(HERE, "vweights_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(data.frame(week_index = M$t, period = ifelse(M$t %in% final_pre_idx, "pre", "post"), actual = M$Y1, synthetic = M$Y0, gap = M$gap),
          file.path(HERE, "path_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")

## Placebos — Abadie et al. (2015)
plc <- list(); paths <- list(); fails <- c(); t0 <- Sys.time()
for (pid in donor_ids) {
  ctrl <- c(setdiff(donor_ids, pid), treat_id); f <- tryCatch(fit_cv(pid, ctrl), error = function(e) NULL)
  if (is.null(f)) { fails <- c(fails, pid); logmsg("  placebo failed ", pid); next }
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

## LOO — re-estimate the whole two-step procedure
targets <- w_tbl$unit_id_num[w_tbl$weight > 0.001]
lo <- do.call(rbind, lapply(targets, function(d) { f <- tryCatch(fit_cv(treat_id, setdiff(donor_ids, d)), error = function(e) NULL); if (is.null(f)) return(NULL)
  data.frame(omitted = d, w_omitted = w_tbl$weight[w_tbl$unit_id_num == d], pre = f$pre, ratio = f$ratio, att = f$att, cf_pct = f$cf_pct, optimizer = f$optimizer) }))
write.csv(lo, file.path(HERE, "loo_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8")

summ <- data.frame(spec = "adhcv, 79 donors", att = M$att, cf_pct = M$cf_pct, pre_rmspe = M$pre, valid_rmspe = M$valid_rmspe, ratio = M$ratio,
                   rank_all = pv$rank[1], p_all = pv$p_ratio[1], p_tau5 = pv$p_ratio[2], loo_n = nrow(lo), loo_min = min(lo$cf_pct), loo_max = max(lo$cf_pct))
write.csv(summ, file.path(HERE, "summary_D79_adhcv.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(summ)
logmsg("[done] ", HERE)
