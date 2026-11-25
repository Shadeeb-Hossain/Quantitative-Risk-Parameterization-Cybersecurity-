function verify_file_sha256(path, expected)
% Elias Calboreanu. Check exact bytes using the existing Python dependency.
helper = fullfile(fileparts(mfilename('fullpath')), 'file_integrity.py');
command = [quote_shell(python_executable()), ' ', quote_shell(helper), ...
    ' hash ', quote_shell(path), ' ', quote_shell(expected)];
[status, output] = system(command);
assert(status == 0, 'retained:HashMismatch', 'SHA256 verification failed: %s. %s', path, output);
end
