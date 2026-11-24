function [logOdds, belief] = evidence_path(increments, prior, floorProbability)
%EVIDENCE_PATH Accumulate evidence without probability-space saturation.
% Elias Calboreanu. A positive floor defines a modified diagnostic rule.
assert(isvector(increments) && all(isfinite(increments(:))) && ...
    isscalar(prior) && isfinite(prior) && prior > 0 && prior < 1 && ...
    isscalar(floorProbability) && isfinite(floorProbability) && ...
    floorProbability >= 0 && floorProbability < 1, 'Invalid evidence parameters.');
increments = increments(:);
logOdds = zeros(numel(increments) + 1, 1);
logOdds(1) = log(prior) - log1p(-prior);
floorLogOdds = -Inf;
if floorProbability > 0
    floorLogOdds = log(floorProbability) - log1p(-floorProbability);
end
for i = 1:numel(increments)
    logOdds(i + 1) = max(logOdds(i) + increments(i), floorLogOdds);
end
belief = zeros(size(logOdds));
positive = logOdds >= 0;
belief(positive) = 1 ./ (1 + exp(-logOdds(positive)));
odds = exp(logOdds(~positive));
belief(~positive) = odds ./ (1 + odds);
end
