# Extracting Topology

Determines predecessor/successor relationships between lanelets using boundary endpoint node matching.

## Primary Method: Boundary Endpoint Node Matching

Two lanelets are sequential if their boundary ways share endpoint nodes. This captures ~96% of lane connectivity including intersection connections that proximity methods miss.

**Critical: Account for opposing boundary directions.** Left and right boundaries of a lanelet may run in opposite directions (common in bidirectional roads where a center boundary is shared between opposing lanes). The "last node" of a reversed boundary is at the lane START, not end.

### Detecting Backward-Right Boundaries

Use the dot product of left and right boundary directions with a threshold of -0.3 (not 0):

```matlab
lPts = geomMap(ll.leftWayID);
rPts = geomMap(ll.rightWayID);
lDir = lPts(end,:) - lPts(1,:);
rDir = rPts(end,:) - rPts(1,:);
dp = dot(lDir(1:2)/(norm(lDir(1:2))+1e-10), rDir(1:2)/(norm(rDir(1:2))+1e-10));
isRightBackward = (dp < -0.3);
```

When `dp >= -0.3`, boundaries go in the same direction (normal case). When `dp < -0.3`, use **proximity** to determine which direction the right boundary travels relative to the lane:

```matlab
if dp >= -0.3
    % Normal case: right boundary goes in travel direction
    rightStartNode = rightWay.nodeRefs{1};
    rightEndNode = rightWay.nodeRefs{end};
else
    % Opposing boundaries: check proximity to determine travel direction
    d_ls_re = norm(lPts(1,1:2) - rPts(end,1:2));  % left start to right end
    d_ls_rs = norm(lPts(1,1:2) - rPts(1,1:2));    % left start to right start
    if d_ls_re < d_ls_rs
        % Right boundary is BACKWARD: effective start = last node, end = first
        rightStartNode = rightWay.nodeRefs{end};
        rightEndNode = rightWay.nodeRefs{1};
    else
        rightStartNode = rightWay.nodeRefs{1};
        rightEndNode = rightWay.nodeRefs{end};
    end
end
```

### Building Endpoint Maps

Build `endToLanelet` and `startToLanelet` maps using effective right boundary endpoints:

```matlab
endToLanelet = containers.Map('KeyType','char','ValueType','any');
startToLanelet = containers.Map('KeyType','char','ValueType','any');
% For each lanelet: add to endToLanelet(rightEndNode) and startToLanelet(rightStartNode)
```

### Opposing-Direction Filter (MANDATORY)

After connecting lanes via shared endpoint nodes, filter out false connections between opposing-direction lanes. Use **EFFECTIVE travel direction** (not raw right boundary direction):

```matlab
% Compute effective travel direction for predecessor
predDpLR = dot(predLDir(1:2)/norm(...), predRDir(1:2)/norm(...));
if predDpLR >= -0.3
    predTravelDir = predRDir(1:2);      % normal: right = travel
else
    predTravelDir = -predRDir(1:2);     % backward right: reverse
end

% Same for successor...
dpTravel = dot(predTravelDir/norm(...), succTravelDir/norm(...));
if dpTravel < -0.3
    continue;  % Skip opposing-direction connection
end
```

**Why effective direction?** For backward-right lanes, the raw right boundary direction is OPPOSITE to travel. Using it directly in the filter would incorrectly flag valid same-direction connections as "opposing."

### Left-Gap Filtering (MANDATORY — removes false successors)

After building pred/succ connections, apply the left-gap topology filter to remove false connections caused by shared boundary endpoint nodes. See `roadrunner-rrhd-authoring` skill's [references/leftGapFilter.md](../../roadrunner-rrhd-authoring/references/leftGapFilter.md) for the full algorithm and code.

**Summary:** For each lane with multiple successors/predecessors, compute left boundary gap. If any connection has gap < 3m and others > 3m, remove the far ones. Applies bidirectionally. Typically removes ~34 false connections on the reference 184-lane map.

### Why Not Simple Node Matching?

Simple `wayLastNode == wayFirstNode` without flip detection creates false connections for opposing-boundary lanes:
- Lane_124's right boundary ends at node X (which is at lane START due to reversal)
- Lane_56's right boundary starts at node X (which is at lane START)
- Simple matching says "Lane_124 → Lane_56" but actually both STARTs are at node X
- Results in 71m+ gaps between "connected" lanes

With flip detection, effective end/start are correct and all gaps are either ~0m (direct) or ~3m (intersection crossings).

## Fallback: Center Line Proximity

For unmatched pairs after node matching, use geometry proximity:

```matlab
THRESH = 1.0; % meters
d = norm(endPts(i,:) - startPts(j,:));
if d < THRESH
    topo(i).successors(end+1) = lanelets(j).id;
    topo(j).predecessors(end+1) = lanelets(i).id;
end
```

## Endpoint Gaps After Topology

Connected lanes will have two types of gaps:
- **~0m**: Directly adjacent lanes sharing a boundary
- **~2-4m**: Intersection crossings (lane center to next lane center across junction)

Do NOT snap intersection-crossing gaps. Only snap gaps < 1.5m. The ~3m gaps are real physical distances — RoadRunner uses topology references for routing, not geometric coincidence.

## Performance Note

The O(n²) comparison is acceptable for maps with < 1000 lanelets. For larger maps, build a node-to-lanelet index for O(n) lookup.

----

Copyright 2026 The MathWorks, Inc.
