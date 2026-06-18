% Copyright 2026 The MathWorks, Inc.
function [idx, weights] = findClosest(queryPts, refPts, k, opts)
%FINDCLOSEST  Find the closest reference points to each query point.
%
% Inputs:
%   queryPts  - N-by-D matrix of query coordinates
%   refPts    - M-by-D matrix of reference coordinates
%   k         - Number of closest points to return (default: 3)
%   opts      - Optional name-value arguments:
%               'Metric' - Distance metric ("euclidean" or "cityblock"), default "euclidean"
%               'Normalize' - Whether to normalize distances (true/false), default false
%
% Outputs:
%   idx       - N-by-K indices of closest reference points
%   weights   - N-by-K inverse-distance weights
%
% Example:
%   pts = rand(100,3);
%   refs = rand(50,3);
%   [i, w] = findClosest(pts, refs, 5);
%
% See also: knnsearch, pdist2, dsearchn.

    arguments
        queryPts (:,:) double
        refPts (:,:) double
        k (1,1) double = 3
        opts.Metric (1,1) string = "euclidean"
        opts.Normalize (1,1) logical = false
    end
    dists = pdist2(queryPts, refPts, opts.Metric);
    [sortedDists, sortedIdx] = sort(dists, 2);
    idx = sortedIdx(:, 1:k);
    weights = 1 ./ sortedDists(:, 1:k);
    if opts.Normalize
        weights = weights ./ sum(weights, 2);
    end
end
