function result = binData(values, edges)
%binData Compute first and last value in each bin defined by edges.
%   result = binData(values, edges) returns an nBins-by-2 matrix where
%   each row contains the first and last value falling in that bin.

    nBins = length(edges) - 1;
    result = zeros(nBins, 2);
    for k = 1:nBins
        mask = values >= edges(k) & values < edges(k+1);
        binValues = values(mask);
        result(k, 1) = binValues(1);
        result(k, 2) = binValues(end);
    end
end
% Copyright 2026 The MathWorks, Inc.
