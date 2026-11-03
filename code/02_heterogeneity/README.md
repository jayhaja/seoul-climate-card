# 02_heterogeneity — 이질성(반사실 대비 %) 재집계

## 목적 / Purpose
서울 전역 gsynth 주모형(r=4)의 저장된 점추정과 부트스트랩 draw를 출발 단위 특성(환승 부담, 환승 도보·대기 시간, 접근성, 통행 거리, 청년·고령 비율, 생활권)별로 재집계해 반사실 대비 효과(%)를 계산한다. 모형 재추정은 없다. 자치구별 효과 지도도 그린다.
*English: Re-aggregates saved citywide gsynth (r=4) fits and bootstrap draws by origin characteristics (no refitting); also draws a district-level effect map.*

## 입력 / Inputs
*English: Most inputs are restricted (derived from smart-card OD data) and must be placed under `RAW_DIR` (default `data/restricted`).*

| 파일 (RAW_DIR 기준) | 사용 스크립트 | 비고 |
|---|---|---|
| `R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_01.rds`–`chunk_05.rds` | hetero_cf_* | **제한(restricted)**, OD별 부트스트랩 draw. 생성 스크립트 저장소에 없음 |
| `R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv` | hetero_cf_* | **제한**, OD 단위. 생성 스크립트 저장소에 없음 |
| `규모통제_거리환승_20261011/OD_analysis_data.csv` | hetero_cf_* | **제한**, OD 단위 |
| `AI_uc_보정_20261101.csv`, `youth_region_20261101.csv`, `elderly_ratio_unit_20261102.csv`, `환승시간_unit매칭_20261101.csv` | hetero_cf_* | unit_id 매칭 공변량 (OD 단위라 제한 취급). 생성 스크립트 저장소에 없음 |
| `R2_r4_자치구_지도데이터_20261011/district_effects.csv` | maps_r4_district | **제한 자료에서 집계**. 생성 스크립트 저장소에 없음 |
| `읍면동/emd.shp` (+ .shx/.dbf/.prj), `집중지수_0727/공시지가_법정동_2023.csv` | maps_r4_district | 공개 자료이나 저장소에 없음 |

중간 산출물 / intermediate outputs of other repo scripts:
- `point.rds` ← `code/01_citywide_gsynth/R2_r4_Xu권고진단_20261010.R` 출력, 기본 위치 `output/01_citywide_gsynth/R2_r4_Xu권고진단_20261010/<eng>/point.rds` (환경변수 `XU_DIR`로 변경). `<eng>` = `PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155`.
- `plot_*.R` 은 `hetero_cf_tertiles_timepath_20261103.R` 의 `group_cf_pct.csv` 를 읽는다.

## 출력 / Outputs
*English: Written to `OUT_DIR` (default `output/02_heterogeneity/<run_name>`); published copies are in `results/02_heterogeneity/`.*

| 스크립트 | 기본 OUT_DIR (`output/02_heterogeneity/…`) | 공개본 |
|---|---|---|
| hetero_cf_pct_20261102.R | `R2_r4_일평균_100명당_20261102/` (group_cf_pct.csv, contrast_cf_pct.csv) | — |
| hetero_cf_quintiles_20261103.R | `R2_r4_반사실_5분위_20261103/` | `results/02_heterogeneity/R2_r4_반사실_5분위_20261103/` |
| hetero_cf_tertiles_timepath_20261103.R | `R2_r4_반사실_3분위_시간경로_20261103/` | `results/02_heterogeneity/R2_r4_반사실_3분위_시간경로_20261103/` |
| hetero_cf_transfer_wait_cross_20261103.R | `R2_r4_환승_대기_교차_20261103/` | `results/02_heterogeneity/R2_r4_환승_대기_교차_20261103/` |
| plot_cf_early_late_20261103.R, plot_transfer_cf_timepath_20261103.R | `R2_r4_반사실_3분위_시간경로_20261103/` (fig6_5_cf_early_late.png, transfer_timepath_cf.png) | 위 3분위 폴더 |
| maps_r4_district_20261011.py | `maps_r4_district_20261011/` (fig_map_r4_district_{KO,EN}.png) | — |

`membership.csv`, `bootstrap_aggregates.rds` 는 OD/출발 단위 정보라 공개본에 포함하지 않았다.

## 실행 순서 / Run order
*English: Run from the repository root; paths can be overridden with `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`, `XU_DIR` (Python: `BASE` is accepted as an alias for `RAW_DIR`).*

```sh
# 0) 선행: code/01_citywide_gsynth/R2_r4_Xu권고진단_20261010.R  (point.rds)
Rscript code/02_heterogeneity/hetero_cf_pct_20261102.R
Rscript code/02_heterogeneity/hetero_cf_quintiles_20261103.R
Rscript code/02_heterogeneity/hetero_cf_tertiles_timepath_20261103.R
Rscript code/02_heterogeneity/hetero_cf_transfer_wait_cross_20261103.R
Rscript code/02_heterogeneity/plot_cf_early_late_20261103.R
Rscript code/02_heterogeneity/plot_transfer_cf_timepath_20261103.R
python3 code/02_heterogeneity/maps_r4_district_20261011.py
```

## 의존성 / Dependencies
*English: R ≥ 4 with ggplot2; Python 3 with pandas, geopandas, matplotlib; a CJK font (Noto Sans CJK or Apple SD Gothic Neo) for the Korean map.*

- R: base R, `ggplot2` (`fect` 는 `point.rds` 를 읽을 때 객체 클래스용으로 설치 권장)
- Python: `pandas`, `geopandas`, `matplotlib`

### 저장소에 없는 의존 파일 / Missing dependencies
*English: The following are read but not produced by any script in this repo.*
- `R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_*.rds`, `dong_population_effects.csv`, `OD_analysis_data.csv`, 공변량 CSV 4개, `district_effects.csv` 를 만든 스크립트.
- `maps_EN.py` (주석에서 경계 처리 기준으로 언급, 실행에는 불필요).
- 출력 README.txt 안의 "Source script: _review/…" 문구는 원 작업 폴더 기준 표기로, 출력 내용을 바꾸지 않기 위해 그대로 두었다.
