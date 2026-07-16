# Skill Guidance — Expanded Details

This file expands on the *guidance* bullets in `SKILL.md`. `SKILL.md` keeps the "when to suggest" summary; this file holds the decision aids, warnings, and per-option details that don't need to be in the agent's primary context all the time.

For API signatures and parameters, see the split API reference files: [`api-session-and-models.md`](api-session-and-models.md), [`api-metrics-and-options.md`](api-metrics-and-options.md), [`api-plots.md`](api-plots.md), [`api-explainability.md`](api-explainability.md), [`api-export-and-diagnostics.md`](api-export-and-diagnostics.md). This file is complementary — it answers "which option should I pick?", not "what's the syntax?".

**How to use the decision tables in this file:** These tables are for the *agent's* internal decision-making. The agent should:
1. Read the user's stated intent (or infer it from the workflow context).
2. Pick a row from the relevant table internally.
3. Report the choice to the user in **one short sentence, in plain terms** — do **not** paste the table.

## Feature Selection

**When to suggest** (summary from SKILL.md): dataset has many predictors (>20), training is slow, models overfit, interpretability matters, model size must be minimized, or the user knows some predictors are irrelevant/redundant.

**How the agent should use this section:**
1. **Infer intent from the user's request.** Map the user's stated preference (or the workflow's implicit need) to a row in the method table:
   - "Predictors are correlated" / "avoid redundant features" → **MRMR** (classification or regression variant)
   - "I want a nonparametric ranking" / "ANOVA assumptions look shaky" → **KruskalWallis** (classification only, rank-based) or **Chi2** (classification only, bins data)
   - "Simple statistical test per predictor" → **ANOVA** (classification, parametric) or **Chi2** (classification, non-parametric) or **FTest** (regression)
   - "Some features may only matter in combination" / "distance-based model coming next" → **ReliefF / RReliefF**
2. **Check applicability constraints before picking ReliefF.** If the user (or your inference) points to ReliefF but predictors are mixed (some categorical, some numeric), fall back to **MRMR** — it also handles nonlinear structure and is the closest agent-safe substitute. Do not attempt to enable a disabled ranking method.
3. **Default choice when the user has no preference:** **MRMR** (`ClassificationMRMR` or `RegressionMRMR`). It handles correlated predictors well, has no predictor-type constraint, and is a robust general-purpose ranking.
4. **Where to configure it in the workflow:**
   - For all draft models in the session, call `app.setDefaultFeatureSelectionOptions(...)` **before creating draft models** with `app.createModelType(...)`. Include `'IsFeatureSelectionAutomatic', true` and `'NumFeaturesToKeep', N` to auto-apply the top-N.
   - To override for a specific draft model only, call `app.setModelFeatureSelectionOptions(...)` **after** creating that draft (target it by model number).
5. **Do not hide this from the user.** The Learner app applies the ranking independently inside each CV fold, so results reflect that pipeline. If the user later inspects generated code, the ranking step will be visible — pick the method consistent with what you'd tell the user aloud.

**Which ranking method to pick:**

*Classification Learner exposes: `ANOVA`, `Chi2`, `KruskalWallis`, `ClassificationMRMR`, `ClassificationReliefF`.*
*Regression Learner exposes: `FTest`, `RegressionMRMR`, `RegressionReliefF`.*

| Problem type | Goal | Recommended method |
|---|---|---|
| Classification | Marginal per-predictor association, parametric (assumes roughly normal within-class distributions) | ANOVA |
| Classification | Marginal per-predictor association, non-parametric (bins continuous predictors, tests independence via contingency table — works with any predictor distribution) | Chi2 |
| Classification | Marginal per-predictor association, non-parametric rank-based (safer when ANOVA's distributional assumptions are shaky — small classes, non-normal residuals, ordinal-like responses) | KruskalWallis |
| Classification | Non-redundant / de-duplicated ranking (predictors may be correlated) | ClassificationMRMR |
| Classification | Detect features whose relevance only shows up in combination with others (conditional/contextual relevance) | ClassificationReliefF |
| Regression | Marginal linear association per predictor | FTest |
| Regression | Non-redundant / de-duplicated ranking (predictors may be correlated) | RegressionMRMR |
| Regression | Detect features whose relevance only shows up in combination with others (conditional/contextual relevance) | RegressionReliefF |

**Applicability constraints:**
- **ReliefF / RReliefF requires uniform predictor types.** The app disables the toggle when predictor types are mixed (some categorical, some numeric). It is enabled only when *all predictors are categorical* or *all predictors are numeric* (with more than one observation free of missing values in the numeric case). This mirrors the underlying `relieff` function requirement.
- **Regression Learner has no non-linear univariate ranking method.** `FTest` is the sole "marginal-per-predictor" option and captures linear relationships only. There is no regression counterpart to Chi2 / Kruskal-Wallis in the app; for nonlinear per-predictor relevance, `RegressionReliefF` (with the uniform-type constraint above) or `RegressionMRMR` are the alternatives.

**APIs (all draft models):** `app.setDefaultFeatureSelectionOptions('IsFeatureSelectionAutomatic', true, 'SelectedFeatureRankingMethod', ...)`
**APIs (current/specific model):** `app.setModelFeatureSelectionOptions(...)`

**Validation:** After training, compare validation metrics with and without feature selection to confirm no significant metric loss.

## Preprocessing and Data Leakage

**Context:** The Learner app does not perform statistics-based preprocessing (imputation, normalization, outlier removal) inside its CV/holdout folds — only feature-selection ranking, PCA, and misclassification cost matrices are applied per-fold. If the user has already applied statistics-based preprocessing before importing data, the reported metrics may be over-optimistic.

**Practical guidance:**

1. **Prefer observation-independent preprocessing before import.** Unit conversion, physically-motivated log-transform, dropping columns known a priori to be irrelevant, one-hot encoding a fixed categorical set — none of these use dataset-wide statistics, so they are safe to apply before importing.

2. **If statistics-based cleaning is unavoidable (and no custom partition is used):** Warn the user that reported validation/test metrics will be optimistic and that a truly held-out test set (reserved via `TestDataFraction` and never touched during cleaning) is the only reliable accuracy check.

3. **Custom partition approach (R2026a+):** The leak-safe workflow when statistics-based preprocessing is needed:
   - Partition the data at the command line using `cvpartition`.
   - Compute preprocessing statistics (mean, std, IQR, etc.) using **only the training fold observations**.
   - Apply the resulting transform to all data.
   - Pass the custom `cvpartition` object to `openApp` via the `'ValidationPartition'` parameter (or `'TestPartition'` for test splits).
   - This preserves fold boundaries and avoids leakage while still allowing statistics-based cleaning.

## Hyperparameter Optimization

**When to suggest** (summary from SKILL.md): default preset performance is unsatisfactory and the user has training-time budget for a longer run. Suggest *after* initial model comparison, not as the first step — the user needs a baseline to beat.

**Optimizer choice:**
- **`'bayesopt'`** (smart search) — default recommendation. Start with 30 iterations for most cases.
- **`'grid'`** — only when the user wants exhaustive search over a small parameter space.
- **`'random'`** — quick exploration when the search space is very large and bayesopt overhead isn't justified.

**Time-limit escape hatch:** For time-constrained users, set:
```matlab
app.setModelHyperparameterOptions(modelNum, ...
    'HasTrainingTimeLimit', true, ...
    'MaximumTrainingTimeInSeconds', N);
```

## Interpretability Plots

**When to suggest** (summary from SKILL.md): explain predictions to stakeholders, deploy in regulated domain (healthcare, finance), diagnose unexpectedly high/low accuracy, identify predictor drivers.

**Which plot for which purpose:**

| Question the user is asking | Plot to suggest |
|---|---|
| Which predictors matter overall? | Permutation Importance (fast) |
| How does one predictor affect the prediction, holding others fixed? | Partial Dependence |
| Why did the model predict *this* value for *this* observation? | LIME (local) |
| Both global and local explanations, principled game-theoretic attribution | Shapley |

**Warning — Shapley cost:** Shapley computation can be very time-consuming for large datasets or complex models (ensembles, neural networks). Always warn the user before triggering computation. Levers to reduce cost via `app.setShapleyParameters()`:
- Reduce `NumQueryPoints` — fewer background samples.
- Reduce `NumObservationSamples` — fewer instances used to build the estimator.

Both trade precision for speed. When time is very limited and the user only needs global feature ranking, prefer Permutation Importance instead of Shapley.

## Multi-Train Presets (All-*) — Which to Pick

`All*` presets create and train every model preset in a family at once, giving the user a broad baseline across that family without hand-picking individual presets. Pass them to `app.createModelType(...)` like any other preset.

**Cross-cutting presets (both classification and regression):**

| Preset | When to pick |
|---|---|
| `ClassificationAllQuickToTrain` / `RegressionAllQuickToTrain` | **Default first pass.** Trains only the fast-to-fit presets across all families. Best for large datasets, initial exploration, or when the user just wants a baseline before committing time. |
| `ClassificationAll` / `RegressionAll` | Full non-optimizable sweep across every family. Comprehensive but slower — use when the dataset is small enough or the user has time budget, and no family has been ruled out. |
| `ClassificationAllSimulink` / `RegressionAllSimulink` | Filter to only models the app can export to Simulink. Use when Simulink is the end goal — avoids training models that can't be deployed. |
| `ClassificationAllCodegen` / `RegressionAllCodegen` | Same idea for MATLAB Coder (R2025a+). |
| `ClassificationAllDLNetworks` / `RegressionAllDLNetworks` (R2026a+) | Only the Deep Learning family (FullyConnected, Residual, All). Requires Deep Learning Toolbox. Use when the user has explicitly asked for deep networks. |

**Family-specific presets — pick when the user has a domain reason to prefer a family:**

| Preset (classification / regression) | When to pick |
|---|---|
| `ClassificationAllTrees` / `RegressionAllTrees` | Interpretability is important; user wants to visualize decisions; predictors may include categoricals; deployment target favors small memory footprint. |
| `ClassificationAllSVM` / `RegressionAllSVM` | High-dimensional data with a clear margin; smaller-to-medium datasets; user wants a max-margin model. Not great for very large N. |
| `ClassificationAllKNN` (classification only) | Small datasets with well-separated classes; simple non-parametric baseline; the user wants an explainable nearest-neighbor approach. |
| `ClassificationAllEnsemble` / `RegressionAllEnsemble` | Predictive accuracy matters more than interpretability; user has time for slower training; robust to noisy or heterogeneous features. |
| `ClassificationAllNeuralNetwork` / `RegressionAllNeuralNetwork` (R2024a+) | Nonlinear tabular relationships; medium-to-large datasets. **Ships with Statistics and ML Toolbox — no Deep Learning Toolbox required.** |
| `ClassificationAllKernel` / `RegressionAllKernel` (R2023b+) | Large datasets where full SVM is too slow — kernel approximation for scale. |
| `ClassificationAllLinear` (classification only) | Logistic-regression-based linear models. Interpretable, cheap, good baseline. |
| `ClassificationAllClassificationLinear` (classification only, R2023a+) | SVM-based linear models. Similar use case but different underlying optimizer / model family than `AllLinear`. |
| `ClassificationAllLogisticRegression` (classification only, R2024a+) | Logistic-regression variants specifically (not the broader linear family). |
| `ClassificationAllDiscriminant` (classification only) | Linear or quadratic discriminant analysis — small data, roughly Gaussian class distributions. |
| `ClassificationAllNaiveBayes` (classification only) | Text-like or high-dimensional sparse data; a fast probabilistic baseline. |
| `RegressionAllLinear` (regression only) | Baseline linear regression family (linear, robust, stepwise). Highly interpretable. |
| `RegressionAllGPR` (regression only) | Small-to-medium datasets where uncertainty estimates matter; smooth nonlinear regression. Slow on large N. |

**Recommendations for the agent:**
- Default first suggestion: `*AllQuickToTrain`. It's fast enough to run without asking, and its results inform the next choice.
- After the first pass, suggest a family-specific `All*` preset only when the user has stated a preference the results don't yet satisfy (e.g., "these trees look good but I want more interpretability" → `AllLinear`; "accuracy still isn't enough" → `AllEnsemble`).
- If Simulink or Coder is the deployment target, prefer `AllSimulink` / `AllCodegen` over broader presets so no training time is spent on unsupported models.
- **Availability varies by release.** Always call `app.getAvailableModelTypes()` (unfiltered) before assuming a preset exists — e.g., `AllDLNetworks` is R2026a+, `AllClassificationLinear` is R2023a+.

## Deployment Constraints

**When to consult:** Only when the user's export target is Simulink, Coder, Experiment Manager, or Production Server. Not needed for workspace export or code generation.

### Export to Simulink (R2024a+)

- Requires Simulink toolbox.
- **Categorical predictors are NOT supported.** Simulink Predict blocks cannot accept categorical inputs. Warn the user early — before opening the app — and either use only numeric predictors or encode categoricals as numeric before loading data.
- Unsupported model types: linear/stepwise linear regression, ensembles with non-tree learners (discriminant/KNN-learner ensembles), tree models with surrogate splits enabled (`SurrogateUse` ≠ `'Off'`), binary GLM logistic regression, custom models.
- Use `ClassificationAllSimulink` / `RegressionAllSimulink` presets to avoid training unsupported models.
- Cost of a bad export choice: iterating on a Simulink diagram after finding a model problem is much more expensive than switching models in the app.

### Export to Coder (R2025a+)

- Requires MATLAB Coder toolbox.
- Unsupported: multiclass kernel classifiers, ECOC with kernel learners, tree models with surrogate splits, binary GLM logistic regression, custom models.
- Use `ClassificationAllCodegen` / `RegressionAllCodegen` presets.
- For sizing/latency-constrained targets, check `ModelSizeCoderMetric` (codegen-specific, differs from `ModelSizeMetric`) and `PredictionSpeed`; favor compact learners (linear, single tree, small SVM) over large ensembles.
- Other types may fail at export time (surfaced as a dialog error).

### Export to Experiment Manager (R2022a+)

- Part of MATLAB — no extra toolbox required.
- Which API to call: Default to `app.createExperiment(...)` for agent-driven workflows. Only use `app.clickCreateExperimentToolstripButton()` when the user explicitly asks to click the toolstrip button.
- Model must be trained before calling `createExperiment`.
- **Why Experiment Manager vs. app-level optimization:** The Learner app's `Optimizable*` presets let the user pick the optimizer and toggle which hyperparameters to include, but **search ranges are fixed**. Experiment Manager exposes ranges for editing, plus custom training/evaluation logic, constraints, parallelizable/resumable/versioned experiments.
- `setModelHyperparameterOptions` in the Learner app is unrelated — it sets fixed values for draft (non-optimizable) models, not tunable ranges.
- **When to skip the Learner app entirely:** May be simpler when (a) user's only goal is tuning and the model type has no known constraint functions, (b) they need a custom training function, (c) they want a non-app model type, or (d) they need unusual hyperparameters.
- **Why routing through the Learner app is usually better:** It pre-generates a working training function, default search ranges, and critically the `ConditionalConstraints` and `DeterministicConstraints` functions that encode valid hyperparameter combinations. These are poorly documented and very hard to author correctly from scratch.

### Export to Production Server

- Requires MATLAB Compiler SDK.
- Use when: model serves predictions via REST API, deployment target is a server, multiple clients query remotely.

## Importing Models

### Externally Trained Models (R2026a+)

- Use `app.importModel('varName')` or `app.importModel('varName', 'ModelName', 'Custom Name')`.
- Imported models appear in Results Table and Compare Results plot alongside app-trained ones.
- **Important:** Imported models do NOT have validation metrics — only test metrics are available after testing on held-out or imported test data.
- To compare imported vs app-trained models, reserve test data (via `TestDataFraction`) or import test data, then test both.
- The model must be trained on a similar dataset (same predictor names and response class names).

## Session Management

### Save/Load (R2022a+)

**When to suggest saving:** (1) training took a long time and losing progress would be costly, (2) user wants to continue later, (3) comparing across sessions or sharing with colleagues.

- `app.saveSessionToFile()` — full session.
- `app.saveCompactSessionToFile()` — smaller file, no training data.
- To reload: open the app without data first, then call `app.openSessionFromFile('path.mat')`.

### Blocking Save-Confirmation Dialog

Both `openApp` with a session file path and `openSessionFromFile` trigger a **blocking save-confirmation dialog** if the current session has unsaved changes. The dialog is NOT triggered if the session is already saved or no session has been started.

**Avoid the block by:**
- (a) Opening the app without data before loading a session file.
- (b) Saving the current session first.
- (c) Force-closing the app (`closeApp('Force', true)`) only with user permission or in automated testing.

## Model Iteration

**Workflow:** duplicate → adjust → compare.

1. `app.duplicateModelByNumber('3.1')` to preserve the original while creating a draft copy.
2. `app.setModelHyperparameterOptions(...)` to adjust hyperparameters.
3. Try feature selection variations.
4. Compare original and tuned versions side-by-side.

**Constraints:**
- The app does NOT allow retraining already trained models (includes Trained, Failed, or Canceled/Interrupted status).
- To retrain with new settings, either duplicate the model (creates a draft copy) or create a new model from scratch.
- `setModelHyperparameterOptions` only works on models in **Draft** status.
- Cannot be used on multi-model "All" presets (e.g., `ClassificationAllTrees`); target individual model presets instead.

**Tips:**
- `app.toggleModelFavorite('3.1')` to mark promising models.
- `app.sortModelList('Accuracy', 'descend')` (classification) or `app.sortModelList('RMSE', 'ascend')` (regression) to surface best performers.
- Prefer manual tuning before jumping to optimization — it builds understanding of what drives performance.

## Plots for Model Analysis

**When to suggest** (summary from SKILL.md): after key workflow milestones (training, comparing, testing) to help the user understand results. Pick by workflow stage:

### After training (classification)
- **Confusion Matrix** — `app.openValidationConfusionMatrixPlot()`: per-class accuracy and misclassification patterns.
- **ROC Curve** — `app.openValidationROCCurvePlot()`: discrimination ability across thresholds.
- **Precision-Recall Curve (R2024b+)** — `app.openPrecisionRecallPlot()`: performance on imbalanced datasets where precision/recall trade-offs matter more than ROC.
- **Scatter Plot** — `app.openScatterPlot()`: decision boundaries and predictions vs. true labels.

### After training (regression)
- **Predicted vs Actual** — `app.openValidationPredictedVsActualPlot()`: prediction quality visually.
- **Residuals** — `app.openValidationResidualsPlot()`: systematic errors, heteroscedasticity, missed patterns.
- **Response Plot** — `app.openResponsePlot()`: overall fit visualization.

### When comparing multiple models
- **Compare Results** — `app.openCompareResultsPlot()`: multi-metric trade-off visualization.
- **Compare ROC Curves** (classification) — `app.openCompareROCCurvesPlot()`: which model discriminates better per class.

### For optimizable models
- **Min Classification Error** — `app.openMinClassificationErrorPlot()` — monitor optimization convergence; check if more iterations are needed.
- **Min MSE** (regression) — `app.openMinMSEPlot()` — same idea for regression.

### For neural networks / deep learning
- **Training Progress** — `app.openTrainingProgressPlot()`: monitor loss, gradient, and step size during training — detect divergence or stalling early.

### After testing on held-out data
Mirror the validation plots but on test data to confirm generalization:
- **Test Confusion Matrix** — `app.openTestConfusionMatrixPlot()`
- **Test ROC Curve** — `app.openTestROCCurvePlot()`
- **Test Precision-Recall** — `app.openTestPrecisionRecallPlot()`
- **Test Predicted vs Actual** — `app.openTestPredictedVsActualPlot()`
- **Test Residuals** — `app.openTestResidualsPlot()`

### For data exploration (classification)
- **Parallel Coordinates** — `app.openParallelCoordinatesPlot()`: how classes separate across predictors — identifies discriminating features.

----

Copyright 2026 The MathWorks, Inc.

----
