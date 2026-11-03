#!/usr/bin/env python3
"""Build the data for the website's Seoul effect map (docs/assets/map/).

Joins the per-OD effects (each within-Seoul OD = one origin dong -> Seoul) to the
legal-dong boundaries in data/geo/, and aggregates to districts as a ratio of sums.

    python3 scripts/build_map_data.py

Standard library only.
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEO = ROOT / "data" / "geo"
OUT = ROOT / "docs" / "assets" / "map"
EFF = ROOT / "results" / "01_citywide_gsynth" / "R2_r4_submission_20261010" / "OD_point_effects.csv"
NAMES = ROOT / "data" / "transit" / "od_names_ko_en.csv"


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def main():
    dong = json.loads((GEO / "seoul_neighborhoods_geo_simple.json").read_text(encoding="utf-8"))
    gu = json.loads((GEO / "seoul_municipalities_geo_simple.json").read_text(encoding="utf-8"))
    gu_code = {f["properties"]["SIG_KOR_NM"]: f["properties"]["SIG_CD"] for f in gu["features"]}
    gu_en = {f["properties"]["SIG_CD"]: f["properties"]["SIG_ENG_NM"] for f in gu["features"]}
    emd = {(f["properties"]["EMD_CD"][:5], f["properties"]["EMD_KOR_NM"]): f["properties"]["EMD_CD"] for f in dong["features"]}
    names = {r["unit_id"]: r for r in csv.DictReader(NAMES.open(encoding="utf-8"))}

    rows, unmatched = {}, []
    for r in csv.DictReader(EFF.open(encoding="utf-8-sig")):
        n = names[r["unit_id"]]
        parts = n["origin"].split()            # 서울특별시 <gu> <dong>
        g, d = parts[1], parts[2]
        code = emd.get((gu_code.get(g, ""), d))
        if code is None:
            unmatched.append(n["origin"])
            continue
        en = n["origin_en"].split()
        rows[code] = {"unit_id": int(r["unit_id"]), "gu": g, "dong": d, "gu_en": gu_en[gu_code[g]], "dong_en": en[-1],
                      "effect_pct": num(r["effect_pct"]), "gap": num(r["gap"]), "counterfactual": num(r["counterfactual"]),
                      "use_pre": num(r["use_pre"])}
    agg = {}
    for v in rows.values():
        c = gu_code[v["gu"]]
        a = agg.setdefault(c, {"gu": v["gu"], "gu_en": gu_en[c], "gap": 0.0, "counterfactual": 0.0, "n": 0})
        a["gap"] += v["gap"]; a["counterfactual"] += v["counterfactual"]; a["n"] += 1
    for a in agg.values():
        a["effect_pct"] = 100 * a["gap"] / a["counterfactual"]
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "dong.geojson").write_text(json.dumps(dong, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (OUT / "gu.geojson").write_text(json.dumps(gu, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (OUT / "effects.json").write_text(json.dumps({"dong": rows, "gu": agg}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"matched {len(rows)} ODs to dong boundaries; unmatched {len(unmatched)}: {unmatched}; districts {len(agg)}")


if __name__ == "__main__":
    main()
