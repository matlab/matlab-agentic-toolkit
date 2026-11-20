# Split Closed-Loop Geometry

Inline algorithm — generate it in the conversion script (there is no packaged function).

## Description
Detects closed-loop geometry (start point ≈ end point) and splits at the midpoint into two open segments. **RoadRunner cannot render self-closed roads** — this is a required workaround.

## Inputs
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pts` | Nx3 double | (required) | [x y z] coordinates |
| `Tolerance` | double | `1.0` | Max distance (meters) between first/last point to consider closed |

## Outputs
- `ptsA` — first half (points 1..mid). If not closed, returns original `pts`
- `ptsB` — second half (points mid..end), shares start with ptsA's end. If not closed, returns `[]`
- `wasSplit` — logical, true if geometry was closed and split

## Algorithm
```matlab
isClosed = (n >= 4) && (norm(pts(1,:) - pts(end,:)) < tol) && (sum(vecnorm(diff(pts), 2, 2)) > 10);
if ~isClosed, return pts unchanged; end

ptsOpen = pts(1:end-1, :);     % remove closing duplicate
mid = ceil(nOpen / 2);
ptsA = ptsOpen(1:mid, :);
ptsB = ptsOpen(mid:end, :);    % overlap at split point
```

## Example
```matlab
pts = [0 0 0; 10 0 0; 10 10 0; 0 10 0; 0 0 0];  % closed square
% Apply the algorithm above inline: closed (start == end, length 40 m > 10 m) -> split at the midpoint
% ptsA = [0 0 0; 10 0 0], ptsB = [10 0 0; 10 10 0; 0 10 0]
```

## Closed-Loop Boundary Handling (pre-requisite for center line synthesis)

When BOTH left and right boundaries are closed loops, standard direction detection (`dot(leftOverall, rightOverall)`) fails because the overall direction vector is near-zero. This causes incorrect flips that produce center lines cutting across the track interior.

**Detection:** A boundary is a closed loop if `norm(geom(1,:) - geom(end,:)) < 1.0` m **and** its length is > 10 m. Sub-meter lanelets also have start ≈ end but are not loops.

**MANDATORY: Handle closed-loop boundaries BEFORE direction detection:**

```matlab
leftOverall = leftGeom(end,:) - leftGeom(1,:);
rightOverall = rightGeom(end,:) - rightGeom(1,:);

% Closed-loop detection: use LOCAL direction instead of overall
if norm(leftOverall(1:2)) < 1.0 || norm(rightOverall(1:2)) < 1.0
    % Use direction of first few segments
    lDir = leftGeom(min(5,size(leftGeom,1)),:) - leftGeom(1,:);
    % Find closest point on right boundary to left start
    dists = vecnorm(rightGeom(:,1:2) - leftGeom(1,1:2), 2, 2);
    [~, rStart] = min(dists);
    rEnd = min(rStart+4, size(rightGeom,1));
    rDir = rightGeom(rEnd,:) - rightGeom(rStart,:);
    needFlip = dot(lDir(1:2), rDir(1:2)) < 0;
else
    % Standard: use overall direction
    needFlip = dot(leftOverall(1:2), rightOverall(1:2)) < 0;
end
if needFlip, rightGeom = flipud(rightGeom); end

% For closed-loop boundaries, align start points (rotate right to match left)
leftStartGap = norm(leftGeom(1,1:2) - leftGeom(end,1:2));
rightStartGap = norm(rightGeom(1,1:2) - rightGeom(end,1:2));
if leftStartGap < 1.0 && rightStartGap < 1.0
    dists = vecnorm(rightGeom(:,1:2) - leftGeom(1,1:2), 2, 2);
    [~, rStart] = min(dists);
    if rStart > 1
        rightGeom = [rightGeom(rStart:end,:); rightGeom(2:rStart,:)];
    end
end
```

**Why start-point alignment?** Closed-loop boundaries have no natural "start". If left boundary starts at the north end of the oval and right boundary starts at the south end, averaging them produces a center line that zigzags. Rotating the right boundary so its start is closest to the left boundary's start ensures point-by-point averaging produces a valid center line.

**After handling closed loops:** Skip orthogonal endpoint enforcement for closed-loop center lines (`norm(centerGeom(1,:) - centerGeom(end,:)) < 1.0`) since there are no meaningful endpoints.

----

Copyright 2026 The MathWorks, Inc.

----
