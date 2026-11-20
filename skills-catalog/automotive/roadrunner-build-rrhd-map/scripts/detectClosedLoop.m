function [hasClosedLoop, info] = detectClosedLoop(rrMap, options)
%detectClosedLoop Detect closed-loop (track-style) road networks in an HD map.
%   [hasClosedLoop, info] = detectClosedLoop(rrMap) returns true when the
%   map contains a cycle of non-junction lanes (following Successors) whose
%   total center-line length is at least 100 m — e.g. an oval test track.
%   Use it to decide DetectAsphaltSurfaces: asphalt detection fills the
%   interior of such loops.
%
%   A roundabout ring is also a closed loop: a strongly connected group of
%   at least 3 lanes in which every lane has exactly one successor and one
%   predecessor inside the group (a simple ring), with total length of at
%   least MinRingLength (default 30 m). Its lanes may be junction lanes.
%
%   A map is also treated as a closed loop when one strongly connected
%   group of lanes holds at least 90% of all lane length (a track whose
%   ring passes through junction lanes, e.g. at a pit entry).
%
%   Street grids are not closed loops even though their topology contains
%   cycles: every cycle passes through junction lanes and no single cycle
%   group dominates. Short cycles of a few lanes (degenerate topology) are
%   ignored by the length threshold.
%
%   [...] = detectClosedLoop(rrMap, MinLoopLength=len) uses a custom
%   minimum loop length in meters; MinRingLength=len sets the minimum
%   simple-ring (roundabout) length.
%
%   Inputs:
%     rrMap          - roadrunnerHDMap object
%     MinLoopLength  - Minimum total lane length of a loop (default 100 m)
%     MinRingLength  - Minimum length of a simple ring / roundabout (default 30 m)
%
%   Outputs:
%     hasClosedLoop  - true if a qualifying loop exists
%     info           - Struct: nLanes, nJunctionLanes, nLanesOnAnyCycle,
%                      loopLanes (string IDs of the longest qualifying loop),
%                      loopLength (m), nRings (simple rings found), reason (text for logs)
%
%   Example:
%     m = roadrunnerHDMap; read(m, "track.rrhd");
%     [tf, info] = detectClosedLoop(m); disp(info.reason)

% Copyright 2026 The MathWorks, Inc.

    arguments
        rrMap (1,1) roadrunnerHDMap
        options.MinLoopLength (1,1) double {mustBePositive} = 100
        options.MinRingLength (1,1) double {mustBePositive} = 30
    end

    lanes = rrMap.Lanes;
    n = numel(lanes);
    info = struct('nLanes', n, 'nJunctionLanes', 0, 'nLanesOnAnyCycle', 0, ...
        'loopLanes', strings(1, 0), 'loopLength', 0, 'nRings', 0, 'reason', "");
    hasClosedLoop = false;
    if n == 0
        info.reason = "No lanes";
        if nargout == 0, clear hasClosedLoop info; end
        return
    end

    ids = arrayfun(@(l) string(l.ID), lanes);
    ids = ids(:);
    idx = containers.Map(cellstr(ids), num2cell(1:n));
    src = zeros(0, 1); dst = zeros(0, 1);
    for i = 1:n
        for k = 1:numel(lanes(i).Successors)
            sid = char(string(lanes(i).Successors(k).Reference.ID));
            if isKey(idx, sid)
                src(end + 1, 1) = i; %#ok<AGROW>
                dst(end + 1, 1) = idx(sid); %#ok<AGROW>
            end
        end
    end
    len = arrayfun(@(l) sum(vecnorm(diff(l.Geometry(:, 1:2)), 2, 2)), lanes);
    len = len(:);

    junctionIDs = strings(0, 1);
    for j = 1:numel(rrMap.Junctions)
        refs = rrMap.Junctions(j).Lanes;
        junctionIDs = [junctionIDs; arrayfun(@(r) string(r.ID), refs(:))]; %#ok<AGROW>
    end
    isJunction = ismember(ids, junctionIDs);
    info.nJunctionLanes = nnz(isJunction);

    allBins = conncomp(digraph(src, dst, [], n), 'Type', 'strong');
    allBins = allBins(:);
    allCount = accumarray(allBins, 1);
    info.nLanesOnAnyCycle = nnz(allCount(allBins) > 1);
    allLen = accumarray(allBins, len);
    [domLen, dom] = max(allLen .* (allCount > 1));

    % Simple rings (roundabouts): in/out degree exactly 1 inside the group
    ringGroups = zeros(0, 1);
    for g = find(allCount >= 3)'
        inG = allBins == g;
        e = inG(src) & inG(dst);
        outDeg = accumarray(src(e), 1, [n 1]); inDeg = accumarray(dst(e), 1, [n 1]);
        if all(outDeg(inG) == 1) && all(inDeg(inG) == 1) && allLen(g) >= options.MinRingLength
            ringGroups(end + 1, 1) = g; %#ok<AGROW>
        end
    end
    info.nRings = numel(ringGroups);

    keep = ~isJunction(src) & ~isJunction(dst);
    bins = conncomp(digraph(src(keep), dst(keep), [], n), 'Type', 'strong');
    bins = bins(:);
    count = accumarray(bins, 1);
    loopLen = accumarray(bins, len);
    selfLoop = false(numel(count), 1);
    selfLoop(bins(src(keep & src == dst))) = true;
    candidate = (count > 1 | selfLoop) & loopLen >= options.MinLoopLength;
    if ~isempty(ringGroups)
        [info.loopLength, k] = max(allLen(ringGroups));
        info.loopLanes = ids(allBins == ringGroups(k))';
        hasClosedLoop = true;
        info.reason = sprintf("Closed loop: %d simple ring(s) (roundabout); largest has %d lanes, %.0f m", ...
            numel(ringGroups), numel(info.loopLanes), info.loopLength);
    elseif any(candidate)
        [info.loopLength, best] = max(loopLen .* candidate);
        info.loopLanes = ids(bins == best)';
        hasClosedLoop = true;
        info.reason = sprintf("Closed loop: %d non-junction lanes form a %.0f m cycle", ...
            numel(info.loopLanes), info.loopLength);
    elseif domLen >= options.MinLoopLength && domLen >= 0.9 * sum(len)
        info.loopLength = domLen;
        info.loopLanes = ids(allBins == dom)';
        hasClosedLoop = true;
        info.reason = sprintf("Closed loop: one cycle group of %d lanes holds %.0f%% of lane length (%.0f m)", ...
            numel(info.loopLanes), 100 * domLen / sum(len), domLen);
    else
        info.reason = sprintf("No closed loop: %d of %d lanes lie on topology cycles, but none form a junction-free cycle >= %.0f m", ...
            info.nLanesOnAnyCycle, n, options.MinLoopLength);
    end

    if nargout == 0, clear hasClosedLoop info; end
end
