function quoted = quote_shell(value)
% Elias Calboreanu. POSIX quoting for one literal argument, including apostrophes.
single = char(39); double = char(34);
quoted = [single, strrep(char(value), single, [single, double, single, double, single]), single];
end
