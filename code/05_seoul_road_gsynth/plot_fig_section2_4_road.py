# Manuscript Fig. 4 — Section 2.4 (Road traffic across Seoul), created 2026-11-10
# Run (from repo root): python3 code/05_seoul_road_gsynth/plot_fig_section2_4_road.py  → output/05_seoul_road_gsynth/fig_section2_4_road.png
# Published copy: figures/seoul_road_gsynth/fig4_section2_4_road.png
# A: weekly gaps, pooled 149 Seoul monitoring sites, weekday 06-09h, GSC r=3, 53 outside-Seoul donors (diag_event_att_r3.csv;
#    count-weighted post mean = -35.91 veh/h, matches manuscript). rel_week 1 = week beginning 2024-01-29; 0 = last pretreatment week.
# B: average effect by road type, r=3 (bytype/bytype_level_min.csv) and pooled (manuscript: -35.91 [-80.82, 8.99], p = .117).
import pandas as pd, matplotlib.pyplot as plt
from pathlib import Path
import os
ROOT = Path(os.environ.get('REPO_ROOT', '.'))
D = ROOT / 'results' / '05_seoul_road_gsynth'          # inputs (published results)
OUT = ROOT / 'output' / '05_seoul_road_gsynth'; OUT.mkdir(parents=True, exist_ok=True)
ev = pd.read_csv(D / 'diag_event_att_r3.csv')
bt = pd.read_csv(D / 'bytype' / 'bytype_level_min.csv')

fig, (a, b) = plt.subplots(1, 2, figsize=(12, 4.6), gridspec_kw=dict(width_ratios=[1.6, 1]))
pre, post = ev[ev.rel_week <= 0], ev[ev.rel_week >= 1]
for g, c in ((pre, '#9a9a9a'), (post, 'black')):
    a.errorbar(g.rel_week, g.ATT, yerr=[g.ATT - g['CI.lower'], g['CI.upper'] - g.ATT], fmt='o', ms=3, color=c, ecolor=c, elinewidth=0.7, capsize=0)
a.axhline(0, color='#555555', lw=0.8); a.axvline(0.5, color='#d62728', ls='--', lw=1)
a.axhline(-35.91, xmin=(0.5 - ev.rel_week.min()) / (ev.rel_week.max() - ev.rel_week.min() + 1), color='#2f6fdf', lw=1.2)
a.text(-48, -175, 'Blue line: posttreatment average, −35.9 veh/h\n(95% CI −80.8 to 9.0; p = .117)', ha='left', va='top', color='#2f6fdf', fontsize=8.5)
a.set_xlabel('Weeks relative to policy introduction (week 1 begins January 29, 2024)')
a.set_ylabel('Gap (vehicles per hour)')
a.set_title('A. Weekly gaps, 149 Seoul monitoring sites', loc='left', fontsize=11)

lab = {'A': 'Downtown (21)', 'B': 'City boundary (31)', 'C': 'Han River bridges (39)', 'D': 'Arterial roads (38)', 'F': 'Urban expressways (20)'}
rows = [('All sites (149)', -35.91, -80.82, 8.99, 0.117)] + [(lab[r.type], r.ATT, r.lo, r.hi, r.p) for r in bt.itertuples()]
for i, (l, est, lo, hi, p) in enumerate(rows[::-1]):
    col = 'black' if l.startswith('All') else ('#d62728' if p < 0.05 else '#555555')
    b.errorbar(est, i, xerr=[[est - lo], [hi - est]], fmt='s' if l.startswith('All') else 'o', color=col, capsize=3, ms=6)
    b.text(max(hi, 80) + 6, i, f'p = {p:.3f}'.replace('0.', '.'), va='center', fontsize=8.5)
b.set_yticks(range(len(rows))); b.set_yticklabels([r[0] for r in rows[::-1]], fontsize=9)
b.axvline(0, color='#555555', lw=0.8); b.set_xlim(-130, 115)
b.set_xlabel('Average effect (vehicles per hour, 95% CI)')
b.set_title('B. Average effects by road type', loc='left', fontsize=11)
for ax in (a, b):
    ax.spines[['top', 'right']].set_visible(False)
plt.tight_layout()
out = OUT / 'fig_section2_4_road.png'; plt.savefig(out, dpi=300, bbox_inches='tight'); print(out)
