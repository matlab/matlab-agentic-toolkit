function mdl = retrain_with_resume(modelDef, X, Y, extraCycles, useUniformPrior)
% RETRAIN_WITH_RESUME  Retrain an ensemble modelDef with extra learning cycles.
%
%   MDL = RETRAIN_WITH_RESUME(MODELDEF, X, Y, EXTRACYCLES, USEUNIFORMPRIOR)
%   is used by workflow-script export to reproduce the effect of the
%   Step 10 "Boosting learning curve" resume on new data. Instead of
%   fit + resume (which requires a partially-trained model), it trains
%   in one shot with NumLearningCycles = baseCycles + extraCycles.
%
%   Only meaningful for MODELDEF.fnName == 'fitcensemble'. For any
%   other fnName the function errors.

    arguments
        modelDef (1,1) struct
        X
        Y
        extraCycles (1,1) double
        useUniformPrior (1,1) logical = false
    end

    if ~strcmp(modelDef.fnName, 'fitcensemble')
        error('retrain_with_resume:notEnsemble', ...
            'retrain_with_resume only applies to fitcensemble recipes; got %s.', modelDef.fnName);
    end

    args = modelDef.hyperparameters;
    if ~isfield(args, 'NumLearningCycles')
        error('retrain_with_resume:noBaseCycles', ...
            'Ensemble modelDef is missing NumLearningCycles.');
    end
    args.NumLearningCycles = args.NumLearningCycles + extraCycles;

    priorNV = prior_nv(useUniformPrior);
    argsNV  = struct_to_nv(args);

    if ~isempty(modelDef.innerLearner_fnName)
        innerNV = struct_to_nv(modelDef.innerLearner_hyperparameters);
        if template_needs_type(modelDef.innerLearner_fnName)
            innerNV = [innerNV, {'Type','classification'}];
        end
        innerTmpl = feval(modelDef.innerLearner_fnName, innerNV{:});
        mdl = fitcensemble(X, Y, argsNV{:}, 'Learners', innerTmpl, priorNV{:});
    else
        mdl = fitcensemble(X, Y, argsNV{:}, priorNV{:});
    end
end

% -------------------------------------------------------------------------
function nv = prior_nv(useUniformPrior)
    if useUniformPrior
        nv = {'Prior','uniform'};
    else
        nv = {};
    end
end

% -------------------------------------------------------------------------
function nv = struct_to_nv(s)
    fns = fieldnames(s);
    nv = cell(1, 2*numel(fns));
    for k = 1:numel(fns)
        nv{2*k-1} = fns{k};
        nv{2*k}   = s.(fns{k});
    end
end

% -------------------------------------------------------------------------
function tf = template_needs_type(templateFn)
    tf = ismember(templateFn, {'templateTree','templateSVM','templateLinear', ...
        'templateKernel','templateGAM'});
end

% Copyright 2026 The MathWorks, Inc.
