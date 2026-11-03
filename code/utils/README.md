# utils — 보조 계산

## 목적 / Purpose
`cf_denominator_20261102.py`: 도로 SCM(12개 방향 링크)과 여의도 대중교통 SCM의 증가율 분모를 "처치 전 평균 실제값"에서 "반사실(synthetic) 평균"으로 통일해 다시 계산한다. 저장된 경로 파일만 읽으며 재추정은 없다.
*Recomputes road-SCM and Yeouido-SCM percentage effects with the counterfactual as denominator, from saved path files only (no refitting).*

## 입력 / Inputs
원자료를 직접 읽지 않고 다른 스크립트의 중간 산출물을 읽는다. 경로는 스크립트 상단 블록 또는 환경변수로 지정.
*Reads only intermediate outputs of other scripts in this repo.*

| 환경변수 (기본값) | 파일 | 생성 스크립트 |
|---|---|---|
| `ROAD_RUN_DIR` (`output/03_road_scm/runs/v4_stdv_ex107_201_nested53_20261031-131153`) | `unit_XX/path_main.csv` 또는 `path_full.csv`, `unit_XX/loo_paths_main.csv` / `loo_paths_full.csv` | `code/03_road_scm/run_nested53_full.R` |
| `YEOUIDO_DIR` (`output/04_yeouido_transit_scm/SCM_여의도_nested`) | `path_D81_nested.csv`, `loo_sensitivity_D81_nested_vfix.csv`, `V선택_비교.csv` | `code/04_yeouido_transit_scm/SCM_여의도_nested_사전전체.Rmd` |

**제한 / RESTRICTED:** 여의도 경로 파일(관측·합성 주간 경로)은 교통카드 OD 자료에서 나온 것으로 공개하지 않는다(`data/README.md` 참조). 도로 검지기 자료는 재배포 조건 확인 중.
*Yeouido observed/synthetic paths derive from restricted smart-card data and are not distributed.*

## 출력 / Outputs
`OUT_DIR` 기본값 `output/utils/반사실대비_통일_20261102/`: `road_cf.csv`, `road_windows_cf.csv`, `road_loo_cf.csv`, `yeouido_cf.csv`.
공개본: `road_cf.csv`, `road_windows_cf.csv`, `road_loo_cf.csv` → `results/03_road_scm/summary/`; `yeouido_cf.csv`(81-donor 보관본) → `results/04_yeouido_transit_scm/yeouido_cf_81donor_archive.csv`.
*Published copies: road files in `results/03_road_scm/summary/`, Yeouido file archived as `results/04_yeouido_transit_scm/yeouido_cf_81donor_archive.csv`.*

## 실행 순서 / Run order
1. 03_road_scm, 04_yeouido_transit_scm의 해당 스크립트를 먼저 실행 / *run the producing scripts first.*
2. `python3 code/utils/cf_denominator_20261102.py` (저장소 루트에서 / *from repo root*)

## 의존성 / Dependencies
Python 3, `numpy`, `pandas`.
