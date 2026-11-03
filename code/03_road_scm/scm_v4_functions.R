## scm_v4_functions.R — Road SCM v4 function library (data preparation → V selection → final W → effects → diagnostics)
## Depends on: Synth, dplyr, readr, jsonlite, digest (optional). ggplot2 is not used (base graphics).
suppressMessages({ library(dplyr); library(readr); library(Synth) })

## ── 0. Utilities ───────────────────────────────────────────────────────────
rmspe <- function(a, b) sqrt(mean((a - b)^2, na.rm = TRUE))
blocks <- function(idx, n) { ed <- round(seq(0, length(idx), length.out = n + 1)); lapply(seq_len(n), function(b) idx[(ed[b] + 1):ed[b + 1]]) }
ffill <- function(x) {                      # **Forward** fill within unit only. NAs before the first observation are left as is (no use of future values)
  x[!is.finite(x)] <- NA; if (all(is.na(x))) return(x)
  for (k in seq_along(x)[-1]) if (is.na(x[k])) x[k] <- x[k - 1]; x
}
file_md5 <- function(p) { if (is.null(p)) return(NA_character_); p <- path.expand(p); if (!file.exists(p)) return(NA_character_); as.character(tools::md5sum(p)) }
cfg_hash <- function(cfg, code_files, units, infer) {
  s <- paste(c(capture.output(str(cfg, give.attr = FALSE)), file_md5(cfg$panel_csv), file_md5(cfg$pop_csv),
               vapply(code_files, file_md5, ""), paste(units, collapse = ","), infer), collapse = "\n")
  if (requireNamespace("digest", quietly = TRUE)) substr(digest::digest(s, algo = "md5"), 1, 8)
  else substr(as.character(tools::md5sum(local({ tf <- tempfile(); writeLines(s, tf); tf }))), 1, 8)
}

## ── 1. Data preparation ─────────────────────────────────────────────────
load_panel <- function(cfg, logmsg = message) {
  df <- read_csv(path.expand(cfg$panel_csv), show_col_types = FALSE, guess_max = 1e5) %>%
    mutate(unit_id_num = as.integer(unit_id), week_index = as.integer(week_index)) %>%
    arrange(unit_id_num, week_index)                             # make the weekly ordering explicit before handling missing values
  need <- c("traffic", "speed", "lanes_mean", "region_kr", "month_date", "vehicle_count", "is_treat", "unit_name_en")
  miss <- setdiff(need, names(df)); if (length(miss)) stop("Missing panel columns: ", paste(miss, collapse = ", "))
  ## Vehicle variable: per 1,000 population (only if pop_csv is given)
  if (!is.null(cfg$pop_csv)) {
    pop <- read_csv(path.expand(cfg$pop_csv), show_col_types = FALSE) %>%
      mutate(month_date = as.Date(month_date)) %>% select(region_kr, month_date, population)
    dup <- pop %>% count(region_kr, month_date) %>% filter(n > 1)
    if (nrow(dup)) stop("[pop] Duplicate region-month combinations: ", nrow(dup), ": ", paste(head(paste(dup$region_kr, dup$month_date), 5), collapse = "; "))
    if (any(!is.finite(pop$population) | pop$population <= 0)) stop("[pop] Rows with non-positive/missing population")
    df <- df %>% mutate(month_date = as.Date(month_date)) %>% left_join(pop, by = c("region_kr", "month_date"))
    unm <- df %>% filter(is.na(population)) %>% distinct(region_kr, month_date)
    if (nrow(unm)) logmsg("[pop] Unmatched region-months: ", nrow(unm), ": ", paste(head(paste(unm$region_kr, unm$month_date), 8), collapse = "; "))
    df <- df %>% mutate(vehicles_per_1000 = vehicle_count / population * 1000)
    n_na0 <- sum(!is.finite(df$vehicles_per_1000))
    df <- df %>% group_by(unit_id_num) %>% mutate(vehicles_per_1000 = ffill(vehicles_per_1000)) %>% ungroup()
    n_na1 <- sum(!is.finite(df$vehicles_per_1000))
    first_ok <- df %>% filter(is.finite(vehicles_per_1000)) %>% group_by(unit_id_num) %>% summarise(w1 = min(week_index), .groups = "drop")
    logmsg(sprintf("[pop] vehicles_per_1000: missing %d → %d after forward fill (leading NAs kept). Latest first valid week %d (training window ends %d)",
                   n_na0, n_na1, max(first_ok$w1), max(cfg$fit_idx)))
    if (n_na1 > 0) logmsg("[pop] Units with remaining missing cells become NA in window aggregation and may fail in dataprep — exclude those units or complete the data")
  } else {
    df$vehicles_per_1000 <- NA_real_
    logmsg("[data] No pop_csv → vehicles_per_1000 not created (that predictor is dropped automatically)")
  }
  ## vehicle_change (monthly month-on-month change by province/metropolitan city): NA in month-boundary weeks → forward fill within unit (same as the old fill_cov). Used only as a method="cv" candidate covariate.
  if ("vehicle_change" %in% names(df)) {
    n0 <- sum(!is.finite(df$vehicle_change))
    df <- df %>% group_by(unit_id_num) %>% mutate(vehicle_change = { x <- vehicle_change; x[!is.finite(x)] <- NA
      i1 <- which(!is.na(x))[1]; if (!is.na(i1) && i1 > 1) x[seq_len(i1 - 1)] <- x[i1]; ffill(x) }) %>% ungroup()
    logmsg(sprintf("[data] vehicle_change missing %d → %d (forward fill; before the first observation, the first observed value)", n0, sum(!is.finite(df$vehicle_change))))
  }
  ## Missing speed: not filled, since it is handled by median(na.rm) within the window. Units that are entirely NA are to be excluded.
  n_sp_na <- sum(!is.finite(df$speed)); logmsg(sprintf("[data] speed missing in %d cells (handled by na.rm in window aggregation)", n_sp_na))
  df
}

active_predictors <- function(cfg, df) {
  keep <- vapply(cfg$predictors, function(p) {
    if (isTRUE(p$requires_pop) && all(!is.finite(df[[p$var]]))) return(FALSE)
    p$var %in% names(df)
  }, logical(1))
  cfg$predictors[keep]
}

## Build the special.predictors list per window (outcome blocks + covariates)
make_special <- function(cfg, preds, idx) {
  sp <- lapply(blocks(idx, cfg$n_blocks), function(b) list("traffic", b, "mean"))
  c(sp, lapply(preds, function(p) list(p$var, idx, p$op)))
}
sp_names <- function(cfg, preds, prefix) c(sprintf("%s_traffic_b%d", prefix, seq_len(cfg$n_blocks)), sprintf("%s_%s_%s", prefix, vapply(preds, `[[`, "", "var"), vapply(preds, `[[`, "", "op")))

## Fix the donor pool: qualitative exclusions + fully observed outcome requirement
donor_pool <- function(cfg, df, treated_ids, need_idx, logmsg = message) {
  cand <- df %>% filter(!is_treat %in% c(TRUE, "TRUE")) %>% distinct(unit_id_num) %>% pull(unit_id_num)
  cand <- setdiff(cand, c(treated_ids, cfg$donor_exclude))
  ok <- df %>% filter(unit_id_num %in% cand, week_index %in% need_idx) %>% group_by(unit_id_num) %>%
    summarise(n_ok = sum(is.finite(traffic)), .groups = "drop") %>% filter(n_ok == length(need_idx)) %>% pull(unit_id_num)
  logmsg(sprintf("[donor] candidates %d → qualitative exclusions %d → fully observed outcome %d", length(cand) + length(intersect(cfg$donor_exclude, cand)) , length(cfg$donor_exclude), length(ok)))
  sort(ok)
}

## ── 2. Two-step fit (ADH 2015) ──────────────────────────────────────────
## Synth::synth retry wrapper: default → quadopt LowRankQP → relaxed ipop tolerances → all optimx methods. The successful attempt is recorded as an attr.
## (Cases: "computationally singular" when the largest-weight donor is dropped in LOO, "infinite/missing values in 'x'" in placebos — all ipop/optim numerical issues)
.synth_robust <- function(dp, custom.v = NULL, label = "") {
  tries <- list(list(), list(quadopt = "LowRankQP"), list(Margin.ipop = 5e-4, Sigf.ipop = 5, Bound.ipop = 10),
                list(optimxmethod = "All"), list(optimxmethod = "All", quadopt = "LowRankQP"))
  errs <- character()
  for (i in seq_along(tries)) {
    a <- tries[[i]]
    if (!is.null(a$quadopt) && !requireNamespace("LowRankQP", quietly = TRUE)) next
    so <- tryCatch({ invisible(capture.output(s <- do.call(Synth::synth, c(list(data.prep.obj = dp, verbose = FALSE),
                                                                            if (!is.null(custom.v)) list(custom.v = custom.v), a)))); s },
                   error = function(e) { errs <<- c(errs, conditionMessage(e)); NULL })
    if (!is.null(so)) { attr(so, "attempt") <- i; if (i > 1) message("  [synth] ", label, " retry attempt ", i, " succeeded (", paste(names(a), unlist(a), collapse = ","), ")"); return(so) }
  }
  stop("synth failed (", label, "): ", paste(unique(errs), collapse = " | "))
}
## method="stdv": one joint optimisation over the full pre-window / method="adh2015": the two steps below
## Stage 1: W from training-window (fit_idx) predictors; V chosen to fit the validation-window (valid_idx) outcome
## Stage 2: V fixed, final W from validation-window predictors. Effects over the post window.
fit_two_step <- function(cfg, df, preds, treated, donors, fit_idx = cfg$fit_idx, valid_idx = cfg$valid_idx,
                         final_w_idx = cfg$final_w_idx, post_idx = cfg$post_main, plot_idx = NULL, v_fixed = NULL) {
  donors <- sort(as.integer(donors)); treated <- as.integer(treated)
  if (is.null(plot_idx)) plot_idx <- sort(unique(c(fit_idx, valid_idx, final_w_idx, post_idx)))
  foo <- as.data.frame(df %>% filter(unit_id_num %in% c(treated, donors), week_index %in% plot_idx))
  base_args <- list(foo = foo, dependent = "traffic", unit.variable = "unit_id_num", unit.names.variable = "unit_name_en",
                    time.variable = "week_index", treatment.identifier = treated, controls.identifier = donors)
  ## ── method = "stdv": one joint V·W optimisation over the full pre-window (fit∪valid) ──
  if (identical(cfg$method, "stdv") || identical(cfg$method_fit, "stdv")) {
    pre_w <- sort(unique(c(fit_idx, valid_idx)))            # main estimate: fit∪valid = pre_idx (1–50) / in-time: 1–(f0−1)
    if (!setequal(pre_w, cfg$pre_idx) && !any(post_idx <= max(cfg$pre_idx))) stop("stdv: fit∪valid differs from pre_idx")
    dp0 <- do.call(Synth::dataprep, c(base_args, list(special.predictors = make_special(cfg, preds, pre_w),
                   time.predictors.prior = pre_w, time.optimize.ssr = pre_w, time.plot = plot_idx)))
    rownames(dp0$X1) <- rownames(dp0$X0) <- sp_names(cfg, preds, "pre")
    so0 <- .synth_robust(dp0, custom.v = v_fixed, label = paste0("stdv tr=", treated))
    v_star <- as.numeric(so0$solution.v); w2 <- as.numeric(so0$solution.w)
    Y1 <- as.numeric(dp0$Y1plot); Y0 <- as.numeric(dp0$Y0plot %*% w2); tt <- dp0$tag$time.plot; gap <- Y1 - Y0
    m <- list(v_selection_rmspe = NA_real_, stage1_fit_rmspe = NA_real_,     # single step: no validation-based V selection
      final_pre_early_rmspe = rmspe(Y1[tt %in% fit_idx],   Y0[tt %in% fit_idx]),
      final_pre_late_rmspe  = rmspe(Y1[tt %in% valid_idx], Y0[tt %in% valid_idx]),
      final_w_fit_rmspe     = rmspe(Y1[tt %in% pre_w], Y0[tt %in% pre_w]),
      final_pre_rmspe       = rmspe(Y1[tt %in% pre_w], Y0[tt %in% pre_w]),
      post_rmspe            = rmspe(Y1[tt %in% post_idx], Y0[tt %in% post_idx]),
      att_abs = mean(gap[tt %in% post_idx]), baseline_pre = mean(Y1[tt %in% pre_w]),
      max_w = max(w2), hhi_w = sum(w2^2), n_pos_w = sum(w2 > cfg$loo_min_w), synth_attempt = attr(so0, "attempt"))
    m$rmspe_ratio <- m$post_rmspe / m$final_pre_rmspe; m$att_pct <- m$att_abs / m$baseline_pre * 100
    return(list(dp1 = dp0, dp2 = dp0, so1 = NULL, so2 = so0, v = v_star, w1 = w2, w2 = w2, donors = donors, treated = treated,
         path = data.frame(week_index = tt, actual = Y1, synthetic = Y0, gap = gap, period = ifelse(tt %in% post_idx, "post", "pre")), metrics = m))
  }
  ## ── method = "adh2015": two steps ──
  dp1 <- do.call(Synth::dataprep, c(base_args, list(special.predictors = make_special(cfg, preds, fit_idx),
                 time.predictors.prior = fit_idx, time.optimize.ssr = valid_idx, time.plot = c(fit_idx, valid_idx))))
  rownames(dp1$X1) <- rownames(dp1$X0) <- sp_names(cfg, preds, "fit")
  if (is.null(v_fixed)) {
    so1 <- .synth_robust(dp1, label = paste0("stage1 tr=", treated))
    v_star <- as.numeric(so1$solution.v); w1 <- as.numeric(so1$solution.w)
  } else { v_star <- v_fixed; so1 <- NULL; w1 <- rep(NA_real_, length(donors)) }
  ## Stage 2
  ## Stage 2: V fixed, final W from the predictors in the final_w_idx window (default = validation window, ADH 2015)
  dp2 <- do.call(Synth::dataprep, c(base_args, list(special.predictors = make_special(cfg, preds, final_w_idx),
                 time.predictors.prior = final_w_idx, time.optimize.ssr = final_w_idx, time.plot = plot_idx)))
  rownames(dp2$X1) <- rownames(dp2$X0) <- sp_names(cfg, preds, "final")
  so2 <- .synth_robust(dp2, custom.v = v_star, label = paste0("stage2 tr=", treated))
  w2 <- as.numeric(so2$solution.w)
  Y1 <- as.numeric(dp2$Y1plot); Y0 <- as.numeric(dp2$Y0plot %*% w2); tt <- dp2$tag$time.plot; gap <- Y1 - Y0
  ## Stage-1 fit (validation-window prediction with the training-window W = V selection error)
  if (!is.null(so1)) { Y1a <- as.numeric(dp1$Y1plot); Y0a <- as.numeric(dp1$Y0plot %*% w1); ta <- dp1$tag$time.plot
    s1_fit <- rmspe(Y1a[ta %in% fit_idx], Y0a[ta %in% fit_idx]); s1_valid <- rmspe(Y1a[ta %in% valid_idx], Y0a[ta %in% valid_idx])
  } else s1_fit <- s1_valid <- NA_real_
  m <- list(
    v_selection_rmspe   = s1_valid,                         # stage 1: validation-window prediction error of the training-window W (V selection criterion)
    stage1_fit_rmspe    = s1_fit,
    final_pre_early_rmspe = rmspe(Y1[tt %in% fit_idx],   Y0[tt %in% fit_idx]),
    final_pre_late_rmspe  = rmspe(Y1[tt %in% valid_idx], Y0[tt %in% valid_idx]),   # final W's error on weeks 26–50 (in-sample if final_w_idx is the validation window)
    final_w_fit_rmspe     = rmspe(Y1[tt %in% final_w_idx], Y0[tt %in% final_w_idx]),
    final_pre_rmspe     = rmspe(Y1[tt %in% c(fit_idx, valid_idx)], Y0[tt %in% c(fit_idx, valid_idx)]),
    post_rmspe          = rmspe(Y1[tt %in% post_idx], Y0[tt %in% post_idx]),
    att_abs             = mean(gap[tt %in% post_idx]),
    baseline_pre        = mean(Y1[tt %in% c(fit_idx, valid_idx)]),
    max_w               = max(w2), hhi_w = sum(w2^2), n_pos_w = sum(w2 > cfg$loo_min_w), synth_attempt = attr(so2, "attempt"))
  m$rmspe_ratio <- m$post_rmspe / m$final_pre_rmspe; m$att_pct <- m$att_abs / m$baseline_pre * 100
  list(dp1 = dp1, dp2 = dp2, so1 = so1, so2 = so2, v = v_star, w1 = w1, w2 = w2, donors = donors, treated = treated,
       path = data.frame(week_index = tt, actual = Y1, synthetic = Y0, gap = gap,
                         period = ifelse(tt %in% post_idx, "post", "pre")), metrics = m)
}

## ── 2a. method="cv": (combination × K) grid selection — fit on weeks 1–25, score by prediction error on weeks 26–50 (stage-1 W) ─────────
## Caution: the scoring error (valid_rmspe) is the very same weeks 26–50 error minimised when choosing V in stage 1 (unavoidable in the ADH 2015 structure).
## That is, it is "train 1–25 → predict 26–50", but V was chosen by looking at 26–50, so this value is not out-of-sample performance independent of model selection but
## a tuning criterion. Describe it as such in the paper as well.
## Distance: aggregate the combination's covariates over the pre-window → standardise by donor mean/SD → Euclidean (if the combination is empty, pre-period mean traffic)
## Distance aggregation window = training window (fit_idx), so that no validation-window information enters the donor ranking (the old Rmd used constants over the 50 pre-weeks)
cv_distance <- function(cfg, df, preds, treated, donors, idx = cfg$fit_idx) {
  agg <- function(p) df %>% filter(week_index %in% idx, unit_id_num %in% c(treated, donors)) %>% group_by(unit_id_num) %>%
    summarise(v = match.fun(p$op)(.data[[p$var]], na.rm = TRUE), .groups = "drop") %>% arrange(unit_id_num)
  pl <- if (length(preds)) preds else list(list(var = "traffic", op = "mean"))
  M <- do.call(cbind, lapply(pl, function(p) agg(p)$v)); ids <- agg(pl[[1]])$unit_id_num
  dm <- M[ids != treated, , drop = FALSE]; tv <- M[ids == treated, ]
  mu <- colMeans(dm, na.rm = TRUE); sd <- apply(dm, 2, sd, na.rm = TRUE); sd[!is.finite(sd) | sd == 0] <- 1
  delta <- sweep(sweep(dm, 2, mu, "-"), 2, sd, "/") - matrix((tv - mu) / sd, nrow(dm), ncol(dm), byrow = TRUE)
  d <- sqrt(rowSums(delta^2))                                      # Euclidean (fixed 2026-10-06: previously |Σ differences| due to a parenthesis error)
  data.frame(unit_id_num = ids[ids != treated], distance = d) %>% arrange(distance)
}
cv_select <- function(cfg, df, treated, donors, logmsg = message) {
  cand <- cfg$cv$candidates; combos <- list(list())
  for (k in seq_along(cand)) combos <- c(combos, combn(seq_along(cand), k, simplify = FALSE) |> lapply(function(i) cand[i]))
  cname <- function(cb) if (!length(cb)) "outcome_only" else paste(vapply(cb, function(p) paste0(p$var, "_", p$op), ""), collapse = "+")
  Kg <- cfg$cv$K_grid[cfg$cv$K_grid <= length(donors)]
  cfg2 <- cfg; cfg2$method <- "adh2015"; cfg2$method_fit <- NULL          # the selection step is always two-step (fit 1–25 → prediction error 26–50)
  rows <- list(); fits <- list()
  for (cb in combos) {
    dist <- cv_distance(cfg, df, cb, treated, donors)
    for (K in Kg) {
      pool <- sort(dist$unit_id_num[seq_len(K)])
      f <- tryCatch(fit_two_step(cfg2, df, cb, treated, pool, final_w_idx = cfg$valid_idx, post_idx = cfg$post_main), error = function(e) NULL)
      if (is.null(f)) next
      key <- paste(cname(cb), K); fits[[key]] <- list(v = f$v, pool = pool, preds = cb)
      rows[[key]] <- data.frame(treated_unit = treated, combo = cname(cb), n_cov = length(cb), K = K,
                                fit_rmspe = f$metrics$stage1_fit_rmspe, valid_rmspe = f$metrics$v_selection_rmspe)
    }
  }
  grid <- bind_rows(rows) %>% arrange(valid_rmspe, n_cov, desc(K))
  best <- grid[1, ]; sel <- fits[[paste(best$combo, best$K)]]
  logmsg(sprintf("  [cv] grid of %d (combinations %d × K %d) → selected: %s, K=%d (valid RMSPE %.1f)", nrow(grid), length(combos), length(Kg), best$combo, best$K, best$valid_rmspe))
  list(preds = sel$preds, donors = sel$pool, v = sel$v, combo = best$combo, K = best$K, grid = grid)
}

## ── 2b. Donor pre-screening (level ratio + trend correlation) ─────────
screen_donors <- function(cfg, df, treated, donors, pre_idx = cfg$pre_idx) {
  sc <- cfg$donor_screen
  wide <- df %>% filter(week_index %in% pre_idx, unit_id_num %in% c(treated, donors)) %>%
    select(week_index, unit_id_num, traffic) %>% tidyr::pivot_wider(names_from = unit_id_num, values_from = traffic)
  y1 <- wide[[as.character(treated)]]
  tb <- bind_rows(lapply(donors, function(d) {
    y0 <- wide[[as.character(d)]]
    data.frame(unit_id_num = d, level_ratio = mean(y0, na.rm = TRUE) / mean(y1, na.rm = TRUE),
               trend_cor = suppressWarnings(cor(y1, y0, use = "complete.obs")))
  })) %>% left_join(df %>% distinct(unit_id_num, unit_name = unit_name_en), by = "unit_id_num")
  if (!isTRUE(sc$enabled)) return(list(keep = donors, table = tb %>% mutate(pass_level = TRUE, pass_trend = TRUE, keep = TRUE, relaxed = FALSE)))
  tb <- tb %>% mutate(pass_level = is.finite(level_ratio) & level_ratio >= sc$level_ratio[1] & level_ratio <= sc$level_ratio[2],
                      pass_trend = is.finite(trend_cor) & trend_cor >= sc$trend_cor_min, keep = pass_level & pass_trend, relaxed = FALSE)
  if (sum(tb$keep) < sc$min_donors) {                      # relaxation: highest-correlation donors among those passing the level check
    cand <- tb %>% filter(pass_level) %>% arrange(desc(trend_cor)) %>% slice_head(n = sc$min_donors)
    tb <- tb %>% mutate(keep = unit_id_num %in% cand$unit_id_num, relaxed = TRUE)
  }
  list(keep = sort(tb$unit_id_num[tb$keep]), table = tb %>% arrange(desc(keep), desc(trend_cor)))
}

## ── 3. Diagnostics ────────────────────────────────────────────────────────
diagnostics <- function(cfg, fit, df, preds) {
  dp2 <- fit$dp2; dp1 <- fit$dp1
  bal <- function(dp, w, stage) data.frame(stage = stage, predictor = rownames(dp$X1), treated = as.numeric(dp$X1),
    synthetic = as.numeric(dp$X0 %*% w), donor_mean = rowMeans(dp$X0), donor_min = apply(dp$X0, 1, min), donor_max = apply(dp$X0, 1, max)) %>%
    mutate(outside_donor_range = treated < donor_min | treated > donor_max, v_weight = NA_real_)
  b2 <- bal(dp2, fit$w2, if (identical(cfg$method, "stdv")) "single_pre50" else "stage2_final_w"); b2$v_weight <- fit$v
  balance <- if (identical(cfg$method, "stdv")) b2 else {
    b1 <- bal(dp1, if (all(is.na(fit$w1))) fit$w2 else fit$w1, "stage1_fit"); b1$v_weight <- fit$v; bind_rows(b1, b2) }
  ## Change in covariates across windows (treated unit): training window vs validation window
  cov_change <- if (identical(cfg$method, "stdv")) data.frame(predictor = character(), fit_window = numeric(), final_w_window = numeric(), rel_change = numeric()) else
    data.frame(predictor = sub("^fit_", "", rownames(dp1$X1)), fit_window = as.numeric(dp1$X1), final_w_window = as.numeric(dp2$X1)) %>%
    mutate(rel_change = (final_w_window - fit_window) / ifelse(fit_window == 0, NA, abs(fit_window)))
  wt <- data.frame(unit_id_num = fit$donors, w_stage1 = fit$w1, w_final = fit$w2) %>%
    left_join(df %>% distinct(unit_id_num, unit_name = unit_name_en), by = "unit_id_num") %>%
    mutate(w_change = w_final - w_stage1) %>% arrange(desc(w_final))
  m <- fit$metrics
  flags <- c(
    max_weight_high   = m$max_w > cfg$diag_max_w_warn,
    late_fit_worsened = is.finite(m$v_selection_rmspe) && m$final_pre_late_rmspe > cfg$diag_rmspe_worsen * m$v_selection_rmspe,
    treated_outside_range_stage2 = any(b2$outside_donor_range),
    early_fit_poor    = m$final_pre_early_rmspe > 2 * m$final_pre_late_rmspe)
  list(balance = balance, cov_change = cov_change, weights = wt,
       flags = data.frame(flag = names(flags), triggered = as.logical(flags)))
}

## ── 4. Placebo · LOO · in-time ─────────────────────────────────────────────
## In-space placebo and LOO use the fit_two_step default (cfg$final_w_idx), so the same final-W window rule as the main estimate applies
## v_fixed: with method="cv", if cfg$cv$placebo_v == "treated", the treated unit's V is also fixed for placebos (fully fixed specification). Default "own" = each placebo uses its own V (same as the old Rmd).
placebo_in_space <- function(cfg, df, preds, treated, donors, post_idx = cfg$post_main, v_fixed = NULL) {
  out <- list(); paths <- list()
  for (d in donors) {
    f <- tryCatch(fit_two_step(cfg, df, preds, treated = d, donors = setdiff(donors, d), post_idx = post_idx, v_fixed = v_fixed),
                  error = function(e) { message("  placebo ", d, " failed: ", conditionMessage(e)); NULL })
    if (is.null(f)) next
    out[[as.character(d)]] <- data.frame(placebo_unit = d, pre_rmspe = f$metrics$final_pre_rmspe, post_rmspe = f$metrics$post_rmspe,
                                          ratio = f$metrics$rmspe_ratio, att_abs = f$metrics$att_abs, att_pct = f$metrics$att_pct)
    paths[[as.character(d)]] <- f$path %>% mutate(placebo_unit = d)
  }
  res <- bind_rows(out) %>% left_join(df %>% distinct(placebo_unit = unit_id_num, unit_name = unit_name_en), by = "placebo_unit")
  list(res = res, paths = bind_rows(paths))
}
placebo_pvals <- function(cfg, res, main) {
  bind_rows(lapply(cfg$placebo_tau, function(tau) {
    sub <- res %>% filter(pre_rmspe <= tau * main$final_pre_rmspe); n <- nrow(sub)
    data.frame(tau = tau, n_placebo = n,
      p_ratio = (1 + sum(sub$ratio >= main$rmspe_ratio)) / (1 + n),
      p_att_left = (1 + sum(sub$att_abs <= main$att_abs)) / (1 + n),
      p_att_two_sided = (1 + sum(abs(sub$att_abs) >= abs(main$att_abs))) / (1 + n))
  }))
}
loo_refit <- function(cfg, df, preds, fit, post_idx = cfg$post_main) {
  targets <- fit$donors[fit$w2 > cfg$loo_min_w]; res <- list(); paths <- list()
  for (d in targets) {
    keep <- setdiff(fit$donors, d); if (length(keep) < 2) next
    f <- tryCatch(fit_two_step(cfg, df, preds, fit$treated, keep, post_idx = post_idx,
                               v_fixed = if (cfg$loo_mode == "fixedV") fit$v else NULL),
                  error = function(e) { message("  LOO omit ", d, " failed: ", conditionMessage(e)); NULL })
    if (is.null(f)) next
    res[[as.character(d)]] <- data.frame(omitted = d, w_omitted = fit$w2[fit$donors == d], att_abs = f$metrics$att_abs, att_pct = f$metrics$att_pct,
               pre_rmspe = f$metrics$final_pre_rmspe, ratio = f$metrics$rmspe_ratio, mode = cfg$loo_mode)
    paths[[as.character(d)]] <- f$path %>% mutate(omitted = d)
  }
  list(res = bind_rows(res), paths = bind_rows(paths))
}
in_time_placebo <- function(cfg, df, preds, treated, donors) {
  res <- list(); paths <- list()
  for (f0 in cfg$intime_starts) {
    pre <- 1:(f0 - 1); half <- floor(length(pre) / 2)
    fit_i <- pre[1:half]; val_i <- pre[(half + 1):length(pre)]; post_i <- f0:max(cfg$pre_idx)
    ## The final-W window applies the main-estimate rule to the period before the fake treatment: val_i if the validation window, fit_i∪val_i if the full pre-window
    fw_i <- if (identical(cfg$method, "stdv") || setequal(cfg$final_w_idx, cfg$pre_idx)) c(fit_i, val_i) else if (setequal(cfg$final_w_idx, cfg$valid_idx)) val_i else
      stop("in_time_placebo: final_w_idx must equal valid_idx or pre_idx")
    if (length(fit_i) < cfg$n_blocks || length(val_i) < cfg$n_blocks || length(post_i) < 3) next
    f <- tryCatch(fit_two_step(cfg, df, preds, treated, donors, fit_idx = fit_i, valid_idx = val_i, final_w_idx = fw_i, post_idx = post_i),
                  error = function(e) { message("  in-time f", f0, " failed: ", conditionMessage(e)); NULL })
    if (is.null(f)) next
    res[[as.character(f0)]] <- data.frame(fake_start = f0, n_fit = length(fit_i), n_valid = length(val_i), n_post = length(post_i),
               fake_att_pct = f$metrics$att_pct, fake_ratio = f$metrics$rmspe_ratio, pre_rmspe = f$metrics$final_pre_rmspe)
    paths[[as.character(f0)]] <- f$path %>% mutate(fake_start = f0)
  }
  list(res = bind_rows(res), paths = bind_rows(paths))
}

## ── 5. Plots: scm_v4_plots.R (manuscript style) ──────────────────────────
