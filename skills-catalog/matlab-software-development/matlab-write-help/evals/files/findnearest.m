% Copyright 2026 The MathWorks, Inc.
function [idx, dist] = findnearest(points, target, k)
%needs help
    if nargin < 3
        k = 1;
    end
    diffs = points - target;
    dists = sqrt(sum(diffs.^2, 2));
    [dist, idx] = mink(dists, k);
end
