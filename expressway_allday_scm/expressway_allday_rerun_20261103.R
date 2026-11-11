## expressway_allday_rerun_20261103.R — 그림 4-1·부록 D(서울 도시고속도로 9개 종일 교통량 SCM) 경로 재계산 (2026-11-03)
## 원 분석: 외장하드 "/Volumes/Mac OS 확장/thesis/Downloads/Thesis_Materials/scm/final/*.Rmd" (2025-06), 내부순환은 scm/inner*.Rmd
## 원 자료: Thesis_Materials/pre_processed/all_combined_with_info.csv (도로 단위·양방향, 주간, 2023-02-04~2025-03-29, 처치 1–9, 도너 10–74)
## 방법: 각 Rmd를 고치지 않고 읽어, 자료 경로만 외장하드 경로로 바꾼 뒤 'so_refined <- synth' 가 있는 청크까지 차례로 실행
##       (원래 사양 그대로: 예측변수·특수예측변수·도너·지수화 여부는 각 Rmd에 정의된 값). 오류 나는 청크(예: 폰트 내려받기)는 건너뜀.
##       → 처치·합성 경로 저장 + 처치 전 RMSPE(원 단위), RMSPE 비율 계산 → 부록 표 D-1과 대조해 원고 값과 맞는 변형을 고름.
## 출력: ~/Documents/thesis_summary/scm_results/expressway_allday_20261103/ (path_<file>.csv, summary.csv)
## 실행(직렬): cd ~/Documents/thesis_summary && caffeinate -i Rscript _review/expressway_allday_rerun_20261103.R
ARCH <- "/Volumes/Mac OS 확장/thesis/Downloads/Thesis_Materials"
OUT <- path.expand("~/Documents/thesis_summary/scm_results/expressway_allday_20261103"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
files <- c(file.path(ARCH, "scm/final", c("bukbu", "bundang", "bundang_2", "dongbu", "dongbu_2", "gangbyeon", "gangbyeon_2",
                                           "gangnam", "gangnam2", "gyeongbu", "olympic", "seobu", "seobu_2")),
           file.path(ARCH, "scm", c("inner_f", "inner", "inner2")))
files <- paste0(files, ".Rmd"); stopifnot(all(file.exists(files)))
## 부록 표 D-1 (원고): 처치 전 RMSPE(원 단위), 비율
D1 <- data.frame(road = c("Bukbu", "Bundang-Suseo", "Dongbu", "Gangbyeonbuk-ro", "Gangnam Circular", "Gyeongbu", "Naebu Circular", "Olympic-daero", "Seobu"),
                 treat_id = 1:9, D1_pre_rmspe = c(2078, 2301, 2348, 4088, 1950, 2935, 2410, 3446, 918),
                 D1_ratio = c(1.85, 1.09, 1.88, 1.90, 2.51, 1.37, 2.04, 1.89, 1.76))
run_one <- function(f) {
  src <- readLines(f, warn = FALSE, encoding = "UTF-8")
  src <- gsub("/Users/maeg/Downloads/Thesis_Materials", ARCH, src, fixed = TRUE)
  st <- grep("^```\\{r", src); en <- which(trimws(src) == "```")
  stop_i <- which(sapply(st, function(s) { e <- min(en[en > s]); any(grepl("so_refined\\s*<-\\s*synth", src[s:e])) }))[1]
  if (is.na(stop_i)) return(NULL)
  env <- new.env(parent = globalenv())
  for (i in seq_len(stop_i)) { s <- st[i]; e <- min(en[en > s]); code <- paste(src[(s + 1):(e - 1)], collapse = "\n")
    r <- tryCatch({ eval(parse(text = code, encoding = "UTF-8"), envir = env); "ok" }, error = function(err) conditionMessage(err))
    if (r != "ok") cat(sprintf("  [%s] 청크 %d 오류(건너뜀): %s\n", basename(f), i, substr(r, 1, 120))) }
  if (!exists("so_refined", envir = env)) return(NULL)
  dp <- get("dp_refined", envir = env); so <- get("so_refined", envir = env); n_pre <- get("n_pre", envir = env); tid <- get("treat_id", envir = env)
  Y1 <- as.numeric(dp$Y1plot); Y0 <- as.numeric(dp$Y0plot %*% so$solution.w); t <- dp$tag$time.plot; g <- Y1 - Y0
  pre <- t <= n_pre; post <- !pre
  dfs <- get("df_scm", envir = env); raw_pre_mean <- mean(dfs$traffic[dfs$unit_id == tid & dfs$week_index <= n_pre], na.rm = TRUE)
  indexed <- abs(mean(Y1[pre]) - 100) < 5                    # 지수화 사양이면 처치 전 평균이 100 근처
  scale <- if (indexed) raw_pre_mean / 100 else 1
  write.csv(data.frame(week_index = t, treated = Y1, synthetic = Y0, gap = g, indexed = indexed),
            file.path(OUT, sprintf("path_%s.csv", sub("\\.Rmd$", "", basename(f)))), row.names = FALSE)
  data.frame(file = basename(f), treat_id = tid, indexed = indexed, n_pre = n_pre, n_all = length(t), n_donors = length(dp$tag$controls.identifier),
             pre_rmspe_orig = sqrt(mean(g[pre]^2)) * scale, ratio = sqrt(mean(g[post]^2)) / sqrt(mean(g[pre]^2)),
             att_pct_of_synth = 100 * mean(g[post]) / mean(Y0[post]))
}
R <- do.call(rbind, lapply(files, function(f) { cat("==", basename(f), format(Sys.time(), "%H:%M:%S"), "\n")
  tryCatch(run_one(f), error = function(e) { cat("  실패:", conditionMessage(e), "\n"); NULL }) }))
R <- merge(R, D1, by = "treat_id", all.x = TRUE)
R$match <- abs(R$pre_rmspe_orig - R$D1_pre_rmspe) / R$D1_pre_rmspe < 0.03 & abs(R$ratio - R$D1_ratio) < 0.03
print(R[, c("file", "road", "indexed", "n_all", "n_donors", "pre_rmspe_orig", "D1_pre_rmspe", "ratio", "D1_ratio", "match")], digits = 4, row.names = FALSE)
write.csv(R, file.path(OUT, "summary.csv"), row.names = FALSE)
