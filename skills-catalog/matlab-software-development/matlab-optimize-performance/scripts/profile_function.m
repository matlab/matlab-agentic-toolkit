function results = profile_function(benchFn, opts)
%PROFILE_FUNCTION Profile any function handle with the Sampling Profiler.
%
%   results = profile_function(@() myCode(args))
%   results = profile_function(@myBenchmark, 'Tag', 'mytest')
%   results = profile_function(@() sim(mdl), 'NumBaseline', 5)
%   results = profile_function(@myFn, 'MinTime', 2.0)
%
% For quick profiling of arbitrary code without test framework overhead.
%
% NOTE: Cannot profile scripts directly via @() run('script.m') due to
% MATLAB static workspace restrictions. Wrap script logic in a local
% function instead:
%   profile_function(@myWrapper, 'Tag', 'test')
%   function myWrapper(), ... end
%
% Protocol:
%   1. JIT warmup (one call, no profiler)
%   2. Baseline timing (median of N calls, no profiler)
%   3. Warm-start profiled run (auto-loops if MinTime > baseline)
%
% Use MinTime for short benchmarks (<0.2s) to accumulate enough samples.

arguments
    benchFn (1,1) function_handle
    opts.Tag (1,:) char = 'profile'
    opts.ResultsDir (1,:) char = fullfile(pwd, 'sp_results')
    opts.NumBaseline (1,1) double {mustBePositive, mustBeInteger} = 3
    opts.TopN (1,1) double {mustBePositive, mustBeInteger} = 30
    opts.MinTime (1,1) double {mustBeNonnegative} = 0
    opts.Save (1,1) logical = true
end

assertSamplingProfiler();   % clear error + fallback hint on pre-R2026b

fprintf('=== SP Profile: %s ===\n', opts.Tag);

% --- 1. JIT warmup ---
fprintf('[1/3] JIT warmup...\n');
tid = tic;
benchFn();
fprintf('  Warmup: %.2fs\n', toc(tid));

% --- 2. Baseline ---
fprintf('[2/3] Baseline (%d runs)...\n', opts.NumBaseline);
baseTimes = zeros(1, opts.NumBaseline);
for r = 1:opts.NumBaseline
    tid = tic;
    benchFn();
    baseTimes(r) = toc(tid);
end
baselineTime = median(baseTimes);
fprintf('  Baseline (median): %.3fs\n', baselineTime);

if baselineTime < 0.2
    warning('profile_function:short', ...
        'Benchmark is %.3fs (<0.2s). Results will have high statistical noise.', baselineTime);
end

% --- 3. Profiled run (warm-start) ---
% Steps 1-2 warmed the workload with the profiler OFF; one more warm-up under
% 'pause' after 'on' keeps the profiler's own first-call cost out of the samples.
fprintf('[3/3] Profiled run...\n');
sampling_profiler('on');
% Guard: if benchFn() errors mid-run, always tear the profiler down so a later
% run isn't corrupted by a still-armed session.
spCleanup = onCleanup(@() safeDestroy());
sampling_profiler('pause');
benchFn();                                    % warm-up (not collected)
sampling_profiler('clear');
sampling_profiler('resume');

% If benchmark is too short, loop it
nReps = 1;
if opts.MinTime > 0 && baselineTime < opts.MinTime
    nReps = ceil(opts.MinTime / baselineTime);
    fprintf('  Looping %dx to reach %.1fs minimum...\n', nReps, opts.MinTime);
end

tid = tic;
for rep = 1:nReps
    benchFn();
end
profileTime = toc(tid);

[~, stacks] = sampling_profiler('off');
clear spCleanup;                              % onCleanup -> safeDestroy() tears down now

% --- Report ---
overhead = (profileTime / (baselineTime * nReps) - 1) * 100;
fprintf('\n--- Results: %s ---\n', opts.Tag);
fprintf('  Baseline:      %.3fs\n', baselineTime);
fprintf('  Profiled:      %.3fs (%d reps, overhead: %+.1f%%)\n', profileTime, nReps, overhead);
fprintf('  TotalSamples:  %d\n', stacks.TotalSamples);
fprintf('  Snapshots:     %d\n', numel(stacks.Snapshots));
fprintf('  Implied time:  %.2fs\n', stacks.TotalSamples / 100);

fprintf('\n--- Top %d Hotspots ---\n', opts.TopN);
print_hotspot_report(stacks, opts.TopN);

% --- Save ---
if opts.Save
    if ~isfolder(opts.ResultsDir), mkdir(opts.ResultsDir); end
    resultFile = fullfile(opts.ResultsDir, [opts.Tag '.mat']);
    tag = opts.Tag;
    save(resultFile, 'stacks', 'baselineTime', 'profileTime', ...
        'baseTimes', 'nReps', 'tag');
    fprintf('\nSaved: %s\n', resultFile);
end

% --- Return ---
results.stacks = stacks;
results.baselineTime = baselineTime;
results.profileTime = profileTime;
results.tag = opts.Tag;
if opts.Save
    results.resultFile = resultFile;
end
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
