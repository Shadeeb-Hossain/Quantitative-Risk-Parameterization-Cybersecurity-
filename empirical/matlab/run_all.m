function report = run_all(outputDirectory)
%RUN_ALL Validate the fixed held-out data and regenerate empirical figures.
% Elias Calboreanu

empiricalDirectory = fileparts(fileparts(mfilename('fullpath')));
if nargin == 0
    outputDirectory = fullfile(empiricalDirectory, 'output');
end
verificationPath = fullfile(outputDirectory, 'verification.json');
if isfile(verificationPath)
    delete(verificationPath);
end
dataDirectory = fullfile(empiricalDirectory, 'data');
testsDirectory = fullfile(empiricalDirectory, 'tests');
addpath(testsDirectory);
testCount = test_state_score_native();

[alarms, caseChecks, replay, parameters] = replay_study(dataDirectory);
[report, f04] = analyze_service(dataDirectory, replay, parameters);
provenance = jsondecode(fileread(fullfile(dataDirectory, 'provenance.json')));
report.prepared_by = 'Elias Calboreanu';
report.provenance = struct('input_export_manifest', 'data/provenance.json', ...
    'sealed_artifact_manifest_sha256', provenance.sealed_artifact_manifest_sha256, ...
    'pretest_freeze_manifest_sha256', provenance.pretest_freeze_manifest_sha256, ...
    'recorded_native_cases_sha256', provenance.export_sha256.native_cases_csv, ...
    'recorded_native_parameters_sha256', provenance.export_sha256.native_parameters_json);
if exist('OCTAVE_VERSION', 'builtin')
    report.runtime = struct('engine', 'GNU Octave', 'version', version(), 'release', '');
else
    report.runtime = struct('engine', 'MATLAB', 'version', version(), 'release', version('-release'));
end
report.numerical_status = 'PASS';
report.unit_tests_passed = testCount;
report.case_count = numel(caseChecks.case_id);
report.row_count = 300 * report.case_count;
report.exact_count_boolean_comparisons = 5 * report.case_count;
report.exact_count_boolean_mismatches = 0;
report.additional_exact_comparisons = 3 * report.case_count;
report.score_mismatches = 0;
report.maximum_input_count = max(caseChecks.maximum_input_count);
report.maximum_window_count = max(caseChecks.maximum_window_count);
report.maximum_score_absolute_difference = max(caseChecks.maximum_score_absolute_difference);
report.maximum_score_tolerance_ratio = max(caseChecks.maximum_score_tolerance_ratio);
report.score_absolute_tolerance = 1e-10;
report.score_relative_tolerance = 2e-12;
report.state_score_count_gate_equal_every_bin = all(alarms.state_count_gate_identical_every_bin);

if ~isfolder(outputDirectory)
    [made, message] = mkdir(outputDirectory);
    assert(made, 'Cannot create the output directory. %s', message);
end
stagingDirectory = tempname(outputDirectory);
[made, message] = mkdir(stagingDirectory);
assert(made, 'Cannot create the staging directory. %s', message);
cleanup = onCleanup(@() rmdir(stagingDirectory, 's'));
write_csv(fullfile(stagingDirectory, 'case_validation.csv'), caseChecks);
write_csv(fullfile(stagingDirectory, 'trial_alarm_seconds.csv'), alarms);
export_paper_figures(alarms, report, f04, stagingDirectory);
writeReport(fullfile(stagingDirectory, 'verification.json'), report);
[moved, message] = movefile(fullfile(stagingDirectory, '*'), outputDirectory, 'f');
assert(moved, 'Cannot publish the generated files. %s', message);

fprintf('Numerical verification %s (%d cases, %d rows, %s %s).\n', ...
    report.numerical_status, report.case_count, report.row_count, report.runtime.engine, report.runtime.version);
fprintf('F-series study %s (%d/%d primary cohorts passed).\n', ...
    report.study_status, report.primary_cohorts_passed, report.primary_cohorts_assessed);
end

function writeReport(path, report)
[file, message] = fopen(path, 'w');
assert(file >= 0, 'Cannot open the verification report. %s', message);
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(report));
end
