function make_ab_commands(exprA, exprB, opts)
%MAKE_AB_COMMANDS Print sequential A/B profiling commands for two implementations or jobs.
%
%   make_ab_commands('implA(data)', 'implB(data)', 'Setup', 'data = rand(1e4,1);')
%   make_ab_commands('runOldSolver(x)', 'runNewSolver(x)', ...
%       'LabelA', 'old', 'LabelB', 'new', 'Setup', 'x = loadCase();')
%   make_ab_commands("runtests('tJobA')", "runtests('tJobB')", 'LabelA','jobA','LabelB','jobB')
%
% Compares TWO implementations (two versions of the same workload) or TWO jobs by
% profiling each in its OWN fresh MATLAB session, then diffing the results. It only
% PRINTS the commands — you run them yourself, sequentially (one profiling session at
% a time). Use this when the two sides must run in separate MATLAB processes (e.g. to
% avoid any state carrying over between them); for a quick in-session comparison just
% call profile_function on each and compare_profiles the two results.
%
% INPUTS
%   exprA, exprB : the workload for each side, written as it appears inside @() ...
%                  i.e. a no-argument callable expression (e.g. 'implA(data)' or
%                  'runtests(''tMyTest'')'). Each side is profiled with profile_function.
%
% NAME-VALUE
%   'LabelA'      : short name for side A (default 'A') — used as the result tag/filename.
%   'LabelB'      : short name for side B (default 'B').
%   'Setup'       : command(s) run BEFORE profiling on BOTH sides, e.g. to build the
%                   shared input data both implementations consume (default '').
%   'NumBaseline' : uninstrumented baseline reps per side (default 3).
%   'ResultsDir'  : where each side saves its .mat (default fullfile(pwd,'sp_results')).

arguments
    % char (1,:) auto-coerces a scalar string input to char, so callers may
    % pass either 'expr' or "expr" for any of these — same as before.
    exprA (1,:) char
    exprB (1,:) char
    opts.LabelA (1,:) char = 'A'
    opts.LabelB (1,:) char = 'B'
    opts.Setup (1,:) char = ''
    opts.NumBaseline (1,1) double {mustBePositive, mustBeInteger} = 3
    opts.ResultsDir (1,:) char = fullfile(pwd, 'sp_results')
end

labelA = opts.LabelA; labelB = opts.LabelB;
setupCmd = opts.Setup;
resDir = strrep(opts.ResultsDir, '\', '/');

% Result tags double as filenames, so make them filename-safe (keep the labels for display).
tagA = regexprep(labelA, '\W', '_');
tagB = regexprep(labelB, '\W', '_');

% Derive the scripts folder from THIS script's location, so the generated commands
% point at wherever the customer installed the skill. All helper functions
% (profile_function, compare_profiles, ...) live in this one folder. Each side's
% fresh MATLAB gets it through the MATLABPATH environment variable, which MATLAB
% reads at startup, so nothing changes the path of the session running this.
scriptsPath = strrep(fileparts(mfilename('fullpath')), '\', '/');

% Optional shared setup, run before profiling on each side. Ensure exactly one ';'
% separator whether or not the user already ended their setup with one.
setupPart = '';
if ~isempty(strtrim(setupCmd))
    s = regexprep(strtrim(setupCmd), ';+$', '');   % drop any trailing semicolons
    setupPart = [s '; '];
end

% Build one MATLAB batch command per side, for the shell of the platform this runs on.
if ispc
    envPrefix = sprintf('set "MATLABPATH=%s" && ', scriptsPath);
else
    envPrefix = sprintf('MATLABPATH=''%s'' ', scriptsPath);
end
sideCmd = @(expr, tag) sprintf(['%s' ...
    'profile_function(@() %s, ''Tag'', ''%s'', ''NumBaseline'', %d, ''ResultsDir'', ''%s'')'], ...
    setupPart, expr, tag, opts.NumBaseline, resDir);

fprintf('=== A/B Profiling: %s vs %s ===\n\n', labelA, labelB);
if ~isempty(setupCmd)
    fprintf('Shared setup (run on both sides): %s\n\n', setupCmd);
end

fprintf('--- Run these two commands sequentially (one MATLAB session at a time) ---\n\n');
fprintf('# Side A: %s\n', labelA);
fprintf('%smatlab -batch "%s"\n\n', envPrefix, sideCmd(exprA, tagA));
fprintf('# Side B: %s\n', labelB);
fprintf('%smatlab -batch "%s"\n\n', envPrefix, sideCmd(exprB, tagB));

fprintf('--- After both complete, compare ---\n\n');
fprintf("compare_profiles('%s/%s.mat', '%s/%s.mat', 'Label0', '%s', 'Label1', '%s')\n", ...
    resDir, tagA, resDir, tagB, labelA, labelB);
end

% Copyright 2026 The MathWorks, Inc.
