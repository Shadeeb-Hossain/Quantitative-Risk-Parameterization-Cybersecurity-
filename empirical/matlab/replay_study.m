function [alarms, checks, f04, parameters] = replay_study(dataDirectory)
%REPLAY_STUDY Verify held-out arrays and combine the two sources in each trial.
% Elias Calboreanu

trials = read_csv(fullfile(dataDirectory, 'trial_summary.csv'), ...
    {'trial_id', 'block_id', 'arm', 'profile', 'logical_success_latency_ms_method', ...
    'message_success_latency_ms_method', 'full_report_sha256'});
bins = read_csv(fullfile(dataDirectory, 'native_cases.csv'), ...
    {'case_id', 'trial_id', 'detector', 'target_role'});
parameters = jsondecode(fileread(fullfile(dataDirectory, 'native_parameters.json')));
detectors = {'state', 'quantity'};
roles = {'affected', 'peer'};
rules = {'corrected_score_gate', 'score_only', 'count_rate', 'count_rate_gate', 'persistence'};
familyColumns = strcat('family_', rules);
secondsPerTrial = 300;
trialCount = numel(trials.trial_id);

assert(trialCount == 36 && numel(unique(trials.trial_id)) == 36, ...
    'Expected 36 distinct held-out trials.');
caseCount = trialCount * numel(detectors) * numel(roles);
assert(numel(bins.bin_index) == caseCount * secondsPerTrial && ...
    numel(unique(bins.case_id)) == caseCount, 'Expected 144 cases with 300 seconds each.');

alarms = struct('trial_id', {trials.trial_id}, 'block_id', {trials.block_id}, ...
    'arm', {trials.arm}, 'profile', {trials.profile}, 'ordinary_impaired', trials.ordinary_impaired);
blank = zeros(caseCount, 1);
checks = struct('case_id', {cell(caseCount, 1)}, 'maximum_input_count', blank, ...
    'maximum_window_count', blank, 'maximum_score_absolute_difference', blank, ...
    'maximum_score_tolerance_ratio', blank);
families = false(secondsPerTrial, numel(rules), trialCount, numel(detectors));
caseIndex = 0;

for d = 1:numel(detectors)
    detector = detectors{d};
    [mu, shape, scoreBound, rateCutoff] = unpackParameters(parameters.(detector));
    for t = 1:trialCount
        trial = trials.trial_id{t};
        family = false(secondsPerTrial, numel(rules));
        for j = 1:numel(roles)
            role = roles{j};
            caseID = [trial, '_', detector, '_', role];
            fixture = csv_subset(bins, strcmp(bins.case_id, caseID));
            [~, order] = sort(fixture.bin_index);
            fixture = csv_subset(fixture, order);
            assert(isequal(fixture.bin_index, (0:secondsPerTrial-1).') && ...
                all(strcmp(fixture.trial_id, trial) & strcmp(fixture.detector, detector) & ...
                strcmp(fixture.target_role, role)), 'Invalid bin sequence or metadata in %s.', caseID);
            x = [fixture.x1, fixture.x2];
            out = state_score_native(x, fixture.component, mu, shape, scoreBound, rateCutoff);
            [errorMax, errorRatio] = validateCase(out, fixture, familyColumns, scoreBound, caseID);
            if strcmp(caseID, 'f04p_state_affected')
                f04.affected = out;
            end
            family = family | out.family;
            caseIndex = caseIndex + 1;
            checks.case_id{caseIndex} = caseID;
            checks.maximum_input_count(caseIndex) = max(x(:));
            checks.maximum_window_count(caseIndex) = max(out.K(:));
            checks.maximum_score_absolute_difference(caseIndex) = errorMax;
            checks.maximum_score_tolerance_ratio(caseIndex) = errorRatio;
        end
        families(:, :, t, d) = family;
    end

    totals = reshape(sum(families(:, :, :, d), 1), numel(rules), []).';
    for r = 1:numel(rules)
        column = ['alarm_seconds_', detector, '_', rules{r}];
        assert(isequal(totals(:, r), trials.(column)), ...
            'Trial totals differ from the retained %s evidence.', column);
        alarms.(column) = totals(:, r);
    end
end

scoreAndGate = families(:, 1, :, 1);
countAndGate = families(:, 4, :, 1);
assert(isequal(scoreAndGate, countAndGate), ...
    'The retained state score+gate and count+gate decisions must agree in every trial bin.');
alarms.state_count_gate_identical_every_bin = reshape(all(scoreAndGate == countAndGate, 1), [], 1);
alarms.state_persistence_identical_every_bin = reshape(all(scoreAndGate == families(:, 5, :, 1), 1), [], 1);
assert(isequal(double(alarms.state_persistence_identical_every_bin), ...
    trials.state_persistence_identical_every_bin), 'Persistence agreement differs from the frozen summaries.');
f04.family = families(:, :, strcmp(trials.trial_id, 'f04p'), 1);
end

function [mu, shape, scoreBound, rateCutoff] = unpackParameters(parameters)
model = parameters.model;
policy = parameters.policy;
assert(isequal([model.q, model.W, model.G, model.minimum_seconds, model.occupied], ...
    [1.24, 60, 15, 30, 10]) && isequal(model.feature_names, policy.feature_names) && ...
    numel(model.features) == 2 && ~policy.probability_calibration, ...
    'Model or policy differs from the frozen two-feature definition.');
mu = [model.features.mean];
shape = NaN(1, 2);
for j = 1:2
    if ~isempty(model.features(j).shape)
        shape(j) = model.features(j).shape;
    end
end
scoreBound = policy.score_bounds;
rateCutoff = policy.rate_cutoffs;
end

function [errorMax, errorRatio] = validateCase(out, fixture, familyColumns, scoreBound, caseID)
scoreBound = reshape(scoreBound, 1, 2);
family = zeros(numel(fixture.n), numel(familyColumns));
for j = 1:numel(familyColumns)
    family(:, j) = fixture.(familyColumns{j});
end
gate = [fixture.gate1, fixture.gate2];
expectedScores = [fixture.E1, fixture.E2];
scoreError = abs(out.E - expectedScores);
scoreTolerance = 1e-10 + 2e-12 * abs(expectedScores);

exactChecks = [isequal(out.K, [fixture.K1, fixture.K2]), ...
    isequal(out.n, fixture.n), isequal(out.O15, [fixture.O15_1, fixture.O15_2]), ...
    isequal(double(out.valid), fixture.valid), isequal(double(out.family), family), ...
    isequal(out.n15, fixture.n15), isequal(double(out.gate), gate)];
assert(all(exactChecks), 'Count, exposure or decision mismatch in %s.', caseID);
assert(all(scoreError(:) <= scoreTolerance(:)), 'Score tolerance exceeded in %s.', caseID);
rateError = abs(out.rate - [fixture.rate1, fixture.rate2]);
assert(all(rateError(:) <= 1e-12), 'Count-rate mismatch in %s.', caseID);

% Recheck the count boundary with the same comparison as the numeric score.
alpha = out.countCoefficient;
assert(all(alpha > 0), 'Expected a positive count coefficient in %s.', caseID);
offset = out.n .* out.exposureCoefficient;
cap = double(intmax('int32')) * 60 + 1;
threshold = min(ceil((scoreBound - offset) ./ alpha), cap);
converged = false;
for step = 1:4
    down = threshold > 0 & (threshold - 1) .* alpha + offset >= scoreBound;
    up = threshold < cap & threshold .* alpha + offset < scoreBound;
    if ~any(down(:) | up(:))
        converged = true;
        break
    end
    threshold = threshold - double(down) + double(up);
end
assert(converged && ...
    isequal(threshold, [fixture.integer_count_threshold1, fixture.integer_count_threshold2]) && ...
    isequal(any((out.K >= threshold) & out.gate, 2), out.family(:, 1)), ...
    'Integer count-boundary mismatch in %s.', caseID);
errorMax = max(scoreError(:));
errorRatio = max(scoreError(:) ./ scoreTolerance(:));
end
