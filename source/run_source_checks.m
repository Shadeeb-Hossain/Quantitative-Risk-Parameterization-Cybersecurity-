function report = run_source_checks()
%RUN_SOURCE_CHECKS Verify corrected source mathematics in local MATLAB.
% Elias Calboreanu
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'), fullfile(root, 'tests'));
output = fullfile(root, 'output');
if ~isfolder(output), mkdir(output); end
path = fullfile(output, 'math_verification.json');
if isfile(path), delete(path); end
report = test_source_math();
report.empirical_audit = audit_empirical_math(fileparts(root));
file = fopen(path, 'w');
assert(file >= 0, 'Cannot write verification report.');
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(report, 'PrettyPrint', true));
fprintf('%s: %d source-math test groups. %s\n', report.status, report.test_groups_passed, report.version);
fprintf('Poisson alert: cutoff %g, FPR %.8f, sensitivity %.8f.\n', ...
    report.alert_cutoff, report.actual_false_positive_probability, report.actual_sensitivity);
fprintf('Frozen F study remains %s; no new traffic trials.\n', report.empirical_service_verdict);
end
