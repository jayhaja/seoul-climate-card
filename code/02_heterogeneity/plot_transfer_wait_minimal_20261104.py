# plot_transfer_wait_minimal_20261104.py — 그림 6-4 최소형 (2026-11-04). 값은 plot_transfer_wait_en_20261101.py와 동일.
# 제목·부제·주석은 모두 원고 캡션으로 이동. 막대 2개 + 값 라벨만. 6장 다른 그림과 같은 테마(DejaVu Sans, 흑백·회색).
# 실행(repo): python3 code/02_heterogeneity/plot_transfer_wait_minimal_20261104.py
from pathlib import Path
import matplotlib
matplotlib.use('Agg'); import matplotlib.pyplot as plt
import os
BASE = Path(os.environ.get('REPO_ROOT', '.'))  # repo copy: writes to output/02_heterogeneity/ (published copy: figures/heterogeneity/)
plt.rcParams.update({'font.family': 'DejaVu Sans', 'pdf.fonttype': 42})
labels = ['One transfer', 'Two or more transfers']
values = [6.402767187912143, 19.393848478324593]   # minutes per trip, June–August 2023, trips within Seoul, all day
fig, ax = plt.subplots(figsize=(6.5, 2.6))
ax.barh([1, 0], values, height=0.55, color=['#b8c4cf', '#2f4858'], zorder=3)
for y, v in zip([1, 0], values):
    ax.text(v + 0.4, y, f'{v:.1f} min', va='center', fontsize=12, color='#222')
ax.set_yticks([1, 0], labels, fontsize=11)
ax.set_xlim(0, 23); ax.set_xticks([0, 5, 10, 15, 20]); ax.set_ylim(-0.6, 1.6)
ax.set_xlabel('Walking and waiting time per trip (minutes)', fontsize=10, labelpad=8)
ax.tick_params(length=0, labelsize=9, colors='#444')
ax.grid(axis='x', color='#e8e8e8', lw=0.8, zorder=0)
for s in ax.spines.values(): s.set_visible(False)
fig.tight_layout()
for ext in ['png', 'pdf']:
        (BASE / 'output/02_heterogeneity').mkdir(parents=True, exist_ok=True)
    fig.savefig(BASE / f'output/02_heterogeneity/fig6_4_transfer_wait_minimal_en.{ext}', dpi=300, facecolor='white')
print('saved output/02_heterogeneity/fig6_4_transfer_wait_minimal_en.{png,pdf}')
