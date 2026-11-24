# From Reconnaissance to Response

This repository contains the original MATLAB simulations by Shadeeb Hossain and a MATLAB-compatible empirical reproduction companion prepared by Elias Calboreanu. The companion connects the likelihood formulation to measured TCP connection state, compares the resulting decisions with count and persistence controls, and documents the practical limits of a software response.

## Empirical companion

The completed study contains 36 software-testbed trials. Its primary detector remained quiet in all 12 legitimate trials and crossed its threshold during all 24 SYN or NULL load windows. The score with the common gate made the same decisions as the matched count rule throughout the study. Persistence alone also alarmed during impaired legitimate activity.

The service-preservation target **did not pass**. F02 retained missed ordinary-request dispatches. In F04, guarded ordinary-request p95 latency exceeded observation by 271.22 ms, above the predefined 100 ms margin, although all 58 matched requests completed. Successful filtering does not establish nondisruptive operation.

- [MATLAB code and reproduction instructions](empirical/README.md)
- [Numerical data](empirical/data/)
- [Mathematics and findings](empirical/docs/)
- [Generated results and figures](empirical/output/)

The released figures and verification report were generated locally in MATLAB R2026b Update 1. The same numerical replay also passed in GNU Octave 11.3.0. The reports distinguish numerical agreement from the study's failed service target.

The revised manuscript is supplied separately for coauthor review.

The companion reproduces numerical calculations and figures from retained observations. It does not generate new attack traffic or configure a router. It is a numerical supplement, not a public copy of the complete raw capture and application-record archive. The preserved study manifest identifies that underlying evidence.

## Original simulations

The following original scripts are retained unchanged for comparison with the source paper:

| Script | Scope |
| --- | --- |
| `Fig_2_MONTE_CARLO_FAIR_results.m` | Illustrative FAIR Monte Carlo loss calculation |
| `Fig_4_Dynamic_Bayesian_Stackelberg_Decision_SIEM.m` | Simulated SIEM stream and binary-alert belief update |
| `Fig_5_SIEM_different_trigger_times.m` | Simulated count-based belief updates and threshold scenarios |

These simulations are distinct from the empirical companion. Their assumed probabilities, financial parameters and belief floor are not validated by the software traffic study. The empirical implementation uses a finite-window score and a separately calibrated threshold; it does not interpret that score as a calibrated attack probability or an economically optimal action.

## Attribution

Original framework and MATLAB simulations: Shadeeb Hossain. Empirical implementation, reproduction package and revision preparation: Elias Calboreanu. The manuscript retains its coauthor attribution.

Original paper: Hossain, S., and Calboreanu, E. (2026). *From Reconnaissance to Response: Quantitative Risk Parameterization and Game Theoretic Containment in Modern Enterprise Attack*. arXiv:2609.36485. https://arxiv.org/abs/2609.36485

This contribution does not add or change a repository license.
