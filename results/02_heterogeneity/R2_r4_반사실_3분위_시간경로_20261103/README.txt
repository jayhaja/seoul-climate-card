Counterfactual-relative effects, tertile sensitivity analysis, 2026-11-03
Effect (%) = 100 * sum(observed - counterfactual) / sum(counterfactual). Ratio of sums, not mean of individual percentages.
Thresholds: type-7 quantiles of all available origins, then population >=1000 filter. Boundaries fixed in bootstrap.
Waiting-time source: June-August 2023; includes walking and waiting during transfers; excludes initial boarding wait.
Reaggregates existing full-model point estimates and 1000 paired bootstrap draws. No model refitting.
Normal-approximation 95% CI; unadjusted p-values; contrasts in percentage points. All raw precision preserved.
Windows use observed post-treatment week order; final window has 10 weeks. No daily conversion required.
Resampled duplicate unit IDs retained for both gap and observed totals. Invalid denominator/empty-group draws excluded and counted in n_valid.
Source script: _review/hetero_cf_tertiles_timepath_20261103.R
