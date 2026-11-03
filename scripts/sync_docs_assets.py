#!/usr/bin/env python3
"""Copy figures/ and results/ CSVs into docs/assets/ and write docs/assets/manifest.json.

GitHub Pages serving `main` /docs publishes only the docs/ folder, so `../figures`
and `../results` are not reachable from the site. Run this after any change to
figures/ or results/:

    python3 scripts/sync_docs_assets.py

Standard library only. PDFs and HTML in results/ are not copied (CSV only).
"""
import csv
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS_ASSETS = ROOT / "docs" / "assets"
FIG_SRC, FIG_DST = ROOT / "figures", DOCS_ASSETS / "figures"
RES_SRC, RES_DST = ROOT / "results", DOCS_ASSETS / "results"
IMG_EXT = {".jpg", ".jpeg", ".png"}

ANALYSIS_BY_RESULTS_DIR = {
    "01_citywide_gsynth": "citywide",
    "02_heterogeneity": "heterogeneity",
    "03_road_scm": "road_scm",
    "04_yeouido_transit_scm": "yeouido",
    "05_seoul_road_gsynth": "seoul_road",
}

# Road unit names (Korean, from results/03_road_scm/summary/road_cf.csv).
def road_names():
    names = {}
    p = RES_SRC / "03_road_scm" / "summary" / "road_cf.csv"
    with p.open(encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            names[int(row["unit"])] = row["name"]
    return names

ROAD_KIND = {
    "scm_path": ("경로(관측 vs 합성)", "Path (observed vs synthetic)"),
    "scm_gap": ("격차", "Gap"),
    "rmspe_ratio": ("RMSPE 비율 순위", "RMSPE-ratio ranking"),
    "placebo_gaps": ("위약 격차", "Placebo gaps"),
    "placebo_hist": ("RMSPE 비율 히스토그램", "RMSPE-ratio histogram"),
    "loo": ("LOO(도너 1개 제외)", "Leave-one-out"),
    "in_time_path": ("시점 위약", "In-time placebo"),
}
TAU5_NOTE = (
    "원고용 그림: 사전 RMSPE가 처치 단위의 5배 이하인 위약만 표시. "
    "p값은 표시 여부와 무관하게 위약 전체(처치 단위 포함, 사전 적합도 필터 없음) 기준.",
    "Manuscript figure: only placebos with pre-RMSPE ≤ 5× the treated unit are drawn. "
    "The p-value is computed over all placebos (treated unit included, no pre-fit filter), not only those shown.",
)
TAU5_SENS_NOTE = (
    "민감도 분석: 사전 RMSPE가 처치 단위의 5배 이하인 위약만 사용. 본 결과의 p값은 위약 전체 기준.",
    "Sensitivity: only placebos with pre-RMSPE ≤ 5× the treated unit. The headline p-value uses all placebos.",
)
ALL_NOTE = (
    "위약 전체(필터 없음) 표시. p값 계산 기준과 동일한 집합.",
    "All placebos shown (no filter): the same set used for the p-value.",
)


def fig_meta(rel: Path, rnames):
    parts = rel.parts
    name = rel.stem
    m = {"src": "assets/figures/" + rel.as_posix(), "analysis": "other",
         "site": "", "kind_ko": name, "kind_en": name, "note_ko": "", "note_en": "",
         "group": parts[0]}
    if parts[0] == "road_scm":
        unit = int(parts[1])
        m.update(analysis="road_scm", site=f"{unit:02d} {rnames.get(unit, '')}")
        km = re.match(r"\d+\.([a-z_]+?)_\d+_", name)
        if km and km.group(1) in ROAD_KIND:
            m["kind_ko"], m["kind_en"] = ROAD_KIND[km.group(1)]
    elif parts[0] == "yeouido_transit_scm":
        m.update(analysis="yeouido", site="여의도동 출발 / Yeouido-dong")
        km = re.match(r"\d+\.([a-z_]+?)_D79", name)
        if km and km.group(1) in ROAD_KIND:
            m["kind_ko"], m["kind_en"] = ROAD_KIND[km.group(1)]
        fk = re.search(r"_f(\d+)$", name)
        if fk:
            m["kind_ko"] += f" (가짜 시점 {fk.group(1)}주)"
            m["kind_en"] += f" (fake start week {fk.group(1)})"
    elif parts[0] == "seoul_road_gsynth":
        m.update(analysis="seoul_road")
        tm = re.match(r"gap_([A-F])_(index|level)_r(\d)", name)
        if tm:
            m["site"] = f"유형 {tm.group(1)} / Type {tm.group(1)}"
            m["kind_ko"] = f"격차 ({'지수' if tm.group(2)=='index' else '수준'}, r={tm.group(3)})"
            m["kind_en"] = f"Gap ({tm.group(2)}, r={tm.group(3)})"
        dm = re.match(r"diag_(equiv|gap|placebo)_r(\d)", name)
        if dm:
            m["site"] = "전체 / All sites"
            lab = {"equiv": ("동등성 검정", "Equivalence test"), "gap": ("격차", "Gap"),
                   "placebo": ("위약 시점 검정", "Placebo-period test")}[dm.group(1)]
            m["kind_ko"], m["kind_en"] = f"{lab[0]} (r={dm.group(2)})", f"{lab[1]} (r={dm.group(2)})"
    elif parts[0] == "thesis":
        sec = parts[1]
        m["site"] = sec
        if sec.startswith("부록A-1_Road"):
            m["analysis"] = "road_scm"
            u = int(sec[len("부록A-1_Road"):][:2])
            m["site"] = f"{u:02d} {rnames.get(u, '')}"
        elif sec.startswith("부록A-2"):
            m.update(analysis="yeouido", site="여의도동 출발 / Yeouido-dong")
        elif sec.startswith("부록B"):
            m.update(analysis="citywide", site="부록 B gsynth 진단 / Appendix B diagnostics")
        else:  # 본문 그림
            m["site"] = "본문 / Main text"
            if name.startswith("그림4-2"):
                m["analysis"] = "road_scm"
            elif name.startswith("그림5"):
                m["analysis"] = "citywide"
            elif name.startswith("그림6"):
                m["analysis"] = "heterogeneity"
        m["kind_ko"] = m["kind_en"] = name
        m["thesis"] = True
    if name.endswith("_tau5") and "placebo_gaps" in name:
        m["note_ko"], m["note_en"] = TAU5_NOTE
        m["kind_ko"] += " · 원고용(≤5배 표시)"
        m["kind_en"] += " · manuscript (≤5× shown)"
    elif name.endswith("_tau5") and m["analysis"] in ("road_scm", "yeouido"):
        m["note_ko"], m["note_en"] = TAU5_SENS_NOTE
        m["kind_ko"] += " · 민감도(≤5배)"
        m["kind_en"] += " · sensitivity (≤5×)"
    elif name.endswith("_all") and m["analysis"] in ("road_scm", "yeouido"):
        m["note_ko"], m["note_en"] = ALL_NOTE
        m["kind_ko"] += " · 전체"
        m["kind_en"] += " · all placebos"
    return m


def main():
    rnames = road_names()
    for d in (FIG_DST, RES_DST):
        if d.exists():
            shutil.rmtree(d)
    figs = []
    for p in sorted(FIG_SRC.rglob("*")):
        if p.suffix.lower() in IMG_EXT:
            rel = p.relative_to(FIG_SRC)
            (FIG_DST / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, FIG_DST / rel)
            figs.append(fig_meta(rel, rnames))
    tables = []
    for p in sorted(RES_SRC.rglob("*.csv")):
        rel = p.relative_to(RES_SRC)
        (RES_DST / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, RES_DST / rel)
        with p.open(encoding="utf-8-sig", newline="") as f:
            n = sum(1 for _ in csv.reader(f)) - 1
        tables.append({"path": "assets/results/" + rel.as_posix(),
                       "repo_path": "results/" + rel.as_posix(),
                       "analysis": ANALYSIS_BY_RESULTS_DIR.get(rel.parts[0], "other"),
                       "rows": n})
    out = {"figures": figs, "tables": tables}
    (DOCS_ASSETS / "manifest.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"copied {len(figs)} figures, {len(tables)} CSV tables -> {DOCS_ASSETS}")


if __name__ == "__main__":
    main()
