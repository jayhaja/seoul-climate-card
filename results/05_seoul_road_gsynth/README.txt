Seoul-wide road gsynth: 149 TOPIS sites (>=90% weekly coverage) treated from week 51 (2024-01-29), 53 non-Seoul donor links from the road SCM main spec.
Outcome: weekday non-holiday 06-09h hourly volume, daily median -> weekly median (vehicles/hour). Post weeks 51-96.
Effects: mean gap (veh/h) and 100*sum(gap)/sum(counterfactual). Groups by site type (A downtown, B city boundary, C Han bridges, D arterials, F urban expressways); Yeouido-linked sites flagged.
Point estimates for r=1..4 and CV; bootstrap only with NB>0 (fect internal, CV-selected r).
Manuscript Sec. 2.4 pooled estimate (GSC, r = 3, 53 outside-Seoul controls, 200 bootstrap draws, seed 20260731): count-weighted mean of the weekly ATT in diag_event_att_r3.csv over posttreatment weeks (rel_week >= 1, 44 weeks) = sum(ATT x count) / sum(count) = -35.914 veh/h (unweighted mean -36.09). The 95% CI [-80.82, 8.99] and p = .117 are the fect overall ATT from diag_fits_r3.rds (not included; large). diag_placebo_r3.csv: final-four-week placebo for the same model (+49.83, p = .043).
expressway_allday_scm/: nine urban expressways, all-day SCM (SI Appendix D); see the README in that folder.
