function KeepIdx = stratifiedDownsampleRows(Response, MaxRows)
%stratifiedDownsampleRows Row indices capping a table at MaxRows, class-balanced.
%
%   KeepIdx = stratifiedDownsampleRows(Response, MaxRows) returns a sorted column
%   vector of row indices that trims a table down to at most MaxRows while
%   preserving class proportions. When numel(Response) <= MaxRows every row is
%   kept (KeepIdx = (1:n)'). This bounds the cost of a stability read on large
%   data: the read draws M subsamples and re-runs selection (or generation) on
%   each, so the per-resample table size -- not the full dataset size -- sets the
%   cost. Capping once here keeps every subsample small without the caller
%   re-implementing a stratified trim.
%
%   The cap is applied ONCE, up front, before any resampling; the M subsamples
%   are then drawn from the capped set (stratifiedSubsampleIndices), so the whole
%   stability read operates on <= MaxRows rows.
%
%   STRATIFICATION. For a categorical / logical / string response the trim keeps
%   round(MaxRows * classShare) rows per class (via cvpartition Holdout), so the
%   imbalance ratio is preserved -- essential, since stability on imbalanced data
%   is exactly where an accidental class starve would corrupt the read. A
%   continuous (regression) response is trimmed by a plain random draw.
%
%   Inputs:
%     Response - (n,1) response vector; its TYPE decides stratification
%     MaxRows  - (1,1) positive integer row cap (default 3000)
%
%   Output:
%     KeepIdx  - (:,1) sorted row indices to keep (all rows when n <= MaxRows)

% Copyright 2026 The MathWorks, Inc.

    arguments
        Response (:,1) {mustBeVector}
        MaxRows (1,1) double {mustBePositive, mustBeInteger} = 3000
    end

    n = numel(Response);
    if n <= MaxRows
        KeepIdx = (1:n)';
        return;
    end

    Stratify = iscategorical(Response) || islogical(Response) ...
        || isstring(Response) || iscellstr(Response);
    if Stratify
        % Keep a stratified MaxRows/n fraction: cvpartition's training side
        % preserves class proportions.
        Part = cvpartition(Response, Holdout = 1 - MaxRows / n);
        KeepIdx = find(training(Part));
    else
        KeepIdx = sort(randperm(n, MaxRows))';
    end
end
