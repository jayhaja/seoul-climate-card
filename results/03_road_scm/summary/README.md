# results/03_road_scm/summary — 현재 파일과 이전 세대 / current vs earlier-generation files

이 폴더에는 두 번의 실행 결과가 섞여 있습니다. 원고의 본 결과는 **Abadie et al. (2015) 사양** 실행입니다. 이 실행에서는 위약마다 처치 링크를 도너 풀에 넣고, 사전 적합도 필터 없이 p를 계산합니다.
This folder mixes outputs from two runs. The headline results come from the **Abadie et al. (2015) run**: the treated link joins each placebo's donor pool, and p is computed with no pre-fit filter.

## 현재 (본 결과) / Current — headline

| 파일 / File | 내용 / Contents |
|---|---|
| `road_abadie2015_placebo_loo_cf.csv` | 반사실 대비 % (`cf_pct`), p(위약 전체, `p_all`), 순위, LOO 범위, RMSPE 비율 / effect vs counterfactual, p over all placebos, rank, LOO range, RMSPE ratio |
| `../all_units_summary.csv` | 같은 실행의 원 요약(처치 전 평균 대비 % 포함) / raw summary of the same run |
| `../unit_XX/placebo_results.csv`, `../unit_XX/loo_twostep.csv` | 같은 실행의 링크별 위약·LOO(V·W 재추정) / per-link placebo and two-step LOO of the same run |
| `road_cf.csv` | 반사실 대비 % 본추정. 두 실행의 본추정이 같으므로 그대로 유효 / point estimates, identical in both runs, still valid |
| `road_windows_cf.csv` | 기간별(초기·후기·첫 22주) 본추정. 본추정만 쓰므로 유효 / point estimates by window, still valid |

검정통계량은 `rmspe_ratio`(처치 후/처치 전 RMSPE 비율)입니다. 이 파일에는 같은 실행의 `p_tau5`, `n_tau5`(사전 RMSPE 5배 이하 민감도)와 위약 성공·실패 수(`n_placebo_ok`, `n_placebo_fail`)도 들어 있습니다.
The test statistic is `rmspe_ratio` (post/pre RMSPE). The file also carries `p_tau5`, `n_tau5` (≤ 5× pre-RMSPE sensitivity) and placebo success/failure counts from the same run.

## 이전 세대 (참고용) / Earlier generation — reference only

위약 도너 풀에 처치 링크를 넣지 않았고 LOO에서 V를 고정한 이전 실행(`code/03_road_scm/run_nested53_full.R`)의 결과입니다. 순위·p·LOO 범위가 본 결과와 다르므로 인용하지 마십시오.
From the earlier run (`code/03_road_scm/run_nested53_full.R`), in which the treated link was not in the placebo donor pools and LOO kept V fixed. Ranks, p-values and LOO ranges differ from the headline run; do not cite them.

| 파일 / File | 대체 파일 / Use instead |
|---|---|
| `road_placebo_p_all_vs_tau5.csv` | `road_abadie2015_placebo_loo_cf.csv` (`p_all`, `p_tau5`, `n_tau5`) |
| `road_loo_cf.csv` | `road_abadie2015_placebo_loo_cf.csv` (`loo_cf_min`, `loo_cf_max`) |

예: 01 경인로 유출의 p는 이전 세대 .093(5위), 본 결과 .111(6위/54). Example: link 01 has p = .093 (rank 5) in the earlier run and .111 (rank 6 of 54) in the headline run.
