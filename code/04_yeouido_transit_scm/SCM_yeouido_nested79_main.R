## SCM_yeouido_nested79_main.R — Yeouido transit SCM, main specification (79 donors), all outputs (2026-11-03)
## Change to the main specification: donors 81 -> 79. Excluded: 55 Geumgwang-dong (Jungwon-gu, Seongnam) -> Seoul (Line 8 Seongnam section,
##   card usable from 2024-01-27), 23 Haan-dong (Gwangmyeong) -> Seoul (Line 7 Cheolsan station, within the Onsu-Jangam range).
##   Gyeonggi-bound OD flows (54, 56, 22) are kept because their exposure is weak.
## Method: runs the setup, data, fit-fn, main-fit, plot-helpers, plot-path-gap, loo-plots and intime-plots chunks of the Rmd
##   (SCM_yeouido_nested_full_pre.Rmd) as they are, but drops the two OD flows from donor_ids and renames the output folder/files to D79
##   (the Rmd itself is not modified).
##   In-space placebos are run separately following Abadie et al. (2015): only the placebo unit is removed and the treated OD is
##   included as a donor, no filter (excluding > 5x pre-RMSPE is a sensitivity check); if the default optimiser fails,
##   optimxmethod = "All" -> genoud. Placebo paths are also saved and plotted.
## Output: OUT_DIR (default output/04_yeouido_transit_scm/SCM_yeouido_nested79/, + plots/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested79_main.R   (about 25 min; on macOS optionally prefix with caffeinate -i)
## RESTRICTED DATA REQUIRED (restricted data required): smart-card OD data (Data Safety Center, export-restricted) are not in this repository.
## Required input files (place under RAW_DIR):
##   - od_with_pop_sum_without_holiday.csv
##   - df_scm_g.csv
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_yeouido_nested79"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## The Rmd setup chunk keeps REPO_ROOT, RAW_DIR and OUT_DIR above if they are already defined (HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- c(23L, 55L)
rmd <- file.path(CODE_DIR, "SCM_yeouido_nested_full_pre.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")   # not named L: the loo-plots chunk would overwrite a variable called L
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; x <- RMD_LINES[(s + 1):(e - 1)]
  x <- gsub("D81_nested", "D79_nested", x, fixed = TRUE); x }            # relabel file names to D79
run <- function(label) eval(parse(text = chunk(label), encoding = "UTF-8"), envir = globalenv())
## setup: output folder is OUT_DIR above (the gsub below also changes the Rmd default folder name to nested79)
su <- chunk("setup"); su <- gsub('"SCM_yeouido_nested")', '"SCM_yeouido_nested79")', su, fixed = TRUE); stopifnot(any(grepl("SCM_yeouido_nested79", su)))   # OUT_DIR is already defined, so files are actually written to OUT_DIR; this substitution is kept for the Rmd default (used when OUT_DIR is undefined)
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv())
run("data")
donor_ids <- setdiff(donor_ids, EXCL); stopifnot(length(donor_ids) == 79)
cat("donors", length(donor_ids), "| excluded", paste(EXCL, collapse = ","), "| output", HERE, "\n")
## fit function: original + optimiser options can be passed (identical to the original when SYNTH_OPT is an empty list)
ff <- chunk("fit-fn"); target <- "Synth::synth(data.prep.obj = dp, verbose = FALSE)"; stopifnot(sum(grepl(target, ff, fixed = TRUE)) == 1)
ff <- gsub(target, "do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE), SYNTH_OPT))", ff, fixed = TRUE)
SYNTH_OPT <- list(); eval(parse(text = ff, encoding = "UTF-8"), envir = globalenv())
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
fit_try <- function(tid, ctrl, ...) { for (nm in names(OPTS)) { SYNTH_OPT <<- OPTS[[nm]]
  f <- tryCatch(fit_nested(tid, ctrl, ...), error = function(e) NULL); if (!is.null(f)) { SYNTH_OPT <<- list(); f$optimizer <- nm; return(f) } }
  SYNTH_OPT <<- list(); NULL }

run("main-fit")                                     # M, w_tbl, v_tbl, path_tbl, M_nested.rds (saved under D79 names)
cf <- function(f, idx = post_idx) { q <- f$t %in% idx; 100 * sum(f$gap[q]) / sum(f$Y0[q]) }
cat(sprintf("main spec (79 donors): ATT %.1f | vs counterfactual %.2f%% | pre RMSPE %.1f | ratio %.3f\n", M$att, cf(M), M$pre, M$ratio))
## Predictor balance table (for Tables 4-2 and 4-3): treated, synthetic control, simple donor mean
X1 <- as.numeric(M$dp$X1); X0 <- M$dp$X0; w <- as.numeric(M$so$solution.w)
bal <- data.frame(predictor = rownames(M$dp$X1), treated = X1, synthetic = as.numeric(X0 %*% w), donor_mean = rowMeans(X0), V = M$v)
write.csv(bal, file.path(HERE, "predictor_means_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(bal, digits = 4)

run("plot-helpers"); run("plot-path-gap")

## In-space placebos — Abadie et al. (2015)
plc <- list(); plc_paths <- list(); fails <- c(); t0 <- Sys.time()
for (pid in donor_ids) {
  ctrl <- c(setdiff(donor_ids, pid), treat_id); f <- fit_try(pid, ctrl)
  if (is.null(f)) { fails <- c(fails, pid); message("  placebo failed ", pid); next }
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
## Placebo plots: make the "(tau = %d)" in titles work for Inf as well
ph <- chunk("plot-helpers")
ph <- gsub("(tau = %d)\", tau)", "(%s)\", if (is.infinite(tau)) \"all placebos\" else paste0(\"tau = \", tau))", ph, fixed = TRUE)
ph <- gsub("(tau = %d)\", legend_lbl2, tau)", "(%s)\", legend_lbl2, if (is.infinite(tau)) \"all placebos\" else paste0(\"tau = \", tau))", ph, fixed = TRUE)
ph <- gsub("MSPE", "RMSPE", gsub("RMSPE", "MSPE", ph, fixed = TRUE), fixed = TRUE)      # rename the statistic to RMSPE (the values are RMSPE ratios)
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

run("loo-plots")      # saves both V·W re-estimated (revise, main text) and V fixed (reference)
lo <- read.csv(file.path(HERE, "loo_sensitivity_D79_nested.csv")); A <- mean(M$Y1[M$t %in% post_idx])
lo$cf_pct <- 100 * lo$ATT / (A - lo$ATT); write.csv(lo, file.path(HERE, "loo_sensitivity_D79_nested_cf.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("LOO (V·W re-estimated), %d runs: vs counterfactual %.2f to %.2f%%\n", nrow(lo), min(lo$cf_pct), max(lo$cf_pct)))
run("intime-plots")
cat("[done]", HERE, "\n")
