function [stacks, hot] = profile_script(scriptPath, topN)
%PROFILE_SCRIPT Profile a MATLAB SCRIPT file (not a function) and print hotspots.
%
%   profile_script('myAnalysis.m')
%   profile_script('myAnalysis.m', 20)
%   [stacks, hot] = profile_script(fullfile(myDir,'myAnalysis.m'))
%
% WHY THIS EXISTS: you cannot profile a script via @()run('script.m') — MATLAB
% rejects it with "Attempt to add variable to static workspace". This helper
% runs the script through `run` inside a normal (non-anonymous) function frame,
% which is allowed, and captures the profile around it.
%
% The script runs in a workspace of its own, so a script that starts with `clear`
% cannot break the capture. Its variables do not leak back to the caller.
%
% INPUT
%   scriptPath : path to a .m script file (a file with no `function` line, or a
%                script you normally invoke by name).
%   topN       : hotspots to print (default 15).
%
% OUTPUT (optional)
%   stacks : raw stacks struct;  hot : top-N hotspots as data (see find_hotspots).
%
% For a FUNCTION handle use quick_profile / profile_function instead.

    if nargin < 2 || isempty(topN), topN = 15; end
    assertSamplingProfiler();   % clear error + fallback hint on pre-R2026b
    assert(isfile(scriptPath), 'profile_script:notFound', 'Script not found: %s', scriptPath);

    % Warm-start protocol: start -> PAUSE -> warm-up run (NOT collected) ->
    % clear -> resume -> measured run. Warming up after 'on' rather than before
    % it leaves less first-call cost in the measured run.
    sampling_profiler('on');
    cleanup = onCleanup(@() safeDestroy());
    sampling_profiler('pause');
    runIsolated(scriptPath);                  % warm-up (not collected)
    sampling_profiler('clear');
    sampling_profiler('resume');
    runIsolated(scriptPath);                  % measured run
    [~, stacks] = sampling_profiler('off');
    clear cleanup;                            % onCleanup -> safeDestroy() tears down now

    fprintf('profile_script(%s): %d samples (%.2fs implied)\n', ...
        scriptPath, stacks.TotalSamples, stacks.TotalSamples/100);
    if stacks.TotalSamples < 20
        warning('profile_script:fewSamples', ...
            'Only %d samples — statistically noisy.', stacks.TotalSamples);
    end

    print_hotspot_report(stacks, topN);
    if nargout > 1, hot = find_hotspots(stacks, topN); end
    if nargout == 0, clear stacks; end   % called for the printed report only: don't echo the struct
end

function runIsolated(scriptPath)
    run(scriptPath);
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
