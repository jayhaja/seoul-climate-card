# 01_citywide_gsynth — 서울 전역 OD gsynth/fect

## 목적 / Purpose
서울 내부 OD 409쌍(처치)과 통제 OD 941쌍, 99주 패널에 일반화 합성통제(gsynth, `fect`)를 적용해 기후동행카드 도입 효과를 추정한다. 주사양: `users ~ D + log_pop`, two-way FE, r = 4 고정, 가중 없음.
*Generalized synthetic control (fect/gsynth) for 409 treated within-Seoul OD pairs: main fit, OD bootstrap (B = 1000), Xu-recommended diagnostics, post-processing, and robustness refits.*

## 입력 / Inputs
모든 경로는 스크립트 상단의 경로 블록(`REPO_ROOT`, `RAW_DIR`, `OUT_DIR` 등)이나 같은 이름의 환경변수로 바꿀 수 있다. 기본값은 저장소 루트 기준 `data/restricted/`(원자료)와 `output/01_citywide_gsynth/`(중간 산출물)이다.
*All paths are set in the path block at the top of each script or via env vars of the same name.*

| 파일 (`RAW_DIR` 기준) | 비고 | 사용 스크립트 |
|---|---|---|
| `panels/d_w30_no과천.rds` | **제한 / RESTRICTED** — 교통카드 OD × 주 패널 (생성 스크립트는 저장소에 없음) | 전부 |
| `od_with_pop_sum_without_holiday.csv` | **제한 / RESTRICTED** — OD별 주간 이용자수 + 인구, 공휴일 주 제외 | BOOT, Xu권고진단, 8월절단, ife_vs_gsynth |
| `R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv` | **제한 / RESTRICTED** (단위별 산출물, 생성 스크립트 저장소에 없음) | ife_vs_gsynth |
| `규모통제_거리환승_20261011/OD_analysis_data.csv` | **제한 / RESTRICTED** (OD별 공변량, 생성 스크립트 저장소에 없음) | ife_vs_gsynth |
| `AI_uc_보정_20261101.csv`, `youth_region_20261101.csv`, `elderly_ratio_unit_20261102.csv`, `환승시간_unit매칭_20261101.csv` | **제한 / RESTRICTED** (단위별 공변량, 생성 스크립트 저장소에 없음) | ife_vs_gsynth |

다른 스크립트의 중간 산출물 / *Intermediate outputs of other scripts* (OD 수준이므로 공개하지 않음):

| 경로 (환경변수) | 생성 스크립트 |
|---|---|
| `BOOT_DIR/<engine_id>/point_r4.rds`, `chunk_01.rds`–`chunk_05.rds`, `engine_provenance.csv`, `INFERENCE_NOTES.txt`, `sessionInfo.txt` | `R2_원값_인구_비가중_r4_BOOT_20261010.R` |
| `DIAG_DIR/<engine_id>/pre_validation.csv`, `policy_r1.rds` (BOOT에서는 `policy_r4.rds`를 선택적으로 대조) | 주모형진단 실행 `R2_원값_인구_비가중_주모형진단_20261010` — **저장소에 없음** |
| `SUBMIT_DIR/OD_point_effects.csv` | `R2_r4_제출용집계_20261010.R` |

## 출력 / Outputs
기본 출력 위치는 `output/01_citywide_gsynth/<run_name>/`이다. 공개본(집계 결과)은 `results/01_citywide_gsynth/`에 있다.
*Default output is `output/01_citywide_gsynth/<run_name>/`; published aggregated versions are in `results/01_citywide_gsynth/`.*

| 스크립트 | 출력 폴더 (`OUT_DIR` 기본값) | 공개본 / Published |
|---|---|---|
| `R2_원값_인구_비가중_r4_BOOT_20261010.R` | `R2_원값_인구_비가중_r4_BOOT_20261010/<engine_id>/` (summary_B1000.csv, weekly_CI_B1000.csv, chunk_*.rds …) | 일부 메타(engine_provenance.csv, INFERENCE_NOTES.txt, sessionInfo.txt)가 `results/01_citywide_gsynth/R2_r4_제출용_20261010/`에 복사됨 |
| `R2_r4_Xu권고진단_20261010.R` | `R2_r4_Xu권고진단_20261010/<engine_id>/` | 없음 / not published |
| `R2_r4_제출용집계_20261010.R` | `R2_r4_제출용_20261010/` | `results/01_citywide_gsynth/R2_r4_제출용_20261010/` (OD_point_effects.csv 제외) |
| `gsynth_through_august_refit_20261103.R` | `gsynth_8월절단_재추정_20261103/` | `results/01_citywide_gsynth/gsynth_8월절단_재추정_20261103/` |
| `ife_vs_gsynth_point_20261102.R` | `R2_ife_vs_gsynth_20261102/` | 없음 / not published |

참고: `results/01_citywide_gsynth/R2_r4_제출용_20261010/`의 `r4_fect_counterfactual.*`, `r4_*road_window*`, `yeouido_SCM_GSC_sameperiod.csv`, `r4_경제성_조건부계산_20261010.json`, `r4_제출용결과.html`, 그리고 `R2_economics_20261011/`, `R2_normal_final_20261011/`은 이 폴더의 스크립트가 만들지 않는다(생성 스크립트 저장소에 없음).
*Some published files listed above are produced by scripts not included here.*

## 실행 순서 / Run order
저장소 루트에서 실행 / *Run from the repo root.* 원자료를 `data/restricted/`에 두거나 `RAW_DIR`(또는 기존 `ROOT`)을 지정한다.

1. `Rscript code/01_citywide_gsynth/R2_원값_인구_비가중_r4_BOOT_20261010.R` — 점추정 + 부트스트랩 200 × 5 청크 (`POINT` / `BOOT` 인자로 단계 선택, 장시간)
2. `Rscript code/01_citywide_gsynth/R2_r4_Xu권고진단_20261010.R` — fect 내장 진단 (`ALL|POINT|PLACEBO|LOO`; LOO는 수 시간)
3. `Rscript code/01_citywide_gsynth/R2_r4_제출용집계_20261010.R` — 1의 결과 집계(재추정 없음); 주모형진단 산출물(`DIAG_DIR`) 필요
4. `Rscript code/01_citywide_gsynth/ife_vs_gsynth_point_20261102.R` — IFE vs gsynth 점추정 비교 (3의 `OD_point_effects.csv` 필요; env `METHODS`, `MAXIT`, `TOL`)
5. `Rscript code/01_citywide_gsynth/gsynth_through_august_refit_20261103.R` — 2024년 8월 절단 재추정 (부트스트랩: `NB=200 CORES=2 Rscript ...`, fect CV: `CV=1`)

주의: 1·2는 매니페스트에 스크립트 md5를 기록하므로, 이번 경로 수정 전에 만든 체크포인트와는 매니페스트가 일치하지 않는다(새 출력 폴더에서 실행할 것).
*Steps 1–2 record the script md5 in `manifest.rds`; checkpoints made before this path edit will not match.*

## 의존성 / Dependencies
- R ≥ 4.5 (공개 sessionInfo: R 4.5.0)
- `fect` **2.4.7** (engine_id `..._fect2.4.7_...`, sessionInfo 기준), `dplyr`, `readr`
- `R2_fect_가중CV_도구_20261010.R` — 1·2가 스크립트와 같은 폴더에서 `source()`하는 패치 엔진 도구(`r2_engine()`, `r2_args()`, `r2_fit()` 등 정의). 함수 정의만 하며 직접 실행하지 않는다. Helper sourced by scripts 1–2 (function definitions only).
- 3은 base R만 사용. 4·5는 설치된(패치하지 않은) `fect`를 사용.
