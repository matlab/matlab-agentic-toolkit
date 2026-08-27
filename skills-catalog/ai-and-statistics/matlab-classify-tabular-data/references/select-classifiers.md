# Select Promising Classifiers Based on Dataset Characteristics

The authoritative branch table lives in the `.m` files under `scripts/model_catalog/`. This document explains **how the table is used** and **what invariants hold**; it does NOT enumerate branches or model lists — read those files for the recipes.

## Required inputs (from data analysis)

A `flags` struct must already be populated by `scripts/helpers/compute_data_flags.m` (Step 2). It carries:

`N`, `D`, `nClasses`, `classSize`, `smallestClassSize`, `classRatio`, `isBinary`, `isImbalanced`, `isWide`, `isHighD`, `isBig`, `hasManyMissing`, `isSparse`, `hasCategorical`.

Also required: `interpretability` — user preference: `'low'` or `'high'`.

Numeric thresholds behind the flags (5% missing for `hasManyMissing`, `D >= N` for `isWide`, class-ratio 5 for `isImbalanced`, etc.) are defined in `classifier_thresholds.m` — that file is the single source. Do not hardcode them elsewhere.

## Assembling the model list

Do NOT read the branch tables and hand-transcribe recipes into MATLAB code — call the assembly helper. It dispatches the branch, applies every filter, resolves function-valued args, and (crucially) expands every `MulticlassECOC=true` recipe into TWO trained entries. Hand-transcribing the recipe list drops the OVA variant every time — this helper makes that impossible.

```matlab
% flags was populated in Step 2 via compute_data_flags(X, Y).
flags.interp = interpretability;
flags.totalCatLevels = count_categorical_levels(X);

modelDefs = build_model_definitions(flags, skillPath, 'X', XTrain, 'Y', YTrain);
```

`X`/`Y` are only used to construct the `fitcnet` placeholder on pre-R2026b MATLAB (when `templateNeuralNetwork` does not exist). Passing them is safe on any branch — they are ignored when not needed.

`modelDefs` is a struct array; each entry has `.name`, `.template`, `.cvFitFcn`, `.fitFcn`, `.fnName`, `.hyperparameters`, `.innerLearner_fnName`, `.innerLearner_hyperparameters`. `.cvFitFcn` is the `(X, Y, cv) -> cv model` closure the CV path calls at Step 6; `.fitFcn` is the `(X, Y) -> trained model` closure used by `save_selected_models` (Step 13) to make a CV-trained model deployable. Train every entry — there is no further filtering step.

### What the helper does (invariants)

The helper implements this spec — you do not implement it yourself:

- **Dispatch.** Walks `BRANCHES` in ID order (sparse, many_missing, categorical, wide, regular) and picks the first branch whose `entry(flags)` returns true. The regular branch is the default; it always matches last.
- **Filter.** Drops recipes where `binaryOnly && ~flags.isBinary`, where `condition(flags)` returns false, or where `flags.interp` is not in the recipe's `interp` set. The interp filter is the only interpretability knob — recipes declaring `interp: {'high'}` (LogisticRegression, GAM in the regular branch) are absent at low; recipes declaring `interp: {'low'}` are absent at high.
- **Resolve function-valued args.** Recipes may declare fields like `MaxNumSplits = @(f) 5*f.nClasses*(f.nClasses-1)`; the helper calls the handle with `flags` and replaces the field with the resulting scalar.
- **Build the template.** `recipe.fnName` names the fitc function; the corresponding `template*` is derived by replacing the `fitc` prefix. Ensembles (recipe has `innerLearner_fnName`) use `templateEnsemble(Method, NumLearningCycles, innerTmpl, ...)`; other recipes use `feval(templateFn, args...)`.
- **Multiclass ECOC wrap.** Recipes with `multiclassECOC: true` and `nClasses >= 3` produce TWO entries in `modelDefs`, one with `Coding='onevsone'` (name suffix `-OVO`) and one with `Coding='onevsall'` (name suffix `-OVA`). Applies to `templateSVM`, `templateLinear`, and `templateKernel`. `templateGAM` and `templateNeuralNetwork` support multiclass natively and are NOT wrapped (their recipes do not set the flag).

### Template-to-fitc mapping (reference only — the helper handles this)

| fitc function      | Template function      |
|--------------------|------------------------|
| fitctree           | templateTree           |
| fitcsvm            | templateSVM            |
| fitcknn            | templateKNN            |
| fitcnb             | templateNaiveBayes     |
| fitcdiscr          | templateDiscriminant   |
| fitcensemble       | templateEnsemble       |
| fitclinear         | templateLinear         |
| fitcecoc           | templateECOC           |
| fitckernel         | templateKernel         |
| fitcgam            | templateGAM            |
| fitcnet            | templateNeuralNetwork  |

## Imbalanced-data override

When `flags.isImbalanced` is true, the boosting recipes from the base branch (LogitBoost, RoughAdaBoost, FineAdaBoost) are replaced by the list in `scripts/model_catalog/imbalanced_boosting.m`. See that file for the model list and the RUSBoost gate on `smallestClassSize`. The uniform-prior user question is in `select-classifiers-imbalanced.md`.

Pass the overlay into `build_model_definitions` via the `'ImbalancedOverlay'` name-value pair — the helper does the substitution:

```matlab
run(fullfile(skillPath, 'scripts', 'model_catalog', 'imbalanced_boosting.m'));
modelDefs = build_model_definitions(flags, skillPath, ...
    'X', XTrain, 'Y', YTrain, ...
    'ImbalancedOverlay', IMBALANCED_BOOSTING_MODELS);
```

The uniform-prior flag itself is a training-time argument, not a recipe field — it is passed to `train_and_score_holdout` / baked into `cvFitFcn` in Step 6, not into `build_model_definitions`.

## No improvisation

The branch tables are exhaustive. Do not add classifiers the matched branch does not name. The only allowed deviations are:

- The interpretability filter (which is data — every recipe declares its own allowed levels).
- The imbalanced overlay described above.
- Explicit user requests to add or remove a specific model.

If a model you want is not in the matched branch, that is a deliberate omission — freelancing breaks reproducibility across runs and across users.

## Data modifications

### Subsampling for large datasets

If `isBig` and `smallestClassSize >= THRESHOLDS.subsample_smallest_class`, subsample to at most `floor(THRESHOLDS.subsample_total / nClasses)` observations per class for training. Use the `stratified_subsample` function to preserve class proportions.

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

- **`scripts/helpers/build_model_definitions.m`** — the assembly helper called from Step 5. Dispatches the branch, applies every filter, resolves function-valued args, expands `MulticlassECOC=true` recipes into `-OVO` and `-OVA` pairs, and returns the `modelDefs` struct array ready to train.
- **`scripts/helpers/resolve_recipe.m`** — resolves function-valued args to concrete scalars. Called by `build_model_definitions`.
- **`scripts/model_catalog/classifier_branches.m`** — aggregator; loads the 5 branch scripts and populates `BRANCHES`. Called by `build_model_definitions`; callers do not run it directly.
- **`scripts/model_catalog/branch_sparse.m`, `branch_many_missing.m`, `branch_categorical.m`, `branch_wide.m`, `branch_regular.m`** — one branch entry each; the authoritative model lists.
- **`scripts/model_catalog/classifier_thresholds.m`** — numeric constants (imbalance ratio, wide-branch N cap, categorical-level cap, etc.).
- **`scripts/model_catalog/model_recipe.m`** — recipe constructor and schema documentation.
- **`scripts/model_catalog/imbalanced_boosting.m`** — boosting model list applied when `isImbalanced`. Load, then pass `IMBALANCED_BOOSTING_MODELS` to `build_model_definitions` via `'ImbalancedOverlay'`.
- **`select-classifiers-imbalanced.md`** — user-facing prose for the imbalance case (uniform-prior question and extreme-imbalance advisory).

---

Copyright 2026 The MathWorks, Inc.
