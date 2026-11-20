function [junctions, info] = detectJunctions(lanes, laneBoundaries, options)
%detectJunctions Build RRHD junctions from overlapping lane footprints.
%   [junctions, info] = detectJunctions(lanes, laneBoundaries) finds the
%   conflict areas of a road network and returns roadrunner.hdmap.Junction
%   objects. A conflict area is a connected group of lanes whose footprints
%   (area between left and right boundary) overlap — turn and through lanes
%   inside an intersection, the lanes of a diverge or merge, or a
%   roundabout entry/exit with the ring segment it crosses. Lanes that only
%   touch end-to-end (predecessor/successor) or side-by-side (shared
%   boundary) never form a junction, so lane-add/drop tapers and plain
%   road do not become junctions. Diverges and merges whose lanes overlap
%   are kept as junctions by default: if they are left out, RoadRunner
%   builds its own (larger) junction there anyway. Groups smaller than
%   MinJunctionArea are dropped. Groups that continue end to end along the
%   same lanes (one diverge, merge, or crossing cut into short lanelets by
%   the source) are merged first, and so are groups lying side by side
%   across the road (two halves of one intersection), so a conflict area
%   becomes one junction. Groups that only touch at a corner (adjacent
%   roundabout entries) stay separate.
%   Works for any source; does not need turn_direction tags.
%
%   [...] = detectJunctions(..., MinOverlapArea=a, MinOverlapFraction=f)
%   sets the overlap needed to link two lanes: area > max(a, f * smaller
%   lane area). Defaults: a = 0.01 m^2, f = 0 — even small overlaps are
%   linked so RoadRunner does not create sliver junctions for them.
%
%   [...] = detectJunctions(..., MinJunctionArea=A) drops conflict areas
%   smaller than A m^2 (default 15).
%
%   Inputs:
%     lanes              - Array of roadrunner.hdmap.Lane (boundaries and topology assigned)
%     laneBoundaries     - Array of roadrunner.hdmap.LaneBoundary
%     MinOverlapArea     - Minimum overlap area in m^2 (default 0.01)
%     MinOverlapFraction - Minimum overlap as fraction of the smaller lane area (default 0)
%     MinJunctionArea    - Minimum junction area in m^2 (default 15)
%     DropDivergeMerge   - Drop 2-lane groups that split/join at < 15 deg (default false)
%     MergeGap           - Merge groups chained end to end whose footprints are within this
%                          distance in m (default 1.0); 0 disables chain merging
%     SideBySideLength   - Merge groups whose footprints run side by side (within MergeGap)
%                          for at least this length in m (default 4); 0 disables
%
%   Outputs:
%     junctions - Array of roadrunner.hdmap.Junction (ID, Lanes, Geometry = MultiPolygon of the
%                 union of member lane footprints)
%     info      - Struct: nJunctions, laneCounts, areas (m^2), centers (Nx2),
%                 junctionLaneIDs (string array of all member lanes),
%                 nDroppedDivergeMerge, nDroppedSmall, nMergedChains, nMergedSideBySide
%
%   Example:
%     [junctions, info] = detectJunctions(lanes, laneBoundaries);
%     rrMap.Junctions = junctions;

% Copyright 2026 The MathWorks, Inc.

    arguments
        lanes
        laneBoundaries
        options.MinOverlapArea (1,1) double {mustBeNonnegative} = 0.01
        options.MinOverlapFraction (1,1) double {mustBeNonnegative} = 0
        options.MinJunctionArea (1,1) double {mustBeNonnegative} = 15
        options.DropDivergeMerge (1,1) logical = false
        options.MergeGap (1,1) double {mustBeNonnegative} = 1.0
        options.SideBySideLength (1,1) double {mustBeNonnegative} = 4
    end

    n = numel(lanes);
    junctions = roadrunner.hdmap.Junction.empty;
    info = struct('nJunctions', 0, 'laneCounts', zeros(0, 1), 'areas', zeros(0, 1), ...
        'centers', zeros(0, 2), 'junctionLaneIDs', strings(0, 1), 'nDroppedDivergeMerge', 0, 'nDroppedSmall', 0, 'nMergedChains', 0, 'nMergedSideBySide', 0);
    if n == 0, if nargout == 0, clear junctions info; end; return; end

    ids = arrayfun(@(l) string(l.ID), lanes(:));
    idx = containers.Map(cellstr(ids), num2cell(1:n));
    bndGeom = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for k = 1:numel(laneBoundaries)
        bndGeom(char(string(laneBoundaries(k).ID))) = laneBoundaries(k).Geometry;
    end

    % Footprints: left boundary (lane direction) + right boundary reversed
    shapes = cell(n, 1); areas = zeros(n, 1); bb = nan(n, 4);
    leftID = strings(n, 1); rightID = strings(n, 1); zMean = zeros(n, 1);
    w = warning('off', 'MATLAB:polyshape:repairedBySimplify');
    restoreWarning = onCleanup(@() warning(w));
    for i = 1:n
        lr = lanes(i).LeftLaneBoundary; rr = lanes(i).RightLaneBoundary;
        if isempty(lr) || isempty(rr), continue; end
        leftID(i) = string(lr.Reference.ID); rightID(i) = string(rr.Reference.ID);
        if ~isKey(bndGeom, char(leftID(i))) || ~isKey(bndGeom, char(rightID(i))), continue; end
        L = bndGeom(char(leftID(i))); R = bndGeom(char(rightID(i)));
        if lr.Alignment == "Backward", L = flipud(L); end
        if rr.Alignment == "Backward", R = flipud(R); end
        P = [L(:, 1:2); flipud(R(:, 1:2))];
        ps = polyshape(P(:, 1), P(:, 2));
        if ps.NumRegions == 0, continue; end
        shapes{i} = ps; areas(i) = area(ps); zMean(i) = mean([L(:, 3); R(:, 3)]);
        bb(i, :) = [min(P, [], 1), max(P, [], 1)];
    end

    % Topologically connected pairs never link (they touch end to end)
    connected = false(n);
    predOf = cell(n, 1); succOf = cell(n, 1);
    for i = 1:n
        refs = [lanes(i).Predecessors(:); lanes(i).Successors(:)];
        nPred = numel(lanes(i).Predecessors);
        for k = 1:numel(refs)
            rid = char(string(refs(k).Reference.ID));
            if ~isKey(idx, rid), continue; end
            connected(i, idx(rid)) = true; connected(idx(rid), i) = true;
            if k <= nPred, predOf{i}(end + 1) = idx(rid); else, succOf{i}(end + 1) = idx(rid); end
        end
    end
    laneDir = @(i) (lanes(i).Geometry(end, 1:2) - lanes(i).Geometry(1, 1:2)) / ...
        (norm(lanes(i).Geometry(end, 1:2) - lanes(i).Geometry(1, 1:2)) + 1e-10);

    % Overlap graph
    src = zeros(0, 1); dst = zeros(0, 1);
    valid = ~cellfun(@isempty, shapes);
    for i = find(valid)'
        if n > 2000 && mod(i, 1000) == 0
            fprintf(1, 'detectJunctions: %d/%d lanes checked for overlap\n', i, n);
        end
        cand = find(valid & (1:n)' > i & bb(:, 1) <= bb(i, 3) & bb(:, 3) >= bb(i, 1) & ...
            bb(:, 2) <= bb(i, 4) & bb(:, 4) >= bb(i, 2));
        for j = cand'
            if connected(i, j), continue; end
            sharesBoundary = any(ismember([leftID(i), rightID(i)], [leftID(j), rightID(j)]));
            ov = area(intersect(shapes{i}, shapes{j}));
            thresh = max(options.MinOverlapArea, options.MinOverlapFraction * min(areas(i), areas(j)));
            if sharesBoundary, thresh = max(thresh, 0.25 * min(areas(i), areas(j))); end
            if ov > thresh
                src(end + 1, 1) = i; dst(end + 1, 1) = j; %#ok<AGROW>
            end
        end
    end
    if isempty(src), if nargout == 0, clear junctions info; end; return; end

    G = graph(src, dst, [], n);
    comp = conncomp(G);
    deg = degree(G);
    groups = unique(comp(deg > 0));

    % Merge groups chained end to end along the same lanes (a long diverge/merge or crossing that
    % the source cut into short lanelets): a member of one group is the predecessor/successor of a
    % member of the other AND the two footprints are within MergeGap. Lanes that belong to neither
    % group (e.g. roundabout ring segments between entries) keep neighbouring junctions separate.
    groupMembers = arrayfun(@(g) find(comp == g & deg' > 0), groups, 'UniformOutput', false);
    groupShape = cellfun(@(mm) union([shapes{mm}]), groupMembers, 'UniformOutput', false);
    nG = numel(groups);
    parentG = 1:nG;
    laneGroup = zeros(n, 1);
    for g = 1:nG, laneGroup(groupMembers{g}) = g; end
    for g = 1:nG
        for i = groupMembers{g}
            for k = [predOf{i}, succOf{i}]
                h = laneGroup(k);
                if h == 0 || h == g, continue; end
                rg = findRoot(parentG, g); rh = findRoot(parentG, h);
                if rg == rh, continue; end
                if area(intersect(polybuffer(groupShape{g}, options.MergeGap), groupShape{h})) > 0
                    parentG(rg) = rh;
                    info.nMergedChains = info.nMergedChains + 1;
                end
            end
        end
    end
    % Merge groups that lie side by side across the road (two halves of one intersection's
    % cross-section): footprints run alongside each other for >= SideBySideLength metres,
    % i.e. buffering one by MergeGap/2 overlaps the other by > (MergeGap/2) * SideBySideLength.
    % (runs on the chain-merged clusters, so composite junctions are compared as a whole)
    if options.SideBySideLength > 0
        changed = true;
        while changed
            changed = false;
            roots = unique(arrayfun(@(g) findRoot(parentG, g), 1:nG));
            cs = cell(numel(roots), 1);
            for q = 1:numel(roots)
                cs{q} = union([groupShape{arrayfun(@(g) findRoot(parentG, g), 1:nG) == roots(q)}]);
            end
            bbC = cell2mat(cellfun(@(u) [min(u.Vertices, [], 1), max(u.Vertices, [], 1)], cs, 'UniformOutput', false));
            for q = 1:numel(roots)
                for r2 = q+1:numel(roots)
                    if bbC(q,1) > bbC(r2,3) + options.MergeGap || bbC(r2,1) > bbC(q,3) + options.MergeGap || ...
                            bbC(q,2) > bbC(r2,4) + options.MergeGap || bbC(r2,2) > bbC(q,4) + options.MergeGap
                        continue
                    end
                    shared = area(intersect(polybuffer(cs{q}, options.MergeGap / 2), cs{r2}));
                    if shared > (options.MergeGap / 2) * options.SideBySideLength
                        parentG(roots(q)) = roots(r2);
                        info.nMergedSideBySide = info.nMergedSideBySide + 1;
                        changed = true;
                        break
                    end
                end
                if changed, break; end
            end
        end
    end
    rootOf = arrayfun(@(g) findRoot(parentG, g), 1:nG);
    for r = unique(rootOf)
        members = [groupMembers{rootOf == r}];
        if options.DropDivergeMerge && numel(members) == 2
            a = members(1); b = members(2);
            sharesEnd = ~isempty(intersect(predOf{a}, predOf{b})) || ~isempty(intersect(succOf{a}, succOf{b}));
            if sharesEnd && acosd(max(-1, min(1, dot(laneDir(a), laneDir(b))))) < 15
                info.nDroppedDivergeMerge = info.nDroppedDivergeMerge + 1;
                continue
            end
        end
        u = union([shapes{members}]);
        if area(u) < options.MinJunctionArea
            info.nDroppedSmall = info.nDroppedSmall + 1;
            continue
        end
        % Close gaps between member footprints that touch but do not overlap (merged halves of one
        % intersection), so the polygon covers every member lane rather than only the largest piece
        if options.MergeGap > 0 && u.NumRegions > 1
            u = polybuffer(polybuffer(u, options.MergeGap / 2, 'JointType', 'miter'), -options.MergeGap / 2, 'JointType', 'miter');
        end
        u = rmholes(u);
        regs = regions(u);
        [~, big] = max(arrayfun(@area, regs));
        v = regs(big).Vertices;
        v = v(~any(isnan(v), 2), :);
        ring = [v, repmat(mean(zMean(members)), size(v, 1), 1)];
        ring(end + 1, :) = ring(1, :); %#ok<AGROW>

        j = roadrunner.hdmap.Junction;
        j.ID = sprintf("Junction_%d", numel(junctions) + 1);
        for m = members
            ref = roadrunner.hdmap.Reference; ref.ID = ids(m);
            j.Lanes(end + 1) = ref;
        end
        pg = roadrunner.hdmap.Polygon; pg.ExteriorRing = ring;
        mp = roadrunner.hdmap.MultiPolygon; mp.Polygons = pg;
        j.Geometry = mp;
        junctions(end + 1) = j; %#ok<AGROW>

        info.laneCounts(end + 1, 1) = numel(members);
        info.areas(end + 1, 1) = area(u);
        info.centers(end + 1, :) = mean(v, 1);
        info.junctionLaneIDs = [info.junctionLaneIDs; ids(members)];
    end
    info.nJunctions = numel(junctions);

    if nargout == 0, clear junctions info; end
end


function r = findRoot(parent, x)
%findRoot Root of x in a union-find parent array.
    while parent(x) ~= x
        x = parent(x);
    end
    r = x;
end
