function count = test_state_score_native()
%TEST_STATE_SCORE_NATIVE Test boundaries of the frozen rolling scorer.
% Elias Calboreanu
tests = {@testPoissonAndNegativeBinomialScores, @testWindowExpiryAndCoverageReset, ...
    @testScoreEqualityAndStrictRateCutoff, @testGateMustMatchTheTriggeringFeature, ...
    @testMaximumSupportedCountsRemainExact, @testRejectsInvalidCountsAndDisjointComponents};
for i = 1:numel(tests)
    tests{i}();
end
count = numel(tests);
end

function testPoissonAndNegativeBinomialScores()
x = [ones(29, 1), 2 * ones(29, 1); 5, 6];
out = state_score_native(x, zeros(30, 1), [0.2, 3], [NaN, 2], [1, 1], [0, 0]);

q = 1.24;
poissonContrast = 34 * log(q) - 30 * (q - 1) * 0.2;
% The NB probability-mass ratio cancels the combinatorial factor.
nbContrast = 64 * log((q * 3 / (2 + q * 3)) / (3 / (2 + 3))) ...
    + 30 * 2 * log((2 + 3) / (2 + q * 3));
verifyEqual(out.E(30, :), [poissonContrast, nbContrast], 1e-12);
verifyEqual(out.n(29:30), [29; 30]);
assert(~any(out.family(29, :)));
assert(out.valid(30));
end

function testWindowExpiryAndCoverageReset()
x = zeros(94, 2);
x(1, :) = [5, 9];
x(46:55, 1) = 1;
x(64, :) = [20, 30]; % Ineligible input cannot enter a rolling window.
component = [zeros(63, 1); -1; ones(30, 1)];
out = state_score_native(x, component, [1, 1], [NaN, NaN], [1, 1], [0, 0]);

verifyEqual(out.n(60:65), [60; 60; 60; 60; 0; 1]);
verifyEqual(out.n15(63:65), [15; 0; 1]);
verifyEqual(out.K(60:61, :), [15, 9; 10, 0]);
verifyEqual(out.K(64:65, :), zeros(2));
verifyEqual(out.E(64, :), [0, 0]);
verifyEqual(out.O15(59:61, 1), [10; 10; 9]);
verifyEqual(out.gate(60:61, 1), [true; false]);
assert(~any(out.valid(64:93)));
assert(out.valid(94));
end

function testScoreEqualityAndStrictRateCutoff()
x = [ones(30, 1), zeros(30, 1)];
out = state_score_native(x, zeros(30, 1), [0.1, 1], [NaN, NaN], [1, 1], [1, 0]);
atEquality = state_score_native(x, zeros(30, 1), [0.1, 1], [NaN, NaN], ...
    [out.E(30, 1), 1], [1, 0]);
verifyEqual(atEquality.family(30, :), [true, true, false, false, true]);
end

function testGateMustMatchTheTriggeringFeature()
x = zeros(30, 2);
x(1, 1) = 100;
x(16:25, 2) = 1;
out = state_score_native(x, zeros(30, 1), [1, 1], [NaN, NaN], [1, 1], [1, 1]);

verifyEqual(out.gate(30, :), [false, true]);
verifyEqual(out.family(30, :), [false, true, true, false, true]);
end

function testMaximumSupportedCountsRemainExact()
x = repmat(intmax('int32'), 61, 2);
out = state_score_native(x, zeros(61, 1), [1, 1], [NaN, NaN], [1, 1], [0, 0]);
verifyEqual(out.K(60:61, :), 60 * double(intmax('int32')) * ones(2));
end

function testRejectsInvalidCountsAndDisjointComponents()
model = {[1, 1], [NaN, NaN], [1, 1], [0, 0]};
verifyError(@() state_score_native([0.5, 0], 0, model{:}), ...
    'state_score_native:Counts');
verifyError(@() state_score_native([2^31, 0], 0, model{:}), ...
    'state_score_native:Counts');
verifyError(@() state_score_native([0, 0], Inf, model{:}), ...
    'state_score_native:Component');
verifyError(@() state_score_native(zeros(3, 2), [0; -1; 0], model{:}), ...
    'state_score_native:RepeatedComponent');
end

function verifyEqual(actual, expected, tolerance)
if nargin == 2
    assert(isequal(actual, expected));
else
    assert(all(abs(actual(:) - expected(:)) <= tolerance));
end
end

function verifyError(operation, identifier)
try
    operation();
catch problem
    assert(strcmp(problem.identifier, identifier), 'Unexpected error. %s', problem.message);
    return
end
error('Expected an error with identifier %s.', identifier);
end
