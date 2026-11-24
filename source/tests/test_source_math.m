function report = test_source_math()
%TEST_SOURCE_MATH Independent equations, stability and reproducibility checks.
% Elias Calboreanu

% Direct log masses provide the Poisson ratio oracle.
count = [0; 1; 20; 50; 100; 1000; 10000];
maximumError = 0;
for exposure = [0.25, 1, 3]
    logMass0 = -50 * exposure + count .* log(50 * exposure) - gammaln(count + 1);
    logMass1 = -62 * exposure + count .* log(62 * exposure) - gammaln(count + 1);
    observed = poisson_log_ratio(count, 50, 62, exposure);
    error = max(abs(observed - (logMass1 - logMass0)));
    assert(error < 5e-10);
    maximumError = max(maximumError, error);
end

% The strict Poisson alert's actual rates must equal the summed masses.
[cutoff, falsePositive, sensitivity] = model_alert_rates(50, 80, 0.95);
k = (0:500).';
pmf0 = exp(-50 + k * log(50) - gammaln(k + 1));
pmf1 = exp(-80 + k * log(80) - gammaln(k + 1));
assert(cutoff == 62 && sum(pmf0(k <= cutoff - 1)) < 0.95 && sum(pmf0(k <= cutoff)) >= 0.95);
assert(abs(falsePositive - sum(pmf0(k > cutoff))) < 1e-13);
assert(abs(sensitivity - sum(pmf1(k > cutoff))) < 1e-13);
assert(abs(falsePositive - 0.03) > 0.01 && abs(sensitivity - 0.90) > 0.07);

% PERT shape parameters remain stable around a symmetric mode.
modes = 0.5 + (-100:100) * eps(0.5);
legacyMean = (4 * modes + 1) / 6;
legacyAlpha = legacyMean .* (2 * modes - 1) ./ (modes - legacyMean);
legacyAlpha(legacyMean == modes) = 3;
legacyPertError = max(abs(legacyAlpha - (1 + 4 * modes)));
assert(legacyPertError >= 0.5);
for mode = [0, 0.2, modes, 0.8, 1]
    [alpha, beta, expectation] = pert_parameters(0, mode, 1, 4);
    assert(alpha > 0 && beta > 0 && abs(alpha + beta - 6) < 2e-15);
    assert(abs(expectation - (4 * mode + 1) / 6) < 2e-16);
end

% Stable log odds agree with ordinary Bayes updates before rounding saturation.
increments = [-0.4; 0.7; -2; 3];
for floorProbability = [0, 0.005]
    [~, actual] = evidence_path(increments, 0.02, floorProbability);
    direct = zeros(5,1); direct(1) = 0.02;
    for i = 1:4
        ratio = exp(increments(i));
        direct(i+1) = max(floorProbability, ratio * direct(i) / ...
            (ratio * direct(i) + (1 - direct(i))));
    end
    assert(max(abs(actual - direct)) < 1e-14);
end
[largeLogOdds, largeBelief] = evidence_path([10000; -10000], 0.02, 0);
assert(all(isfinite(largeLogOdds)) && all(isfinite(largeBelief)) && abs(largeBelief(end) - 0.02) < 1e-13);
legacyRatio = 1.24^10000 * exp(-12);
legacyPosterior = legacyRatio * 0.02 / (legacyRatio * 0.02 + 0.98);
assert(isnan(legacyPosterior));
reversibleEvidence = [10 * ones(10,1); -10 * ones(10,1)];
direct = 0.02;
for increment = reversibleEvidence.'
    ratio = exp(increment);
    direct = ratio * direct / (ratio * direct + (1 - direct));
end
[~, restored] = evidence_path(reversibleEvidence, 0.02, 0);
assert(direct == 1 && abs(restored(end) - 0.02) < 1e-14);

% Cost indifference is an algebraic result under the declared assumptions.
for harm = [0.450, 0.739, 0.920]
    [p, bound] = containment_threshold(15, harm, 92.58);
    assert(abs(p * harm * 92.58 - 15) < 1e-13 && isfinite(bound));
    assert((p - 1e-5) * harm * 92.58 < 15 && (p + 1e-5) * harm * 92.58 > 15);
end
[p, bound] = containment_threshold(200, 0.739, 92.58);
assert(p > 1 && isinf(bound));

% Check inverse-CDF samples against independently summed probability masses.
saved = rng; rng(19, 'twister');
uniform = rand(500, 1); rng(19, 'twister');
sample = sample_poisson_reference(50 * ones(500, 1)); rng(saved);
cumulative = cumsum(pmf0);
below = zeros(size(sample)); nonzero = sample > 0;
below(nonzero) = cumulative(sample(nonzero));
assert(all(uniform >= below - 1e-13 & uniform <= cumulative(sample + 1) + 1e-13));

% Fixed seeds reproduce the supplied illustrations without toolbox functions.
fair = corrected_source_simulation('fair', false);
assert(isequal(fair, corrected_source_simulation('fair', false)));
assert(abs(fair.analytic_mean_annual_exposure - 92.6916666666667) < 1e-12);
assert(abs(fair.sample_mean_annual_exposure - fair.analytic_mean_annual_exposure) < ...
    6 * fair.sample_std_annual_exposure / sqrt(fair.sample_count));
binary = corrected_source_simulation('binary', false);
counts = corrected_source_simulation('count', false);
assert(isequaln(binary, corrected_source_simulation('binary', false)));
assert(isequaln(counts, corrected_source_simulation('count', false)));
assert(numel(binary.counts) == 100 && numel(binary.log_odds) == 101 && nnz(binary.elevated_bin) == 40);
assert(numel(counts.counts) == 100 && numel(counts.log_odds) == 101 && nnz(counts.elevated_bin) == 60);
assert(all(isfinite([binary.log_odds; counts.log_odds])));
% Isolate the binary likelihood correction on the same generated observations.
legacyAlert = binary.counts > binary.alert_cutoff;
legacyIncrement = legacyAlert * log(0.90 / 0.03) + (~legacyAlert) * log(0.10 / 0.97);
[legacyLogOdds, ~] = evidence_path(legacyIncrement, 0.02, 0);
[~, binaryBound] = containment_threshold(15, 0.739, 92.58);
index = find(legacyLogOdds >= binaryBound, 1);
legacyFirstCrossing = NaN;
if ~isempty(index), legacyFirstCrossing = binary.time(index); end

report = struct('status', 'MATH_CHECKS_PASS', 'engine', 'MATLAB', 'version', version, ...
    'test_groups_passed', 7, 'poisson_log_mass_comparisons', 21, ...
    'maximum_poisson_log_ratio_error', maximumError, 'alert_cutoff', cutoff, ...
    'actual_false_positive_probability', falsePositive, 'actual_sensitivity', sensitivity, ...
    'legacy_assumed_false_positive_probability', 0.03, 'legacy_assumed_sensitivity', 0.90, ...
    'legacy_near_symmetric_PERT_alpha_error', legacyPertError, ...
    'legacy_high_count_posterior_is_nan', isnan(legacyPosterior), ...
    'legacy_probability_saturates_after_reversible_evidence', direct == 1, ...
    'stable_log_odds_return_to_prior_error', abs(largeBelief(end) - 0.02), ...
    'binary_first_crossing_seconds', binary.first_crossing_seconds, ...
    'binary_legacy_probabilities_same_counts_first_crossing_seconds', legacyFirstCrossing, ...
    'count_first_crossing_seconds', counts.first_crossing_seconds, ...
    'binary_elevated_seconds', nnz(binary.elevated_bin), ...
    'count_elevated_seconds', nnz(counts.elevated_bin), ...
    'fair', fair, 'empirical_service_verdict', 'NOT_PASSED', ...
    'new_traffic_trials', 0, 'prepared_by', 'Elias Calboreanu');
end
