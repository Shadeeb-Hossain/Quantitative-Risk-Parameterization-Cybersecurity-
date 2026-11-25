function subset = csv_subset(rows, take)
%CSV_SUBSET Select rows from a structure of evidence columns.
% Elias Calboreanu
names = fieldnames(rows);
subset = rows;
for k = 1:numel(names)
    column = rows.(names{k});
    subset.(names{k}) = column(take);
end
end
