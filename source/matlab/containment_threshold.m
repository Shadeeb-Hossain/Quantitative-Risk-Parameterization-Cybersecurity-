function [probability, logOdds] = containment_threshold(actionCost, harmProbability, conditionalLoss)
%CONTAINMENT_THRESHOLD Restricted one-decision expected-cost indifference.
% Elias Calboreanu. Costs use the same units and horizon; action prevents loss.
assert(all(isfinite([actionCost, harmProbability, conditionalLoss])) && ...
    actionCost > 0 && harmProbability > 0 && harmProbability <= 1 && ...
    conditionalLoss > 0, 'Invalid decision inputs.');
probability = actionCost / (harmProbability * conditionalLoss);
if probability >= 1
    logOdds = Inf; % No strict benefit at a finite posterior log odds.
else
    logOdds = log(probability) - log1p(-probability);
end
end
