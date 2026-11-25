function executable = python_executable()
%PYTHON_EXECUTABLE Select the Python 3 interpreter for file integrity checks.
% Elias Calboreanu
executable = getenv('RECON_PYTHON');
if isempty(executable), executable = 'python3'; end
end
