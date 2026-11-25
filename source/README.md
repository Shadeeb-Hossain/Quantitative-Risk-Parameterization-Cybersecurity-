# Source mathematics checks

Elias Calboreanu

These checks cover three numerical and model-consistency corrections to Shadeeb Hossain's original MATLAB illustrations.

| Check | Original behavior | Corrected behavior |
| --- | --- | --- |
| Binary alert likelihood | Assumed sensitivity 0.90 and false-positive probability 0.03, while generating an alert when a Poisson count exceeded its benign 95th percentile | The cutoff is 62. Exact probabilities for counts above 62 are 0.978094010967198 under mean 80 and 0.042390934965085 under mean 50. The update now uses these model-derived rates. |
| Evidence arithmetic | Direct exponentiation and probability updates can overflow, return NaN, or round to an absorbing probability of one | The state retains log odds and decisions compare log odds directly. The displayed probability is not fed back into the recurrence. |
| PERT parameters | The general expression divides by mode minus mean, making it unstable near a symmetric mode | Shapes use alpha = 1 + g(mode-low)/(high-low) and beta = 1 + g(high-mode)/(high-low). Both stay finite and positive on the declared domain. |

For the synthetic PERT test with bounds 0 and 1, weight 4 and mode `0.5 + 4*eps(0.5)`, the original expression gives alpha 4, with the correct value approximately 3. At count 10,000 the original update produces NaN and the log-odds update stays finite.

The independent empirical audit reproduces the F study score with direct Poisson and negative-binomial log-mass ratios, explicitly indexed rolling windows and integer-boundary searches on all 144 cases. F02 failed dispatch and paired service checks. In F04 the added p95 of 271.22 ms exceeded the 100 ms service limit.

On the same generated observations, the original assumed alert probabilities yield a first crossing at 56 seconds. The model-derived probabilities yield no crossing in 100 seconds because quiet bins supply stronger benign evidence and the fixed-hypothesis update retains it after the simulated onset. In the separate seeded count illustration with a belief floor, the first crossing occurs at 21 seconds for all three assumed cost thresholds. A null crossing time in the verification JSON indicates no crossing in the simulated horizon.

## Run locally

Open the repository root in MATLAB and run the source checks.

```matlab
addpath('source');
run_source_checks;
```

The seven source check groups cover likelihood ratios, alert-tail probabilities, PERT stability, ordinary and extreme evidence updates, expected-cost indifference, inverse-CDF sampling and reproducibility of the seeded illustrations. The empirical audit covers 144 cases, 43,200 retained rows, 86,400 integer count-boundary checks, 108 equality cases and 226 synthetic window rows. The checks write `source/output/math_verification.json` and use base MATLAB functions.

The three root scripts display the corrected illustrations with fixed seeds and restore the caller's random state. Each one-second interval contributes one count displayed at its end. The elevated intervals are half-open, [35,75) seconds in the binary illustration and [15,75) seconds in the count illustration. The base-MATLAB sampler yields different seeded sample paths from `poissrnd`.

## Interpretation limits

With a fixed hypothesis and conditionally independent observations, adding log likelihood ratios to prior log odds implements Bayes' rule. When the demonstration stream changes regime, the fixed-hypothesis belief remains a diagnostic and posterior calibration for the current attack state remains untested. Figure 5 retains the original 0.005 belief floor as an additional rule and shows the unfloored result separately.

The cost ratio is the indifference threshold for one decision. Action costs `C` and prevents all considered loss. Inaction has expected loss `p*s*L` over the same horizon. A Stackelberg equilibrium would require a strategic model beyond this threshold. The illustration assumes a conditional event loss of 92.58. The separate FAIR example assumes independent inputs and has analytic mean annualized exposure 92.6916667. Its 95th percentile is a quantile of the assumed annualized loss distribution, with larger losses possible.

The source checks run simulations and replay the retained F observations. Novelty, sensitivity to a sustained 24% increase, general service preservation and transfer to physical routers remain unestablished.
