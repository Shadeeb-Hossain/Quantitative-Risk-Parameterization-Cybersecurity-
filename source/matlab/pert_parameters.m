function [alpha, beta, expectation] = pert_parameters(low, mode, high, weight)
%PERT_PARAMETERS Stable beta-PERT parameters and expected value.
% Elias Calboreanu
assert(all(isfinite([low, mode, high, weight])) && low < high && ...
    low <= mode && mode <= high && weight >= 0, 'Invalid PERT parameters.');
alpha = 1 + weight * (mode - low) / (high - low);
beta = 1 + weight * (high - mode) / (high - low);
expectation = low + (high - low) * alpha / (alpha + beta);
end
