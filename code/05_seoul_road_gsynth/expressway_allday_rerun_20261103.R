## expressway_allday_rerun_20261103.R — recomputes the paths for SI Appendix D (all-day traffic SCM for nine Seoul urban expressways) (2026-11-03)
## Original analyses: R Markdown files from 2025-06 (scm/final/*.Rmd; Naebu Circular in scm/inner*.Rmd) — not in this repository.
## Original data: Thesis_Materials/pre_processed/all_combined_with_info.csv (road-level, both directions, weekly, 2023-02-04 to 2025-03-29; treated 1–9, donors 10–74) — not in this repository.
## Method: reads each Rmd unchanged, replaces only the data path with ARCH, and runs the chunks in order up to the chunk containing 'so_refined <- synth'
##         (original specification: predictors, special predictors, donors and indexing as defined in each Rmd). Chunks that error (e.g. font downloads) are skipped.
##         → saves treated and synthetic paths, pre-RMSPE (original units) and RMSPE ratio, and compares them with SI Table D-1.
## INPUT DATA (not in the repository): set ARCH to the folder that holds Thesis_Materials (scm/ and pre_processed/).
## Output: OUT_DIR (default output/05_seoul_road_gsynth/expressway_allday_20261103/): path_<file>.csv, summary.csv
##         Published copy: results/05_seoul_road_gsynth/expressway_allday_scm/
## Run (from repo root, serial): ARCH=/path/to/Thesis_Materials Rscript code/05_seoul_road_gsynth/expressway_allday_rerun_20261103.R
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")
ARCH <- Sys.getenv("ARCH", file.path(REPO_ROOT, "data/restricted/Thesis_Materials"))
OUT <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "05_seoul_road_gsynth", "expressway_allday_20261103")); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
files <- c(file.path(ARCH, "scm/final", c("bukbu", "bundang", "bundang_2", "dongbu", "dongbu_2", "gangbyeon", "gangbyeon_2",
                                           "gangnam", "gangnam2", "gyeongbu", "olympic", "seobu", "seobu_2")),
           file.path(ARCH, "scm", c("inner_f", "inner", "inner2")))
files <- paste0(files, ".Rmd"); stopifnot(all(file.exists(files)))
## SI Table D-1 (manuscript): pre-RMSPE (original units) and ratio
D1 <- data.frame(road = c("Bukbu", "Bundang-Suseo", "Dongbu", "Gangbyeonbuk-ro", "Gangnam Circular", "Gyeongbu", "Naebu Circular", "Olympic-daero", "Seobu"),
                 treat_id = 1:9, D1_pre_rmspe = c(2078, 2301, 2348, 4088, 1950, 2935, 2410, 3446, 918),
                 D1_ratio = c(1.85, 1.09, 1.88, 1.90, 2.51, 1.37, 2.04, 1.89, 1.76))
run_one <- function(f) {
  src <- readLines(f, warn = FALSE, encoding = "UTF-8")
  src <- gsub("/Users/maeg/Downloads/Thesis_Materials", ARCH, src, fixed = TRUE)   # literal data path inside the original Rmds
  st <- grep("^```\\{r", src); en <- which(trimws(src) == "```")
  stop_i <- which(sapply(st, function(s) { e <- min(en[en > s]); any(grepl("so_refined\\s*<-\\s*synth", src[s:e])) }))[1]
  if (is.na(stop_i)) return(NULL)
  env <- new.env(parent = globalenv())
  for (i in seq_len(stop_i)) { s <- st[i]; e <- min(en[en > s]); code <- paste(src[(s + 1):(e - 1)], collapse = "\n")
    r <- tryCatch({ eval(parse(text = code, encoding = "UTF-8"), envir = env); "ok" }, error = function(err) conditionMessage(err))
    if (r != "ok") cat(sprintf("  [%s] chunk %d error (skipped): %s\n", basename(f), i, substr(r, 1, 120))) }
  if (!exists("so_refined", envir = env)) return(NULL)
  dp <- get("dp_refined", envir = env); so <- get("so_refined", envir = env); n_pre <- get("n_pre", envir = env); tid <- get("treat_id", envir = env)
  Y1 <- as.numeric(dp$Y1plot); Y0 <- as.numeric(dp$Y0plot %*% so$solution.w); t <- dp$tag$time.plot; g <- Y1 - Y0
  pre <- t <= n_pre; post <- !pre
  dfs <- get("df_scm", envir = env); raw_pre_mean <- mean(dfs$traffic[dfs$unit_id == tid & dfs$week_index <= n_pre], na.rm = TRUE)
  indexed <- abs(mean(Y1[pre]) - 100) < 5                    # indexed specifications have a pretreatment mean near 100
  scale <- if (indexed) raw_pre_mean / 100 else 1
  write.csv(data.frame(week_index = t, treated = Y1, synthetic = Y0, gap = g, indexed = indexed),
            file.path(OUT, sprintf("path_%s.csv", sub("\\.Rmd$", "", basename(f)))), row.names = FALSE)
  data.frame(file = basename(f), treat_id = tid, indexed = indexed, n_pre = n_pre, n_all = length(t), n_donors = length(dp$tag$controls.identifier),
             pre_rmspe_orig = sqrt(mean(g[pre]^2)) * scale, ratio = sqrt(mean(g[post]^2)) / sqrt(mean(g[pre]^2)),
             att_pct_of_synth = 100 * mean(g[post]) / mean(Y0[post]))
}
R <- do.call(rbind, lapply(files, function(f) { cat("==", basename(f), format(Sys.time(), "%H:%M:%S"), "\n")
  tryCatch(run_one(f), error = function(e) { cat("  failed:", conditionMessage(e), "\n"); NULL }) }))
R <- merge(R, D1, by = "treat_id", all.x = TRUE)
R$match <- abs(R$pre_rmspe_orig - R$D1_pre_rmspe) / R$D1_pre_rmspe < 0.03 & abs(R$ratio - R$D1_ratio) < 0.03
print(R[, c("file", "road", "indexed", "n_all", "n_donors", "pre_rmspe_orig", "D1_pre_rmspe", "ratio", "D1_ratio", "match")], digits = 4, row.names = FALSE)
write.csv(R, file.path(OUT, "summary.csv"), row.names = FALSE)
