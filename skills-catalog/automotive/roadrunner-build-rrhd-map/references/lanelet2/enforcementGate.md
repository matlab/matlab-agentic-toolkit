# Enforcement Gate

Run this validation block BEFORE calling `write(rrMap, outputFile)`. It catches the three most common conversion errors. Do NOT skip or simplify it.

## Alignment Check (informational)

```matlab
lanes = rrMap.Lanes;
nFwd = 0; nBwd = 0;
for i = 1:numel(lanes)
    if lanes(i).LeftLaneBoundary.Alignment == "Forward", nFwd = nFwd+1;
    else, nBwd = nBwd+1; end
    if lanes(i).RightLaneBoundary.Alignment == "Forward", nFwd = nFwd+1;
    else, nBwd = nBwd+1; end
end
fprintf('Alignment check: %d Forward, %d Backward\n', nFwd, nBwd);
% NOTE: All-Forward IS valid for oval/circular tracks where boundaries run same direction.
% The spatial check below is the authoritative correctness test.
```

## Left Boundary Spatial Check (multi-sample)

Uses LOCAL tangent at multiple sample points — NOT overall direction. Overall direction fails on highly curved lanes (split half-ovals, U-turns).

```matlab
bnds = rrMap.LaneBoundaries;
bndMap = containers.Map;
for i = 1:numel(bnds), bndMap(bnds(i).ID) = bnds(i).Geometry; end
nBadSide = 0;
for i = 1:numel(lanes)
    lGeom = lanes(i).Geometry;
    if size(lGeom,1) < 3, continue; end
    nSamples = min(5, size(lGeom,1)-1);
    sampleIdx = round(linspace(2, size(lGeom,1)-1, nSamples));
    leftBndID = lanes(i).LeftLaneBoundary.Reference.ID;
    if ~bndMap.isKey(leftBndID), continue; end
    leftBndGeom = bndMap(leftBndID);
    badCount = 0;
    for si = 1:numel(sampleIdx)
        idx = sampleIdx(si);
        localTan = lGeom(min(idx+1,size(lGeom,1)),1:2) - lGeom(max(idx-1,1),1:2);
        if norm(localTan) < 1e-6, continue; end
        localTan = localTan / norm(localTan);
        localLeftN = [-localTan(2), localTan(1)];
        distsL = vecnorm(leftBndGeom(:,1:2) - lGeom(idx,1:2), 2, 2);
        [~, closestL] = min(distsL);
        toBnd = leftBndGeom(closestL,1:2) - lGeom(idx,1:2);
        if dot(toBnd, localLeftN) < 0, badCount = badCount + 1; end
    end
    if badCount > numel(sampleIdx)/2, nBadSide = nBadSide + 1; end
end
assert(nBadSide == 0, ...
    'SPATIAL ERROR: %d lanes have left boundary on the RIGHT side — fix alignment algorithm.', nBadSide);
fprintf('Spatial left-side check (multi-sample): PASS\n');
```

## Asset Extension Check

Verify no `.rrcws` used for non-crosswalk CurveMarkingTypes (stop lines and bike markings use `.rrlms`).

```matlab
cmTypes = rrMap.CurveMarkingTypes;
for i = 1:numel(cmTypes)
    ap = string(cmTypes(i).AssetPath.AssetPath);
    id = string(cmTypes(i).ID);
    if contains(id, "Stop", IgnoreCase=true) || contains(id, "Bike", IgnoreCase=true) || contains(id, "Zig", IgnoreCase=true)
        assert(~endsWith(ap, ".rrcws"), ...
            sprintf('ASSET ERROR: %s uses .rrcws but should use .rrlms', id));
    end
end
fprintf('Asset extension check: PASS\n');
```

## Completeness Check

```matlab
assert(numel(rrMap.CurveMarkings) > 0 || (numel(stopLineWays)==0 && numel(pedestrianMarkingWays)==0 && numel(crosswalkLanelets)==0), ...
    'INCOMPLETE: CurveMarkings not built');
assert(numel(rrMap.Barriers) > 0 || (numel(fenceWays)==0 && numel(guardRailWays)==0), ...
    'INCOMPLETE: Barriers not built');
assert(numel(rrMap.Signs) > 0 || (numel(trafficSignWays)==0 && numel(trafficSignRels)==0), ...
    'INCOMPLETE: Signs not built');
assert(all(rrMap.GeoReference ~= 0), 'GeoReference not set');
fprintf('Completeness check: PASS\n');
```

----

Copyright 2026 The MathWorks, Inc.

----
