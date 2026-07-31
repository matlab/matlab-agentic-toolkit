---
name: matlab-classify-tabular-data
description: >
  Use this skill to classify tabular data end-to-end in MATLAB — load a dataset, prepare and clean
  it, select promising classifiers, train them, and compare accuracies with cross-validation,
  holdout, or hyperparameter optimization plus statistical tests.
  TRIGGER when: user asks to classify tabular data, pick classifiers for a dataset, compare
  classifier accuracy, run cross-validation or a holdout evaluation, or find the best model with
  statistical uncertainty.
  DO NOT TRIGGER when: user has non-tabular inputs (images, sequences, time series), wants a
  regression model, is training a specific neural network architecture (use matlab-train-network),
  or wants cost-sensitive learning or an arbitrary class-prior vector (this skill only supports the
  built-in uniform-prior toggle for imbalanced data).
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Compare Classification Models with Statistical Uncertainty

Compare classifiers on the user's dataset and identify the top tier of models that are statistically equivalent in accuracy.

This skill bundles the workflow in `references/` (step-by-step instructions and branch tables read on-demand) and `scripts/` (reusable computation and plotting helpers). Do not invoke files in `references/` as separate skills — they are only loaded via the `Read` tool when the corresponding step runs. See `references/README.md` for the layout and why the branch-table `.m` files live in `references/` instead of `scripts/`.

## When to Use

- User wants to classify tabular data (matrix or table of predictors + categorical response).
- User asks to compare multiple classifiers, pick the best model, or evaluate classifier accuracy.
- User needs cross-validation, a holdout evaluation, or hyperparameter optimization for classifiers.
- User needs statistical tests (McNemar, 5×2 cv, Friedman) to know which accuracy differences are significant.

## When NOT to Use

- Response is continuous — use a regression skill instead.
- Predictors are images, sequences, or time series — this skill assumes a numeric matrix or a table of scalar predictors.
- User wants to design or train a specific neural network architecture — use `matlab-train-network`. This skill *does* include `fitcnet` as one candidate on regular-branch data, but does not tune network layers or hyperparameters.
- User only wants to score a pretrained model on new data — this skill trains and compares; scoring an existing model does not need it.
- **User wants cost-sensitive learning or a custom class-prior vector.** Refuse plainly and stop — do not attempt a workaround. This skill's only supported prior control is the built-in **uniform-prior** toggle for imbalanced data (`'Prior','uniform'`, offered via the `UseUniformPrior` flag in Step 5). Arbitrary `'Prior',[...]` vectors and `'Cost',C` matrices are not supported: neither the model-definition helper nor the CV/holdout scoring helpers thread these through, the branch tables and ECOC-expansion logic assume the built-in prior/cost defaults, and pairwise statistical tests (`testckfold`, `testcholdout`) score misclassification rate rather than expected cost. Attempting to bypass the helpers to inject a custom prior or cost is a **hard refusal**, not a judgment call — tell the user: *"This skill does not support custom class priors or cost matrices. If you need cost-sensitive learning or a specific prior vector, use `fitc*` directly with the `'Prior'` or `'Cost'` name-value pair; this skill's statistical-comparison workflow will not give correct results in that setting."*

## Running MATLAB

Run all MATLAB code via the MATLAB MCP server (`mcp__matlab__evaluate_matlab_code`, or `mcp__matlab__run_matlab_file` for scripts). Set `project_path` to this skill's `scripts/` directory so the workflow helpers resolve on the current working folder without any `addpath` calls.

## Communication style while running this skill

Talk to the user about their **data and results**, not about the skill's plumbing. Everything under `references/`, `scripts/`, and the branch tables is internal — a user watching the run should never have to ask what a filename means.

Concretely, while executing this skill:

- **Do not name internal files or helpers** in progress messages. `references/select-classifiers.md`, `build_model_definitions`, `compute_pairwise_pvalues_cv`, `classifier_branches.m`, `resolve_recipe`, `modelDefs`, `cvFitFcn`, etc., are all internal. If you must reference them (e.g., surfacing a bug the user can act on), name them once and explain what they are.
- **Do not narrate branch dispatch or filter decisions** by name. "Dispatching to the wide branch", "applying the imbalanced overlay", "`isSparse` is false so we skip the sparse branch" — all internal. The user only needs to hear the *outcome*: "This dataset is wide (200 features, 40 samples), so I'm using linear models."
- **Do not read reference files out loud.** When a step says *STOP and read `references/foo.md`*, that is a directive to you, not a status update to broadcast. Read it silently and continue.
- **Do announce what the user chose to run, and roughly how long it will take**, before a long training loop or HPO run. One sentence.
- **Do surface user-facing questions verbatim** where the step specifies them (evaluation strategy, interpretability, uniform prior, HPO selection). Those *are* the user's interface to the skill.
- **Do surface a real problem** if one appears — a failed check gate, a branch that couldn't match, a fit call that errored. Name it plainly; then, and only then, is it fine to reference the internal file where the fix belongs.

Illustrative contrast:

> **Don't:** "Reading `references/dataprep.md`... computing `flags` via `compute_data_flags`... `isImbalanced=true`, so reading `references/select-classifiers-imbalanced.md` and applying `IMBALANCED_BOOSTING_MODELS` overlay to `build_model_definitions`. `modelDefs` now has 8 entries including RUSBoost-OVO and RUSBoost-OVA."
>
> **Do:** "Class ratio is 9:1, so I'll use imbalance-aware boosting models. Before I train, I need to ask you about the class prior — [uniform-prior question verbatim]."

Rule of thumb: if a sentence would only make sense to someone who has read this skill's source files, don't say it.

## Before Writing Code

**Do not reuse any variables from previous analysis runs.** Always execute the full prescription and set all variables from scratch for each analyzed dataset. Every step must define its own variables — never assume anything remains in the workspace from a prior run.

**Define `skillPath` up front.** Several helpers and reference `.m` files take `skillPath` as an argument (the parent directory of `scripts/`). When you invoke MATLAB via `evaluate_matlab_code` with `project_path` set to this skill's `scripts/` folder, MATLAB's working directory *is* `scripts/`, so `skillPath = fileparts(pwd);` gives the correct value. Set it at the top of the first code block that needs it (Step 2 or Step 3) and rely on the same value thereafter:

```matlab
skillPath = fileparts(pwd);  % parent of scripts/; used by build_model_definitions, THRESHOLDS load, imbalanced overlay, export_workflow_script
```

For all rules about how to write the MATLAB code itself (use built-ins, do not inspect template objects, training-time rules, figure rules), see `scripts/README.md`.

## Step 1: Load data

- Load the dataset
- Determine whether a separate test set is provided (e.g., separate training and test tables/matrices).
  - If yes: set `hasHoldout = true` and assign `XTrain`, `YTrain`, `XTest`, `YTest`.
  - If no: assign `X`, `Y` from the loaded data. Do NOT split or ask about splitting yet.

**Assumption on input shape.** If any predictor is categorical, X must be a **table** with the categorical column(s) stored as MATLAB `categorical` (or `string`/`cellstr`, which `compute_data_flags` also treats as categorical). Matrix inputs are assumed fully numeric. If the user hands you predictors as a set of separate variables of mixed types (some numeric, some categorical/string), assemble them into a table with `table(...)` before proceeding — do not concatenate them into a numeric matrix, which would silently coerce categoricals to numeric codes. `CategoricalPredictors` NV pairs on `fitc*` are not used by this skill; categorical detection is entirely through the table column dtype.

## Step 2: Analyze and clean data

**STOP. Use the Read tool on `references/dataprep.md` (relative to this skill's directory). Do NOT write any MATLAB code until you have read that file. Follow its instructions exactly as written.**

Run the dataprep instructions on `XTrain`/`YTrain` if `hasHoldout = true` (dataset came with a separate test set), or on `X`/`Y` otherwise. On return, the workspace must contain a `flags` struct produced by `scripts/compute_data_flags.m` with fields: `N`, `D`, `nClasses`, `classSize`, `smallestClassSize`, `classRatio`, `isBinary`, `isImbalanced`, `isWide`, `isHighD`, `isBig`, `hasManyMissing`, `isSparse`, `hasCategorical`.

The workspace must also contain a `preproc` struct array recording every mutation to X or Y in the order applied. Its op catalog — the only four ops the exported Step 14 workflow script can replay via `scripts/apply_preproc.m` — is:

| `.op` | When emitted | `.payload` fields |
|---|---|---|
| `omitColumns` | User chose to drop high-missingness or high-cardinality features | `columnNames` (table X) or `columnIndices` (matrix X) |
| `dropZeroVariance` | Automatic drop of globally constant features | `columnNames` (table X) or `columnIndices` (matrix X) |
| `removeClasses` | User chose to remove minority classes | `classes` (cell array of class labels) |
| `mergeClasses` | User chose to merge minority classes into one label | `map.from` (source labels), `map.to` (target label) |

Any op name outside this catalog will cause `apply_preproc` to error at replay time — inventing new op names is a bug, not an extension point.

## Step 3: Choose evaluation strategy

If `hasHoldout = true` (dataset came with a separate test set): skip this step.

Otherwise, load the thresholds and use `flags.smallestClassSize` (computed in Step 2) to present a recommendation:

```matlab
run(fullfile(skillPath, 'references', 'classifier_thresholds.m'));  % populates THRESHOLDS
```

If `flags.smallestClassSize > THRESHOLDS.holdout_smallest_class`, recommend a 70/30 holdout split. Interpolate the actual threshold into the prompt via `sprintf` — do not hardcode the number:

> This dataset has [flags.N] observations and the smallest class has [flags.smallestClassSize] observations — larger than the [THRESHOLDS.holdout_smallest_class]-observation threshold for holdout evaluation. I recommend a **70/30 stratified train/test split**. This is faster and evaluates on unseen data.
>
> Alternatively, I can use **5-fold cross-validation**. CV uses all data for both training and evaluation but is slower.
>
> Which do you prefer? (holdout / cv)

Otherwise (`flags.smallestClassSize <= THRESHOLDS.holdout_smallest_class`), recommend cross-validation:

> This dataset has [flags.N] observations and the smallest class has [flags.smallestClassSize] observations — at or below the [THRESHOLDS.holdout_smallest_class]-observation threshold for a reliable holdout split. I recommend **5-fold cross-validation**.
>
> Alternatively, I can use a **70/30 stratified holdout split**, though the test set may be small.
>
> Which do you prefer? (cv / holdout)

Wait for the user's response. If the user chooses holdout, create the split via `scripts/make_holdout_split.m` and set `hasHoldout = true`. If the user chooses cv, set `hasHoldout = false`.

All subsequent steps operate on the training data (`XTrain`/`YTrain` when `hasHoldout`, or `X`/`Y` otherwise).

## Step 4: Ask about interpretability

Before selecting models, ask the user:

> How important is model interpretability for this task? (low / high)

Record the answer as `interpretability` with value `'low'` or `'high'`. This rating is passed to the `select-classifiers` reference to prioritize models:

| Rating | Meaning |
|---|---|
| **high** | Predictions must be explainable to a human (e.g., regulated domain, clinical). Prefer trees, discriminant analysis, logistic regression. |
| **low** | Accuracy is the priority. All model families are candidates. |

## Step 5: Select and define model templates

**STOP. Use the Read tool on `references/select-classifiers.md` (relative to this skill's directory). Do NOT write any MATLAB code until you have read that file. Follow its instructions exactly as written.**

The matched branch list is exhaustive. Do not add models the branch does not name, even for "variety" or as a related variant of a listed model. The only allowed modifications are the interpretability filter, the imbalanced-data overrides, and explicit user requests.

If `isImbalanced = true`, also Read `references/select-classifiers-imbalanced.md` for the boosting-method override and the **mandatory** uniform-prior decision. In an interactive session the agent must pose the uniform-prior question verbatim to the user and receive an answer before any `fit*` call. In a non-interactive session (e.g., automated evaluation) where the agent has been instructed not to prompt, the agent must still surface the choice explicitly: name both options (`Prior='uniform'` vs `Prior='empirical'`), state which one it is defaulting to and why, and flag that this is normally the user's call. Silently defaulting without surfacing the trade-off — even when the domain (e.g., fraud detection, medical screening) makes one option sound "obviously right" — is a hard failure of the imbalanced workflow.

Model definitions are assembled by `scripts/build_model_definitions.m`. Do NOT hand-transcribe recipes from the branch table — call the helper. It dispatches the branch, applies every filter (binaryOnly / condition / interpretability), resolves function-valued args, and expands every `MulticlassECOC=true` recipe into TWO entries (one `-OVO`, one `-OVA`). Hand-writing the recipe list drops the OVA variant every time — the helper makes that impossible.

```matlab
% flags was populated in Step 2 via compute_data_flags(X, Y).
flags.interp = interpretability;
flags.totalCatLevels = count_categorical_levels(X);

% X and Y are only used to build the fitcnet placeholder on pre-R2026b
% MATLAB (regular branch); passing them is always safe.
modelDefs = build_model_definitions(flags, skillPath, 'X', XTrain, 'Y', YTrain);

% Imbalanced case only: read select-classifiers-imbalanced.md first,
% ask the uniform-prior question, then pass the overlay in. The
% 'UseUniformPrior' NV pair — set from the user's answer — bakes
% 'Prior','uniform' into every cvFitFcn (CV path). On the holdout path
% it is passed straight to train_and_score_holdout in Step 6 instead.
%   run(fullfile(skillPath, 'references', 'imbalanced_boosting.m'));
%   modelDefs = build_model_definitions(flags, skillPath, ...
%       'X', XTrain, 'Y', YTrain, ...
%       'ImbalancedOverlay',  IMBALANCED_BOOSTING_MODELS, ...
%       'UseUniformPrior',    useUniformPrior);   % CV path only
```

`modelDefs` is a struct array. Each entry has `.name`, `.template`, `.cvFitFcn`, `.fitFcn`, `.fnName`, `.hyperparameters`, `.innerLearner_fnName`, `.innerLearner_hyperparameters`. `.cvFitFcn` is the `(X, Y, cv) -> cv model` closure used by the CV path in Step 6; `.fitFcn` is the `(X, Y) -> trained model` closure used by `save_selected_models` in Step 13 to produce a deployable model from a CV-wrapped one. Multiclass ECOC recipes appear twice: `LinearSVM-OVO` and `LinearSVM-OVA`, `LogisticRegression-OVO` and `LogisticRegression-OVA`, etc. Train every entry.

**Never type a `fitc*` or `fitensemble` call anywhere in Step 6.** The correct fit signature — modern `fitcensemble` name-value form, `fitcecoc` with `'Learners'` set to the inner template, everything else `fitc*(X, Y, hyperparams...)` — is baked into `modelDefs(k).cvFitFcn` (CV path) and `modelDefs(k).template` (holdout path). If any step below appears to require you to write a `fitc*` call yourself, that is a bug in this skill file — surface it, do not improvise. `fitensemble` (no "c") is retired; `Learners = templateEnsemble(...)` is wrong; `fitcensemble('Method', ..., 'NumLearningCycles', ..., 'Learners', innerTmpl)` is right — the helper already emits the right form.

### Sparse-branch NaiveBayesMN gate

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

### CV path (`hasHoldout = false`) — use the baked-in `cvFitFcn`

`build_model_definitions` sets `modelDefs(k).cvFitFcn` to a `(X, Y, cv) -> cv model` handle that already closes over the correct `fitc*` signature for the recipe (including modern `fitcensemble` name-value form for ensembles and the right `Learners`/`Coding` for ECOC). Do NOT reconstruct this handle by hand — pass it straight to `train_and_score_cv`:

```matlab
[cvModel, trainTime, acc, accCI, foldAcc] = ...
    train_and_score_cv(modelDefs(k).cvFitFcn, X, Y, cvp);
```

### Holdout path (`hasHoldout = true`)

Pass `.template` directly to `train_and_score_holdout(template, XTrain, YTrain, XTest, YTest)`. No CV wrapper needed.

## Step 6: Get baseline accuracy estimates

Record training time for each model using `tic`/`toc`. For CV, time the `cvFitFcn` call. For holdout, time the `fit` call.

### Static check gate (mandatory, before any training call)

Before you execute *any* MATLAB code in this step, first save that code to a `.m` file and run `mcp__matlab__check_matlab_code` on it. Then grep the same source for the four banned patterns below and abort — do not execute — if any of them appear anywhere in the file:

| Banned token / pattern | Why it is wrong |
|---|---|
| `fitensemble(` (no "c") | Retired API. Use `modelDefs(k).cvFitFcn` or `modelDefs(k).template` — both bake in the modern `fitcensemble` call for you. |
| `'Learners', templateEnsemble` (any casing/whitespace) | An ensemble template cannot be an ECOC learner. To train an ensemble, call the ensemble template with `fit(...)`, or (much better) use `modelDefs(k).cvFitFcn` / `.template`. |
| `fitcensemble(` typed by hand in Step 6 | The helper in `build_model_definitions.m` already emits `fitcensemble(X, Y, 'Method', ..., 'NumLearningCycles', ..., 'Learners', innerTmpl)` under the `cvFitFcn` closure. Hand-typing it re-introduces the retired positional signature nine times out of ten. |
| Any other `fitc*(` typed by hand in Step 6 | Same reason: `modelDefs(k).cvFitFcn` and `train_and_score_holdout(modelDefs(k).template, ...)` are the only sanctioned entry points for training in this step. |

If the check gate flags any of these, the correct response is *not* to rewrite the fit call — it is to replace it with `train_and_score_cv(modelDefs(k).cvFitFcn, X, Y, cvp)` (CV path) or `train_and_score_holdout(modelDefs(k).template, XTrain, YTrain, XTest, YTest, useUniformPrior)` (holdout path). Only these two calls appear in Step 6's training loop.

### Uniform prior for imbalanced data

If `useUniformPrior = true`:

- **CV path:** pass `'UseUniformPrior', true` to `build_model_definitions` in Step 5. Every `modelDefs(k).cvFitFcn` will then append `'Prior','uniform'` to its fit call. Do NOT modify `cvFitFcn` yourself — the closure already exists and the flag is the only supported entry point.
- **Holdout path:** pass `useUniformPrior` as the 6th argument to `train_and_score_holdout`.

### CV path (`hasHoldout = false`)

For each model, call `scripts/train_and_score_cv.m`. It runs the model's `cvFitFcn` and returns `cvModel`, `trainTime`, `acc`, `accCI` (95% CI from `binofit`), and `perFoldAcc` — the per-model per-fold accuracy vector (nFolds × 1).

Aggregate the per-model results across the loop as follows:

```matlab
nModels = numel(modelDefs);
nFolds  = cvp.NumTestSets;
trainTime = zeros(1, nModels);
acc       = zeros(1, nModels);
accCI     = zeros(nModels, 2);
foldAcc   = zeros(nFolds, nModels);   % preallocated as an nFolds × nModels MATRIX
cvModels  = cell(1, nModels);

for k = 1:nModels
    [cvModels{k}, trainTime(k), acc(k), accCI(k,:), perFoldK] = ...
        train_and_score_cv(modelDefs(k).cvFitFcn, X, Y, cvp);
    foldAcc(:, k) = perFoldK;         % one column per model — REQUIRED for Step 7 friedman()
end
```

The nFolds × nModels shape is exactly what `friedman(foldAcc, 1, 'off')` expects in Step 7 — folds are treatments applied within each subject-model. Do NOT collect `perFoldAcc` into a cell array, and do NOT concatenate along the wrong dimension.

Report a table of cross-validated accuracies with 95% confidence intervals.

### Holdout path (`hasHoldout = true`)

For each model, call `scripts/train_and_score_holdout.m`. It handles the `ClassificationNeuralNetwork` exception (R2026a and earlier, where the "template" is actually a trained model) and the optional `'Prior','uniform'` flag. It returns the trained `model`, `trainTime`, `acc`, `accCI`, and `YHat` (the prediction vector on the test set).

Aggregate the per-model results across the loop as follows:

```matlab
nModels = numel(modelDefs);
trainTime     = zeros(1, nModels);
acc           = zeros(1, nModels);
accCI         = zeros(nModels, 2);
YHat          = cell(1, nModels);          % cell array — each entry is one model's prediction vector
trainedModels = cell(1, nModels);

for k = 1:nModels
    [trainedModels{k}, trainTime(k), acc(k), accCI(k,:), YHat{k}] = ...
        train_and_score_holdout(modelDefs(k).template, XTrain, YTrain, XTest, YTest, useUniformPrior);
end
```

`YHat` MUST be a cell array of prediction vectors — `compute_pairwise_pvalues_holdout` (Step 8) indexes it as `YHat{i}`. Do NOT stack predictions into a numeric matrix; class labels are `categorical`/`string`/`cellstr` and would coerce to numeric codes on `[YHat{:}]`-style concatenation.

## Step 7: Choose the statistical comparison method

- **CV path** (`hasHoldout = false`): run a Friedman omnibus test on `foldAcc` first, then proceed to pairwise `testckfold` in Step 8. Do not follow Friedman with `multcompare` — pairwise comparisons come from `testckfold`.

  ```matlab
  [pFriedman, tbl, stats] = friedman(foldAcc, 1, 'off');
  ```

- **Holdout path** (`hasHoldout = true`): skip Friedman (no folds exist); proceed directly to pairwise `testcholdout` in Step 8.

## Step 8: Run the comparison

- Run pairwise comparisons for **all** pairs of models (not just vs the best), storing p-values in a symmetric matrix
- Apply Bonferroni correction: `alpha_corrected = 0.05 / nchoosek(nModels, 2)`
- Identify the top tier: models NOT significantly different from the best (after Bonferroni correction)
- Report the full pairwise p-value matrix as a table

Do NOT hand-write the pairwise loop — call the bundled helper for the current path. Both helpers seed the diagonal with `pvalMatrix(i,i) = 1` (self-comparison p-value) so downstream code (top-tier selection, `plot_pvalue_heatmap`) works without special-casing NaN.

### CV path (`hasHoldout = false`)

Uses `testckfold` (5×2 F-test) internally:

```matlab
[pvalMatrix, hMatrix] = compute_pairwise_pvalues_cv(modelDefs, X, Y, alpha_corrected);
```

### Holdout path (`hasHoldout = true`)

Uses `testcholdout` (McNemar) on the stored predictions from Step 6. **`testcholdout` and `testckfold` have completely different signatures:** `testcholdout` does NOT accept templates, trained models, or data matrices — it only compares two vectors of predicted labels against ground truth. Pass `YHat` (the cell array of prediction vectors stored in Step 6 via `predict`) and `YTest`:

```matlab
[pvalMatrix, hMatrix] = compute_pairwise_pvalues_holdout(YHat, YTest, alpha_corrected);
```

### Visualize pairwise p-values (ALWAYS — both CV and holdout paths)

ALWAYS display the pairwise p-value matrix as a heatmap, regardless of which path was used. This figure is generated in Step 8, not Step 9. Call the bundled script:

```matlab
% CV path:
plot_pvalue_heatmap(pvalMatrix, modelNames, sprintf('Pairwise testckfold p-values (Friedman p = %.4f)', pFriedman));

% Holdout path:
plot_pvalue_heatmap(pvalMatrix, modelNames, 'Pairwise testcholdout p-values (McNemar)');
```

The script lives at `scripts/plot_pvalue_heatmap.m` in this skill directory. As with every other helper, it resolves via the current working folder — do not modify the MATLAB path.

## Step 9: Visualize

Show two figures by calling the bundled scripts (`scripts/plot_accuracy_bars.m` and `scripts/plot_training_time.m`). Both sort models by descending accuracy and highlight top-tier models.

```matlab
plot_accuracy_bars(modelNames, acc, accCI, topTierIdx, ...
    sprintf('Accuracy with 95%% CI (path: %s)', evalPath));
plot_training_time(modelNames, trainTime, acc, topTierIdx);
```

## Step 10: Boosting learning curve

For each boosting model (RUSBoost, AdaBoost, LogitBoost), plot its learning curve and offer to resume training.

First, identify which entries in `modelDefs` are boosting models. Boosting means `fnName == 'fitcensemble'` AND `hyperparameters.Method` is one of `RUSBoost`, `LogitBoost`, `AdaBoostM1`, `AdaBoostM2`, `GentleBoost` — *not* `Bag` or `Subspace`. Iterate over these `boostIdx` values; every code snippet below uses `boostIdx` as the current model's index into the per-model arrays (`acc`, `accCI`, `foldAcc`, `trainTime`).

```matlab
boostMethods = {'RUSBoost','LogitBoost','AdaBoostM1','AdaBoostM2','GentleBoost'};
isBoost = false(1, numel(modelDefs));
for k = 1:numel(modelDefs)
    hp = modelDefs(k).hyperparameters;
    isBoost(k) = strcmp(modelDefs(k).fnName, 'fitcensemble') ...
        && isfield(hp, 'Method') && ismember(hp.Method, boostMethods);
end
boostIndices = find(isBoost);
```

Loop `for boostIdx = boostIndices`, then call the bundled script (`scripts/plot_boosting_curve.m`):

```matlab
boostModelName = modelDefs(boostIdx).name;

% Holdout path: pass the trained model and test set
plot_boosting_curve(trainedModels{boostIdx}, boostModelName, true, XTest, YTest);

% CV path: pass the cross-validated model; XTest/YTest unused
plot_boosting_curve(cvModels{boostIdx}, boostModelName, false, [], []);
```

After displaying the plot, ask the user:

> The learning curve for [modelName] shows accuracy at each number of trees. Please inspect the curve.
>
> Would you like to resume training with more trees? If yes, how many additional trees? (no / number)

If the user provides a number, call the path-appropriate resume script and update the per-model results:

```matlab
% Holdout path
[trainedModels{boostIdx}, resumeTime, acc(boostIdx), accCI(boostIdx,:), YHat{boostIdx}] = ...
    resume_boosting_holdout(trainedModels{boostIdx}, nMoreTrees, XTest, YTest);
trainTime(boostIdx) = trainTime(boostIdx) + resumeTime;

% CV path
[cvModels{boostIdx}, resumeTime, acc(boostIdx), accCI(boostIdx,:), foldAcc(:, boostIdx), oofPreds] = ...
    resume_boosting_cv(cvModels{boostIdx}, nMoreTrees);
trainTime(boostIdx) = trainTime(boostIdx) + resumeTime;
```

After each resume, report the boosting model's final mean accuracy and cumulative training time (pre-resume + resume).

Once all resuming is done, re-run the Step 8 statistical comparison for the final boosting model and report those results.

After each resume, ALWAYS ask the user again whether they want to continue training with more trees — regardless of whether the model's accuracy is still far from the top tier. You may note the remaining gap, but the decision to stop belongs to the user. Never unilaterally conclude that further training is futile.

## Step 11: Hyperparameter optimization (optional)

First, ask the user whether they want to run HPO and, if so, on which models. Present the top-tier list and the remaining models as plain chat text (the same two-step pattern as Step 5: list first, then question). Mention that HPO on the CV path uses nested cross-validation and can be slow.

If the user declines (e.g., "none", "skip"), proceed directly to Step 12 — do NOT read `references/hpo.md`.

If the user wants HPO on one or more models:

**STOP. Use the Read tool on `references/hpo.md` (relative to this skill's directory). Do NOT write any MATLAB code until you have read that file. Follow its instructions exactly as written.**

Pass the top-tier model list, baseline accuracies, the user's selected models, and all relevant training/evaluation data.

## Step 12: Summary

Report:
- The chosen statistical test and why
- The top tier of statistically equivalent models
- Which model has the highest mean accuracy (even if not significantly better)

Include the per-model accuracy and 95% CI for every trained model so the user has enough context to decide what to save in Step 13.

**Consistent metric naming:** Pick one of accuracy or error rate and use it consistently throughout the summary. Do NOT mix them — never label an accuracy value with the word "error", or an error value with "accuracy". If you say "lowest mean error", the values reported must be error rates (e.g., 5.1%); if you say "highest mean accuracy", the values must be accuracy (e.g., 94.9%). The same rule applies to confidence intervals.

## Steps 13 and 14: Save models and export retraining script (optional)

Steps 13 (save selected trained models to a `.mat` file via `save_selected_models`) and 14 (emit a self-contained retraining `.m` script via `export_workflow_script`) are covered together in a single reference. Both are optional and must be offered in that order — the user's answer to "which models should I save?" depends on the per-model accuracy table presented in Step 12.

**STOP. Use the Read tool on `references/save-and-export.md` (relative to this skill's directory). Do NOT write any MATLAB code for these steps until you have read that file. Follow its instructions exactly as written.**

If the user declines to save any models, the workflow is complete — Step 14 is not offered.

## Behavioral guardrails

These guardrails apply to the user-facing summary and recommendations, not to MATLAB code (see `scripts/README.md` for code-level rules).

Do NOT:
- Make generic textbook claims about model properties (overfitting risk, robustness) that are not supported by the actual results
- Recommend a single model for production use based on accuracy alone

## Bundled files

### References (loaded on demand)

- **`references/README.md`** — layout: how `references/` and `scripts/` split responsibilities, and why the branch-table `.m` files must live in `references/`
- **`references/dataprep.md`** — analyzes and cleans data, computes characteristic flags (Step 2)
- **`references/select-classifiers.md`** — selects promising models based on dataset characteristics and interpretability rating (Step 5)
- **`references/select-classifiers-imbalanced.md`** — boosting/uniform-prior overrides for imbalanced data (read from Step 5 when `isImbalanced`)
- **`references/hpo.md`** — hyperparameter optimization for user-selected models (Step 11)
- **`references/save-and-export.md`** — save selected trained models to `.mat` and emit a self-contained retraining `.m` script (Steps 13 and 14)
- **`references/classifier_branches.m`** — assembles the `BRANCHES` struct array (sparse / many-missing / categorical / wide / regular) via `run(...)`; invoked from `build_model_definitions`. Not called directly by the agent.
- **`references/classifier_thresholds.m`** — declarative thresholds shared by the branch tables (populates `THRESHOLDS`). Not called directly by the agent.
- **`references/branch_sparse.m`, `branch_many_missing.m`, `branch_categorical.m`, `branch_wide.m`, `branch_regular.m`** — one file per branch; each appends its models to `BRANCHES` via `model_recipe(...)`. Not called directly.
- **`references/imbalanced_boosting.m`** — overlay of boosting recipes applied when `isImbalanced`; populates `IMBALANCED_BOOSTING_MODELS`. Not called directly.
- **`references/model_recipe.m`** — recipe constructor used only inside the branch `.m` files. Kept in `references/` so `run(...)` chains resolve it (see `references/README.md`).

### Scripts (called by the agent)

- **`scripts/README.md`** — code-level rules (use built-ins, don't inspect templates, training-time rules, figure rules)
- **`scripts/build_model_definitions.m`** — assembles the `modelDefs` struct array from `flags` + branch table; handles branch dispatch, recipe filters, `resolve_recipe`, and OVO/OVA expansion. Call from Step 5 with `project_path` set to `scripts/`.
- **`scripts/resolve_recipe.m`** — resolves function-valued recipe args to concrete scalars using `flags`. Called by `build_model_definitions`.
- **`scripts/find_zero_variance_columns.m`** — sparse-safe zero-variance column detection (used by `references/dataprep.md`)
- **`scripts/compute_data_flags.m`** — computes the dataset-characteristic flags consumed by Step 5 (used by `references/dataprep.md`)
- **`scripts/is_bag_of_tokens.m`** — sparse-safe check for non-negative integer values (used by `references/select-classifiers.md`)
- **`count_categorical_levels`** — total number of categorical levels in a table (used by `references/select-classifiers.md`; p-coded per `scripts/.pcode`)
- **`stratified_subsample`** — per-class capped subsample preserving class proportions (used by `references/select-classifiers.md`; p-coded per `scripts/.pcode`)
- **`scripts/make_holdout_split.m`** — stratified train/test split (Step 3)
- **`scripts/train_and_score_cv.m`** — CV training, accuracy CI, per-fold accuracies (Step 6, CV path)
- **`scripts/train_and_score_holdout.m`** — holdout training, accuracy CI, predictions; handles the `ClassificationNeuralNetwork` exception (Step 6, holdout path)
- **`scripts/compute_pairwise_pvalues_cv.m`** — pairwise `testckfold` p-value matrix, diagonal seeded with 1 (Step 8, CV path)
- **`scripts/compute_pairwise_pvalues_holdout.m`** — pairwise `testcholdout` p-value matrix, diagonal seeded with 1 (Step 8, holdout path)
- **`scripts/plot_pvalue_heatmap.m`** — pairwise p-value heatmap (Step 8)
- **`scripts/plot_accuracy_bars.m`** — accuracy bar chart with 95% CI (Step 9)
- **`scripts/plot_training_time.m`** — training-time bar chart (Step 9)
- **`scripts/plot_boosting_curve.m`** — boosting learning curve, holdout or CV (Step 10)
- **`scripts/resume_boosting_holdout.m`** — resume an ensemble with more trees on the holdout path; recompute accuracy and predictions (Step 10)
- **`scripts/resume_boosting_cv.m`** — resume a cross-validated ensemble with more trees on the CV path; recompute accuracy and per-fold accuracies via `kfoldLoss` (Step 10)
- **`scripts/score_holdout_test.m`** — final accuracy + 95% CI on the held-out test set (used by `references/hpo.md`)
- **`scripts/aggregate_nested_cv_loss.m`** — aggregate out-of-fold predictions into accuracy + 95% CI, with optional uniform-prior weighting (used by `references/hpo.md`)
- **`scripts/sanitize_model_name.m`** — convert a model display name (e.g., `LinearSVM-OVO`) into a valid MATLAB identifier (`LinearSVM_OVO`). Shared by `save_selected_models` and the retraining script emitted by `export_workflow_script` so both sides sanitize identically.
- **`scripts/save_selected_models.m`** — save user-selected trained models to a `.mat` file, retraining CV-wrapped models on full data via `modelDefs(k).fitFcn` so what's saved is deployable (Step 13)
- **`scripts/apply_preproc.m`** — replay recorded `preproc` ops on new data (used by the exported workflow script; Step 14)
- **`scripts/retrain_with_hpo.m`** — single-shot HPO on the full training set (used by the exported workflow script; Step 14)
- **`scripts/retrain_with_resume.m`** — retrain an ensemble with extra learning cycles baked into `NumLearningCycles` (used by the exported workflow script; Step 14)
- **`scripts/export_workflow_script.m`** — emit a self-contained retraining workflow `.m` script (Step 14)

---

Copyright 2026 The MathWorks, Inc.
