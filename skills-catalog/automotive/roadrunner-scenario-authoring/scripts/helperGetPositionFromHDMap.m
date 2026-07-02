function [position, heading, laneInfo] = helperGetPositionFromHDMap(rrHDMap, varargin)
%helperGetPositionFromHDMap Get a world position on a lane via arc-length interpolation.
%
%   [pos, hdg] = helperGetPositionFromHDMap(rrHDMap, laneIdx, fraction)
%       Position at fractional distance (0=start, 1=end) on the laneIdx-th
%       longest lane matching filters.
%
%   [pos, hdg] = helperGetPositionFromHDMap(rrHDMap, queryPoint)
%       Nearest lane position to [x,y] or [x,y,z] query point.
%
%   [pos, hdg, laneInfo] = helperGetPositionFromHDMap(...)
%       Also returns struct: ID, LaneType, TravelDirection, GlobalIndex, Geometry.
%
%   Name-Value Options:
%       LaneType        - default "Driving"
%       TravelDirection - default "" (any)
%       Offset          - lateral offset in meters (default 0)
%       MinLength       - minimum lane length filter (default 0)
%       LaneIDs         - string array of lane IDs to restrict search to (default "" = all)
%
% This is a helper function for example purposes and may be removed or
% modified in the future.

    % Determine calling mode
    if nargin >= 3 && isnumeric(varargin{1}) && isscalar(varargin{1}) && isnumeric(varargin{2}) && isscalar(varargin{2})
        mode = "index";
        laneIdx = varargin{1};
        fraction = varargin{2};
        remainingArgs = varargin(3:end);
    elseif nargin >= 2 && isnumeric(varargin{1}) && ~isscalar(varargin{1})
        mode = "nearest";
        queryPoint = varargin{1};
        remainingArgs = varargin(2:end);
    else
        error("helperGetPositionFromHDMap:InvalidInput", ...
            "Provide either (laneIdx, fraction) or (queryPoint) as input.");
    end

    p = inputParser;
    addParameter(p, "LaneType", "Driving", @(x) isstring(x) || ischar(x));
    addParameter(p, "TravelDirection", "", @(x) isstring(x) || ischar(x));
    addParameter(p, "Offset", 0, @isnumeric);
    addParameter(p, "MinLength", 0, @isnumeric);
    addParameter(p, "LaneIDs", "", @(x) isstring(x) || ischar(x));
    parse(p, remainingArgs{:});
    opts = p.Results;

    % Build lane ID filter set (empty means no filter)
    laneIDFilter = string(opts.LaneIDs);
    laneIDFilter = laneIDFilter(laneIDFilter ~= "");
    hasLaneIDFilter = ~isempty(laneIDFilter);

    % Filter and sort lanes by length descending
    allLanes = rrHDMap.Lanes;
    filteredIndices = [];
    filteredLengths = [];

    for i = 1:numel(allLanes)
        lane = allLanes(i);
        if hasLaneIDFilter && ~ismember(string(lane.ID), laneIDFilter)
            continue;
        end
        if ~strcmpi(lane.LaneType, opts.LaneType)
            continue;
        end
        if opts.TravelDirection ~= "" && ~strcmpi(lane.TravelDirection, opts.TravelDirection)
            continue;
        end
        if size(lane.Geometry, 1) < 2
            continue;
        end
        geom = lane.Geometry;
        if size(geom, 2) == 2
            geom = [geom, zeros(size(geom, 1), 1)]; %#ok<AGROW>
        end
        laneLen = sum(sqrt(sum(diff(geom).^2, 2)));
        if laneLen < opts.MinLength
            continue;
        end
        filteredIndices(end+1) = i; %#ok<AGROW>
        filteredLengths(end+1) = laneLen; %#ok<AGROW>
    end

    if isempty(filteredIndices)
        error("helperGetPositionFromHDMap:NoLanes", ...
            "No lanes found matching filters (LaneType=%s, Direction=%s, MinLength=%.1f).", ...
            opts.LaneType, opts.TravelDirection, opts.MinLength);
    end

    [~, sortOrder] = sort(filteredLengths, 'descend');
    filteredIndices = filteredIndices(sortOrder);

    if mode == "index"
        if laneIdx < 1 || laneIdx > numel(filteredIndices)
            error("helperGetPositionFromHDMap:InvalidLaneIndex", ...
                "Lane index %d out of range. Found %d matching lanes.", laneIdx, numel(filteredIndices));
        end
        fraction = max(0, min(1, fraction));
        globalIdx = filteredIndices(laneIdx);
        [position, heading] = sampleLane(allLanes(globalIdx), fraction, opts.Offset);
    else
        % Nearest-point mode
        if numel(queryPoint) == 2
            queryPoint = [queryPoint(:)', 0];
        end
        bestDist = inf;
        bestPos = [0 0 0];
        bestHdg = [1 0 0];
        globalIdx = filteredIndices(1);

        for k = 1:numel(filteredIndices)
            idx = filteredIndices(k);
            geom = allLanes(idx).Geometry;
            if size(geom, 2) == 2
                geom = [geom, zeros(size(geom, 1), 1)]; %#ok<AGROW>
            end
            dists = sqrt(sum((geom(:,1:2) - queryPoint(1:2)).^2, 2));
            [minD, minI] = min(dists);
            if minD < bestDist
                bestDist = minD;
                cumDist = [0; cumsum(sqrt(sum(diff(geom).^2, 2)))];
                totalLen = cumDist(end);
                frac = 0;
                if totalLen > 0
                    frac = cumDist(minI) / totalLen;
                end
                [bestPos, bestHdg] = sampleLane(allLanes(idx), frac, opts.Offset);
                globalIdx = idx;
            end
        end
        position = bestPos;
        heading = bestHdg;
    end

    % Build lane info
    selectedLane = allLanes(globalIdx);
    laneInfo.ID = selectedLane.ID;
    laneInfo.LaneType = selectedLane.LaneType;
    laneInfo.TravelDirection = selectedLane.TravelDirection;
    laneInfo.GlobalIndex = globalIdx;
    laneInfo.Geometry = selectedLane.Geometry;
end


function [pos, hdg] = sampleLane(lane, fraction, lateralOffset)
%sampleLane Interpolate position and heading along a lane at a given fraction.
    geom = lane.Geometry;
    if size(geom, 2) == 2
        geom = [geom, zeros(size(geom, 1), 1)];
    end

    segLengths = sqrt(sum(diff(geom).^2, 2));
    cumDist = [0; cumsum(segLengths)];
    totalLen = cumDist(end);
    targetDist = fraction * totalLen;

    if targetDist <= 0
        pos = geom(1, :);
        tangent = geom(2, :) - geom(1, :);
    elseif targetDist >= totalLen
        pos = geom(end, :);
        tangent = geom(end, :) - geom(end-1, :);
    else
        segIdx = find(cumDist(2:end) >= targetDist, 1, 'first');
        t = (targetDist - cumDist(segIdx)) / segLengths(segIdx);
        pos = geom(segIdx, :) * (1 - t) + geom(segIdx + 1, :) * t;
        tangent = geom(segIdx + 1, :) - geom(segIdx, :);
    end

    tangentNorm = norm(tangent(1:2));
    if tangentNorm > 0
        hdg = tangent / tangentNorm;
    else
        hdg = [1 0 0];
    end

    if lateralOffset ~= 0
        perpendicular = [-hdg(2), hdg(1), 0];
        pos = pos + lateralOffset * perpendicular;
    end
end
% Copyright 2026 The MathWorks, Inc.
