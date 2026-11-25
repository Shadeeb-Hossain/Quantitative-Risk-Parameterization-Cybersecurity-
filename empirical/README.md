# Held-out empirical analysis

This numerical supplement reproduces the 36-trial F study for *From Reconnaissance to Response*. Elias Calboreanu prepared the empirical implementation. Shadeeb Hossain's original MATLAB illustrations are documented with the [source mathematics checks](../source/README.md).

## Run locally

Open the repository root in GNU Octave or MATLAB. The analysis uses base functions and the fixed inputs in [`data/`](data/). Figure export in GNU Octave requires a graphics toolkit and Ghostscript.

```matlab
addpath(fullfile(pwd, 'empirical', 'matlab'));
run_all;
```

To choose another destination, pass it to `run_all(outputDirectory)`. The default output directory is `empirical/output`. You can also run from a terminal in the repository root.

```sh
octave --no-gui --no-init-file --no-site-file --quiet --eval "addpath('empirical/matlab'); run_all();"
matlab -batch "addpath(fullfile(pwd,'empirical','matlab')); run_all"
```

The entry point runs the unit tests, checks 144 source-detector cases across 43,200 one-second rows, verifies the 36 trial alarm totals, and recalculates the F02 matched outcomes and F04 matched-success p95 difference. It writes the verification report, vector PDF and 300 dpi PNG figures, and figure data in CSV. `case_validation.csv` gives the maximum score error and tolerance ratio for each case. `trial_alarm_seconds.csv` gives alarm totals for all five rules after combining the two observed sources in each trial and detector.

## Numerical and service results

The rolling score is a log likelihood contrast under a Poisson or negative-binomial working marginal with alternative mean multiplier 1.24. It is affine in each feature's count and eligible exposure over at most 60 seconds. For each feature, the gated score rule requires the fixed calibration bound, at least 30 seconds of exposure, and at least 10 occupied bins in the most recent 15. The detector takes the union of per-feature decisions. Verification compares counts and Boolean decisions exactly and uses score tolerance `1e-10 + 2e-12 * abs(expected)`.

The F study verdict is **NOT_PASSED**. Of 199 primary service cohorts, 197 passed. The F02 affected-source new TCP cohort had one newly harmed matched request over the whole trial, with seven fewer failures overall. In the F04 guarded admission cohort, matched ordinary requests that succeeded under both policies had p95 latencies of 274.63 ms under conditional proxy and 3.42 ms under observe. The increase of 271.22 ms exceeded the 100 ms limit.

## Figure outputs

| Output | Plotted data |
| --- | --- |
| `figure2_detector_comparison` | Handshake-state score plus gate, count rate plus gate, and persistence alone. Bars are medians and whiskers span the observed minimum to maximum over realized trials in each workload. Workload counts are 4 steady, 4 bursty, 4 impaired, 16 SYN, and 8 NULL. |
| `figure3_f04_timeline` | Affected-source score around the ungated count-rate crossing at 12.251 s, the ungated score crossing at 13.254 s, and the shared gated crossing at 20.252 s. The lower panel shows observed SYN load, response installation at 20.257 s, and the guarded admission and ACK-grace intervals. Both panels use seconds since actual load start. |
| `figure4_f04_service_latency` | All 58 paired ordinary requests that succeeded on a single attempt in each arm in the F04 guarded admission cohort. Both policies share each request's scheduled time. The log-scaled vertical axis shows request latency in milliseconds. The 100 ms bound applies to the difference between cohort p95 values. |

MATLAB R2026b Update 1 generated the figures. The replay also passed in GNU Octave 11.3.0. The original numerical comparison used GNU Octave 10.3.0. [MATLAB verification](output/verification.json) and [Octave verification](verification/octave_11_3_0.json)
