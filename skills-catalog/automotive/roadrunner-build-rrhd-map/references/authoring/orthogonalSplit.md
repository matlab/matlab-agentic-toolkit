# Generic N-Way Orthogonal Split for Closed-Loop Geometry

## Description

Splits closed-loop lane geometry (where start ≈ end) into N open segments with **perfectly orthogonal joints**. Every joint is a perpendicular cross-section through the reference center line, ensuring left, center, and right endpoints are co-linear and perpendicular to the lane travel direction.

RoadRunner cannot render self-closed roads — this is a required workaround.

## When to Use

- Closed-loop lanelets (oval tracks, circuits, roundabouts)
- Any lane where `norm(geom(1,:) - geom(end,:)) < 1.0m`
- Default N=2 (two halves); use N=3 for longer loops to reduce segment length

## Algorithm

### Step 1: Synthesize Reference Center Line

```matlab
% Align boundary directions (closed-loop-aware)
lDir = leftOpen(min(5,nL),:) - leftOpen(1,:);
dists = vecnorm(rightOpen(:,1:2) - leftOpen(1,1:2), 2, 2);
[~, rStartIdx] = min(dists);
rDir = rightOpen(min(rStartIdx+4,nR),:) - rightOpen(rStartIdx,:);
if dot(lDir(1:2), rDir(1:2)) < 0
    rightOpen = flipud(rightOpen);
    dists = vecnorm(rightOpen(:,1:2) - leftOpen(1,1:2), 2, 2);
    [~, rStartIdx] = min(dists);
end
% Rotate right boundary to align start points
if rStartIdx > 1
    rightOpen = [rightOpen(rStartIdx:end,:); rightOpen(1:rStartIdx-1,:)];
end

% Resample both to same count for averaging
nRef = max(nL, nR);
dL = diff(leftOpen); sL = sqrt(sum(dL.^2,2)); cL = [0;cumsum(sL)];
dR = diff(rightOpen); sR = sqrt(sum(dR.^2,2)); cR = [0;cumsum(sR)];
tt = linspace(0,1,nRef)';
leftRes = zeros(nRef,3); rightRes = zeros(nRef,3);
for dim = 1:3
    leftRes(:,dim) = interp1(cL/cL(end), leftOpen(:,dim), tt, 'pchip');
    rightRes(:,dim) = interp1(cR/cR(end), rightOpen(:,dim), tt, 'pchip');
end
refCenter = (leftRes + rightRes) / 2;
```

### Step 2: Find N Split Points Along Center Arc Length

```matlab
dC = diff(refCenter); sC = sqrt(sum(dC.^2,2)); cumC = [0;cumsum(sC)];
totalCLen = cumC(end);

splitPts = zeros(N_SPLITS, 3);
splitTans = zeros(N_SPLITS, 2);
splitCIdx = zeros(N_SPLITS, 1);

for sp = 1:N_SPLITS
    targetLen = (sp-1)/N_SPLITS * totalCLen;  % 0, 1/N, 2/N, ...
    segIdx = find(cumC >= targetLen, 1);
    if isempty(segIdx), segIdx = nRef; end
    if segIdx < 2, segIdx = 2; end
    splitCIdx(sp) = segIdx;
    splitPts(sp,:) = refCenter(segIdx,:);
    % Local tangent (use neighbors for stability)
    prevIdx = max(segIdx-2, 1);
    nextIdx = min(segIdx+2, nRef);
    tan2D = refCenter(nextIdx,1:2) - refCenter(prevIdx,1:2);
    splitTans(sp,:) = tan2D / norm(tan2D);
end
```

### Step 3: Project Both Boundaries onto Perpendicular Cross-Sections

At each split point, the **tangent direction** is the plane normal. Find where each boundary crosses this perpendicular plane:

```matlab
for sp = 1:N_SPLITS
    planePt = splitPts(sp, 1:2);
    planeNormal = splitTans(sp, :);  % tangent = normal to cross-section

    % Project left boundary onto plane
    projL = (leftOpen(:,1:2) - planePt) * planeNormal';
    scL = find(diff(sign(projL)) ~= 0);
    expectedIdx = round((sp-1)/N_SPLITS * nL) + 1;
    if ~isempty(scL)
        [~, best] = min(abs(scL - expectedIdx));
        seg = scL(best);
        t = -projL(seg) / (projL(seg+1) - projL(seg));
        leftSplitPts(sp,:) = leftOpen(seg,:) + t*(leftOpen(seg+1,:) - leftOpen(seg,:));
        leftSplitSeg(sp) = seg;
    else
        leftSplitPts(sp,:) = leftOpen(expectedIdx,:);
        leftSplitSeg(sp) = expectedIdx;
    end

    % Same for right boundary
    projR = (rightOpen(:,1:2) - planePt) * planeNormal';
    scR = find(diff(sign(projR)) ~= 0);
    expectedIdxR = round((sp-1)/N_SPLITS * nR) + 1;
    if ~isempty(scR)
        [~, best] = min(abs(scR - expectedIdxR));
        seg = scR(best);
        t = -projR(seg) / (projR(seg+1) - projR(seg));
        rightSplitPts(sp,:) = rightOpen(seg,:) + t*(rightOpen(seg+1,:) - rightOpen(seg,:));
        rightSplitSeg(sp) = seg;
    else
        rightSplitPts(sp,:) = rightOpen(expectedIdxR,:);
        rightSplitSeg(sp) = expectedIdxR;
    end
end
```

### Step 4: Build N Segments

Each segment runs from split point `k` to split point `k+1` (mod N):

```matlab
for s = 1:N_SPLITS
    nextS = mod(s, N_SPLITS) + 1;

    % Left boundary segment
    startSeg = leftSplitSeg(s);
    endSeg = leftSplitSeg(nextS);
    if endSeg > startSeg
        midPts = leftOpen(startSeg+1:endSeg, :);
    else
        midPts = [leftOpen(startSeg+1:end, :); leftOpen(1:endSeg, :)];
    end
    leftSegment = [leftSplitPts(s,:); midPts; leftSplitPts(nextS,:)];

    % Right boundary segment (same pattern)
    startSeg = rightSplitSeg(s);
    endSeg = rightSplitSeg(nextS);
    if endSeg > startSeg
        midPts = rightOpen(startSeg+1:endSeg, :);
    else
        midPts = [rightOpen(startSeg+1:end, :); rightOpen(1:endSeg, :)];
    end
    rightSegment = [rightSplitPts(s,:); midPts; rightSplitPts(nextS,:)];
end
```

### Step 5: Orthogonal Endpoint Enforcement (100%)

After center line synthesis, force tangent at each joint to be **fully perpendicular** to the boundary cross-section. Do NOT use the 50% blend from `synthesizeCenterLine` — that is for general lanes. Split joints are engineered to be perpendicular and need 100% enforcement:

```matlab
% For each segment's center line:
lgRaw = leftBoundaryGeometry;
rgRaw = rightBoundaryGeometry;
cg = centerLineGeometry;

% Start endpoint
cs = rgRaw(1,1:2) - lgRaw(1,1:2);
cn = norm(cs);
if cn > 1e-6
    csDir = cs / cn;
    desiredTan = [-csDir(2), csDir(1)];  % perpendicular to cross-section
    laneOverall = cg(end,1:2) - cg(1,1:2);
    if dot(desiredTan, laneOverall) < 0, desiredTan = -desiredTan; end
    origDist = norm(cg(2,1:2) - cg(1,1:2));
    cg(2,1:2) = cg(1,1:2) + desiredTan * origDist;
end

% End endpoint (mirror)
ce = rgRaw(end,1:2) - lgRaw(end,1:2);
cn = norm(ce);
if cn > 1e-6
    ceDir = ce / cn;
    desiredTan = [-ceDir(2), ceDir(1)];
    if dot(desiredTan, laneOverall) < 0, desiredTan = -desiredTan; end
    origDist = norm(cg(end,1:2) - cg(end-1,1:2));
    cg(end-1,1:2) = cg(end,1:2) - desiredTan * origDist;
end

% Force center endpoints to boundary midpoints
cg(1,:) = (lgRaw(1,:) + rgRaw(1,:)) / 2;
cg(end,:) = (lgRaw(end,:) + rgRaw(end,:)) / 2;
```

## Verification

At every joint, verify:
```matlab
crossSection = rightSplitPt - leftSplitPt;
crossDir = crossSection(1:2) / norm(crossSection(1:2));
orthDot = abs(dot(crossDir, splitTangent));
assert(orthDot < 0.01, 'Joint not orthogonal: dot=%.4f', orthDot);
```

## Track-Specific Guidance

For **track maps** (closed-loop ovals, test tracks, circuits):
- Use N=2 (default) or N=3 for longer loops
- Do **NOT** add predecessor/successor topology — let RoadRunner handle connectivity
- Do **NOT** apply artificial Z height bumps — use natural elevation from source data
- Do **NOT** add ParametricAttributes (marking references) on boundaries
- Set `GeoReference = [0, 0]` when source uses local_x/local_y coordinates

These simplifications produce correct scene builds for tracks. Topology, Z bumps, and marking attributes are appropriate for urban road networks with intersections, not for closed tracks.

## Common Failures This Prevents

| Failure | Root Cause | Fix |
|---------|-----------|-----|
| Overlap at closure joint (C→A) | Only split at 1/3, 2/3 without closure cross-section | Use same perpendicular algorithm at ALL N joints |
| Non-orthogonal joints | Used 50% tangent blend | Use 100% orthogonal enforcement at split joints |
| Boundary endpoints not on same cross-section | Split L and R independently by arc fraction | Project both onto same perpendicular plane |
| Scene build "lane intersects" warnings | Added topology + Z bumps to track | Omit topology and Z bumps for tracks |
| Center line cutting across track interior | Overall direction vector near-zero for closed loop | Use local direction detection + start-point alignment |

----

Copyright 2026 The MathWorks, Inc.

----
