# Select Promising Classifiers Based on Dataset Characteristics

Build the model list with `build_model_definitions`; it applies the branch table in `scripts/model_catalog/` (do not read those files). The rules below say how the list is formed.

## Required inputs (from data analysis)

A `flags` struct must already be populated by `compute_data_flags` (Step 2). It carries:

`N`, `D`, `nClasses`, `classSize`, `smallestClassSize`, `classRatio`, `isBinary`, `isImbalanced`, `isWide`, `isHighD`, `isBig`, `hasManyMissing`, `isSparse`, `hasCategorical`.

Also required: `interpretability` — user preference: `'low'` or `'high'`.

Do not hardcode the thresholds behind the flags; where a step needs one, load `THRESHOLDS` by running `classifier_thresholds.m` as SKILL.md Step 3 shows.

## Assembling the model list

Do NOT read the branch tables and hand-transcribe recipes into MATLAB code — call the assembly helper. It dispatches the branch, applies every filter, resolves function-valued args, and (crucially) expands every `MulticlassECOC=true` recipe into TWO trained entries. Hand-transcribing the recipe list drops the OVA variant every time — this helper makes that impossible.

Use the Step 5 code in SKILL.md.

`X`/`Y` are only used to construct the `fitcnet` placeholder on pre-R2026b MATLAB (when `templateNeuralNetwork` does not exist). Passing them is safe on any branch — they are ignored when not needed.

`modelDefs` is a struct array; each entry has `.name`, `.template`, `.cvFitFcn`, `.fitFcn`, `.fnName`, `.hyperparameters`, `.innerLearner_fnName`, `.innerLearner_hyperparameters`. `.cvFitFcn` is the `(X, Y, cv) -> cv model` closure the CV path calls at Step 6; `.fitFcn` is the `(X, Y) -> trained model` closure used by `save_selected_models` (Step 13) to make a CV-trained model deployable. Train every entry — there is no further filtering step.

## Imbalanced-data override

When `flags.isImbalanced` is true, the base branch's boosting recipes (LogitBoost, RoughAdaBoost, FineAdaBoost) are replaced by the imbalanced boosting list, which includes RUSBoost only when the smallest class is large enough. The uniform-prior question is in `select-classifiers-imbalanced.md`.

Pass the overlay into `build_model_definitions` via the `'ImbalancedOverlay'` name-value pair — the helper does the substitution:

```matlab
run(fullfile(skillPath, 'scripts', 'model_catalog', 'imbalanced_boosting.m'));
modelDefs = build_model_definitions(flags, skillPath, ...
    'X', XTrain, 'Y', YTrain, ...
    'ImbalancedOverlay', IMBALANCED_BOOSTING_MODELS);
```

The uniform-prior flag is not a recipe field. On the CV path pass it to `build_model_definitions` as `'UseUniformPrior'` (Step 5), which bakes `'Prior','uniform'` into each `cvFitFcn`; on the holdout path pass it to `train_and_score_holdout` as its 6th argument (Step 6).

## Sparse branch: NaiveBayesMN gate

If the matched branch is `sparse`, `NaiveBayesMN` is always in `modelDefs`. Check whether the data is a non-negative integer bag-of-tokens matrix; if it is, ask the user whether to include the multinomial NB model. If the check fails or the user says no, drop the entry:

```matlab
if is_bag_of_tokens(XTrain)
    % Ask the user (yes/no); assume useNaiveBayesMN carries the answer.
else
    useNaiveBayesMN = false;
end
if ~useNaiveBayesMN
    modelDefs = modelDefs(~strcmp({modelDefs.name}, 'NaiveBayesMN'));
end
```

## No improvisation

The branch tables are exhaustive. Do not add classifiers the matched branch does not name. The only allowed deviations are:

- The interpretability filter (which is data — every recipe declares its own allowed levels).
- The imbalanced overlay described above.
- Explicit user requests to add or remove a specific model.

If a model you want is not in the matched branch, that is a deliberate omission — freelancing breaks reproducibility across runs and across users.

## Data modifications

### Subsampling for large datasets

If `isBig` and `smallestClassSize >= THRESHOLDS.subsample_smallest_class`, subsample to at most `floor(THRESHOLDS.subsample_total / nClasses)` observations per class for training. Use the `stratified_subsample` function to preserve class proportions. It takes four inputs — `[Xsub, Ysub] = stratified_subsample(X, Y, classes, perClassMax)` — where `classes` is the list of distinct class labels in `Y` and `perClassMax` is the per-class cap above; a three-input call errors.

## Confirm selection with user

After building the model list, present it to the user for confirmation. This MUST be done in two separate steps:

**Step A — print the model list as plain chat text.** Use the MATLAB documentation name for each model's `fitc*` function and list any non-default hyperparameters. Do NOT expose internal implementation details ("multiclass native, no ECOC", "no template", "wrapped in templateECOC") — these are skill-internal notes. The list must be fully readable in the conversation transcript without the user clicking, focusing, or expanding anything.

**Step B — only after the list is emitted as chat text, ask the confirmation question.** Do NOT bundle the model list into an `AskUserQuestion` `preview` field — the list belongs in the visible chat, the question is separate.

If the user requests changes, apply them and present the updated list as chat text again before re-asking.

### Explaining model choices

When the user asks why models were selected, explain based on **data characteristics and model capabilities** — not on internal skill mechanics:

- Do NOT refer to "branches", "branch logic", "selection logic", or any internal structure of this skill.
- Never mention surrogate splits — no model selected in this skill uses them.
- Do NOT describe specific model families (KNN, ensembles, etc.) as "non-parametric" or "making no distributional assumptions" — that applies to most models and is uninformative.
- DO explain choices in terms of which data properties matter (missing values, categorical features, dataset size, class count) and which models handle those properties natively.
- DO explain why certain families were excluded (e.g., "SVM drops rows with NaN internally, losing ~6% of training data").

## Referenced files

- **`references/helpers.md`** — signatures of `build_model_definitions`, `count_categorical_levels`, `is_bag_of_tokens` and `stratified_subsample`.
- **`select-classifiers-imbalanced.md`** — the uniform-prior question, the boosting overlay and the extreme-imbalance advisory.

----

Copyright 2026 The MathWorks, Inc.

----
