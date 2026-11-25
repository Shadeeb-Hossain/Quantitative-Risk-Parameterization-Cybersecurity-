# From Reconnaissance to Response

This repository contains corrected versions of Shadeeb Hossain's MATLAB illustrations and numerical replays of two software-testbed studies. The studies compare decisions based on measured TCP connection state with count and persistence rules and measure the service impact of the response.

## Original 36-trial study

The primary detector remained quiet in all 12 legitimate trials and crossed its threshold during all 24 SYN or NULL load windows. With a common persistence gate, the score and the matched count rule made identical decisions throughout the study. Persistence alone also alarmed during impaired legitimate activity.

The service-preservation target **failed**. F02 missed ordinary-request dispatches and failed the paired service comparison. In F04, the guarded cohort's ordinary-request p95 latency was 271.22 ms higher under conditional proxy than under observation, exceeding the predefined 100 ms margin. All 58 matched requests completed.

- [MATLAB and Octave replay instructions](empirical/README.md)
- [Numerical data](empirical/data/)
- [Mathematics and findings](empirical/docs/study.md)
- [Generated results and figures](empirical/output/)

MATLAB R2026b Update 1 generated the figures and verification report. The same numerical replay also passed in GNU Octave 11.3.0. Replay uses retained numerical observations. Full packet and service-log reconstruction requires the archived captures and application records identified by the study manifest.

## Subsequent six-trial study

An instrumented diagnostic missed 3 of 1,549 ordinary requests or messages and recorded another first call beyond the 250 ms dispatch bound. A same-schedule confirmation and five subsequent regression trials ran with the host idle and the acceptance criteria unchanged. All 9,664 ordinary requests and messages succeeded. All 42 paired service cohorts passed, with maximum added p95 latency of 1.92172455 ms. The NULL response lease renewed 10 times. None of the 567 packets offered after the initial expiry reached the backend, and the lease expired after qualifying traffic stopped.

Native MATLAB reproduced 1,200 rows from 12 source cases with zero maximum absolute score error and rejected four corrupted-input controls. The gated score, gated count and persistence-only decisions agreed on these observations. These results describe the evaluated software response under the stated conditions. Evaluation under competing background workloads and on a physical Cisco ASA remains future work. F02 and F04 retain their original verdicts.

To replay the subsequent observations, open the repository root in MATLAB and choose a new output directory. [Replay requirements](followup/README.md)

```matlab
addpath('followup');
run_followup(fullfile(tempdir,'recon_followup_check'));
```

Fresh live trials require adaptation to the local VM and kernel. The November 24, 2026 manuscript candidate and reproduction archive are supplied separately for coauthor review.

## Source illustrations

The original scripts are preserved at commit `2e72863ae761082d383c527a5bbd028bcf0c16bc`. The current entry points call the corrected illustrations in `source/matlab/`. [Source mathematics checks](source/README.md)

| Script | Scope |
| --- | --- |
| `Fig_2_MONTE_CARLO_FAIR_results.m` | Illustrative FAIR Monte Carlo loss calculation |
| `Fig_4_Dynamic_Bayesian_Stackelberg_Decision_SIEM.m` | Simulated SIEM stream with alert probabilities derived from its count rule |
| `Fig_5_SIEM_different_trigger_times.m` | Stable count-evidence updates with explicit floor and cost assumptions |

The simulations assume probabilities, financial parameters and a belief floor whose empirical validity remains untested. The empirical implementation uses a finite-window log score and a separately calibrated threshold. Posterior calibration and economic optimality remain outside the empirical studies' scope.

## Attribution

Shadeeb Hossain developed the original framework and MATLAB simulations. Elias Calboreanu prepared the empirical implementation, replay code and revisions. Both authors retain their manuscript attribution.

Hossain, S., and Calboreanu, E. (2026). *From Reconnaissance to Response: Quantitative Risk Parameterization and Game Theoretic Containment in Modern Enterprise Attack*. [arXiv:2609.36485](https://arxiv.org/abs/2609.36485)
