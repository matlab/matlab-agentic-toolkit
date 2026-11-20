# Train and Score Every Model

Run this as Step 6, after Step 5 has built `modelDefs`. Train every entry of `modelDefs`.

## Static check gate (mandatory, before any training call)

Before you execute *any* MATLAB code in this step, first save that code to a `.m` file and run `mcp__matlab__check_matlab_code` on it. Then grep the same source for the four banned patterns below and abort — do not execute — if any of them appear anywhere in the file:

| Banned token / pattern | Why it is wrong |
|---|---|
| `fitensemble(` (no "c") | Retired API. Use `modelDefs(k).cvFitFcn` or `modelDefs(k).template` — both bake in the modern `fitcensemble` call for you. |
| `'Learners', templateEnsemble` (any casing/whitespace) | An ensemble template cannot be an ECOC learner. To train an ensemble, call the ensemble template with `fit(...)`, or (much better) use `modelDefs(k).cvFitFcn` / `.template`. |
| `fitcensemble(` typed by hand in Step 6 | The helper in `build_model_definitions.m` already emits `fitcensemble(X, Y, 'Method', ..., 'NumLearningCycles', ..., 'Learners', innerTmpl)` under the `cvFitFcn` closure. Hand-typing it re-introduces the retired positional signature nine times out of ten. |
| Any other `fitc*(` typed by hand in Step 6 | Same reason: `modelDefs(k).cvFitFcn` and `train_and_score_holdout(modelDefs(k).template, ...)` are the only sanctioned entry points for training in this step. |

If the check gate flags any of these, the correct response is *not* to rewrite the fit call — it is to replace it with `train_and_score_cv(modelDefs(k).cvFitFcn, X, Y, cvp)` (CV path) or `train_and_score_holdout(modelDefs(k).template, XTrain, YTrain, XTest, YTest, useUniformPrior)` (holdout path). Only these two calls appear in Step 6's training loop.

## Uniform prior for imbalanced data

If `useUniformPrior = true`:

- **CV path:** pass `'UseUniformPrior', true` to `build_model_definitions` in Step 5. Every `modelDefs(k).cvFitFcn` will then append `'Prior','uniform'` to its fit call. Do NOT modify `cvFitFcn` yourself — the closure already exists and the flag is the only supported entry point.
- **Holdout path:** pass `useUniformPrior` as the 6th argument to `train_and_score_holdout`.

## CV path (`hasHoldout = false`)

For each model, call `train_and_score_cv`. It runs the model's `cvFitFcn` and returns `cvModel`, `trainTime`, `acc`, `accCI` (95% CI from `binofit`), and `foldAcc` — the per-model per-fold accuracy vector (nFolds × 1).

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

The nFolds × nModels shape is exactly what `friedman(foldAcc, 1, 'off')` expects in Step 7 — folds are treatments applied within each subject-model. Do NOT collect `foldAcc` into a cell array, and do NOT concatenate along the wrong dimension.

Report a table of cross-validated accuracies with 95% confidence intervals.

## Holdout path (`hasHoldout = true`)

For each model, call `train_and_score_holdout`. It handles the `ClassificationNeuralNetwork` exception (R2026a and earlier, where the "template" is actually a trained model) and the optional `'Prior','uniform'` flag. It returns the trained `model`, `trainTime`, `acc`, `accCI`, and `YHat` (the prediction vector on the test set).

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

----

Copyright 2026 The MathWorks, Inc.

----
