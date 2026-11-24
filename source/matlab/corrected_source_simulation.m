function result = corrected_source_simulation(kind, makeFigures)
%CORRECTED_SOURCE_SIMULATION Numerical revisions of Hossain's illustrations.
% Elias Calboreanu. These are model simulations, not measured study results.
if nargin < 2, makeFigures = true; end
savedRandomState = rng;
restoreRandomState = onCleanup(@() rng(savedRandomState));
rng(42, 'twister');
switch kind
    case 'fair'
        result = fairSimulation(makeFigures);
    case 'binary'
        result = detectorSimulation(false, makeFigures);
    case 'count'
        result = detectorSimulation(true, makeFigures);
    otherwise
        error('Unknown source illustration.');
end
end

function result = fairSimulation(makeFigures)
specification = [0.5, 0.8, 1.2; 80, 94, 120; 5, 15, 40];
draws = zeros(10000, 3);
expectations = zeros(1, 3);
alpha = expectations; beta = expectations;
for j = 1:3
    bounds = specification(j, :);
    [alpha(j), beta(j), expectations(j)] = pert_parameters(bounds(1), bounds(2), bounds(3), 4);
    betaDraw = betaincinv(rand(10000, 1), alpha(j), beta(j));
    draws(:, j) = bounds(1) + (bounds(3) - bounds(1)) * betaDraw;
end
annualExposure = draws(:, 1) .* (draws(:, 2) + draws(:, 3));
ordered = sort(annualExposure);
rank = 1 + 0.95 * (numel(ordered) - 1);
p95 = ordered(floor(rank)) + (rank - floor(rank)) * ...
    (ordered(ceil(rank)) - ordered(floor(rank)));
result = struct('seed', 42, 'sample_count', 10000, 'alpha', alpha, 'beta', beta, ...
    'analytic_mean_annual_exposure', expectations(1) * (expectations(2) + expectations(3)), ...
    'sample_mean_annual_exposure', mean(annualExposure), 'sample_std_annual_exposure', std(annualExposure), ...
    'sample_p95_annual_exposure', p95, 'sample_median_annual_exposure', median(annualExposure));
if makeFigures
    fig = publicationFigure();
    histogram(annualExposure, 50, 'Normalization', 'pdf');
    xline(result.sample_mean_annual_exposure, '--k', 'Sample mean');
    xline(p95, '--r', '95th percentile');
    xlabel('Annualized loss exposure (million currency units per year)');
    ylabel('Density'); title('Illustrative independent beta-PERT inputs'); grid on;
    set(fig, 'Name', 'FAIR illustration — assumed inputs');
end
end

function result = detectorSimulation(useCounts, makeFigures)
time = (0:100).';
binStart = time(1:end-1);
rate0 = 50; prior = 0.02;
if useCounts
    rate1 = 62; attackStart = 15; attackStop = 75;
    harmProbabilities = [0.450, 0.739, 0.920];
    floorProbability = 0.005;
else
    rate1 = 80; attackStart = 35; attackStop = 75;
    harmProbabilities = 0.739;
    floorProbability = 0;
end
elevated = binStart >= attackStart & binStart < attackStop;
means = rate0 + (rate1 - rate0) * elevated;
counts = sample_poisson_reference(means);
if useCounts
    increments = poisson_log_ratio(counts, rate0, rate1, 1);
    cutoff = NaN; falsePositive = NaN; sensitivity = NaN;
else
    [cutoff, falsePositive, sensitivity] = model_alert_rates(rate0, rate1, 0.95);
    alert = counts > cutoff;
    increments = alert * log(sensitivity / falsePositive) + ...
        (~alert) * (log1p(-sensitivity) - log1p(-falsePositive));
end
[logOdds, belief] = evidence_path(increments, prior, floorProbability);
[unflooredLogOdds, unflooredBelief] = evidence_path(increments, prior, 0);
threshold = zeros(size(harmProbabilities));
firstCrossing = NaN(size(harmProbabilities));
for j = 1:numel(harmProbabilities)
    % Assumed conditional loss over the decision horizon, not annual FAIR exposure.
    [threshold(j), bound] = containment_threshold(15, harmProbabilities(j), 92.58);
    index = find(logOdds >= bound, 1);
    if ~isempty(index), firstCrossing(j) = time(index); end
end
result = struct('seed', 42, 'time', time, 'bin_start', binStart, 'counts', counts, ...
    'elevated_bin', elevated, 'attack_interval', [attackStart, attackStop], ...
    'increments', increments, 'log_odds', logOdds, 'belief_display', belief, ...
    'unfloored_log_odds', unflooredLogOdds, 'unfloored_belief_display', unflooredBelief, ...
    'floor_probability', floorProbability, 'alert_cutoff', cutoff, ...
    'false_positive_probability', falsePositive, 'sensitivity', sensitivity, ...
    'thresholds', threshold, 'first_crossing_seconds', firstCrossing);
if makeFigures
    fig = publicationFigure();
    subplot(2,1,1); stairs(time(2:end), counts); hold on;
    xline(attackStart, ':k'); xline(attackStop, ':k');
    ylabel('Count in preceding second'); title('Simulated observations at bin end'); grid on;
    subplot(2,1,2); plot(time, belief, 'LineWidth', 1.5); hold on;
    if floorProbability > 0
        plot(time, unflooredBelief, '--', 'LineWidth', 1.1);
        legend('Floored diagnostic belief', 'Unfloored model belief', 'Location', 'best');
    end
    for j = 1:numel(threshold)
        yline(threshold(j), ':', sprintf('Cost indifference %.3f', threshold(j)));
    end
    xline(attackStart, ':k'); xline(attackStop, ':k'); ylim([0,1]);
    ylabel('Diagnostic model belief'); xlabel('Time (s)'); grid on;
    title('Fixed-hypothesis evidence on a changing simulated stream');
    set(fig, 'Name', 'Illustrative scoring — no calibrated threat probability');
end
end

function fig = publicationFigure()
fig = figure('Color', 'w', 'Position', [100,100,900,650], ...
    'DefaultAxesColor', 'w', 'DefaultAxesXColor', 'k', 'DefaultAxesYColor', 'k', ...
    'DefaultTextColor', 'k', 'DefaultLegendTextColor', 'k', 'DefaultLegendColor', 'w', ...
    'DefaultAxesFontSize', 11);
end
