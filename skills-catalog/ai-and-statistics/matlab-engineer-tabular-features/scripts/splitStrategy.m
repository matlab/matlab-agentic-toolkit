function [Splits, Decision] = splitStrategy(T, ProblemType, Response, Options)
%splitStrategy Level-1 evaluation split over the pipeline's working data.
%
%   [Splits, Decision] = splitStrategy(T, ProblemType, Response) decides how the
%   WORKING data is evaluated. Working data is whatever reserveHoldoutForUser
%   (Level 0) left after setting aside the user's untouched slice; pass those row
%   indices as Subset so this operates only on them and returns GLOBAL indices.
%   Both evaluation strategies share one deliverable rule handled downstream: the
%   delivered recipe is refit on ALL working rows; the split below only decides
%   how performance is ESTIMATED, never what ships.
%
%     "holdout"          - split the working rows into a train part and a held
%                          part (stratified for classification, random for
%                          regression). Generation + selection run on the train
%                          part; the held part yields a single-split point
%                          estimate (no error bars). TrainIdx / TestIdx are the
%                          two parts.
%     "cross_validated"  - no single held-out slice: every working row rotates
%                          through a fold's test set under assessKFold, whose
%                          cross-fold mean +/- std IS the estimate. TrainIdx spans
%                          ALL working rows and TestIdx is empty.
%
%   Splits struct fields:
%     .TrainIdx - (:,1) GLOBAL row indices generation/selection run on (the whole
%                 working set under "cross_validated")
%     .TestIdx  - (:,1) GLOBAL row indices for the point-estimate test; EMPTY
%                 under "cross_validated"
%     .Method   - string: "stratified_holdout", "random_holdout", or
%                 "cross_validated"
%     .Strategy - the EvaluationStrategy in force ("holdout"/"cross_validated")
%
%   Decision struct fields:
%     .Choice       - chosen method description
%     .Alternatives - alternative methods considered
%     .Reasoning    - why this method was selected
%
%   Options:
%     EvaluationStrategy (1,1) string  - "holdout" (default) or "cross_validated".
%     Subset             (:,1) numeric - working row indices to operate on
%                          (default: all rows of T). Returned indices are global.
%     HoldoutFraction    (1,1) double  - held fraction under "holdout" (default 0.2).

% Copyright 2026 The MathWorks, Inc.

    arguments
        T table
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Response (1,1) string
        Options.EvaluationStrategy (1,1) string ...
            {mustBeMember(Options.EvaluationStrategy, ["holdout","cross_validated"])} = "holdout"
        Options.Subset (:,1) {mustBeNumeric, mustBeInteger} = []
        Options.HoldoutFraction (1,1) double {mustBePositive, mustBeLessThan(Options.HoldoutFraction, 1)} = 0.2
    end

    if isempty(Options.Subset)
        WorkingIdx = (1:height(T))';
    else
        WorkingIdx = unique(Options.Subset(:));
        if any(WorkingIdx < 1) || any(WorkingIdx > height(T))
            error('splitStrategy:subsetOutOfRange', ...
                'Subset contains row indices outside 1..%d.', height(T));
        end
    end

    if Options.EvaluationStrategy == "cross_validated"
        [Splits, Decision] = crossValidatedSplit(WorkingIdx);
    else
        [Splits, Decision] = holdoutSplit(T, WorkingIdx, ProblemType, Response, Options.HoldoutFraction);
    end
    Splits.Strategy = Options.EvaluationStrategy;

    printSplitSummary(Splits, Decision.Choice, Decision.Reasoning);
end


function [Splits, Decision] = crossValidatedSplit(WorkingIdx)
%crossValidatedSplit No single held-out slice; folds (assessKFold) do the work.
    Splits.TrainIdx = WorkingIdx;
    Splits.TestIdx = zeros(0, 1);
    Splits.Method = "cross_validated";

    Decision.Choice = "cross_validated";
    Decision.Alternatives = "stratified_holdout, random_holdout";
    Decision.Reasoning = sprintf(['Cross-validated pipeline (%d working rows): every row rotates ' ...
        'through a fold''s test slice, so the cross-fold mean +/- std is the estimate; ' ...
        'no single held-out slice is carved'], numel(WorkingIdx));
end


function [Splits, Decision] = holdoutSplit(T, WorkingIdx, ProblemType, Response, Fraction)
%holdoutSplit Split working rows into train/test; returns GLOBAL indices.
    if ProblemType == "classification"
        Cv = cvpartition(T.(Response)(WorkingIdx), Holdout=Fraction);
        Splits.Method = "stratified_holdout";
        Decision.Alternatives = "random_holdout";
        Decision.Reasoning = sprintf(['Classification (%d working rows); stratified %.0f%% ' ...
            'holdout preserves class proportions'], numel(WorkingIdx), 100 * Fraction);
    else
        Cv = cvpartition(numel(WorkingIdx), Holdout=Fraction);
        Splits.Method = "random_holdout";
        Decision.Alternatives = "stratified_holdout";
        Decision.Reasoning = sprintf("Regression (%d working rows); random %.0f%% holdout sufficient", ...
            numel(WorkingIdx), 100 * Fraction);
    end
    Splits.TrainIdx = WorkingIdx(training(Cv));
    Splits.TestIdx = WorkingIdx(test(Cv));

    Decision.Choice = Splits.Method;
end


function printSplitSummary(Splits, Choice, Reasoning)
    fprintf('Split strategy: %s | Train=%d, Test=%d\n', ...
        Choice, numel(Splits.TrainIdx), numel(Splits.TestIdx));
    fprintf('  Reasoning: %s\n', Reasoning);
end
