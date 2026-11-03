## SCM_여의도_nested79_intime.R — 여의도 주사양(도너 79) 시점 위약만 실행 (2026-11-03)
## SCM_여의도_nested79_main.R가 LOO까지 끝난 뒤 청크 이름 충돌(L 변수)로 시점 위약 직전에 멈춤 → 그 부분만 실행. 위약·LOO는 다시 돌리지 않음.
## Rmd의 intime-plots 청크 그대로(가짜 시점 = 사전 기간 55·70·85% 분위, nested V·W 재추정) + MSPE 비율(= RMSPE 비율²) 열 추가.
## 출력: OUT_DIR (기본 output/04_yeouido_transit_scm/SCM_여의도_nested79/, + plots/)
## Run (from repo root): Rscript code/04_yeouido_transit_scm/SCM_여의도_nested79_intime.R
## RESTRICTED DATA REQUIRED (restricted data required): smart-card OD data (Data Safety Center, export-restricted) are not in this repository.
## Required input files (place under RAW_DIR):
##   - od_with_pop_sum_without_holiday.csv
##   - df_scm_g.csv
##   - (from SCM_여의도_nested79_main.R, in OUT_DIR) M_nested.rds
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "04_yeouido_transit_scm", "SCM_여의도_nested79"))
CODE_DIR  <- file.path(REPO_ROOT, "code", "04_yeouido_transit_scm")
## Rmd setup 청크는 위 REPO_ROOT·RAW_DIR·OUT_DIR가 이미 있으면 그대로 사용(HERE <- OUT_DIR, PLOT <- OUT_DIR/plots).
EXCL <- c(23L, 55L)
rmd <- file.path(CODE_DIR, "SCM_여의도_nested_사전전체.Rmd"); RMD_LINES <- readLines(rmd, encoding = "UTF-8")
chunk <- function(label) { s <- grep(sprintf("^```\\{r %s[,}]", label), RMD_LINES); stopifnot(length(s) == 1)
  e <- s + which(grepl("^```\\s*$", RMD_LINES[(s + 1):length(RMD_LINES)]))[1]; gsub("D81_nested", "D79_nested", RMD_LINES[(s + 1):(e - 1)], fixed = TRUE) }
su <- gsub('"SCM_여의도_nested")', '"SCM_여의도_nested79")', chunk("setup"), fixed = TRUE)   # OUT_DIR가 이미 정의돼 있어 실제 저장 폴더는 OUT_DIR; 이 치환은 Rmd 기본값(OUT_DIR 미정의 시)용으로 유지
eval(parse(text = su, encoding = "UTF-8"), envir = globalenv())
for (lab in c("data", "fit-fn")) eval(parse(text = chunk(lab), encoding = "UTF-8"), envir = globalenv())
donor_ids <- setdiff(donor_ids, EXCL); stopifnot(length(donor_ids) == 79)
eval(parse(text = chunk("plot-helpers"), encoding = "UTF-8"), envir = globalenv())
M <- readRDS(file.path(HERE, "M_nested.rds")); stopifnot(abs(M$ratio - 3.267) < 0.01)
eval(parse(text = chunk("intime-plots"), encoding = "UTF-8"), envir = globalenv())
it$mspe_ratio <- it$ratio^2
write.csv(it, file.path(HERE, "in_time_summary_D79_nested.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(it); cat(sprintf("본추정 MSPE 비율 %.3f\n", M$ratio^2))
