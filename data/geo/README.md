# data/geo — Seoul boundary files

| File | Contents |
|---|---|
| `seoul_neighborhoods_geo_simple.json` | 467 legal dongs (법정동) of Seoul, simplified GeoJSON. Properties: `EMD_CD` (8-digit code; first 5 digits = district code), `EMD_KOR_NM`, `EMD_ENG_NM` |
| `seoul_municipalities_geo_simple.json` | 25 districts (자치구), simplified GeoJSON. Properties: `SIG_CD`, `SIG_KOR_NM`, `SIG_ENG_NM` |

**Source:** [southkorea/seoul-maps](https://github.com/southkorea/seoul-maps) (`juso/2015/json/`), © Lucy Park and contributors, licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). Original data: JUSO (juso.go.kr) Seoul administrative boundaries, 2015. Files are copied unchanged.

These files are used by `scripts/build_map_data.py` to draw the effect map on the website. Boundaries are from 2015; dong names in the smart-card data were matched on district + dong name.
