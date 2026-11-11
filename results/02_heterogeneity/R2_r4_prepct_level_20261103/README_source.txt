Chapter 6 heterogeneity, Hainmueller-style metric (2026-11-03).
Level effect = sum(observed - counterfactual) / (weeks x ODs in group): additional weekly ridership per OD pair (person-days), same unit as the gsynth ATT.
Pre-treatment % = 100 x level effect / group mean weekly ridership per OD over the 53 pretreatment weeks (observed).
Groups: pretreatment tertiles (membership.csv of R2_r4_반사실_3분위_시간경로_20261103), origins with >= 1,000 residents, boundaries fixed in bootstrap.
CIs: 1,000 paired OD bootstrap draws re-aggregated (no refit); normal approximation; duplicated ODs in a draw count in numerator and denominator.
Level effects scale with group size of ODs; compare groups on the % column, report level for the original unit.
