function hot = find_hotspots(stacks, topN)
%FIND_HOTSPOTS Return the top-N self-time hotspots as data (not printed).
%
%   hot = find_hotspots(stacks)        % top 20
%   hot = find_hotspots(stacks, 10)    % top 10
%
% Use this when a script or program needs to act on hotspots programmatically
% (e.g. decide which function to optimize) rather than read a printed report. For
% a human-readable terminal report use print_hotspot_report instead.
%
% INPUT
%   stacks : the struct returned by sampling_profiler('off')
%            / ('data'), or
%            results.stacks from profile_function / profile_test.
%   topN   : how many hotspots to return (default 20).
%
% OUTPUT
%   hot : struct array, sorted by self-samples descending, with fields:
%     .location  '<file>:<line>'  (self/leaf location — where CPU actually is)
%     .file      file base name (no path/ext)
%     .line      source line
%     .samples   leaf-sample count at this location
%     .selfPct   percent of captured snapshots whose leaf is here
%
% NOTE: self-time = leaf frame of each snapshot. A hot builtin (sort/fft) shows
% as self-time on its CALLING line (builtins have no MATLAB frame of their own).

    if nargin < 2 || isempty(topN), topN = 20; end
    if ~isfield(stacks, 'Snapshots') || isempty(stacks.Snapshots)
        hot = struct('location', {}, 'file', {}, 'line', {}, 'samples', {}, 'selfPct', {});
        return;
    end

    snaps = stacks.Snapshots;
    n = numel(snaps);
    counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for s = 1:n
        fr = snaps(s).Frames;
        d = min(double(snaps(s).Depth), numel(fr));
        if d < 1, continue; end
        leaf = fr(d);                       % innermost frame = self-time
        [~, b] = fileparts(leaf.FileName);
        key = sprintf('%s:%d', b, leaf.StartLine);
        if isKey(counts, key), counts(key) = counts(key) + 1; else, counts(key) = 1; end
    end

    keys = counts.keys;
    vals = cell2mat(counts.values);
    [vals, ord] = sort(vals, 'descend');
    keys = keys(ord);
    m = min(topN, numel(keys));

    hot = struct('location', {}, 'file', {}, 'line', {}, 'samples', {}, 'selfPct', {});
    for i = 1:m
        parts = strsplit(keys{i}, ':');
        hot(i).location = keys{i};             %#ok<AGROW>
        hot(i).file     = parts{1};
        hot(i).line     = str2double(parts{end});
        hot(i).samples  = vals(i);
        hot(i).selfPct  = 100 * vals(i) / n;
    end
end

% Copyright 2026 The MathWorks, Inc.
