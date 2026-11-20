function [lanes, laneBoundaries, info] = resolveHeightConflicts(lanes, laneBoundaries, zStep, options)
%resolveHeightConflicts Resolve at-grade crossings of unconnected lanes via graph coloring.
%   [lanes, laneBoundaries, info] = resolveHeightConflicts(lanes, laneBoundaries)
%   finds unconnected lanes whose center lines cross in 2D at nearly the same
%   elevation and raises one side by a small step using greedy graph coloring.
%   Prevents grass artifacts where roads cross in RoadRunner. Source
%   elevation is preserved: offsets are added on top of the existing Z, and
%   crossings already separated vertically (bridges, overpasses) are ignored.
%
%   [lanes, laneBoundaries, info] = resolveHeightConflicts(lanes, laneBoundaries, zStep)
%   uses a custom Z step in meters (default 0.15m).
%
%   [...] = resolveHeightConflicts(..., MinSeparation=sep) treats crossings
%   whose elevations differ by at least sep meters (default 2.0m) as already
%   separated.
%
%   [...] = resolveHeightConflicts(..., JunctionLaneIDs=ids) ignores
%   crossings where both lanes are junction lanes — crossings inside a
%   junction are at grade by design. Pass info.junctionLaneIDs from
%   detectJunctions.
%
%   Inputs:
%     lanes           - Array of roadrunner.hdmap.Lane objects
%     laneBoundaries  - Array of roadrunner.hdmap.LaneBoundary objects
%     zStep           - Elevation increment per level (default 0.15m)
%     MinSeparation   - Vertical gap that already separates a crossing (default 2.0m)
%     JunctionLaneIDs - String IDs of junction lanes; crossings between two of them are ignored
%
%   Outputs:
%     lanes           - Lanes with resolved Z elevations
%     laneBoundaries  - Boundaries with resolved Z elevations
%     info            - Struct with nComponents, nConflicts, nZLevels, maxZ, lanesAdjusted

% Copyright 2026 The MathWorks, Inc.

    arguments
        lanes
        laneBoundaries
        zStep (1,1) double {mustBeNonnegative} = 0.15
        options.MinSeparation (1,1) double {mustBePositive} = 2.0
        options.JunctionLaneIDs (1,:) string = strings(1, 0)
    end

    nLanes = numel(lanes);
    info = struct('nComponents', 0, 'nConflicts', 0, 'nZLevels', 1, 'maxZ', 0, 'lanesAdjusted', 0);
    if nLanes == 0
        if nargout == 0, clear lanes laneBoundaries info; end
        return
    end

    laneIDs = arrayfun(@(l) char(string(l.ID)), lanes, 'UniformOutput', false);
    laneIdx = containers.Map(laneIDs, num2cell(1:nLanes));
    isJunctionLane = ismember(string(laneIDs(:)), options.JunctionLaneIDs);
    bndIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:numel(laneBoundaries), bndIdx(char(string(laneBoundaries(i).ID))) = i; end

    % Connected components via predecessor/successor links
    parent = 1:nLanes;
    for i = 1:nLanes
        refs = [lanes(i).Predecessors(:); lanes(i).Successors(:)];
        for k = 1:numel(refs)
            rid = char(string(refs(k).Reference.ID));
            if isKey(laneIdx, rid), parent = ufUnion(parent, i, laneIdx(rid)); end
        end
    end
    roots = arrayfun(@(x) ufFind(parent, x), 1:nLanes);
    [~, ~, compIdx] = unique(roots);
    compIdx = compIdx(:);
    nComps = max(compIdx);

    % Lane geometry and 2D bounding boxes
    geom = arrayfun(@(l) l.Geometry, lanes, 'UniformOutput', false);
    bb = zeros(nLanes, 4);
    for i = 1:nLanes
        g = geom{i};
        bb(i, :) = [min(g(:, 1:2), [], 1), max(g(:, 1:2), [], 1)];
    end

    % Lane pairs from different components that cross at nearly the same Z
    compAdj = false(nComps);
    nConflicts = 0;
    for i = 1:nLanes
        cand = find(bb(i, 1) <= bb(:, 3) & bb(i, 3) >= bb(:, 1) & ...
            bb(i, 2) <= bb(:, 4) & bb(i, 4) >= bb(:, 2) & ...
            compIdx ~= compIdx(i) & (1:nLanes)' > i);
        for j = cand'
            if compAdj(compIdx(i), compIdx(j)), continue; end
            if isJunctionLane(i) && isJunctionLane(j), continue; end   % at-grade by design
            if crossesAtGrade(geom{i}, geom{j}, options.MinSeparation)
                compAdj(compIdx(i), compIdx(j)) = true;
                compAdj(compIdx(j), compIdx(i)) = true;
                nConflicts = nConflicts + 1;
            end
        end
        if mod(i, 1000) == 0
            fprintf(1, 'resolveHeightConflicts: %d/%d lanes checked\n', i, nLanes);
        end
    end

    % Greedy graph coloring (highest degree first)
    compColor = zeros(nComps, 1);
    [~, order] = sort(sum(compAdj, 2), 'descend');
    for c = order'
        nb = find(compAdj(c, :));
        if isempty(nb), continue; end
        color = 0;
        while ismember(color, compColor(nb)), color = color + 1; end
        compColor(c) = color;
    end

    % Add offsets on top of the existing elevation (boundaries offset once, by the largest level)
    bndOffset = zeros(numel(laneBoundaries), 1);
    lanesAdjusted = 0;
    for i = 1:nLanes
        z = compColor(compIdx(i)) * zStep;
        if z == 0, continue; end
        lanes(i).Geometry(:, 3) = lanes(i).Geometry(:, 3) + z;
        lanesAdjusted = lanesAdjusted + 1;
        for side = ["LeftLaneBoundary", "RightLaneBoundary"]
            bid = char(string(lanes(i).(side).Reference.ID));
            if isKey(bndIdx, bid)
                k = bndIdx(bid);
                bndOffset(k) = max(bndOffset(k), z);
            end
        end
    end
    for k = find(bndOffset)'
        laneBoundaries(k).Geometry(:, 3) = laneBoundaries(k).Geometry(:, 3) + bndOffset(k);
    end

    info = struct('nComponents', nComps, 'nConflicts', nConflicts, 'nZLevels', max(compColor) + 1, ...
        'maxZ', max(compColor) * zStep, 'lanesAdjusted', lanesAdjusted);

    if nargout == 0, clear lanes laneBoundaries info; end
end


function tf = crossesAtGrade(gA, gB, minSeparation)
%crossesAtGrade True if polylines cross in 2D where their elevations differ by less than minSeparation.
    tf = false;
    if size(gA, 1) < 2 || size(gB, 1) < 2, return; end
    a1 = gA(1:end-1, 1:2); d1 = diff(gA(:, 1:2));
    b1 = gB(1:end-1, 1:2); d2 = diff(gB(:, 1:2));
    denom = d1(:, 1) .* d2(:, 2)' - d1(:, 2) .* d2(:, 1)';
    dx = b1(:, 1)' - a1(:, 1);
    dy = b1(:, 2)' - a1(:, 2);
    t = (dx .* d2(:, 2)' - dy .* d2(:, 1)') ./ denom;
    u = (dx .* d1(:, 2) - dy .* d1(:, 1)) ./ denom;
    hit = abs(denom) > 1e-10 & t >= 0 & t <= 1 & u >= 0 & u <= 1;
    if ~any(hit, 'all'), return; end
    [r, c] = find(hit);
    idx = sub2ind(size(t), r, c);
    zA = gA(r, 3) + t(idx) .* (gA(r + 1, 3) - gA(r, 3));
    zB = gB(c, 3) + u(idx) .* (gB(c + 1, 3) - gB(c, 3));
    tf = any(abs(zA - zB) < minSeparation);
end


function root = ufFind(parent, x)
%ufFind Find root with path compression.
    while parent(x) ~= x
        parent(x) = parent(parent(x));
        x = parent(x);
    end
    root = x;
end


function parent = ufUnion(parent, a, b)
%ufUnion Union two elements.
    ra = ufFind(parent, a);
    rb = ufFind(parent, b);
    if ra ~= rb, parent(ra) = rb; end
end
