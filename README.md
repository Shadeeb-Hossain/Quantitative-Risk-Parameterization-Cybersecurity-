# From Reconnaissance to Response

This working copy contains numerical revisions of Shadeeb Hossain's MATLAB illustrations and a MATLAB-compatible empirical reproduction companion prepared by Elias Calboreanu. The companion connects the likelihood formulation to measured TCP connection state, compares the resulting decisions with count and persistence controls, and documents the practical limits of a software response.

The [source mathematics checks](source/README.md) document the local corrections and how to run them. These corrections have not been submitted. The earlier empirical pull request was closed without merging.

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

## Source illustrations

The following entry points now call the corrected, reproducible illustrations in `source/matlab/`. Their original contents remain in Git history at commit `2e72863ae761082d383c527a5bbd028bcf0c16bc`:

| Script | Scope |
| --- | --- |
| `Fig_2_MONTE_CARLO_FAIR_results.m` | Illustrative FAIR Monte Carlo loss calculation |
| `Fig_4_Dynamic_Bayesian_Stackelberg_Decision_SIEM.m` | Simulated SIEM stream with alert probabilities derived from its count rule |
| `Fig_5_SIEM_different_trigger_times.m` | Stable count-evidence updates with explicit floor and cost assumptions |

These simulations are distinct from the empirical companion. Their assumed probabilities, financial parameters and belief floor are not validated by the software traffic study. The empirical implementation uses a finite-window score and a separately calibrated threshold; it does not interpret that score as a calibrated attack probability or an economically optimal action.

## Attribution

Original framework and MATLAB simulations: Shadeeb Hossain. Empirical implementation, reproduction package and revision preparation: Elias Calboreanu. The manuscript retains its coauthor attribution.

Original paper: Hossain, S., and Calboreanu, E. (2026). *From Reconnaissance to Response: Quantitative Risk Parameterization and Game Theoretic Containment in Modern Enterprise Attack*. arXiv:2609.36485. https://arxiv.org/abs/2609.36485

This contribution does not add or change a repository license.
