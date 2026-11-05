function filtered = filter_test_frames(stacks, testFile)
%FILTER_TEST_FRAMES Filter stacks to exclude test framework overhead.
%
%   filtered = filter_test_frames(stacks, 'tMyTest')
%   filtered = filter_test_frames(stacks, 'tMyPerfTest')
%
% Removes samples where ALL frames on the stack are test framework code
% (TestRunner, PathFixture, Teardownable, path, addpath, etc.).
% Keeps all samples where ANY non-framework code is executing.
%
% This removes setup/teardown overhead (PathFixture cleanup, path
% manipulation) while preserving all samples from the actual test logic,
% even if the test class file itself isn't directly on the stack.
%
% The testFile argument is accepted for API consistency but the filtering
% logic is based on framework file detection, not test file matching.

frameworkFiles = {'TestRunner', 'TeardownElement', 'TeardownDelegate', ...
    'Teardownable', 'PathFixture', 'CurrentFolderFixture', 'Fixture', ...
    'path', 'addpath', 'parsedirs', 'onCleanup', 'InternalFixtureRole', ...
    'UserFixtureRole', 'TestCase', 'SetupElement'};

keep = true(1, numel(stacks.Snapshots));
for s = 1:numel(stacks.Snapshots)
    snap = stacks.Snapshots(s);
    if snap.Depth == 0
        keep(s) = false;
        continue;
    end
    allFramework = true;
    nf = min(double(snap.Depth), numel(snap.Frames));   % honor Frames(1:Depth) contract
    for f = 1:nf
        [~, fn, ~] = fileparts(snap.Frames(f).FileName);
        if ~ismember(fn, frameworkFiles)
            allFramework = false;
            break;
        end
    end
    if allFramework
        keep(s) = false;
    end
end

nRemoved = sum(~keep);

filtered = stacks;
filtered.Snapshots = stacks.Snapshots(keep);
% Subtract only the removed (framework-only) samples from TotalSamples — do NOT set it to
% numel(Snapshots). Setting TotalSamples == numel(Snapshots) would destroy the idle-sample
% count (TotalSamples - numel(Snapshots)), the wrap signal (TotalSamples > numel(Snapshots)),
% and implied time (TotalSamples/100). Subtracting nRemoved preserves the original idle count.
filtered.TotalSamples = stacks.TotalSamples - nRemoved;
filtered.FilteredSamples = nRemoved;   % how many framework-only snapshots were dropped
fprintf('filter_test_frames: kept %d/%d snapshots (removed %d framework-only samples)\n', ...
    sum(keep), numel(stacks.Snapshots), nRemoved);
end

% Copyright 2026 The MathWorks, Inc.
