function verify_live(root, expectedIndexSHA256)
% Elias Calboreanu. Native MATLAB replay of preserved inputs; no network I/O.
assert(~exist('OCTAVE_VERSION', 'builtin'), 'This report requires native MATLAB.');
output = fullfile(root, 'MATLAB_VERIFICATION.json');
assert(~isfile(output), 'retained:Exists', 'Refusing to overwrite a verification result.');
indexPath = fullfile(root, 'INPUT_INDEX.json');
verify_file_sha256(indexPath, expectedIndexSHA256);
index = jsondecode(fileread(indexPath));
verify_file_sha256(indexPath, expectedIndexSHA256);
assert(numel(index.cases) == 12 && numel(unique({index.cases.case_id})) == 12 && ...
    numel(unique({index.cases.file})) == 12, 'retained:Index', 'Unexpected case identities.');
corePath = fullfile(root, 'Native', 'state_score_native.m');
assert(strcmp(which('state_score_native'), corePath), 'retained:CorePath', 'Unexpected numerical core on MATLAB path.');
verify_file_sha256(corePath, index.numerical_core_sha256);
reports = cell(numel(index.cases), 1);
first = [];
for k = 1:numel(index.cases)
    [~, name, extension] = fileparts(index.cases(k).file);
    assert(strcmp(index.cases(k).file, [name, extension]), 'retained:Index', 'Fixture must be a local basename.');
    path = fullfile(root, 'fixtures', index.cases(k).file);
    verify_file_sha256(path, index.cases(k).sha256);
    f = load(path);
    verify_file_sha256(path, index.cases(k).sha256);
    assert(strcmp(strtrim(f.case_id), index.cases(k).case_id), 'retained:Index', 'Fixture identity mismatch.');
    r = validateFixture(f);
    r.case_id = strtrim(f.case_id);
    r.phase = index.cases(k).phase;
    r.comparison_basis = index.cases(k).comparison_basis;
    r.saved_live_decisions_checked_in_python = index.cases(k).saved_live_decisions_checked;
    reports{k} = r;
    if k == 1, first = f; end
end
% Deliberately corrupt a copy: a passing numerical audit must reject it.
mutations = {'count', 'decision', 'score', 'boundary'};
rejected = false(size(mutations));
for k = 1:numel(mutations)
    f = first;
    switch mutations{k}
        case 'count', f.expected_K(1, 1) = f.expected_K(1, 1) + 1;
        case 'decision', f.expected_family(1, 1) = 1 - f.expected_family(1, 1);
        case 'score', f.expected_E(1, 1) = f.expected_E(1, 1) + 1;
        case 'boundary', f.expected_integer_count_threshold(30, 1) = f.expected_integer_count_threshold(30, 1) + 1;
    end
    try
        validateFixture(f);
    catch error
        rejected(k) = strcmp(error.identifier, 'retained:Mismatch');
    end
end
assert(all(rejected), 'Mutation control did not reject incorrect evidence.');
report = struct('status', 'PASS_NUMERICAL_REPLAY_ONLY', 'runtime', version, ...
    'native_matlab_used', true, 'cases', {reports}, 'case_count', numel(reports), ...
    'rows', sum(cellfun(@(x)x.rows, reports)), ...
    'maximum_score_absolute_error', max(cellfun(@(x)x.score_max_absolute_error, reports)), ...
    'maximum_score_tolerance_ratio', max(cellfun(@(x)x.score_max_tolerance_ratio, reports)), ...
    'mutation_controls', {mutations}, 'mutations_rejected', rejected, ...
    'mutation_control_case', index.cases(1).case_id, ...
    'mutation_scope', 'Four corrupted in-memory copies of the first fresh live-pilot source case only.', ...
    'fixture_hash_checks', 2 * numel(index.cases), ...
    'integrity_backend', 'Python standard library; executable selected by RECON_PYTHON or python3', ...
    'state_cases_linked_to_saved_live_decisions_in_python', sum([index.cases.saved_live_decisions_checked]), ...
    'quantity_cases_python_matlab_only', sum(~[index.cases.saved_live_decisions_checked]), ...
    'input_index_sha256', expectedIndexSHA256, ...
    'scope', 'Native numerical reproduction of fresh live-pilot records, independently linked to saved decisions in Python; no complete-study acceptance.');
verify_file_sha256(indexPath, expectedIndexSHA256);
verify_file_sha256(corePath, index.numerical_core_sha256);
write_json_exclusive(output, report);
fprintf('Native MATLAB: %d cases, %d rows; max score error %.17g; four mutation controls rejected.\n', ...
    report.case_count, report.rows, report.maximum_score_absolute_error);
end

function report = validateFixture(f)
r = state_score_native(f.x, f.component, f.mu, f.shape, f.B, f.R);
checks = [isequal(r.K, f.expected_K), isequal(r.n, f.expected_n), ...
    isequal(r.O15, f.expected_O15), isequal(r.n15, f.expected_n15), ...
    isequal(r.valid, logical(f.expected_valid)), isequal(r.gate, logical(f.expected_gate)), ...
    isequal(r.family, logical(f.expected_family))];
scoreError = abs(r.E - f.expected_E);
scoreTolerance = 1e-10 + 2e-12 * abs(f.expected_E);
assert(all(checks) && all(scoreError(:) <= scoreTolerance(:)) && ...
    all(abs(r.rate - f.expected_rate) < 1e-12, 'all'), 'retained:Mismatch', ...
    'Count, score, exposure or decision differs.');
offset = r.n .* r.exposureCoefficient;
cap = double(intmax('int32')) * 60 + 1;
threshold = min(ceil((f.B - offset) ./ r.countCoefficient), cap);
converged = false;
for step = 1:4
    down = threshold > 0 & (threshold - 1) .* r.countCoefficient + offset >= f.B;
    up = threshold < cap & threshold .* r.countCoefficient + offset < f.B;
    if ~any(down(:) | up(:)), converged = true; break; end
    threshold = threshold - double(down) + double(up);
end
assert(converged && isequal(threshold, f.expected_integer_count_threshold) && ...
    isequal(any((r.K >= threshold) & r.gate, 2), r.family(:, 1)), ...
    'retained:Mismatch', 'Integer boundary differs.');
report = struct('passed', true, 'rows', size(f.x, 1), ...
    'score_max_absolute_error', max(scoreError(:)), ...
    'score_max_tolerance_ratio', max(scoreError(:) ./ scoreTolerance(:)), ...
    'exact_count_exposure_gate_and_decisions', true, 'integer_boundary_identity', true);
end
