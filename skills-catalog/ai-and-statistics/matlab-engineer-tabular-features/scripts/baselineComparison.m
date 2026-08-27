function Result = baselineComparison(OriginalData, T, TrainIdx, ValIdx, ResponseVar, OriginalPredVars, EngineeredPredVars, ProblemType, Options)
%baselineComparison Model-family baseline panel: engineered vs original vs naive.
%
%   Result = baselineComparison(OriginalData, T, TrainIdx, ValIdx, ...
%       ResponseVar, OriginalPredVars, EngineeredPredVars, ProblemType)
%   trains one or more model families on original vs. engineered features and
%   compares against a naive predictor, using holdout scoring on ValIdx plus
%   internal k-fold CV within TrainIdx for the primary family.
%
%   The panel of families is chosen by the TargetModel option so the baseline
%   evaluates the pipeline through the lens of the user's actual downstream
%   model rather than assuming a random forest:
%     "agnostic"      (default) → all three families: bagged ensemble (primary),
%                                 linear, and kernel — no single model is assumed
%     "tree_ensemble"           → bagged ensemble only
%     "linear"                  → linear only
%     "kernel_distance"         → kernel only
%   A declared family trains through that family alone; only "agnostic" spans the
%   full panel.
%
%   For every top-level field the primary family is authoritative (for "agnostic"
%   that is the bagged ensemble): .Metric, .Naive, .Original, .Engineered,
%   .Improvement, the pass/beat flags, .MacroF1, .Accuracy, .AccuracyReliable,
%   .Model, .CV, and .CVOriginal all come from the primary family. Classification
%   always reports .Accuracy; .AccuracyReliable is true only when the training
%   imbalance ratio is <= 1.5:1, so a reader can tell when a raw hit-rate is
%   trustworthy versus flattered by a dominant class. Two additions: .Primary
%   (primary family name) and .Panel (a struct array of per-family holdout
%   summaries). The panel is evaluation-only — it trains N families on the ONE
%   engineered feature set; it never produces N feature sets.
%
%   The PrimaryFamily option overrides which trained family is primary, but only
%   under TargetModel="agnostic" — the one panel that trains all three families
%   and so has a lens to choose. It defaults to "auto" (the TargetModel-derived
%   primary above); under "agnostic", set it to "bag", "linear", or "kernel" to
%   promote that family as the lens whose metrics become the top-level fields and
%   whose fit drives internal CV, so a user can keep the broad panel yet headline
%   on linear or kernel. Under a declared single-family TargetModel the primary is
%   fixed to that family, so naming any PrimaryFamily there errors
%   (baselineComparison:primaryNotTrained).
%
%   All families take the predictors as-is (table or numeric matrix). The linear
%   and kernel learners auto-encode categorical predictors when given a table, so
%   no manual dummy-coding is needed; the only real limit is that fitclinear /
%   fitckernel classification is binary-only, which fitFamily handles by wrapping
%   multi-class responses in a one-vs-one ECOC. No feature scaling is applied
%   here: engineered features arrive already standardized from the generator's
%   transformer, and the original-feature baseline is scored as-is (raw).

% Copyright 2026 The MathWorks, Inc.

    arguments
        OriginalData
        T
        TrainIdx (:,1) {mustBeNumeric}
        ValIdx (:,1) {mustBeNumeric}
        ResponseVar (1,1) string
        OriginalPredVars
        EngineeredPredVars
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Options.SplitMethod (1,1) string {mustBeMember(Options.SplitMethod, ...
            ["stratified_holdout","random_holdout"])} = "stratified_holdout"
        Options.CVFolds (1,1) {mustBePositive, mustBeInteger} = 5
        Options.ImbalanceRatio (1,1) double = NaN
        Options.TargetModel (1,1) string {mustBeMember(Options.TargetModel, ...
            ["agnostic","tree_ensemble","linear","kernel_distance"])} = "agnostic"
        Options.PrimaryFamily (1,1) string {mustBeMember(Options.PrimaryFamily, ...
            ["auto","bag","linear","kernel"])} = "auto"
        Options.InternalCV (1,1) logical = true
    end

    OrigX = extractPredictors(OriginalData, OriginalPredVars);
    EngX = extractPredictors(T, EngineeredPredVars);
    if istable(T)
        ResponseCol = T.(ResponseVar);
    else
        error('baselineComparison:responseRequired', ...
            'T must be a table when ResponseVar is specified.');
    end

    [Families, Primary] = resolvePanel(Options.TargetModel);
    Primary = applyPrimaryOverride(Primary, Options.TargetModel, Options.PrimaryFamily);

    % Decide binary vs. multi-class ONCE from the full training response, so the
    % linear/kernel learner choice (direct binary fit vs. ECOC wrapper) is fixed
    % for every fit — including CV folds that might otherwise omit a rare class.
    IsMultiClass = isMultiClassResponse(ResponseCol, TrainIdx, ProblemType);

    Panel = repmat(emptyFamilyResult(ProblemType, Options.ImbalanceRatio, ResponseCol, TrainIdx), ...
        1, numel(Families));
    for i = 1:numel(Families)
        Panel(i) = runHoldoutFamily(Families(i), OrigX, EngX, ResponseCol, ...
            TrainIdx, ValIdx, ProblemType, Options.ImbalanceRatio, IsMultiClass);
    end

    PrimaryIdx = find(Families == Primary, 1);
    Result = Panel(PrimaryIdx);
    Result.Primary = Primary;
    Result.TargetModel = Options.TargetModel;
    Result.Panel = Panel;

    if Options.InternalCV
        Result.CV = runInternalCV(EngX, ResponseCol, TrainIdx, ProblemType, ...
            Options.SplitMethod, Options.CVFolds, "Engineered", Primary, IsMultiClass);

        if ~isempty(OrigX)
            Result.CVOriginal = runInternalCV(OrigX, ResponseCol, TrainIdx, ProblemType, ...
                Options.SplitMethod, Options.CVFolds, "Original", Primary, IsMultiClass);
        else
            Result.CVOriginal.Mean = NaN;
            Result.CVOriginal.Std = NaN;
            Result.CVOriginal.NumFolds = 0;
        end
    else
        % Internal CV suppressed: an outer k-fold (assessKFold) already owns the
        % performance-variance estimate, so re-running CV inside each fold would
        % be redundant. Emit the same struct shape with a skipped marker.
        Result.CV = struct(Mean = NaN, Std = NaN, NumFolds = 0);
        Result.CVOriginal = struct(Mean = NaN, Std = NaN, NumFolds = 0);
    end
end


function [Families, Primary] = resolvePanel(TargetModel)
%resolvePanel Map TargetModel to the ordered family panel and its primary lens.
%   A declared family evaluates through that family ALONE — the user named their
%   downstream model, so a reference lens adds nothing. Only "agnostic" spans the
%   full panel (all three families), scoring the one engineered set through every
%   lens because no single model is assumed.
    switch TargetModel
        case "tree_ensemble"
            Families = "bag";
            Primary = "bag";
        case "linear"
            Families = "linear";
            Primary = "linear";
        case "kernel_distance"
            Families = "kernel";
            Primary = "kernel";
        otherwise  % "agnostic"
            Families = ["bag", "linear", "kernel"];
            Primary = "bag";
    end
end


function Primary = applyPrimaryOverride(Primary, TargetModel, PrimaryFamily)
%applyPrimaryOverride Let the caller name which trained family is primary.
%   PrimaryFamily "auto" (default) keeps the TargetModel-derived primary. A named
%   family promotes that family to primary — the lens whose metrics become the
%   top-level fields and whose fit drives internal CV. The override is meaningful
%   ONLY for "agnostic", the one panel that trains all three families and so has a
%   free choice of lens; there it lets a user keep the broad panel yet headline
%   (and CV) on linear or kernel. A declared single-family TargetModel trains that
%   family alone, so its primary is fixed — naming any PrimaryFamily under it is an
%   error, since there is no other trained row to promote.
    if PrimaryFamily == "auto"
        return
    end
    if TargetModel ~= "agnostic"
        error('baselineComparison:primaryNotTrained', ...
            ['PrimaryFamily is tunable only when TargetModel="agnostic" (which ' ...
            'trains all three families). Under TargetModel="%s" only the "%s" ' ...
            'family is trained, so its primary lens is fixed. Leave PrimaryFamily ' ...
            'at "auto", or set TargetModel="agnostic" to choose a lens.'], ...
            TargetModel, Primary);
    end
    Primary = PrimaryFamily;
end


function FR = runHoldoutFamily(Family, OrigX, EngX, ResponseCol, TrainIdx, ValIdx, ProblemType, ImbalanceRatio, IsMultiClass)
%runHoldoutFamily Three-way holdout comparison for a single model family.
    FR = emptyFamilyResult(ProblemType, ImbalanceRatio, ResponseCol, TrainIdx);
    FR.Family = Family;

    fprintf('\nBaseline Signal Test (%s — holdout):\n', familyLabel(Family));

    TrainY = ResponseCol(TrainIdx);
    ValY = ResponseCol(ValIdx);

    [EngDesign, ~] = getFamilyDesign(EngX, Family, TrainIdx);
    [OrigDesign, ~] = getFamilyDesign(OrigX, Family, TrainIdx);
    HasOrig = ~isempty(OrigX);

    if ProblemType == "classification"
        FR.Naive = 0.5;
        FR.Metric = "auc";

        MdlEng = fitFamily(Family, EngDesign(TrainIdx,:), TrainY, ProblemType, IsMultiClass);
        [PredEng, ScoresEng] = predict(MdlEng, EngDesign(ValIdx,:));
        [FR.Engineered, FR.MacroF1.Engineered] = aucAndF1(ValY, ScoresEng, MdlEng.ClassNames);
        EngAcc = sum(categorical(PredEng) == categorical(ValY)) / numel(ValY);

        if HasOrig
            MdlOrig = fitFamily(Family, OrigDesign(TrainIdx,:), TrainY, ProblemType, IsMultiClass);
            [PredOrig, ScoresOrig] = predict(MdlOrig, OrigDesign(ValIdx,:));
            [FR.Original, FR.MacroF1.Original] = aucAndF1(ValY, ScoresOrig, MdlOrig.ClassNames);
            OrigAcc = sum(categorical(PredOrig) == categorical(ValY)) / numel(ValY);
        else
            OrigAcc = NaN;
        end

        if isnan(ImbalanceRatio)
            ClassCounts = countcats(categorical(TrainY));
            ImbalanceRatio = max(ClassCounts) / max(min(ClassCounts), 1);
        end

        FR.Improvement = FR.Engineered - FR.Original;
        FR.OriginalPassedNaive = FR.Original > FR.Naive;
        FR.EngineeredPassedNaive = FR.Engineered > FR.Naive;
        FR.EngineeredBeatOriginal = FR.Engineered > FR.Original;

        % Accuracy is always reported; AccuracyReliable flags whether a raw
        % hit-rate is trustworthy at this class balance (ratio <= 1.5:1). Above
        % that a majority-only classifier already scores well, so the number is
        % kept but the reader is cautioned rather than having it hidden.
        FR.Accuracy.Original = OrigAcc;
        FR.Accuracy.Engineered = EngAcc;
        FR.AccuracyReliable = ImbalanceRatio <= 1.5;
    else
        FR.Naive = sqrt(mean((mean(TrainY) - ValY).^2));
        FR.Metric = "rmse";

        MdlEng = fitFamily(Family, EngDesign(TrainIdx,:), TrainY, ProblemType, IsMultiClass);
        PredEng = predict(MdlEng, EngDesign(ValIdx,:));
        FR.Engineered = sqrt(mean((PredEng - ValY).^2));

        if HasOrig
            MdlOrig = fitFamily(Family, OrigDesign(TrainIdx,:), TrainY, ProblemType, IsMultiClass);
            PredOrig = predict(MdlOrig, OrigDesign(ValIdx,:));
            FR.Original = sqrt(mean((PredOrig - ValY).^2));
        end

        FR.Improvement = FR.Original - FR.Engineered;
        FR.OriginalPassedNaive = FR.Original < FR.Naive;
        FR.EngineeredPassedNaive = FR.Engineered < FR.Naive;
        FR.EngineeredBeatOriginal = FR.Engineered < FR.Original;
    end

    fprintf('  Naive predictor:       %s = %.3f\n', FR.Metric, FR.Naive);
    if ~isnan(FR.Original)
        fprintf('  Original features:     %s = %.3f\n', FR.Metric, FR.Original);
    end
    fprintf('  Engineered features:   %s = %.3f\n', FR.Metric, FR.Engineered);
    if ~isnan(FR.Original)
        fprintf('  Improvement (eng-orig): %+.3f\n', FR.Improvement);
    end
    if ProblemType == "classification"
        fprintf('  Macro F1 (supplementary): orig=%.3f, eng=%.3f\n', FR.MacroF1.Original, FR.MacroF1.Engineered);
        if FR.AccuracyReliable
            fprintf('  Accuracy (supplementary): orig=%.3f, eng=%.3f\n', FR.Accuracy.Original, FR.Accuracy.Engineered);
        else
            fprintf(['  Accuracy (supplementary): orig=%.3f, eng=%.3f ' ...
                '(imbalanced %.1f:1 - unreliable; prefer AUC / macro-F1)\n'], ...
                FR.Accuracy.Original, FR.Accuracy.Engineered, ImbalanceRatio);
        end
    end

    FR.Passed = FR.EngineeredPassedNaive;
    FR.Model = MdlEng;
end


function FR = emptyFamilyResult(ProblemType, ImbalanceRatio, ResponseCol, TrainIdx)
%emptyFamilyResult Fixed-field template so the Panel struct array stays uniform.
    FR.Family = "";
    FR.Metric = "";
    FR.Naive = NaN;
    FR.Original = NaN;
    FR.Engineered = NaN;
    FR.Improvement = NaN;
    FR.OriginalPassedNaive = false;
    FR.EngineeredPassedNaive = false;
    FR.EngineeredBeatOriginal = false;
    FR.Passed = false;
    FR.Skipped = false;
    FR.Reasoning = "";
    FR.Model = [];
    if ProblemType == "classification"
        FR.MacroF1.Original = NaN;
        FR.MacroF1.Engineered = NaN;
        % Accuracy is always present; AccuracyReliable (set per fit) tells the
        % reader whether to trust it at the run's class balance.
        FR.Accuracy.Original = NaN;
        FR.Accuracy.Engineered = NaN;
        FR.AccuracyReliable = accuracyReliable(ImbalanceRatio, ResponseCol, TrainIdx);
    end
end


function Tf = accuracyReliable(ImbalanceRatio, ResponseCol, TrainIdx)
%accuracyReliable Whether a raw hit-rate is trustworthy (ratio <= 1.5:1).
    if isnan(ImbalanceRatio)
        ClassCounts = countcats(categorical(ResponseCol(TrainIdx)));
        ImbalanceRatio = max(ClassCounts) / max(min(ClassCounts), 1);
    end
    Tf = ImbalanceRatio <= 1.5;
end


function [Design, Usable] = getFamilyDesign(X, Family, TrainIdx) %#ok<INUSD>
%getFamilyDesign Prepare a family's design matrix.
%   Every family takes the predictors as-is: bagged ensembles handle categoricals
%   natively, and the linear/kernel learners auto-encode categorical columns when
%   given a table. No scaling is applied here -- engineered features arrive
%   already standardized from the generator's transformer, and originals are
%   scored raw -- so this is now a pass-through. Family and TrainIdx are retained
%   in the signature for call-site symmetry with the former design-matrix path.
    Usable = true;
    Design = X;
end


function Tf = isMultiClassResponse(ResponseCol, TrainIdx, ProblemType)
%isMultiClassResponse True when the training response carries three or more
%   classes. Regression is never multi-class. Counting on the full training
%   response (not per fit) keeps the linear/kernel learner choice consistent.
    if ProblemType ~= "classification"
        Tf = false;
        return
    end
    TrainY = ResponseCol(TrainIdx);
    Tf = numel(categories(removecats(categorical(TrainY)))) > 2;
end


function Mdl = fitFamily(Family, X, Y, ProblemType, IsMultiClass)
%fitFamily Train one model family for the given problem type.
%   The linear and kernel classification learners are binary-only. When the
%   response has three or more classes (IsMultiClass), they are wrapped in a
%   one-vs-one ECOC whose binary learner is the declared family, so
%   "linear"/"kernel" still drives the fit and predict returns a per-class
%   score matrix (ECOC NegLoss) that aucAndF1 consumes exactly like the binary
%   two-column scores. IsMultiClass is decided once from the full training
%   response, so the learner choice is stable across every fit (holdout and CV
%   folds alike).
    if ProblemType == "classification"
        switch Family
            case "linear"
                if IsMultiClass
                    Mdl = fitcecoc(X, Y, Learners=templateLinear());
                else
                    Mdl = fitclinear(X, Y);
                end
            case "kernel"
                if IsMultiClass
                    Mdl = fitcecoc(X, Y, Learners=templateKernel(KernelScale="auto"));
                else
                    Mdl = fitckernel(X, Y, KernelScale="auto");
                end
            otherwise
                Mdl = fitcensemble(X, Y, Method="Bag");
        end
    else
        switch Family
            case "linear"
                Mdl = fitrlinear(X, Y);
            case "kernel"
                Mdl = fitrkernel(X, Y, KernelScale="auto");
            otherwise
                Mdl = fitrensemble(X, Y, Method="Bag");
        end
    end
end


function Label = familyLabel(Family)
    switch Family
        case "linear"
            Label = "Linear";
        case "kernel"
            Label = "Kernel (KernelScale=auto)";
        otherwise
            Label = "Random Forest";
    end
end


function CV = runInternalCV(FeatureX, ResponseCol, TrainIdx, ProblemType, SplitMethod, K, Label, Family, IsMultiClass)
    if nargin < 7, Label = "Engineered"; end
    if nargin < 8, Family = "bag"; end
    if nargin < 9, IsMultiClass = false; end
    N = numel(TrainIdx);

    [Design, ~] = getFamilyDesign(FeatureX, Family, TrainIdx);
    if N < 50
        CV.Mean = NaN;
        CV.Std = NaN;
        CV.NumFolds = 0;
        fprintf('  Internal CV (%s): skipped (fewer than 50 training rows)\n', Label);
        return;
    end

    TrainX = Design(TrainIdx, :);
    TrainResponse = ResponseCol(TrainIdx);

    if SplitMethod == "stratified_holdout" && ProblemType == "classification"
        CVP = cvpartition(TrainResponse, KFold=K);
    else
        CVP = cvpartition(N, KFold=K);
    end
    CVMetrics = zeros(K, 1);
    for k = 1:K
        CVTrain = find(training(CVP, k));
        CVVal = find(test(CVP, k));
        CVMetrics(k) = trainAndScore(TrainX, TrainResponse, CVTrain, CVVal, ProblemType, Family, IsMultiClass);
    end

    CV.Mean = mean(CVMetrics);
    CV.Std = std(CVMetrics);
    CV.NumFolds = K;
    fprintf('  Internal CV %s (%d-fold): %.3f +/- %.3f\n', Label, K, CV.Mean, CV.Std);
end


function Score = trainAndScore(X, Y, TrainRows, ValRows, ProblemType, Family, IsMultiClass)
    if nargin < 6, Family = "bag"; end
    if nargin < 7, IsMultiClass = false; end
    Mdl = fitFamily(Family, X(TrainRows, :), Y(TrainRows), ProblemType, IsMultiClass);
    if ProblemType == "classification"
        [~, Scores] = predict(Mdl, X(ValRows, :));
        [Score, ~] = aucAndF1(Y(ValRows), Scores, Mdl.ClassNames);
    else
        Pred = predict(Mdl, X(ValRows, :));
        Score = sqrt(mean((Pred - Y(ValRows)).^2));
    end
end


function X = extractPredictors(Data, PredVars)
    if isempty(PredVars)
        X = [];
        return;
    end
    if istable(Data)
        X = Data(:, PredVars);
    else
        X = Data;
    end
end


function [AUC, F1] = aucAndF1(TrueY, Scores, ClassNames)
    RocObj = rocmetrics(TrueY, Scores, ClassNames, AdditionalMetrics="f1score");
    [~, ~, ~, AUC] = average(RocObj, "macro");
    F1PerClass = groupsummary(RocObj.Metrics, "ClassName", "max", "F1Score");
    F1 = mean(F1PerClass.max_F1Score, 'omitnan');
end
