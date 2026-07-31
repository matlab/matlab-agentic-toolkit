# Center Line Synthesis Algorithm

Computes a center line from left and right boundary geometry using **arc-length parameterization** with orthogonal endpoint enforcement. Correctly handles boundaries with different point counts and curvature distributions. Must NOT use uniform `linspace` — arc-length is required.

## Inputs
| Parameter | Type | Description |
|-----------|------|-------------|
| `leftPts` | Nx3 double | Left boundary coordinates |
| `rightPts` | Mx3 double | Right boundary coordinates |

## Output
`centerPts` — Kx3 double, center line (K = max(10, round(avgLen), N, M)).

## Algorithm

### Step 1: Density-Based Point Count
```matlab
dL = diff(leftPts); segLenL = sqrt(sum(dL.^2, 2)); cumLenL = [0; cumsum(segLenL)];
dR = diff(rightPts); segLenR = sqrt(sum(dR.^2, 2)); cumLenR = [0; cumsum(segLenR)];
avgLen = (cumLenL(end) + cumLenR(end)) / 2;
nTarget = max([10, round(avgLen), size(leftPts,1), size(rightPts,1)]);
```

**Critical:** Use `max(10, round(avgLen), nLeft, nRight)` — 1 point per meter minimum. NEVER use just `max(nLeft, nRight)` which gives too few points for short lanes with sparse nodes.

### Step 2: Arc-Length Pchip Resampling
```matlab
tNormL = cumLenL / cumLenL(end);
tTarget = linspace(0, 1, nTarget)';
leftRes = zeros(nTarget, 3);
for dim = 1:3
    leftRes(:,dim) = interp1(tNormL, leftPts(:,dim), tTarget, 'pchip');
end

tNormR = cumLenR / cumLenR(end);
rightRes = zeros(nTarget, 3);
for dim = 1:3
    rightRes(:,dim) = interp1(tNormR, rightPts(:,dim), tTarget, 'pchip');
end
```

### Step 3: Midpoint Averaging
```matlab
centerPts = (leftRes + rightRes) / 2;
```

### Step 4: Orthogonal Endpoint Enforcement

**Skip for closed-loop lanes** where `norm(centerPts(1,:) - centerPts(end,:)) < 1.0`. For all others with >= 4 points, enforce perpendicular start/end via 50% tangent blending:

```matlab
isClosedLoop = norm(centerPts(1,:) - centerPts(end,:)) < 1.0;
if ~isClosedLoop && nTarget >= 4
    centerPts(1,:) = (leftRes(1,:) + rightRes(1,:)) / 2;
    centerPts(end,:) = (leftRes(end,:) + rightRes(end,:)) / 2;
    laneOverall = centerPts(end,1:2) - centerPts(1,1:2);

    % Start tangent: blend 50% toward perpendicular-to-cross-lane
    crossStart = rightRes(1,:) - leftRes(1,:);
    crossNorm = norm(crossStart(1:2));
    if crossNorm > 1e-6
        crossStart2D = crossStart(1:2) / crossNorm;
        desiredTan = [-crossStart2D(2), crossStart2D(1)];
        if dot(desiredTan, laneOverall) < 0, desiredTan = -desiredTan; end
        origVec = centerPts(2,:) - centerPts(1,:);
        origDist = norm(origVec);
        if origDist > 1e-6
            origDir2D = origVec(1:2) / norm(origVec(1:2));
            blended2D = 0.5*origDir2D + 0.5*desiredTan;
            blended2D = blended2D / norm(blended2D);
            centerPts(2,:) = centerPts(1,:) + [blended2D*origDist, origVec(3)];
        end
    end

    % End tangent: same blend (mirror)
    crossEnd = rightRes(end,:) - leftRes(end,:);
    crossNorm = norm(crossEnd(1:2));
    if crossNorm > 1e-6
        crossEnd2D = crossEnd(1:2) / crossNorm;
        desiredTan = [-crossEnd2D(2), crossEnd2D(1)];
        if dot(desiredTan, laneOverall) < 0, desiredTan = -desiredTan; end
        origVec = centerPts(end,:) - centerPts(end-1,:);
        origDist = norm(origVec);
        if origDist > 1e-6
            origDir2D = origVec(1:2) / norm(origVec(1:2));
            blended2D = 0.5*origDir2D + 0.5*desiredTan;
            blended2D = blended2D / norm(blended2D);
            centerPts(end-1,:) = centerPts(end,:) - [blended2D*origDist, origVec(3)];
        end
    end
end
```

**Why tangent blending?** Simple midpoint placement (Step 3) creates correct endpoint positions but the tangent at the endpoint may not be perpendicular to the lane cross-section. The 50% blend toward the perpendicular direction ensures smooth, orthogonal connections with successor/predecessor lanes.

**NEVER use simple `min(nPts)` truncation** — this loses curve information and produces non-smooth center lines.

## Common Failures This Prevents
| Failure Mode | Root Cause |
|---|---|
| Center line overshoots boundary at curved ends | Simple truncation lost curve info |
| Grass/gap at lane connections | Non-orthogonal endpoint misaligns with successor |
| Center line zigzags at mismatched boundaries | Linear interp instead of pchip |
| Lane has fewer points than its longest boundary | Used min(nPts) instead of density-based |

## Example
```matlab
leftPts  = [0 1 0; 50 1.5 0; 100 1 0];
rightPts = [0 -1 0; 30 -1.2 0; 60 -1.5 0; 100 -1 0];
% Apply Steps 1-4 above to compute centerPts from leftPts, rightPts
```

----

Copyright 2026 The MathWorks, Inc.
