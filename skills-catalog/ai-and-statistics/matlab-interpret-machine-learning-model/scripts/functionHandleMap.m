function map = functionHandleMap(mdl)
%functionHandleMap  For a given model, how must it be passed to each
%   interpretability function.
%
%   MAP = functionHandleMap(MDL) returns a table with one row per function:
%       Function            - name of the interpretability function
%       NeedsFunctionHandle - for THIS model:
%                               "no"            built-in model works directly
%                               "yes"           must be wrapped as a handle
%                               "not supported" cannot be used with MDL at all
%
%   Model matching uses documented (short) class names. A full model has its
%   Compact* class as a superclass (e.g. ClassificationSVM is a
%   CompactClassificationSVM), so listing the compact short name matches both
%   the full and compact forms. NOTE: isa() with an unqualified short name
%   does NOT see packaged superclasses, so matching is done against the
%   package-stripped class + superclass names of MDL instead of isa().
%
%   Example:
%       load fisheriris
%       svm = fitcsvm(meas(1:100,:), species(1:100));
%       functionHandleMap(svm)

%   Copyright 2026 The MathWorks, Inc.

    isHandle = isa(mdl, "function_handle");

    % Package-stripped class + superclass names of MDL (empty for a handle).
    if isHandle
        hierarchy = strings(0,1);
    else
        hierarchy = string(regexprep([{class(mdl)}; superclasses(mdl)], '.*\.', ''));
    end

    % Documented built-in classes accepted directly, by group (compact names).
    classif = ["CompactClassificationTree" "CompactClassificationSVM" ...
        "CompactClassificationEnsemble" "CompactClassificationDiscriminant" ...
        "CompactClassificationNaiveBayes" "CompactClassificationNeuralNetwork" ...
        "CompactClassificationGAM" "CompactClassificationECOC" ...
        "CompactClassificationXGBoost" "ClassificationKNN" ...
        "ClassificationLinear" "ClassificationKernel"];
    regr = ["CompactRegressionTree" "CompactRegressionSVM" ...
        "CompactRegressionEnsemble" "CompactRegressionGP" "CompactRegressionGAM" ...
        "CompactRegressionNeuralNetwork" "CompactRegressionXGBoost" ...
        "RegressionLinear" "RegressionKernel"];
    statsRegr = ["CompactLinearModel" "CompactGeneralizedLinearModel" ...
        "NonLinearModel" "LinearMixedModel" "GeneralizedLinearMixedModel"];
    bagger = ["TreeBagger" "CompactTreeBagger"];

    isClassif = iAny(hierarchy, classif);
    isRegr    = iAny(hierarchy, regr);
    isPD      = isClassif || isRegr || iAny(hierarchy, statsRegr) || iAny(hierarchy, bagger);
    isCF      = isClassif && ~iAny(hierarchy, "CompactClassificationECOC") && iBinary(mdl);

    % Registry: {function, supportsHandle, isBuiltInForThisModel}
    reg = {
        "counterfactuals"       , false, isCF
        "lime"                  , true , isClassif || isRegr
        "shapley"               , true , isClassif || isRegr
        "partialDependence"     , true , isPD
        "plotPartialDependence" , true , isPD
        "permutationImportance" , false, isClassif || isRegr
        };

    n = size(reg, 1);
    name  = strings(n,1);
    needs = strings(n,1);
    for k = 1:n
        name(k)        = reg{k,1};
        supportsHandle = reg{k,2};
        isBuiltIn      = reg{k,3};
        if isBuiltIn
            needs(k) = "no";                        % built-in works directly
        elseif supportsHandle
            needs(k) = "yes";                       % wrap as a handle
        else
            needs(k) = "not supported";             % cannot use this model
        end
        if isHandle && supportsHandle
            needs(k) = "no";                        % already a handle
        end
    end

    map = table(name, needs, ...
        'VariableNames', {'Function','NeedsFunctionHandle'});
end

function tf = iAny(hierarchy, classes)
    tf = any(ismember(classes, hierarchy));
end

function tf = iBinary(mdl)
    tf = isprop(mdl, "ClassNames") && numel(mdl.ClassNames) == 2;
end
