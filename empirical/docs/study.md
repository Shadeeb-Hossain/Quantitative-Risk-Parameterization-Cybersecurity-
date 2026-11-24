# F study numerical supplement

Elias Calboreanu

The completed F study ran nine workload blocks under four policies, for 36 trials. The joint verdict was **NOT_PASSED**. The primary state rule detected a new crossing in each of the 24 prescribed SYN or NULL trials and stayed quiet in all 12 legitimate trials. Two of 199 primary service cohorts failed. Eight of nine conditional-proxy trials met the separate whole-trial zero-disruption requirement.

## Measurement and design

Each trial is 300 seconds, with 120 seconds of baseline, a scheduled 90-second main window and 90 seconds of follow-up. Four policies ran concurrently within each block on one virtualized host. The policies were observe, conditional drop, conditional proxy and always-on proxy. The nine blocks were steady, bursty and impaired legitimate activity, two SYN blocks with ordinary continuity traffic, two SYN blocks with impaired ordinary continuity traffic, and two NULL blocks. Controlled load profiles are experimental conditions. The two observation roles are the affected source and a peer.

The state detector counts matured attempts whose three-way handshake was still uncompleted at a ten-second deadline, and flags-zero packets on tuples without retained established or closing state. The first quantity comparator counts all matured attempts at the same deadline. Its second feature counts all flags-zero packets. Each configured-service initiator supplies one row per observed second and retains eligible zero history. A missing or ineligible bin ends a coverage component. The collector uses a 250 ms closure allowance, with late frames and observed quality failures subject to abstention. All 10,800 trial seconds in F were eligible. The dataset begins with measured feature arrays and treatment records.

## Working score and matched count rules

Reference means are fitted per feature over all 1,080 eligible source-seconds pooled across three benign fit runs. The negative-binomial working marginal has mean $\mu$ and shape $r$. Its shape is fitted at the fixed sample mean by bounded maximum likelihood on $\log r \in [-8,14]$. An all-zero fitting feature instead uses a Poisson reference mean $0.5/1080$. The alternative multiplies the reference mean by the stipulated $q=1.24$ and retains shape.

Let $K$ be the feature count summed over the latest $n$ covered one-second bins, including the current bin. The window holds at most 60 bins from the current coverage component. After cancellation of all terms common to the two marginals, the sum of the log mass ratios is
$$
E=aK+cn,\qquad
d=\log\!\left(\frac{r+q\mu}{r+\mu}\right),\qquad
a=\log q-d,\qquad c=-rd.
$$
Under the Poisson reference, $a=\log q$ and $c=-(q-1)\mu$. The reference is a working marginal and $E$ is a log score. Temporal independence and posterior calibration are outside the study's scope.

The rule is eligible once $n\ge30$. Its persistence gate requires at least ten positive bins among the latest 15 in the same component. For each feature, three separate benign calibration runs contribute 906 valid source-seconds. The score bound $B$ is the larger of 1 and one plus the largest gated calibration score, using 1 if there is no gated observation. The rate cutoff $R$ is the maximum calibration rate over valid windows. The fit and calibration were frozen before F.

| Decision family | Per-feature condition in a valid window |
| --- | --- |
| Score plus persistence | $E\ge B$ and the gate is true |
| Score only | $E\ge B$ |
| Count rate | $K/n>R$ |
| Count rate plus persistence | $K/n>R$ and the gate is true |
| Persistence only | The gate is true |

Feature decisions are combined by OR within a source and source decisions by OR within a trial bin. Because $a>0$, the score bound is exactly an increasing integer count threshold. In real arithmetic it is $K\ge\lceil(B-cn)/a\rceil$. The reference implementation tests adjacent integers with the same float64 score expression to preserve equality behavior. The separately calibrated count-rate control uses its own cutoff and a strict rate comparison. Its observed agreement with the score-and-gate family in F is an empirical result.

| Workload | Trials | State score plus gate alarm seconds per trial | State gate-only alarm seconds per trial | Agreement of score plus gate with count rate plus gate | Agreement of score plus gate with gate only |
| --- | ---: | ---: | ---: | ---: | ---: |
| Steady legitimate | 4 | 0 | 0 | 4/4 | 4/4 |
| Bursty legitimate | 4 | 0 | 0 | 4/4 | 4/4 |
| Impaired legitimate | 4 | 0 | 84 | 4/4 | 0/4 |
| SYN | 16 | 86–87 | 86–87 | 16/16 | 16/16 |
| NULL | 8 | 86 | 86 | 8/8 | 8/8 |

During impaired legitimate activity the numerical thresholds removed the gate-only alarms. The likelihood score supplied no observed decision advantage over the matched count control in any F trial. The quantity ablation gave 66 score-plus-gate alarm seconds in each steady legitimate trial. All five families for both feature sets are in the per-trial data.

## F04 crossing and guarded service outcome

In the conditional-proxy trial f04p, the primary SYN-feature threshold was $B=12.489792550036382$. At bin index 139 the affected source contributed $K=301$, $n=60$, $O_{15}=10$ and $E=63.76185415128762$. At that exposure, the score's integer count bound was 63. Both ungated numerical rules first crossed earlier. Logged decision availability relative to the actual raw-load start was 12.251340481 s for count rate alone, 13.253745080 s for score alone, and 20.252218919 s for both gated rules and for persistence alone.

The conditional response installed 4.609569 ms after the recorded attempt. Nominal SYN admission handling lasted 12 seconds and ACK handling lasted 22 seconds from installation. Only one case could be acted on, with no rearm or refresh. Prespecified uncertainty guards used a 0.2-second interior margin. The guarded admission interval included 347 suppressed targeted raw attempts in F04. Across the four SYN and two NULL selective intervals, all guarded effect checks passed and accounted for 2,086 suppressed targeted raw attempts. The 90-second continuing load extends beyond these intervals.

The primary latency comparison used 58 affected ordinary continuity requests selected by the treated guarded admission interval and joined by planned identity to the observe trial. Every request succeeded with one attempt in each arm. With linear interpolation, p95 was 274.6331268499978 ms for conditional proxy and 3.4177765499999992 ms for observe, an increase of 271.2153502999978 ms against a 100 ms limit. Three selective latencies were between 1.630 and 1.696 seconds. Application latency is measured from logical start to final verified application acknowledgment, including any retries. Cohort quantiles are computed separately on the verified successes in each arm.

## Preserved service failures

The primary engineering comparison fixes request identity within each block and checks for newly harmed intended-to-complete identities, net intended nonsuccess and added p95 where defined. Connection records test continuity and outcome without a latency percentile. The 199 primary cohorts overlap across phases, channels and roles.

F02's affected new-TCP whole-trial cohort had 543 matched intended logical requests. Among them, 17 failed in both arms, eight succeeded only in conditional proxy, one succeeded only in observe, and 517 succeeded in both. The one newly harmed identity failed the frozen paired criterion despite seven fewer total nonsuccesses in conditional proxy. Across all four F02 policies, 134 jobs were rejected before starting a call and eight first-call timing brackets straddled the 250 ms dispatch deadline. All four F02 trials failed joint measurement quality, and all 36 trials passed the frozen guest clock and capture checks. The evidence records overlapping execution gaps during F02. Its precise resource cause remained unresolved.

Conditional proxy recorded 23,825 successes across 23,856 intended ordinary logical requests, with 31 unissued and zero failures after dispatch. The 31 unissued requests fail the absolute whole-trial service requirement. The study reports all failed or retried ordinary requests and separately counts the prespecified abandonments in the planned denominator.

## Reproduction scope

The frozen study initially verified 144 observed cases and 43,200 per-source rows in GNU Octave 10.3.0. Its 720 exact count or Boolean hash comparisons passed, and the largest absolute score difference was approximately $6.04\times10^{-14}$. The separate-copy source reproduction matched 255 normalized reports and 2,448 arrays. Those checks establish arithmetic and result integrity on fixed observations. The evidence supports a finite software study. It leaves open population error rates, endpoint or physical-device transfer, sustained 24% sensitivity, full-load containment and economic benefit.

The released figures were subsequently generated by the accompanying implementation in local MATLAB R2026b Update 1. The same numerical replay also passed in GNU Octave 11.3.0. The [MATLAB verification report](../output/verification.json) and [Octave verification report](../verification/octave_11_3_0.json) record the separate runtime results. These replays use the retained observations and introduce no new traffic trials.

See [the data dictionary](data.md) for identifiers, units and provenance.
