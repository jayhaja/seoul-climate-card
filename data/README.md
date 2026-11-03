# Data

## Not included (restricted)
- **Smart-card origin–destination (OD) records** (Ministry of Land, Infrastructure and Transport transit card data, accessed through a secure data centre). The original records are not in this repository and will not be added. Researchers can request access from the data provider. / 교통카드 OD 원자료는 저장소에 없으며 앞으로도 넣지 않습니다.

## Processed outputs (cleared for export) / 정제 결과물 (반출 승인)
- Everything in `results/` and `figures/` was processed from the OD records and is within the export approval of the data centre, including the Yeouido OD path and placebo figures. Processed data files within that approval (e.g. per-OD effects `OD_point_effects.csv`, origin membership tables, observed/synthetic weekly paths for the Yeouido OD) may also be redistributed; they are not yet included in this repository.
- `results/`와 `figures/`는 OD 원자료를 정제·집계한 결과로, 여의도 OD 경로·위약 그림을 포함해 모두 데이터안전센터 반출 승인 범위입니다. 승인 범위의 정제 데이터 파일(OD별 효과 `OD_point_effects.csv`, 출발지 구성표, 여의도 OD 관측·합성 주별 경로 등)도 배포할 수 있으며, 아직 저장소에 넣지 않았습니다.

## Not yet included (licence to be confirmed)
- Road detector counts: Seoul TOPIS sites and donor links outside Seoul (national ITS link IDs). The analysis panels will be added once redistribution terms are confirmed.

## Public sources used
- Resident registration population (행정안전부 주민등록 인구통계)
- KTDB transport accessibility indicators; Seoul Institute 2019-BR-26 accessibility index
- Climate Card service coverage: Seoul Metropolitan Government announcements

## Running the code with restricted data
Place restricted / non-redistributed inputs under `data/restricted/` (git-ignored) or point the `RAW_DIR` environment variable at them. Each script lists the exact files it needs in a `RESTRICTED DATA REQUIRED` header; see also `code/*/README.md`.
원자료와 중간 패널은 `data/restricted/`(git 제외) 또는 환경변수 `RAW_DIR` 위치에 둡니다. 필요한 파일 이름은 각 스크립트 상단과 `code/*/README.md`에 있습니다.
