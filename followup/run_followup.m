function report = run_followup(outputDirectory)
%RUN_FOLLOWUP Recompute the six-trial numerical checks in a new directory.
% Elias Calboreanu
% Inputs are preserved observations. This function performs no network I/O.
% Requires native MATLAB and Python 3 on a macOS or Linux host.

assert(nargin == 1, 'followup:Output', 'Supply a new output directory.');
assert(~ispc, 'followup:Platform', 'The integrity helper uses a POSIX shell.');
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory), ...
    'followup:Exists', 'Output already exists; choose a new directory.');
root = fileparts(mfilename('fullpath'));
provenance = jsondecode(fileread(fullfile(root, 'PROVENANCE.json')));
[made, message] = mkdir(outputDirectory);
assert(made, 'followup:Output', 'Cannot create output directory: %s', message);
[found, attributes] = fileattrib(outputDirectory);
assert(found, 'followup:Output', 'Cannot resolve output directory.');
outputDirectory = attributes.Name;

% A separate working copy prevents overwriting the retained input or report.
for name = {'Native', 'fixtures', 'INPUT_INDEX.json'}
    [copied, message] = copyfile(fullfile(root, name{1}), ...
        fullfile(outputDirectory, name{1}));
    assert(copied, 'followup:Copy', 'Cannot copy input: %s', message);
end
oldPath = path;
restorePath = onCleanup(@() path(oldPath));
addpath(fullfile(outputDirectory, 'Native'), '-begin');
clear state_score_native verify_live verify_file_sha256 write_json_exclusive
verify_live(outputDirectory, provenance.delivery_input_index_sha256);
report = jsondecode(fileread(fullfile(outputDirectory, 'MATLAB_VERIFICATION.json')));
assert(report.case_count == 12 && report.rows == 1200 && ...
    all(report.mutations_rejected), 'followup:Result', 'Unexpected replay result.');
end
