# 04 여의도 대중교통 SCM / Yeouido transit synthetic control

## 목적 / Purpose
*Synthetic control for public-transport flows from Yeouido-dong, 79 donors, nested V optimisation.*

- 처치 단위: 여의도동 → 서울 대중교통 OD(주별 이용자 수, 공휴일 주 제외). 정책일 2024-01-29, 사전 49주(2023-02-13~), 사후 ~2024-12-30.
- 주사양(`nested79`): 도너 79개(Rmd의 81개에서 23 하안동→서울, 55 금광동→서울 제외). 예측변수 `tranfer`, `pop_dong` + 사전기간 결과변수 5구간 평균. V·W를 사전 49주 전체 예측오차 최소화로 동시 선택(Synth nested). 기본 최적화 실패 시 `optimxmethod = "All"` → `genoud = TRUE`.
- 대안 사양(`adhcv79`): 사전 49주를 학습 25주·검증 24주로 나눠 V 선택 후 전체 사전기간으로 W 적합(Abadie et al. 2015).
- 공간 위약(코드로 확인): 검정통계량 = 사후/사전 **RMSPE 비율**(Abadie et al. 2015). 각 위약은 위약 대상만 도너에서 빼고 **처치 단위를 도너에 포함**해 같은 절차로 적합. p = (1 + #{위약 비율 ≥ 처치 비율}) / (1 + 위약 수) — 즉 처치 단위가 분포에 포함된 순위. 주결과는 **사전 적합도 필터 없음**(`all (Abadie 2015)`), 사전 RMSPE ≤ 5배 위약만 쓰는 것은 민감도(`pre RMSPE <= 5x`).
  - 참고: Rmd 자체의 `placebo`/`pvals` 청크(81 도너, τ = 2·3·5·Inf, 처치 단위를 위약 도너에서 제외)는 구 사양이며 79 도너 스크립트는 이 청크를 쓰지 않는다.
- 효과 크기(반사실 대비 %): `cf_pct = 100 × Σ_post gap / Σ_post synthetic = ATT / mean(synthetic_post) × 100`. LOO에서는 같은 값을 `100 × ATT / (mean(actual_post) − ATT)`로 계산. Rmd의 `att_pct`는 다른 정의(ATT / 사전기간 실제 평균 × 100)이므로 혼동 주의.

## 입력 / Inputs
*Restricted smart-card OD data; not included in this repository.*

RESTRICTED DATA REQUIRED: 스마트카드 OD 자료(데이터안심구역, 반출 제한)는 저장소에 없음. `RAW_DIR`(기본 `data/restricted/`)에 두어야 함.
- `od_with_pop_sum_without_holiday.csv` — 열 `flow`, `week`, `이용자수_주총합`
- `df_scm_g.csv` — 열 `unit_id`, `unit_name`, `week`, `is_treat`, `tranfer`, `pop_dong` 등

경로는 각 스크립트 상단 Paths 블록(또는 환경변수 `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`)에서 설정. Rmd의 setup 청크는 이미 정의된 R 객체 → 환경변수 → 기본값 순으로 경로를 정하며, 직접 knit할 때(작업 폴더 = 이 폴더)는 `REPO_ROOT = "../.."`, 저장소 루트에서 eval할 때는 `"."`가 기본값이다. R 스크립트는 Rmd 청크를 읽어 eval하므로 Rmd를 고칠 때 스크립트의 `gsub` 대상 문자열(`"SCM_여의도_nested")`, `D81_nested`, `Synth::synth(data.prep.obj = dp, verbose = FALSE)`, `fit_nested <- function`, 플롯 제목의 `(tau = %d)`, `MSPE`)을 유지해야 한다.

## 출력 / Outputs
*Written to OUT_DIR (default `output/04_yeouido_transit_scm/<run>/`); published copies under `results/` and `figures/`.*

| 스크립트 | 기본 OUT_DIR | 주요 산출물 |
|---|---|---|
| `SCM_여의도_nested79_main.R` | `SCM_여의도_nested79/` | `M_nested.rds`, `weights_/vweights_/path_D79_nested.csv`, `predictor_means_D79_nested.csv`, `placebo_summary_/placebo_paths_/placebo_pvals_D79_nested.csv`, `loo_sensitivity_D79_nested{,_vfix,_cf}.csv`, `in_time_summary_D79_nested.csv`, `사양_비교_nested기준.csv`, `plots/` |
| `SCM_여의도_adhcv79.R` | `SCM_여의도_adhcv79/` | `weights_/vweights_/path_/placebo_summary_/placebo_paths_/placebo_pvals_/loo_/summary_D79_adhcv.csv`, `run.log` |
| `SCM_여의도_nested_excl_exposed.R` | `SCM_여의도_nested/excl_direct_exposure[_<EXCL>]/` | `weights.csv`, `path.csv`, `placebo_*.csv`, `loo_refitV.csv`, `in_time.csv`, `summary.csv` |
| `SCM_여의도_nested_optimizer_check.R` | `SCM_여의도_nested/excl_direct_exposure/` | `optimizer_check_excl_<EXCL>.csv` |

공개본: `results/04_yeouido_transit_scm/nested79/`, `results/04_yeouido_transit_scm/adhcv79/`, 그림 `figures/yeouido_transit_scm/`.

주의: nested79 주추정의 ATT·cf_pct는 **요약 파일로 저장되지 않는다**(콘솔 출력과 `M_nested.rds`, `path_D79_nested.csv`에만 있음; `사양_비교_nested기준.csv`는 `att_pct` 정의). 공개본에서는 `loo_sensitivity_D79_nested.csv`의 `ATT − delta_ATT`로 주 ATT(≈ 1154.0)를 복원할 수 있다. adhcv79는 `summary_D79_adhcv.csv`에 `att`, `cf_pct`를 저장한다.

## 실행 순서 / Run order
*Run from the repository root.*

```sh
Rscript code/04_yeouido_transit_scm/SCM_여의도_nested79_main.R          # 주사양 (~25분)
Rscript code/04_yeouido_transit_scm/SCM_여의도_nested79_intime.R        # main이 시점 위약 전에 멈춘 경우만
Rscript code/04_yeouido_transit_scm/SCM_여의도_nested79_plots_rmspe.R   # 위약 그림(RMSPE 비율) 재작성
Rscript code/04_yeouido_transit_scm/SCM_여의도_nested79_loo_plot.R      # LOO 그림 v2
Rscript code/04_yeouido_transit_scm/SCM_여의도_adhcv79.R                # 대안 사양 (~30분)
Rscript code/04_yeouido_transit_scm/SCM_여의도_nested_excl_exposed.R    # 직접 노출 도너 제외 민감도 (EXCL=22,23,54,55,56 기본)
Rscript code/04_yeouido_transit_scm/SCM_여의도_nested_optimizer_check.R # 최적화 방법 점검 (excl_exposed 다음)
```
intime·plots_rmspe·loo_plot은 main의 `M_nested.rds`(및 위약 CSV)를 읽는다. macOS에서는 `caffeinate -i`를 앞에 붙여도 된다. Rmd(`SCM_여의도_nested_사전전체.Rmd`)는 청크 원본(81 도너 구 사양)이며 직접 knit할 수도 있다.

## 의존성 / Dependencies
*R packages.*

R ≥ 4.1, `Synth`(+ `optimx`, `rgenoud` — `optimxmethod = "All"`, `genoud = TRUE` 사용 시), `dplyr`, `tidyr`, `readr`, `purrr`, `tibble`, `ggplot2`, `lubridate`; 선택 `ragg`(그림 장치), `knitr`/`rmarkdown`(Rmd knit). 한글 그림 글꼴: macOS AppleGothic, 그 외 NanumGothic. UTF-8 로케일에서 실행(한글 식별자 `이용자수_주총합` 파싱).
