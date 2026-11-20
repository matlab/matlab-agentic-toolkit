---
name: matlab-classify-tabular-data
description: >
  Use this skill to classify tabular data end-to-end in MATLAB — load a dataset, prepare and clean
  it, select promising classifiers, train them, and compare accuracies with cross-validation,
  holdout, or hyperparameter optimization plus statistical tests.
  TRIGGER when: user asks to classify tabular data, pick classifiers for a dataset, compare the
  accuracy of several classifiers by cross-validation or holdout, or find the best model with
  statistical uncertainty.
  DO NOT TRIGGER when: user has non-tabular inputs (images, sequences, time series), wants a
  regression model, wants the Classification or Regression Learner app (use
  matlab-use-machine-learning-apps), evaluates one model already chosen, is training a specific
  neural network architecture (use matlab-train-network), or wants cost-sensitive learning or an
  arbitrary class-prior vector (use fitc* with 'Prior' or 'Cost'; this skill only supports the
  built-in uniform-prior toggle).
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.2"
---

# Compare Classification Models with Statistical Uncertainty

Compare classifiers on the user's dataset and identify the top tier of models that are statistically equivalent in accuracy. The workflow below runs in order; each step that says **STOP** loads a file from `references/` with the Read tool before any code for that step. Those files are not separate skills.

## When to Use

- User wants to classify tabular data (matrix or table of predictors + categorical response).
- User asks to compare multiple classifiers, pick the best model, or evaluate classifier accuracy.
- User needs cross-validation, a holdout evaluation, or hyperparameter optimization for classifiers.
- User needs statistical tests (McNemar, 5×2 cv, Friedman) to know which accuracy differences are significant.

## When NOT to Use

- Response is continuous — use the `fitr*` functions, or the Regression Learner app through `matlab-use-machine-learning-apps`.
- User wants to work in the Classification Learner or Regression Learner app, or export a model to Simulink, MATLAB Coder or MATLAB Production Server — use `matlab-use-machine-learning-apps`.
- User wants to explain a trained model (predictor importance, partial dependence, single predictions), or to engineer or select features — use `matlab-interpret-machine-learning-model` or `matlab-engineer-tabular-features`.
- Predictors are images, sequences, or time series — use `matlab-train-network`, or extract tabular features first with `matlab-engineer-tabular-features`.
- User wants to design or train a specific neural network architecture — use `matlab-train-network`. This skill includes `fitcnet` as one candidate but does not tune network layers.
- User only wants to score a pretrained model on new data — call `predict` on that model directly.
- **User wants cost-sensitive learning or a custom class-prior vector.** Refuse plainly and stop; do not work around the helpers. The only supported prior control is the uniform-prior toggle for imbalanced data, and the pairwise tests score misclassification rate, not expected cost. Tell the user: *"This skill does not support custom class priors or cost matrices. If you need cost-sensitive learning or a specific prior vector, use `fitc*` directly with the `'Prior'` or `'Cost'` name-value pair; this skill's statistical-comparison workflow will not give correct results in that setting."*

## Running MATLAB

Run all MATLAB code via the MATLAB MCP server (`mcp__matlab__evaluate_matlab_code`, or `mcp__matlab__run_matlab_file` for scripts). Set `project_path` to this skill's `scripts/helpers/` directory so the helpers resolve on the current folder without `addpath`. Every helper, its signature and the shared variable names are in `references/helpers.md`; read it before Step 1.

## Before Writing Code

**STOP. Use the Read tool on `references/communication.md` and `references/helpers.md`.** Talk to the user about their data and results, never about this skill's files or internal steps.

- Do not reuse variables from earlier runs; set every variable from scratch.
- Set `skillPath = fileparts(fileparts(pwd));` in the first code block (the skill root; `pwd` is `scripts/helpers/`).
- For code-level rules (use built-ins, do not inspect template objects, training-time and figure rules), see `scripts/README.md`.

## Step 1: Load data

- Load the dataset.
- If a separate test set is provided, set `hasHoldout = true` and assign `XTrain`, `YTrain`, `XTest`, `YTest`. Otherwise assign `X`, `Y`; do not split or ask about splitting yet.

If any predictor is categorical, `X` must be a **table** with those columns stored as `categorical`, `string` or `cellstr`. Assemble separate mixed-type variables with `table(...)`; never concatenate them into a numeric matrix, which turns categories into numeric codes.

## Step 2: Analyze and clean data

**STOP. Use the Read tool on `references/dataprep.md`. Do NOT write any MATLAB code until you have read that file. Follow its instructions exactly as written.**

Run it on `XTrain`/`YTrain` when `hasHoldout`, else on `X`/`Y`. On return the workspace holds `flags` (from `compute_data_flags`) and a `preproc` struct array recording every change to X or Y in order. Use only the op names that file lists (`omitColumns`, `dropZeroVariance`, `removeClasses`, `mergeClasses`); the exported Step 14 script cannot replay any other.

## Step 3: Choose evaluation strategy

If `hasHoldout = true` (dataset came with a separate test set): skip this step.

Otherwise, load the thresholds and use `flags.smallestClassSize` (computed in Step 2) to present a recommendation:

```matlab
run(fullfile(skillPath, 'scripts', 'model_catalog', 'classifier_thresholds.m'));  % populates THRESHOLDS
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

Wait for the user's response. If the user chooses holdout, create the split with `make_holdout_split` and set `hasHoldout = true`. If the user chooses cv, set `hasHoldout = false` and create the folds: `cvp = cvpartition(Y, 'KFold', 5, 'Stratify', true);`

All subsequent steps operate on the training data (`XTrain`/`YTrain` when `hasHoldout`, or `X`/`Y` otherwise).

## Step 4: Ask about interpretability

Before selecting models, ask the user:

> How important is model interpretability for this task? (low / high)

Record the answer as `interpretability` (`'low'` or `'high'`). **high**: predictions must be explainable to a human (trees, discriminant analysis, logistic regression). **low**: accuracy is the priority; all model families are candidates.

## Step 5: Select and define model templates

**STOP. Use the Read tool on `references/select-classifiers.md`. Do NOT write any MATLAB code until you have read that file. Follow its instructions exactly as written.**

The model list `build_model_definitions` returns is exhaustive: do not add models it does not produce. The only allowed changes are the interpretability filter, the imbalanced-data overlay, and explicit user requests.

If `flags.isImbalanced`, also Read `references/select-classifiers-imbalanced.md` for the boosting overlay, the **mandatory** uniform-prior decision, and the extreme-imbalance advisory.

**Extreme imbalance:** when that reference's advisory condition holds, send the advisory as a chat message before Step 6 and wait for the answer. In a non-interactive session, include the advisory in your reply and say which choice you applied. In an interactive session, pose the uniform-prior question verbatim and wait for the answer before any `fit*` call. In a non-interactive session where you have been told not to prompt, still surface the choice: name both options (`Prior='uniform'` vs `Prior='empirical'`), say which one you are using and why, and note that this is normally the user's call. Silently defaulting — even when the domain (fraud detection, medical screening) makes one option sound obvious — is a hard failure of the imbalanced workflow.

```matlab
% Training data: XTrain/YTrain on the holdout path, X/Y on the CV path.
flags.interp = interpretability;
flags.totalCatLevels = count_categorical_levels(XTrain);
modelDefs = build_model_definitions(flags, skillPath, 'X', XTrain, 'Y', YTrain);
% Imbalanced data: run(fullfile(skillPath, 'scripts', 'model_catalog', 'imbalanced_boosting.m'));
% then add 'ImbalancedOverlay', IMBALANCED_BOOSTING_MODELS and, on the CV path, 'UseUniformPrior', useUniformPrior.
modelNames = {modelDefs.name};
```

Multiclass ECOC recipes appear twice (`-OVO` and `-OVA`). Train every entry. **Never type a `fitc*` or `fitensemble` call to train these models**: the correct fit call is baked into `modelDefs(k).cvFitFcn` (CV path) and `modelDefs(k).template` (holdout path).

## Step 6: Get baseline accuracy estimates

**STOP. Use the Read tool on `references/training.md`. Do NOT write any MATLAB code for this step until you have read that file. Follow its instructions exactly as written.**

It covers the mandatory static check gate, the training loop for each path (`train_and_score_cv` with `cvp`, or `train_and_score_holdout`), and the per-model results table with 95% confidence intervals.

## Step 7: Choose the statistical comparison method

- **CV path** (`hasHoldout = false`): run a Friedman omnibus test on `foldAcc` first, then proceed to pairwise `testckfold` in Step 8. Do not follow Friedman with `multcompare` — pairwise comparisons come from `testckfold`.

  ```matlab
  [pFriedman, tbl, stats] = friedman(foldAcc, 1, 'off');
  ```

- **Holdout path** (`hasHoldout = true`): skip Friedman (no folds exist); proceed directly to pairwise `testcholdout` in Step 8.

## Step 8: Run the comparison

- Compare **all** pairs of models (not just against the best), with p-values in a symmetric matrix.
- Apply Bonferroni correction: `alpha_corrected = 0.05 / nchoosek(nModels, 2)`.
- The top tier is every model not significantly different from the best after correction: `[~, bestIdx] = max(acc); topTierIdx = find(~hMatrix(bestIdx, :));`
- Report the full pairwise p-value matrix as a table.

Do NOT hand-write the pairwise loop. Both helpers seed the diagonal with 1.

```matlab
% CV path: testckfold (5x2 F-test), under the run's prior, each pair seeded
[pvalMatrix, hMatrix, cmpInfo] = compute_pairwise_pvalues_cv(modelDefs, X, Y, alpha_corrected, 'UseUniformPrior', useUniformPrior);
% Holdout path: testcholdout (McNemar) on the stored prediction vectors
[pvalMatrix, hMatrix] = compute_pairwise_pvalues_holdout(YHat, YTest, alpha_corrected);
```

On the CV path, if `cmpInfo.reason` is not empty (sparse `X` too large to densify), tell the user `cmpInfo.reason` and name `cmpInfo.test` as the test used.

ALWAYS show the p-value matrix as a heatmap, on both paths:

```matlab
plot_pvalue_heatmap(pvalMatrix, modelNames, sprintf('Pairwise testckfold p-values (Friedman p = %.4f)', pFriedman));  % CV path
plot_pvalue_heatmap(pvalMatrix, modelNames, 'Pairwise testcholdout p-values (McNemar)');                              % holdout path
```

## Step 9: Visualize

Show two figures by calling `plot_accuracy_bars` and `plot_training_time`. Both sort models by descending accuracy and highlight top-tier models.

```matlab
evalPath = 'cv'; if hasHoldout, evalPath = 'holdout'; end
plot_accuracy_bars(modelNames, acc, accCI, topTierIdx, ...
    sprintf('Accuracy with 95%% CI (path: %s)', evalPath));
plot_training_time(modelNames, trainTime, acc, topTierIdx);
```

## Step 10: Boosting learning curve

If `modelDefs` contains boosting models (`fitcensemble` with `Method` RUSBoost, LogitBoost, AdaBoostM1, AdaBoostM2 or GentleBoost):

**STOP. Use the Read tool on `references/boosting.md`. Follow its instructions exactly as written** — learning curves, the resume question, updating the model definition, re-testing only the resumed models' pairs, and redrawing the Step 8 and Step 9 figures.

## Step 11: Hyperparameter optimization (optional)

Ask whether to run HPO and on which models. Print the top tier and the other models as plain chat text, each numbered by its position in `modelNames` so the user can answer with numbers, then ask. Mention that HPO on the CV path uses nested cross-validation and can be slow. If the user declines, go to Step 12 without reading `references/hpo.md`.

Otherwise: **STOP. Use the Read tool on `references/hpo.md`. Do NOT write any MATLAB code until you have read that file. Follow its instructions exactly as written.**

## Step 12: Summary

Report:
- The chosen statistical test and why
- The top tier of statistically equivalent models
- Which model has the highest mean accuracy (even if not significantly better)

Include the per-model accuracy and 95% CI for every trained model so the user has enough context to decide what to save in Step 13. If Step 11 optimized models on the CV path, say once, unprompted, that the top tier and p-values were computed before optimization and the optimized models were not re-tested.

**Consistent metric naming:** Pick one of accuracy or error rate and use it consistently throughout the summary. Do NOT mix them — never label an accuracy value with the word "error", or an error value with "accuracy". If you say "lowest mean error", the values reported must be error rates (e.g., 5.1%); if you say "highest mean accuracy", the values must be accuracy (e.g., 94.9%). The same rule applies to confidence intervals.

## Steps 13 and 14: Save models and export retraining script (optional)

Offer them in order after the Step 12 summary: Step 13 saves selected models (`save_selected_models`), Step 14 writes a retraining script (`export_workflow_script`) and is offered only if models were saved.

**STOP. Use the Read tool on `references/save-and-export.md`. Do NOT write any MATLAB code for these steps until you have read that file. Follow its instructions exactly as written.**

## Behavioral guardrails

- **Always:** train every model `build_model_definitions` returns; report accuracy with its 95% CI; compare all pairs with Bonferroni correction; record every data change in `preproc`.
- **Ask first:** evaluation strategy (Step 3), interpretability (Step 4), uniform prior and extreme imbalance (Step 5), the NaiveBayesMN model (sparse data), resuming boosting (Step 10), HPO (Step 11), saving and exporting (Steps 13–14).
- **Never:** type `fitc*` or `fitensemble` calls to train the models; add models the helper did not return; support custom priors or cost matrices; make generic textbook claims about model properties that the results do not support; recommend a single model for production on accuracy alone.

## Key functions

| Function | Used for | Product |
|---|---|---|
| `testckfold` | Pairwise 5×2 CV F-test (CV path) | Statistics and Machine Learning Toolbox |
| `testcholdout` | Pairwise McNemar test (holdout path) | Statistics and Machine Learning Toolbox |
| `friedman` | Omnibus test across folds (CV path) | Statistics and Machine Learning Toolbox |
| `binofit` | Clopper-Pearson 95% CI of accuracy | Statistics and Machine Learning Toolbox |
| `cvpartition` | Stratified folds and holdout split | Statistics and Machine Learning Toolbox |
| `bestPoint` | Settings of an optimized model | Statistics and Machine Learning Toolbox |
| `templateNeuralNetwork` | Neural network template (R2026b+; earlier releases use a `fitcnet` placeholder) | Statistics and Machine Learning Toolbox |

## Bundled files

- **`references/helpers.md`** — every helper's signature and the shared workflow variables (read before Step 1)
- **`references/communication.md`** — how to talk to the user while running (read before Step 1)
- **`references/dataprep.md`** — Step 2; **`references/select-classifiers.md`** and **`references/select-classifiers-imbalanced.md`** — Step 5; **`references/training.md`** — Step 6; **`references/boosting.md`** — Step 10; **`references/hpo.md`** — Step 11; **`references/save-and-export.md`** — Steps 13 and 14
- **`references/README.md`** — layout of `references/`, `scripts/helpers/` and `scripts/model_catalog/`
- **`scripts/README.md`** — code-level rules
- **`scripts/helpers/`** — the functions the workflow calls; **`scripts/model_catalog/`** — branch tables read only by `build_model_definitions` (do not read them)

----

Copyright 2026 The MathWorks, Inc.

----
