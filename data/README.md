# Data

All data files in this repository are cleared for publication, including the weekly smart-card OD panel. They were exported from the secure data centre with its approval. With them, analyses 1, 3, 4 and 5 can be rerun from this repository (see the main README for what still needs upstream files).

## `data/transit/` — smart-card OD panels

Source: Ministry of Land, Infrastructure and Transport (MOLIT) public-transport smart-card OD records, processed in the secure data centre and exported with approval. Population: resident registration statistics (Ministry of the Interior and Safety).

### `od_with_pop_sum_without_holiday.csv.gz`
Weekly OD panel (gzip; 161 MB uncompressed; R `readr::read_csv` and pandas read it directly).

- **Rows:** 633,189 OD × week rows; 5,905 OD units (`unit_id`); 427 units are within-Seoul ODs (`is_treat = 1`).
- **Period:** weeks starting 2023-01-02 to 2025-12-29 (151 weeks, Monday week start).
- **Holidays:** the six weeks containing major public holidays are removed (weeks of 2023-01-23, 2023-10-02, 2024-04-08, 2024-09-16, 2024-12-23, 2025-01-27). `week_index` (1–151) numbers the remaining weeks consecutively, so it is not a calendar-week count.
- **Missing values:** a unit appears only in weeks with recorded trips (median 151 weeks per unit, minimum 1). `dest` is empty for 6 rows whose destination was not recorded.

| Column | Description | Unit |
|---|---|---|
| `Unnamed: 0` | row number from export | — |
| `flow` | OD label, `"<origin> -> <destination>"` (Korean) | — |
| `week` | week start date (Monday) | date |
| `이용자수_주총합` | weekly total of users (sum of daily users over the week) | person-days |
| `환승건수_평균` | mean number of transfers per trip | transfers |
| `탑승시간_평균` | mean in-vehicle time per trip | seconds |
| `이용거리_평균` | mean trip distance | metres |
| `origin`, `dest` | origin (province/city, district, dong) and destination region (Korean) | — |
| `is_treat` | 1 = within-Seoul OD (card-eligible), 0 = control | — |
| `ym` | year-month of the week start | — |
| `origin_region`, `origin_sigungu`, `origin_dong` | origin province/city, district, dong (Korean) | — |
| `week_index` | consecutive index of non-holiday weeks (1–151) | — |
| `pop_total`, `pop_youth` | origin resident population, total and youth | persons |
| `youth_ratio` | `pop_youth / pop_total` | share |
| `pop_source` | `dong` = dong-level population; `sigungu` = district-level value used where dong data were missing | — |
| `unit_id` | OD unit identifier | — |

### `d_w30_no과천.rds`
Main gsynth panel for analysis 1 (R data frame; file name kept as used by the code: `w30` = week 30 removed, `no과천` = Gwacheon excluded).

- **Rows:** 133,650 = 1,350 OD units × 99 weeks; 409 treated (within-Seoul) and 941 control ODs.
- **Period:** `week_index` 1–100 of the OD panel above (weeks of 2023-01-02 to 2024-12-30) without week 30 (2023-07-31). Treatment starts at `week_index` 55 (2024-01-29): 53 pre and 46 post weeks.
- **Missing values:** none.

| Column | Description |
|---|---|
| `unit_id` | OD unit (joins to the OD panel) |
| `week_index` | week index as in the OD panel |
| `log_pc` | log users per capita (earlier specification; the reported model uses users and log population from the OD panel) |
| `D` | treatment indicator (within-Seoul OD × week ≥ 2024-01-29) |
| `use_pre` | pre-period mean weekly users of the OD (person-days); used for size groups |

### `df_scm_g.csv`
Panel for the Yeouido-dong transit SCM (analysis 4).

- **Rows:** 14,949 = 151 OD units × 99 weeks; the treated unit is `서울특별시 영등포구 여의도동 -> 서울특별시` (Yeouido-dong → Seoul).
- **Period:** weeks starting 2023-02-13 to 2024-12-30 (`week_index` 1–99 in this file).
- **Missing values:** `pop_dong` and `users_pc` are missing in 1,782 rows (units without dong-level population).

| Column | Description | Unit |
|---|---|---|
| `unit_name` | OD label (Korean) | — |
| `week`, `week_index`, `ym` | week start date, index (1–99), year-month | — |
| `users` | weekly users | person-days |
| `tranfer` | mean transfers per trip (column name as in the source) | transfers |
| `time` | mean in-vehicle time | seconds |
| `length` | mean trip distance | metres |
| `is_treat` | TRUE for Yeouido-dong | — |
| `unit_id` | unit identifier | — |
| `origin`, `region`, `sigungu`, `dong` | origin labels (Korean) | — |
| `pop_dong`, `pop_sgg` | origin dong and district population | persons |
| `users_sgg`, `users_pc` | users per district resident, users per dong resident | per person |
| `log_pop` | log origin population | — |

The SCM script takes the outcome (`이용자수_주총합`) from `od_with_pop_sum_without_holiday.csv.gz` and predictors from this file.

### `od_names_ko_en.csv`
Romanised names for all 5,905 OD units (`unit_id`, `flow`, `origin`, `dest` with `_en` columns; Revised Romanization, generated automatically). The panels keep their Korean name columns unchanged; adding English columns to the 161 MB panel would roughly add another 13 MB of text, so the names are provided once in this lookup table instead.

## `data/road/` — road detector panels

Source: Seoul TOPIS detector counts and national ITS link counts (weekday 06–09 h). Redistributable.

### `0628_6to10_df_with_new_covariates_fixed.csv`
Road SCM panel (analysis 3): 7,854 rows = 77 links × 102 weeks (2023-02-13 to 2025-01-20); 12 treated links around Yeouido. `traffic` is the weekday 06–09 h hourly volume (vehicles/hour; daily median → weekly median); 25 missing values. English names are in `route_en`, `road_en`, `unit_name_en`.

### `panel_seoul176_donor53_6to9.csv`
Seoul-wide road gsynth panel (analysis 5): 20,008 rows, 202 units (TOPIS Seoul sites and 53 non-Seoul donor links), weeks 2023-02-13 to 2025-01-20. `traffic` in vehicles/hour; 313 missing values (zeros were treated as missing upstream). Korean `roadName` and `path` are romanised in `site_names_ko_en.csv`.

## Processed outputs
`results/` and `figures/` hold model outputs, including OD-level result files (Yeouido OD paths and placebo paths, per-OD effects `OD_point_effects.csv`) and road SCM per-link paths.

## Other public sources used
- Resident registration population statistics (Ministry of the Interior and Safety)
- KTDB transport accessibility indicators; Seoul Institute report 2019-BR-26 accessibility index
- Climate Card service coverage: Seoul Metropolitan Government announcements

## Inputs still outside the repository
Some scripts also read intermediate files that are not uploaded yet (bootstrap chunks and covariate tables for analysis 2, the original road pipeline Rmds). Place them under `data/restricted/` (git-ignored) or point `RAW_DIR` at them; each script lists them in its header.
