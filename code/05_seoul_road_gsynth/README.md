# 05_seoul_road_gsynth — 서울 전역 도로 교통량 gsynth

## 목적 / Purpose
서울시 상시 교통량 조사 지점(TOPIS, 관측률 90% 이상 149개)을 처치, 서울 밖 도로 SCM 도너 53개를 통제로 두고 평일 06–09시 주간 중앙값 교통량에 gsynth(fect)를 적용해 기후동행카드 도입(2024-01-29, 51주) 이후 도로 교통량 변화를 추정한다. 지점 유형별 적합, 위약·사전추세·동등성 진단, Liu·Wang·Xu(2024) 가이드 방식 재분석을 포함한다.
*English: Seoul-wide road-traffic gsynth (149 TOPIS sites vs 53 non-Seoul donor links), with by-type fits, diagnostics, and an LWX-guide re-analysis.*

## 입력 / Inputs
*English: The TOPIS road panel is not redistributed (licence pending); place it under `RAW_DIR` (default `data/restricted`).*

- `panel_seoul176_donor53_6to9.csv` — **not redistributed (licence pending)**. TOPIS 지점 + 도너 링크 주간 패널. 원래 파이썬으로 구성했으며, 이를 만든 스크립트는 저장소에 없다(아래 Missing dependencies). 모든 4개 스크립트가 이 파일 하나만 읽는다.

## 출력 / Outputs
*English: Written to `OUT_DIR` (default under `output/05_seoul_road_gsynth/서울전역_도로_gsynth_20261103/`); published tables in `results/05_seoul_road_gsynth/`, figures in `figures/seoul_road_gsynth/`.*

| 스크립트 | 기본 OUT_DIR (`output/05_seoul_road_gsynth/…`) | 주요 출력 | 공개본 |
|---|---|---|---|
| seoul_road_gsynth_20261103.R | `서울전역_도로_gsynth_20261103/` | seoul_road_effects_cv{CRIT}.csv, seoul_road_site_gaps_cv{CRIT}.csv, fit_cv_{CRIT}.rds, README.txt | `results/05_seoul_road_gsynth/` |
| seoul_road_gsynth_diag_20261103.R | `서울전역_도로_gsynth_20261103/` | diag_placebo_r*.csv, diag_event_att_r*.csv, diag_fits_r*.rds, diag_{gap,equiv,placebo}_r*.png | csv: `results/05_seoul_road_gsynth/`, png: `figures/seoul_road_gsynth/` |
| seoul_road_gsynth_bytype_20261103.R | `서울전역_도로_gsynth_20261103/bytype/` | bytype_{OUTCOME}_{R_MODE}.csv, gap_*.png | csv: `results/05_seoul_road_gsynth/bytype/`, png: `figures/seoul_road_gsynth/bytype/` |
| seoul_road_lwx_20261103.R | `서울전역_도로_gsynth_20261103/lwx/` | lwx_summary_<시각>.csv, gap_/equiv_*.png, fit_*.rds | (공개본 없음) |

`.rds` 적합 객체는 비공개 패널을 담고 있어 공개하지 않는다.

## 실행 순서 / Run order
*English: Run from the repository root; override paths with `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`. Existing env vars (NB, CORES, CRIT, R_FIX, OUTCOME, R_MODE, TYPES, PRE_F, METHODS, GROUPS, LOO) are unchanged.*

```sh
Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_20261103.R                 # 점추정 (NB=200 CORES=2 로 부트스트랩)
CRIT=mspe Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_20261103.R       # MSPE 기준 비교
Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_diag_20261103.R            # r = CV 선택
R_FIX=3 Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_diag_20261103.R
Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
R_MODE=min Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
OUTCOME=index R_MODE=min Rscript code/05_seoul_road_gsynth/seoul_road_gsynth_bytype_20261103.R
NB=100 GROUPS=all Rscript code/05_seoul_road_gsynth/seoul_road_lwx_20261103.R
```
각 스크립트는 독립적이며(같은 패널만 읽음) 순서는 위와 같이 권장한다. `OUT_DIR`를 바꿀 때는 스크립트마다 지정해야 한다(bytype·lwx 기본값은 하위 폴더).

## 의존성 / Dependencies
*English: R with fect (tested 2.4.x; `fect_sens` used only if available) and dplyr.*

- R: `fect`, `dplyr` (lwx: `fect_sens` 가 있으면 민감도 구간 추가)

### 저장소에 없는 의존 파일 / Missing dependencies
*English: The Python script that builds the road panel is not in this repo.*
- `panel_seoul176_donor53_6to9.csv` 를 만드는 파이썬 스크립트 (TOPIS 원자료 + `road6to9_new_try` 기준 도너 53개). 도로 SCM 패널 구성은 `code/03_road_scm/` 참고.
