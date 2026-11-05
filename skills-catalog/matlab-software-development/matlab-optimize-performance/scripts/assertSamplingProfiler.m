function assertSamplingProfiler()
%ASSERTSAMPLINGPROFILER Error early if the Sampling Profiler is unavailable.
%
%   assertSamplingProfiler()
%
% The Sampling Profiler entry points (quick_profile, profile_function,
% profile_script, profile_test) need R2026b or newer. Call this first so that on
% an older release the caller gets a clear, actionable message pointing at the
% MATLAB profiler (Step 2) instead of failing partway through.
%
% Detection is sampling_profiler('available'), which never errors.

    if ~sampling_profiler('available')
        error('SamplingProfiler:notAvailable', ...
            ['The Sampling Profiler is not ' ...
             'available on this release — it requires R2026b or newer. Use the ' ...
             'MATLAB profiler instead (Step 2):\n' ...
             '    profile on; yourCode(); profile off; profile viewer']);
    end
end

% Copyright 2026 The MathWorks, Inc.
