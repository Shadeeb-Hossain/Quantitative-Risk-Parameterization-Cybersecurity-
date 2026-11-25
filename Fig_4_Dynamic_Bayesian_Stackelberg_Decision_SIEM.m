% Illustration based on the original MATLAB simulation by Shadeeb Hossain.
% Numerical revision: Elias Calboreanu
% Assumed model inputs; no empirical probability calibration or executed response.
sourceCodeDirectory = fullfile(fileparts(mfilename('fullpath')), 'source', 'matlab');
addpath(sourceCodeDirectory);
binary_results = corrected_source_simulation('binary', true);
