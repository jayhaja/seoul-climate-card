## config_v4.R — 도로 SCM v4 설정 (v3 + method 선택) (변수 정의 · 기간 · 도너 기준 · 출력)
## 변경 이력은 run_info.json(설정 해시)과 실행 로그로 추적. 설정이 바뀌면 캐시가 무효화된다.
## ---- Paths (edit here or set env vars) -------------------------------
## Guarded so this file can be sourced by other scripts (which may already define these) in any order.
if (!exists("REPO_ROOT")) REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                                    # run from repo root
if (!exists("RAW_DIR"))   RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # non-redistributed road inputs
if (!exists("OUT_DIR"))   OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "03_road_scm"))
if (!exists("CODE_DIR"))  CODE_DIR  <- file.path(REPO_ROOT, "code", "03_road_scm")
## RESTRICTED DATA REQUIRED (restricted data required): road detector inputs (Seoul TOPIS sites and national ITS link counts) are not redistributed (licence pending).
## Required input files (place under RAW_DIR):
##   - 77_units/0628_6to10_df_with_new_covariates_fixed.csv   (analysis panel, 77 units; built by the original 06–09 median pipeline, not in this repo)
CFG <- list(
  ## ── 입력 ─────────────────────────────────────────────────────────────────
  panel_csv = file.path(RAW_DIR, "77_units", "0628_6to10_df_with_new_covariates_fixed.csv"),
  ##   06:00–09:59 창, 일 중앙값→주 중앙값, 77 유닛(처치 12 + 도너 후보 65). 열: unit_id, week_index, traffic, speed,
  ##   lanes_mean, region_kr, month_date, vehicle_count(시도 월별 등록대수), is_treat, unit_name_en …
  pop_csv   = NULL,   # 인구 1,000명당 등록차량용. 열: region_kr, month_date(YYYY-MM-01), population. NULL이면 차량 변수 미사용.
  ##   주의: vehicle_count는 시도(5개) 단위라 같은 시도 도너는 값이 모두 같다 → 사실상 지역 더미. 시군구 단위 자료로 교체 권장.

  ## ── 분석 단위 ────────────────────────────────────────────────────────────
  treated_ids = 1:12,
  donor_exclude = c(114, 304, 126, 129, 131, 202, 102, 101, 404, 305),   # 질적 제외(부록 C 표 C-1). 사유는 donor_exclude_reason에.
  donor_exclude_reason = c(
    "114" = "통일로IC–양주TG: 자료 품질/구조 변동(부록 C)", "304" = "서대전IC–서대전JC(부록 C)", "126" = "마성IC–신갈JC(부록 C)",
    "129" = "천진암교–산곡JC(부록 C)", "131" = "감곡IC–여주JC(부록 C)", "202" = "인천TG–부평IC(부록 C)", "102" = "목감IC–광명역IC(부록 C)",
    "101" = "남양주TG–화도IC(부록 C)", "404" = "기장IC–해운대IC(부록 C)", "305" = "천변도시고속화도로 하행→상행(부록 C)"),

  ## ── 추정 방식 ───────────────────────────────────────────────────────────
  ## "stdv"    : 표준 SCM(ADH 2010). 사전 50주(pre_idx) 전체의 예측변수·결과변수로 V·W를 nested 최적화 1회.
  ##             fit_idx/valid_idx/final_w_idx는 적합에 쓰이지 않음(지표의 early/late RMSPE 구간 표시에만 사용).
  ## "adh2015" : v3와 동일한 2단계(학습 1–25 → 검증 26–50으로 V 선택 → final_w_idx로 최종 W).
  method = "stdv",
  ## "cv"      : 구 본표(cv2550)의 사양 선택을 표본외 기준으로 바로잡은 판. 처치 지점별로 (공변량 조합 × 도너 수 K) 격자를
  ##             1–25주 적합 / 26–50주 예측오차(1단계 W 기준)로 채점해 최소 쌍을 고른 뒤, 그 V 고정·상위 K 도너로 1–50주 전체 W 적합.
  ##             위약은 선택된 사양(조합·풀) 고정. 설정은 아래 cv 항목.
  cv = list(
    candidates = list(                       # 공변량 후보 (부분집합 전부 = 조합 후보; 빈 조합 = 결과변수 블록만)
      list(var = "lanes_mean",     op = "mean",   label = "차로 수 평균"),
      list(var = "speed",          op = "median", label = "속도 중앙값"),
      list(var = "speed",          op = "min",    label = "최저 속도"),
      list(var = "vehicle_change", op = "mean",   label = "자동차등록대수 변화")),
    K_grid   = 55:40,                        # 거리순 상위 K 도너 (풀 크기보다 크면 자동 절사)
    final_v  = "fixed",                      # "fixed": 선택 단계 V 고정 후 1–50주 W (구 방식) / "nested": 선택된 조합·풀로 V·W 재최적화(stdv)
    placebo_v = "own"                        # "own": 위약마다 자기 V 재선택(구 Rmd와 동일) / "treated": 처치의 V까지 고정(사양 완전 고정)
    ## 한계(설계): 위약·in-time은 처치에서 선택된 조합·풀을 물려받을 뿐 (조합×K) 선택 절차 자체를 반복하지 않는다 → 선택에 조건부인 추론.
  ),

  ## ── 도너 사전 선별 (처치 전 자료만, 임계값은 적합 전에 고정 — 결과 보고 조정하지 않음) ──
  ## 처치 지점별로 적용. 본 추정·위약·LOO·in-time 모두 같은 선별 풀 사용. 결과는 unit_XX/donor_screen.csv.
  donor_screen = list(
    enabled       = FALSE,       # 2026-10-05: 오라클 선별 보류(Jay). TRUE로 바꾸면 처치별 선별 적용
    level_ratio   = c(1/3, 3),   # 도너 사전 평균 교통량 / 처치 사전 평균 교통량 허용 범위
    trend_cor_min = 0.3,         # 사전 50주 주별 교통량 피어슨 상관 하한 (처치 전 결과변수, 적합 아님)
    min_donors    = 15           # 통과 수가 이보다 적으면 수준 통과 도너 중 상관 상위 min_donors개로 완화(플래그 기록)
  ),

  ## ── 기간 (week_index) ───────────────────────────────────────────────────
  fit_idx   = 1:25,      # 1단계: 예측변수 집계 + W 적합(학습)
  valid_idx = 26:50,     # 1단계: V 선택 기준(검증 결과변수)
  final_w_idx = 26:50,   # 2단계: 예측변수 집계 + 최종 W 적합 창 (ADH 2015 = 검증창). 민감도: 1:50 (학습·검증은 그대로)
  pre_idx   = 1:50,
  post_main = 51:72,     # 본표 사후 창(2024-06-24까지)
  post_full = 51:100,    # 참고(전체)
  n_blocks  = 5,         # 결과변수(교통량) 구간 평균 블록 수 (각 창을 n등분)
  ## 관측 완전성은 분석 창별로 검사: 본표 = pre_idx ∪ post_main, 전체 = pre_idx ∪ post_full. 처치·도너 모두 창별 적용.

  ## ── 예측변수 (공통 기본 조합, 도로별 자동 선택 없음) ───────────────────
  ## 각 항목: var = 패널 열, op = 창 내 집계. 창은 단계별로 fit_idx / valid_idx가 자동 적용된다.
  predictors = list(
    list(var = "lanes_mean",        op = "mean",   label = "차로 수 평균"),
    list(var = "speed",             op = "median", label = "속도 중앙값")
    ## 차량등록 변수는 제외 (2026-10-03 결정): vehicle_count가 시도(5개) 단위 월별 총계라 같은 시도 도너는 값이 동일 →
    ## 매칭 정보가 없는 지역 더미에 불과. 시군구 단위 자료를 확보하면 아래 줄을 되살려 민감도로 사용.
    ## , list(var = "vehicles_per_1000", op = "mean", label = "인구 1,000명당 등록차량", requires_pop = TRUE)
  ),

  ## ── 추론·진단 ───────────────────────────────────────────────────────────
  placebo_tau   = c(2, 3, 5, Inf),   # 위약 풀 필터: 사전 RMSPE ≤ tau × 처치 사전 RMSPE
  loo_min_w     = 0.001,             # LOO 대상: 최종 가중치 > loo_min_w
  loo_mode      = "fixedV",          # "fixedV": V 고정, W만 재적합(정본 부록 A-1 LOO = vfix) / "twostep": 제외마다 V·W 모두 재최적화
  intime_starts = c(27, 34, 40),     # in-time 위약 가짜 처치 시점(주)
  diag_max_w_warn    = 0.5,          # 최대 도너 가중치 경고 기준
  diag_rmspe_worsen  = 1.5,          # 최종 W의 26–50주 RMSPE가 1단계 검증 RMSPE의 몇 배를 넘으면 경고

  ## ── 출력 ────────────────────────────────────────────────────────────────
  out_root = file.path(OUT_DIR, "runs"),   # 실행별 하위 폴더(타임스탬프_해시) 자동 생성
  run_tag  = "v4_stdv_lanes_speed"
)
