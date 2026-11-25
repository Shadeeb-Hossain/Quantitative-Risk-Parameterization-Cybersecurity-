function [cutoff, falsePositive, sensitivity] = model_alert_rates(mean0, mean1, quantile)
%MODEL_ALERT_RATES Exact Poisson probabilities for the strict count alert.
% Elias Calboreanu
% The reference cutoff is the first integer with CDF at least quantile.
% Both alert probabilities use the upper count tail P(X > cutoff).
assert(all(isfinite([mean0, mean1, quantile])) && mean0 > 0 && mean1 > 0 && ...
    quantile > 0 && quantile < 1, 'Invalid alert parameters.');
cutoff = 0;
while gammainc(mean0, cutoff + 1, 'upper') < quantile
    cutoff = cutoff + 1;
end
falsePositive = gammainc(mean0, cutoff + 1, 'lower');
sensitivity = gammainc(mean1, cutoff + 1, 'lower');
assert(min([falsePositive, sensitivity]) > 0 && max([falsePositive, sensitivity]) < 1, ...
    'Alert probabilities cannot be represented in the required open interval.');
end
