function r = model_recipe(id, fnName, args, varargin)
% MODEL_RECIPE  Build a struct entry for the classifier branch tables.
%
%   R = MODEL_RECIPE(ID, FN, ARGS) constructs a recipe with default
%   values for optional fields. FN is the fitc* function name
%   ('fitctree', 'fitcensemble', ...) — used both to build the
%   template at skill runtime AND as the fitc call for HPO (so we
%   don't maintain a separate template-to-fitc mapping table).
%
%   ARGS is a scalar struct. Each field's value is either a scalar
%   (char/numeric/logical) OR a function handle `@(flags) -> scalar`
%   for values that depend on the dataset (e.g. `MaxNumSplits =
%   @(f) 5*f.nClasses*(f.nClasses-1)`). Function-valued fields are
%   resolved by RESOLVE_RECIPE before the recipe is used by either
%   the skill runtime or the harness matcher — so the post-resolution
%   invariant "args values are plain scalars" still holds.
%
%   Optional name-value pairs:
%     'InnerLearnerFn'  — name of an inner template function
%                         ('templateTree', 'templateSVM', ...) for
%                         ensemble/ECOC recipes. Default: ''.
%     'InnerLearnerArgs' — scalar struct passed to the inner template.
%                          Default: struct().
%     'Interp'          — cellstr of allowed interpretability levels.
%                         Default: {'low','high'}.
%     'BinaryOnly'      — skip this recipe when nClasses > 2. Default: false.
%     'MulticlassECOC'  — wrap in templateECOC when nClasses > 2.
%                         Default: false.
%     'Condition'       — @(flags) predicate. Recipe is dropped
%                         from the assembled list when the predicate
%                         returns false. Default: @(f) true.
%
%   Recipes returned by this function feed BOTH the skill runtime (which
%   assembles fitc* template arguments from fnName + args) AND the
%   skill_eval harness's select_classifiers_expected (which compares
%   these fields to manifest rows). Adding a new field is a schema
%   change — extend the harness matcher at the same time.

    p = inputParser();
    p.addParameter('InnerLearnerFn',   '');
    p.addParameter('InnerLearnerArgs', struct());
    p.addParameter('Interp',           {'low','high'});
    p.addParameter('BinaryOnly',       false);
    p.addParameter('MulticlassECOC',   false);
    p.addParameter('Condition',        @(f) true);
    p.parse(varargin{:});

    % Assign field-by-field so struct() does not expand cellstr fields
    % into a struct array. Post-condition: r.interp is a plain 1xK
    % cellstr, not a wrapped {{...}}. Interpretability levels are
    % {'low','high'}: 'low' includes every recipe not gated to high-
    % only, and 'high' drops the non-interpretable families (kernel
    % SVMs, neural networks, KNN, ensembles) while adding
    % LogisticRegression + GAM to the regular branch.
    r.id                  = char(id);
    r.fnName              = char(fnName);
    r.args                = args;
    r.innerLearner_fnName = char(p.Results.InnerLearnerFn);
    r.innerLearner_args   = p.Results.InnerLearnerArgs;
    interpIn = p.Results.Interp;
    if iscell(interpIn) && isscalar(interpIn) && iscell(interpIn{1})
        interpIn = interpIn{1};  % unwrap {{'low',...}} → {'low',...}
    end
    r.interp              = cellstr(interpIn);
    r.binaryOnly          = logical(p.Results.BinaryOnly);
    r.multiclassECOC      = logical(p.Results.MulticlassECOC);
    r.condition           = p.Results.Condition;
end

% Copyright 2026 The MathWorks, Inc.
