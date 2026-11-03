# 03_road_scm — 여의도 주변 도로 합성통제(SCM)

## 목적 / Purpose
*English: synthetic control for 12 directional road links around Yeouido with 53 donors, nested V·W, Abadie et al. (2015)-style placebo inference on the RMSPE ratio.*

- 처치 단위: 여의도 주변 방향별 도로 링크 12개(unit 1–12). 사후 창은 일반 지점 51–96주, 공사 영향 지점(1·2·10번) 51–72주. 처치 시점 = 51주(사전 1–50주).
- 도너: 77 유닛 패널(처치 12 + 후보 65) → 질적 제외 10개(`config_v4.R`의 `donor_exclude`, 부록 C) → 이전 실행의 도너 풀(55개)에서 107·201 추가 제외 → **53개**.
- 추정: `method = "stdv"` — 사전 50주 전체에서 V(예측변수 가중치)와 W(도너 가중치)를 Synth로 **nested 최적화**(ADH 2010). 예측변수는 차로 수 평균(`lanes_mean`), 속도 중앙값(`speed`), 교통량 구간 평균 5블록.
- 추론(`run_nested53_abadie2015_placebo.R`): 도너 d마다 d를 처치로 두고 V·W를 다시 추정하는 공간 위약. Abadie et al. (2015) 원저자 구현처럼 위약 도너 = (53개 − d) ∪ {현재 처치 지점} — **처치 지점을 위약 도너 풀에 포함**(다른 처치 지점 11개는 제외).
- 검정통계량: 사후/사전 RMSPE 비율. 주 p값 = (1 + #{위약 비율 ≥ 처치 비율}) / (1 + n), **사전 적합도 필터 없음**(성공한 위약 전체; 처치 지점은 분자·분모의 "1"로 분포에 포함).
- 민감도: 사전 RMSPE가 처치 지점의 **5배 이하**인 위약만 쓴 p값(`p_tau5`).
- LOO: 양(>0.001)의 가중치 도너를 하나씩 빼고 V·W 모두 재추정(`loo_mode = "twostep"`).
- `run_nested53_full.R`은 같은 사양의 이전 판(위약 도너에 처치 지점 미포함, p값 τ = 2·3·5·Inf, LOO V 고정, 시점 위약 27·34·40주)이다.

## 입력 / Inputs
*English: road detector data are restricted and must be placed under `RAW_DIR` (default `data/restricted/`).*

**제한 자료(restricted data required)**: 서울 TOPIS 지점과 전국 ITS 링크 교통량은 재배포하지 않는다(이용 허락 확인 중). `RAW_DIR` 아래에 둔다.

| 파일 | 사용 스크립트 |
|---|---|
| `RAW_DIR/77_units/0628_6to10_df_with_new_covariates_fixed.csv` — 06:00–09:59, 일 중앙값 → 주 중앙값 패널(열: unit_id, week_index, traffic, speed, lanes_mean, region_kr, month_date, vehicle_count, is_treat, unit_name_en …) | `config_v4.R` (`panel_csv`) → 모든 실행·플롯 스크립트 |
| `OUT_DIR/runs/v4_stdv_lanes_speed_20261003-215235_566ddb10_ubu6/` 의 `run_info.json`, `donor_pool_main.csv`, `donor_pool_full.csv` — 설정·도너 풀을 복원하는 이전 실행(`run_scm_v4.R` 산출). 환경변수 `SRC_RUN`으로 경로 지정 가능 | `run_nested53_full.R`, `run_nested53_abadie2015_placebo.R` |
| `RAW_DIR/0629_roads_6to9_day.median_week.median.Rmd`, `RAW_DIR/scm_analysis_6to10_day.median_week.median_without_pre_traffic_cov.Rmd` 및 이 Rmd들이 읽는 원자료 — 원 파이프라인(저장소에 없음) | `build_panel_6to9_sum.R` (sum 민감도 패널만) |

경로는 각 스크립트 맨 위 `## ---- Paths` 블록 또는 환경변수 `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`로 바꾼다. `config_v4.R`은 이미 정의된 경로 변수를 덮어쓰지 않는다.

## 출력 / Outputs
*English: runs go to `OUT_DIR/runs/`; the published copies are in `results/03_road_scm/` and `figures/road_scm/NN/`.*

- 실행 폴더: `OUT_DIR/runs/v4_stdv_ex107_201_nested53_abadie2015pl_<YYYYmmdd-HHMMSS>/` — `run_info.json`, `run.log`, `all_units_summary.csv`, `unit_XX/{path.csv, placebo_results.csv, placebo_paths.csv, placebo_failures.csv(실패 시), loo_twostep.csv, loo_paths_twostep.csv}`, `plots/NN/*.jpg`.
- 공개본 `results/03_road_scm/`: `all_units_summary.csv`, `run_info.json`(원 실행 기록 — 원 경로를 그대로 둠), `unit_XX/{placebo_results.csv, loo_twostep.csv}`, `summary/*.csv`(반사실 대비 % 등 후처리 표; 일부는 `code/utils/cf_denominator_20261102.py`).
- 공개본 `figures/road_scm/NN/` (NN = 처치 지점 01–12, `<tag>` = `nested53_<사후 주 수>w`, 즉 22w 또는 46w):
  - `1.scm_path_<u>_<tag>.jpg` — 처치 vs 합성 경로
  - `2.scm_gap_<u>_<tag>.jpg` — 격차(처치 − 합성)
  - `3.rmspe_ratio_<u>_<tag>_{all,tau5}.jpg` — 사후/사전 RMSPE 비율 순위(처치 = 빨간 삼각형)
  - `4.placebo_gaps_<u>_<tag>_{all,tau5}.jpg` — 위약 격차 묶음(회색) + 처치 격차(검정), 51주에 점선
  - `10.placebo_hist_<u>_<tag>_{all,tau5}.jpg` — RMSPE 비율 히스토그램(부제에 처치 비율, 위약 수, p)
  - `5.loo_<u>_<tag>_twostep.jpg` — LOO(V·W 재추정) 합성 경로
- `*_all` = 성공한 위약 전체(주 검정, 필터 없음). `*_tau5` = 사전 RMSPE ≤ 5 × 처치 지점 사전 RMSPE인 위약만 표시(민감도 부분집합). 원고의 위약 격차 그림은 `4.placebo_gaps_<u>_<tag>_tau5.jpg`로, 이 부분집합의 위약 격차 경로(회색)와 처치 격차(검정)를 1주부터 사후 창 끝까지 그린다. 주 p값(`p_all`)은 필터 없는 전체 위약 기준이므로 그림에 보이는 위약 수(`n_tau5`)와 다를 수 있다.

## 실행 순서 / Run order
*English: run from the repository root.*

```sh
# (선택) sum 민감도 패널 생성 — 원 파이프라인 Rmd 필요
Rscript code/03_road_scm/build_panel_6to9_sum.R 2>&1 | tee build_panel_6to9_sum.log
# 0. 기본 v4 실행 — 설정(run_info.json)과 도너 풀을 만든다. 새 폴더 이름은 실행 시각·해시로 정해지므로
#    아래 두 스크립트에는 SRC_RUN=output/03_road_scm/runs/<새 폴더> 로 지정한다.
Rscript code/03_road_scm/run_scm_v4.R
# (이전 판) nested53, 병렬 위약 + 시점 위약 + 플롯
Rscript code/03_road_scm/run_nested53_full.R            # 또는 ... 4,6,8,12 / NESTED_EXCL=none ...
# 본 결과: Abadie et al. (2015) 위약 + LOO(twostep), 직렬 실행
Rscript code/03_road_scm/run_nested53_abadie2015_placebo.R
# 원고 그림 (가장 최근 abadie2015pl 실행 폴더 사용)
Rscript code/03_road_scm/plot_nested53_abadie2015pl.R
```
macOS에서는 오래 걸리는 실행 앞에 `caffeinate -i`를 붙여도 된다(선택). `config_v4.R`, `scm_v4_functions.R`, `scm_v4_plots.R`은 위 스크립트가 `source()`하는 설정·함수 파일이다.

## 의존성 / Dependencies
*English: R packages below; the original median-panel pipeline is not in this repo.*

- R 패키지: `Synth`, `dplyr`, `readr`, `tidyr`, `jsonlite`, `ggplot2`, `parallel`(`mclapply`, Windows에서는 병렬 안 됨); 선택 `LowRankQP`, `digest`, `ragg`, `showtext`·`sysfonts`(원고와 같은 글자 크기, Noto Sans KR 내려받기). `build_panel_6to9_sum.R`은 추가로 `knitr`, `readxl`, `stringr`, `lubridate`, `purrr`, `tibble`.
- 저장소에 없는 것: 원 06–09 median 파이프라인 Rmd 두 개.
