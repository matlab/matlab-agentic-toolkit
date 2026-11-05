function results = profile_test(testPath, opts)
%PROFILE_TEST Profile any MATLAB test file with the Sampling Profiler.
%
%   results = profile_test('tMyPerfTest')            % resolved via which()
%   results = profile_test('/full/path/to/tMyPerfTest.m')
%   results = profile_test(testPath, 'Tag', 'configA', 'NumBaseline', 3)
%   results = profile_test(testPath, 'ResultsDir', 'my_results')
%   results = profile_test(testPath, 'SkipWarmup', true)
%
% Protocol (sequential, no contention):
%   1. JIT warmup run (no profiler) — pays first-run compilation cost
%   2. Baseline timing (median of N runs, no profiler) — authoritative wall-clock
%   3. Warm-start profiled run:
%      on -> pause -> warm-up -> clear -> resume -> measure -> off -> destroy
%
% IMPORTANT: Run only ONE profiling session at a time. Do not run two
% MATLAB sessions in parallel — shared resource contention invalidates results.
%
% Saves .mat file with: stacks, baselineTime, profileTime, baseTimes, tag.
% Use find_hotspots / print_hotspot_report to analyze the saved stacks.
%
% The test path can be:
%   - A full or relative path to the .m file
%   - Just a test class name that is on the MATLAB path (uses which() to resolve)

arguments
    testPath (1,:) char
    opts.ResultsDir (1,:) char = fullfile(pwd, 'sp_results')
    opts.Tag (1,:) char = ''
    opts.NumBaseline (1,1) double {mustBePositive, mustBeInteger} = 3
    opts.SkipWarmup (1,1) logical = false
    opts.TopN (1,1) double {mustBePositive, mustBeInteger} = 30
end

assertSamplingProfiler();   % clear error + fallback hint on pre-R2026b

% --- Resolve test file ---
testFile = resolveTestPath(testPath);
[~, testName, ~] = fileparts(testFile);

% --- Build output tag ---
if isempty(opts.Tag)
    tag = testName;
else
    tag = sprintf('%s_%s', testName, opts.Tag);
end

fprintf('=== SP Profile: %s ===\n', tag);
fprintf('Test file: %s\n', testFile);

% --- Create test suite ---
suite = testsuite(testFile);
assert(~isempty(suite), 'No test methods found in: %s', testFile);
fprintf('Test methods: %d\n', numel(suite));

% --- 1. JIT warmup ---
if ~opts.SkipWarmup
    fprintf('[1/3] JIT warmup...\n');
    tid = tic;
    runner = matlab.unittest.TestRunner.withNoPlugins;
    runner.run(suite);
    fprintf('  Warmup: %.1fs\n', toc(tid));
end

% --- 2. Baseline timing ---
fprintf('[2/3] Baseline timing (%d run(s))...\n', opts.NumBaseline);
baseTimes = zeros(1, opts.NumBaseline);
for r = 1:opts.NumBaseline
    tid = tic;
    runner = matlab.unittest.TestRunner.withNoPlugins;
    runner.run(suite);
    baseTimes(r) = toc(tid);
    fprintf('  Run %d: %.2fs\n', r, baseTimes(r));
end
baselineTime = median(baseTimes);
fprintf('  Baseline (median): %.2fs\n', baselineTime);

% --- 3. Profiled run (warm-start) ---
% Steps 1-2 warmed the suite with the profiler OFF; one more run under 'pause'
% after 'on' keeps the profiler's own first-call cost out of the samples.
fprintf('[3/3] Profiled run (warm-start)...\n');
sampling_profiler('on');
% Guard: if a test throws, tear the profiler down so it is never left armed for the
% rest of the session (which would corrupt every later profile).
spCleanup = onCleanup(@() safeDestroy());
sampling_profiler('pause');
matlab.unittest.TestRunner.withNoPlugins.run(suite);   % warm-up (not collected)
sampling_profiler('clear');
sampling_profiler('resume');

tid = tic;
runner = matlab.unittest.TestRunner.withNoPlugins;
testResults = runner.run(suite);
profileTime = toc(tid);

[~, stacks] = sampling_profiler('off');
clear spCleanup;   % normal path: destroy now via the cleanup guard

% --- Report ---
overhead = (profileTime / baselineTime - 1) * 100;
fprintf('\n--- Results: %s ---\n', tag);
fprintf('  Baseline:      %.2fs\n', baselineTime);
fprintf('  Profiled:      %.2fs (overhead: %+.1f%%)\n', profileTime, overhead);
fprintf('  TotalSamples:  %d\n', stacks.TotalSamples);
fprintf('  Snapshots:     %d\n', numel(stacks.Snapshots));
fprintf('  Implied time:  %.2fs\n', stacks.TotalSamples / 100);

fprintf('\n--- Top %d Hotspots ---\n', opts.TopN);
print_hotspot_report(stacks, opts.TopN);

% --- Save ---
if ~isfolder(opts.ResultsDir), mkdir(opts.ResultsDir); end
resultFile = fullfile(opts.ResultsDir, [tag '.mat']);
save(resultFile, 'stacks', 'baselineTime', 'profileTime', ...
    'testResults', 'testFile', 'tag', 'baseTimes');
fprintf('\nSaved: %s\n', resultFile);

% --- Return ---
results.stacks = stacks;
results.baselineTime = baselineTime;
results.profileTime = profileTime;
results.testResults = testResults;
results.tag = tag;
results.resultFile = resultFile;
end

function testFile = resolveTestPath(testPath)
    % Accept an absolute/relative path directly, or a test name resolvable on the
    % MATLAB path via which().
    if isfile(testPath)
        testFile = testPath;
        return;
    end
    resolved = which(testPath);
    if ~isempty(resolved)
        testFile = resolved;
        return;
    end
    error('profile_test:notFound', ...
        ['Cannot resolve test path: %s. Pass a full path to the .m file, or a ' ...
         'test name that is on the MATLAB path (resolvable with which()).'], testPath);
end

function safeDestroy()
% Tear the profiler down no matter what state it is in (used by the onCleanup
% guard so an error mid-run never leaves a session armed).
    try
        st = sampling_profiler('status');
        if ~strcmp(st, 'off'), sampling_profiler('off'); end
    catch
    end
    try sampling_profiler('destroy'); catch, end
end

% Copyright 2026 The MathWorks, Inc.
