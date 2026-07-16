# API Reference — Session & Models

Setup, lifecycle, model creation, training, selection, and status queries. Includes GalleryModels enum values for `createModelType`.

For metrics and configuration options, see [`api-metrics-and-options.md`](api-metrics-and-options.md).
For plots, see [`api-plots.md`](api-plots.md).
For explainability plots (Shapley, LIME, PDP, permutation importance), see [`api-explainability.md`](api-explainability.md).
For export and diagnostics, see [`api-export-and-diagnostics.md`](api-export-and-diagnostics.md).

---

## Opening the App

### Via AppController (programmatic testing)

```matlab
% Open with no data
app = mlearnapp.internal.appcontroller.AppController.openApp('classification');
app = mlearnapp.internal.appcontroller.AppController.openApp('regression');

% Open with a saved session file (.mat)
app = mlearnapp.internal.appcontroller.AppController.openApp('classification', 'mySession.mat');

% Table + response variable name
app = mlearnapp.internal.appcontroller.AppController.openApp('classification', Tbl, ResponseVarName);

% Table + separate response vector
app = mlearnapp.internal.appcontroller.AppController.openApp('regression', Tbl, Y);

% Predictor matrix + response vector
app = mlearnapp.internal.appcontroller.AppController.openApp('classification', X, Y);

% Any data syntax + Name-Value arguments for partitioning
app = mlearnapp.internal.appcontroller.AppController.openApp('classification', Tbl, 'Species', 'KFold', 10);
app = mlearnapp.internal.appcontroller.AppController.openApp('regression', X, Y, 'Holdout', 0.2, 'TestDataFraction', 0.25);
app = mlearnapp.internal.appcontroller.AppController.openApp('classification', Tbl, Y, 'ValidationPartition', cvp, 'TestPartition', testCvp);
```

### Getting a handle to an already-running app

If the app is already open, use the constructor to get a handle to the existing instance:

```matlab
app = mlearnapp.internal.appcontroller.AppController('classification');
app = mlearnapp.internal.appcontroller.AppController('regression');
```

Alternatively, calling `openApp` with just the problem type (no data arguments) also returns a handle without relaunching:

```matlab
app = mlearnapp.internal.appcontroller.AppController.openApp('classification');
app = mlearnapp.internal.appcontroller.AppController.openApp('regression');
```

**Internal note:** App handles are stored on `groot`: `getappdata(groot, 'ClassificationLearnerAppHandle')` / `'RegressionLearnerAppHandle'`.

### Via classificationLearner / regressionLearner commands (user-facing entry points)

```matlab
classificationLearner
classificationLearner(Tbl, ResponseVarName)
classificationLearner(Tbl, Y)
classificationLearner(X, Y)
classificationLearner(___, Name=Value)
classificationLearner(filename)

regressionLearner
regressionLearner(Tbl, ResponseVarName)
regressionLearner(Tbl, Y)
regressionLearner(X, Y)
regressionLearner(___, Name=Value)
regressionLearner(filename)
```

### Name-Value arguments (apply to AppController.openApp, classificationLearner, and regressionLearner)

| Argument | Type | Description |
|----------|------|-------------|
| `CrossVal` | `"on"` (default) or `"off"` | Cross-validation flag. `"on"` = 5-fold CV, `"off"` = resubstitution. |
| `KFold` | integer in [2, 50] | Number of folds for cross-validation. Overrides `CrossVal`. |
| `Holdout` | scalar in [0.05, 0.5] | Fraction of training data for holdout validation. Overrides `CrossVal`. |
| `ValidationPartition` | `cvpartition` object | Custom validation scheme. Cannot combine with `CrossVal`/`KFold`/`Holdout`. Can only combine with `TestPartition`. |
| `TestDataFraction` | scalar in [0.05, 0.5] | Fraction of data set aside for testing. Cannot combine with `TestPartition`. |
| `TestPartition` | `cvpartition` object (Type='holdout') | Custom test partition. Cannot combine with `TestDataFraction`. |

**Constraints:**
- Only one of `CrossVal`, `KFold`, `Holdout`, or `ValidationPartition` at a time.
- Only one of `TestDataFraction` or `TestPartition` at a time.
- Response variable Y: for classification, must have ≤ 500 unique class labels; for regression, must be a numeric vector.
- When using `ValidationPartition`, you cannot use `TestDataFraction` (random split). Use an explicit `TestPartition` object instead, or import test data in-app after session start.
- **Simulink export:** If the user intends to export the trained model to Simulink, check the training data for categorical predictors BEFORE opening the app. Models trained with categorical predictors cannot be exported to Simulink. Warn the user early and either use only numeric predictors or encode categoricals as numeric before loading data.

## Waiting for App Readiness

After opening the app with data, wait for the session to be fully ready before interacting:

```matlab
app.waitForAppSessionReady();      % Default 60s timeout
app.waitForAppSessionReady(120);   % Custom timeout in seconds
```

Uses `this.ProblemType` internally to determine which plot to wait for (Scatter for classification, ResponsePlot for regression). Called automatically by `openApp` when data is provided — only call manually if connecting to an existing app instance.

**Note:** When a session is started with data, the app automatically creates a single default Fine Tree model (ClassificationFineTree or RegressionFineTree). This model appears in the model list immediately and can be trained without calling `createModelType` first. When a session is started with a trained model (e.g., via `classificationLearner(trainedModel)` or `regressionLearner(trainedModel)`), the trained model is imported as the default model instead.

## Closing the App

**Important:** Do NOT call `closeApp('Force', true)` without explicit user permission. Use `'Force', true` for automated testing where no human is present to dismiss the confirmation dialog, or when the app is not responding as expected and needs to be force closed.

```matlab
app.closeApp();                    % Shows confirmation dialog — preferred for interactive use
app.closeApp('Force', true);       % No confirmation — for automated testing or unresponsive app
```

## Save and Load Sessions (R2022a+)

```matlab
app.saveSessionToFile('mySession.mat');
app.saveCompactSessionToFile('myCompactSession.mat');
app.openSessionFromFile('existingSession.mat');
```

## Resetting the Session

**Important:** Do NOT call `resetApp()` without explicit user permission. Resetting discards all trained models and results in the current session. Use only for automated testing where no human is present, or after the user has explicitly confirmed they want to start over.

```matlab
app.resetApp();
```

## New Session Dialog

**Important:** Do NOT use the `click*` methods below to start a new session programmatically. Use `openApp()` instead, which handles session creation directly. The `click*` methods open interactive dialogs and should only be used to demonstrate the dialog UI to the user when they ask about it.

```matlab
data = app.getNewSessionDialogData();
% Returns struct: DataSetVariableName, ResponseVariableName, ResponseVariableOrigin,
%   PredictorsTable, ValidationMethod ('CrossVal'/'HoldOut'/'Resubstitution'),
%   ValidationValue, TestDataValue

% These open interactive dialogs — use only to show the user the dialog, not to start sessions programmatically
app.clickNewSessionFromWorkspaceToolstripButton();
app.clickNewSessionFromFileToolstripButton();
app.clickNewSessionFromTrainedModelToolstripButton();
```

## Session Data

```matlab
data = app.getSessionData();
% Returns struct: TrainingDataSetVariableName, TrainingPredictorsTable,
%   TrainingResponseVariableName, TrainingResponseVector,
%   TestDataSetVariableName, TestPredictorsTable, TestResponseVector,
%   TestResponseVariableName, ResponseVariableOrigin,
%   ValidationMethod, ValidationValue

% Check if test data is loaded: TestPredictorsTable is empty when no test data
hasTestData = ~isempty(data.TestPredictorsTable);
```

## Import Test Data

```matlab
app.importTestData('testTable')
app.importTestData('testTable', 'Species')
```

## Import Model from Workspace (R2026a+)

```matlab
app.importModel('trainedTree')
app.importModel('myModel', 'ModelName', 'Custom SVM')
```

**Validation performed:** model type supported, problem type match, predictor names match session, categorical/numerical predictor types match, response classes match (classification). The model variable must be a classreg model object or app-exported struct.

## Querying Available Model Types

```matlab
% Get all model types available for the current session's problem type and MATLAB release
modelTypes = app.getAvailableModelTypes();

% Filter by category keyword
treeModels = app.getAvailableModelTypes('Category', 'Tree');
svmModels = app.getAvailableModelTypes('Category', 'SVM');
ensembleModels = app.getAvailableModelTypes('Category', 'Ensemble');
knnModels = app.getAvailableModelTypes('Category', 'KNN');
```

Returns a string array of valid `GalleryModels` enum values that can be passed to `createModelType`. Filters by the current session's problem type (classification or regression) and excludes models requiring a newer MATLAB release than the one running.

**Model type naming convention:** Each category contains three kinds of entries:
- **Individual presets** (e.g., `ClassificationFineTree`, `ClassificationMediumTree`, `ClassificationCoarseTree`) — train a single model with specific hyperparameters
- **"All" multi-train presets** (e.g., `ClassificationAllTrees`) — creates and trains all individual presets in that category at once (equivalent to selecting each one manually)
- **Optimizable variants** (e.g., `ClassificationOptimizableTree`) — trains a single model with Bayesian hyperparameter optimization

## Creating and Training Models

```matlab
app.createModelType('ClassificationFineTree');
app.createModelType('RegressionLinearSVM');

app.trainCurrentModel();                    % Trains selected model
app.clickTrainToolstripButton();            % Train all draft models
app.clickTrainSelectedToolstripButton();    % Train only selected model

app.cancelCurrentModelTraining();
app.cancelAllModelTraining();

app.waitForTrainingToComplete();            % Default 300s timeout
app.waitForTrainingToComplete(600);         % Custom timeout

% Wait for active plot to finish rendering (polls every 0.5s, default 30s timeout)
app.waitForPlotToPopulate();
app.waitForPlotToPopulate(10);              % Custom timeout

% Parallel / background training query and toggle
tf = app.isUseParallelEnabled();              % returns true if parallel training is on
tf = app.isUseBackgroundTrainingEnabled();    % returns true if background training is on
app.toggleUseParallelButton();                % requires Parallel Computing Toolbox
app.toggleUseBackgroundTrainingCheckbox();    % only available when Parallel Computing Toolbox is NOT installed
```

## Model Selection and Deletion

```matlab
app.selectModelByIndex(2);
app.selectModelByNumber('1.3');
app.deleteModelByNumber('1.3');
```

## Model Duplication, Favorites, and Sorting

```matlab
% Duplicate a model (creates a new draft with the same specs)
newModelNumber = app.duplicateModelByNumber('3.1');

% Toggle favorite status
app.toggleModelFavorite('3.1');
isFav = app.isModelFavorite('3.1');    % returns logical

% Sort the model list
app.sortModelList('Accuracy', 'descend');
app.sortModelList('ModelNumber', 'ascend');
app.sortModelList('Favorite', 'descend');

% Get available sort metric keys
metricKeys = app.getAvailableSortMetrics();
```

**Sort metric keys** (vary by problem type and release):
- Common: `'ModelNumber'`, `'Favorite'`
- Classification: `'Accuracy'`, `'TotalCost'`, `'MacroF1Score'`, etc.
- Regression: `'RMSE'`, `'RSquared'`, `'MSE'`, `'MAE'`, etc.

Use `app.getAvailableSortMetrics()` to discover available keys for the current session.

## Model Status

```matlab
status = app.getModelStatus(1);
status = app.getCurrentModelStatus();
number = app.getCurrentModelNumber();
name = app.getCurrentModelName();       % e.g., 'Fine Tree', 'Optimizable Tree'
name = app.getModelName(1);             % by index

app.isCurrentModelDraft()
app.isCurrentModelTrained()
app.isCurrentModelTested()
app.isCurrentModelFailed()
app.isCurrentModelCanceled()
app.isCurrentModelOptimized()

count = app.getNumberOfModels();
numbers = app.getAllModelNumbers();
statuses = app.getAllModelStatuses();

% Failure/warning messages
msg = app.getModelFailureMessage()          % current model
msg = app.getModelFailureMessage('3')       % by model number
% Returns struct: TrainingFailure (string), TestingFailure (string), Warnings (string array)
```

## GalleryModels Enum Reference

Use these string values with `app.createModelType(modelType)`.

The enum class is: `mlearnapp.internal.enums.GalleryModels`

### Classification Models

| Category | Model Types | Min Release |
|----------|------------|-------------|
| Quick/All | ClassificationAllQuickToTrain, ClassificationAll, ClassificationAllLinear | — |
| Simulink | ClassificationAllSimulink | R2024a |
| Codegen | ClassificationAllCodegen | R2025a |
| Trees | ClassificationFineTree, ClassificationMediumTree, ClassificationCoarseTree, ClassificationAllTrees, ClassificationOptimizableTree | — |
| Discriminant | ClassificationLinearDiscriminant, ClassificationQuadraticDiscriminant, ClassificationAllDiscriminant, ClassificationOptimizableDiscriminant | — |
| Logistic | ClassificationLogistic, ClassificationAllLogisticRegression | R2024a |
| Efficient Linear | ClassificationLinearLogisticRegression, ClassificationLinearLinearSVM, ClassificationAllClassificationLinear, ClassificationOptimizableClassificationLinear | R2023a |
| Naive Bayes | ClassificationGaussianNaiveBayes, ClassificationKernelNaiveBayes, ClassificationAllNaiveBayes, ClassificationOptimizableNaiveBayes | — |
| SVM | ClassificationLinearSVM, ClassificationQuadraticSVM, ClassificationCubicSVM, ClassificationFineGaussianSVM, ClassificationMediumGaussianSVM, ClassificationCoarseGaussianSVM, ClassificationAllSVM, ClassificationOptimizableSVM | — |
| KNN | ClassificationFineKNN, ClassificationMediumKNN, ClassificationCoarseKNN, ClassificationCosineKNN, ClassificationCubicKNN, ClassificationWeightedKNN, ClassificationAllKNN, ClassificationOptimizableKNN | — |
| Ensemble | ClassificationBoostedEnsemble, ClassificationBaggedEnsemble, ClassificationSubspaceDiscriminantEnsemble, ClassificationSubspaceKNNEnsemble, ClassificationRUSBoostedEnsemble, ClassificationAllEnsemble, ClassificationOptimizableEnsemble | — |
| Neural Net | ClassificationUniLayeredNeuralNetwork, ClassificationBiLayeredNeuralNetwork, ClassificationTriLayeredNeuralNetwork, ClassificationAllNeuralNetwork | R2024a |
| Neural Net (Optimizable) | ClassificationOptimizeNeuralNetwork | R2021b |
| Deep Learning | ClassificationFullyConnectedDLNetwork, ClassificationResidualDLNetwork, ClassificationAllDLNetworks | R2026a |
| Kernel | ClassificationSVMKernel, ClassificationLogisticRegressionKernel | R2021b |
| Kernel (All, Optimizable) | ClassificationAllKernel, ClassificationOptimizableKernel | R2023b |

### Regression Models

| Category | Model Types | Min Release |
|----------|------------|-------------|
| Quick/All | RegressionAllQuickToTrain, RegressionAll | — |
| Simulink | RegressionAllSimulink | R2024a |
| Codegen | RegressionAllCodegen | R2025a |
| Linear | RegressionLinear, RegressionInteractionsLinear, RegressionRobustLinear, RegressionStepwiseLinear, RegressionAllLinear | — |
| Trees | RegressionFineTree, RegressionMediumTree, RegressionCoarseTree, RegressionAllTrees, RegressionOptimizableTree | — |
| SVM | RegressionLinearSVM, RegressionQuadraticSVM, RegressionCubicSVM, RegressionFineGaussianSVM, RegressionMediumGaussianSVM, RegressionCoarseGaussianSVM, RegressionAllSVM, RegressionOptimizableSVM | — |
| Efficient Linear | EfficientLinearLSRegression, EfficientLinearSVMRegression, AllEfficientRegressionLinear, RegressionOptimizableEfficientLinear | R2023b |
| GPR | RegressionRationalQuadraticGPR, RegressionSquaredExponentialGPR, RegressionMatern52GPR, RegressionExponentialGPR, RegressionAllGPR, RegressionOptimizeGPR | — |
| Ensemble | RegressionBoostedEnsemble, RegressionBaggedEnsemble, RegressionAllEnsemble, RegressionOptimizableEnsemble | — |
| Neural Net | RegressionUniLayeredNeuralNetwork, RegressionBiLayeredNeuralNetwork, RegressionTriLayeredNeuralNetwork, RegressionAllNeuralNetwork | R2024a |
| Neural Net (Optimizable) | RegressionOptimizeNeuralNetwork | R2021b |
| Deep Learning | RegressionFullyConnectedDLNetwork, RegressionResidualDLNetwork, RegressionAllDLNetworks | R2026a |
| Kernel | RegressionSVMKernel, LeastSquaresRegressionKernel | R2022a |
| Kernel (All, Optimizable) | RegressionAllKernel, RegressionOptimizableKernel | R2023b |

----

Copyright 2026 The MathWorks, Inc.

----
