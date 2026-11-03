## SCM_yeouido_nested79_intime.R — Yeouido main specification (79 donors): in-time placebos only (2026-11-03)
## SCM_yeouido_nested79_main.R once stopped after LOO, just before the in-time placebos, because of a name clash (variable L) -> this runs
##   only that part. Placebos and LOO are not re-run.
## The Rmd intime-plots chunk as it is (fake dates = 55th/70th/85th percentiles of the pre-period, nested V·W re-estimated)
##   + an added MSPE-ratio column (= RMSPE ratio squared).
## Output: OUT_DIR (default output/04_yeouido_transit_scm/SCM_yeouido_nested79/, + plots/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested79_intime.R
## RESTRICTED DATA REQUIRED (restricted data required): smart-card OD data (Data Safety Center, export-restricted) are not in this repository.
## Required input files (place under RAW_DIR):
##   - od_with_pop_sum_without_holiday.csv
##   - df_scm_g.csv
##   - (from SCM_yeouido_nested79_main.R, in OUT_DIR) M_nested.rds
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_yeouido_nested79"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## The Rmd setup chunk keeps REPO_ROOT, RAW_DIR and OUT_DIR above if they are already defined (HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- c(23L, 55L)
rmd <- file.path(CODE_DIR, "SCM_yeouido_nested_full_pre.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; gsub("D81_nested", "D79_nested", RMD_LINES[(s + 1):(e - 1)], fixed = TRUE) }
su <- gsub('"SCM_yeouido_nested")', '"SCM_yeouido_nested79")', chunk("setup"), fixed = TRUE)   # OUT_DIR is already defined, so files are actually written to OUT_DIR; this substitution is kept for the Rmd default (used when OUT_DIR is undefined)
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv())
for (lab in c("data", "fit-fn")) eval(parse(text = chunk(lab), encoding = "UTF-8"), envir = globalenv())
donor_ids <- setdiff(donor_ids, EXCL); stopifnot(length(donor_ids) == 79)
eval(parse(text = chunk("plot-helpers"), encoding = "UTF-8"), envir = globalenv())
M <- readRDS(file.path(HERE, "M_nested.rds")); stopifnot(abs(M$ratio - 3.267) < 0.01)
eval(parse(text = chunk("intime-plots"), encoding = "UTF-8"), envir = globalenv())
it$mspe_ratio <- it$ratio^2
write.csv(it, file.path(HERE, "in_time_summary_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(it); cat(sprintf("main estimate MSPE ratio %.3f\n", M$ratio^2))
