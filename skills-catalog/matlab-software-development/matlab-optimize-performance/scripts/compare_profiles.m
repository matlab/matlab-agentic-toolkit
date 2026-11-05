function compare_profiles(file0, file1, opts)
%COMPARE_PROFILES Compare two sampling profiler results and generate a report.
%
%   compare_profiles('results/myTest_configA.mat', 'results/myTest_configB.mat')
%   compare_profiles(file0, file1, 'Label0', 'config A', 'Label1', 'config B')
%   compare_profiles(file0, file1, 'FilterTest', 'tMyTest')
%   compare_profiles(file0, file1, 'TopN', 40, 'ReportFile', 'my_report.md')
%
% Parameters:
%   Label0, Label1  — display labels for the two configs
%   FilterTest      — exclude test framework overhead (PathFixture, TestRunner
%                     teardown, path manipulation). Removes samples where only
%                     framework code is on the stack.
%   TopN            — number of top functions/lines to show (default 30)
%   ReportFile      — path for markdown report (default: comparison_report.md)
%
% Accepts .mat files saved by profile_test or profile_function.
% Generates:
%   - Console output with function-level and line-level diffs
%   - Markdown report file (auto-saved next to file0)

arguments
    file0 (1,:) char
    file1 (1,:) char
    opts.Label0 (1,:) char = 'Config0'
    opts.Label1 (1,:) char = 'Config1'
    opts.TopN (1,1) double {mustBePositive, mustBeInteger} = 30
    opts.ReportFile (1,:) char = ''
    opts.FilterTest (1,:) char = ''
end

d0 = load(file0);
d1 = load(file1);

% Validate the .mat files came from profile_function / profile_test.
validateResultFile(d0, file0);
validateResultFile(d1, file1);

% Filter stacks to exclude test framework overhead
if ~isempty(opts.FilterTest)
    d0.stacks = filter_test_frames(d0.stacks, opts.FilterTest);
    d1.stacks = filter_test_frames(d1.stacks, opts.FilterTest);
end

% Auto-detect labels from tag if available
if strcmp(opts.Label0, 'Config0') && isfield(d0, 'tag')
    opts.Label0 = d0.tag;
end
if strcmp(opts.Label1, 'Config1') && isfield(d1, 'tag')
    opts.Label1 = d1.tag;
end

fprintf('=== Sampling Profiler Comparison ===\n');
fprintf('  A: %s\n', opts.Label0);
fprintf('  B: %s\n\n', opts.Label1);

% Attribution only. The two results usually come from different sessions, so a
% speedup from their baselines would carry session drift; time A vs B
% interleaved in one session instead (measurement-protocol.md Step 2).

% --- Build maps ---
[funcIncl0, funcSelf0, n0] = buildFuncMap(d0.stacks);
[funcIncl1, funcSelf1, n1] = buildFuncMap(d1.stacks);

% Percentages below divide by n0/n1 (captured-snapshot counts). If either run
% captured nothing (e.g. a purely MEX/blocking workload = all idle ticks, or a
% failed run), bail with a clear message instead of flooding the report with NaN.
if n0 == 0 || n1 == 0
    error('compare_profiles:noSnapshots', ...
        ['One or both runs produced zero captured snapshots (n0=%d, n1=%d). ' ...
         'Cannot compare — the workload may be all idle/MEX time, or profiling failed.'], ...
        n0, n1);
end

allFuncs = unique([funcIncl0.keys, funcIncl1.keys]);
nFuncs = numel(allFuncs);

% Build table
names = cell(1, nFuncs);
incl0 = zeros(1, nFuncs); incl1 = zeros(1, nFuncs);
self0 = zeros(1, nFuncs); self1 = zeros(1, nFuncs);

for i = 1:nFuncs
    fn = allFuncs{i};
    names{i} = fn;
    if funcIncl0.isKey(fn), incl0(i) = funcIncl0(fn) / n0 * 100; end
    if funcIncl1.isKey(fn), incl1(i) = funcIncl1(fn) / n1 * 100; end
    if funcSelf0.isKey(fn), self0(i) = funcSelf0(fn) / n0 * 100; end
    if funcSelf1.isKey(fn), self1(i) = funcSelf1(fn) / n1 * 100; end
end
inclDiff = incl1 - incl0;
selfDiff = self1 - self0;

% Sort by absolute inclusive diff
[~, si] = sort(abs(inclDiff), 'descend');

% --- Print function table ---
fprintf('Per-function (sorted by |inclusive change|):\n');
fprintf('%-45s  %7s %7s %7s  %7s %7s %7s\n', ...
    'Function', 'Inc%A', 'Inc%B', 'Diff', 'Self%A', 'Self%B', 'Diff');
fprintf('%s\n', repmat('-', 1, 105));
nShow = min(opts.TopN, nFuncs);
for i = 1:nShow
    j = si(i);
    fprintf('%-45s  %6.1f%% %6.1f%% %+6.1f%%  %6.1f%% %6.1f%% %+6.1f%%\n', ...
        trunc(names{j}, 45), incl0(j), incl1(j), inclDiff(j), ...
        self0(j), self1(j), selfDiff(j));
end

% --- Line-level ---
[~, lineSelf0] = buildLineMap(d0.stacks);
[~, lineSelf1] = buildLineMap(d1.stacks);

allLines = unique([lineSelf0.keys, lineSelf1.keys]);
nLines = numel(allLines);
lnames = cell(1, nLines);
ls0 = zeros(1, nLines); ls1 = zeros(1, nLines);
for i = 1:nLines
    k = allLines{i};
    lnames{i} = k;
    if lineSelf0.isKey(k), ls0(i) = lineSelf0(k) / n0 * 100; end
    if lineSelf1.isKey(k), ls1(i) = lineSelf1(k) / n1 * 100; end
end
ldiff = ls1 - ls0;

% Sort by absolute change, as the function table does, so a line hot only in B shows
[~, lsi] = sort(abs(ldiff), 'descend');

fprintf('\n\nTop %d line changes in self time:\n', opts.TopN);
fprintf('%-55s  %7s %7s %7s\n', 'Location', 'Self%A', 'Self%B', 'Diff');
fprintf('%s\n', repmat('-', 1, 85));
for i = 1:min(opts.TopN, nLines)
    j = lsi(i);
    fprintf('%-55s  %6.1f%% %6.1f%% %+6.1f%%\n', ...
        trunc(lnames{j}, 55), ls0(j), ls1(j), ldiff(j));
end

% --- Markdown report ---
if isempty(opts.ReportFile)
    [dir0, ~, ~] = fileparts(file0);
    opts.ReportFile = fullfile(dir0, 'comparison_report.md');
end

fid = fopen(opts.ReportFile, 'w');
fprintf(fid, '# Sampling Profiler Comparison\n\n');
fprintf(fid, '- **A**: %s\n', opts.Label0);
fprintf(fid, '- **B**: %s\n\n', opts.Label1);

fprintf(fid, '## Summary\n\n');
fprintf(fid, '| Metric | %s | %s | Change |\n', opts.Label0, opts.Label1);
fprintf(fid, '|--------|------|------|--------|\n');
fprintf(fid, '| Profiled | %.2fs | %.2fs | |\n', d0.profileTime, d1.profileTime);
fprintf(fid, '| Samples | %d | %d | |\n', d0.stacks.TotalSamples, d1.stacks.TotalSamples);
fprintf(fid, '\n');

fprintf(fid, '## Function-Level Changes\n\n');
fprintf(fid, '| Function | Incl%%A | Incl%%B | Diff | Self%%A | Self%%B | Diff |\n');
fprintf(fid, '|----------|--------|--------|------|--------|--------|------|\n');
for i = 1:nShow
    j = si(i);
    fprintf(fid, '| %s | %.1f%% | %.1f%% | %+.1f%% | %.1f%% | %.1f%% | %+.1f%% |\n', ...
        names{j}, incl0(j), incl1(j), inclDiff(j), self0(j), self1(j), selfDiff(j));
end
fprintf(fid, '\n');

fprintf(fid, '## Line-Level Hotspots\n\n');
fprintf(fid, '| Location | Self%%A | Self%%B | Diff |\n');
fprintf(fid, '|----------|--------|--------|------|\n');
for i = 1:min(opts.TopN, nLines)
    j = lsi(i);
    fprintf(fid, '| `%s` | %.1f%% | %.1f%% | %+.1f%% |\n', ...
        lnames{j}, ls0(j), ls1(j), ldiff(j));
end
fclose(fid);
fprintf('\n\nReport: %s\n', opts.ReportFile);
end

%% --- Helpers ---
function validateResultFile(d, fname)
    % The .mat must have been saved by profile_function / profile_test.
    required = {'stacks', 'baselineTime', 'profileTime'};
    missing = required(~isfield(d, required));
    if ~isempty(missing)
        error('compare_profiles:badResultFile', ...
            ['%s is missing field(s): %s. Pass a .mat saved by profile_function ' ...
             'or profile_test.'], fname, strjoin(missing, ', '));
    end
end

function [inclMap, selfMap, totalSnap] = buildFuncMap(stacks)
    inclMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    selfMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    totalSnap = numel(stacks.Snapshots);
    for s = 1:totalSnap
        snap = stacks.Snapshots(s);
        nf = min(double(snap.Depth), numel(snap.Frames));   % honor Frames(1:Depth) contract
        if nf == 0, continue; end
        seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        for f = 1:nf
            [~, fn, ~] = fileparts(snap.Frames(f).FileName);
            if ~seen.isKey(fn)
                seen(fn) = true;
                if inclMap.isKey(fn), inclMap(fn) = inclMap(fn)+1;
                else, inclMap(fn) = 1; end
            end
        end
        fr = snap.Frames(nf);
        [~, fn, ~] = fileparts(fr.FileName);
        if selfMap.isKey(fn), selfMap(fn) = selfMap(fn)+1;
        else, selfMap(fn) = 1; end
    end
end

function [inclMap, selfMap] = buildLineMap(stacks)
    inclMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    selfMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for s = 1:numel(stacks.Snapshots)
        snap = stacks.Snapshots(s);
        nf = min(double(snap.Depth), numel(snap.Frames));   % honor Frames(1:Depth) contract
        if nf == 0, continue; end
        seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        for f = 1:nf
            [~, fn, ~] = fileparts(snap.Frames(f).FileName);
            key = sprintf('%s:%d', fn, double(snap.Frames(f).StartLine));
            if ~seen.isKey(key)
                seen(key) = true;
                if inclMap.isKey(key), inclMap(key) = inclMap(key)+1;
                else, inclMap(key) = 1; end
            end
        end
        fr = snap.Frames(nf);
        [~, fn, ~] = fileparts(fr.FileName);
        leafKey = sprintf('%s:%d', fn, double(fr.StartLine));
        if selfMap.isKey(leafKey), selfMap(leafKey) = selfMap(leafKey)+1;
        else, selfMap(leafKey) = 1; end
    end
end

function s = trunc(str, n)
    if numel(str) > n, s = [str(1:n-3) '...']; else, s = str; end
end

% Copyright 2026 The MathWorks, Inc.
