# Data

## Not included: raw records
- **Smart-card origin–destination (OD) records** (Ministry of Land, Infrastructure and Transport transit card data, accessed through a secure data centre). The original records are not in this repository and will not be added. Researchers can request access from the data provider.

## Processed outputs (cleared for export)
- Everything in `results/` and `figures/` was processed from the OD records and is within the data centre's export approval, including the Yeouido OD path and placebo figures.
- Processed data files within that approval (e.g. per-OD effects `OD_point_effects.csv`, origin membership tables, observed/synthetic weekly paths for the Yeouido OD) may also be redistributed; they are not yet included in this repository.

## Not yet included (licence to be confirmed)
- Road detector counts: Seoul TOPIS sites and donor links outside Seoul (national ITS link IDs). The analysis panels will be added once redistribution terms are confirmed.

## Public sources used
- Resident registration population statistics (Ministry of the Interior and Safety)
- KTDB transport accessibility indicators; Seoul Institute report 2019-BR-26 accessibility index
- Climate Card service coverage: Seoul Metropolitan Government announcements

## Running the code with restricted data
Place restricted / non-redistributed inputs under `data/restricted/` (git-ignored) or point the `RAW_DIR` environment variable at them. Each script lists the exact files it needs in a `RESTRICTED DATA REQUIRED` header; see also `code/*/README.md`. Input file names are kept as the data holder's original names (some are Korean); scripts give an English gloss for each.
