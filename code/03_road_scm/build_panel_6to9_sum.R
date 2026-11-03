## build_panel_6to9_sum.R — 06:00–09:59 창, 결과변수 = 시간별 합계 → 일 합계 → 주 평균 패널 생성 (sum 민감도용)
## 정본 06–09 median 파이프라인(road6to9_new_try)의 두 Rmd를 텍스트 패치해 실행한다. 원본 Rmd·폴더는 수정하지 않는다.
##   1) 패널 Rmd: 일 집계 median → sum(4시간 모두 관측된 날만), 주 집계 median → mean. 출력은 panel_sum/ 아래.
##   2) SCM Rmd §0–4: 공변량 부착·id 재부여 → panel_sum/77_units/0628_6to10_df_with_new_covariates_fixed.csv
##      (스펙 선택·배치는 실행하지 않음. 유닛 id는 정본 6to9와 같은 lookup 규칙이므로 동일해야 하며 아래에서 검사)
## 실행: cd ~/Thesis/0614/0628/road_scm_v4 && Rscript build_panel_6to9_sum.R 2>&1 | tee build_panel_6to9_sum.log
## 이후: config_v4.R의 panel_csv를 panel_sum/77_units/…fixed.csv 로, run_tag를 "v4_stdv_sum" 으로 바꿔 run_scm_v4.R 실행
suppressMessages(library(knitr))
SRC  <- path.expand("~/Thesis/0614/0628/road6to9_new_try")
OUT  <- path.expand("~/Thesis/0614/0628/road_scm_v4/panel_sum")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
PANEL_CSV <- file.path(OUT, "0629_6to9_day.sum_week.mean.csv")

## ── 1) 패널 ───────────────────────────────────────────────────────────
rmd1 <- file.path(SRC, "0629_roads_6to9_day.median_week.median.Rmd")
src <- readLines(rmd1, warn = FALSE)
patch <- function(src, from, to, n = 1) {
  i <- grep(from, src, fixed = TRUE); if (length(i) != n) stop("패치 실패(", length(i), "건): ", from); src[i] <- sub(from, to, src[i], fixed = TRUE); src }
src <- patch(src, 'OUT_FILE  <- "~/Thesis/0614/0628/road6to9_new_try/0629_6to10_day.median_week.median.csv"',
                  sprintf('OUT_FILE  <- "%s"', PANEL_CSV))
src <- patch(src, 'traffic = if_else(n_obs >= 1, median(traffic, na.rm = TRUE), NA_real_),',
                  'traffic = if_else(n_obs >= 4, sum(traffic, na.rm = TRUE), NA_real_),      # [sum] 06–09 4시간 모두 관측된 날만 합계')
src <- patch(src, 'med_traffic     = safe_median(traffic),    # 주 median',
                  'med_traffic     = mean(traffic, na.rm = TRUE),    # [sum] 주 평균 (열 이름은 호환 위해 유지)')
src <- patch(src, 'write.csv(weekly_dir1, "~/Thesis/0614/0628/road6to9_new_try/weekly_weekly_dir.csv"',
                  sprintf('write.csv(weekly_dir1, "%s/weekly_weekly_dir.csv"', OUT))
tmp1 <- file.path(OUT, "_panel_6to9_sum.Rmd"); writeLines(src, tmp1)
r1 <- file.path(OUT, "_panel_6to9_sum.R"); knitr::purl(tmp1, output = r1, quiet = TRUE)
if (!file.exists(PANEL_CSV)) {
  cat("\n[1] 패널 생성 →", PANEL_CSV, "\n")
  setwd(OUT)                                   # unit_lookup.csv, units_list.csv 가 cwd에 저장됨 → 원본 폴더 보호
  source(r1, echo = FALSE, local = globalenv())
  stopifnot(file.exists(PANEL_CSV))
} else cat("\n[1] 패널 CSV 존재 → 건너뜀\n")

## ── 2) 공변량 부착 (SCM Rmd §0–4) ───────────────────────────────────────
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
i_load <- which(lab == "data-load"); i_dir <- which(s2[starts] == "```{r}" & seq_along(starts) > i_load)[2]   # 2번째 무명 청크 = root/dir_name
i_plot <- which(s2[starts] == "```{r}" & seq_along(starts) > i_load)[1]                                          # 1번째 무명 청크 = must_to_delete + plotly
i_save <- which(lab == "")[which(lab == "") > which(lab == "covariate-specs")]                                # covariate-specs 뒤 무명 청크들
suppressMessages({ library(dplyr); library(readr); library(readxl); library(tidyr); library(stringr); library(lubridate); library(purrr); library(tibble) })
run_i(i_load, pt(blk(i_load)))
## plotly 청크: df_m_f 정의 줄까지만 실행
pc <- strsplit(blk(i_plot), "\n")[[1]]; run_i(i_plot, paste(pc[seq_len(grep("^regions <-", pc)[1] - 1)], collapse = "\n"))
run_i(i_dir, pt(blk(i_dir)))
run_i(i_dir + 1)                                              # donor_list.csv
for (nm in c("vehicle-merge", "safe-helpers", "build-covariates", "unit-ids")) run_i(which(lab == nm))
dir.create("table", showWarnings = FALSE)                     # id 재부여 청크가 table/unit_id_remap.csv 를 cwd(77_units)에 저장
## covariate-specs 뒤: ORI 보관 → id 재부여 → fixed.csv 저장 (validation·best-spec 청크는 건너뜀)
after <- which(seq_along(lab) > which(lab == "best-spec-selection") & lab == "")[1:3]
for (i in after) run_i(i)
FIXED <- file.path(OUT, "77_units", "0628_6to10_df_with_new_covariates_fixed.csv")
stopifnot(file.exists(FIXED))

## ── 3) 유닛 id 검사: 정본 6to9와 linkID+direction→unit_id 동일해야 함 ─────
a <- unique(read.csv(FIXED)[, c("unit_id", "linkID", "direction")])
b <- unique(read.csv(file.path(SRC, "77_units/0628_6to10_df_with_new_covariates_fixed.csv"))[, c("unit_id", "linkID", "direction")])
m <- merge(a, b, by = c("linkID", "direction"), suffixes = c("_sum", "_med"), all = TRUE)
cat(sprintf("\n[check] 유닛 %d(sum) vs %d(median) · 공통 %d · id 불일치 %d\n", nrow(a), nrow(b),
            sum(!is.na(m$unit_id_sum) & !is.na(m$unit_id_med)), sum(m$unit_id_sum != m$unit_id_med, na.rm = TRUE)))
if (any(m$unit_id_sum != m$unit_id_med, na.rm = TRUE) || any(is.na(m$unit_id_sum)) || any(is.na(m$unit_id_med))) {
  print(m[is.na(m$unit_id_sum) | is.na(m$unit_id_med) | m$unit_id_sum != m$unit_id_med, ]); stop("유닛 id가 정본과 다름 → donor_exclude 재매핑 필요")
}
cat("\nDONE:", FIXED, "\n")
