function write_csv(path, rows)
%WRITE_CSV Write named columns with round-trip double precision.
% Elias Calboreanu
[file, message] = fopen(path, 'w');
assert(file >= 0, 'Could not write %s. %s', path, message);
cleanup = onCleanup(@() fclose(file));
names = fieldnames(rows);
columns = struct2cell(rows);
fprintf(file, '%s\n', strjoin(names.', ','));
for i = 1:numel(columns{1})
    values = cell(size(names));
    for j = 1:numel(names)
        column = columns{j};
        if iscell(column)
            values{j} = ['"', strrep(column{i}, '"', '""'), '"'];
        else
            values{j} = sprintf('%.17g', column(i));
        end
    end
    fprintf(file, '%s\n', strjoin(values.', ','));
end
end
