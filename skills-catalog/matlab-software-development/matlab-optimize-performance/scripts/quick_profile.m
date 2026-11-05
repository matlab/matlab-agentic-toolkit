function [stacks, hot] = quick_profile(fn, topN)
%QUICK_PROFILE Profile an expression and print its top hotspots — the fast path.
%
%   quick_profile(@() myCode(args))          % capture + print top 15
%   quick_profile(@myBenchmark, 20)          % top 20
%   [stacks, hot] = quick_profile(@() sim(m)) % also return data
%
% The minimal "just show me where the time goes" helper. It runs the correct
% warm-start capture sequence for you:
%   on -> pause -> warm-up -> clear -> resume -> measured run -> off -> destroy,
% then prints a hotspot report. For a rigorous timed/baselined run or to save
% results, use profile_function instead.
%
% INPUT
%   fn   : a function handle, e.g. @() myCode(args). Cannot be @()run('s.m')
%          (MATLAB static-workspace rule) — use profile_script for a script.
%   topN : hotspots to print (default 15).
%
% OUTPUT (optional)
%   stacks : raw stacks struct from the profiled run.
%   hot    : top-N hotspots as data (see find_hotspots).

    if nargin < 2 || isempty(topN), topN = 15; end
    assertSamplingProfiler();   % clear error + fallback hint on pre-R2026b

    % Warm-start protocol: start the profiler, PAUSE, run the warm-up (its
    % first-call cost is not collected), CLEAR, RESUME, then the measured pass.
    % Warming up after 'on' rather than before it leaves less first-call cost in
    % the measured run.
    sampling_profiler('on');
    cleanup = onCleanup(@() safeDestroy());   % always tear down, even on error
    sampling_profiler('pause');
    fn();                                     % warm-up (not collected)
    sampling_profiler('clear');
    sampling_profiler('resume');
    fn();                                     % measured run
    [~, stacks] = sampling_profiler('off');
    clear cleanup;                            % onCleanup -> safeDestroy() tears down now

    fprintf('quick_profile: %d samples (%.2fs implied)\n', ...
        stacks.TotalSamples, stacks.TotalSamples/100);
    if stacks.TotalSamples < 20
        warning('quick_profile:fewSamples', ...
            'Only %d samples — result is statistically noisy. Run a longer/heavier workload.', ...
            stacks.TotalSamples);
    end

    print_hotspot_report(stacks, topN);
    if nargout > 1, hot = find_hotspots(stacks, topN); end
    if nargout == 0, clear stacks; end   % called for the printed report only: don't echo the struct
end

function safeDestroy()
    try
        st = sampling_profiler('status');
        if ~strcmp(st, 'off'), sampling_profiler('off'); end
    catch
    end
    try, sampling_profiler('destroy'); catch, end
end

% Copyright 2026 The MathWorks, Inc.
