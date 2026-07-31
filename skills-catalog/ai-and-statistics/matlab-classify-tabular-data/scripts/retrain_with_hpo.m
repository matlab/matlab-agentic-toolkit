function mdl = retrain_with_hpo(modelDef, X, Y, useUniformPrior)
% RETRAIN_WITH_HPO  Retrain a modelDef with single-shot HPO on X, Y.
%
%   MDL = RETRAIN_WITH_HPO(MODELDEF, X, Y, USEUNIFORMPRIOR) calls the
%   fitc* function baked into MODELDEF.fnName with
%   'OptimizeHyperparameters','auto' and returns a deployable trained
%   model. This is the single-shot HPO used by workflow-script export —
%   the nested-CV design in the skill's Step 11 does not produce a
%   single deployable set of hyperparameters, so the exported workflow
%   re-runs HPO on the full training set instead. Users should expect
%   the estimated accuracy from the skill run to be a slight
%   overestimate for this configuration.
%
%   For ECOC models (fnName == 'fitcecoc'), the 'Coding' argument is
%   omitted so the optimizer searches over coding designs. The inner
%   learner template is passed via 'Learners'.

    arguments
        modelDef (1,1) struct
        X
        Y
        useUniformPrior (1,1) logical = false
    end

    priorNV = prior_nv(useUniformPrior);
    hpoNV = {'OptimizeHyperparameters', 'auto', ...
             'HyperparameterOptimizationOptions', ...
             struct('ShowPlots', false, 'Verbose', 0)};

    switch modelDef.fnName
        case 'fitcecoc'
            innerFn = modelDef.innerLearner_fnName;
            innerArgs = struct_to_nv(modelDef.innerLearner_hyperparameters);
            if template_needs_type(innerFn)
                innerArgs = [innerArgs, {'Type','classification'}];
            end
            innerTmpl = feval(innerFn, innerArgs{:});
            mdl = fitcecoc(X, Y, 'Learners', innerTmpl, ...
                priorNV{:}, hpoNV{:});
        case 'fitcensemble'
            argsNV = struct_to_nv(modelDef.hyperparameters);
            mdl = fitcensemble(X, Y, argsNV{:}, priorNV{:}, hpoNV{:});
        otherwise
            argsNV = struct_to_nv(modelDef.hyperparameters);
            mdl = feval(modelDef.fnName, X, Y, argsNV{:}, priorNV{:}, hpoNV{:});
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
