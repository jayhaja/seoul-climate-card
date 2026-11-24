# Origin-cluster bootstrap for the citywide gsynth main model (r = 4; also r = 2). Created 2026-11-17.
# Purpose: the published CI (1.87%, 95% CI 0.93-2.81) resamples OD pairs as independent units. Treated and control
# OD pairs share origin neighbourhoods, so this script resamples ORIGINS (all OD pairs of a drawn origin together)
# and refits the model with the factor number fixed. Destination clustering is not done (only ~5 destination regions).
#
# Settings are copied from gsynth_Mangwol_only_full_20261104/code/estimate.R (args_for): users ~ D + log_pop,
# method gsynth, force two-way, loading.bound none, normalize FALSE, min.T0 5, tol 1e-5, max.iteration 20000,
# CV = FALSE, fixed r. Uses the same local engine (R2_fect_가중CV_도구_20261010.R; requires fect 2.4.7).
# No existing file is modified; all output goes to this folder.
#
# Strata (fixed before seeing any result):
#   seoul   = origins in 서울특별시 (hold all 409 treated OD pairs and their Seoul-origin control pairs)
#   outside = origins outside Seoul (control OD pairs only)
# Within each stratum, origins are drawn with replacement (same number as in the stratum); every OD pair of a drawn
# origin is copied; duplicated copies get new unit_ids. The number of treated OD pairs per draw is NOT fixed at 409.
#
# Validation scheme "od": the same manual loop, resampling OD pairs within treated / control groups (as fect does).
# Its SE for pre_pct should reproduce the published bootstrap SE (~0.48 pp). If not, the loop is wrong.
#
# Run (from a terminal; each fit takes seconds to tens of seconds; B = 1000 per run):
#   cd ~/Documents/thesis_summary/scm_results/gsynth_origin_cluster_boot_20261117
#   caffeinate -i Rscript origin_cluster_boot.R POINT            # step 1: reproduce 362.657 / 1.871213% (and r = 2 point)
#   caffeinate -i Rscript origin_cluster_boot.R BOOT od 4        # step 4: validation (OD resampling)
#   caffeinate -i Rscript origin_cluster_boot.R BOOT origin 4    # main: origin-cluster bootstrap, r = 4
#   caffeinate -i Rscript origin_cluster_boot.R BOOT origin 2    # same for r = 2
#   Rscript origin_cluster_boot.R SUMMARY
# Optional: CORES=4 to run draws in parallel (forked processes); B=200 for a quick trial (official runs use 1000).
# Interrupted runs resume: completed 50-draw chunks are reused.

suppressPackageStartupMessages({library(fect); library(dplyr); library(parallel)})
base <- '/Users/maeg/Documents/thesis_summary'
src  <- file.path(base, 'scm_results/gsynth_Mangwol_only_full_20261104')
out  <- file.path(base, 'scm_results/gsynth_origin_cluster_boot_20261117')
dir.create(out, showWarnings = FALSE, recursive = TRUE)
source(file.path(src, 'code/R2_fect_가중CV_도구_20261010.R'))
engine <- r2_engine()
B      <- as.integer(Sys.getenv('B', '1000'))
CORES  <- as.integer(Sys.getenv('CORES', '1'))
CHUNK  <- 50L
SEED0  <- 20261117L

atomic <- function(x, p) { saveRDS(x, paste0(p, '.tmp')); stopifnot(file.rename(paste0(p, '.tmp'), p)) }
logmsg <- function(...) { m <- paste(format(Sys.time()), ...); cat(m, '\n'); write(m, file.path(out, 'run_log.txt'), append = TRUE) }

## ---- panel and origin map ----
d <- readRDS(file.path(src, 'panel_mangwol.rds'))
d <- as.data.frame(d)
if (!'origin' %in% names(d)) {
  # Fallback: origin from the source OD file used to build the panel (unit_id is the same identifier).
  raw <- read.csv(path.expand('~/Thesis/0614/public.transportation/0702/od_with_pop_sum_without_holiday.csv'),
                  fileEncoding = 'UTF-8', check.names = FALSE)
  map <- distinct(raw[, c('unit_id', 'origin')])
  stopifnot(!any(duplicated(map$unit_id)))
  d <- left_join(d, map, by = 'unit_id')
}
units <- distinct(d[, c('unit_id', 'origin')])
stopifnot(!any(is.na(units$origin)), !any(duplicated(units$unit_id)))
tr_ids <- unique(d$unit_id[d$D == 1])
units$treated <- units$unit_id %in% tr_ids
units$stratum <- ifelse(grepl('^서울특별시', units$origin), 'seoul', 'outside')
stopifnot(length(tr_ids) == 409, all(units$stratum[units$treated] == 'seoul'))
orig_tab <- units %>% group_by(stratum, origin) %>%
  summarise(n_od = n(), n_treated = sum(treated), .groups = 'drop')
write.csv(orig_tab, file.path(out, 'origin_strata.csv'), row.names = FALSE, fileEncoding = 'UTF-8')
rows_by_unit <- split(seq_len(nrow(d)), d$unit_id)

## ---- model ----
args_for <- function(dat, r) {
  a <- r2_args(users ~ D + log_pop, dat, 'none', r, 20000L, 1e-5, 20260731L)
  a$W.agg <- NULL; a$W.est <- NULL; a$W <- NULL; a$normalize <- FALSE; a$min.T0 <- 5L
  a$se <- FALSE; a
}
summ <- function(f) {
  tr <- which(colSums(f$D.dat) > 0); post <- rowSums(f$D.dat) > 0
  gap <- f$Y.dat[post, tr, drop = FALSE] - f$Y.ct[post, tr, drop = FALSE]
  pre_mean <- mean(f$Y.dat[!post, tr, drop = FALSE])
  c(ATT = mean(gap), pre_mean = pre_mean, pre_pct = 100 * mean(gap) / pre_mean,
    n_treated = length(tr), n_units = ncol(f$Y.dat))
}
fit_one <- function(dat, r) {
  run <- tryCatch(r2_fit(engine, args_for(dat, r)), error = function(e) e)
  if (inherits(run, 'error') || is.null(run$fit)) return(c(ATT = NA, pre_mean = NA, pre_pct = NA, n_treated = NA, n_units = NA,
                                       converged = 0, error = 1))
  c(summ(run$fit), converged = as.numeric(isTRUE(run$convergence_ok)), error = 0)
}

## ---- resampling ----
draw_panel <- function(scheme, b) {
  set.seed(SEED0 + b)
  if (scheme == 'origin') {
    pick <- unlist(lapply(split(orig_tab$origin, orig_tab$stratum), function(o) sample(o, length(o), replace = TRUE)))
    ids_list <- lapply(pick, function(o) units$unit_id[units$origin == o])
  } else {  # 'od': OD pairs within treated / control groups
    tr <- units$unit_id[units$treated]; co <- units$unit_id[!units$treated]
    ids_list <- as.list(c(sample(tr, length(tr), replace = TRUE), sample(co, length(co), replace = TRUE)))
  }
  parts <- vector('list', length(ids_list))
  for (k in seq_along(ids_list)) {
    ix <- unlist(rows_by_unit[as.character(ids_list[[k]])], use.names = FALSE)
    p <- d[ix, c('unit_id', 'week_index', 'users', 'D', 'log_pop')]
    p$unit_id <- k * 100000 + p$unit_id   # unique id per drawn copy
    parts[[k]] <- p
  }
  do.call(rbind, parts)
}

mode <- toupper(commandArgs(TRUE)[1])

if (mode == 'POINT') {
  res <- rbind(r4 = fit_one(d, 4L), r2 = fit_one(d, 2L))
  print(res); write.csv(res, file.path(out, 'point_estimates.csv'))
  ok <- abs(res['r4', 'ATT'] - 362.657) < 0.01 && abs(res['r4', 'pre_pct'] - 1.871213) < 1e-4
  logmsg('POINT r4 ATT', round(res['r4', 'ATT'], 4), 'pre_pct', round(res['r4', 'pre_pct'], 6),
         if (ok) 'REPRODUCED' else 'NOT REPRODUCED - stop and check')
  quit(save = 'no')
}

if (mode == 'BOOT') {
  scheme <- tolower(commandArgs(TRUE)[2]); r <- as.integer(commandArgs(TRUE)[3])
  stopifnot(scheme %in% c('origin', 'od'), r %in% 0:5)
  tag <- sprintf('%s_r%d', scheme, r); dir.create(file.path(out, tag), showWarnings = FALSE)
  for (ch in seq_len(ceiling(B / CHUNK))) {
    p <- file.path(out, tag, sprintf('chunk_%02d.rds', ch))
    if (file.exists(p)) { logmsg(tag, 'chunk', ch, 'REUSE'); next }
    bs <- ((ch - 1) * CHUNK + 1):min(ch * CHUNK, B)
    one <- function(b) c(b = b, fit_one(draw_panel(scheme, b), r))
    res <- if (CORES > 1) mclapply(bs, one, mc.cores = CORES) else lapply(bs, one)
    res <- as.data.frame(do.call(rbind, res))
    atomic(res, p)
    logmsg(tag, 'chunk', ch, 'saved;', sum(res$converged == 1, na.rm = TRUE), 'converged of', nrow(res))
  }
  quit(save = 'no')
}

if (mode == 'SUMMARY') {
  pt <- read.csv(file.path(out, 'point_estimates.csv'), row.names = 1)
  tags <- list.dirs(out, full.names = FALSE, recursive = FALSE)
  rows <- list(); dist <- list()
  for (tag in tags) {
    fs <- list.files(file.path(out, tag), pattern = '^chunk_.*\\.rds$', full.names = TRUE)
    if (!length(fs)) next
    x <- do.call(rbind, lapply(fs, readRDS))
    r <- as.integer(sub('.*_r', '', tag)); p0 <- pt[paste0('r', r), ]
    ok <- x$converged == 1 & is.finite(x$pre_pct)
    for (m in c('ATT', 'pre_pct')) {
      v <- x[[m]][ok]; est <- p0[[m]]; se <- sd(v); q <- quantile(v, c(.025, .975))
      rows[[length(rows) + 1]] <- data.frame(run = tag, r = r, metric = m, estimate = est, se = se,
        normal_lo = est - 1.96 * se, normal_hi = est + 1.96 * se,
        pct_lo = q[[1]], pct_hi = q[[2]], basic_lo = 2 * est - q[[2]], basic_hi = 2 * est - q[[1]],
        draws = nrow(x), used = sum(ok), conv_fail = sum(x$converged != 1, na.rm = TRUE), errors = sum(x$error == 1))
    }
    dist[[tag]] <- data.frame(run = tag, n_treated = x$n_treated)
  }
  s <- do.call(rbind, rows)
  od4 <- s$se[s$run == 'od_r4' & s$metric == 'pre_pct']
  if (length(od4)) s$se_ratio_vs_od_r4 <- ifelse(s$metric == 'pre_pct', s$se / od4, NA)
  write.csv(s, file.path(out, 'summary_CI.csv'), row.names = FALSE)
  td <- do.call(rbind, dist)
  tsum <- td %>% group_by(run) %>% summarise(min = min(n_treated, na.rm = TRUE), p5 = quantile(n_treated, .05, na.rm = TRUE),
                                              median = median(n_treated, na.rm = TRUE), p95 = quantile(n_treated, .95, na.rm = TRUE),
                                              max = max(n_treated, na.rm = TRUE))
  write.csv(tsum, file.path(out, 'treated_count_distribution.csv'), row.names = FALSE)
  print(s); print(tsum)
  cat('\nValidation: od_r4 pre_pct SE should be about 0.48 pp (published CI 0.93-2.81).\n')
}
