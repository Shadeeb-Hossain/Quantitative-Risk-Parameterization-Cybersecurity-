function write_json_exclusive(path, value)
% Elias Calboreanu. Reserve a new result atomically; never replace a file.
temporary = tempname;
closer = onCleanup(@()delete(temporary));
fid = fopen(temporary, 'w');
assert(fid >= 0, 'retained:Write', 'Cannot create temporary result.');
fprintf(fid, '%s\n', jsonencode(value, PrettyPrint=true));
fclose(fid);
helper = fullfile(fileparts(mfilename('fullpath')), 'file_integrity.py');
command = [quote_shell(python_executable()), ' ', quote_shell(helper), ...
    ' publish ', quote_shell(temporary), ' ', quote_shell(path)];
[status, output] = system(command);
assert(status ~= 3, 'retained:Exists', 'Refusing to overwrite %s.', path);
assert(status == 0, 'retained:Write', 'Cannot publish result: %s', output);
end
