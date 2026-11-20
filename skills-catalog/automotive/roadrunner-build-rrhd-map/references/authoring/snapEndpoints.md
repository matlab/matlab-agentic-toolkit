# Snap Connected Endpoints

Snaps lane and boundary geometry endpoints for connected lanes (predecessor/successor pairs) to eliminate small gaps that cause visual artifacts in RoadRunner. This is the one sanctioned modification of source boundary geometry in a conversion: only endpoints of connected lanes, only for gaps below the threshold (default 1.0 m).

## Algorithm

For each lane with successors:
1. Check if the 2D gap between predecessor end and successor start is within threshold (default 1.0m)
2. If within threshold, snap successor start point to predecessor end point (XY only, preserve Z)
3. Also snap corresponding boundary endpoints, respecting alignment direction

## Implementation

```matlab
function [lanes, laneBoundaries, snapCount] = snapConnectedEndpoints(lanes, laneBoundaries, threshold)
    if nargin < 3, threshold = 1.0; end

    % Build ID -> index maps
    laneIdx = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(lanes), laneIdx(char(string(lanes(i).ID))) = i; end
    bndIdx = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(laneBoundaries), bndIdx(char(string(laneBoundaries(i).ID))) = i; end

    % Determine boundary alignment per lane via dot product
    nLanes = numel(lanes);
    leftFwd = true(nLanes,1);
    rightFwd = true(nLanes,1);
    for i = 1:nLanes
        lDir = lanes(i).Geometry(2,:) - lanes(i).Geometry(1,:);
        lbID = char(string(lanes(i).LeftLaneBoundary.Reference.ID));
        if isKey(bndIdx, lbID)
            bg = laneBoundaries(bndIdx(lbID)).Geometry;
            leftFwd(i) = dot(lDir(1:2), bg(2,1:2) - bg(1,1:2)) >= 0;
        end
        rbID = char(string(lanes(i).RightLaneBoundary.Reference.ID));
        if isKey(bndIdx, rbID)
            bg = laneBoundaries(bndIdx(rbID)).Geometry;
            rightFwd(i) = dot(lDir(1:2), bg(2,1:2) - bg(1,1:2)) >= 0;
        end
    end

    % Snap: successor start -> predecessor end
    snapCount = 0;
    for i = 1:nLanes
        predEnd = lanes(i).Geometry(end,:);
        for k = 1:numel(lanes(i).Successors)
            succID = char(string(lanes(i).Successors(k).Reference.ID));
            if ~isKey(laneIdx, succID), continue; end
            j = laneIdx(succID);
            gap = norm(predEnd(1:2) - lanes(j).Geometry(1,1:2));
            if gap > threshold || gap < 1e-6, continue; end

            % Snap lane center
            lanes(j).Geometry(1,1:2) = predEnd(1:2);

            % Snap left boundary
            predLB = char(string(lanes(i).LeftLaneBoundary.Reference.ID));
            succLB = char(string(lanes(j).LeftLaneBoundary.Reference.ID));
            if isKey(bndIdx, predLB) && isKey(bndIdx, succLB)
                if leftFwd(i), srcPt = laneBoundaries(bndIdx(predLB)).Geometry(end,1:2);
                else, srcPt = laneBoundaries(bndIdx(predLB)).Geometry(1,1:2); end
                if leftFwd(j), laneBoundaries(bndIdx(succLB)).Geometry(1,1:2) = srcPt;
                else, laneBoundaries(bndIdx(succLB)).Geometry(end,1:2) = srcPt; end
            end

            % Snap right boundary
            predRB = char(string(lanes(i).RightLaneBoundary.Reference.ID));
            succRB = char(string(lanes(j).RightLaneBoundary.Reference.ID));
            if isKey(bndIdx, predRB) && isKey(bndIdx, succRB)
                if rightFwd(i), srcPt = laneBoundaries(bndIdx(predRB)).Geometry(end,1:2);
                else, srcPt = laneBoundaries(bndIdx(predRB)).Geometry(1,1:2); end
                if rightFwd(j), laneBoundaries(bndIdx(succRB)).Geometry(1,1:2) = srcPt;
                else, laneBoundaries(bndIdx(succRB)).Geometry(end,1:2) = srcPt; end
            end

            snapCount = snapCount + 1;
        end
    end
end
```

## Key Details

- **XY only** — Z is preserved (handled separately by height conflict resolution)
- **Alignment-aware** — Forward boundaries: end→start. Backward boundaries: start→end.
- **Threshold** — Default 1.0m. Gaps larger than this are intentional (junction gaps).
- **Skip tiny gaps** — < 1e-6m means already snapped, no action needed.

----

Copyright 2026 The MathWorks, Inc.

----
