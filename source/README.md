# Source mathematics checks

Elias Calboreanu

The original illustrative scripts had three reproducible numerical or model-consistency defects. The local corrections preserve their role as illustrations. They do not change the frozen F observations, establish calibrated threat probabilities, or repair the failed service target.

| Check | Original behavior | Corrected behavior |
| --- | --- | --- |
| Binary alert likelihood | Assumed sensitivity 0.90 and false-positive probability 0.03, while generating an alert when a Poisson count exceeded its benign 95th percentile | The cutoff is 62. Exact probabilities for counts above 62 are 0.978094010967198 under mean 80 and 0.042390934965085 under mean 50. The update now uses these model-derived rates. |
| Evidence arithmetic | Direct exponentiation and probability updates can overflow, return NaN, or round to an absorbing probability of one | The state retains log odds and decisions compare log odds directly. The displayed probability is not fed back into the recurrence. |
| PERT parameters | The general expression divides by mode minus mean, making it unstable near a symmetric mode | Shapes use alpha = 1 + g(mode-low)/(high-low) and beta = 1 + g(high-mode)/(high-low). Both stay finite and positive on the declared domain. |

For the PERT regression case with bounds 0 and 1, weight 4 and mode `0.5 + 4*eps(0.5)`, the original expression gives alpha 4 rather than approximately 3. The original count update produces NaN at count 10,000; the log-odds update stays finite. These robustness examples are synthetic arithmetic tests, not explanations of the recorded F02 or F04 outcomes.

The independent empirical audit uses direct Poisson and negative-binomial log-mass ratios, explicitly indexed rolling windows, and integer-boundary searches on all 144 cases. The existing empirical scorer needed no correction. F02's dispatch and paired-service failure and F04's added p95 of 271.22 ms remain observations, not arithmetic defects.

On the same generated binary-illustration observations, the legacy assumed probabilities produce a first crossing at 56 seconds; the consistent probabilities produce no crossing during the 100-second run. This controlled comparison changes only the likelihood rates. Earlier quiet bins supply stronger benign evidence under the consistent rates, and the fixed-hypothesis update retains that evidence across the simulated onset. Correcting the likelihood therefore does not establish a useful changing-state detector. In the separate floored count illustration, all three assumed cost thresholds first cross at 21 seconds. These are seeded simulation results, not F trial results or population detection estimates. A null crossing time in the verification JSON means no crossing was observed in the simulated horizon.

## Run locally

From the repository root in MATLAB:

```matlab
addpath('source');
run_source_checks;
```

The entry point runs seven source-math groups and the independent empirical audit. The source groups check likelihood ratios, alert-tail probabilities, PERT stability, ordinary and extreme evidence updates, expected-cost indifference, inverse-CDF sampling, and seeded illustration reproducibility. The empirical audit covers all 144 cases, 43,200 retained rows, 86,400 integer count-boundary checks, 108 equality cases and 226 synthetic window rows. The report is `source/output/math_verification.json`. Base MATLAB is sufficient; Statistics and Machine Learning Toolbox is not required.

The three root scripts display the corrected illustrations. Random seeds are fixed and the caller's random state is restored. One count is generated per one-second interval and displayed at its end. Elevated intervals are half-open: [35,75) for the binary illustration and [15,75) for the count illustration. The original extra terminal count and inclusive-end ambiguity are removed. The base-MATLAB sampler changes seeded sample paths relative to `poissrnd`; these are revised illustrations, not exact replicas of the old graphs.

## Interpretation limits

With a fixed hypothesis and conditionally independent observations, adding log likelihood ratios to prior log odds implements Bayes' rule. The demonstration stream changes regime, so its fixed-hypothesis belief is a diagnostic; it is not a calibrated probability of the current attack state. Figure 5 retains the original 0.005 floor as an explicit additional rule and shows the unfloored result separately.

The cost ratio is the indifference threshold for a one-decision model in which action costs C, prevents all considered loss, and inaction has expected loss p*s*L over the same horizon. It does not establish a Stackelberg equilibrium. The illustrative conditional loss 92.58 is an assumption; the FAIR example's annualized exposure is not substituted for a conditional event loss. The FAIR inputs imply analytic mean annualized exposure 92.6916667, with an explicitly independent-input assumption. Its 95th percentile is not a maximum loss or an empirically calibrated incident forecast.

The corrected source checks and empirical replay establish numerical properties of these implementations. Novelty, sustained-24% sensitivity, general service preservation, and physical-router transfer remain unestablished. No new network experiment is included.
