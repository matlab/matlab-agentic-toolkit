function [NumBins, Info] = chooseNumBins(X, ContinuousMask, NEff, Options)
%chooseNumBins Data-driven bin count for fscchi2 / fsrftest continuous binning.
%
%   [NumBins, Info] = chooseNumBins(X, ContinuousMask, NEff) returns a single
%   positive-integer NumBins to pass to fscchi2 / fsrftest, chosen from the data
%   rather than left at the fixed default of 10. Those filters bin ONLY the
%   continuous predictors before the chi-square / F-test, so the bin count trades
%   resolution (more bins) against contingency-cell reliability (fewer bins);
%   a fixed 10 ignores both the sample size and the spread of the columns.
%
%   Method. For each continuous predictor we compute the Freedman-Diaconis bin
%   count -- range / (2 * IQR * n^(-1/3)) -- which is IQR-based and therefore
%   robust to the skew and outliers a gencfeatures pool tends to produce (unlike
%   Sturges' rule, which assumes near-normal data, or Scott's rule, whose use of
%   the standard deviation is inflated by outliers). We take the MEDIAN of those
%   per-column counts (robust to a few wild columns), then apply two guards:
%     * a validity cap floor(NEff / MinPerCell) so the sparsest cells of the
%       (bin x class) contingency table stay populated enough for the chi-square
%       approximation to hold (Cochran's rule: expected cell count >= 5). The
%       caller passes NEff already reduced to the constraint that binds -- the
%       minority-class count for classification (the fewest-observations row of
%       the table, whose expected cell count under independence is ~NEff/NumBins)
%       and the row count for regression -- so the per-cell cap is exactly
%       floor(NEff / MinPerCell) with MinPerCell = 5, no separate class factor.
%     * a floor of MinBins (default 5) so the test keeps some resolution.
%   Columns with zero IQR (constant / near-constant) contribute no FD estimate.
%
%   Inputs:
%     X              - table or numeric matrix of predictors
%     ContinuousMask - (1,p) logical, true for continuous predictors to bin
%                      (categoricals are excluded; they are not binned)
%     NEff           - (1,1) effective sample size, ALREADY reduced to the binding
%                      constraint: minority-class count for classification, row
%                      count for regression
%     Options.MinPerCell - (1,1) target minimum expected count in the sparsest
%                      contingency cell (default 5, per Cochran's rule)
%     Options.MinBins    - (1,1) lower floor on the returned count (default 5)
%
%   Outputs:
%     NumBins - (1,1) positive integer bin count for fscchi2 / fsrftest
%     Info    - struct with fields:
%                 .FDBins       - (1,:) per-column Freedman-Diaconis counts used
%                 .MedianFDBins - (1,1) median before guards
%                 .ValidityCap  - (1,1) floor(NEff / MinPerCell)
%                 .Reasoning    - (1,1) string explanation
%
%   References:
%     Freedman D, Diaconis P. "On the histogram as a density estimator: L2
%     theory." Zeitschrift fur Wahrscheinlichkeitstheorie und verwandte Gebiete,
%     57(4):453-476, 1981. (bin width = 2 * IQR * n^(-1/3))
%     Cochran WG. "Some methods for strengthening the common chi-square tests."
%     Biometrics 10(4):417-451, 1954. (expected cell count >= 5 for validity)

% Copyright 2026 The MathWorks, Inc.

    arguments
        X
        ContinuousMask (1,:) logical
        NEff (1,1) double {mustBePositive}
        Options.MinPerCell (1,1) double {mustBePositive} = 5
        Options.MinBins (1,1) double {mustBePositive, mustBeInteger} = 5
    end

    if istable(X)
        X = X{:, ContinuousMask};
    else
        X = X(:, ContinuousMask);
    end
    X = double(X);

    ValidityCap = max(Options.MinBins, floor(NEff / Options.MinPerCell));

    % Per-column Freedman-Diaconis bin counts over the continuous predictors.
    n = size(X, 1);
    FDBins = double.empty(1, 0);
    for c = 1:size(X, 2)
        Col = X(~isnan(X(:, c)), c);
        if numel(Col) < 2
            continue;
        end
        Iqr = iqr(Col);
        Rng = max(Col) - min(Col);
        if Iqr <= 0 || Rng <= 0
            continue;   % constant / near-constant column contributes no estimate
        end
        Width = 2 * Iqr * n^(-1/3);
        FDBins(end+1) = max(1, ceil(Rng / Width)); %#ok<AGROW>
    end

    if isempty(FDBins)
        % No informative continuous column (all categorical or constant): the
        % bin count is irrelevant to the ranking, so return the floor.
        MedianFDBins = Options.MinBins;
    else
        MedianFDBins = median(FDBins);
    end

    NumBins = max(Options.MinBins, min(round(MedianFDBins), ValidityCap));

    Info = struct( ...
        FDBins = FDBins, ...
        MedianFDBins = MedianFDBins, ...
        ValidityCap = ValidityCap, ...
        Reasoning = sprintf(...
            "Freedman-Diaconis median=%.0f over %d continuous col(s), " + ...
            "capped to [%d, %d] (NEff=%d, >=%d/cell) -> %d bins", ...
            MedianFDBins, numel(FDBins), Options.MinBins, ValidityCap, ...
            NEff, Options.MinPerCell, NumBins));
end
