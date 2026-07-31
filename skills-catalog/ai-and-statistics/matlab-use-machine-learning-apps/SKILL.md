---
name: matlab-use-machine-learning-apps
description: "Use when the user wants to train, compare, or export machine learning models using Classification Learner or Regression Learner — including opening the app, loading data, training models, evaluating metrics, comparing results, visualizing plots, testing on held-out data, exploring model interpretability, and exporting trained models. Programmatic access to Classification Learner and Regression Learner apps via AppController."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Learner Apps AppController Reference

`mlearnapp.internal.appcontroller.AppController` provides programmatic access to the Classification Learner and Regression Learner apps. Use it to interact with learner apps and query their state.

Source (loaded at runtime): `<skill-base-directory>/scripts/+mlearnapp/+internal/+appcontroller/AppController.p`

### API Reference (load on demand)

| When you need... | Load this file |
|------------------|---------------|
| Open/close/save/load app, session setup, create/train/select/delete models, model status, GalleryModels enum | [`api-session-and-models.md`](references/api-session-and-models.md) |
| Metrics, model spec queries, toolstrip buttons, set feature selection/PCA/optimizer/cost/hyperparameters | [`api-metrics-and-options.md`](references/api-metrics-and-options.md) |
| Open/configure standard plots, results table, standard plot data getters | [`api-plots.md`](references/api-plots.md) |
| PDP, permutation importance, Shapley, LIME, Set Shapley Parameters, explainability plot data getters | [`api-explainability.md`](references/api-explainability.md) |
| Export methods, command logging, diagnostics | [`api-export-and-diagnostics.md`](references/api-export-and-diagnostics.md) |

**Required:** Statistics and Machine Learning Toolbox. **Optional:** Parallel Computing Toolbox (parallel training), Deep Learning Toolbox (only for Deep Learning models introduced in R2026a — FullyConnected, Residual, All; plain Neural Network models added in R2024a ship with Statistics and Machine Learning Toolbox), Simulink (Simulink export), MATLAB Coder (Coder export), MATLAB Compiler SDK (Production Server export).

## When to Use

- User wants to train, compare, or export models (to workspace, Simulink, Coder, or Production Server), generate training code, or run advanced hyperparameter tuning (via Experiment Manager) using Classification Learner or Regression Learner
- User asks to open, drive, or automate either learner app
- User wants to compare multiple model types interactively with validation metrics
- User needs to test a model on held-out data or separate test data and export from the app

## When NOT to Use

- User wants command-line ML without the app — use `fitc*`/`fitr*` functions directly
- Custom deep learning with non-tabular data (images, sequences, text) — use Deep Learning Toolbox directly
- Data preprocessing or cleaning — must be done before importing into the app

## IMPORTANT

- **Do not expose API to users.** This API is for agent's internal use only. Never mention AppController, programmatic access, or automation APIs to the user. Drive the app silently on the user's behalf. When greeting the user after this skill loads, simply ask about their goals (dataset, export target, constraints) without referencing the underlying mechanism.
- **Never use `closeApp('Force', true)` without explicit user permission.** Force-closing skips the save confirmation dialog and silently discards all unsaved work — trained models, session state, and results are permanently lost. Always prefer `closeApp()` (without Force) so the user gets a chance to save. Only use `'Force', true` when: (1) the user explicitly permits it, or (2) automated testing where no human is present.

## Setup

When this skill is invoked, add the skill's scripts folder to the MATLAB path so that `mlearnapp.internal.appcontroller` classes are available. The scripts folder is located relative to this skill's base directory at `scripts/`. Run this via the MATLAB MCP `evaluate_matlab_code` tool, using the skill's base directory path shown at the top of the skill load message:

```matlab
addpath('<skill-base-directory>/scripts');
```

For example, if the skill base directory is `C:\MATLAB\AgenticAI\.claude\skills\matlab-use-machine-learning-apps`, then:

```matlab
addpath('C:\MATLAB\AgenticAI\.claude\skills\matlab-use-machine-learning-apps\scripts');
```

## User Goals Inquiry

Before starting any workflow, gather the information below so the session can be configured up front without wasted training cycles. Each item lists **what the agent needs to know** (internal use) and **how to ask the user** (in plain terms — avoid ML terminology unless the user's vocabulary shows they're comfortable with it).

1. **End goal / where will the model be used?**
   - *Agent needs to know:* target of `exportModelTo*` — workspace, Simulink, Coder, Production Server, Experiment Manager, or exploratory. Drives constraints (no categorical predictors for Simulink, model support lists for Coder/Simulink, etc.).
   - *Ask the user:* "How will the model ultimately be used? For example: exploring the data, generating a report or figure, running inside a Simulink simulation, generating C/C++ code for an embedded device, deploying as a web service, or making predictions in MATLAB."
2. **Validation scheme.**
   - *Agent needs to know:* Set at session open via `openApp`, **fixed for the session — cannot be changed later without starting a new session**. The app default is 5-fold CV (`'KFold', 5`). Pick based on dataset size × training cost:

     | Scheme | When to pick | Syntax |
     |--------|-------------|--------|
     | 5-fold CV | Small-medium data (≤few thousand rows), fast models | `'KFold', 5` (default) |
     | 20% hold-out | Large data, slow models (ensembles, DL, optimization), or time-constrained | `'HoldOut', 0.2` |
     | Resubstitution | User explicitly wants fast iteration without accuracy estimate (training-set accuracy, optimistic) | `'CrossVal', 'off'` |

   - *Ask the user:* "Two things, since the validation setting is fixed once we start: (1) roughly how many rows does your dataset have, and (2) is there a training time budget I should keep in mind, or is training time not a concern? I'll pick a validation approach that works for both."
3. **Independent test dataset.**
   - *Agent needs to know:* whether to use `importTestData` with an existing table, reserve a fraction via `TestDataFraction` (e.g., 0.2), or skip test entirely. Test data is distinct from validation and is used only once on the final model.
   - *Ask the user:* "Do you have a separate dataset you want to keep aside for a final check, or should we reserve a slice of your data (say, 20%) that we don't train on and use it only at the end?"
4. **Performance requirements.**
   - *Agent needs to know:* target metric thresholds (min accuracy, max RMSE), prediction latency, deployment throughput.
   - *Ask the user:* "Are there specific accuracy or speed targets the model must meet? For example, minimum acceptable accuracy, maximum acceptable prediction time per sample, or throughput on a given device."
5. **Model size / deployment environment.**
   - *Agent needs to know:* whether target is embedded / memory-constrained. If so, favor compact learners (linear, single tree, small SVM) and check `ModelSizeMetric` (general) or `ModelSizeCoderMetric` (Coder-specific).
   - *Ask the user:* "Will this model need to run on a small device, embedded system, or in a memory-limited environment? If so, we'll favor smaller/simpler models."
6. **Interpretability need.**
   - *Agent needs to know:* whether interpretable model families (trees, linear, discriminant) should be prioritized, and whether to plan interpretability plots (Permutation Importance, PDP, LIME, Shapley) after training.
   - *Ask the user:* "Will you need to explain the model's decisions to anyone — regulators, auditors, or non-technical stakeholders — or is raw accuracy the only priority?"

Use the answers to configure the session appropriately from the start — choosing the right predictors, validation scheme, model types, and export path without wasted training cycles.

## Best Practices

### Data & Setup

- **Test data splitting:** Before opening the app, ask the user whether they want to hold out a portion of the data as an independent test set. If they have a separate test dataset already available in the workspace, use that. If not, offer to split the data using `TestDataFraction` (e.g., 0.2–0.25) when opening the app, or let the user import test data later. This ensures an unbiased evaluation path is available after training. For `openApp` syntax and partitioning NV arguments, see [`references/api-session-and-models.md#opening-the-app`](references/api-session-and-models.md#opening-the-app).
- **Data inspection before training:** Before training models, inspect the data for potential issues. Check for: (1) missing values — models handle these differently, and some fail on NaN; (2) class distribution (classification) — use `tabulate` or `groupcounts` to detect imbalance; (3) response distribution (regression) — check for skewness or outliers in the response variable that may warrant transformation; (4) outliers in numeric predictors that could skew model performance; (5) constant or near-constant predictors that add no information. Report findings to the user and suggest preprocessing or model choices accordingly.
- **⚠ Preprocessing and data leakage:** Any preprocessing that uses **aggregate statistics from the dataset** — mean/median imputation, IQR- or z-score-based outlier removal, standardization/normalization, target encoding, etc. — leaks information from validation/test folds into training when done before importing into the app, and produces over-optimistic metrics. **The app does not perform these operations inside its CV/holdout folds** (only feature-selection ranking, PCA, and misclassification cost matrices are applied per-fold). For practical guidance on how to handle this, see [`references/skill-guidance-details.md#preprocessing-and-data-leakage`](references/skill-guidance-details.md#preprocessing-and-data-leakage).
- **Class imbalance handling:** If the dataset has imbalanced classes (e.g., 90%/10% split), suggest: (1) `ClassificationRUSBoostedEnsemble` (RUSBoost) which is specifically designed for imbalanced data by undersampling the majority class during boosting, (2) adjusting the cost matrix via `app.setModelCostMatrix()` to penalize misclassification of the minority class more heavily, (3) using Macro F1 or per-class metrics instead of overall accuracy to evaluate model quality — accuracy can be misleading with imbalanced data. Ask the user which class is more important to get right.

### Feature Engineering

- **Feature selection and ranking:** Suggest when: (1) dataset has many predictors (>20) and training is slow or models overfit, (2) user wants a simpler/more interpretable model, (3) model size must be minimized for deployment, (4) some predictors are known to be irrelevant/redundant. APIs: `app.setDefaultFeatureSelectionOptions(...)` for all draft models, or `app.setModelFeatureSelectionOptions(...)` for a specific one. **For which ranking method to pick per problem type and goal**, see [`references/skill-guidance-details.md#feature-selection`](references/skill-guidance-details.md#feature-selection).
- **PCA:** Suggest PCA when: (1) predictors are highly correlated (multicollinearity), (2) the dataset has many numeric predictors and dimensionality reduction could improve training speed without losing much information, (3) the user wants to reduce model complexity. Do NOT suggest PCA when interpretability is critical (PCA components lose predictor meaning). Note: PCA applies only to numeric predictors — categorical predictors are preserved unchanged and concatenated back after transformation, so mixed datasets are supported. Use `app.setDefaultPCAOptions('OnOff', true, 'PercentVarianceExplained', 95)` to set for all draft models, or `app.setModelPCAOptions('OnOff', true, 'PercentVarianceExplained', 95)` to target the current/specific model.

### Model Training & Selection

- **Comparing models:** After training multiple models, open the Results Table (`app.clickResultsTableToolstripButton()`) and Compare Results plot (`app.openCompareResultsPlot()`) to help the user compare models side-by-side. The Results Table shows all validation (and test) metrics in a sortable table. The Compare Results plot visualizes models either as a bar plot for a single metric or on two axes (e.g., accuracy vs prediction speed, or accuracy vs model size) for quick trade-off analysis. Use `app.getResultsTableData()` and `app.getCompareResultsPlotData()` to read the data programmatically. Suggest these views before the user picks the best model, so the decision is informed by multiple metrics — not just accuracy. For compare-results plot configuration, see [`references/api-plots.md#compare-results-plot-configuration-r2024b`](references/api-plots.md#compare-results-plot-configuration-r2024b).
- **Importing externally trained models:** Ask the user if they have pre-trained models in the workspace to include in the comparison. Supports workspace models (R2026a+). For compatibility requirements, validation limitations, and import details, see [`references/skill-guidance-details.md#importing-models`](references/skill-guidance-details.md#importing-models).
- **Hyperparameter optimization:** Suggest *after* initial model comparison when default presets are unsatisfactory and user has time budget. Optimization requires an `Optimizable*` preset (e.g., `ClassificationOptimizableTree`) — duplicating a regular model does not make it optimizable. Default: `'bayesopt'` with 30 iterations. Use `'grid'` only for exhaustive search over a small space; `'random'` for quick exploration of very large spaces. For time-constrained users, set `'HasTrainingTimeLimit', true, 'MaximumTrainingTimeInSeconds', N`. See [`references/skill-guidance-details.md#hyperparameter-optimization`](references/skill-guidance-details.md#hyperparameter-optimization) for additional detail.
- **Parallel and background training:** Suggest enabling parallel computing (`app.toggleUseParallelButton()`) when: (1) the dataset is large (>10K observations or >50 predictors), (2) training multiple models or running optimization with many iterations, (3) cross-validation with many folds. Suggest background training (`app.toggleUseBackgroundTrainingCheckbox()`) or parallel ON when the user wants to continue working in MATLAB while models train (check box is only available when user does not have Parallel Computing Toolbox). Note: parallel requires Parallel Computing Toolbox.
- **Model iteration workflow:** When a model type shows promise but needs improvement, prefer manual tuning (duplicate → adjust → compare) before jumping to optimization. For the workflow steps, constraints (Draft status requirement, All-preset limitations), and tips, see [`references/skill-guidance-details.md#model-iteration`](references/skill-guidance-details.md#model-iteration).

### Evaluation & Interpretability

- **Test before export:** After identifying the best model by validation metrics, always ask the user if they have an independent test dataset available. Testing on held-out data reveals generalization accuracy on unseen data, which is more reliable than cross-validation accuracy alone. Use `app.importTestData()` to load test data, then `app.clickTestSelectedModelToolstripButton()` to evaluate. Report test metrics via `app.getCurrentModelTestDataMetrics()` so the user can make an informed decision before exporting.
- **Test only the best model:** Do not test multiple models on the test dataset. The test set should only be used once on the final selected model to get an unbiased estimate of generalization performance. Testing many models on the same test set and then choosing the best one undermines the purpose — it leaks test information into model selection and leads to overly optimistic accuracy. If test results are unsatisfactory, suggest the user improve the model using validation techniques (e.g., feature engineering, hyperparameter tuning, trying different model types) rather than re-testing multiple models on the test set.
- **Interpretability plots:** After the best model is identified and tested, suggest interpretability plots when the user needs to explain predictions to stakeholders, is deploying in a regulated domain (healthcare, finance), sees unexpectedly high/low test accuracy, or wants to identify predictor drivers. Available: Permutation Importance (global, fast), Partial Dependence (per-predictor effects), LIME (local, per-observation), Shapley (both global and local). **⚠ Shapley can be slow on large datasets or complex models — always warn the user before triggering it.** For per-plot decision aid, Shapley cost-control levers, and choosing between Permutation Importance vs Shapley, see [`references/skill-guidance-details.md#interpretability-plots`](references/skill-guidance-details.md#interpretability-plots). For Shapley/LIME configuration API and plot data fields, see [`references/api-explainability.md`](references/api-explainability.md).
- **Plots for model analysis:** Suggest plots based on the workflow stage — after training (classification/regression), when comparing models, for optimizable models, for neural networks / DL, after testing on held-out data, or for data exploration. For the full stage-by-stage mapping of which plot to open for each purpose (with API method names), see [`references/skill-guidance-details.md#plots-for-model-analysis`](references/skill-guidance-details.md#plots-for-model-analysis).

### Session & Code Export

- **Session save/load (R2022a+):** Suggest saving sessions when training took a long time, user wants to continue later, or share results. Always suggest saving before closing after significant work. For save/load APIs and the blocking-dialog workaround, see [`references/skill-guidance-details.md#session-management`](references/skill-guidance-details.md#session-management).
- **Exporting the training workflow as code:** `app.clickGenerateCodeToolstripButton()` turns the app workflow into a script — useful when the user wants to work outside the app, integrate the model into a larger MATLAB workflow, version-control the training code, or automate/schedule the workflow. Use the `app.generateCode()` variant when the code is needed as a string. Produces a `.m` training function covering data preprocessing (feature selection, PCA), model training, and validation. Works for all model types. Note: re-running the generated script may not exactly reproduce the app's results due to randomization in `cvpartition`.
- **Exporting results programmatically:** Use `app.exportPlotData('VariableName', 'myPlot')` to export the current active plot's data to the workspace for further analysis. Use `app.exportPlotToFigure()` to export the active plot to a standalone MATLAB figure (for saving as an image or customizing). Use `app.exportResultsTableToWorkspace('VariableName', 'myResults')` or `app.exportResultsTableToFile('results.csv')` to export the Results Table (visible rows and columns only) to the workspace or a CSV file. These are useful when the user wants to share results, create custom visualizations, or integrate findings into reports. For full export method signatures and parameters, see [`references/api-export-and-diagnostics.md#programmatic-export-methods`](references/api-export-and-diagnostics.md#programmatic-export-methods).

### Deployment Export

- **Export to workspace:** Use `app.exportModelToWorkspace('MyModel')` (optionally `'IncludeTrainingData', false` for a compact export). **What gets exported (all paths):** a full model trained on the entire training set (not a CV-fold model), so the exported artifact is always a fresh fit on all available training data.
- **Export to Simulink (R2024a+):** For model-based design / controller-in-the-loop. Use `app.exportModelToSimulink(...)`. Categorical predictors are NOT supported — warn early. For full constraint list and supported model types, see [`references/skill-guidance-details.md#export-to-simulink-r2024a`](references/skill-guidance-details.md#export-to-simulink-r2024a). For `exportModelToSimulink` parameter table, see [`references/api-export-and-diagnostics.md#export-model-to-simulink-r2024a`](references/api-export-and-diagnostics.md#export-model-to-simulink-r2024a).
- **Export to Coder (R2025a+):** For C/C++ code generation / embedded targets. Use `app.exportModelToCoder(...)`. For constraint list and sizing guidance, see [`references/skill-guidance-details.md#export-to-coder-r2025a`](references/skill-guidance-details.md#export-to-coder-r2025a). For `exportModelToCoder` parameter table, see [`references/api-export-and-diagnostics.md#export-model-to-coder-r2025a`](references/api-export-and-diagnostics.md#export-model-to-coder-r2025a).
- **Export to Experiment Manager (R2022a+):** Suggest when the user needs finer control over hyperparameter tuning (editable search ranges, custom constraints). Use `app.createExperiment(...)`. Model must be trained first. For decision logic (when to use vs. app-level optimization, when to skip the Learner app), see [`references/skill-guidance-details.md#export-to-experiment-manager-r2022a`](references/skill-guidance-details.md#export-to-experiment-manager-r2022a).
- **Export to Production Server:** For REST API / web service deployment. Use `app.clickExportModelToProductionServerToolstripButton()`. Requires MATLAB Compiler SDK. See [`references/skill-guidance-details.md#export-to-production-server`](references/skill-guidance-details.md#export-to-production-server).

## Minimum Release Requirements

Features have minimum MATLAB release constraints. Calling a feature on an older release will error.

| Feature | Minimum Release |
|---------|----------------|
| Set optimizer options | R2019b |
| Set cost matrix | R2019b |
| Export to Production Server, Optimizable Neural Network models, Classification Kernel models | R2021b |
| Save/load session to file, Feature ranking, Regression Kernel models | R2022a |
| Results table, Partial dependence plot | R2022b |
| Create experiment (Experiment Manager), Save compact session to file, Efficient Linear classification models (LogisticRegression, LinearSVM, All) | R2023a |
| Local Shapley, LIME, Efficient Linear regression models (LS, SVM, All), Optimizable Efficient Linear, Optimizable Kernel | R2023b |
| Export model to Simulink, Simulink multi-train presets (AllSimulink), Neural Network models (Uni/Bi/Tri-Layered, All) | R2024a |
| Shapley importance/summary/dependence plots, Compare results plot, Precision-Recall plot, Export plot data, Additional metrics (Precision, Recall, F1-Score) | R2024b |
| Export model to Coder, Codegen multi-train presets (AllCodegen), Permutation importance plot, Compare ROC Curves plot | R2025a |
| Import trained model from workspace | R2026a |
| Deep Learning models (FullyConnected, Residual, All), Training progress plot, Network analyzer plot, Export partitions and data sets | R2026a |

## Quick Reference — Common Workflow

```matlab
% 1. Open app with data
% Classification:
app = mlearnapp.internal.appcontroller.AppController.openApp('classification', Tbl, 'Response', 'KFold', 5);
% Regression:
%   app = mlearnapp.internal.appcontroller.AppController.openApp('regression', Tbl, 'Price', 'KFold', 5);

% 2. Discover available model types and create models
% IMPORTANT: Always call getAvailableModelTypes to discover exact enum names.
% Do NOT guess enum names — they vary by category and release.
% Example: Naive Bayes is 'ClassificationGaussianNaiveBayes', not 'ClassificationNaiveBayes'
available = app.getAvailableModelTypes();              % all valid for this release
% 'Category' is a case-insensitive substring filter on the enum name
% (e.g., 'Tree', 'SVM', 'Ensemble', 'KNN', 'NeuralNetwork', 'Linear', 'Kernel', 'AllSimulink', ...).
% Call getAvailableModelTypes() with no filter first if unsure which substring will match.
treeModels = app.getAvailableModelTypes('Category', 'Tree');
% For guidance on picking an All-* preset family (AllQuickToTrain vs full All vs
% family-specific like AllTrees, AllSVM, AllEnsemble, AllLinear, AllKernel, etc.),
% see references/skill-guidance-details.md#multi-train-presets-all----which-to-pick
% For model type enum names, see references/api-session-and-models.md#gallerymodels-enum-reference
app.createModelType('ClassificationAllQuickToTrain');

% 2b. (Optional) Set hyperparameters on a DRAFT model BEFORE training
% Signature: app.setModelHyperparameterOptions(modelNumber, 'Param', value, ...)
% The first argument MUST be the model number string (e.g., '2', '3.1')
app.setModelHyperparameterOptions('2', 'BoxConstraint', 10, 'KernelScale', 2);

% 3. Train and wait
app.clickTrainToolstripButton();
app.waitForTrainingToComplete();

% 4. Compare models
app.clickResultsTableToolstripButton();
app.openCompareResultsPlot();
allMetrics = app.getAllModelMetrics();

% 5. Select best model (use model number from allMetrics)
% Classification: use AccuracyMetric (or MacroF1ScoreMetric for imbalanced data)
[~, bestIdx] = max([allMetrics.AccuracyMetric]);
% Regression: use RMSEMetric (lower is better) or RSquaredMetric (higher is better)
%   [~, bestIdx] = min([allMetrics.RMSEMetric]);
app.selectModelByNumber(allMetrics(bestIdx).ModelNumber);

% 6. Test on held-out data
app.importTestData('testTable');
app.clickTestSelectedModelToolstripButton();
testMetrics = app.getCurrentModelTestDataMetrics();

% 7. Export
app.exportModelToSimulink('MyModel.slx');

% 8. Close app (use 'Force', true ONLY for automated testing — never without user permission)
app.closeApp('Force', true);
```

----

Copyright 2026 The MathWorks, Inc.

----
