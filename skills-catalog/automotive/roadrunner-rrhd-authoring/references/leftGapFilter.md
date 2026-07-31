# Left-Gap Topology Filter (MANDATORY Post-Construction Step)

Removes false predecessor/successor connections by validating left boundary continuity. False connections arise when lanes share right-boundary endpoint nodes but are physically on opposite sides of the road (left boundary gap > 3m).

**This step is MANDATORY after all topology connections are built, before `write()`.**

## Why

Source formats (Lanelet2, HERE, NDS) encode topology via shared boundary nodes. When opposing-direction lanes share a center divider node, naive node matching creates false connections between lanes that are physically adjacent but going different directions. The opposing-direction filter catches most cases, but shared center-line endpoint nodes at junction entries can still produce false connections with 3-6m left boundary gaps.

Without this filter, junction lanes get 2-4x too many connections, producing visually wrong routing in RoadRunner.

**Typical result:** On a 184-lane Japanese urban map, removes ~34 false connections.

## Algorithm

For each lane with multiple successors (or predecessors), compute the gap between the left boundary endpoints of the connection pair. If any connection has gap < 3m and others have gap > 3m, remove the far connections.

```matlab
%% --- LEFT-GAP TOPOLOGY FILTER (MANDATORY) ---
% Requires: lanes array, bndGeomMap (boundary ID → Nx3 geometry), laneIDMap (lane ID → index)

removeCount = 0;

% --- Filter successors ---
for i = 1:numel(lanes)
    nSucc = numel(lanes(i).Successors);
    if nSucc <= 1, continue; end

    % Get effective END of this lane's left boundary
    lbRef = lanes(i).LeftLaneBoundary;
    if ~bndGeomMap.isKey(lbRef.Reference.ID), continue; end
    lbGeom = bndGeomMap(lbRef.Reference.ID);
    if lbRef.Alignment == "Forward"
        predLeftEnd = lbGeom(end,:);
    else
        predLeftEnd = lbGeom(1,:);
    end

    % Compute gap to each successor's left boundary START
    succGaps = inf(1, nSucc);
    for s = 1:nSucc
        sID = lanes(i).Successors(s).Reference.ID;
        if ~laneIDMap.isKey(sID), continue; end
        sIdx = laneIDMap(sID);
        sLbRef = lanes(sIdx).LeftLaneBoundary;
        if ~bndGeomMap.isKey(sLbRef.Reference.ID), continue; end
        sLbGeom = bndGeomMap(sLbRef.Reference.ID);
        if sLbRef.Alignment == "Forward"
            succLeftStart = sLbGeom(1,:);
        else
            succLeftStart = sLbGeom(end,:);
        end
        succGaps(s) = norm(predLeftEnd(1:2) - succLeftStart(1:2));
    end

    % Remove far connections if a close one exists
    minGap = min(succGaps);
    if minGap < 3.0
        toRemove = find(succGaps > 3.0);
        if ~isempty(toRemove) && numel(toRemove) < nSucc
            for r = sort(toRemove, 'descend')
                sID = lanes(i).Successors(r).Reference.ID;
                if laneIDMap.isKey(sID)
                    sIdx = laneIDMap(sID);
                    % Remove reciprocal predecessor reference
                    for pp = numel(lanes(sIdx).Predecessors):-1:1
                        if strcmp(lanes(sIdx).Predecessors(pp).Reference.ID, lanes(i).ID)
                            lanes(sIdx).Predecessors(pp) = [];
                            break;
                        end
                    end
                end
                lanes(i).Successors(r) = [];
                removeCount = removeCount + 1;
            end
        end
    end
end

% --- Filter predecessors ---
for i = 1:numel(lanes)
    nPred = numel(lanes(i).Predecessors);
    if nPred <= 1, continue; end

    % Get effective START of this lane's left boundary
    lbRef = lanes(i).LeftLaneBoundary;
    if ~bndGeomMap.isKey(lbRef.Reference.ID), continue; end
    lbGeom = bndGeomMap(lbRef.Reference.ID);
    if lbRef.Alignment == "Forward"
        succLeftStart = lbGeom(1,:);
    else
        succLeftStart = lbGeom(end,:);
    end

    % Compute gap from each predecessor's left boundary END
    predGaps = inf(1, nPred);
    for p = 1:nPred
        pID = lanes(i).Predecessors(p).Reference.ID;
        if ~laneIDMap.isKey(pID), continue; end
        pIdx = laneIDMap(pID);
        pLbRef = lanes(pIdx).LeftLaneBoundary;
        if ~bndGeomMap.isKey(pLbRef.Reference.ID), continue; end
        pLbGeom = bndGeomMap(pLbRef.Reference.ID);
        if pLbRef.Alignment == "Forward"
            predLeftEnd = pLbGeom(end,:);
        else
            predLeftEnd = pLbGeom(1,:);
        end
        predGaps(p) = norm(succLeftStart(1:2) - predLeftEnd(1:2));
    end

    % Remove far connections if a close one exists
    minGap = min(predGaps);
    if minGap < 3.0
        toRemove = find(predGaps > 3.0);
        if ~isempty(toRemove) && numel(toRemove) < nPred
            for r = sort(toRemove, 'descend')
                pID = lanes(i).Predecessors(r).Reference.ID;
                if laneIDMap.isKey(pID)
                    pIdx = laneIDMap(pID);
                    % Remove reciprocal successor reference
                    for ss = numel(lanes(pIdx).Successors):-1:1
                        if strcmp(lanes(pIdx).Successors(ss).Reference.ID, lanes(i).ID)
                            lanes(pIdx).Successors(ss) = [];
                            break;
                        end
                    end
                end
                lanes(i).Predecessors(r) = [];
                removeCount = removeCount + 1;
            end
        end
    end
end

fprintf('Left-gap filter: removed %d false connections\n', removeCount);
```

## Key Details

- **Threshold:** 3.0m — connections with left boundary gap < 3m are valid; those > 3m when a better alternative exists are false
- **Bidirectional:** Apply to BOTH successors and predecessors
- **Reciprocal removal:** When removing a successor, also remove the corresponding predecessor from the target lane (and vice versa)
- **Safety:** Never remove ALL connections — only remove far ones when a close alternative exists (`numel(toRemove) < nSucc`)
- **Left boundary effective endpoints:** Respect `Alignment` — Forward means start=geom(1,:)/end=geom(end,:); Backward means start=geom(end,:)/end=geom(1,:)

## When to Skip

- Synthetic scenes built from scratch (topology is explicit and intentional)
- Maps where only 1 predecessor and 1 successor per lane exist (nothing to filter)

## Integration with Pipeline

In the standard RRHD construction pipeline:

1. Build all boundaries and lanes
2. Build topology connections (pred/succ)
3. **Left-gap topology filter** ← this step
4. Endpoint snapping
5. Height conflict resolution
6. Boundary deduplication
7. Enforcement gate
8. Assemble map and `write()`

----

Copyright 2026 The MathWorks, Inc.
