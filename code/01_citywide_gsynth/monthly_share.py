# Monthly share of pass users who were "additional" travelers, manuscript-version estimate (created 2026-11-12).
# Input: ../gsynth_Mangwol_only_full_20261104/weekly_estimates_CI.csv (key all409, metric ATT = additional person-days per OD pair per week;
#        manuscript main model, 409 treated OD pairs; post-week mean x 409 = 148,327 person-days/week).
# Pass users: average daily Climate Card users by month (SI Table S1, Seoul Metropolitan Government).
# Daily additional people = weekly person-days / weekday count. Two versions: /5 (simple) and / non-holiday weekdays in that week
# (2024 Korean public holidays, incl. the Apr 10 election and the Oct 1 temporary holiday). Weeks are assigned to the month of their Monday;
# the week of 29 Jan is assigned to February. Caveats: weekday mornings within Seoul only; assumes every additional traveler used the pass.
import pandas as pd, numpy as np
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
D = ROOT / 'results' / '01_citywide_gsynth'
w = pd.read_csv(D / 'weekly_estimates_CI_manuscript.csv')
w = w[(w.key == 'all409') & (w.metric == 'ATT')].copy()
w['date'] = pd.to_datetime(w.date)
post = w[w.date >= '2024-01-29'].copy()
post['total'] = post.estimate * 409
print('post weeks', len(post), 'mean weekly total', round(post.total.mean()))
hol = pd.to_datetime(['2024-02-09','2024-02-12','2024-03-01','2024-04-10','2024-05-06','2024-05-15','2024-06-06','2024-08-15',
                      '2024-09-16','2024-09-17','2024-09-18','2024-10-01','2024-10-03','2024-10-09','2024-12-25'])
def wd(d):
    days = pd.date_range(d, periods=5); return int((~days.isin(hol)).sum())
post['wd'] = post.date.map(wd)
post['month'] = post.date.dt.month.where(post.date >= '2024-02-01', 2)
post['day5'] = post.total / 5; post['dayH'] = post.total / post.wd.clip(lower=1)
users = {2:231393,3:387742,4:470615,5:476739,6:472170,7:498142,8:498545,9:509877,10:560787,11:589650,12:573843}
g = post.groupby('month').agg(weeks=('total','size'), add5=('day5','mean'), addH=('dayH','mean')).reset_index()
g['pass_users'] = g.month.map(users)
g['share5_%'] = 100*g.add5/g.pass_users; g['shareH_%'] = 100*g.addH/g.pass_users
g['existing5'] = g.pass_users - g.add5
out = g.round({'add5':-2,'addH':-2,'existing5':-2,'share5_%':1,'shareH_%':1})
print(out.to_string(index=False)); (D / 'monthly_additional_share').mkdir(exist_ok=True); out.to_csv(D / 'monthly_additional_share' / 'monthly_share.csv', index=False)
