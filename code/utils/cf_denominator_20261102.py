# 증가율 분모를 반사실 대비로 통일 (2026-11-02). 저장된 경로 파일만 읽음, 재추정 없음. 위약 p는 RMSPE 비율 순위라 분모와 무관(변경 없음).
#  반사실 대비 % = 100 × 구간 평균 gap / 구간 평균 synthetic.  (기존: ÷ 처치 전 평균 actual)
#  도로: nested 53 run, 공사 3지점(1,2,10)은 path_main(51–72), 나머지 path_full(51–96). 46주 = week_index 51–96.
#  여의도: SCM_여의도_nested/path_D81_nested.csv, LOO(V 고정)와 ADH CV는 ATT만 저장 → 반사실 = 처치 후 실제 평균 − ATT.
# 출력: OUT_DIR = output/utils/반사실대비_통일_20261102/{road_cf.csv, road_windows_cf.csv, road_loo_cf.csv, yeouido_cf.csv}
# Run (from repo root): python3 code/utils/cf_denominator_20261102.py
# 입력 (intermediate outputs of other scripts in this repo; no raw data read directly):
#   ROAD_RUN_DIR/unit_XX/path_main.csv | path_full.csv, loo_paths_main.csv | loo_paths_full.csv
#       <- code/03_road_scm/run_nested53_full.R (run folder v4_stdv_ex107_201_nested53_20261031-131153)
#   YEOUIDO_DIR/path_D81_nested.csv, loo_sensitivity_D81_nested_vfix.csv, V선택_비교.csv
#       <- code/04_yeouido_transit_scm/SCM_여의도_nested_사전전체.Rmd
#       (Yeouido paths are derived from restricted smart-card data; not distributed)
import os, numpy as np, pandas as pd
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT = os.environ.get('REPO_ROOT', '.')                                  # run from repo root
RAW_DIR   = os.environ.get('RAW_DIR', os.path.join(REPO_ROOT, 'data/restricted'))   # restricted data required (not read directly here)
OUT_DIR   = os.environ.get('OUT_DIR', os.path.join(REPO_ROOT, 'output', 'utils/반사실대비_통일_20261102'))
# OUT_DIR-style locations of the producing scripts (03_road_scm, 04_yeouido_transit_scm)
ROAD_RUN_DIR = os.environ.get('ROAD_RUN_DIR', os.path.join(REPO_ROOT, 'output', '03_road_scm', 'runs', 'v4_stdv_ex107_201_nested53_20261031-131153'))
YEOUIDO_DIR  = os.environ.get('YEOUIDO_DIR', os.path.join(REPO_ROOT, 'output', '04_yeouido_transit_scm', 'SCM_여의도_nested'))
run = ROAD_RUN_DIR
yd = YEOUIDO_DIR
out = OUT_DIR; os.makedirs(out, exist_ok=True)
names = {1:'경인로 유출',2:'경인로 유입',3:'노들로 북행',4:'노들로 남행',5:'마포대교 남행',6:'마포대교 북행',
         7:'서강대교 남행',8:'서강대교 북행',9:'여의대방로 남행',10:'여의대방로 북행',11:'원효대교 남행',12:'원효대교 북행'}
pct = lambda g, base: round(100 * g / base, 2)

R, W, L = [], [], []
for u, nm in names.items():
    d = f'{run}/unit_{u:02d}'; tag = 'main' if os.path.exists(f'{d}/path_main.csv') else 'full'
    end = 72 if tag == 'main' else 96
    p = pd.read_csv(f'{d}/path_{tag}.csv'); pre = p[p.period == 'pre']
    post = p[(p.week_index >= 51) & (p.week_index <= end)]
    R.append(dict(unit=u, name=nm, weeks=f'51-{end}', att=round(post.gap.mean(), 1), pct_pre=pct(post.gap.mean(), pre.actual.mean()),
                  pct_cf=pct(post.gap.mean(), post.synthetic.mean())))
    for w, (a, b) in {'early': (51, 62), 'late': (63, end), 'first22': (51, 72)}.items():
        g = p[(p.week_index >= a) & (p.week_index <= b)]
        W.append(dict(unit=u, name=nm, window=w, weeks=f'{a}-{b}', pct_pre=pct(g.gap.mean(), pre.actual.mean()), pct_cf=pct(g.gap.mean(), g.synthetic.mean())))
    # 월별(처치 후 주를 달력 월로): week_index→날짜 매핑이 경로에 없으면 생략
    lp = f'{d}/loo_paths_{tag}.csv'
    if os.path.exists(lp):
        q = pd.read_csv(lp); v = []
        for o, z in q.groupby('omitted'):
            zz = z[(z.week_index >= 51) & (z.week_index <= end)]; v.append(100 * zz.gap.mean() / zz.synthetic.mean())
        L.append(dict(unit=u, name=nm, loo_cf_min=round(min(v), 2), loo_cf_max=round(max(v), 2), n_loo=len(v)))
pd.DataFrame(R).to_csv(f'{out}/road_cf.csv', index=False)
pd.DataFrame(W).to_csv(f'{out}/road_windows_cf.csv', index=False)
pd.DataFrame(L).to_csv(f'{out}/road_loo_cf.csv', index=False)
print(pd.DataFrame(R).to_string(index=False)); print(pd.DataFrame(W).to_string(index=False)); print(pd.DataFrame(L).to_string(index=False))

y = pd.read_csv(f'{yd}/path_D81_nested.csv'); pre = y[y.period == 'pre']; post = y[y.period == 'post']; A = post.actual.mean()
same = post[(post.week >= '2024-01-29') & (post.week <= '2024-06-24')]
loo = pd.read_csv(f'{yd}/loo_sensitivity_D81_nested_vfix.csv'); lc = 100 * loo.ATT / (A - loo.ATT); lp_ = 100 * loo.ATT / pre.actual.mean()
vs = pd.read_csv(f'{yd}/V선택_비교.csv'); adh = vs.loc[vs.iloc[:, 0] == 'ADH CV', 'ATT'].iloc[0]
Y = [dict(item='46주', pct_pre=pct(post.gap.mean(), pre.actual.mean()), pct_cf=pct(post.gap.mean(), post.synthetic.mean())),
     dict(item='같은 기간 1/29~6/24 (%d주)' % len(same), pct_pre=pct(same.gap.mean(), pre.actual.mean()), pct_cf=pct(same.gap.mean(), same.synthetic.mean())),
     dict(item='LOO(V 고정) 최소', pct_pre=round(lp_.min(), 2), pct_cf=round(lc.min(), 2)),
     dict(item='LOO(V 고정) 최대', pct_pre=round(lp_.max(), 2), pct_cf=round(lc.max(), 2)),
     dict(item='ADH CV', pct_pre=pct(adh, pre.actual.mean()), pct_cf=pct(adh, A - adh))]
pd.DataFrame(Y).to_csv(f'{out}/yeouido_cf.csv', index=False); print(pd.DataFrame(Y).to_string(index=False))
