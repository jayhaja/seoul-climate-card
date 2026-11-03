# 서울 기후동행카드의 대중교통·도로 교통 효과 / Seoul Climate Card: effects on public transport use and car traffic

석사 논문 「서울시 기후동행카드(2024-01-27 시행)의 효과 분석」의 **공개용 재현 자료**(코드, 집계 결과, 그림)입니다.
Public replication package (code, aggregated results, figures) for a master's thesis evaluating Seoul's Climate Companion Card (기후동행카드), launched on 27 January 2024.

- 웹사이트 / Website: `docs/` (GitHub Pages — 결과 표 탐색, 그림 갤러리 / results explorer, figure gallery)
- 인용 / Citation: [`CITATION.cff`](CITATION.cff) · 라이선스 / Licence: [아래 / below](#라이선스--licence)

> **원자료 미포함 / Raw data not included.** 교통카드 OD 자료는 데이터안전센터 반출 제한 자료이므로 이 저장소에 없으며 앞으로도 포함하지 않습니다. 저장소의 결과는 모두 집계값입니다.
> The smart-card origin–destination (OD) data are export-restricted (secure data centre) and are not, and will not be, in this repository. Everything here is aggregated output.

---

## 1. 연구 질문 / Research questions

1. 기후동행카드 시행 후 서울 내부 대중교통 이용이 반사실(시행하지 않았을 경우) 대비 얼마나 늘었는가?
   How much did within-Seoul public transport use increase relative to a no-card counterfactual?
2. 효과는 환승 부담, 대기 시간, 접근성, 통행 거리, 연령 구성에 따라 달랐는가?
   Did the effect differ by transfer burden, waiting time, accessibility, trip distance and age structure?
3. 승용차 통행(도로 교통량)이 줄었는가? 여의도 연결도로와 서울 전역 도로에서 확인한다.
   Did car traffic fall — on the road links around Yeouido and across Seoul?
4. 여의도동에서 출발하는 대중교통 통행이 합성통제 대비 늘었는가?
   Did public transport trips from Yeouido-dong rise relative to a synthetic control?

## 2. 자료 / Data

| 자료 / Source | 용도 / Use | 저장소 포함 / In repo |
|---|---|---|
| 국토교통부 교통카드 OD 자료 (데이터안전센터) / MOLIT smart-card OD records (secure data centre) | 분석 1·2·4 결과변수 / outcome for analyses 1, 2, 4 | ✗ 반출 제한 / restricted |
| 서울 TOPIS 지점 교통량, 국가 ITS 링크 교통량 / Seoul TOPIS detector counts, national ITS link counts | 분석 3·5 결과변수 / outcome for analyses 3, 5 | ✗ 재배포 조건 확인 중 / licence pending |
| 주민등록 인구통계 (행정안전부) / Resident registration population | 공변량 / covariate | ✗ 공개 출처 / public source |
| KTDB 접근성 지표, 서울연구원 2019-BR-26 / KTDB accessibility, Seoul Institute 2019-BR-26 | 이질성 / heterogeneity | ✗ 공개 출처 / public source |

자세한 내용은 [`data/README.md`](data/README.md). Details: [`data/README.md`](data/README.md).

## 3. 방법 / Methods

| # | 분석 / Analysis | 처치 단위 / Treated | 비교 단위 / Controls | 방법 / Method | 코드 / Code |
|---|---|---|---|---|---|
| 1 | 서울 내부 대중교통 / Within-Seoul transit | 서울 내부 OD 409쌍 / 409 within-Seoul OD pairs | 도너 OD 941 / 941 donor ODs | gsynth (fect, r = 4, OD·주 고정효과, 공변량 log 인구) / generalised synthetic control | [`code/01_citywide_gsynth`](code/01_citywide_gsynth) |
| 2 | 이질성 / Heterogeneity | 분석 1의 409쌍 / the 409 ODs of analysis 1 | — | 분석 1 적합값을 집단별로 재집계(재추정 없음), 쌍체 부트스트랩 1,000회 / re-aggregation of analysis 1 fit, 1,000 paired bootstrap draws | [`code/02_heterogeneity`](code/02_heterogeneity) |
| 3 | 여의도 연결도로 / Yeouido road links | 12개 방향 링크 / 12 directional links | 서울 밖 도너 53 / 53 non-Seoul donors | SCM (nested V), 단위별 / per link | [`code/03_road_scm`](code/03_road_scm) |
| 4 | 여의도동 출발 대중교통 / Transit from Yeouido-dong | 여의도동 출발 OD 1 / 1 OD unit | 도너 79 / 79 donors | SCM (nested V) | [`code/04_yeouido_transit_scm`](code/04_yeouido_transit_scm) |
| 5 | 서울 전역 도로 / Seoul-wide roads | TOPIS 149개 지점 / 149 TOPIS sites | 서울 밖 도너 53 / 53 non-Seoul donors | gsynth (CV 선택 r, r = 1–4 민감도) / gsynth, CV rank with r = 1–4 sensitivity | [`code/05_seoul_road_gsynth`](code/05_seoul_road_gsynth) |

**효과율 / Effect in %.** 반사실 대비 효과 = 100 × Σ(관측 − 반사실) / Σ반사실 (개별 비율의 평균이 아닌 합의 비율).
Effect relative to counterfactual = 100 × Σ(observed − counterfactual) / Σ counterfactual (a ratio of sums, not a mean of unit percentages).

**SCM 추론 / SCM inference (분석 3·4).**
- 검정통계량: 처치 후 RMSPE / 처치 전 RMSPE 비율 (Abadie, Diamond & Hainmueller 2015).
  Test statistic: post-/pre-treatment RMSPE ratio (Abadie et al. 2015).
- 위약 분포에 **처치 단위를 포함**: p = (처치 단위 이상 비율을 가진 단위 수) / (위약 수 + 1).
  The treated unit is **included** in the placebo distribution: p = rank / (number of placebos + 1).
- 주 결과에는 **사전 적합도 필터를 적용하지 않음**. 사전 RMSPE가 처치 단위의 5배 이하인 위약만 쓰는 결과는 민감도 분석으로만 보고.
  **No pre-fit filter** in the headline result; restricting to placebos with pre-RMSPE ≤ 5× the treated unit is a sensitivity check only.
- 원고용 위약 격차 그림(`*_tau5.jpg`)은 5배 이하 위약만 그리지만, 그 그림과 함께 보고하는 p값은 위약 전체 기준.
  The manuscript placebo-gap figures (`*_tau5.jpg`) draw only the ≤ 5× placebos, but the p-value reported with them uses all placebos.

**gsynth 추론 / gsynth inference (분석 1·2).** OD 부트스트랩 1,000회, 정규근사 95% 구간(점추정 ± 1.96 × 부트스트랩 SD). [`results/01_citywide_gsynth/R2_normal_final_20261011/README.txt`](results/01_citywide_gsynth/R2_normal_final_20261011/README.txt) 참조.
1,000 OD bootstrap draws; normal-approximation 95 % intervals (estimate ± 1.96 × bootstrap SD).

## 4. 주요 결과 / Main results

모든 수치는 아래 CSV에서 직접 읽은 값입니다. All numbers are read directly from the CSV files cited.

### 4.1 서울 내부 대중교통 (분석 1) / Within-Seoul transit

| 기간 / Window | 주 수 / Weeks | 반사실 대비 / vs counterfactual | 95% CI (normal) |
|---|---|---|---|
| 전체 2024-01-29 ~ 2024-12-30 / full | 46 | **+1.568%** | 0.823 – 2.313 |
| 8월까지 / through August | 30 | +1.444% | 0.741 – 2.148 |
| 12월 제외 / excluding December | 42 | +1.478% | 0.759 – 2.198 |

출처 / Source: [`results/01_citywide_gsynth/R2_normal_final_20261011/windows.csv`](results/01_citywide_gsynth/R2_normal_final_20261011/windows.csv) (`metric = effect_pct`, `normal_lo`, `normal_hi`).
같은 파일 기준 OD당 주평균 ATT 288.4건, 409쌍 합산 주평균 +117,959건(46주 누적 약 543만 건). Same file: ATT 288.4 trips per OD-week; +117,959 trips per week summed over 409 ODs (≈ 5.43 million over 46 weeks).

### 4.2 이질성 (분석 2) / Heterogeneity

- 통행 거리: 원거리 3분위(Q3)가 근거리(Q1)보다 효과율이 1.55%p 낮음 (95% CI −2.59 ~ −0.51). Longer-distance tertile: −1.55 pp vs shortest (CI −2.59 to −0.51).
- 대기 시간: 긴 대기 3분위가 짧은 대기보다 0.97%p 낮음 (CI −1.75 ~ −0.19). Longest-wait tertile: −0.97 pp (CI −1.75 to −0.19).
- 환승 부담: 전체 기간 차이는 유의하지 않음(+0.23%p, CI −0.55 ~ 1.02), 후기−초기 변화는 +1.37%p. Transfer burden: no full-period difference (+0.23 pp), but the late-minus-early change is +1.37 pp.

출처 / Source: [`results/02_heterogeneity/R2_r4_반사실_3분위_시간경로_20261103/contrast_cf_pct.csv`](results/02_heterogeneity/R2_r4_반사실_3분위_시간경로_20261103/contrast_cf_pct.csv) (`window = full`, `late_minus_early`). p값은 다중비교 미보정. Unadjusted p-values; descriptive heterogeneity, not causal effects of the characteristics.

### 4.3 여의도 연결도로 SCM (분석 3) / Yeouido road-link SCM

12개 방향 중 **4개 지점이 p = .019**(53개 위약 + 처치 단위 중 1위)로 유의합니다.
**Four of the 12 links** are significant at p = .019 (rank 1 among 53 placebos plus the treated unit).

| 지점 / Link | 반사실 대비 / vs counterfactual | p (위약 전체 / all placebos) | LOO 범위 / LOO range |
|---|---|---|---|
| 노들로 남행 / Nodeul-ro southbound | −10.03% | .019 | −13.85 ~ −9.85 |
| 마포대교 북행 / Mapo Bridge northbound | −4.85% | .019 | −5.40 ~ −3.65 |
| 서강대교 북행 / Seogang Bridge northbound | −2.18% | .019 | −2.79 ~ −0.78 |
| 원효대교 북행 / Wonhyo Bridge northbound | −4.23% | .019 | −4.60 ~ −3.51 |

나머지 8개 링크는 p ≥ .093. The other eight links have p ≥ .093.
출처 / Source: [`results/03_road_scm/summary/road_abadie2015_placebo_loo_cf.csv`](results/03_road_scm/summary/road_abadie2015_placebo_loo_cf.csv). 5배 이하 위약만 쓴 민감도 p(같은 실행): [`results/03_road_scm/all_units_summary.csv`](results/03_road_scm/all_units_summary.csv)의 `p_tau5` — 같은 4개 지점 .019–.033. Sensitivity p with ≤ 5× placebos (same run): `p_tau5` in `all_units_summary.csv`, .019–.033 for the same four links.
`summary/road_placebo_p_all_vs_tau5.csv`와 `summary/road_loo_cf.csv`는 이전 사양(위약 도너에 처치 단위 미포함) 실행 값이라 본 결과와 다릅니다. `summary/road_placebo_p_all_vs_tau5.csv` and `summary/road_loo_cf.csv` come from the earlier specification (treated unit not in placebo donor pools) and differ from the headline run.

### 4.4 여의도동 출발 대중교통 SCM (분석 4) / Transit from Yeouido-dong

- 반사실 대비 **+4.98%**, 위약 순위 1/80, **p = .0125** (위약 79 + 처치 단위, 필터 없음). 5배 이하 민감도 p = .0127.
  **+4.98 %** relative to the synthetic control; rank 1 of 80, **p = .0125** (79 placebos plus the treated unit, no filter); ≤ 5× sensitivity p = .0127.
- LOO(양의 가중치 도너 5개 각각 제외): +3.81% ~ +5.52%. Leave-one-out over the five positive-weight donors: +3.81 % to +5.52 %.
- 시점 위약(가짜 시행 27·35·42주): +1.6 ~ +2.4%. In-time placebos: +1.6 % to +2.4 %.

출처 / Sources: [`results/04_yeouido_transit_scm/nested79/placebo_pvals_D79_nested.csv`](results/04_yeouido_transit_scm/nested79/placebo_pvals_D79_nested.csv) (p), [`loo_sensitivity_D79_nested_cf.csv`](results/04_yeouido_transit_scm/nested79/loo_sensitivity_D79_nested_cf.csv) (LOO), [`in_time_summary_D79_nested.csv`](results/04_yeouido_transit_scm/nested79/in_time_summary_D79_nested.csv).
\+4.98%는 nested79 폴더에 단일 값으로 저장되어 있지 않아 `loo_sensitivity_D79_nested_cf.csv`에서 계산합니다: 본 ATT = `ATT − delta_ATT` = 1,154.0, 처치 후 관측 평균 = `ATT × (1 + 100/cf_pct)` = 24,317.1 → 1,154.0 / (24,317.1 − 1,154.0) = 4.982% (5개 행 모두 동일).
The +4.98 % is not stored as a single value in `nested79/`; it is derived from `loo_sensitivity_D79_nested_cf.csv` as above (identical across all five rows).

### 4.5 서울 전역 도로 gsynth (분석 5) / Seoul-wide road gsynth

- 149개 TOPIS 지점, CV 선택 r = 0: 반사실 대비 −1.37% (여의도 연계 지점 제외 −1.25%). 요인 수 r = 1–4에서 −2.15% ~ −0.65%.
  149 TOPIS sites, CV-selected r = 0: −1.37 % (−1.25 % without Yeouido-linked sites); −2.15 % to −0.65 % across r = 1–4.
- 사전 기간 위약 검정이 기각됨(r = 0: p < .001; r = 3: p = .043) — 평행 추세 진단을 통과하지 못하므로 **기술적 결과로만 해석**.
  The pre-period placebo test rejects (r = 0: p < .001; r = 3: p = .043); the diagnostics fail, so treat these as **descriptive**.

출처 / Sources: [`results/05_seoul_road_gsynth/seoul_road_effects.csv`](results/05_seoul_road_gsynth/seoul_road_effects.csv), [`diag_placebo_r0.csv`](results/05_seoul_road_gsynth/diag_placebo_r0.csv), [`diag_placebo_r3.csv`](results/05_seoul_road_gsynth/diag_placebo_r3.csv), 유형별 / by type: [`bytype/`](results/05_seoul_road_gsynth/bytype).

## 5. 폴더 안내 / Repository layout

```
code/      분석 스크립트 (폴더마다 README: 목적·입력·출력·실행 순서) / analysis scripts, one README per folder
  01_citywide_gsynth/      서울 내부 409 OD gsynth / within-Seoul OD gsynth
  02_heterogeneity/        반사실 대비 이질성 재집계 / heterogeneity re-aggregation
  03_road_scm/             여의도 연결도로 12개 방향 SCM / Yeouido road-link SCM
  04_yeouido_transit_scm/  여의도동 출발 대중교통 SCM (도너 79) / Yeouido transit SCM
  05_seoul_road_gsynth/    서울 전역 TOPIS 도로 gsynth / Seoul-wide road gsynth
  utils/                   공용 도구 / shared helpers
results/   집계 결과 CSV (위 폴더와 같은 번호) / aggregated CSV results, same numbering
figures/   논문 그림(thesis/), 분석별 진단 그림 / thesis figures and diagnostic plots
data/      자료 출처와 접근 안내 (원자료 없음) / data sources and access notes (no raw data)
docs/      GitHub Pages 사이트 / static website
scripts/   sync_docs_assets.py — figures·results를 docs/assets로 복사 / copies figures and results into docs/assets
```

## 6. 재현 방법 / How to reproduce

1. 원자료 접근 승인(데이터안전센터, 교통카드 OD 자료) 및 TOPIS·ITS 교통량 확보. Obtain access to the restricted OD data and the road counts.
2. 원자료와 중간 패널을 `data/restricted/`(또는 환경변수 `RAW_DIR`)에 둡니다. 각 스크립트 상단의 `RESTRICTED DATA REQUIRED` 주석에 필요한 파일 이름이 적혀 있습니다.
   Place inputs under `data/restricted/` (or set `RAW_DIR`). Each script lists its required files in a `RESTRICTED DATA REQUIRED` header.
3. 저장소 최상위에서 실행합니다. 출력은 `output/`(git 제외)에 생깁니다. 경로는 스크립트 상단의 `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`로 바꿀 수 있습니다.
   Run from the repo root; outputs go to `output/` (git-ignored). Override paths with `REPO_ROOT`, `RAW_DIR`, `OUT_DIR`.
   ```bash
   Rscript code/03_road_scm/run_nested53_full.R
   ```
4. 실행 순서는 각 `code/*/README.md`를 따릅니다. Follow the run order in each `code/*/README.md`.
5. 결과를 `results/`의 CSV와 비교합니다. Compare with the CSVs in `results/`.

원자료 없이 할 수 있는 것: `results/`의 집계값 확인, 그림 재사용, 사이트 열람. Without the raw data you can inspect all aggregated results and figures.

## 7. 한계 / Limitations

- **원자료 비공개**: 분석 1·2·4는 반출 제한 자료가 있어야 재실행됩니다. 공개된 것은 집계 결과뿐입니다. Analyses 1, 2 and 4 cannot be rerun without the restricted data.
- **요인 수 민감도(분석 1)**: r = 4(GMSPE 1-SE 규칙)에서 +1.568%이지만, MSPE 1-SE 규칙이 고른 r = 1에서는 +0.27%로 작아집니다 ([`results/01_citywide_gsynth/R2_r4_제출용_20261010/rank_sensitivity.csv`](results/01_citywide_gsynth/R2_r4_제출용_20261010/rank_sensitivity.csv)). The citywide effect is sensitive to the number of factors (r = 1 gives +0.27 %).
- **도로 SCM**: 12개 링크를 각각 검정하므로 다중비교 문제가 있고, p의 최소값이 1/54 ≈ .019로 제한됩니다. 도너는 서울 밖 도로라 지역 충격이 다를 수 있습니다. Multiple testing across 12 links; minimum attainable p is 1/54; donors are outside Seoul.
- **여의도 대중교통 SCM**: 단일 처치 단위이며, 시점 위약에서도 +1.6~2.4%의 양의 격차가 나타나 효과 크기 해석에 주의가 필요합니다. 가중치 사양(adhcv)에 따라 +5.53%, p = .038 ([`results/04_yeouido_transit_scm/adhcv79/summary_D79_adhcv.csv`](results/04_yeouido_transit_scm/adhcv79/summary_D79_adhcv.csv)). Single treated unit; in-time placebos show +1.6–2.4 % gaps.
- **서울 전역 도로 gsynth**: 사전 추세 진단 실패, 기술적 결과로만 사용. Pre-trend diagnostics fail; descriptive only.
- **도로 교통량 자료**: TOPIS·ITS 패널은 재배포 조건 확인 전까지 미포함. Road panels withheld until licence terms are confirmed.
- **누락된 보조 스크립트**: 일부 스크립트가 저장소에 없는 보조 파일을 `source()` 합니다(각 `code/*/README.md`의 "누락 의존성" 참조). Some scripts source helper files not in the repository; see each folder README.

## 8. 웹사이트 / Website

`docs/`는 빌드 도구 없는 정적 사이트입니다. GitHub Pages: **Settings → Pages → Source: Deploy from a branch → Branch `main`, folder `/docs`**.
`figures/`나 `results/`를 바꾸면 다음을 실행해 `docs/assets/`를 갱신합니다. After changing figures or results, refresh the site assets:

```bash
python3 scripts/sync_docs_assets.py
```

## 라이선스 / Licence

| 대상 / Content | 라이선스 / Licence |
|---|---|
| 코드: `code/`, `scripts/`, `docs/`의 HTML·CSS·JS / Code | [MIT](LICENSE) |
| 결과·그림: `results/`, `figures/`, `docs/assets/results/`, `docs/assets/figures/` / Results and figures | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

자세한 내용은 [`LICENSE`](LICENSE). 인용은 [`CITATION.cff`](CITATION.cff)를 따릅니다. See [`LICENSE`](LICENSE); cite via [`CITATION.cff`](CITATION.cff).
