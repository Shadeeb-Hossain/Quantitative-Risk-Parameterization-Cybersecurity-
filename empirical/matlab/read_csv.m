function rows = read_csv(path, textColumns)
%READ_CSV Read a published evidence CSV into a structure of columns.
% Elias Calboreanu
if nargin == 1
    textColumns = {};
end
[file, message] = fopen(path, 'r');
assert(file >= 0, 'Could not open %s. %s', path, message);
cleanup = onCleanup(@() fclose(file));
names = strsplit(strtrim(fgetl(file)), ',');
specifiers = repmat({'%f'}, size(names));
specifiers(ismember(names, textColumns)) = {'%q'};
columns = textscan(file, strjoin(specifiers, ''), 'Delimiter', ',', ...
    'EmptyValue', NaN, 'ReturnOnError', false);
assert(all(cellfun(@numel, columns) == numel(columns{1})), ...
    'Columns have different lengths in %s.', path);
rows = cell2struct(columns, names, 2);
end
