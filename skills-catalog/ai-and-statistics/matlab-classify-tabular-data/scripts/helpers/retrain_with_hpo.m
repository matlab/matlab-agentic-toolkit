function mdl = retrain_with_hpo(modelDef, X, Y, useUniformPrior, options)
% RETRAIN_WITH_HPO  Retrain a modelDef with single-shot HPO on X, Y.
%
%   MDL = RETRAIN_WITH_HPO(MODELDEF, X, Y, USEUNIFORMPRIOR) calls the
%   fitc* function baked into MODELDEF.fnName with
%   'OptimizeHyperparameters' and returns a deployable trained model. This
%   is the single-shot HPO used by workflow-script export and by
%   save_selected_models for models optimized on the CV path — the
%   nested-CV design in the skill's Step 11 does not produce a single
%   deployable set of hyperparameters, so HPO is re-run on the full
%   training set instead. Users should expect the estimated accuracy from
%   the skill run to be a slight overestimate for this configuration.
%
%   What is searched follows references/hpo.md:
%     - ECOC (fitcecoc): 'auto' with the model's own inner learner as
%       'Learners'; 'Coding' is omitted so the coding design is searched.
%     - Ensembles (fitcensemble): 'auto' with the model's own inner learner
%       as 'Learners' (it keeps, e.g., the trees' MaxNumSplits); Method,
%       NumLearningCycles and LearnRate are searched, so they are not passed.
%     - Quadratic discriminants (fitcdiscr with a quadratic DiscrimType):
%       {'DiscrimType','Gamma'}. 'auto' searches Delta, which a quadratic
%       discriminant does not have, and every evaluation fails.
%     - Everything else: 'auto' with the model's own settings.
%
%   MDL = RETRAIN_WITH_HPO(..., 'MaxObjectiveEvaluations', N) limits the
%   search (default 30, the bayesopt default).

    arguments
        modelDef (1,1) struct
        X
        Y
        useUniformPrior (1,1) logical = false
        options.MaxObjectiveEvaluations (1,1) double {mustBePositive, mustBeInteger} = 30
    end

    priorNV = prior_nv(useUniformPrior);
    hpoOpts = struct('ShowPlots', false, 'Verbose', 1, ...
        'MaxObjectiveEvaluations', options.MaxObjectiveEvaluations);
    autoNV = {'OptimizeHyperparameters', 'auto', ...
              'HyperparameterOptimizationOptions', hpoOpts};

    fprintf(1, 'HPO retrain of %s started (%d evaluations)\n', ...
        modelDef.name, options.MaxObjectiveEvaluations);
    t0 = tic;

    switch modelDef.fnName
        case 'fitcecoc'
            mdl = fitcecoc(X, Y, 'Learners', model_inner_template(modelDef), ...
                priorNV{:}, autoNV{:});
        case 'fitcensemble'
            mdl = fitcensemble(X, Y, 'Learners', model_inner_template(modelDef), ...
                priorNV{:}, autoNV{:});
        case 'fitcdiscr'
            args = modelDef.hyperparameters;
            if isfield(args, 'DiscrimType') && contains(lower(args.DiscrimType), 'quadratic')
                args = rmfield(args, 'DiscrimType');
                argsNV = struct_to_nv(args);
                mdl = fitcdiscr(X, Y, argsNV{:}, priorNV{:}, ...
                    'OptimizeHyperparameters', {'DiscrimType', 'Gamma'}, ...
                    'HyperparameterOptimizationOptions', hpoOpts);
            else
                argsNV = struct_to_nv(args);
                mdl = fitcdiscr(X, Y, argsNV{:}, priorNV{:}, autoNV{:});
            end
        otherwise
            argsNV = struct_to_nv(modelDef.hyperparameters);
            mdl = feval(modelDef.fnName, X, Y, argsNV{:}, priorNV{:}, autoNV{:});
    end
    fprintf(1, 'HPO retrain of %s finished in %.1f s\n', modelDef.name, toc(t0));

    if nargout == 0
        clear mdl
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

% Copyright 2026 The MathWorks, Inc.
