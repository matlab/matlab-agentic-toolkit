function [leftAlignment, rightAlignment] = detectAlignment(centerGeom, leftBndGeom, rightBndGeom)
%detectAlignment Compute boundary alignment relative to lane center geometry
%   [leftAlignment, rightAlignment] = detectAlignment(centerGeom, leftBndGeom, rightBndGeom)
%   determines whether each boundary runs in the same direction ("Forward") or
%   opposite direction ("Backward") compared to the lane center geometry.
%
%   Uses a two-step algorithm: proximity-based direction detection followed by
%   multi-sample spatial verification. A simple dot product is NOT sufficient
%   for highly curved lanes (U-turns, split half-ovals).
%
%   Inputs:
%       centerGeom   - Nx3 double, lane center polyline coordinates
%       leftBndGeom  - Mx3 double, left boundary polyline coordinates
%       rightBndGeom - Px3 double, right boundary polyline coordinates
%
%   Outputs:
%       leftAlignment  - "Forward" or "Backward"
%       rightAlignment - "Forward" or "Backward"

% Copyright 2026 The MathWorks, Inc.

    arguments
        centerGeom (:,3) double
        leftBndGeom (:,3) double
        rightBndGeom (:,3) double
    end

    % Step 1: Proximity-based alignment detection
    leftAlignment = computeProximityAlignment(centerGeom, leftBndGeom);
    rightAlignment = computeProximityAlignment(centerGeom, rightBndGeom);

    % Step 2: Multi-sample spatial verification to confirm left/right assignment
    nSamples = min(5, size(centerGeom, 1) - 1);
    if nSamples < 1
        if nargout == 0, clear leftAlignment rightAlignment; end
        return
    end

    sampleIdx = round(linspace(2, size(centerGeom, 1) - 1, nSamples));
    leftOnLeft = 0;

    for si = 1:numel(sampleIdx)
        idx = sampleIdx(si);

        % Local tangent (NOT overall direction)
        prevIdx = max(idx - 1, 1);
        nextIdx = min(idx + 1, size(centerGeom, 1));
        localTan = centerGeom(nextIdx, 1:2) - centerGeom(prevIdx, 1:2);
        tanNorm = norm(localTan);
        if tanNorm < 1e-12
            continue
        end
        localTan = localTan / tanNorm;

        % 90 deg CCW = geometric left normal
        localLeftN = [-localTan(2), localTan(1)];

        % Find closest point on left boundary to this center point
        distsL = vecnorm(leftBndGeom(:, 1:2) - centerGeom(idx, 1:2), 2, 2);
        [~, closestL] = min(distsL);
        toBndL = leftBndGeom(closestL, 1:2) - centerGeom(idx, 1:2);

        if dot(toBndL, localLeftN) > 0
            leftOnLeft = leftOnLeft + 1;
        end
    end

    % If left boundary is NOT on the geometric left at majority of samples,
    % the boundary assignments are swapped — swap alignments
    if leftOnLeft < numel(sampleIdx) / 2
        [leftAlignment, rightAlignment] = deal(rightAlignment, leftAlignment);
    end

    if nargout == 0, clear leftAlignment rightAlignment; end
end

function alignment = computeProximityAlignment(centerGeom, bndGeom)
%computeProximityAlignment Determine alignment by comparing boundary endpoints
%   to lane center start point. Boundary start closer to lane start = Forward.

    dStartToLaneStart = norm(bndGeom(1, 1:2) - centerGeom(1, 1:2));
    dEndToLaneStart = norm(bndGeom(end, 1:2) - centerGeom(1, 1:2));

    if dStartToLaneStart <= dEndToLaneStart
        alignment = "Forward";
    else
        alignment = "Backward";
    end
end
