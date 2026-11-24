function out = state_score_native(x, component, mu, shape, scoreBound, rateCutoff)
%STATE_SCORE_NATIVE Replay five rules on two observed per-second features.
% Elias Calboreanu. Adapted from the frozen response-watermark MATLAB scorer.
% A NaN shape selects the Poisson working marginal. The score is an
% affine log-likelihood contrast in count and exposure.
% Rows with component -1 are ineligible. Each nonnegative component must
% occupy one contiguous segment and starts with empty windows.

q = 1.24;
window = 60;
gateWindow = 15;
minExposure = 30;
minOccupied = 10;

assert(isnumeric(x) && isreal(x) && ismatrix(x) && size(x, 2) == 2 && ...
    all(isfinite(x(:))) && all(x(:) >= 0) && all(x(:) == fix(x(:))) && ...
    all(x(:) <= double(intmax('int32'))), 'state_score_native:Counts', ...
    'Counts must be two columns of nonnegative int32-range integers.');
x = double(x);
component = double(component(:));
assert(numel(component) == size(x, 1) && isreal(component) && ...
    all(isfinite(component) & component >= -1 & component == fix(component)), ...
    'state_score_native:Component', 'Supply one integer component per bin.');

mu = double(mu(:).');
shape = double(shape(:).');
scoreBound = double(scoreBound(:).');
rateCutoff = double(rateCutoff(:).');
assert(numel(mu) == 2 && numel(shape) == 2 && numel(scoreBound) == 2 && ...
    numel(rateCutoff) == 2 && isreal([mu, shape, scoreBound, rateCutoff]) && ...
    all(isfinite(mu) & mu > 0) && all(isnan(shape) | (isfinite(shape) & shape > 0)) && ...
    all(isfinite(scoreBound) & scoreBound >= 1) && ...
    all(isfinite(rateCutoff) & rateCutoff >= 0), ...
    'state_score_native:Parameters', 'Supply valid parameters for both features.');

countCoefficient = repmat(log(q), 1, 2);
exposureCoefficient = -(q - 1) * mu;
nb = ~isnan(shape);
adjustment = log1p((q - 1) * mu(nb) ./ (shape(nb) + mu(nb)));
countCoefficient(nb) = countCoefficient(nb) - adjustment;
exposureCoefficient(nb) = -shape(nb) .* adjustment;

rows = size(x, 1);
K = zeros(rows, 2);
n = zeros(rows, 1);
O15 = zeros(rows, 2);
n15 = zeros(rows, 1);
countBuffer = zeros(window, 2);
positiveBuffer = zeros(gateWindow, 2);
windowCount = zeros(1, 2);
occupied = zeros(1, 2);
componentStart = [true; component(2:end) ~= component(1:end-1)];
activeStarts = find(componentStart(1:rows) & component >= 0);
assert(numel(unique(component(activeStarts))) == numel(activeStarts), ...
    'state_score_native:RepeatedComponent', 'An active component cannot resume after a gap.');

used = 0;
for i = 1:rows
    if component(i) < 0
        continue
    end
    if componentStart(i)
        countBuffer(:) = 0;
        positiveBuffer(:) = 0;
        windowCount(:) = 0;
        occupied(:) = 0;
        used = 0;
    end

    used = used + 1;
    countIndex = mod(used - 1, window) + 1;
    gateIndex = mod(used - 1, gateWindow) + 1;
    windowCount = windowCount - countBuffer(countIndex, :) + x(i, :);
    countBuffer(countIndex, :) = x(i, :);
    positive = double(x(i, :) > 0);
    occupied = occupied - positiveBuffer(gateIndex, :) + positive;
    positiveBuffer(gateIndex, :) = positive;

    K(i, :) = windowCount;
    O15(i, :) = occupied;
    n(i) = min(used, window);
    n15(i) = min(used, gateWindow);
end

E = K .* countCoefficient + n .* exposureCoefficient;
valid = n >= minExposure;
gate = (O15 >= minOccupied) & valid;
rate = zeros(rows, 2);
hasExposure = n > 0;
rate(hasExposure, :) = K(hasExposure, :) ./ n(hasExposure);
scoreAlarm = (E >= scoreBound) & valid;
rateAlarm = (rate > rateCutoff) & valid;

family = [any(scoreAlarm & gate, 2), any(scoreAlarm, 2), any(rateAlarm, 2), ...
    any(rateAlarm & gate, 2), any(gate, 2)];
out = struct('K', K, 'n', n, 'O15', O15, 'n15', n15, 'E', E, ...
    'valid', valid, 'gate', gate, 'rate', rate, 'family', family, ...
    'countCoefficient', countCoefficient, 'exposureCoefficient', exposureCoefficient);
end
