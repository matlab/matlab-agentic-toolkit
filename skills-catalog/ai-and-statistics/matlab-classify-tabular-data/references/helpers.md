# Call the Bundled Helpers

Call these functions by name with `project_path` set to this skill's `scripts/helpers/` folder. Do not read their source; this page is their interface. Functions marked *(p-coded)* ship as `.p` files.

## Shared workflow variables

Define each variable once, at the step shown, and reuse it:

| Variable | Set in | Value |
|---|---|---|
| `skillPath` | first code block | `fileparts(fileparts(pwd))` — the skill root |
| `hasHoldout` | Step 1 or 3 | `true` with a supplied or chosen test set, else `false` |
| `X`, `Y` / `XTrain`, `YTrain`, `XTest`, `YTest` | Steps 1–3 | full data (CV path) / split data (holdout path) |
| `cvp` | Step 3, CV path | `cvp = cvpartition(Y, 'KFold', 5, 'Stratify', true);` |
| `interpretability` | Step 4 | `'low'` or `'high'` |
| `useUniformPrior` | Step 5 | `true` only if the user chose the uniform prior (imbalanced data); otherwise `false` |
| `modelDefs`, `modelNames` | Step 5 | from `build_model_definitions`; `modelNames = {modelDefs.name};` |
| `acc`, `accCI`, `trainTime` | Step 6 | one entry (row of `accCI`) per model |
| `foldAcc`, `cvModels` | Step 6, CV path | `nFolds × nModels` matrix; cell array of CV models |
| `trainedModels`, `YHat` | Step 6, holdout path | cell arrays of trained models and test-set predictions |
| `alpha_corrected` | Step 8 | `0.05 / nchoosek(nModels, 2)` |
| `pvalMatrix`, `hMatrix` | Step 8 | pairwise p-values; `hMatrix = pvalMatrix < alpha_corrected` |
| `bestIdx`, `topTierIdx` | Step 8 | `[~, bestIdx] = max(acc); topTierIdx = find(~hMatrix(bestIdx, :));` |
| `evalPath` | Step 9 | `'holdout'` if `hasHoldout`, else `'cv'` |

## Data preparation (Step 2)

- **`[X, Y, info] = drop_unusable_rows(X, Y)`** *(p-coded)* — removes rows with a missing label or with every predictor missing; a char-matrix `Y` becomes cellstr. `info.nMissingLabel`, `info.nAllPredictorsMissing`.
- **`idx = find_zero_variance_columns(X)`** — indices of globally constant columns of a matrix (sparse-safe) or table; missing values never count as a value.
- **`flags = compute_data_flags(X, Y)`** *(p-coded)* — dataset flags: `N`, `D`, `nClasses`, `classSize`, `smallestClassSize`, `classRatio`, `isBinary`, `isImbalanced`, `isWide`, `isHighD`, `isBig`, `hasManyMissing`, `isSparse`, `hasCategorical`.
- **`[XTest, YTest, info] = drop_unseen_test_classes(XTest, YTest, YTrain)`** *(p-coded)* — removes test observations of classes absent from training. `info.removedClasses`, `info.removedCounts`, `info.nRemaining`.
- **`[X, Y] = apply_preproc(preproc, X, Y)`** *(p-coded)* — replays recorded `preproc` ops (used by the exported script).

## Evaluation split and model list (Steps 3 and 5)

- **`[XTrain, YTrain, XTest, YTest] = make_holdout_split(X, Y, holdoutFraction)`** *(p-coded)* — stratified split; `holdoutFraction` defaults to 0.3.
- **`n = count_categorical_levels(T)`** *(p-coded)* — total categorical levels in a table; set `flags.totalCatLevels = count_categorical_levels(X);` before Step 5.
- **`tf = is_bag_of_tokens(X)`** — true when every value is a non-negative integer (sparse-safe); gates `NaiveBayesMN`.
- **`[Xsub, Ysub] = stratified_subsample(X, Y, classes, perClassMax)`** *(p-coded)* — per-class capped subsample; `classes` lists the distinct labels. All four inputs are required.
- **`modelDefs = build_model_definitions(flags, skillPath, Name=Value)`** — the model list for the data. Options: `'X'`, `'Y'` (training data; always pass them), `'ImbalancedOverlay'` (`IMBALANCED_BOOSTING_MODELS`, imbalanced data), `'UseUniformPrior'` (CV path). Each entry has `.name`, `.template`, `.cvFitFcn`, `.fitFcn`, `.fnName`, `.hyperparameters`, `.innerLearner_fnName`, `.innerLearner_hyperparameters`. Example: `modelDefs = build_model_definitions(flags, skillPath, 'X', XTrain, 'Y', YTrain);`
- **`tmpl = model_inner_template(modelDef)`** — the model's own inner learner, for `'Learners'` in HPO calls.

## Training and scoring (Step 6)

- **`[cvModel, trainTime, acc, accCI, foldAcc] = train_and_score_cv(cvFitFcn, X, Y, cvp)`** *(p-coded)* — CV training; `accCI` is a 95% Clopper-Pearson interval; `foldAcc` is `nFolds × 1`. Example: `train_and_score_cv(modelDefs(k).cvFitFcn, X, Y, cvp)`.
- **`[model, trainTime, acc, accCI, YHat] = train_and_score_holdout(template, XTrain, YTrain, XTest, YTest, useUniformPrior)`** *(p-coded)* — holdout training and test-set scoring.
- **`[acc, accCI, YHat] = score_holdout_test(model, XTest, YTest)`** *(p-coded)* — accuracy and CI of a trained model on the test set.

## Comparison and plots (Steps 8 and 9)

- **`[pvalMatrix, hMatrix, info] = compute_pairwise_pvalues_cv(modelDefs, X, Y, alpha, Name=Value)`** *(p-coded)* — every pair by the 5×2 F-test (`testckfold`), seeded per pair. Options: `'UseUniformPrior'`, `'Models'` (indices to re-test), `'PValues'` (previous matrix to keep), `'DensifyMaxBytes'`. `info.test`, `info.reason` (non-empty when sparse `X` forced a holdout `testcholdout` comparison).
- **`[pvalMatrix, hMatrix] = compute_pairwise_pvalues_holdout(YHat, YTest, alpha)`** — every pair by McNemar's test (`testcholdout`) on the stored predictions.
- **`plot_pvalue_heatmap(pvalMatrix, modelNames, titleStr)`** — p-value heatmap.
- **`plot_accuracy_bars(modelNames, acc, accCI, topTierIdx, titleStr)`** — accuracy bars with 95% CI, top tier highlighted.
- **`plot_training_time(modelNames, trainTime, acc, topTierIdx)`** — training-time bars.

## Boosting resume (Step 10)

- **`plot_boosting_curve(boostModel, boostModelName, hasHoldout, XTest, YTest)`** — learning curve; on the CV path pass `[]` for `XTest`, `YTest`.
- **`[boostModel, trainTime, acc, accCI, YHat] = resume_boosting_holdout(boostModel, nMoreTrees, XTest, YTest)`**
- **`[cvBoostModel, trainTime, acc, accCI, foldAcc, oofPreds] = resume_boosting_cv(cvBoostModel, nMoreTrees)`**
- **`modelDef = resume_model_definition(modelDef, nMoreCycles, useUniformPrior)`** — rebuilds a resumed model's `modelDefs` entry at its new size.

## Hyperparameter optimization (Step 11)

- **`[acc, accCI] = aggregate_nested_cv_loss(YHatOpt, Y, useUniformPrior)`** *(p-coded)* — accuracy and CI from nested-CV out-of-fold predictions.
- **`mdl = retrain_with_hpo(modelDef, X, Y, useUniformPrior, MaxObjectiveEvaluations=30)`** — single-shot search on the full training data.

## Save and export (Steps 13 and 14)

- **`savedPath = save_selected_models(selectedNames, modelDefs, trainedModels, X, Y, savePath, metadata, useCompact, Name=Value)`** — saves the selected models; CV models are retrained on the full data. On the CV path pass `cvModels` as `trainedModels`. Options: `'HpoModels'` (models optimized in Step 11), `'UseUniformPrior'`.
- **`s = sanitize_model_name(name)`** — `'LinearSVM-OVO'` → `'LinearSVM_OVO'`.
- **`mdl = retrain_with_resume(modelDef, X, Y, extraCycles, useUniformPrior)`** — used by the exported script.
- **`exportedPath = export_workflow_script(scriptPath, config)`** — writes the retraining script. `config` fields: `skillPath`, `selectedNames`, `preproc`, `interpretability`, `useUniformPrior`, `useCompact`, `modelSavePath` (where the script saves its models; relative paths resolve against the folder the script is run from), `datasetLabel` (short label for comments), and optional `hpoModels` (default `{}`), `resumeCycles` (struct: sanitized model name → extra cycles, default `struct()`), `useImbalancedOverlay` (force the overlay on; default `false`, the script detects imbalance itself).

## Do not call directly

Do not call `to_class_label` *(p-coded)* or `resolve_recipe`; other helpers use them. Do not read or edit the files in `scripts/model_catalog/`; run only `classifier_thresholds.m` (Step 3) and `imbalanced_boosting.m` (Step 5) as SKILL.md shows.

----

Copyright 2026 The MathWorks, Inc.

----
