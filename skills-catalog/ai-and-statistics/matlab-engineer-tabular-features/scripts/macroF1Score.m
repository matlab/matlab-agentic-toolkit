function F1 = macroF1Score(TrueY, Scores, ClassNames)
%macroF1Score Macro-averaged F1 score via rocmetrics.
%   F1 = macroF1Score(TrueY, Scores, ClassNames) computes macro-averaged
%   F1 by taking the max F1 per class (across thresholds) from rocmetrics,
%   then averaging across classes.
%
%   Inputs:
%     TrueY      — categorical or numeric vector of true labels
%     Scores     — N-by-K matrix of posterior scores (from predict)
%     ClassNames — 1-by-K or K-by-1 array of class names (from model.ClassNames)
%
%   Output:
%     F1 — scalar macro-averaged F1 score

% Copyright 2026 The MathWorks, Inc.

    arguments
        TrueY (:,1)
        Scores (:,:) {mustBeFloat}
        ClassNames
    end

    RocObj = rocmetrics(TrueY, Scores, ClassNames, AdditionalMetrics="f1score");
    F1PerClass = groupsummary(RocObj.Metrics, "ClassName", "max", "F1Score");
    F1 = mean(F1PerClass.max_F1Score, 'omitnan');
end
