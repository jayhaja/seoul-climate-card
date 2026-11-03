## maps_r4_district_20261011.py — r4 원값 모형(users ~ D + log_pop, r=4) 출발 자치구별 총량 효과 지도 (KO·EN)
## 입력: scm_results/R2_r4_자치구_지도데이터_20261011/district_effects.csv (effect_pct = 100·Σ격차/Σ반사실, 점추정만)
## 경계: maps_EN.py 와 동일(0702/읍면동/emd.shp → 공시지가 csv 의 gu 로 dissolve; 둘 다 읽기만 함)
import os, pandas as pd, geopandas as gpd, matplotlib.pyplot as plt, matplotlib as mpl
from matplotlib import font_manager as fm
BASE = os.environ.get("BASE", "/Users/maeg")
P0702 = f"{BASE}/Thesis/0614/public.transportation/0702"; TS = f"{BASE}/Documents/thesis_summary"
SHP = f"{P0702}/읍면동/emd.shp"; GUCSV = f"{P0702}/집중지수_0727/공시지가_법정동_2023.csv"
SRC = f"{TS}/scm_results/R2_r4_자치구_지도데이터_20261011/district_effects.csv"; OUT = f"{TS}/figures"
for p in ["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", "/System/Library/Fonts/AppleSDGothicNeo.ttc"]:
    if os.path.exists(p): fm.fontManager.addfont(p); mpl.rcParams["font.family"] = fm.FontProperties(fname=p).get_name(); break
mpl.rcParams["axes.unicode_minus"] = False
ROMAN = {"종로구":"Jongno","중구":"Jung","용산구":"Yongsan","성동구":"Seongdong","광진구":"Gwangjin","동대문구":"Dongdaemun","중랑구":"Jungnang",
 "성북구":"Seongbuk","강북구":"Gangbuk","도봉구":"Dobong","노원구":"Nowon","은평구":"Eunpyeong","서대문구":"Seodaemun","마포구":"Mapo",
 "양천구":"Yangcheon","강서구":"Gangseo","구로구":"Guro","금천구":"Geumcheon","영등포구":"Yeongdeungpo","동작구":"Dongjak","관악구":"Gwanak",
 "서초구":"Seocho","강남구":"Gangnam","송파구":"Songpa","강동구":"Gangdong"}
lp = pd.read_csv(GUCSV, dtype={"emd_cd": str})
shp = gpd.read_file(SHP, encoding="cp949"); shp = shp[shp.EMD_CD.astype(str).str.startswith("11")].copy()
shp["emd_cd"] = shp.EMD_CD.astype(str); shp = shp.set_crs(5179, allow_override=True); shp["geometry"] = shp.geometry.buffer(0)
shp = shp.merge(lp[["emd_cd", "gu"]], on="emd_cd", how="left")
gu = shp.dissolve(by="gu").reset_index()[["gu", "geometry"]]; gu["geometry"] = gu.geometry.buffer(2).buffer(-2)
gu = gpd.GeoDataFrame(gu, geometry="geometry", crs=5179).to_crs(4326)
e = pd.read_csv(SRC, encoding="utf-8-sig")
gu = gu.merge(e[["district_name", "effect_pct", "gap_weekly_total", "n_od"]], left_on="gu", right_on="district_name", how="left")
assert len(gu) == 25 and gu.effect_pct.notna().all(), "자치구 결합 실패"
vmin, vmax = 0, float(gu.effect_pct.max())
for lang in ["KO", "EN"]:
    fig, ax = plt.subplots(figsize=(9, 7.6))
    gu.plot(column="effect_pct", cmap="YlGnBu", vmin=vmin, vmax=vmax, linewidth=.6, edgecolor="grey", ax=ax, legend=True,
            legend_kwds={"label": "총량 대비 효과 (%)" if lang == "KO" else "Effect relative to counterfactual total (%)", "shrink": .7})
    for _, r in gu.iterrows():
        c = r.geometry.representative_point(); name = r.gu if lang == "KO" else ROMAN[r.gu]
        ax.annotate(f"{name}\n{r.effect_pct:.1f}", (c.x, c.y), ha="center", va="center", fontsize=6.6 if lang == "KO" else 6.2,
                    color="white" if r.effect_pct > 0.75 * vmax else "black")
    ax.set_title("출발 자치구별 대중교통 이용 변화 (원값 모형, r=4)" if lang == "KO" else
                 "Change in morning public transport use by origin district (level model, r=4)", fontsize=12)
    note = ("효과 = 100×Σ(실제−반사실)/Σ반사실, 해당 구 출발→서울 OD 합산, 사후 46주. 점추정(신뢰구간 없음). 서울 전체 +1.57%."
            if lang == "KO" else
            "Effect = 100×Σ(observed−counterfactual)/Σcounterfactual over OD pairs originating in each district, 46 post weeks.\nPoint estimates only (no intervals). Seoul total +1.57%.")
    ax.text(0.0, -0.03, note, transform=ax.transAxes, fontsize=7.2, va="top", wrap=True)
    ax.set_axis_off(); plt.tight_layout()
    f = f"{OUT}/fig_map_r4_district_{lang}.png"; plt.savefig(f, dpi=300, bbox_inches="tight"); plt.close(); print("saved", f)
print(gu.sort_values("effect_pct", ascending=False)[["gu", "effect_pct", "gap_weekly_total", "n_od"]].to_string(index=False))
