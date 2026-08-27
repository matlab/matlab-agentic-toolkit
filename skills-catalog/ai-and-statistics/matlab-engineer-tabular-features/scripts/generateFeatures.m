function [FullTbl, Transformer, GenInfo] = generateFeatures(RawTbl, Response, ProblemType, Options)
%generateFeatures Generate the full candidate feature pool via SMLT (no selection).
%
%   [FullTbl, Transformer, GenInfo] = generateFeatures(RawTbl, Response, ...
%       ProblemType) runs gencfeatures (classification) or genrfeatures
%   (regression) in generate-only mode: external consensus selection
%   (runConsensusSelection) does the cutting, not the generator's own internal
%   selection. By default it requests an effectively-infinite feature count
%   (Options.NumFeatures = intmax('uint64')), so the generator returns its full
%   rich pool; it caps q at its true maximum and warns, which is expected and
%   suppressed by exact id.
%
%   WIDE-INPUT GUARD. The generators build features combinatorially, so a wide
%   predictor table (D predictors) produces a very large, mostly-useless pool
%   that is slow to generate and to rank. This function does NOT hold that
%   conversation with the user -- the orchestrator does (see the generation
%   reference): when D exceeds Options.MaxNumPredictors (default 50) the user is
%   asked to either give an explicit NumFeatures (a smaller custom pool) or
%   "skip" generation, which is simply NumFeatures = D (with
%   IncludeInputVariables="include", q = D yields the originals passed through
%   and no engineered features, while still returning a real FeatureTransformer
%   so the downstream contract is unchanged). To enforce that the conversation
%   happened, this function errors (generateFeatures:tooManyPredictors) only in
%   the ACCIDENTAL case: NumFeatures left at its intmax default AND D >
%   MaxNumPredictors. An explicit NumFeatures (custom or = D) always proceeds. The
%   guard does NOT apply to domain-skill recipes -- only to the SMLT generators.
%
%   The returned FeatureTransformer is the deterministic inference artifact:
%   transform(Transformer, NewRawTbl) reproduces FullTbl's engineered columns
%   on new raw data, so no bespoke op-log replay is needed downstream.
%
%   MULTI-CLASS + binary-only family: gencfeatures binary-only learners
%   ("linear", "gaussian-svm") hard-error on 3+ classes. Since the only
%   response-dependent transform gencfeatures produces is Weight-of-Evidence
%   (WoE), we generate under a deterministic dummy binary response
%   (most-frequent class vs rest), then flag the WoE columns in
%   GenInfo.BinaryReliant so selection can exclude them. The remaining features
%   are pure functions of the predictors and reusable for a multi-class model
%   trained via ECOC. WoE columns are never selected, so inference (subset to
%   selected columns) drops them and no dummy-response leakage reaches it.
%
%   Inputs:
%     RawTbl      - table of raw predictors + response (fit on training rows only)
%     Response    - (1,1) string, either a bare response variable name in RawTbl
%                   (e.g. "Target") or a Wilkinson formula (e.g. "Y ~ x1 + x2").
%                   A formula is passed to the generator verbatim (so it honors
%                   the predictor subset); its left-hand side names the response
%                   column used for dummy binarization / restoration.
%     ProblemType - (1,1) string, "classification" or "regression"
%     Options.TargetModel - (1,1) string model family that biases which
%                   candidates the generator prioritizes (pool is taken whole,
%                   so this only shapes ordering): "agnostic" (default),
%                   "tree_ensemble", "linear", "kernel_distance"
%     Options.Standardization - (1,1) string TransformedDataStandardization mode
%                   for the generator: "auto" (default) delegates to
%                   chooseStandardization; "none"/"zscore"/"mad"/"range" override
%                   it explicitly.
%     Options.NumFeatures - (1,1) positive integer, the total post-generation
%                   feature count q passed to the generator. Default
%                   intmax('uint64') = full rich pool. Set to a smaller value for
%                   a bounded pool, or to D (the predictor count) to add no
%                   engineered features (a no-op transformer).
%     Options.MaxNumPredictors - (1,1) positive integer predictor-count threshold
%                   above which an unbounded (default-NumFeatures) call is refused
%                   so the wide-input conversation is not skipped. Default 50.
%
%   Outputs:
%     FullTbl     - table: full engineered feature pool + response column (the
%                   ORIGINAL response, not any dummy used for generation)
%     Transformer - FeatureTransformer object (save for inference)
%     GenInfo     - struct with fields:
%                     .PoolSize      - number of engineered features (excl response)
%                     .TargetLearner - learner passed to the generator
%                     .Standardization - resolved TransformedDataStandardization mode
%                     .StandardizationReasoning - why that mode was chosen
%                     .UsedDummyResponse - true if a dummy binary Y was used
%                     .BinaryReliant - string array of response-dependent (WoE)
%                                      feature names to exclude from selection
%                     .Reasoning     - human-readable dispatch explanation

% Copyright 2026 The MathWorks, Inc.

    arguments
        RawTbl table
        Response (1,1) string
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Options.TargetModel (1,1) string {mustBeMember(Options.TargetModel, ...
            ["agnostic","tree_ensemble","linear","kernel_distance"])} = "agnostic"
        Options.Standardization (1,1) string {mustBeMember(Options.Standardization, ...
            ["auto","none","zscore","mad","range"])} = "auto"
        Options.NumFeatures (1,1) {mustBeInteger, mustBePositive} = intmax('uint64')
        Options.MaxNumPredictors (1,1) {mustBeInteger, mustBePositive} = 50
    end

    % Wide-input guard: refuse an unbounded (default-NumFeatures) pool on a wide
    % predictor table so the orchestrator's D > MaxNumPredictors conversation is not
    % silently skipped. An explicit NumFeatures (custom, or = D for no new
    % features) signals the decision was made, so it proceeds. The response
    % column is excluded from the predictor count.
    NumPredictors = width(RawTbl) - 1;
    UnboundedDefault = Options.NumFeatures == intmax('uint64');
    if UnboundedDefault && NumPredictors > Options.MaxNumPredictors
        error('generateFeatures:tooManyPredictors', ...
            ['Input has %d predictors (> MaxNumPredictors = %d). An unbounded ' ...
            'feature pool on wide data is slow and mostly useless. Pass an ' ...
            'explicit NumFeatures (a bounded pool, or = %d to add no engineered ' ...
            'features), or raise MaxNumPredictors to proceed unbounded.'], ...
            NumPredictors, Options.MaxNumPredictors, NumPredictors);
    end

    q = Options.NumFeatures;
    WarnId = "stats:featlearn:genfeatures:FeauresRequestedGreaterThanMax";
    PrevState = warning('off', WarnId);
    RestoreWarn = onCleanup(@() warning(PrevState));

    % Response may be a bare variable name or a Wilkinson formula ("Y ~ x1+x2").
    % Pass it to the generator verbatim (so a formula's predictor subset is
    % honored); resolve the LHS name for table-column operations.
    ResponseVar = resolveResponseName(Response, RawTbl);

    % Resolve the standardization mode: "auto" delegates to the introspection
    % utility; an explicit value is passed straight through.
    if Options.Standardization == "auto"
        [Standardization, StdReasoning] = chooseStandardization(RawTbl, ResponseVar, ...
            Options.TargetModel);
    else
        Standardization = Options.Standardization;
        StdReasoning = sprintf("explicit override: %s", Standardization);
    end

    UsedDummy = false;
    BinaryReliant = string.empty(1, 0);

    if ProblemType == "regression"
        TargetLearner = regressionLearner(Options.TargetModel);
        Reasoning = sprintf("regression: genrfeatures generate-only, TargetLearner=%s", TargetLearner);
        [Transformer, FullTbl] = genrfeatures(RawTbl, Response, q, ...
            TargetLearner=TargetLearner, IncludeInputVariables="include", ...
            TransformedDataStandardization=Standardization);
    else
        [TargetLearner, NeedsDummy, Reasoning] = classificationLearner( ...
            Options.TargetModel, RawTbl.(ResponseVar));

        if NeedsDummy
            % Binary-only learner on a multi-class response: generate under a
            % deterministic dummy binarization, then flag WoE (the sole
            % response-dependent transform) for exclusion from selection.
            UsedDummy = true;
            GenTbl = RawTbl;
            GenTbl.(ResponseVar) = buildDummyBinary(RawTbl.(ResponseVar));
        else
            GenTbl = RawTbl;
        end

        [Transformer, FullTbl] = gencfeatures(GenTbl, Response, q, ...
            TargetLearner=TargetLearner, IncludeInputVariables="include", ...
            TransformedDataStandardization=Standardization);

        if UsedDummy
            BinaryReliant = responseDependentFeatures(Transformer);
            % Restore the ORIGINAL (multi-class) response on the output table so
            % downstream selection/assessment sees the real target.
            FullTbl.(ResponseVar) = RawTbl.(ResponseVar);
        end
    end

    GenInfo = struct( ...
        PoolSize = width(FullTbl) - 1, ...
        TargetLearner = TargetLearner, ...
        Standardization = Standardization, ...
        StandardizationReasoning = string(StdReasoning), ...
        UsedDummyResponse = UsedDummy, ...
        BinaryReliant = BinaryReliant, ...
        Reasoning = string(Reasoning));

    fprintf('Generated %d candidate features (generate-only, TargetLearner=%s, standardization=%s).\n', ...
        GenInfo.PoolSize, TargetLearner, Standardization);
    if UsedDummy
        fprintf(['  Multi-class + binary-only family: used dummy binarization; ' ...
            'excluding %d response-dependent (WoE) feature(s) from selection.\n'], ...
            numel(BinaryReliant));
    end
end


function ResponseVar = resolveResponseName(Response, RawTbl)
%resolveResponseName Extract the response variable name from a name or formula.
%   A Wilkinson formula "LHS ~ RHS" yields its trimmed left-hand side; a bare
%   name is returned unchanged after confirming it is a column of RawTbl.

    Response = string(Response);
    if contains(Response, "~")
        Parts = split(Response, "~");
        ResponseVar = strtrim(Parts(1));
    else
        ResponseVar = strtrim(Response);
    end

    if ~ismember(ResponseVar, string(RawTbl.Properties.VariableNames))
        error('generateFeatures:responseNotFound', ...
            'Response variable "%s" is not a column of the input table.', ResponseVar);
    end
end


function [Learner, NeedsDummy, Reasoning] = classificationLearner(TargetModel, ResponseCol)
%classificationLearner Map model family to a gencfeatures TargetLearner.
%   gencfeatures TargetLearner support: "bag" (multi-class OK), "linear" and
%   "gaussian-svm" (binary only). For a multi-class response with a binary-only
%   family, NeedsDummy is true: we generate under a dummy binarization and later
%   drop the response-dependent (WoE) columns rather than falling back to "bag".

    NumClasses = numel(categories(categorical(ResponseCol)));
    IsBinary = NumClasses <= 2;
    NeedsDummy = false;

    switch TargetModel
        case "tree_ensemble"
            Learner = "bag";
            Reasoning = "tree_ensemble -> bag";
        case "linear"
            Learner = "linear";
            if IsBinary
                Reasoning = "linear -> linear (binary)";
            else
                NeedsDummy = true;
                Reasoning = sprintf("linear -> linear via dummy binarization " + ...
                    "(%d classes; WoE features excluded, ECOC downstream)", NumClasses);
            end
        case "kernel_distance"
            Learner = "gaussian-svm";
            if IsBinary
                Reasoning = "kernel_distance -> gaussian-svm (binary)";
            else
                NeedsDummy = true;
                Reasoning = sprintf("kernel_distance -> gaussian-svm via dummy " + ...
                    "binarization (%d classes; WoE features excluded, ECOC downstream)", ...
                    NumClasses);
            end
        otherwise  % "agnostic"
            % agnostic wants the RICHEST pool. "linear" generates the broadly
            % useful FE space (interactions, ratios, nonlinear maps, k-means
            % distances) that "bag" suppresses -- verified ~55 of 57 linear
            % candidates are absent from the bag pool. Since we take the whole
            % pool and select externally, the linear generation bias is best.
            Learner = "linear";
            if IsBinary
                Reasoning = "agnostic -> linear (richest candidate pool)";
            else
                NeedsDummy = true;
                Reasoning = sprintf("agnostic -> linear via dummy binarization " + ...
                    "(%d classes; WoE features excluded, ECOC downstream)", NumClasses);
            end
    end
end


function Learner = regressionLearner(TargetModel)
%regressionLearner Map model family to a genrfeatures TargetLearner.
%   genrfeatures supports "linear" (default), "bag", "gaussian-svm" with no
%   multi-class restriction. Kernel/SVM regression maps to "gaussian-svm";
%   "agnostic" maps to "linear" (its richer pool), matching classification.

    switch TargetModel
        case "tree_ensemble"
            Learner = "bag";
        case "kernel_distance"
            Learner = "gaussian-svm";
        otherwise  % "linear" or "agnostic"
            Learner = "linear";
    end
end


function Dummy = buildDummyBinary(ResponseCol)
%buildDummyBinary Deterministic one-vs-rest binarization (most-frequent vs rest).
%   Only used to unblock generation under a binary-only learner; the resulting
%   response-dependent (WoE) features are excluded from selection afterwards, so
%   the specific split choice does not affect the delivered feature set.

    C = categorical(ResponseCol);
    Cats = categories(C);
    Counts = countcats(C);
    [~, MaxPos] = max(Counts);
    Dummy = categorical(C == Cats{MaxPos});
end


function Names = responseDependentFeatures(Transformer)
%responseDependentFeatures Names of engineered features that depend on the
%   response. For gencfeatures the only such transform is Weight of Evidence.

    D = describe(Transformer);
    Trans = string(D.Transformations);
    Mask = contains(Trans, "Weight of Evidence", IgnoreCase=true);
    Names = string(D.Properties.RowNames(Mask))';
    if isempty(Names)
        Names = string.empty(1, 0);
    end
end
