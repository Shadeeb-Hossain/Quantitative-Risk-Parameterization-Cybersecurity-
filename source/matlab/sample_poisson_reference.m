function values = sample_poisson_reference(means)
%SAMPLE_POISSON_REFERENCE Inverse-CDF draws for the source simulations.
% Elias Calboreanu. Restricted to their small means; base MATLAB only.
assert(all(isfinite(means(:)) & means(:) > 0 & means(:) <= 100), ...
    'The illustrative sampler supports means in (0,100].');
uniform = rand(size(means));
values = zeros(size(means));
for meanValue = unique(means(:)).'
    k = (0:ceil(meanValue + 12 * sqrt(meanValue) + 20)).';
    cumulative = gammainc(meanValue, k + 1, 'upper');
    assert(cumulative(end) == 1, 'Poisson CDF does not cover the sampling precision.');
    for i = find(means(:) == meanValue).'
        values(i) = find(cumulative >= uniform(i), 1) - 1;
    end
end
end
