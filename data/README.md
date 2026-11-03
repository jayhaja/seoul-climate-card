# Data

## Not included: raw smart-card OD panel
- **Smart-card origin–destination (OD) records** (Ministry of Land, Infrastructure and Transport transit card data, accessed through a secure data centre). The source records and the full OD × week panel built from them are not in this repository and will not be added. Researchers can request access from the data provider.

## Included: processed outputs cleared for export
- Apart from the raw OD panel above, every data file the author holds is processed output and may be redistributed.
- Everything in `results/` and `figures/` was produced from the OD records and is within the data centre's export approval.
- This includes OD-level result files: the observed/synthetic weekly paths and placebo paths for the Yeouido OD (`path_D79_nested.csv`, `placebo_paths_D79_nested.csv`) and the per-OD effects for the 409 within-Seoul ODs (`OD_point_effects.csv`). These are approved for publication. *As of this writing they have not yet been uploaded to `results/`.*

## Road counts (redistributable)
- All road detector data held by the author (Seoul TOPIS sites, national ITS links) may be redistributed.
- Included: per-link weekly paths from the road SCM — observed and synthetic volumes for each treated link (`results/03_road_scm/unit_XX/path.csv`), placebo paths for the donor links (`placebo_paths.csv`) and leave-one-out paths (`loo_paths_twostep.csv`).
- Not yet uploaded: the full road analysis panels (Seoul TOPIS sites and non-Seoul ITS donor links with covariates).

## Public sources used
- Resident registration population statistics (Ministry of the Interior and Safety)
- KTDB transport accessibility indicators; Seoul Institute report 2019-BR-26 accessibility index
- Climate Card service coverage: Seoul Metropolitan Government announcements

## Running the code with restricted data
Place restricted inputs and not-yet-uploaded inputs under `data/restricted/` (git-ignored) or point the `RAW_DIR` environment variable at them. Each script lists the exact files it needs in a `RESTRICTED DATA REQUIRED` header; see also `code/*/README.md`. Input file names are kept as the data holder's original names (some are Korean); scripts give an English gloss for each.
