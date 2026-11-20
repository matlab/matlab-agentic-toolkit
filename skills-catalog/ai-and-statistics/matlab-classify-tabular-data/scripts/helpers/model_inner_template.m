function tmpl = model_inner_template(modelDef)
%MODEL_INNER_TEMPLATE  The inner-learner template of a modelDefs entry.
%
%   TMPL = MODEL_INNER_TEMPLATE(MODELDEF) builds the template named by
%   MODELDEF.innerLearner_fnName with MODELDEF.innerLearner_hyperparameters,
%   typed for classification where the template needs it, the same way
%   build_model_definitions builds it. Pass it as 'Learners' when
%   optimizing an ECOC or ensemble model, so the search keeps the model's
%   own learner (e.g. a Gaussian-kernel SVM, or trees with MaxNumSplits 10)
%   instead of the default one.
    if isempty(modelDef.innerLearner_fnName)
        error('model_inner_template:noInnerLearner', ...
            '%s has no inner learner (innerLearner_fnName is empty).', modelDef.name);
    end
    innerFn = modelDef.innerLearner_fnName;
    s = modelDef.innerLearner_hyperparameters;
    fns = fieldnames(s);
    nv = cell(1, 2*numel(fns));
    for k = 1:numel(fns)
        nv{2*k-1} = fns{k};
        nv{2*k}   = s.(fns{k});
    end
    % Same list as build_model_definitions/template_needs_type.
    if ismember(innerFn, {'templateTree','templateSVM','templateLinear', ...
            'templateKernel','templateGAM','templateNeuralNetwork'})
        nv = [nv, {'Type', 'classification'}];
    end
    tmpl = feval(innerFn, nv{:});

    if nargout == 0
        clear tmpl
    end
end

% Copyright 2026 The MathWorks, Inc.
