## build_panel_6to9_sum.R — builds the 06:00–09:59 panel with outcome = hourly sum → daily sum → weekly mean (for the sum sensitivity check)
## Runs the two Rmds of the canonical 06–09 median pipeline (road6to9_new_try) after patching their text. The original Rmds/folder are not modified.
##   1) Panel Rmd: daily aggregation median → sum (only days with all 4 hours observed), weekly aggregation median → mean. Output under panel_sum/.
##   2) SCM Rmd §0–4: attach covariates · reassign ids → panel_sum/77_units/0628_6to10_df_with_new_covariates_fixed.csv
##      (specification selection / batch runs are not executed. Unit ids follow the same lookup rule as the canonical 6to9 panel, so they must be identical; checked below)
## Run (from repo root): Rscript code/03_road_scm/build_panel_6to9_sum.R 2>&1 | tee build_panel_6to9_sum.log
## Then: set panel_csv in config_v4.R to OUT_DIR/panel_sum/77_units/…fixed.csv and run_tag to "v4_stdv_sum", and run run_scm_v4.R
##       (run_scm_v4.R: code/03_road_scm/run_scm_v4.R)
## RESTRICTED DATA REQUIRED (restricted data required): road detector inputs (Seoul TOPIS sites and national ITS link counts) are not redistributed (licence pending).
## Required input files (place under RAW_DIR; = the original "road6to9_new_try" pipeline folder, NOT in this repo):
##   - 0629_roads_6to9_day.median_week.median.Rmd                                  (original panel Rmd, patched in memory)
##   - scm_analysis_6to10_day.median_week.median_without_pre_traffic_cov.Rmd       (original SCM Rmd, §0–4 run)
##   - 77_units/0628_6to10_df_with_new_covariates_fixed.csv                        (canonical median panel, for the unit-id check)
##   - plus the raw detector/covariate files those two Rmds read themselves (paths are set inside the Rmds)
suppressMessages(library(knitr))
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # non-redistributed road inputs
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "03_road_scm"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "03_road_scm")
SRC  <- normalizePath(RAW_DIR, winslash = "/", mustWork = FALSE)                 # original pipeline folder (Rmds + 77_units/)
OUT  <- file.path(OUT_DIR, "panel_sum")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
OUT  <- normalizePath(OUT, winslash = "/", mustWork = TRUE)                       # absolute: script setwd()s into OUT below and embeds OUT in patched code
PANEL_CSV <- file.path(OUT, "0629_6to9_day.sum_week.mean.csv")

## ── 1) Panel ──────────────────────────────────────────────────────────
rmd1 <- file.path(SRC, "0629_roads_6to9_day.median_week.median.Rmd")
src <- readLines(rmd1, warn = FALSE)
## NOTE: the first (`from`) argument of every patch() call below, and the first argument of sub() in pt(), is a LITERAL
## search string that must match the text of the original external Rmds (0629_roads_6to9_day.median_week.median.Rmd /
## scm_analysis_6to10_day.median_week.median_without_pre_traffic_cov.Rmd; not in this repo). The home-directory paths in
## those strings are the original author's paths as written in those Rmds — do NOT edit them, or the patch fails.
## Only the replacement targets (PANEL_CSV, OUT) are ours.
patch <- function(src, from, to, n = 1) {
  i <- grep(from, src, fixed = TRUE); if (length(i) != n) stop("Patch failed (", length(i), " matches): ", from); src[i] <- sub(from, to, src[i], fixed = TRUE); src }
src <- patch(src, 'OUT_FILE  <- "~/Thesis/0614/0628/road6to9_new_try/0629_6to10_day.median_week.median.csv"',
                  sprintf('OUT_FILE  <- "%s"', PANEL_CSV))
src <- patch(src, 'traffic = if_else(n_obs >= 1, median(traffic, na.rm = TRUE), NA_real_),',
                  'traffic = if_else(n_obs >= 4, sum(traffic, na.rm = TRUE), NA_real_),      # [sum] sum only on days with all 4 hours (06–09) observed')
src <- patch(src, 'med_traffic     = safe_median(traffic),    # 주 median',   # protected literal from the original Rmd (its Korean comment means "weekly median")
                  'med_traffic     = mean(traffic, na.rm = TRUE),    # [sum] weekly mean (column name kept for compatibility)')
src <- patch(src, 'write.csv(weekly_dir1, "~/Thesis/0614/0628/road6to9_new_try/weekly_weekly_dir.csv"',
                  sprintf('write.csv(weekly_dir1, "%s/weekly_weekly_dir.csv"', OUT))
tmp1 <- file.path(OUT, "_panel_6to9_sum.Rmd"); writeLines(src, tmp1)
r1 <- file.path(OUT, "_panel_6to9_sum.R"); knitr::purl(tmp1, output = r1, quiet = TRUE)
if (!file.exists(PANEL_CSV)) {
  cat("\n[1] Building panel →", PANEL_CSV, "\n")
  setwd(OUT)                                   # unit_lookup.csv and units_list.csv are written to the cwd → protects the original folder
  source(r1, echo = FALSE, local = globalenv())
  stopifnot(file.exists(PANEL_CSV))
} else cat("\n[1] Panel CSV exists → skipping\n")

## ── 2) Attach covariates (SCM Rmd §0–4) ─────────────────────────────────
rmd2 <- file.path(SRC, "scm_analysis_6to10_day.median_week.median_without_pre_traffic_cov.Rmd")
s2 <- readLines(rmd2, warn = FALSE)
starts <- grep("^```\\{r", s2); ends <- which(trimws(s2) == "```")
lab <- sub("^```\\{r *([^,} ]*).*$", "\\1", s2[starts])
blk <- function(i) { s <- starts[i]; e <- min(ends[ends > s]); paste(s2[(s + 1):(e - 1)], collapse = "\n") }
run_i <- function(i, code = blk(i)) { cat(sprintf("\n===== chunk %d [%s] =====\n", i, lab[i])); eval(parse(text = code), envir = globalenv()) }
pt <- function(code) {
  code <- sub('read.csv("~/Thesis/0614/0628/road6to9_new_try/0629_6to10_day.median_week.median.csv"', sprintf('read.csv("%s"', PANEL_CSV), code, fixed = TRUE)
  code <- sub('root <- "~/Thesis/0614/0628/road6to9_new_try"', sprintf('root <- "%s"', OUT), code, fixed = TRUE)
  code
}
i_load <- which(lab == "data-load"); i_dir <- which(s2[starts] == "```{r}" & seq_along(starts) > i_load)[2]   # 2nd unnamed chunk = root/dir_name
i_plot <- which(s2[starts] == "```{r}" & seq_along(starts) > i_load)[1]                                          # 1st unnamed chunk = must_to_delete + plotly
i_save <- which(lab == "")[which(lab == "") > which(lab == "covariate-specs")]                                # unnamed chunks after covariate-specs
suppressMessages({ library(dplyr); library(readr); library(readxl); library(tidyr); library(stringr); library(lubridate); library(purrr); library(tibble) })
run_i(i_load, pt(blk(i_load)))
## plotly chunk: run only up to the line defining df_m_f
pc <- strsplit(blk(i_plot), "\n")[[1]]; run_i(i_plot, paste(pc[seq_len(grep("^regions <-", pc)[1] - 1)], collapse = "\n"))
run_i(i_dir, pt(blk(i_dir)))
run_i(i_dir + 1)                                              # donor_list.csv
for (nm in c("vehicle-merge", "safe-helpers", "build-covariates", "unit-ids")) run_i(which(lab == nm))
dir.create("table", showWarnings = FALSE)                     # the id-reassignment chunk saves table/unit_id_remap.csv in the cwd (77_units)
## After covariate-specs: keep ORI → reassign ids → save fixed.csv (validation / best-spec chunks are skipped)
after <- which(seq_along(lab) > which(lab == "best-spec-selection") & lab == "")[1:3]
for (i in after) run_i(i)
FIXED <- file.path(OUT, "77_units", "0628_6to10_df_with_new_covariates_fixed.csv")
stopifnot(file.exists(FIXED))

## ── 3) Unit id check: linkID+direction → unit_id must match the canonical 6to9 panel ─────
a <- unique(read.csv(FIXED)[, c("unit_id", "linkID", "direction")])
b <- unique(read.csv(file.path(SRC, "77_units/0628_6to10_df_with_new_covariates_fixed.csv"))[, c("unit_id", "linkID", "direction")])
m <- merge(a, b, by = c("linkID", "direction"), suffixes = c("_sum", "_med"), all = TRUE)
cat(sprintf("\n[check] units %d (sum) vs %d (median) · common %d · id mismatches %d\n", nrow(a), nrow(b),
            sum(!is.na(m$unit_id_sum) & !is.na(m$unit_id_med)), sum(m$unit_id_sum != m$unit_id_med, na.rm = TRUE)))
if (any(m$unit_id_sum != m$unit_id_med, na.rm = TRUE) || any(is.na(m$unit_id_sum)) || any(is.na(m$unit_id_med))) {
  print(m[is.na(m$unit_id_sum) | is.na(m$unit_id_med) | m$unit_id_sum != m$unit_id_med, ]); stop("Unit ids differ from the canonical panel → donor_exclude must be remapped")
}
cat("\nDONE:", FIXED, "\n")
