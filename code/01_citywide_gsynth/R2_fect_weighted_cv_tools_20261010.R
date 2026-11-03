## Shared helper tools. source() only defines functions; it does not load data or fit any model.
r2_replace <- function(txt, from, to) {
  hits <- gregexpr(from, txt, fixed = TRUE)[[1]]
  if (length(hits) != 1L || hits[1] < 0) stop("Unexpected fect function structure: ", from)
  sub(from, to, txt, fixed = TRUE)
}
r2_engine <- function() {
  ns <- asNamespace("fect"); e <- new.env(parent = ns)
  e$audit <- new.env(parent = emptyenv())
  e$audit$solvers <- list(); e$audit$folds <- list()
  txt <- paste(deparse(get("fect_nevertreated", ns)), collapse = "\n")
  txt <- r2_replace(txt, "else if (!0 %in% I_obs) {",
    "else if (!0 %in% I_obs && (length(W_in) == 1L || all(W_in == 0))) {")
  txt <- r2_replace(txt, "    .estimate_co <- function", "    Y0.co <- YY.co\n    .estimate_co <- function")
  txt <- r2_replace(txt, "out <- c(out, list(CV.out = CV.out))",
    "out <- c(out, list(CV.out = CV.out))\n        if (exists('CV.out.se', inherits=FALSE)) out$CV.out.se <- CV.out.se")
  assign("fect_nevertreated", eval(parse(text = txt), e), e)
  cv <- paste(deparse(get("fect_cv", ns)), collapse = "\n")
  anchor <- "tol = tol, boot = 0, norm.para = norm.para"
  if (!grepl(anchor, cv, fixed = TRUE)) stop("CV argument-forwarding path changed: review the fect version.")
  ## Forward max.iteration on the gsynth path (first match). fect 2.4.7 already forwards W.in.fit/cv.rule.
  cv <- sub(anchor, "tol = tol, max.iteration = max.iteration, boot = 0, norm.para = norm.para", cv, fixed = TRUE)
  if (!grepl("W.in.fit = W.in.fit", cv, fixed = TRUE)) stop("Requires the argument-forwarding structure of fect >= 2.4.7")
  assign("fect_cv", eval(parse(text = cv), e), e)
  for (nm in c("fect.default", "fect.formula", "fect_boot")) {
    fn <- get(nm, ns); environment(fn) <- e; assign(nm, fn, e)
  }
  ## Record iteration limit, iteration count and warnings for every C++ solver call. The installed namespace is not modified.
  base_solver <- get("inter_fe_ub", ns)
  spy <- base_solver
  environment(spy) <- e
  e$.base_solver <- base_solver
  body(spy) <- quote({
    env <- environment()
    aa <- lapply(names(formals(.base_solver)), function(nm) get(nm, envir = env, inherits = FALSE))
    names(aa) <- names(formals(.base_solver))
    ww <- character()
    val <- withCallingHandlers(do.call(.base_solver, aa),
      warning = function(w) ww <<- c(ww, conditionMessage(w)))
    nit <- if (length(val$niter) == 1) as.numeric(val$niter) else NA_real_
    lim <- if (!is.null(aa$max_iter)) aa$max_iter else aa$max.iteration
    audit$solvers[[length(audit$solvers) + 1L]] <- list(r = aa$r, niter = nit,
      max_iteration = lim, tol = aa$tol, warnings = ww,
      convergence_ok = is.finite(nit) && nit < lim && !any(grepl("converg|unreliable", ww, ignore.case = TRUE)))
    val
  })
  assign("inter_fe_ub", spy, e)
  ht <- paste(deparse(get(".fect_cv_score_one_ife_nt_all", ns)), collapse = "\n")
  ht <- r2_replace(ht, "    list(resid = resid_ii", paste0(
    "    ij <- arrayInd(estCV[[ii]], dim(YY.co))\n",
    "    audit$folds[[paste(r, ii, sep=':')]] <- list(r=r, fold=ii, time_pos=ij[,1],\n",
    "      donor_pos=ij[,2], residual=resid_ii, weight=if (!is.null(W)) W.use[estCV[[ii]]] else rep(1,length(resid_ii)),\n",
    "      solver=audit$solvers[[length(audit$solvers)]])\n",
    "    list(resid = resid_ii"))
  assign(".fect_cv_score_one_ife_nt_all", eval(parse(text = ht), e), e)
  list(fit = get("fect.formula", e), env = e)
}
r2_fit <- function(engine, args) {
  engine$env$audit$solvers <- list(); engine$env$audit$folds <- list()
  warnings <- character(); t0 <- Sys.time()
  fit <- withCallingHandlers(do.call(engine$fit, args),
    warning = function(w) warnings <<- c(warnings, conditionMessage(w)))
  events <- engine$env$audit$solvers
  nit <- if (length(fit$niter) == 1L) as.numeric(fit$niter) else NA_real_
  ok <- !any(grepl("converg|unreliable", warnings, ignore.case = TRUE)) &&
    all(vapply(events, function(x) isTRUE(x$convergence_ok), logical(1)))
  if (length(events) == 0L && isTRUE(fit$W.in.fit)) ok <- FALSE
  list(fit = fit, warnings = warnings, solvers = events, folds = engine$env$audit$folds,
       niter = nit, convergence_ok = ok,
       minutes = as.numeric(difftime(Sys.time(), t0, units = "mins")))
}
r2_checkpoint <- function(path, compute) {
  if (file.exists(path)) {cat("[REUSE]", basename(path), "\n"); return(readRDS(path))}
  ans <- tryCatch(compute(), error = function(err) list(error = conditionMessage(err), convergence_ok = FALSE))
  tmp <- paste0(path, ".tmp"); saveRDS(ans, tmp)
  if (!file.rename(tmp, path)) stop("Save failed: ", path)
  if (!is.null(ans$error)) cat("[FAILED]", basename(path), ans$error, "\n")
  ans
}
r2_args <- function(fm, data, west, r, maxiter = 20000L, tol = 1e-5, seed = 20260731L) {
  a <- list(formula = fm, data = data, index = c("unit_id", "week_index"),
    method = "gsynth", force = "two-way", loading.bound = "none", parallel = FALSE,
    cores = 1, seed = seed, se = FALSE, CV = FALSE, r = r, tol = tol,
    max.iteration = maxiter, W.agg = "use_pre")
  if (west != "none") a$W.est <- west
  a
}
