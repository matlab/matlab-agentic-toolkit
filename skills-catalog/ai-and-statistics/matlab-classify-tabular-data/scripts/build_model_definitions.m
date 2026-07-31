function modelDefs = build_model_definitions(flags, skillPath, varargin)
% BUILD_MODEL_DEFINITIONS  Assemble the model list for the current dataset.
%
%   DEFS = BUILD_MODEL_DEFINITIONS(FLAGS, SKILLPATH) returns a struct
%   array — one entry per model the caller should train — for the branch
%   matched by FLAGS. Each entry has the fields:
%
%       .name                        char, e.g. 'LinearSVM-OVO'
%       .template                    template* object ready for fit()
%       .cvFitFcn                    function handle (X, Y, cv) -> cv model
%                                     that trains this recipe under
%                                     'CrossVal','on','CVPartition',cv. The
%                                     handle closes over the correct modern
%                                     fitc* signature so callers on the CV
%                                     path never type a fit call by hand.
%       .fitFcn                      function handle (X, Y) -> trained model
%                                     that trains the same recipe WITHOUT
%                                     cross-validation. Used by
%                                     save_selected_models to produce a
%                                     deployable model on the CV path (the
%                                     holdout path already has one), and by
%                                     any downstream "retrain on new data"
%                                     workflow.
%       .fnName                      char, e.g. 'fitcecoc' (for manifest)
%       .hyperparameters             scalar struct of outer args
%       .innerLearner_fnName         char, e.g. 'templateLinear' (or '')
%       .innerLearner_hyperparameters  scalar struct of inner args
%
%   The template is built by:
%     - Dispatching on FLAGS (first-match branch walk over BRANCHES).
%     - Filtering by binaryOnly / condition / interpretability.
%     - Resolving function-valued args via RESOLVE_RECIPE.
%     - For recipes with multiclassECOC=true AND nClasses>=3: emitting
%       TWO entries per recipe — one wrapped in templateECOC with
%       Coding='onevsone' (suffix '-OVO') and one with 'onevsall'
%       (suffix '-OVA'). This rule is not optional; every ECOC-eligible
%       recipe produces both entries.
%     - For ensembles (recipe has an innerLearner_fnName): building the
%       inner template first, then wrapping with templateEnsemble via
%       its positional Method / NumLearningCycles / innerTmpl form.
%     - For every other recipe: feval(templateFn, args...).
%
%   Because the OVO+OVA expansion happens here, callers never need to
%   remember it — the branch table's multiclassECOC flag automatically
%   becomes two trained models. See select-classifiers.md § Multiclass
%   ECOC wrapping for the spec this implements.
%
%   Required FLAGS fields:
%       interp                 char: 'low' | 'high'
%       nClasses               scalar
%       isBinary               logical
%       plus every field referenced by any recipe's condition() and by
%       any function-valued arg (see model_recipe.m).
%
%   Optional name-value pairs:
%       'ImbalancedOverlay'  — struct array from imbalanced_boosting.m.
%                              When provided (and non-empty), the helper
%                              swaps the branch's boosting recipes for
%                              this overlay before filtering. Callers
%                              set this after asking the uniform-prior
%                              question in select-classifiers-imbalanced.md;
%                              the helper does not consult flags.isImbalanced
%                              on its own.
%
%   Notes:
%     - The 'NaiveBayesMN' recipe in the sparse branch is always emitted
%       when the branch matches — the bag-of-tokens user question is a
%       caller concern. If the user declines, drop the corresponding
%       entry from DEFS before training.
%     - The 'Prior' knob is a training-time argument (see
%       train_and_score_holdout / train_and_score_cv), not a recipe
%       field, so it never appears in modelDefs(k).hyperparameters.

    p = inputParser();
    p.addParameter('ImbalancedOverlay', struct('id', {}, 'fnName', {}, ...
        'args', {}, 'innerLearner_fnName', {}, 'innerLearner_args', {}, ...
        'interp', {}, 'binaryOnly', {}, 'multiclassECOC', {}, 'condition', {}));
    % Pre-R2026b has no templateNeuralNetwork — the fitcnet recipe must be
    % expressed as a *trained* ClassificationNeuralNetwork on a tiny slice
    % of the data, which train_and_score_holdout re-trains via fitcnet.
    % Callers on regular-branch datasets pass X and Y so the helper can
    % build that placeholder; on branches that never emit fitcnet (sparse,
    % many_missing, categorical, wide) the args can be omitted.
    p.addParameter('X', []);
    p.addParameter('Y', []);
    % When true, the baked-in cvFitFcn appends 'Prior','uniform' to every
    % fit call. Callers set this on the CV path after asking the uniform-
    % prior question in select-classifiers-imbalanced.md. On the holdout
    % path this flag is ignored — pass useUniformPrior as the 6th argument
    % of train_and_score_holdout instead.
    p.addParameter('UseUniformPrior', false);
    p.parse(varargin{:});
    overlay         = p.Results.ImbalancedOverlay;
    XSeed           = p.Results.X;
    YSeed           = p.Results.Y;
    useUniformPrior = logical(p.Results.UseUniformPrior);

    refDir = fullfile(skillPath, 'references');
    run(fullfile(refDir, 'classifier_branches.m'));  % populates BRANCHES

    branch = pick_branch(BRANCHES, flags);
    recipes = branch.models;

    if ~isempty(overlay)
        recipes = apply_boosting_overlay(recipes, overlay);
    end

    modelDefs = empty_defs();
    for k = 1:numel(recipes)
        r = recipes(k);
        if r.binaryOnly && ~flags.isBinary,       continue; end
        if ~r.condition(flags),                    continue; end
        if ~ismember(flags.interp, r.interp),      continue; end

        r = resolve_recipe(r, flags);

        if r.multiclassECOC && flags.nClasses >= 3
            innerTmpl = build_template(r, XSeed, YSeed);
            innerFn   = fitc_to_template(r.fnName);
            modelDefs(end+1) = ecoc_def(r, innerTmpl, innerFn, 'onevsone', 'OVO', useUniformPrior); %#ok<AGROW>
            modelDefs(end+1) = ecoc_def(r, innerTmpl, innerFn, 'onevsall', 'OVA', useUniformPrior); %#ok<AGROW>
        else
            modelDefs(end+1) = plain_def(r, XSeed, YSeed, useUniformPrior); %#ok<AGROW>
        end
    end
end

% -------------------------------------------------------------------------
function b = pick_branch(BRANCHES, flags)
    for k = 1:numel(BRANCHES)
        if BRANCHES(k).entry(flags)
            b = BRANCHES(k);
            return
        end
    end
    error('build_model_definitions:noBranch', ...
        'No branch matched flags — the regular branch (entry = @(f) true) must be last.');
end

% -------------------------------------------------------------------------
function recipes = apply_boosting_overlay(recipes, overlay)
    keep = true(1, numel(recipes));
    for k = 1:numel(recipes)
        if is_boosting_recipe(recipes(k))
            keep(k) = false;
        end
    end
    recipes = [recipes(keep), overlay];
end

% -------------------------------------------------------------------------
function tf = is_boosting_recipe(r)
    tf = strcmp(r.fnName, 'fitcensemble') && ...
         isfield(r.args, 'Method') && ...
         ~ismember(r.args.Method, {'Bag','Subspace'});
end

% -------------------------------------------------------------------------
function templateFn = fitc_to_template(fnName)
% Explicit map: 'fitclinear' -> 'templateLinear', NOT 'templatelinear'.
    m = struct( ...
        'fitctree',     'templateTree', ...
        'fitcsvm',      'templateSVM', ...
        'fitcknn',      'templateKNN', ...
        'fitcnb',       'templateNaiveBayes', ...
        'fitcdiscr',    'templateDiscriminant', ...
        'fitcensemble', 'templateEnsemble', ...
        'fitclinear',   'templateLinear', ...
        'fitcecoc',     'templateECOC', ...
        'fitckernel',   'templateKernel', ...
        'fitcgam',      'templateGAM', ...
        'fitcnet',      'templateNeuralNetwork');
    if ~isfield(m, fnName)
        error('build_model_definitions:unknownFitc', ...
            'No template function known for %s', fnName);
    end
    templateFn = m.(fnName);
end

% -------------------------------------------------------------------------
function tmpl = build_template(r, XSeed, YSeed)
% Build the (inner or plain) template for a resolved recipe. For ECOC
% wrapping this is the learner passed as 'Learners'; for a plain
% (non-ECOC) recipe this is the returned template itself.
%
% NOTE — .template is exercised only on the HOLDOUT path. The CV path uses
% .cvFitFcn, which calls the raw fitc* function directly (never the
% template). This means the pre-R2026b trained-NN placeholder built below
% sits unused on .template when the workflow is CV-only — that is
% intentional; do not remove the placeholder to save memory without
% updating train_and_score_holdout in step.
    if nargin < 2, XSeed = []; end
    if nargin < 3, YSeed = []; end
    templateFn = fitc_to_template(r.fnName);
    % Pre-R2026b: fitcnet has no template function. train_and_score_holdout
    % expects a *trained* ClassificationNeuralNetwork here; it detects that
    % type and retrains via fitcnet at fit time.
    if strcmp(r.fnName, 'fitcnet') && ~exist('templateNeuralNetwork', 'file')
        if isempty(XSeed) || isempty(YSeed)
            error('build_model_definitions:missingSeed', ...
                ['Pre-R2026b: fitcnet needs a trained-model placeholder. ' ...
                 'Pass X and Y to build_model_definitions via ''X'' and ''Y'' name-value pairs.']);
        end
        n = min(size(XSeed, 1), 100);
        seedNV = struct_to_nv(r.args);
        tmpl = fitcnet(XSeed(1:n, :), YSeed(1:n), seedNV{:});
        return
    end
    argsNV = struct_to_nv(r.args);
    if ~isempty(r.innerLearner_fnName)
        innerNV = struct_to_nv(r.innerLearner_args);
        if template_needs_type(r.innerLearner_fnName)
            innerNV = [innerNV, {'Type','classification'}];
        end
        innerTmpl = feval(r.innerLearner_fnName, innerNV{:});
        extraNV = struct_to_nv(rmfield_safe(r.args, {'Method','NumLearningCycles'}));
        if isempty(extraNV)
            tmpl = templateEnsemble(r.args.Method, r.args.NumLearningCycles, ...
                innerTmpl, 'Type','classification');
        else
            tmpl = templateEnsemble(r.args.Method, r.args.NumLearningCycles, ...
                innerTmpl, extraNV{:}, 'Type','classification');
        end
    elseif template_needs_type(templateFn)
        tmpl = feval(templateFn, argsNV{:}, 'Type','classification');
    else
        tmpl = feval(templateFn, argsNV{:});
    end
end

% -------------------------------------------------------------------------
function tf = template_needs_type(templateFn)
% templateTree/SVM/Linear/Kernel/GAM support both classification and
% regression and error at fit time without an explicit Type. templateKNN
% and templateDiscriminant are classification-only and REJECT the Type
% name-value; templateNaiveBayes accepts it but does not need it.
    tf = ismember(templateFn, {'templateTree','templateSVM','templateLinear', ...
        'templateKernel','templateGAM'});
end

% -------------------------------------------------------------------------
function d = plain_def(r, XSeed, YSeed, useUniformPrior)
    d.name                         = r.id;
    d.template                     = build_template(r, XSeed, YSeed);
    d.cvFitFcn                     = make_cv_fit_fcn(r, useUniformPrior);
    d.fitFcn                       = make_fit_fcn(r, useUniformPrior);
    d.fnName                       = r.fnName;
    d.hyperparameters              = r.args;
    d.innerLearner_fnName          = r.innerLearner_fnName;
    if isempty(r.innerLearner_fnName)
        d.innerLearner_hyperparameters = struct();
    else
        d.innerLearner_hyperparameters = r.innerLearner_args;
    end
end

% -------------------------------------------------------------------------
function d = ecoc_def(r, innerTmpl, innerFn, coding, suffix, useUniformPrior)
    d.name                         = sprintf('%s-%s', r.id, suffix);
    d.template                     = templateECOC('Learners', innerTmpl, 'Coding', coding);
    d.cvFitFcn                     = make_cv_fit_fcn_ecoc(innerTmpl, coding, useUniformPrior);
    d.fitFcn                       = make_fit_fcn_ecoc(innerTmpl, coding, useUniformPrior);
    d.fnName                       = 'fitcecoc';
    d.hyperparameters              = struct('Coding', coding);
    d.innerLearner_fnName          = innerFn;
    d.innerLearner_hyperparameters = r.args;
end

% -------------------------------------------------------------------------
function fcn = make_cv_fit_fcn(r, useUniformPrior)
% Return a (X, Y, cv) -> cross-validated model handle for a resolved recipe.
% This closes over the modern fitc* signature per recipe kind so callers on
% the CV path never write a fit call by hand. Ensembles go through
% fitcensemble(X, Y, 'Method',..., 'NumLearningCycles',..., 'Learners',...)
% — modern name-value form, NOT the retired fitensemble positional form.
% Plain recipes go through fitc*(X, Y, <hyperparams>).
    priorNV = prior_nv(useUniformPrior);
    argsNV  = struct_to_nv(r.args);
    if ~isempty(r.innerLearner_fnName)
        innerNV = struct_to_nv(r.innerLearner_args);
        if template_needs_type(r.innerLearner_fnName)
            innerNV = [innerNV, {'Type','classification'}];
        end
        innerFn = r.innerLearner_fnName;
        fcn = @(X, Y, cv) fitcensemble(X, Y, argsNV{:}, ...
            'Learners', feval(innerFn, innerNV{:}), ...
            priorNV{:}, ...
            'CrossVal', 'on', 'CVPartition', cv);
    else
        fnName = r.fnName;
        fcn = @(X, Y, cv) feval(fnName, X, Y, argsNV{:}, ...
            priorNV{:}, ...
            'CrossVal', 'on', 'CVPartition', cv);
    end
end

% -------------------------------------------------------------------------
function fcn = make_cv_fit_fcn_ecoc(innerTmpl, coding, useUniformPrior)
% CV fit handle for an ECOC-wrapped recipe. The inner template is passed to
% fitcecoc as 'Learners'; 'Coding' selects OVO vs OVA.
    priorNV = prior_nv(useUniformPrior);
    fcn = @(X, Y, cv) fitcecoc(X, Y, ...
        'Learners', innerTmpl, ...
        'Coding',   coding, ...
        priorNV{:}, ...
        'CrossVal', 'on', 'CVPartition', cv);
end

% -------------------------------------------------------------------------
function fcn = make_fit_fcn(r, useUniformPrior)
% Non-CV twin of make_cv_fit_fcn — same fitc* signature, no CVPartition.
% Used to produce a deployable trained model on the CV path.
    priorNV = prior_nv(useUniformPrior);
    argsNV  = struct_to_nv(r.args);
    if ~isempty(r.innerLearner_fnName)
        innerNV = struct_to_nv(r.innerLearner_args);
        if template_needs_type(r.innerLearner_fnName)
            innerNV = [innerNV, {'Type','classification'}];
        end
        innerFn = r.innerLearner_fnName;
        fcn = @(X, Y) fitcensemble(X, Y, argsNV{:}, ...
            'Learners', feval(innerFn, innerNV{:}), ...
            priorNV{:});
    else
        fnName = r.fnName;
        fcn = @(X, Y) feval(fnName, X, Y, argsNV{:}, priorNV{:});
    end
end

% -------------------------------------------------------------------------
function fcn = make_fit_fcn_ecoc(innerTmpl, coding, useUniformPrior)
    priorNV = prior_nv(useUniformPrior);
    fcn = @(X, Y) fitcecoc(X, Y, ...
        'Learners', innerTmpl, ...
        'Coding',   coding, ...
        priorNV{:});
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
function s = rmfield_safe(s, names)
    for k = 1:numel(names)
        if isfield(s, names{k})
            s = rmfield(s, names{k});
        end
    end
end

% -------------------------------------------------------------------------
function d = empty_defs()
    d = struct('name', {}, 'template', {}, 'cvFitFcn', {}, 'fitFcn', {}, ...
        'fnName', {}, 'hyperparameters', {}, ...
        'innerLearner_fnName', {}, 'innerLearner_hyperparameters', {});
end

% Copyright 2026 The MathWorks, Inc.
