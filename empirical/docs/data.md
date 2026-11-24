# Empirical data dictionary

The tables under [data](../data/) retain the held-out F study's recorded numbers. Booleans in CSV are 0 or 1. A blank value is unavailable or inapplicable. Durations and offsets use nanoseconds where marked `_ns`, milliseconds where marked `_ms`, and seconds where marked `_seconds` or `_s`. The CSV rows use round-trip decimal representations of binary64 values. Absolute timestamps and network addresses are mapped to relative times and source roles.

| File | Rows or contents | Definition |
| --- | ---: | --- |
| [native_cases.csv](../data/native_cases.csv) | 43,200 | 36 trials × 2 detectors × 2 source roles × 300 one-second bins. `bin_index` starts at zero. Each case is one trial, detector and source role. |
| [native_parameters.json](../data/native_parameters.json) | 2 detector entries | Frozen model and policy parameters, including feature order, working means, shapes, affine coefficients and calibrated bounds. A null shape denotes the Poisson reference. |
| [native_case_index.json](../data/native_case_index.json) | 144 cases | Source identities bound to the SHA-256 digests for each original numerical export and native fixture, model and policy. The source-native expected hashes cover `K`, `n`, `O15`, `valid` and the five-column `family` matrix. |
| [trial_summary.csv](../data/trial_summary.csv) | 36 | Per-trial service outcome counts, coverage, primary new-crossing delay and alarm seconds for five decision families in each detector. Trial-family rows aggregate across source roles. |
| [arm_summary.csv](../data/arm_summary.csv) | 4 | Nine trials per policy, retaining ordinary requests, explicit abandonments, verified outcomes, unissued jobs and retries, plus service message and continuity connection outcomes. |
| [primary_cohorts.csv](../data/primary_cohorts.csv) | 199 | Prespecified conditional proxy versus observe comparisons by block, role, channel and phase. `newly_harmed` counts treated nonsuccess with reference success. `failure_difference` and `p95_delta_ms` are treatment minus reference. |
| [measurement_summary.csv](../data/measurement_summary.csv) | 36 | Trial-level capture and clock quality, verified dispatch or raw initiation counts and guarded effect totals. `rin` is the upstream auxiliary capture and `rsvc` is the service-side capture. |
| [f04_timeline.csv](../data/f04_timeline.csv) | 300 | Affected-source, first-feature numerical trace and trial family decisions from f04p. Bin boundaries are offsets from capture start. `decision_since_actual_load_start_ns` records availability relative to the observed generator-window start. |
| [f04_events.csv](../data/f04_events.csv) | 17 | Actual and scheduled load boundaries, first crossing availability, installation and conservative guard boundaries. Nominal expiries derive from recorded installation plus the frozen durations. |
| [f04_guarded_requests.csv](../data/f04_guarded_requests.csv) | 58 | Matched affected-source ordinary continuity requests selected in the f04p guarded admission cohort with corresponding f04o records. Start and acknowledgment offsets are relative to each arm's trial start. |
| [f02_matched_requests.csv](../data/f02_matched_requests.csv) | 543 | The full matched affected-source `new_tcp` cohort in f02p and f02o, including all nonsuccesses. Columns use the same units and identities as the F04 request table. |
| [f02_dispatch_failures.csv](../data/f02_dispatch_failures.csv) | 142 | One row per rejected-before-call failure or unverified deadline-crossing bracket across four F02 arms. `scheduled_phase_s` and `observed_phase_s` use offsets from trial start. Bracket lags are from the planned due time in the guest clock. |
| [study_summary.json](../data/study_summary.json) | Study verdict and verification | Combined outcome, retained failures, cohort counts and original numerical verification. |
| [provenance.json](../data/provenance.json) | SHA-256 mapping | Hashes for the sealed artifact manifest, pretest freeze, source reports and published data files. The source keys are evidence-package-relative names. |

## Native cases

`x1` and `x2` are per-source feature counts in model order. The state detector's feature order is `matured_uncompleted`, `null_unestablished`. The quantity detector's order is `matured_attempts`, `flags0_all`. `component` identifies contiguous eligible time and uses -1 for absent or ineligible rows. `K1` and `K2` are counts in the up-to-60-bin window, with exposure `n`. `O15_1` and `O15_2` count positive bins in the up-to-15-bin window with exposure `n15`. `E1` and `E2` are the affine scores. The count rates `rate1` and `rate2` are in events per covered second. `integer_count_threshold1` and `integer_count_threshold2` invert the inclusive score bound using float64 comparison corrections. Each `family_*` flag is the OR of feature decisions for one source.

For source-native digests, `K`, `n` and `O15` are little-endian float64 arrays in column-major order. `valid` and `family` are uint8. The five `family` columns are corrected-score-plus-gate, score-only, count-rate, count-rate-plus-gate and persistence. The score tolerance recorded in the source index is absolute 1e-10 and relative 2e-12.

## Release boundary

The data support replay of the numerical policy and the published summaries. The release includes the frozen fit and calibration parameters, all held-out feature and result arrays, the two retained failed-cohort extracts and descriptive aggregate measurements. A new packet-level reconstruction or a complete recomputation of matched identity outcomes would require the archived traffic captures and raw service logs. The fitting inputs and live testbed code also stay in the research archive.

The export script takes a local copy of the sealed F evidence package and a fresh destination. It checks each used source against the sealed manifest. Its SHA-256 checks cover the 144 original NPZ exports, 144 original MAT fixtures and the 720 array digests recorded in the numerical index. It derives published rows from already recorded outcomes and reads no capture payloads. Reproducing the export with the archive requires Python 3.9 or later and NumPy 1.22 or later.

```sh
python3 empirical/scripts/export_evidence.py path/to/sealed-f-study path/to/new-output
```

The supplied data files are ready for numerical replay without access to the research evidence archive.
