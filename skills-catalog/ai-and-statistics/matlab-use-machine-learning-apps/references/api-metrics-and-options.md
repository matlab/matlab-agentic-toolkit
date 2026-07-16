# API Reference — Metrics & Model Options

Metrics retrieval, model specification queries, toolstrip buttons, and programmatic configuration methods (feature selection, PCA, optimizer, cost matrix, hyperparameters).

For session setup and model creation, see [`api-session-and-models.md`](api-session-and-models.md).
For plots, see [`api-plots.md`](api-plots.md).
For explainability plots (Shapley, LIME, PDP, permutation importance), see [`api-explainability.md`](api-explainability.md).
For export and diagnostics, see [`api-export-and-diagnostics.md`](api-export-and-diagnostics.md).

---

## Metrics

**Important:** `getAllModelMetrics()` and `getAllModelTestDataMetrics()` return a **struct array**, not a cell array. Use parentheses indexing `allMetrics(i).Field`, not brace indexing `allMetrics{i}.Field`.

```matlab
metrics = app.getCurrentModelMetrics();
metrics = app.getModelMetrics(modelIndex);
allMetrics = app.getAllModelMetrics();

metrics = app.getCurrentModelTestDataMetrics();
metrics = app.getModelTestDataMetrics(modelIndex);
allMetrics = app.getAllModelTestDataMetrics();
```

**Classification validation metric fields:** AccuracyMetric, ErrorRateMetric, MacroF1ScoreMetric, MacroPrecisionMetric, MacroRecallMetric, MicroF1ScoreMetric, MicroPrecisionMetric, MicroRecallMetric, ModelName, ModelNumber, ModelSizeCoderMetric, ModelSizeMetric, PerClassF1ScoreMetric, PerClassPrecisionMetric, PerClassRecallMetric, PredictionSpeedMetric, TotalCostMetric, TrainingTimeMetric, WeightedF1ScoreMetric, WeightedPrecisionMetric, WeightedRecallMetric

**Classification test metric fields:** AccuracyMetric, ErrorRateMetric, MacroF1ScoreMetric, MacroPrecisionMetric, MacroRecallMetric, MicroF1ScoreMetric, MicroPrecisionMetric, MicroRecallMetric, ModelName, ModelNumber, PerClassF1ScoreMetric, PerClassPrecisionMetric, PerClassRecallMetric, TotalCostMetric, WeightedF1ScoreMetric, WeightedPrecisionMetric, WeightedRecallMetric

**Regression validation metric fields:** MAEMetric, MAPEMetric, MSEMetric, ModelName, ModelNumber, ModelSizeCoderMetric, ModelSizeMetric, PredictionSpeedMetric, RMSEMetric, RSquaredMetric, TrainingTimeMetric

**Regression test metric fields:** MAEMetric, MAPEMetric, MSEMetric, ModelName, ModelNumber, RMSEMetric, RSquaredMetric

## Model Specifications

```matlab
spec = app.getModelFeatureSelectionOptions();          % current model
spec = app.getModelFeatureSelectionOptions('2');       % by model number
% Fields: FeatureInclusionVector, SelectedFeatureRankingMethod,
%   IsFeatureSelectionAutomatic, NumFeaturesToKeep, FeatureNames,
%   HasSpecChanged, IsDefaultSpecification, HasFeatureSelectionSupport, ModelNumber

spec = app.getModelPCAOptions();                      % current model
spec = app.getModelPCAOptions('3');                    % by model number
% Fields: OnOff, ComponentChoiceMethod, NumComponentsToKeep,
%   PercentVarianceExplained, IsDefaultSpecification, HasPCASupport, ModelNumber

spec = app.getModelCostOptions();                  % current model (Classification only)
spec = app.getModelCostOptions('2');               % by model number
% Fields: CostMatrix, ModelNumber

spec = app.getModelHyperparameterOptions();         % current model
spec = app.getModelHyperparameterOptions('2');      % by model number
% Fields vary by model type (e.g., PresetID, Learner, Solver, etc.), plus ModelNumber

spec = app.getModelOptimizerOptions();             % current model
spec = app.getModelOptimizerOptions('4');          % by model number
% Fields: Optimizer, AcquisitionFunction, Iterations, HasTrainingTimeLimit,
%   MaximumTrainingTimeInSeconds, NumGridDivisions, IsDefaultSpecification, ModelNumber
```

## Toolstrip Button Clicks

```matlab
% Specification dialogs — open interactive dialogs, use only to show the user the dialog UI
% For programmatic access, use setModel*() / setDefault*() methods instead (e.g., setModelFeatureSelectionOptions, setDefaultFeatureSelectionOptions, setModelPCAOptions, setDefaultPCAOptions, setModelOptimizerOptions, setDefaultOptimizerOptions, setModelCostMatrix, setDefaultCostMatrix)
app.clickFeatureSelectionToolstripButton();
app.clickPCAToolstripButton();
app.clickCostsToolstripButton();                % Classification only
app.clickOptimizerOptionsToolstripButton();

% Layout
app.clickLayoutToolstripButton();
app.clickCompareModelsLayoutToolstripButton();
app.clickResultsTableToolstripButton();
app.clickTestResultsTableToolstripButton();     % R2023b+

% Export
app.clickGenerateCodeToolstripButton();
app.clickExportPlotToolstripButton();
app.clickExportPlotDataToolstripButton();
app.clickExportModelToolstripButton();
app.clickExportModelToProductionServerToolstripButton();
app.clickExportModelToSimulinkToolstripButton();        % R2024a+
app.clickExportModelToCoderToolstripButton();           % R2025a+
app.clickCreateExperimentToolstripButton();             % R2022a+
app.clickExportPartitionsAndDataSetsToolstripButton();  % R2026a+

% Test data
app.clickImportTestDataFromWorkspaceToolstripButton();
app.clickImportTestDataFromFileToolstripButton();
app.clickTestSelectedModelToolstripButton();
app.clickTestAllModelsToolstripButton();

% Import models
app.clickImportModelFromWorkspaceToolstripButton();     % R2026a+

% Save session (R2022a+)
app.clickSaveSessionToolstripButton();
app.clickSaveSessionAsToolstripButton();
app.clickSaveAsCompactSessionToolstripButton();

```

## Programmatic Model Options Methods

All setter methods support an optional `ModelNumber` name-value argument:
- **Without `ModelNumber`**: updates the default session specification (propagates to all draft models)
- **With `ModelNumber`**: updates only that specific draft model's specification

### Set Feature Selection Options

```matlab
% Set on current model (or specific model by number)
app.setModelFeatureSelectionOptions('FeatureInclusionVector', [true true false false])
app.setModelFeatureSelectionOptions('FeatureInclusionVector', [true true false false], 'ModelNumber', '2')

% Set default (propagates to all draft models)
app.setDefaultFeatureSelectionOptions('IncludedPredictorNames', {'Sepal_Length', 'Petal_Width'})
app.setDefaultFeatureSelectionOptions('IsFeatureSelectionAutomatic', true, 'SelectedFeatureRankingMethod', 'ANOVA', 'NumFeaturesToKeep', 2)
```

| Argument | Description |
|----------|-------------|
| `ModelNumber` | (string) Target a specific draft model |
| `FeatureInclusionVector` | Logical vector (length = num predictors) |
| `IncludedPredictorNames` | Cell/string array of predictor names (alternative to vector) |
| `IsFeatureSelectionAutomatic` | Enable ranking-based automatic selection |
| `SelectedFeatureRankingMethod` | Classification: `'ANOVA'`, `'Chi2'`, `'ClassificationMRMR'`, `'ClassificationReliefF'`, `'KruskalWallis'`; Regression: `'FTest'`, `'RegressionMRMR'`, `'RegressionReliefF'` |
| `NumFeaturesToKeep` | Number of top-ranked features (automatic mode) |

### Set PCA Options

```matlab
% Set on current model (or specific model by number)
app.setModelPCAOptions('OnOff', true, 'PercentVarianceExplained', 90)
app.setModelPCAOptions('OnOff', true, 'ModelNumber', '3')

% Set default (propagates to all draft models)
app.setDefaultPCAOptions('OnOff', true, 'PercentVarianceExplained', 95)
app.setDefaultPCAOptions('OnOff', false)
```

### Set Optimizer Options

```matlab
% Set on current model (or specific model by number)
app.setModelOptimizerOptions('Optimizer', 'bayesopt', 'Iterations', 50)
app.setModelOptimizerOptions('Iterations', 100, 'ModelNumber', '2')

% Set default (propagates to all draft models)
app.setDefaultOptimizerOptions('Optimizer', 'bayesopt', 'Iterations', 50)
app.setDefaultOptimizerOptions('HasTrainingTimeLimit', true, 'MaximumTrainingTimeInSeconds', 600)
```

### Set Cost Matrix (Classification only)

```matlab
% Set on current model (or specific model by number)
app.setModelCostMatrix([0 1 1; 2 0 1; 2 1 0])
app.setModelCostMatrix([0 1 1; 2 0 1; 2 1 0], 'ModelNumber', '2')

% Set default (propagates to all draft models)
app.setDefaultCostMatrix([0 1 1; 2 0 1; 2 1 0])
```

### Set Advanced Model Options (Hyperparameters)

```matlab
app.setModelHyperparameterOptions('2', 'MaxNumSplits', 100, 'SplitCriterion', 'GDI')
app.setModelHyperparameterOptions('3', 'KernelFunction', 'Gaussian', 'BoxConstraint', 10, 'KernelScaleMode', 'Manual', 'KernelScale', 2.5)
app.setModelHyperparameterOptions('4', 'NumNeighbors', 5, 'DistanceMetric', 'Cosine')
```

**Constraints:**
- Model must be in Draft status
- Cannot be used on multi-model ("All") presets
- Parameter names must match the model spec properties exactly

----

Copyright 2026 The MathWorks, Inc.

----
