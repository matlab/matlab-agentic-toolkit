function [RankedIdx, Scores] = rankFeatures(TrainX, TrainY, Method, Options)
%rankFeatures Unified supervised feature ranking via SMLT methods.
%   Accepts table input (with mixed numeric/categorical columns) for methods
%   that support it natively (fscmrmr, fscnca, fsrnca, permutation,
%   predictorImportance, sequentialfs). Methods requiring numeric-only input
%   (lasso, relieff, chi2, ftest, stepwiselm, stepwiseglm) extract numeric
%   columns automatically.

% Copyright 2026 The MathWorks, Inc.
    arguments
        TrainX
        TrainY (:,1)
        Method (1,1) string {mustBeMember(Method, ...
            ["fscmrmr","fsrmrmr","relieff","fscnca","fsrnca","lasso", ...
             "chi2","ftest","sequentialfs","permutation", ...
             "predictorImportance","stepwiselm","stepwiseglm"])}
        Options.ProblemType (1,1) string {mustBeMember(Options.ProblemType, ...
            ["classification","regression"])} = "classification"
        Options.MethodOptions (1,1) struct = struct()
    end

    ProblemType = Options.ProblemType;
    NVPairs = namedargs2cell(Options.MethodOptions);

    NeedsNumeric = ismember(Method, ["relieff","lasso","chi2","ftest","stepwiselm","stepwiseglm","fsrmrmr"]);
    if NeedsNumeric && istable(TrainX)
        TrainX = TrainX(:, vartype("numeric"));
    end

    if istable(TrainX)
        p = width(TrainX);
    else
        p = size(TrainX, 2);
    end

    switch Method
        case "fscmrmr"
            [Idx, Scores] = fscmrmr(TrainX, TrainY);
            RankedIdx = Idx;

        case "fsrmrmr"
            [Idx, Scores] = fsrmrmr(TrainX, TrainY);
            RankedIdx = Idx;

        case "relieff"
            K = 10;
            if isfield(Options.MethodOptions, 'NumNeighbors')
                K = Options.MethodOptions.NumNeighbors;
            end
            [RankedIdx, Weights] = relieff(TrainX, TrainY, K);
            Scores = zeros(1, p);
            Scores(RankedIdx) = Weights;

        case "fscnca"
            Mdl = fscnca(TrainX, TrainY, NVPairs{:}, Verbose=0);
            Scores = Mdl.FeatureWeights';
            [~, RankedIdx] = sort(Scores, 'descend');

        case "fsrnca"
            Mdl = fsrnca(TrainX, TrainY, NVPairs{:}, Verbose=0);
            Scores = Mdl.FeatureWeights';
            [~, RankedIdx] = sort(Scores, 'descend');

        case "lasso"
            if ProblemType == "classification"
                Classes = categories(categorical(TrainY));
                nClasses = numel(Classes);
                ClassScores = zeros(nClasses, p);
                for k = 1:nClasses
                    Yk = categorical(TrainY) == Classes{k};
                    [B, FitInfo] = lassoglm(TrainX, Yk, 'binomial', NVPairs{:}, CV=5);
                    ClassScores(k, :) = abs(B(:, FitInfo.Index1SE))';
                end
                Scores = max(ClassScores, [], 1);
            else
                [B, FitInfo] = lasso(TrainX, double(TrainY), NVPairs{:}, CV=5);
                Scores = abs(B(:, FitInfo.Index1SE))';
            end
            [~, RankedIdx] = sort(Scores, 'descend');

        case "chi2"
            [Idx, Scores] = fscchi2(TrainX, TrainY);
            RankedIdx = Idx;

        case "ftest"
            [Idx, Scores] = fsrftest(TrainX, TrainY);
            RankedIdx = Idx;

        case "sequentialfs"
            if ProblemType == "classification"
                Criterion = @(XTr, YTr, XTe, YTe) ...
                    loss(fitcensemble(XTr, YTr, Method="Bag", NumLearningCycles=30), XTe, YTe);
            else
                Criterion = @(XTr, YTr, XTe, YTe) ...
                    loss(fitrensemble(XTr, YTr, Method="Bag", NumLearningCycles=30), XTe, YTe);
            end
            Selected = sequentialfs(Criterion, TrainX, TrainY, NVPairs{:});
            Scores = scoreSelectedSubset(TrainX, TrainY, Selected, ProblemType, p);
            [~, RankedIdx] = sort(Scores, 'descend');

        case "permutation"
            if ProblemType == "classification"
                Mdl = fitcensemble(TrainX, TrainY, NVPairs{:}, Method="Bag");
            else
                Mdl = fitrensemble(TrainX, TrainY, NVPairs{:}, Method="Bag");
            end
            Imp = oobPermutedPredictorImportance(Mdl);
            Scores = Imp;
            [~, RankedIdx] = sort(Scores, 'descend');

        case "predictorImportance"
            if ProblemType == "classification"
                Tree = fitctree(TrainX, TrainY, NVPairs{:});
            else
                Tree = fitrtree(TrainX, TrainY, NVPairs{:});
            end
            Scores = predictorImportance(Tree);
            [~, RankedIdx] = sort(Scores, 'descend');

        case "stepwiselm"
            Mdl = stepwiselm(TrainX, double(TrainY), NVPairs{:}, Verbose=0);
            Selected = Mdl.VariableInfo.InModel';
            Scores = scoreSelectedSubset(TrainX, TrainY, Selected, ProblemType, p);
            [~, RankedIdx] = sort(Scores, 'descend');

        case "stepwiseglm"
            if ProblemType == "classification"
                Classes = categories(categorical(TrainY));
                nClasses = numel(Classes);
                Selected = false(1, p);
                for k = 1:nClasses
                    Yk = double(categorical(TrainY) == Classes{k});
                    Mdl = stepwiseglm(TrainX, Yk, NVPairs{:}, ...
                        Distribution="binomial", Verbose=0);
                    InModel = Mdl.VariableInfo.InModel;
                    Selected = Selected | InModel(1:p)';
                end
            else
                Mdl = stepwiseglm(TrainX, double(TrainY), NVPairs{:}, Verbose=0);
                InModel = Mdl.VariableInfo.InModel;
                Selected = InModel(1:p)';
            end
            Scores = scoreSelectedSubset(TrainX, TrainY, Selected, ProblemType, p);
            [~, RankedIdx] = sort(Scores, 'descend');
    end

    RankedIdx = RankedIdx(:)';
    Scores = Scores(:)';
end


function Scores = scoreSelectedSubset(TrainX, TrainY, Selected, ProblemType, p)
    SelIdx = find(Selected);
    SelX = TrainX(:, SelIdx);

    if ProblemType == "regression"
        [~, SubScores] = fsrftest(SelX, TrainY);
    else
        [~, SubScores] = fscchi2(SelX, TrainY);
    end

    Scores = zeros(1, p);
    Scores(SelIdx) = SubScores;
end
