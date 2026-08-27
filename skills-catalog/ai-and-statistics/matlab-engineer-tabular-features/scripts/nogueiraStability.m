function [Stability, Info] = nogueiraStability(Z)
%nogueiraStability Chance-corrected selection-stability index (Nogueira 2018).
%
%   [Stability, Info] = nogueiraStability(Z) measures how consistently a feature
%   selector picks the same features across repeated runs (e.g. k folds). Z is a
%   K-by-p binary matrix over a FIXED shared feature universe: Z(i,j) = 1 if
%   feature j was selected in run i, else 0. K is the number of runs (folds),
%   p the number of candidate features.
%
%   Unlike Kuncheva's index or a plain Jaccard, this estimator does NOT require
%   an equal number of features selected per run, so it handles the variable
%   per-fold subset size that elbow-cut selection (computeNSelect) produces. It
%   scores selection DECISIONS, not feature VALUES, so it is feature-type
%   agnostic (numeric/categorical/continuous all work).
%
%   Definition (see Reference below, eq. 2):
%     Let p_f = mean(Z(:,f)) be feature f's selection frequency, and
%     s_f^2 = (K/(K-1)) p_f (1 - p_f) its unbiased Bernoulli sample variance.
%     Let kbar = mean row-sum (average subset size). Then
%       Stability = 1 - ( (1/p) sum_f s_f^2 ) / ( (kbar/p)(1 - kbar/p) ).
%   The denominator is the variance expected if the same number of features were
%   chosen uniformly at random, so the index is chance-corrected: ~0 means
%   selections are no more consistent than random, 1 means identical every run.
%   It can be slightly negative (below-chance agreement); that is reported
%   honestly rather than clamped.
%
%   Inputs:
%     Z - (K,p) binary (0/1) selection matrix; K >= 2 runs, p >= 1 features
%
%   Outputs:
%     Stability - (1,1) double, the stability index (typically in [0,1], may be
%                 slightly negative; 1 = perfectly stable)
%     Info      - struct with fields:
%                   .SelectionFrequency - (1,p) per-feature selection frequency
%                                         (the "consensus core" companion read)
%                   .MeanSubsetSize     - (1,1) average number selected per run
%                   .NumRuns            - (1,1) K
%                   .NumFeatures        - (1,1) p
%
%   Reference:
%     Nogueira S, Sechidis K, Brown G. "On the Stability of Feature Selection
%     Algorithms." Journal of Machine Learning Research, 18(174):1-54, 2018.
%     https://jmlr.org/papers/v18/17-514.html  (estimator: eq. 2, Sec. 2)

% Copyright 2026 The MathWorks, Inc.

    arguments
        Z {mustBeNumericOrLogical, mustBeReal}
    end

    Z = double(Z);
    if ~ismatrix(Z)
        error('nogueiraStability:notMatrix', 'Z must be a K-by-p matrix.');
    end
    if ~all(ismember(Z(:), [0 1]))
        error('nogueiraStability:notBinary', 'Z must contain only 0 and 1.');
    end

    [K, p] = size(Z);
    if K < 2
        error('nogueiraStability:tooFewRuns', ...
            'Stability needs at least 2 runs (rows); got %d.', K);
    end
    if p < 1
        error('nogueiraStability:noFeatures', 'Z must have at least one column.');
    end

    SelectionFrequency = mean(Z, 1);                 % p_f, one per feature (1,p)
    MeanSubsetSize = mean(sum(Z, 2));                % kbar, average subset size

    % Unbiased per-feature Bernoulli variance, averaged over features.
    UnbiasedVar = (K / (K - 1)) .* SelectionFrequency .* (1 - SelectionFrequency);
    MeanVar = mean(UnbiasedVar);

    % Chance-level variance from the average subset size.
    ExpectedFrac = MeanSubsetSize / p;
    NullVar = ExpectedFrac * (1 - ExpectedFrac);

    if NullVar == 0
        % Every run selected all features (or none): selections are trivially
        % identical, so stability is perfect by convention.
        Stability = 1;
    else
        Stability = 1 - MeanVar / NullVar;
    end

    Info = struct( ...
        SelectionFrequency = SelectionFrequency, ...
        MeanSubsetSize = MeanSubsetSize, ...
        NumRuns = K, ...
        NumFeatures = p);
end
