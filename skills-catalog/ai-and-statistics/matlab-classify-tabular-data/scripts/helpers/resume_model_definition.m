function modelDef = resume_model_definition(modelDef, nMoreCycles, useUniformPrior)
%RESUME_MODEL_DEFINITION  Update an ensemble's modelDefs entry after a boosting resume.
%
%   DEF = RESUME_MODEL_DEFINITION(DEF, NMORECYCLES, USEUNIFORMPRIOR) returns
%   the modelDefs entry DEF with NumLearningCycles increased by NMORECYCLES,
%   and its .template, .cvFitFcn and .fitFcn rebuilt to match. Call it right
%   after resume_boosting_cv or resume_boosting_holdout, passing the same
%   NMORECYCLES, so that every later use of the entry refers to the model
%   that was evaluated:
%     - the CV-path pairwise comparison, which refits from .template
%       (compute_pairwise_pvalues_cv);
%     - save_selected_models, which retrains a CV model from .fitFcn.
%   USEUNIFORMPRIOR must match the run's prior (it is baked into the fit
%   functions, as in build_model_definitions).
%
%   The rebuilt fields are built exactly as build_model_definitions builds
%   an ensemble entry (fitcensemble name-value form, inner template typed
%   for classification), so with NMORECYCLES = 0 they train the same models.
%   Only meaningful for fnName == 'fitcensemble'; other entries error.
    arguments
        modelDef (1,1) struct
        nMoreCycles (1,1) double {mustBeInteger, mustBeNonnegative}
        useUniformPrior (1,1) logical = false
    end
    if ~strcmp(modelDef.fnName, 'fitcensemble') || ~isfield(modelDef.hyperparameters, 'NumLearningCycles')
        error('resume_model_definition:notEnsemble', ...
            'resume_model_definition only applies to fitcensemble entries with NumLearningCycles; got %s.', ...
            modelDef.fnName);
    end

    args = modelDef.hyperparameters;
    args.NumLearningCycles = args.NumLearningCycles + nMoreCycles;
    modelDef.hyperparameters = args;

    innerFn = modelDef.innerLearner_fnName;
    innerNV = struct_to_nv(modelDef.innerLearner_hyperparameters);
    if ~isempty(innerFn) && template_needs_type(innerFn)
        innerNV = [innerNV, {'Type', 'classification'}];
    end
    priorNV = {};
    if useUniformPrior
        priorNV = {'Prior', 'uniform'};
    end
    argsNV = struct_to_nv(args);

    if isempty(innerFn)
        % Every ensemble recipe in the catalog has an inner learner.
        error('resume_model_definition:noInnerLearner', ...
            '%s has no innerLearner_fnName; ensemble entries are built with one.', modelDef.name);
    end

    innerTmpl = feval(innerFn, innerNV{:});
    extraNV = struct_to_nv(rmfield(args, intersect(fieldnames(args), {'Method', 'NumLearningCycles'})));
    modelDef.template = templateEnsemble(args.Method, args.NumLearningCycles, innerTmpl, ...
        extraNV{:}, 'Type', 'classification');
    modelDef.cvFitFcn = @(X, Y, cv) fitcensemble(X, Y, argsNV{:}, ...
        'Learners', feval(innerFn, innerNV{:}), priorNV{:}, ...
        'CrossVal', 'on', 'CVPartition', cv);
    modelDef.fitFcn = @(X, Y) fitcensemble(X, Y, argsNV{:}, ...
        'Learners', feval(innerFn, innerNV{:}), priorNV{:});

    if nargout == 0
        clear modelDef
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
% Same list as build_model_definitions.
    tf = ismember(templateFn, {'templateTree','templateSVM','templateLinear', ...
        'templateKernel','templateGAM','templateNeuralNetwork'});
end

% Copyright 2026 The MathWorks, Inc.
