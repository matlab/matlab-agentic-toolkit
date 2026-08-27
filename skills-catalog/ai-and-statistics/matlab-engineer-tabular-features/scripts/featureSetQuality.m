function Result = featureSetQuality(OriginalData, T, RowIdx, ResponseVar, OriginalPredVars, EngineeredPredVars, ProblemType, Options)
%featureSetQuality Model-free representation-quality panel: engineered vs original.
%
%   Result = featureSetQuality(OriginalData, T, RowIdx, ResponseVar, ...
%       OriginalPredVars, EngineeredPredVars, ProblemType) scores the engineered
%   feature set against the original one along three model-agnostic dimensions,
%   with NO trained model. It complements baselineComparison (which measures
%   predictive lift through a model): a representation can be judged on relevance,
%   redundancy, and compactness independently of any single predictor's bias.
%   The verdicts are diagnostic only — this never gates the pipeline.
%
%   The comparison basis is the raw-original predictor set vs. the SELECTED
%   engineered set, so pruning is reflected in the engineered side. Because it
%   fits no model and grades nothing for generalization, there is no leakage
%   exposure — so the headline read describes the SHIPPED set on ALL working rows
%   (the refit-on-all-working-data artifact, deliver.md §2), not a train slice.
%   RowIdx names the rows to compute on: all working rows for the shipped read,
%   or a single fold's train rows for the per-fold cross-validated stability band
%   (assessKFold). Binning edges are taken from those same rows.
%
%   The three dimensions:
%     Relevance   - marginal mutual information (MI, nats) of each feature with
%                   the response. Two k-free reads:
%                     .Max          strongest single feature (peak signal).
%                                   A rise raw->eng means FE concentrated signal
%                                   into an accessible axis (e.g. XOR -> product);
%                                   a drop means FE destroyed the best signal.
%                     .NumRelevant  count of features with MI above
%                                   RelevanceThreshold (breadth — how many carry
%                                   real signal).
%     Redundancy  - pairwise MI (nats) across feature pairs, from the off-diagonal
%                   of the feature-by-feature MI matrix. Two reads:
%                     .MeanPairwiseMI  set-wide duplication level (mean over pairs).
%                     .MaxPairwiseMI   the single worst near-duplicate pair -- a low
%                                      mean can hide two features that are near-
%                                      copies, so the max flags a concrete cut
%                                      candidate the mean misses.
%                   Both span numeric-numeric, categorical-categorical AND numeric-
%                   categorical pairs -- so a numeric feature that duplicates a
%                   categorical one is visible. Lower is better (less duplicated info).
%     Compactness - feature count and effective dimensionality (participation
%                   ratio of the numeric correlation-matrix eigenvalues). Lower
%                   effective dim on a comparable count means a tighter
%                   representation.
%
%   MI (both the relevance and redundancy reads) is estimated by
%   mutualInformationPanel, which bins the predictors and response internally the
%   same way fscmrmr / fsrmrmr do and, from that single estimator, returns both
%   the feature-vs-response MI (relevance) and the feature-vs-feature MI matrix
%   (redundancy) -- so both reads stay consistent with the MRMR selection voter.
%
%   Accepts table input only (categorical handling requires named columns).

% Copyright 2026 The MathWorks, Inc.

    arguments
        OriginalData table
        T table
        RowIdx (:,1) {mustBeNumeric}
        ResponseVar (1,1) string
        OriginalPredVars
        EngineeredPredVars
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Options.RelevanceThreshold (1,1) double {mustBeNonnegative} = 0.02
        Options.Verbose (1,1) logical = true
    end

    OriginalPredVars = string(OriginalPredVars);
    EngineeredPredVars = string(EngineeredPredVars);

    Y = T.(ResponseVar)(RowIdx);

    Orig = scoreSet(OriginalData, OriginalPredVars, RowIdx, Y, ProblemType, Options.RelevanceThreshold);
    Eng = scoreSet(T, EngineeredPredVars, RowIdx, Y, ProblemType, Options.RelevanceThreshold);

    Result = struct();
    Result.Relevance = struct( ...
        MaxOriginal = Orig.MaxRelevance, MaxEngineered = Eng.MaxRelevance, ...
        NumRelevantOriginal = Orig.NumRelevant, NumRelevantEngineered = Eng.NumRelevant, ...
        Threshold = Options.RelevanceThreshold);
    Result.Redundancy = struct( ...
        MeanPairwiseMIOriginal = Orig.Redundancy, ...
        MeanPairwiseMIEngineered = Eng.Redundancy, ...
        MaxPairwiseMIOriginal = Orig.MaxRedundancy, ...
        MaxPairwiseMIEngineered = Eng.MaxRedundancy);
    Result.Compactness = struct( ...
        NumFeaturesOriginal = Orig.NumFeatures, NumFeaturesEngineered = Eng.NumFeatures, ...
        EffectiveDimOriginal = Orig.EffectiveDim, EffectiveDimEngineered = Eng.EffectiveDim);
    Result.Verdicts = buildVerdicts(Result);

    if Options.Verbose
        printPanel(Result);
    end
end


function S = scoreSet(Data, PredVars, RowIdx, Y, ProblemType, Threshold)
%scoreSet Compute all three dimensions for one predictor set.
    [NumericVars, ~] = splitByType(Data, PredVars);
    S.NumFeatures = numel(PredVars);

    if isempty(PredVars)
        S.MaxRelevance = NaN;
        S.NumRelevant = 0;
        S.Redundancy = NaN;
        S.MaxRedundancy = NaN;
        S.EffectiveDim = effectiveDimensionality(Data, NumericVars, RowIdx);
        return
    end

    % mutualInformationPanel bins the predictor block and the response
    % internally (numeric columns adaptively binned, categoricals re-indexed;
    % missing handled as code 0) exactly as fscmrmr / fsrmrmr do, then from that
    % one estimator returns BOTH the feature-vs-feature MI matrix (Ix,
    % redundancy) and the feature-vs-response MI (Iy, relevance). Column order
    % follows PredVars.
    [Ix, Iy] = mutualInformationPanel(Data(RowIdx, PredVars), Y, ProblemType);

    % --- Relevance: marginal MI per feature vs the response -------------------
    S.MaxRelevance = max(Iy);
    S.NumRelevant = sum(Iy >= Threshold);

    % --- Redundancy: pairwise feature-vs-feature MI ---------------------------
    % Ix(i,j) = MI(i;j). The MEAN off-diagonal is the set-wide duplication level;
    % the MAX off-diagonal is the single worst near-duplicate pair -- a low mean
    % can hide two features that are near-copies, so the max is the actionable
    % "is any pair redundant?" read.
    S.Redundancy = meanOffDiagonal(Ix);
    S.MaxRedundancy = maxOffDiagonal(Ix);

    % --- Compactness: effective dimensionality of the numeric block -----------
    S.EffectiveDim = effectiveDimensionality(Data, NumericVars, RowIdx);
end


function M = meanOffDiagonal(Ix)
%meanOffDiagonal Mean of the strictly upper-triangular MI entries; NaN with < 2
%   features (no pair to measure).
    P = size(Ix, 1);
    if P < 2
        M = NaN;
        return
    end
    Mask = triu(true(P), 1);
    M = mean(Ix(Mask), "omitnan");
end


function M = maxOffDiagonal(Ix)
%maxOffDiagonal Largest strictly upper-triangular MI entry (the worst near-
%   duplicate pair); NaN with < 2 features (no pair to measure).
    P = size(Ix, 1);
    if P < 2
        M = NaN;
        return
    end
    Mask = triu(true(P), 1);
    M = max(Ix(Mask), [], "omitnan");
end


function [NumericVars, CategoricalVars] = splitByType(Data, PredVars)
%splitByType Partition predictors into numeric and categorical-like columns.
    IsNumeric = false(size(PredVars));
    for i = 1:numel(PredVars)
        IsNumeric(i) = isnumeric(Data.(PredVars(i)));
    end
    NumericVars = PredVars(IsNumeric);
    CategoricalVars = PredVars(~IsNumeric);
end


function EffDim = effectiveDimensionality(Data, NumericVars, RowIdx)
%effectiveDimensionality Participation ratio (sum L)^2 / sum(L^2) of the numeric
%   correlation-matrix eigenvalues. Ranges from 1 (all features collinear) to the
%   feature count (all orthogonal). NaN with no numeric features; the count
%   itself when a single numeric feature exists.
    if isempty(NumericVars)
        EffDim = NaN;
        return
    end
    if isscalar(NumericVars)
        EffDim = 1;
        return
    end
    X = zeros(numel(RowIdx), numel(NumericVars));
    for i = 1:numel(NumericVars)
        X(:, i) = double(Data.(NumericVars(i))(RowIdx));
    end
    % Pearson (a linear correlation matrix): the participation ratio reads the
    % eigenvalues of that matrix, so the variance-based (PSD) Pearson matrix is
    % the right operand.
    R = corr(X, Rows="pairwise");
    R(isnan(R)) = 0;
    R(1:size(R,1)+1:end) = 1;           % restore unit diagonal after NaN scrub
    Lambda = eig(R);
    Lambda = Lambda(Lambda > 0);
    if isempty(Lambda)
        EffDim = NaN;
    else
        EffDim = sum(Lambda)^2 / sum(Lambda.^2);
    end
end


function Verdicts = buildVerdicts(Result)
%buildVerdicts Directional plain-English reads per dimension.
    Verdicts = struct();

    Rel = Result.Relevance;
    if isnan(Rel.MaxEngineered) || isnan(Rel.MaxOriginal)
        Verdicts.Relevance = "Relevance: not assessable (a feature set has no usable predictors).";
    elseif Rel.MaxEngineered > Rel.MaxOriginal + 1e-6
        Verdicts.Relevance = sprintf("Relevance: engineering STRENGTHENED the peak signal (max MI %.3f -> %.3f); %d vs %d features above threshold.", ...
            Rel.MaxOriginal, Rel.MaxEngineered, Rel.NumRelevantEngineered, Rel.NumRelevantOriginal);
    elseif Rel.MaxEngineered < Rel.MaxOriginal - 1e-6
        Verdicts.Relevance = sprintf("Relevance: WARNING — engineering weakened the peak signal (max MI %.3f -> %.3f). FE may have destroyed the strongest single feature.", ...
            Rel.MaxOriginal, Rel.MaxEngineered);
    else
        Verdicts.Relevance = sprintf("Relevance: peak signal preserved (max MI ~%.3f); %d vs %d features above threshold.", ...
            Rel.MaxEngineered, Rel.NumRelevantEngineered, Rel.NumRelevantOriginal);
    end

    Red = Result.Redundancy;
    Verdicts.Redundancy = redundancyVerdict(Red);

    Comp = Result.Compactness;
    Verdicts.Compactness = sprintf("Compactness: %d -> %d features; effective dimensionality %s -> %s.", ...
        Comp.NumFeaturesOriginal, Comp.NumFeaturesEngineered, ...
        fmtNum(Comp.EffectiveDimOriginal), fmtNum(Comp.EffectiveDimEngineered));
end


function V = redundancyVerdict(Red)
%redundancyVerdict Directional read of the mean pairwise MI (nats), one line.
    if isnan(Red.MeanPairwiseMIEngineered) || isnan(Red.MeanPairwiseMIOriginal)
        V = "Redundancy: not assessable (need >= 2 features to measure pairwise redundancy).";
        return
    end
    Direction = "reduced";
    if Red.MeanPairwiseMIEngineered > Red.MeanPairwiseMIOriginal + 1e-6
        Direction = "INCREASED";
    end
    V = sprintf("Redundancy: mean pairwise MI %s (%.3f -> %.3f); worst pair %.3f -> %.3f.", ...
        Direction, ...
        Red.MeanPairwiseMIOriginal, Red.MeanPairwiseMIEngineered, ...
        Red.MaxPairwiseMIOriginal, Red.MaxPairwiseMIEngineered);
end


function Str = fmtNum(X)
    if isnan(X)
        Str = "n/a";
    else
        Str = sprintf("%.2f", X);
    end
end


function printPanel(Result)
%printPanel Console block mirroring baselineComparison's fprintf style.
    fprintf('\nModel-Free Quality Panel (original vs engineered):\n');
    Rel = Result.Relevance;
    fprintf('  Relevance (marginal MI with response):\n');
    fprintf('    Peak feature:  orig=%s  eng=%s\n', fmtNum(Rel.MaxOriginal), fmtNum(Rel.MaxEngineered));
    fprintf('    Above %.2f-nat threshold: orig=%d  eng=%d features\n', Rel.Threshold, Rel.NumRelevantOriginal, Rel.NumRelevantEngineered);
    Red = Result.Redundancy;
    fprintf('  Redundancy (pairwise MI):\n');
    fprintf('    Mean (all pairs): orig=%s  eng=%s\n', fmtNum(Red.MeanPairwiseMIOriginal), fmtNum(Red.MeanPairwiseMIEngineered));
    fprintf('    Max (worst pair): orig=%s  eng=%s\n', fmtNum(Red.MaxPairwiseMIOriginal), fmtNum(Red.MaxPairwiseMIEngineered));
    Comp = Result.Compactness;
    fprintf('  Compactness:\n');
    fprintf('    Feature count:      orig=%d  eng=%d\n', Comp.NumFeaturesOriginal, Comp.NumFeaturesEngineered);
    fprintf('    Effective dim:      orig=%s  eng=%s\n', fmtNum(Comp.EffectiveDimOriginal), fmtNum(Comp.EffectiveDimEngineered));
end
