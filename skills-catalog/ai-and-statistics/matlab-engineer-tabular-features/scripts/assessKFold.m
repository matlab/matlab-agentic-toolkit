function Result = assessKFold(RawTrainTbl, Response, ProblemType, CVPartition, Options)
%assessKFold K-fold PERFORMANCE read of the whole feature-engineering pipeline.
%
%   Result = assessKFold(RawTrainTbl, Response, ProblemType, CVPartition) wraps
%   the ENTIRE pipeline -- generate -> select -> model contrast -- in a single
%   K-fold loop over the training rows and reports how the engineered recipe
%   performs on held-out folds. The folds are supplied by the caller as a
%   cvpartition object so the same function serves stratified, grouped, or
%   time-series schemes without change; K is taken from CVPartition.NumTestSets.
%
%   This partition is INNER and diagnostic: it k-folds the TRAINING block only.
%   It is a different job from the outer train/val/test holdout that
%   splitStrategy produces for the pipeline run itself -- do not conflate them.
%   The caller builds the cvpartition (e.g. cvpartition(y, KFold=5) for a
%   stratified classification scheme, or cvpartition(n, KFold=5) otherwise).
%
%   The reads:
%
%     PERFORMANCE (repeatability + lift). Each fold refits gencfeatures on its
%     own training rows (so the engineered VALUES differ fold to fold, even
%     though the feature DEFINITIONS are largely shared), re-selects, and scores
%     an engineered-vs-original-vs-naive contrast on the held-out fold. Reported
%     as mean +/- std across folds: how repeatable the whole recipe is, and how
%     much the engineered set actually beats the raw features and a naive
%     predictor. This is the honest end-to-end variance -- it includes the
%     generation step, which a single holdout hides. Because this loop owns the
%     performance-variance estimate, the per-fold baselineComparison runs with
%     InternalCV=false (its own k-fold CV would be redundant here).
%
%     REPRESENTATION-QUALITY STABILITY. Each fold's engineered set is scored by
%     featureSetQuality on that fold's TRAINING rows (engineered-side only) and
%     the dimensions aggregated mean +/- std across folds -- how much the recipe's
%     OUTPUT quality wobbles under resampling. Distinct from the shipped set's own
%     quality (featureSetQuality on all working data at delivery).
%
%   This is DIAGNOSTIC ONLY. It grades the recipe's held-out performance; it
%   never revises the delivered feature set.
%
%   Inputs:
%     RawTrainTbl - table of RAW predictors + response, TRAINING rows only (the
%                   final test set is held out upstream and never seen here)
%     Response    - (1,1) string, response variable name in RawTrainTbl
%     ProblemType - (1,1) string, "classification" or "regression"
%     CVPartition - (1,1) cvpartition over height(RawTrainTbl) rows with
%                   NumTestSets >= 2; test(CVPartition,k) gives fold k's held-out
%                   rows. The caller owns stratification / grouping / K, and
%                   whether the partition covers the train block (default flow)
%                   or all rows (whole-data k-fold mode).
%     Options.TargetModel  - (1,1) string model family, passed to the producer
%                            and baselineComparison (default "agnostic")
%     Options.Producer     - (1,1) function_handle, the PLUGGABLE generator (see
%                            below). Default is the SMLT gencfeatures producer, so
%                            the SMLT path is unchanged; a domain path injects a
%                            producer that re-runs its extraction per fold.
%
%   THE PLUGGABLE PRODUCER. Generation is injected so this one loop serves both
%   the SMLT path and a domain path (Mode 3 in either case). The producer is
%     [EngTrain, Apply, ExcludeFeatures] = Producer(FoldTrainRaw, Response, ...
%                                                    ProblemType, TargetModel)
%   where EngTrain is the engineered TRAINING table (predictors + response), Apply
%   is a function handle mapping a raw table to the engineered pool (the fold's
%   fitted recipe -- transform(Transformer,.) for SMLT, Recipe.Apply for a domain
%   skill) used to engineer the held-out rows leakage-safely, and ExcludeFeatures
%   are names to drop before ranking (e.g. GenInfo.BinaryReliant; string.empty for
%   a domain pool). The default SMLT producer wraps generateFeatures; because it
%   refits per fold, the loop already handles a pool that differs fold to fold, so
%   a domain producer needs no special-casing.
%
%   Output:
%     Result - struct with fields:
%       .K, .MetricName, .TargetModel
%       .Performance.Engineered / .Original / .Naive / .Improvement
%                          - each a struct(.Mean, .Std, .PerFold), for the primary
%                            metric (.MetricName: AUC or RMSE)
%       .Performance.Secondary       - ordered struct array of companion metrics
%                            any fold recorded (classification: macro-F1 always,
%                            accuracy when balanced), each element
%                            struct(Name, Engineered, Original) with Engineered /
%                            Original a meanStd struct; empty (1x0) when none
%                            (e.g. regression)
%       .Performance.Panel           - ordered struct array, one element per trained
%                            family (single family when declared; bag/linear/kernel
%                            under agnostic), each aggregated mean +/- std as above
%       .QualityStability            - engineered-side model-free quality across
%                                        folds: struct with MaxRelevance,
%                                        NumRelevant, MeanRedundancy, MaxRedundancy,
%                                        EffectiveDim (each a meanStd struct)
%       .PerFold                       - struct array (.Metric, .NumSelected, .PoolSize)
%       .Reasoning                     - human-readable summary

% Copyright 2026 The MathWorks, Inc.

    arguments
        RawTrainTbl table
        Response (1,1) string
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        CVPartition (1,1) cvpartition
        Options.TargetModel (1,1) string {mustBeMember(Options.TargetModel, ...
            ["agnostic","tree_ensemble","linear","kernel_distance"])} = "agnostic"
        Options.Producer (1,1) function_handle = @smltProducer
    end

    AllVars = string(RawTrainTbl.Properties.VariableNames);
    if ~ismember(Response, AllVars)
        error('assessKFold:responseNotFound', ...
            'Response variable "%s" is not a column of the input table.', Response);
    end
    OriginalPredVars = setdiff(AllVars, Response, "stable");
    % The original-reference baseline fits a learner on these raw columns, so the
    % reference can only hold model-ready predictor types. datetime/duration
    % columns are valid GENERATION inputs (the producer extracts components from
    % them, so they still shape the engineered pool) but a learner cannot fit a
    % bare datetime -- exclude those types from the ORIGINAL reference only.
    IsModelReady = ~varfun(@(c) isdatetime(c) || isduration(c) || isa(c, "calendarDuration"), ...
        RawTrainTbl(:, OriginalPredVars), OutputFormat = "uniform");
    OriginalPredVars = OriginalPredVars(IsModelReady);

    if CVPartition.NumObservations ~= height(RawTrainTbl)
        error('assessKFold:partitionSizeMismatch', ...
            'CVPartition was built for %d observations but the table has %d rows.', ...
            CVPartition.NumObservations, height(RawTrainTbl));
    end
    K = CVPartition.NumTestSets;
    if K < 2
        error('assessKFold:tooFewFolds', ...
            'CVPartition must define at least 2 folds; got %d.', K);
    end

    fprintf(['assessKFold: re-running generate -> select -> score on %d folds. ' ...
        'The producer refits per fold, so expect ~%dx a single generation''s cost.\n'], K, K);

    % --- Per-fold loop ---------------------------------------------------------
    EngMetric = nan(K, 1);
    OrigMetric = nan(K, 1);
    NaiveMetric = nan(K, 1);
    ImprovMetric = nan(K, 1);
    % Companion classification metrics, aggregated alongside the primary. Macro-F1
    % is always recorded for classification; accuracy only when the fold panel
    % logged it (balanced problems). NaN for folds/problem types that lack them.
    MacroF1Eng = nan(K, 1);
    MacroF1Orig = nan(K, 1);
    AccEng = nan(K, 1);
    AccOrig = nan(K, 1);
    % Engineered-side model-free quality per fold. Each fold scores its own
    % regenerated+reselected set on its TRAINING rows, engineered side only;
    % aggregated mean +/- std below.
    QMaxRel = nan(K, 1);
    QNumRel = nan(K, 1);
    QMeanRed = nan(K, 1);
    QMaxRed = nan(K, 1);
    QEffDim = nan(K, 1);
    % Full per-family panel each fold (all trained families, not just the primary),
    % so agnostic can report bag/linear/kernel side by side. baselineComparison
    % always returns .Panel, so this is populated for every fold.
    PanelPerFold = cell(K, 1);
    PerFold = repmat(struct(Metric = NaN, NumSelected = 0, PoolSize = 0), 1, K);
    MetricName = "";

    for k = 1:K
        TestRows = test(CVPartition, k);
        FoldTrain = RawTrainTbl(~TestRows, :);
        FoldTest = RawTrainTbl(TestRows, :);

        % Generate on fold-train ONLY (leakage-safe) via the pluggable producer;
        % Apply reproduces this fold's pool on any raw rows for the held-out score.
        [EngTrain, Apply, ExcludeFeatures] = Options.Producer(FoldTrain, Response, ...
            ProblemType, Options.TargetModel);
        PoolNames = setdiff(string(EngTrain.Properties.VariableNames), Response, "stable");

        % Select on the fold's engineered training pool.
        SelectedNames = runConsensusSelection(EngTrain, Response, ProblemType, ...
            ExcludeFeatures = ExcludeFeatures);

        % Build combined engineered + raw tables (train rows first, then test)
        % so baselineComparison scores this fold's selected set out-of-fold.
        RawCombined = [FoldTrain; FoldTest];
        EngCombined = combineEngineered(EngTrain, Apply, RawCombined, Response);
        nTrain = height(FoldTrain);
        TrainIdxLocal = (1:nTrain)';
        ValIdxLocal = (nTrain + 1 : height(RawCombined))';

        % Cast integer originals to double in the diagnostic REFERENCE only (the
        % fitters and the MI panel accept floating-point, not integer types); the
        % producer above already generated on the untouched integer columns, so the
        % pool is unaffected. datetime/duration are already dropped from
        % OriginalPredVars, so they are never referenced here.
        RawCombinedRef = castReferenceIntegers(RawCombined, OriginalPredVars);

        FoldResult = baselineComparison(RawCombinedRef, EngCombined, TrainIdxLocal, ValIdxLocal, ...
            Response, OriginalPredVars, SelectedNames, ProblemType, ...
            TargetModel = Options.TargetModel, InternalCV = false);

        EngMetric(k) = FoldResult.Engineered;
        OrigMetric(k) = FoldResult.Original;
        NaiveMetric(k) = FoldResult.Naive;
        ImprovMetric(k) = FoldResult.Improvement;
        MetricName = FoldResult.Metric;

        % Companion metrics when this fold's panel carries them.
        if isfield(FoldResult, 'MacroF1')
            MacroF1Eng(k) = FoldResult.MacroF1.Engineered;
            MacroF1Orig(k) = FoldResult.MacroF1.Original;
        end
        if isfield(FoldResult, 'Accuracy')
            AccEng(k) = FoldResult.Accuracy.Engineered;
            AccOrig(k) = FoldResult.Accuracy.Original;
        end

        PanelPerFold{k} = FoldResult.Panel;

        % Model-free quality of THIS fold's selected set, on its training rows
        % (EngTrain is row-aligned with FoldTrain). Engineered side only; the
        % original-side numbers are discarded here (the shipped-set read at
        % delivery owns the raw-vs-engineered contrast).
        FoldTrainRef = castReferenceIntegers(FoldTrain, OriginalPredVars);
        FoldQuality = featureSetQuality(FoldTrainRef, EngTrain, (1:height(EngTrain))', ...
            Response, OriginalPredVars, SelectedNames, ProblemType, Verbose = false);
        QMaxRel(k) = FoldQuality.Relevance.MaxEngineered;
        QNumRel(k) = FoldQuality.Relevance.NumRelevantEngineered;
        QMeanRed(k) = FoldQuality.Redundancy.MeanPairwiseMIEngineered;
        QMaxRed(k) = FoldQuality.Redundancy.MaxPairwiseMIEngineered;
        QEffDim(k) = FoldQuality.Compactness.EffectiveDimEngineered;

        PerFold(k) = struct(Metric = FoldResult.Engineered, ...
            NumSelected = numel(SelectedNames), PoolSize = numel(PoolNames));

        fprintf('  Fold %d/%d: pool=%d, selected=%d, %s(eng)=%.3f\n', ...
            k, K, numel(PoolNames), numel(SelectedNames), MetricName, FoldResult.Engineered);
    end

    % --- Aggregate performance -------------------------------------------------
    Result = struct();
    Result.K = K;
    Result.MetricName = MetricName;
    Result.TargetModel = Options.TargetModel;   % declared family, for report labelling
    Result.Performance = struct( ...
        Engineered = meanStd(EngMetric), ...
        Original = meanStd(OrigMetric), ...
        Naive = meanStd(NaiveMetric), ...
        Improvement = meanStd(ImprovMetric));
    % Companion metrics, aggregated the same way and stored under .Secondary as an
    % ordered struct array {Name, Engineered, Original} so a metric only appears
    % when at least one fold recorded it. Consumers (summary, reports) loop this
    % without hard-coding which companions exist.
    Result.Performance.Secondary = aggregateSecondary( ...
        {"macro-F1", MacroF1Eng, MacroF1Orig; "accuracy", AccEng, AccOrig});
    % Per-family panel: aggregate every trained family across folds the same way as
    % the primary above. Under a declared model this is a single family (identical
    % to the top-level fields); under agnostic it is bag/linear/kernel, so reports
    % and the grouped plot can show all three. The top-level .Engineered/.Original/
    % etc. remain the PRIMARY family so existing consumers are unaffected.
    Result.Performance.Panel = aggregatePanel(PanelPerFold, K);
    Result.PerFold = PerFold;

    % --- Representation-quality stability across folds -------------------------
    Result.QualityStability = struct( ...
        MaxRelevance = meanStd(QMaxRel), ...
        NumRelevant = meanStd(QNumRel), ...
        MeanRedundancy = meanStd(QMeanRed), ...
        MaxRedundancy = meanStd(QMaxRed), ...
        EffectiveDim = meanStd(QEffDim));

    Result.Reasoning = buildReasoning(Result, MetricName);
    fprintf('%s\n', Result.Reasoning);
end


function Tbl = castReferenceIntegers(Tbl, PredVars)
%castReferenceIntegers Cast integer predictor columns to double, reference-only.
%   The original-reference diagnostics (baselineComparison fitters, the MI panel's
%   floating-point check) accept double but not integer types. Integers are valid
%   predictors once cast, so widen them here in the reference copy only; generation
%   already ran on the untouched columns. Non-integer columns are left as-is.
    for i = 1:numel(PredVars)
        Col = Tbl.(PredVars(i));
        if isinteger(Col)
            Tbl.(PredVars(i)) = double(Col);
        end
    end
end


function EngCombined = combineEngineered(EngTrain, Apply, RawCombined, Response)
%combineEngineered Engineer the combined (train+test) raw rows in ONE Apply.
%   Applying the fold's recipe separately to train and test can yield engineered
%   categorical (binned) columns with different category sets, so a later vertcat
%   fails. Applying it to the combined raw table once gives every engineered
%   column a single consistent category set. It stays leakage-safe: the recipe
%   was fit on the fold's TRAINING rows only, so the test rows only ever have that
%   fitted recipe applied, never re-fit. Apply is the producer's fold recipe
%   (SMLT transform(Transformer,.) or a domain Recipe.Apply). The response is
%   reattached from the raw table and columns are aligned to EngTrain's order.
    EngCombined = Apply(RawCombined);
    if ~ismember(Response, string(EngCombined.Properties.VariableNames))
        EngCombined.(Response) = RawCombined.(Response);
    end
    EngCombined = EngCombined(:, EngTrain.Properties.VariableNames);
end


function [EngTrain, Apply, ExcludeFeatures] = smltProducer(FoldTrainRaw, Response, ProblemType, TargetModel)
%smltProducer Default producer: gencfeatures/genrfeatures via generateFeatures.
%   Fits the SMLT FeatureTransformer on the fold's training rows and returns its
%   transform method as the Apply handle, so held-out rows are engineered with the
%   fold-fitted recipe (never re-fit). ExcludeFeatures forwards the binary-reliant
%   WoE columns generateFeatures flags, matching the delivered selection run.
    [EngTrain, Transformer, GenInfo] = generateFeatures(FoldTrainRaw, Response, ...
        ProblemType, TargetModel = TargetModel);
    Apply = @(RawTbl) transform(Transformer, RawTbl);
    ExcludeFeatures = GenInfo.BinaryReliant;
end


function MS = meanStd(V)
%meanStd Mean/std over folds ignoring NaN, plus the raw per-fold vector.
    MS = struct(Mean = mean(V, "omitnan"), Std = std(V, "omitnan"), PerFold = V(:)');
end


function Secondary = aggregateSecondary(Spec)
%aggregateSecondary Aggregate each companion metric that any fold recorded.
%   Spec is an N-by-3 cell array {Name, EngVec, OrigVec}. A metric is included
%   only when at least one fold produced a finite value (so regression, which has
%   no companion, and balanced-only accuracy, drop out cleanly). Returns an
%   ordered struct array with fields Name/Engineered/Original, each aggregate a
%   meanStd struct -- empty (1x0) when nothing qualified.
    Secondary = struct('Name', {}, 'Engineered', {}, 'Original', {});
    for i = 1:size(Spec, 1)
        EngVec = Spec{i, 2};
        if ~any(isfinite(EngVec))
            continue
        end
        Secondary(end+1) = struct( ...
            Name = string(Spec{i, 1}), ...
            Engineered = meanStd(EngVec), ...
            Original = meanStd(Spec{i, 3})); %#ok<AGROW>
    end
end


function Families = aggregatePanel(PanelPerFold, K)
%aggregatePanel Aggregate each trained family's metrics across folds.
%   PanelPerFold{k} is fold k's baselineComparison .Panel (a struct array, one
%   entry per trained family). Families are identified by .Family and aggregated
%   independently, mean +/- std across folds, mirroring the primary aggregation.
%   Returns an ordered struct array with one element per family, fields:
%     .Family, .Engineered/.Original/.Naive/.Improvement (each a meanStd struct),
%     .Secondary (companion metrics, same shape as the top-level .Secondary).
%   Family order follows the first fold's panel (bag, linear, kernel for agnostic).
    Families = struct('Family', {}, 'Engineered', {}, 'Original', {}, ...
        'Naive', {}, 'Improvement', {}, 'Secondary', {});
    if K < 1 || isempty(PanelPerFold{1})
        return
    end
    FamilyNames = string({PanelPerFold{1}.Family});
    for f = 1:numel(FamilyNames)
        Name = FamilyNames(f);
        EngV = nan(K, 1); OrigV = nan(K, 1); NaiveV = nan(K, 1); ImprovV = nan(K, 1);
        MacroEngV = nan(K, 1); MacroOrigV = nan(K, 1);
        AccEngV = nan(K, 1); AccOrigV = nan(K, 1);
        for k = 1:K
            FR = familyEntry(PanelPerFold{k}, Name);
            if isempty(FR)
                continue
            end
            EngV(k) = FR.Engineered;
            OrigV(k) = FR.Original;
            NaiveV(k) = FR.Naive;
            ImprovV(k) = FR.Improvement;
            if isfield(FR, 'MacroF1')
                MacroEngV(k) = FR.MacroF1.Engineered;
                MacroOrigV(k) = FR.MacroF1.Original;
            end
            if isfield(FR, 'Accuracy')
                AccEngV(k) = FR.Accuracy.Engineered;
                AccOrigV(k) = FR.Accuracy.Original;
            end
        end
        Families(f) = struct( ...
            Family = Name, ...
            Engineered = meanStd(EngV), ...
            Original = meanStd(OrigV), ...
            Naive = meanStd(NaiveV), ...
            Improvement = meanStd(ImprovV), ...
            Secondary = aggregateSecondary( ...
                {"macro-F1", MacroEngV, MacroOrigV; "accuracy", AccEngV, AccOrigV}));
    end
end


function FR = familyEntry(Panel, Name)
%familyEntry The panel entry for a named family, or [] if absent this fold.
    FR = [];
    for i = 1:numel(Panel)
        if string(Panel(i).Family) == Name
            FR = Panel(i);
            return
        end
    end
end


function Reasoning = buildReasoning(Result, MetricName)
%buildReasoning One-line audit summary of the held-out performance read.
    Eng = Result.Performance.Engineered;
    Reasoning = string(sprintf( ...
        "K=%d: %s(eng)=%.3f+/-%.3f, improvement=%.3f+/-%.3f.", ...
        Result.K, MetricName, Eng.Mean, Eng.Std, ...
        Result.Performance.Improvement.Mean, Result.Performance.Improvement.Std));
end
