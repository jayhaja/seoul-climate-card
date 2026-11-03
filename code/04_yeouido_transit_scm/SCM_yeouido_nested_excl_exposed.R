## SCM_yeouido_nested_excl_exposed.R — Yeouido transit SCM sensitivity: exclude donors directly exposed to the Climate Card (2026-11-03)
## Excluded donors (next to subway stations where the Climate Card could be used in 2024):
##   54 Geumgwang-dong (Jungwon-gu, Seongnam) -> Gyeonggi, 55 Geumgwang-dong -> Seoul, 56 Sangdaewon-dong -> Gyeonggi
##       : Line 8 Seongnam section (Namwirye-Moran), card usable from 2024-01-27
##   22 Haan-dong (Gwangmyeong) -> Gyeonggi, 23 Haan-dong -> Seoul
##       : Line 7 Cheolsan station (within the Onsu-Jangam range), from 2024-01-27
## Otherwise identical to the main specification: the Rmd setup, data and fit-fn chunks as they are
##   (V·W estimated jointly over 49 pre weeks, predictors tranfer and pop_dong + 5 block means of the outcome).
## Diagnostics: (1) in-space placebos — Abadie et al. (2015): only the placebo unit is removed and the treated OD is included as a donor,
##                  no pre-fit filter (excluding > 5x pre-RMSPE is a sensitivity check)
##              (2) LOO — drop each positive-weight donor in turn and re-estimate V·W
##              (3) in-time placebos — same fake dates as the Rmd (55th/70th/85th percentiles of the pre-period)
## Optimiser: in every fit, if the default (Nelder-Mead) fails, optimxmethod = "All", then genoud = TRUE (failures and method used are recorded)
## Output: OUT_DIR/excl_direct_exposure[_<EXCL>]/ (OUT_DIR default output/04_yeouido_transit_scm/SCM_yeouido_nested/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_yeouido_nested_excl_exposed.R   (on macOS optionally prefix with caffeinate -i)
## INPUT DATA: smart-card OD panels published in data/transit/ (export approved).
## Required input files (place under RAW_DIR):
##   - data/transit/od_with_pop_sum_without_holiday.csv.gz (included in the repo)
##   - data/transit/df_scm_g.csv (included in the repo)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_yeouido_nested"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## The Rmd setup chunk keeps REPO_ROOT, RAW_DIR and OUT_DIR above if they are already defined (HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- as.integer(strsplit(Sys.getenv("EXCL", "22,23,54,55,56"), ",")[[1]])   # e.g. EXCL=23,55 (Seoul-bound flows only)
rmd <- file.path(CODE_DIR, "SCM_yeouido_nested_full_pre.Rmd")
L <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) {
  s <- grep(sprintf("^```\\{r %s[,}]", label), L); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", L[(s + 1):length(L)]))[1]
  L[(s + 1):(e - 1)]
}
for (lab in c("setup", "data", "fit-fn")) eval(parse(text = chunk(lab), encoding = "UTF-8"), envir = globalenv())
ff <- chunk("fit-fn"); target <- "Synth::synth(data.prep.obj = dp, verbose = FALSE)"
stopifnot(sum(grepl(target, ff, fixed = TRUE)) == 1)
ff <- gsub(target, "do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE), SYNTH_OPT))", ff, fixed = TRUE)
ff <- gsub("fit_nested <- function", "fit_nested_opt <- function", ff, fixed = TRUE)
eval(parse(text = ff, encoding = "UTF-8"), envir = globalenv())
OPTS <- list(default = list(), `optimxmethod=All` = list(optimxmethod = "All"), genoud = list(genoud = TRUE))
fit_try <- function(tid, ctrl, ...) {           # default -> All -> genoud
  for (nm in names(OPTS)) { SYNTH_OPT <<- OPTS[[nm]]
    f <- tryCatch(fit_nested_opt(tid, ctrl, ...), error = function(e) NULL)
    if (!is.null(f)) { f$optimizer <- nm; return(f) } }
  NULL
}
cf_pct <- function(f, idx) { q <- f$t %in% idx; 100 * sum(f$gap[q]) / sum(f$Y0[q]) }

OUT <- file.path(HERE, paste0("excl_direct_exposure", if (setequal(EXCL, c(22, 23, 54, 55, 56))) "" else paste0("_", paste(EXCL, collapse = "_")))); dir.create(OUT, showWarnings = FALSE)
logf <- file.path(OUT, "run.log")
logmsg <- function(...) { s <- paste0(format(Sys.time(), "%H:%M:%S "), paste0(...)); cat(s, "\n"); cat(s, "\n", file = logf, append = TRUE) }
donors <- setdiff(donor_ids, EXCL)
logmsg(sprintf("donors %d -> %d (excluded %s; %d actually removed)", length(donor_ids), length(donors), paste(EXCL, collapse = ","), length(intersect(donor_ids, EXCL))))

## Main estimate
M0 <- fit_try(treat_id, donor_ids); M <- fit_try(treat_id, donors)
logmsg(sprintf("main spec (%d donors): ATT %.1f | vs counterfactual %.2f%% | pre RMSPE %.1f | ratio %.3f", length(donor_ids), M0$att, cf_pct(M0, post_idx), M0$pre, M0$ratio))
logmsg(sprintf("exclusion spec (%d donors): ATT %.1f | vs counterfactual %.2f%% | pre RMSPE %.1f | ratio %.3f | optimiser %s", length(donors), M$att, cf_pct(M, post_idx), M$pre, M$ratio, M$optimizer))
w_tbl <- data.frame(unit_id_num = sort(as.integer(donors)), weight = as.numeric(M$so$solution.w)) %>%
  left_join(df_scm %>% distinct(unit_id_num, unit_name), by = "unit_id_num") %>% arrange(desc(weight))
write.csv(w_tbl, file.path(OUT, "weights.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(data.frame(week_index = M$t, period = ifelse(M$t %in% final_pre_idx, "pre", "post"), actual = M$Y1, synthetic = M$Y0, gap = M$gap),
          file.path(OUT, "path.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(head(w_tbl, 8))

## (1) In-space placebos
res <- list(); fails <- c(); t0 <- Sys.time()
for (pid in donors) {
  ctrl <- c(setdiff(donors, pid), treat_id); f <- fit_try(pid, ctrl)
  if (is.null(f)) { fails <- c(fails, pid); logmsg("  placebo failed ", pid); next }
  w <- as.numeric(f$so$solution.w); names(w) <- sort(as.integer(ctrl))
  res[[as.character(pid)]] <- data.frame(placebo_unit = pid, pre = f$pre, post = f$post, ratio = f$ratio, att_abs = f$att, att_pct = f$att_pct,
                                         w_on_treated = unname(w[as.character(treat_id)]), optimizer = f$optimizer)
  logmsg(sprintf("  %3d done (%s, %.0fs)", pid, f$optimizer, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
res <- do.call(rbind, res); write.csv(res, file.path(OUT, "placebo_summary.csv"), row.names = FALSE, fileEncoding = "UTF-8")
n <- nrow(res); c_ge <- sum(res$ratio >= M$ratio); sub5 <- res[res$pre <= 5 * M$pre, ]
pv <- data.frame(rule = c("all (Abadie 2015)", "pre RMSPE <= 5x"), n_attempted = length(donors), n_placebo = c(n, nrow(sub5)), n_failed = length(fails),
                 n_alt_optimizer = sum(res$optimizer != "default"), rank = c(1 + c_ge, 1 + sum(sub5$ratio >= M$ratio)),
                 p_ratio = c((1 + c_ge) / (1 + n), (1 + sum(sub5$ratio >= M$ratio)) / (1 + nrow(sub5))))
write.csv(pv, file.path(OUT, "placebo_pvals.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(pv)

## (2) LOO — re-estimate V·W
targets <- w_tbl$unit_id_num[w_tbl$weight > 0.001]
lo <- do.call(rbind, lapply(targets, function(d) { f <- fit_try(treat_id, setdiff(donors, d)); if (is.null(f)) return(NULL)
  data.frame(omitted = d, w_omitted = w_tbl$weight[w_tbl$unit_id_num == d], pre = f$pre, ratio = f$ratio, att = f$att, cf_pct = cf_pct(f, post_idx), optimizer = f$optimizer) }))
write.csv(lo, file.path(OUT, "loo_refitV.csv"), row.names = FALSE, fileEncoding = "UTF-8")
logmsg(sprintf("LOO, %d runs: vs counterfactual %.2f to %.2f%%", nrow(lo), min(lo$cf_pct), max(lo$cf_pct)))

## (3) In-time placebos
fakes <- as.integer(round(quantile(final_pre_idx, c(0.55, 0.70, 0.85))))
it <- do.call(rbind, lapply(fakes, function(fs) { fp <- final_pre_idx[final_pre_idx < fs]; fq <- setdiff(final_pre_idx, fp)
  f <- fit_try(treat_id, donors, pre_idx = fp, eval_post_idx = fq); if (is.null(f)) return(NULL)
  data.frame(fake_start = fs, n_fake_pre = length(fp), pre_rmspe = f$pre, ratio = f$ratio, fake_att_pct = f$att_pct) }))
write.csv(it, file.path(OUT, "in_time.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(it)

summ <- data.frame(spec = c("main (81 donors)", "excl. direct exposure"), n_donors = c(length(donor_ids), length(donors)),
                   att = c(M0$att, M$att), cf_pct = c(cf_pct(M0, post_idx), cf_pct(M, post_idx)), pre_rmspe = c(M0$pre, M$pre), ratio = c(M0$ratio, M$ratio),
                   p_all = c(NA, pv$p_ratio[1]), loo_min = c(NA, min(lo$cf_pct)), loo_max = c(NA, max(lo$cf_pct)))
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE, fileEncoding = "UTF-8"); print(summ)
logmsg("[done] ", OUT)
