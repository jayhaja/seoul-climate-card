# Data

## Not included (restricted)
- **Smart-card origin–destination (OD) records** (Ministry of Land, Infrastructure and Transport transit card data, accessed through a secure data centre). OD-level weekly counts and any file that reproduces them are excluded, including per-OD effect files (`OD_point_effects.csv`), origin membership tables, and observed/synthetic weekly paths for the Yeouido OD pair. Researchers can request access from the data provider. Figures that plot aggregated paths (including the Yeouido OD path and placebo figures in `figures/`) were cleared for export by the data centre; the underlying values are not distributed as data files. / `figures/`의 그림(여의도 OD 경로·위약 그림 포함)은 데이터안전센터 반출 승인 범위이며, 그 값은 데이터 파일로 배포하지 않습니다.

## Not yet included (licence to be confirmed)
- Road detector counts: Seoul TOPIS sites and donor links outside Seoul (national ITS link IDs). The analysis panels will be added once redistribution terms are confirmed.

## Public sources used
- Resident registration population (행정안전부 주민등록 인구통계)
- KTDB transport accessibility indicators; Seoul Institute 2019-BR-26 accessibility index
- Climate Card service coverage: Seoul Metropolitan Government announcements

## Running the code with restricted data
Place restricted / non-redistributed inputs under `data/restricted/` (git-ignored) or point the `RAW_DIR` environment variable at them. Each script lists the exact files it needs in a `RESTRICTED DATA REQUIRED` header; see also `code/*/README.md`.
원자료와 중간 패널은 `data/restricted/`(git 제외) 또는 환경변수 `RAW_DIR` 위치에 둡니다. 필요한 파일 이름은 각 스크립트 상단과 `code/*/README.md`에 있습니다.
