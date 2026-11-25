function report = audit_empirical_math(repo)
%AUDIT_EMPIRICAL_MATH Independently check the fixed empirical MATLAB scorer.
% Elias Calboreanu
% Run in base MATLAB with the release repository root as the argument.
addpath(fullfile(repo, 'empirical', 'matlab'));
data = fullfile(repo, 'empirical', 'data');
cases = readtable(fullfile(data, 'native_cases.csv'), 'TextType', 'string');
models = jsondecode(fileread(fullfile(data, 'native_parameters.json')));
ids = unique(cases.case_id, 'stable');
assert(numel(ids) == 144 && height(cases) == 43200);
q = 1.24;
thresholdChecks = 0;
equalityChecks = 0;
largestError = 0;
largestRatio = 0;
for name = ["state", "quantity"]
    model = models.(name).model;
    policy = models.(name).policy;
    means = [model.features.mean];
    shapes = NaN(1, 2);
    for j = 1:2
        if ~isempty(model.features(j).shape)
            shapes(j) = model.features(j).shape;
        end
    end
    bounds = policy.score_bounds(:).';
    rates = policy.rate_cutoffs(:).';
    for id = ids(startsWith(ids, "f") & contains(ids, "_" + name + "_")).'
        f = cases(cases.case_id == id, :);
        assert(isequal(f.bin_index, (0:299).'), 'Unexpected bin order in %s', id);
        expected = explicitWindows([f.x1, f.x2], f.component);
        observed = state_score_native([f.x1, f.x2], f.component, means, shapes, bounds, rates);
        compareWindows(observed, expected);
        reference = zeros(300, 2);
        for j = 1:2
            reference(:,j) = independentContrast(expected.K(:,j), expected.n, means(j), shapes(j), q);
        end
        [maximum, ratio] = compareScores(observed.E, reference, id);
        largestError = max(largestError, maximum);
        largestRatio = max(largestRatio, ratio);
        compareRules(observed, expected, reference, bounds, rates);
    end

    % The inverse count boundary depends on feature and exposure only.
    % Find it by searching the discrete count domain with full log masses.
    f = cases(cases.detector == name, :);
    for j = 1:2
        for exposure = 1:60
            k = massThreshold(exposure, means(j), shapes(j), q, bounds(j));
            idx = f.n == exposure;
            field = sprintf('integer_count_threshold%d', j);
            assert(all(f.(field)(idx) == k), 'Independent count boundary differs.');
            thresholdChecks = thresholdChecks + nnz(idx);
        end
        for exposure = [30, 59, 60]
            k = max(12, massThreshold(exposure, means(j), shapes(j), q, bounds(j)) + 1);
            testEquivalenceAtEquality(exposure, k, means(j), shapes(j));
            equalityChecks = equalityChecks + 9;
        end
    end
end

% Exercise window expiry, gap reset, consecutive segments, gate occupancy
% at 9/10/11, and an unsupported count's exclusion in a quality gap.
component = [zeros(64, 1); -ones(4, 1); 7 * ones(63, 1); 10 * ones(33, 1)];
x = zeros(numel(component), 2);
x(1, :) = [9, 3];
x(46:56, 1) = 1;
x(65:68, :) = double(intmax('int32'));
x(69:131, 2) = mod((1:63).', 13);
x(145:157, 1) = 5;
means = [2.25, 3.25];
shapes = [exp(-8), exp(14)];
bounds = [1, 2];
rates = [2, 2.5];
expected = explicitWindows(x, component);
observed = state_score_native(x, component, means, shapes, bounds, rates);
compareWindows(observed, expected);
assert(isequal(observed.O15(54:56,1), [9; 10; 11]) && ...
    isequal(observed.gate(54:56,1), [false; true; true]) && ...
    isequal(observed.K(60:61,1), [20; 11]));
ref = zeros(size(x));
for j = 1:2
    ref(:,j) = independentContrast(expected.K(:,j), expected.n, means(j), shapes(j), q);
end
[maximum, ratio] = compareScores(observed.E, ref, 'synthetic');
largestError = max(largestError, maximum);
largestRatio = max(largestRatio, ratio);
compareRules(observed, expected, ref, bounds, rates);

largestCounts = repmat(double(intmax('int32')), 62, 2);
maxComp = zeros(62,1);
observeMax = state_score_native(largestCounts, maxComp, [1, 1], [NaN, NaN], [1, 1], [0, 0]);
compareWindows(observeMax, explicitWindows(largestCounts, maxComp));
assert(all(observeMax.K(60,:) == 60 * double(intmax('int32'))));

report = struct('status', 'PASS', 'cases', numel(ids), 'retained_rows', height(cases), ...
    'synthetic_window_rows', size(x,1) + size(largestCounts,1), ...
    'independent_count_threshold_checks', thresholdChecks, 'equality_checks', equalityChecks, ...
    'maximum_log_mass_difference', largestError, 'maximum_tolerance_ratio', largestRatio);

fprintf('PASS %s\n', version);
fprintf('Cases %d; retained rows %d; direct-window synthetic rows %d.\n', ...
    numel(ids), height(cases), size(x,1) + size(largestCounts,1));
fprintf('Independent log-PMF max difference %.17g; max retained-tolerance ratio %.17g.\n', ...
    largestError, largestRatio);
fprintf('Independent count thresholds %d; score and rate equality combinations %d.\n', ...
    thresholdChecks, equalityChecks);
end

function out = explicitWindows(x, component)
rows = size(x, 1);
out = struct('K', zeros(rows,2), 'O15', zeros(rows,2), 'n', zeros(rows,1), ...
    'n15', zeros(rows,1), 'rate', zeros(rows,2));
for row = 1:rows
    if component(row) < 0
        continue
    end
    different = find(component(1:row-1) ~= component(row), 1, 'last');
    begin = max([1, different + 1, row - 59]);
    gateBegin = max([1, different + 1, row - 14]);
    out.K(row,:) = sum(x(begin:row,:), 1);
    out.O15(row,:) = sum(x(gateBegin:row,:) > 0, 1);
    out.n(row) = row - begin + 1;
    out.n15(row) = row - gateBegin + 1;
    out.rate(row,:) = out.K(row,:) / out.n(row);
end
out.valid = out.n >= 30;
out.gate = (out.O15 >= 10) & out.valid;
end

function compareWindows(actual, expected)
for name = ["K", "O15", "n", "n15", "rate", "valid", "gate"]
    assert(isequal(actual.(name), expected.(name)), 'Explicit window mismatch in %s', name);
end
end

function compareRules(actual, windows, reference, bounds, rates)
score = (reference >= bounds) & windows.valid;
count = (windows.rate > rates) & windows.valid;
gate = windows.gate;
expected = [any(score & gate,2), any(score,2), any(count,2), any(count & gate,2), any(gate,2)];
assert(isequal(actual.family, expected), 'Independent decision rule mismatch.');
end

function [maximum, ratio] = compareScores(actual, expected, id)
difference = abs(actual - expected);
tolerance = 1e-10 + 2e-12 * abs(expected);
maximum = max(difference(:));
ratio = max(difference(:) ./ tolerance(:));
assert(ratio <= 1, 'Independent log-PMF mismatch in %s (max error %.17g)', id, maximum);
end

function value = independentContrast(count, exposure, mu, shape, q)
% The sum of equal-parameter working marginals has count total K,
% mean n*mu and, for NB, shape n*r. Evaluate each full log mass.
[pairs, ~, pairIndex] = unique([count(:), exposure(:)], 'rows');
contrasts = zeros(size(pairs,1),1);
for i = 1:size(pairs,1)
    k = pairs(i,1);
    n = pairs(i,2);
    if n > 0
        contrasts(i) = fullLogMass(k, n*q*mu, n*shape) - fullLogMass(k, n*mu, n*shape);
    end
end
value = contrasts(pairIndex);
end

function value = fullLogMass(k, meanCount, shape)
if isnan(shape)
    value = -meanCount + k*log(meanCount) - gammaln(k + 1);
else
    % Evaluate the gamma-ratio normalization via its finite product.
    % Keeping the log1p terms avoids subtracting large log gamma values.
    rising = sum(log1p((0:k-1)/shape));
    value = rising - gammaln(k + 1) + k*log(meanCount) - (shape + k)*log1p(meanCount/shape);
end
end

function k = massThreshold(exposure, mu, shape, q, bound)
lo = 0;
hi = 16;
while independentContrast(hi, exposure, mu, shape, q) < bound
    hi = hi * 2;
end
while hi - lo > 1
    center = floor((hi + lo)/2);
    if independentContrast(center, exposure, mu, shape, q) >= bound
        hi = center;
    else
        lo = center;
    end
end
k = hi;
end

function testEquivalenceAtEquality(n, k, mu, shape)
% Each input has ten occupied bins, so the gated rule tests the threshold
% of the same feature. Move each cutoff one machine unit either way.
params = {[mu, 1], [shape, NaN]};
target = state_score_native(equalityInput(n,k), zeros(n,1), params{:}, [1,1], [0,0]);
equalScore = target.E(end,1);
equalRate = k/n;
assert(equalScore - eps(equalScore) >= 1);
for cutoff = -1:1
    bound = equalScore + cutoff*eps(equalScore);
    rate = equalRate + cutoff*eps(equalRate);
    for count = k-1:k+1
        out = state_score_native(equalityInput(n,count), zeros(n,1), params{:}, [bound,1], [rate,0]);
        scoreAlarm = count >= k + (cutoff > 0);
        rateAlarm = count >= k + (cutoff >= 0);
        assert(out.gate(end,1) && isequal(out.family(end,:), ...
            [scoreAlarm, scoreAlarm, rateAlarm, rateAlarm, true]), ...
            'Inclusive score or strict-rate equality case differs.');
    end
end
end

function x = equalityInput(n,k)
x = zeros(n,2);
x(end-9:end,1) = 1;
x(end,1) = k-9;
end
