function NSelect = computeNSelect(Scores, NCandidates)
%computeNSelect Compute number of features to select via score elbow detection.
%
%   NSelect = computeNSelect(Scores, NCandidates) finds the elbow in the sorted
%   consensus scores as the point of maximum BELOW-CHORD distance from the line
%   connecting the first and last points, clamped to the pool size NCandidates.
%   Only a convex curve -- one whose scores dip below that chord -- has a knee to
%   cut at; a linear decline (scores on the chord) or a concave one (scores above
%   it) has no below-chord point, so there is no elbow and the function keeps all
%   features. A signed distance is used deliberately: taking abs() would
%   manufacture a spurious "elbow" near the tail of a concave curve where none
%   exists.
%
%   Distance is measured as the VERTICAL drop from the chord down to each score,
%   not the perpendicular distance. The two are proportional by the constant
%   factor DX/LineMag (a property of the chord, identical for every point), so
%   they are maximized at the exact same feature -- the elbow is unchanged either
%   way. Vertical drop is chosen because it is what plotSelectionDecision draws to
%   illustrate the cut, so the metric and its picture are one and the same
%   quantity rather than merely proportional.
%
%   Inputs:
%     Scores      - (p,1) or (1,p) numeric, consensus scores (unsorted or sorted)
%     NCandidates - (1,1) positive integer, pool size (upper clamp)
%
%   Output:
%     NSelect - number of features to select (at least 2, at most NCandidates)

% Copyright 2026 The MathWorks, Inc.

    arguments
        Scores (:,1) double {mustBeNonempty}
        NCandidates (1,1) {mustBePositive, mustBeInteger}
    end

    Scores = sort(Scores, 'descend');
    p = numel(Scores);

    if p <= 3
        NSelect = min(p, NCandidates);
        return;
    end

    X1 = 1;       Y1 = Scores(1);
    X2 = p;       Y2 = Scores(end);
    DX = X2 - X1;
    DY = Y2 - Y1;

    if DX < eps
        NSelect = min(p, NCandidates);
        return;
    end

    % Signed vertical drop from the chord down to each score. With scores
    % sorted descending and the chord running from point 1 to point p, a point
    % that dips BELOW the chord (the convex knee we want) yields a positive
    % value; a point on the chord yields zero (linear, no knee); a point above
    % it yields a negative value (concave, no knee). Taking the max therefore
    % fires only when a genuine below-chord elbow exists. This is the same
    % quantity plotSelectionDecision draws as the vertical construction line.
    ChordY = Y1 + ((1:p)' - X1) / DX * DY;
    Distances = ChordY - Scores;

    [MaxDist, ElbowIdx] = max(Distances);

    if MaxDist < 1e-10
        % No point falls below the chord: linear or concave decline, no elbow.
        NSelect = min(p, NCandidates);
        return;
    end

    % A genuine convex elbow: it alone drives the count.
    NSelect = min(max(2, ElbowIdx), NCandidates);
end
