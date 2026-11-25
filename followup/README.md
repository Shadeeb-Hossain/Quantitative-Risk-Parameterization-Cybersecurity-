# Subsequent six-trial numerical reproduction

Elias Calboreanu

This directory reproduces the likelihood scores, rolling counts, persistence decisions and integer boundaries recorded in the separate six-trial evaluation. It contains 12 source cases and 1,200 one-second rows. It does not run traffic or apply firewall rules.

From the repository root in native MATLAB:

```matlab
addpath('followup');
run_followup(fullfile(tempdir, 'recon_followup_check'));
```

Choose a new output directory on each run. The function copies the inputs there, checks their SHA-256 digests and writes `MATLAB_VERIFICATION.json`. The retained report in `expected/` is never overwritten. The replay must agree on counts and decisions and satisfy the score tolerance `1e-10 + 2e-12 * abs(expected)`. Four deliberately corrupted copies must be rejected. The recorded native MATLAB run had zero maximum score difference.

The entry point requires native MATLAB and Python 3 on macOS or Linux. MATLAB R2026b Update 1 was used for the retained run. Python uses only its standard library. If `python3` is not on MATLAB's command path, set an installed interpreter explicitly:

```matlab
setenv('RECON_PYTHON', '/absolute/path/to/python3');
```

`PROVENANCE.json` identifies the source freeze and the original and delivery index hashes. The delivery index replaces machine-specific provenance keys with paths relative to the source package. The fixture bytes, numerical core and recorded input digests are unchanged. The original report consequently has a different index hash; scores and decisions remain the comparison of interest.

The separate traffic evaluation recorded 9,664 successful ordinary requests and messages and 42 passing paired service comparisons. Sustained NULL protection continued through ten renewals, including 567 blocked packets after the original expiry. These are retained traffic observations, not outcomes newly established by this numerical replay. The original 36-trial Study F and its F02/F04 service failures remain separate.
