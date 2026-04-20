function results = batchProcess(dataCell)
%batchProcess Analyze each dataset in a cell array and return scores.
%   results = batchProcess(dataCell) processes each cell element through
%   analyzeOne and returns a vector of scores.

    n = numel(dataCell);
    results = zeros(n, 1);
    for k = 1:n
        results(k) = analyzeOne(dataCell{k});
    end
end

function score = analyzeOne(data)
%analyzeOne Compute a robust score from a single dataset.
%   Removes non-finite values, computes quartiles, and returns
%   median / IQR as a dispersion-normalized score.

    cleaned = data(isfinite(data));
    sorted = sort(cleaned);
    q1 = sorted(round(0.25 * length(sorted)));
    q3 = sorted(round(0.75 * length(sorted)));
    iqr = q3 - q1;
    score = median(cleaned) / iqr;
end
% Copyright 2026 The MathWorks, Inc.
