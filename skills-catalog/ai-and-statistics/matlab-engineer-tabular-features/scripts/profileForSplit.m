function Profile = profileForSplit(RawTbl, Response, Options)
%profileForSplit Minimal profiling to fix problem type and drive the split.
%
%   Profile = profileForSplit(RawTbl, Response) inspects the raw table just
%   enough to (1) decide whether the task is classification or regression, (2)
%   summarize class balance for classification, and (3) list the predictor
%   names. It deliberately does NO cleaning / encoding / scaling profiling --
%   that work belongs to the generator (gencfeatures) or a domain skill. The
%   returned Profile.ProblemType drives splitStrategy (which builds the outer
%   train/test holdout) and every downstream phase that branches on
%   classification vs regression (generation, selection, assessment, baseline).
%   The class-balance summary (counts, minority count, imbalance ratio) feeds
%   the report's intake/overview summary.
%
%   NOTE ON SAMPLE SIZE. Profile.ClassBalance.MinorityCount is a full-table
%   summary used for the report/overview only -- it is deliberately a whole-table
%   value, so it must not be read as a train-block statistic by downstream phases.
%
%   PROBLEM-TYPE DETECTION. A non-numeric response (categorical, logical,
%   string, char, or cellstr) is always classification. A numeric response is
%   classification only when it is integer-valued with few distinct levels
%   (<= MaxDiscreteLevels), otherwise regression. This heuristic is fragile at
%   the boundary (e.g. an integer-coded target with many levels, or a rating
%   scale), so ProblemType can be set explicitly to override it.
%
%   Inputs:
%     RawTbl   - table of raw predictors + response
%     Response - (1,1) string, response variable name in RawTbl
%     Options.ProblemType - (1,1) string: "auto" (default) detects as above;
%                 "classification" / "regression" force the type.
%     Options.MaxDiscreteLevels - (1,1) integer; the largest number of distinct
%                 integer response values still treated as classification when
%                 ProblemType is "auto" (default 10).
%
%   Output:
%     Profile - struct with fields:
%       .ProblemType    - (1,1) string "classification" | "regression"
%       .Response       - (1,1) string response name
%       .PredictorNames - (1,:) string predictor column names
%       .NumRows        - (1,1) double row count
%       .ClassBalance   - struct:
%                           .NumClasses     - class count (NaN for regression)
%                           .Classes        - (1,:) string class labels ([] regr)
%                           .Counts         - (1,:) double per-class counts ([] regr)
%                           .MinorityCount  - min class count (NaN for regression)
%                           .ImbalanceRatio - max/min class count (NaN regr)
%       .Reasoning      - (1,1) string, how the problem type was decided

% Copyright 2026 The MathWorks, Inc.

    arguments
        RawTbl table
        Response (1,1) string
        Options.ProblemType (1,1) string {mustBeMember(Options.ProblemType, ...
            ["auto","classification","regression"])} = "auto"
        Options.MaxDiscreteLevels (1,1) {mustBeInteger, mustBePositive} = 10
    end

    AllVars = string(RawTbl.Properties.VariableNames);
    if ~ismember(Response, AllVars)
        error('profileForSplit:responseNotFound', ...
            'Response variable "%s" is not a column of the input table.', Response);
    end

    PredictorNames = setdiff(AllVars, Response, "stable");
    y = RawTbl.(Response);

    [ProblemType, Reasoning] = resolveProblemType(y, Options.ProblemType, Options.MaxDiscreteLevels);

    Profile = struct();
    Profile.ProblemType = ProblemType;
    Profile.Response = Response;
    Profile.PredictorNames = PredictorNames;
    Profile.NumRows = height(RawTbl);
    Profile.ClassBalance = classBalance(y, ProblemType);
    Profile.Reasoning = string(Reasoning);

    if ProblemType == "classification"
        fprintf('Profile: classification, %d classes, imbalance %.1f:1 (minority=%d). %s\n', ...
            Profile.ClassBalance.NumClasses, Profile.ClassBalance.ImbalanceRatio, ...
            Profile.ClassBalance.MinorityCount, Reasoning);
    else
        fprintf('Profile: regression, %d rows. %s\n', Profile.NumRows, Reasoning);
    end
end


function [ProblemType, Reasoning] = resolveProblemType(y, Override, MaxDiscreteLevels)
%resolveProblemType Decide classification vs regression (explicit or heuristic).
    if Override ~= "auto"
        ProblemType = Override;
        Reasoning = sprintf("problem type set explicitly to %s", ProblemType);
        return
    end

    if ~isnumeric(y)
        % categorical / logical / string / char / cellstr responses are labels.
        ProblemType = "classification";
        Reasoning = sprintf("non-numeric response (%s) -> classification", class(y));
        return
    end

    yObs = y(~ismissing(y));
    Levels = unique(yObs);
    nLevels = numel(Levels);
    AllInteger = ~isempty(Levels) && all(Levels == round(Levels));

    if AllInteger && nLevels <= MaxDiscreteLevels
        ProblemType = "classification";
        Reasoning = sprintf(...
            "numeric response, integer-valued with %d distinct level(s) <= %d -> classification", ...
            nLevels, MaxDiscreteLevels);
    else
        ProblemType = "regression";
        Reasoning = sprintf(...
            "numeric response with %d distinct value(s) (integer=%d) -> regression", ...
            nLevels, AllInteger);
    end
end


function CB = classBalance(y, ProblemType)
%classBalance Per-class counts, minority count, and imbalance ratio.
%   Full-table summary values, reported for context in the report/overview only
%   (see the sample-size note in the function header).
    if ProblemType ~= "classification"
        CB = struct(NumClasses = NaN, Classes = string.empty(1,0), ...
            Counts = [], MinorityCount = NaN, ImbalanceRatio = NaN);
        return
    end

    C = removecats(categorical(y));
    Counts = countcats(C)';
    Classes = string(categories(C))';
    MinorityCount = min(Counts);

    CB = struct( ...
        NumClasses = numel(Classes), ...
        Classes = Classes, ...
        Counts = Counts, ...
        MinorityCount = MinorityCount, ...
        ImbalanceRatio = max(Counts) / max(MinorityCount, 1));
end
