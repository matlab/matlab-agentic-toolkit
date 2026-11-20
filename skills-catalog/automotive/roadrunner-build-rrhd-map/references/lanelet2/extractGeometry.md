# Extract Geometry — Center Lines from Boundary Pairs

## Description
Synthesizes lane center lines from left/right boundary geometry. Way geometry comes from `geomMap`, built once by [coordinates.md](coordinates.md) (origin resolution, projection, source elevation).

## Inputs
| Parameter | Type | Description |
|-----------|------|-------------|
| `ways` | containers.Map | Parsed ways with nodeRefs |
| `nodes` | containers.Map | Parsed nodes with x, y, z |
| `geoRef` | [lat, lon] | Reference point for ENU transform |

## Output
Per-lanelet: `leftGeom`, `rightGeom`, `centerGeom` — all Nx3 double [x, y, z] in ENU meters.

## Center Line Synthesis

1. **Orient copies, not boundaries.** Compute the lanelet's alignment with Invariant 3 of the conversion pipeline (dp −0.3 threshold, proximity, inverted-lanelet check). Flip *copies* of the boundaries whose alignment is `Backward` so both run in the travel direction; the stored boundary geometry stays untouched.
2. **Synthesize** with [synthesizeCenterLine.md](../authoring/synthesizeCenterLine.md): density-based point count `max(10, round(avgLen), nLeft, nRight)`, arc-length `pchip` resampling, midpoint averaging, orthogonal endpoints (skipped for closed loops).
3. **Guard degenerate boundaries** first (below).

## Verification Criteria
After synthesis, check orthogonality at endpoints:
```matlab
% dot(cross-lane direction, tangent) should be near 0
crossStart = rightRes(1,:) - leftRes(1,:);   % names from synthesizeCenterLine.md
tanStart = centerPts(2,:) - centerPts(1,:);
orthCheck = dot(crossStart(1:2)/norm(crossStart(1:2)), tanStart(1:2)/norm(tanStart(1:2)));
% |orthCheck| < 0.05 is acceptable
```

## MANDATORY: Guard for Degenerate Boundaries

Before calling `interp1`, verify boundaries have non-zero arc length. Closed-loop rotation or duplicate removal can produce zero-length boundaries that cause `interp1` to error with "X and V must be of the same length" or "sample points must be finite."

```matlab
% Remove consecutive duplicate points BEFORE resampling
keepL = [true; vecnorm(diff(leftGeom),2,2) > 1e-6];
leftGeom = leftGeom(keepL,:);
keepR = [true; vecnorm(diff(rightGeom),2,2) > 1e-6];
rightGeom = rightGeom(keepR,:);

% Guard: skip interp1 if boundary has < 2 points or zero length
sL = vecnorm(diff(leftGeom),2,2); cumLenL = [0; cumsum(sL)];
if size(leftGeom,1) < 2 || cumLenL(end) < 1e-4
    % Fallback: use simple midpoint for center line
    centerGeom = [(leftGeom(1,:)+rightGeom(1,:))/2; (leftGeom(end,:)+rightGeom(end,:))/2];
    continue;  % skip to next lanelet
end

% Ensure strictly increasing parameterization (handles floating-point ties)
tNormL = cumLenL / cumLenL(end);
for k = 2:numel(tNormL)
    if tNormL(k) <= tNormL(k-1), tNormL(k) = tNormL(k-1) + 1e-10; end
end
```

## Common Failures This Prevents
| Failure Mode | Root Cause |
|---|---|
| Center line overshoots boundary at curved ends | Simple truncation lost curve info |
| Grass/gap at lane connections | Non-orthogonal endpoint misaligns with successor |
| Center line zigzags at mismatched boundaries | Linear interp instead of pchip |
| Lane_N has too few points (pchip deviates from the true midpoint) | Used min(nPts) or max(nPts) instead of the density rule `max(10, round(avgLen), nLeft, nRight)` |
| `interp1` "X and V must be of same length" | Zero-length boundary after closed-loop rotation |
| `interp1` "sample points must be finite" | Duplicate points causing `0/0 = NaN` in normalization |

----

Copyright 2026 The MathWorks, Inc.

----
