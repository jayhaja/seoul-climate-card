## SCM_yeouido_nested_optimizer_check.R — check of the optimiser used in the joint V·W estimation (2026-11-03)
## Purpose: when the 5 directly exposed donors are excluded (76 donors) the pre RMSPE worsens from 389 to 459; check whether this is due
##   to the donor exclusion or to a local optimum in the V optimisation.
##   V is not fixed. The nested objective (minimise pre-treatment outcome MSPE) is kept and only Synth's optimiser is changed.
##   default (Nelder-Mead) / optimxmethod = "All" (lowest loss among several optimx methods) / genoud = TRUE (genetic algorithm, then local optimisation)
##   Both 81 donors (main spec) and 76 (excluded). The solution with the lowest pre RMSPE is the better one under the nested criterion.
## Output: OUT_DIR/excl_direct_exposure/optimizer_check_excl_<EXCL>.csv (folder created by SCM_yeouido_nested_excl_exposed.R;
##   OUT_DIR default output/04_yeouido_transit_scm/SCM_yeouido_nested/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested_optimizer_check.R   (a few to ~15 minutes because of genoud; on macOS optionally prefix with caffeinate -i)
## RESTRICTED DATA REQUIRED (restricted data required): smart-card OD data (Data Safety Center, export-restricted) are not in this repository.
## Required input files (place under RAW_DIR):
##   - od_with_pop_sum_without_holiday.csv
##   - df_scm_g.csv
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_yeouido_nested"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## The Rmd setup chunk keeps REPO_ROOT, RAW_DIR and OUT_DIR above if they are already defined (HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- as.integer(strsplit(Sys.getenv("EXCL", "22,23,54,55,56"), ",")[[1]])   # e.g. EXCL=23,55 (Seoul-bound flows only)
rmd <- file.path(CODE_DIR, "SCM_yeouido_nested_full_pre.Rmd"); L <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), L); e <- s + which(grepl("^```\\s*$", L[(s + 1):length(L)]))[1]; L[(s + 1):(e - 1)] }
for (lab in c("setup", "data")) eval(parse(text = chunk(lab), encoding = "UTF-8"), envir = globalenv())
ff <- chunk("fit-fn"); target <- "Synth::synth(data.prep.obj = dp, verbose = FALSE)"; stopifnot(sum(grepl(target, ff, fixed = TRUE)) == 1)
ff <- gsub(target, "do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE), SYNTH_OPT))", ff, fixed = TRUE)
eval(parse(text = ff, encoding = "UTF-8"), envir = globalenv())
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
cf_pct <- function(f) { q <- f$t %in% post_idx; 100 * sum(f$gap[q]) / sum(f$Y0[q]) }
rows <- list()
for (sp in c("81", "excl")) {
  dn <- if (sp == "81") donor_ids else setdiff(donor_ids, EXCL)
  for (nm in names(OPTS)) {
    SYNTH_OPT <- OPTS[[nm]]; set.seed(20261103); t0 <- Sys.time()
    f <- tryCatch(fit_nested(treat_id, dn), error = function(e) { cat(sp, nm, "failed:", conditionMessage(e), "\n"); NULL })
    if (is.null(f)) next
    w <- sort(setNames(as.numeric(f$so$solution.w), sort(as.integer(dn))), decreasing = TRUE)[1:3]
    rows[[length(rows) + 1]] <- data.frame(donors = sp, optimizer = nm, pre_rmspe = f$pre, loss_v = f$so$loss.v, ratio = f$ratio, cf_pct = cf_pct(f),
      top_w = paste(sprintf("%s:%.2f", names(w), w), collapse = " "), secs = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
    print(tail(rows, 1)[[1]], row.names = FALSE)
  }
}
R <- do.call(rbind, rows); print(R, row.names = FALSE)
write.csv(R, file.path(HERE, "excl_direct_exposure", sprintf("optimizer_check_excl_%s.csv", paste(EXCL, collapse = "_"))), row.names = FALSE, fileEncoding = "UTF-8")
