function export_paper_figures(alarms, service, f04, outputDirectory)
%EXPORT_PAPER_FIGURES Export paper figures and their plotted values.
% Elias Calboreanu

exportDetectorComparison(alarms, outputDirectory);
exportResponseTimeline(f04, outputDirectory);
exportServiceLatency(service, f04, outputDirectory);
end

function exportDetectorComparison(alarms, outputDirectory)
profiles = {'steady', 'bursty', 'impaired', 'syn', 'null'};
profileLabels = {'Steady', 'Bursty', 'Impaired', 'SYN load', 'NULL load'};
rules = {'corrected_score_gate', 'count_rate_gate', 'persistence'};
ruleLabels = {'Score + gate', 'Count rate + gate', 'Persistence only'};
colors = [0.00, 0.34, 0.59; 0.03, 0.51, 0.37; 0.84, 0.38, 0.14];

fig = newFigure(1000, 490);
cleanup = onCleanup(@() close(fig));
ax = axes('parent', fig);
hold(ax, 'on');
nRows = numel(profiles) * numel(rules);
blank = zeros(nRows, 1);
data = struct('profile', {cell(nRows, 1)}, 'rule', {cell(nRows, 1)}, 'trial_count', blank, ...
    'median_alarm_seconds', blank, 'minimum_alarm_seconds', blank, 'maximum_alarm_seconds', blank);
row = 0;
center = zeros(numel(profiles), numel(rules));
low = center;
high = center;

for j = 1:numel(profiles)
    subset = strcmp(alarms.profile, profiles{j});
    assert(any(subset), 'Expected trials for profile %s.', profiles{j});
    profileLabels{j} = sprintf('%s (n = %d)', profileLabels{j}, nnz(subset));
    for k = 1:numel(rules)
        values = alarms.(['alarm_seconds_state_', rules{k}]);
        values = values(subset);
        center(j, k) = median(values);
        low(j, k) = min(values);
        high(j, k) = max(values);
        row = row + 1;
        data.profile{row} = profiles{j};
        data.rule{row} = rules{k};
        data.trial_count(row) = nnz(subset);
        data.median_alarm_seconds(row) = center(j, k);
        data.minimum_alarm_seconds(row) = low(j, k);
        data.maximum_alarm_seconds(row) = high(j, k);
    end
end

for k = 1:numel(rules)
    x = (1:numel(profiles)).' + 0.23 * (k - 2);
    bars(k) = bar(ax, x, center(:, k), 0.20, 'facecolor', colors(k, :), 'edgecolor', 'none');
    varies = find(low(:, k) < high(:, k)).';
    for j = varies
        whisker = [0.16, 0.19, 0.23];
        plot(ax, [x(j), x(j)], [low(j,k), high(j,k)], '-', 'color', whisker);
        plot(ax, x(j) + [-0.05, 0.05], [low(j,k), low(j,k)], '-', 'color', whisker);
        plot(ax, x(j) + [-0.05, 0.05], [high(j,k), high(j,k)], '-', 'color', whisker);
    end
    zero = center(:, k) == 0;
    plot(ax, x(zero), center(zero, k), 'o', 'markersize', 4, ...
        'markerfacecolor', colors(k, :), 'markeredgecolor', colors(k, :));
end
styleAxes(ax);
title(ax, 'Handshake-state rules across held-out trials');
ylabel(ax, 'Alarm seconds per trial');
set(ax, 'xlim', [0.50, 5.50], 'ylim', [-3, 110], 'ytick', 0:20:100, ...
    'xtick', 1:numel(profiles), 'xticklabel', profileLabels);
key = legend(ax, bars, ruleLabels, 'location', 'northwest', 'box', 'off');
styleLegend(key);

stem = fullfile(outputDirectory, 'figure2_detector_comparison');
write_csv([stem, '.csv'], data);
exportFigure(fig, stem);
end

function exportResponseTimeline(f04, outputDirectory)
decision = f04.decision;
events = f04.events;
time = @(name) events.s_since_load_start(strcmp(events.event, name));
first = f04.firstCrossingIndex;
timeLimits = [0, ceil(time('actual_load_end'))];
scoreColor = [0.00, 0.34, 0.59];
actionColor = [0.78, 0.27, 0.12];
countColor = [0.03, 0.51, 0.37];

fig = newFigure(1000, 675);
cleanup = onCleanup(@() close(fig));
ax = subplot(2, 1, 1, 'parent', fig);
hold(ax, 'on');
countTime = decision.decision_s_since_load_start(first.count_rate);
scoreTime = decision.decision_s_since_load_start(first.score_only);
gatedTime = decision.decision_s_since_load_start(first.corrected_score_gate);
detail = [floor(countTime) - 3, ceil(gatedTime) + 4];
inView = decision.decision_s_since_load_start >= detail(1) & decision.decision_s_since_load_start <= detail(2);
scoreLimits = [-10, 1.12 * max(decision.score(inView))];

threshold = plot(ax, detail, [1, 1] * decision.score_bound(1), '--', ...
    'color', [0.37, 0.42, 0.47], 'linewidth', 1.2);
trace = stairs(ax, decision.decision_s_since_load_start, decision.score, ...
    'color', scoreColor, 'linewidth', 1.9);
countOnly = plot(ax, [countTime, countTime], scoreLimits, ':', 'color', countColor, 'linewidth', 1.7);
scoreOnly = plot(ax, scoreTime, decision.score(first.score_only), ...
    's', 'markersize', 7, 'markerfacecolor', scoreColor, 'markeredgecolor', scoreColor);
crossing = plot(ax, gatedTime, decision.score(first.corrected_score_gate), ...
    'o', 'markersize', 7, 'markerfacecolor', actionColor, 'markeredgecolor', actionColor);
set(ax, 'xlim', detail, 'ylim', scoreLimits);
ylabel(ax, 'Log score');
title(ax, 'A. First crossings on the affected source');
xlabel(ax, 'Time since observed SYN load start (s)');
styleAxes(ax);
labels = {'Affected-source log score', 'Score bound', sprintf('Count rate only, %.3f s', countTime), ...
    sprintf('Score only, %.3f s', scoreTime), sprintf('Shared gated crossing, %.3f s', gatedTime)};
key = legend(ax, [trace, threshold, countOnly, scoreOnly, crossing], labels, ...
    'location', 'eastoutside', 'box', 'off');
set(key, 'fontsize', 11);
styleLegend(key);

ax = subplot(2, 1, 2, 'parent', fig);
hold(ax, 'on');
plot(ax, [time('actual_load_start'), time('actual_load_end')], [3, 3], ...
    '-', 'color', [0.63, 0.66, 0.69], 'linewidth', 5);
plot(ax, [time('guarded_admission_start'), time('guarded_admission_end')], [2, 2], ...
    '-', 'color', scoreColor, 'linewidth', 6);
plot(ax, [time('guarded_ack_grace_start'), time('guarded_ack_grace_end')], [1, 1], ...
    '-', 'color', countColor, 'linewidth', 6);
installed = time('action_installed');
plot(ax, installed, 3, 'd', 'markersize', 8, 'markerfacecolor', actionColor, ...
    'markeredgecolor', actionColor);
text(ax, installed + 2, 3.25, sprintf('Response installed at %.3f s', installed), ...
    'color', actionColor, 'fontsize', 12);
set(ax, 'ytick', 1:3, 'yticklabel', {'Guarded ACK grace', 'Guarded admission', 'Observed SYN load'}, ...
    'ylim', [0.5, 3.65], 'xlim', timeLimits, 'xtick', 0:10:90);
xlabel(ax, 'Time since observed SYN load start (s)');
title(ax, 'B. Observed load and verified response intervals');
styleAxes(ax);
set(ax, 'ygrid', 'off', 'xgrid', 'on');
position = get(ax, 'position');
right = position(1) + position(3);
position(1) = max(position(1), 0.18);
position(3) = right - position(1);
set(ax, 'position', position);

write_csv(fullfile(outputDirectory, 'figure3_f04_decision.csv'), decision);
write_csv(fullfile(outputDirectory, 'figure3_f04_events.csv'), events);
exportFigure(fig, fullfile(outputDirectory, 'figure3_f04_timeline'));
end

function exportServiceLatency(service, f04, outputDirectory)
data = f04.latencies;
events = f04.events;
start = events.s_since_load_start(strcmp(events.event, 'guarded_admission_start'));
stop = events.s_since_load_start(strcmp(events.event, 'guarded_admission_end'));
fig = newFigure(960, 565);
cleanup = onCleanup(@() close(fig));
ax = axes('parent', fig, 'position', [0.13, 0.22, 0.79, 0.64]);
hold(ax, 'on');
reference = plot(ax, data.scheduled_s_since_load_start, data.observe_ms, 'o', ...
    'linestyle', 'none', 'markersize', 6, 'color', [0.00, 0.34, 0.59], 'linewidth', 1.15);
conditional = plot(ax, data.scheduled_s_since_load_start, data.conditional_proxy_ms, '^', ...
    'linestyle', 'none', 'markersize', 6, 'markeredgecolor', [0.78, 0.27, 0.12], ...
    'markerfacecolor', [0.78, 0.27, 0.12]);
set(ax, 'yscale', 'log', 'xlim', [start, stop], 'ylim', [0.25, 3000], ...
    'ytick', [1, 10, 100, 1000]);
xlabel(ax, 'Scheduled request time since observed SYN load start (s)');
ylabel(ax, 'Successful request latency (ms)');
title(ax, sprintf('F04 guarded admission, %d matched requests per arm', numel(data.seq)));
text(ax, stop - 0.3, 420, ...
    {sprintf('Added p95  +%.2f ms', service.f04_added_p95_ms), ...
    sprintf('Added-p95 limit  %.0f ms', service.added_p95_limit_ms)}, ...
    'horizontalalignment', 'right', 'verticalalignment', 'top', 'fontsize', 12, 'color', 'black');
key = legend(ax, [reference, conditional], ...
    {sprintf('Observe (p95 %.2f ms)', service.f04_observe_p95_ms), ...
    sprintf('Conditional proxy (p95 %.2f ms)', service.f04_conditional_p95_ms)}, ...
    'orientation', 'horizontal', 'box', 'off');
set(key, 'position', [0.23, 0.038, 0.57, 0.06]);
styleLegend(key);
styleAxes(ax);

stem = fullfile(outputDirectory, 'figure4_f04_service_latency');
write_csv([stem, '.csv'], data);
exportFigure(fig, stem);
end

function fig = newFigure(width, height)
fig = figure('visible', 'off', 'color', 'white', 'position', [80, 80, width, height]);
set(fig, 'defaultaxesfontname', 'Helvetica', 'defaulttextfontname', 'Helvetica', ...
    'defaultaxescolor', 'white', 'defaulttextcolor', 'black');
page = [width, height] / 100;
set(fig, 'paperunits', 'inches', 'papersize', page, ...
    'paperposition', [0, 0, page], 'paperpositionmode', 'manual', 'inverthardcopy', 'off');
end

function styleAxes(ax)
set(ax, 'fontsize', 12, 'box', 'off', 'tickdir', 'out', ...
    'layer', 'top', 'ygrid', 'on', 'gridalpha', 0.15, 'gridcolor', [0.38, 0.44, 0.50], ...
    'color', 'white', 'xcolor', 'black', 'ycolor', 'black', ...
    'yminorgrid', 'off', 'yminortick', 'off');
set(get(ax, 'title'), 'color', 'black');
set(get(ax, 'xlabel'), 'color', 'black');
set(get(ax, 'ylabel'), 'color', 'black');
end

function styleLegend(key)
set(key, 'color', 'white', 'textcolor', 'black');
end

function exportFigure(fig, stem)
drawnow;
print(fig, [stem, '.pdf'], '-dpdf', '-painters');
print(fig, [stem, '.png'], '-dpng', '-painters', '-r300');
end
