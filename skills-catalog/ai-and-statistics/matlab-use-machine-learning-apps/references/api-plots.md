# API Reference — Plots & Results Table

Opening, configuring, and reading data from standard result plots (scatter, confusion matrix, ROC, precision-recall, parallel coordinates, compare results, response, residuals, training progress, min objective, compare ROC curves) and the Results Table.

For session setup and model creation, see [`api-session-and-models.md`](api-session-and-models.md).
For metrics and configuration options, see [`api-metrics-and-options.md`](api-metrics-and-options.md).
For explainability plots (Shapley, LIME, PDP, permutation importance), see [`api-explainability.md`](api-explainability.md).
For export and diagnostics, see [`api-export-and-diagnostics.md`](api-export-and-diagnostics.md).

---

## Opening Plots

```matlab
% Classification-only plots
app.openScatterPlot();
app.openValidationConfusionMatrixPlot();
app.openTestConfusionMatrixPlot();
app.openValidationROCCurvePlot();
app.openTestROCCurvePlot();
app.openPrecisionRecallPlot();                  % R2024b+
app.openTestPrecisionRecallPlot();              % R2024b+
app.openParallelCoordinatesPlot();
app.openMinClassificationErrorPlot();
app.openCompareROCCurvesPlot();                 % R2025a+

% Regression-only plots
app.openResponsePlot();
app.openValidationPredictedVsActualPlot();
app.openTestPredictedVsActualPlot();
app.openValidationResidualsPlot();
app.openTestResidualsPlot();
app.openMinMSEPlot();

% Shared plots
app.openTrainingProgressPlot();                 % R2026a+
app.openNetworkAnalyzerPlot();                  % R2026a+
app.openCompareResultsPlot();                   % R2024b+

% Explainability plots (configuration in api-explainability.md)
app.openPartialDependencePlot();                % R2022b+
app.openLocalShapleyPlot();                     % R2023b+
app.openLIMEPlot();                             % R2023b+
app.openShapleyImportancePlot();                % R2024b+
app.openShapleySummaryPlot();                   % R2024b+
app.openShapleyDependencePlot();                % R2024b+
app.openPermutationImportancePlot();            % R2025a+
```

## Active Figure

```matlab
name = app.getCurrentActiveFigureName();
hFigure = app.getCurrentActiveFigure();
```

## Checking If Plots/Documents Are Open

```matlab
tf = app.isModelPlotOpen('2.1', 'Scatter');
tf = app.isModelPlotOpen('1.3', 'ConfusionMatrix');

% Supported plotType values:
%   Scatter, ConfusionMatrix, TestConfusionMatrix, ParallelCoordinates,
%   ResponsePlot, PartialDependence, PermutationImportance,
%   ShapleyImportance, ShapleySummary, ShapleyDependence, LocalShapley,
%   LIME, ROCCurve, TestROCCurve, PrecisionRecall, TestPrecisionRecall,
%   PredictedVsActual, TestPredictedVsActual, Residuals, TestResiduals,
%   MinClassificationError, MinMSE, TrainingProgress, AnalyzeNetwork

tf = app.isResultsTableOpen();
tf = app.isCompareResultsPlotOpen();
tf = app.isCompareMultiROCPlotOpen();       % Classification only
```

## Scatter Plot Configuration (Classification Only)

The scatter plot must be the active figure before calling these methods.

**Important:** `'Predictions'` mode requires a trained model to be selected. Do not call `setScatterPlotMode('Predictions')` or `setScatterPlotPredictionVisibility()` unless a model has been trained. The method asserts that predictions mode is active before setting correct/incorrect visibility.

```matlab
% Set X-axis predictor (must match a predictor name in the dataset)
app.setScatterPlotXPredictor('education_num');

% Set Y-axis predictor
app.setScatterPlotYPredictor('hours_per_week');

% Set plot mode: 'Data' (original labels) or 'Predictions' (model predictions)
app.setScatterPlotMode('Data');
app.setScatterPlotMode('Predictions');       % Requires a trained model

% Set class visibility — only named classes are shown, others hidden
app.setScatterPlotClassVisibility({'<=50K'});           % Show only <=50K
app.setScatterPlotClassVisibility({'<=50K', '>50K'});   % Show both

% Show/hide correct and incorrect predictions (Predictions mode must be active)
app.setScatterPlotPredictionVisibility(true, true);    % Show both correct and incorrect
app.setScatterPlotPredictionVisibility(true, false);   % Show only correct predictions
app.setScatterPlotPredictionVisibility(false, true);   % Show only incorrect predictions
```

## Confusion Matrix Configuration (Classification Only)

Works for both validation and test confusion matrix plots. The plot must be the active figure.

```matlab
% Set summary mode
app.setConfusionMatrixPlotMode('Off');            % No summary row/column
app.setConfusionMatrixPlotMode('RowSummary');     % TPR/FNR per true class
app.setConfusionMatrixPlotMode('ColumnSummary');  % PPV/FDR per predicted class
```

## ROC Curve Configuration (Classification Only)

Works for both validation and test ROC curve plots. The plot must be the active figure.

```matlab
% Set which class curves are visible
app.setROCCurveClassVisibility({'<=50K'});           % Show only <=50K curve
app.setROCCurveClassVisibility({'<=50K', '>50K'});   % Show both classes

% Set which averaging method curves are visible
app.setROCCurveAveragingMethodVisibility({'Macro', 'Micro'});  % Show Macro and Micro
app.setROCCurveAveragingMethodVisibility({'Weighted'});        % Show only Weighted
app.setROCCurveAveragingMethodVisibility({});                  % Hide all averaging curves
```

## Precision-Recall Curve Configuration (Classification Only, R2024b+)

Works for both validation and test Precision-Recall plots. The plot must be the active figure.

```matlab
% Set which class curves are visible
app.setPrecisionRecallClassVisibility({'<=50K'});           % Show only <=50K curve
app.setPrecisionRecallClassVisibility({'<=50K', '>50K'});   % Show both classes

% Set which averaging method curves are visible
app.setPrecisionRecallAveragingMethodVisibility({'Macro', 'Micro'});  % Show Macro and Micro
app.setPrecisionRecallAveragingMethodVisibility({'Weighted'});        % Show only Weighted
app.setPrecisionRecallAveragingMethodVisibility({});                  % Hide all averaging curves
```

## Parallel Coordinates Configuration (Classification Only)

The plot must be the active figure.

**Important:** `'Predictions'` mode requires a trained model to be selected. Do not call `setParallelCoordinatesMode('Predictions')` unless a model has been trained.

```matlab
% Set which predictors are displayed as vertical axes
app.setParallelCoordinatesPredictors({'Age', 'Hours_per_week'});  % Show only these two
app.setParallelCoordinatesPredictors(allPredictorNames);          % Show all predictors

% Set the scaling method
app.setParallelCoordinatesScaling("none");      % No scaling
app.setParallelCoordinatesScaling("range");     % Range [0, 1]
app.setParallelCoordinatesScaling("z-score");   % Z-score normalization (default)
app.setParallelCoordinatesScaling("center");    % Center (subtract mean)
app.setParallelCoordinatesScaling("scale");     % Unit variance (divide by std)
app.setParallelCoordinatesScaling("norm");      % Norm

% Set plot mode: 'Data' (original labels) or 'Predictions' (model predictions)
app.setParallelCoordinatesMode('Data');
app.setParallelCoordinatesMode('Predictions');       % Requires a trained model
```

## Compare Results Plot Configuration (R2024b+)

Multiple Compare Results plots can be open simultaneously. These setters operate on the currently active figure — bring the desired plot to focus before calling them.

```matlab
% Managing multiple instances
count = app.getOpenCompareResultsPlotCount();       % Number of open plots
plotIDs = app.getOpenCompareResultsPlotIDs();        % e.g., ["1", "2", "3"]
app.setActiveCompareResultsPlot("2");               % Bring plot 2 to focus

% Get available metrics (returns table with Key and DisplayName columns)
metrics = app.getCompareResultsAvailableMetrics();
% Use Key values with setCompareResultsXMetric/YMetric/SortBy/MetricFilter

% Set X and Y axis metrics
app.setCompareResultsXMetric('PredictionSpeedMetric');
app.setCompareResultsYMetric('AccuracyMetric');

% Set sort options
app.setCompareResultsSortBy('AccuracyMetric');
app.setCompareResultsSortDirection("descend");   % "ascend" or "descend"

% Group by model type and show colors
app.setCompareResultsGroupByModelType(true);
app.setCompareResultsShowModelColors(true);

% Filter by model type visibility — uses model category names (e.g., 'Tree', 'SVM', 'Ensemble'),
% not individual model names. These correspond to the model class groupings in the plot legend.
app.setCompareResultsModelTypeVisibility({'Tree', 'SVM'});              % Show only Tree and SVM models
app.setCompareResultsModelTypeVisibility({'Ensemble', 'KNN'});          % Show only Ensemble and KNN models

% Filter by individual model number — show only specific models
app.setCompareResultsModelNumberVisibility({'1', '2.1', '3'});          % Show only these models
app.setCompareResultsModelNumberVisibility({'1', '2'});                 % Show models 1 and 2

% Filter by metric value conditions — N-by-3 cell array: {metricKey, condition, threshold}
% Conditions: '<=', '>=', '==', '~='
app.setCompareResultsMetricFilter({'AccuracyMetric', '>=', 0.9});                              % Accuracy >= 90%
app.setCompareResultsMetricFilter({'AccuracyMetric', '>=', 0.85; 'PredictionSpeedMetric', '<=', 1000}); % Combined
app.clearCompareResultsMetricFilter();                                                          % Remove all filters
```

## Response Plot Configuration (Regression Only)

Controls for the Response Plot (trace plot). The plot must be the active figure.

```matlab
% Set plot style
app.setResponsePlotStyle("Markers");    % Scatter markers (default)
app.setResponsePlotStyle("Box Plot");   % Box plot (only when X predictor has ≤20 unique values)

% Set X-axis predictor
app.setResponsePlotXPredictor("PetalLength");   % Any predictor name from the dataset
% Use the localized "Observation Index" label for observation-based X-axis

% Show/hide data traces
app.setResponsePlotShowTrainingData(true);      % Show/hide training data markers
app.setResponsePlotShowPredictions(true);       % Show/hide predicted values (requires trained model)
app.setResponsePlotShowResiduals(true);         % Show/hide residual error lines (Markers style only)
```

## Residuals Plot Configuration (Regression Only)

Controls for the Residuals plot. Works on both Validation and Test Residuals plots. The plot must be the active figure.

```matlab
% Set plot style
app.setResidualsPlotStyle("Markers");    % Scatter markers (default)
app.setResidualsPlotStyle("Lines");      % Vertical lines from zero
app.setResidualsPlotStyle("Box Plot");   % Box plot (only when X-axis has ≤30 unique values)

% Set X-axis mode
app.setResidualsPlotXAxisMode("TrueResponse");        % True response values (default)
app.setResidualsPlotXAxisMode("PredictedResponse");   % Predicted response values
app.setResidualsPlotXAxisMode("ObservationIndex");    % Observation number
app.setResidualsPlotXAxisMode("Predictor");           % A specific predictor variable

% Set predictor (also switches X-axis mode to 'Predictor' if needed)
app.setResidualsPlotPredictor("Horsepower");   % Any predictor name from the dataset
```

## Training Progress Plot Configuration (R2026a+)

Controls which subplots are shown in the Training Progress plot. Requires a neural network or deep learning model. The plot must be the active figure.

```matlab
% Show/hide individual subplots (Name-Value, specify any subset)
app.setTrainingProgressPlotVisibility('TrainingLoss', true, 'Gradient', true, 'StepSize', true);
app.setTrainingProgressPlotVisibility('TrainingLoss', true);              % Show only training loss
app.setTrainingProgressPlotVisibility('Gradient', false);                 % Hide gradient, keep others unchanged
app.setTrainingProgressPlotVisibility('TrainingLoss', true, 'StepSize', true);  % Show loss + step
```

## Minimum Objective Plot Configuration

Works for both Min Classification Error and Min MSE plots. The plot must be the active figure.

```matlab
% Switch between scatter plot view and results table view
app.setMinObjectivePlotDisplayMode("Plot");    % Show scatter plot (default)
app.setMinObjectivePlotDisplayMode("Table");   % Show results table
```

## Compare ROC Curves Plot Configuration (R2025a+, Classification only)

Multiple Compare ROC Curves plots can be open simultaneously. These setters operate on the currently active figure.

```matlab
% Set which classes are visible
app.setCompareROCCurvesClassVisibility({'setosa', 'versicolor'});  % Show only these classes

% Set which averaging methods are visible
app.setCompareROCCurvesAveragingMethodVisibility({'Macro', 'Micro'});  % Localized display names

% Set which models are compared (max 4)
app.setCompareROCCurvesModelSelection({'1', '2.1', '3'});

% Switch between validation and test data
app.setCompareROCCurvesDataMode("validation");
app.setCompareROCCurvesDataMode("test");
```

## Reading Standard Plot Data

All plot data getter methods auto-switch to the correct document if the plot is open but not currently active. If the plot is not open, they throw a descriptive error prompting you to open it first.

```matlab
plotData = app.getScatterPlotData();
% Fields: Title, XLabel, YLabel, IsPredictionsModeSelected, ResponseClassTable

plotData = app.getValidationConfusionMatrixPlotData();
% Fields: Title, XLabel, YLabel, ClassLabels, PlotMode ('Off'/'RowSummary'/'ColumnSummary'), NormalizedValues

plotData = app.getParallelCoordinatesPlotData();
% Fields: Title, YLabel, SelectedPredictors, Scaling, IsPredictionsModeSelected, ResponseClasses

plotData = app.getResponsePlotData();           % Regression only
% Fields: Title, XLabel, YLabel, PlotStyle ('Markers'/'Box Plot'),
%   IsShowTrueResponseSelected, IsShowPredictedResponseSelected, IsShowResidualErrorsSelected

plotData = app.getValidationROCCurvePlotData();
% Fields: Title, XLabel, YLabel, ClassesTable, AveragingMethodTable
plotData = app.getTestROCCurvePlotData();

plotData = app.getValidationPrecisionRecallPlotData();     % R2024b+
% Fields: Title, XLabel, YLabel, ClassesTable, AveragingMethodTable
plotData = app.getTestPrecisionRecallPlotData(); % R2024b+

plotData = app.getTestConfusionMatrixPlotData();
% Fields: Title, XLabel, YLabel, ClassLabels, PlotMode, NormalizedValues

plotData = app.getValidationPredictedVsActualPlotData();    % Regression only
% Fields: Title, XLabel, YLabel
plotData = app.getTestPredictedVsActualPlotData();

plotData = app.getValidationResidualsPlotData();     % Regression only
% Fields: Title, XLabel, YLabel, PlotStyle ('Markers'/'Lines'/'Box Plot'),
%   XAxisMode ('TrueResponse'/'PredictedResponse'/'ObservationIndex'/'Predictor'),
%   SelectedPredictor (when XAxisMode is 'Predictor')
plotData = app.getTestResidualsPlotData();

plotData = app.getMinObjectivePlotData();
% Fields: Title, XLabel, YLabel, HyperparametersTable

plotData = app.getTrainingProgressPlotData();    % R2026a+
% Fields: IsTrainingLossSelected, IsGradientSelected, IsStepSizeSelected,
%   TrainingLoss (Title, YLabel, XData, YData),
%   Gradient (Title, YLabel, XData, YData),
%   StepSize (Title, YLabel, XData, YData)

plotData = app.getCompareResultsPlotData();      % R2024b+
% Fields: Title, XLabel, YLabel, XDataMetric, YDataMetric, SortBy,
%   SortDirection, IsGroupByModelType, IsShowModelColors, ModelTypeSelectionTable

plotData = app.getCompareROCCurvesPlotData();    % R2025a+
% Fields: Title, XLabel, YLabel, IsValidationDataSelected, ClassesTable,
%   AveragingMethodTable, ModelsSelectorTable

data = app.getResultsTableData();
```

## Results Table Configuration

**Prerequisite:** The Results Table must be open before calling these methods. Use `app.clickResultsTableToolstripButton()` first.

For what the metric column values mean and how to retrieve them programmatically, see [`api-metrics-and-options.md#metrics`](api-metrics-and-options.md#metrics).

```matlab
% Get all available column names (superset of what can be shown)
allColumns = app.getResultsTableAvailableColumns();

% Get currently visible column names
visibleColumns = app.getResultsTableVisibleColumns();

% Set which columns are visible (Favorite and Model Number are always included)
app.setResultsTableVisibleColumns({'Model Type', 'Accuracy (Validation)', 'Training Time (sec)'});

% Hide specific model rows by model number
app.hideResultsTableRows({'1', '2.1'});

% Show all hidden rows
app.showAllResultsTableRows();

% Export current table view to workspace (visible rows and columns only)
app.exportResultsTableToWorkspace();
app.exportResultsTableToWorkspace('VariableName', 'myResults');

% Export current table view to CSV file (visible rows and columns only)
app.exportResultsTableToFile('results.csv');
app.exportResultsTableToFile('C:\path\to\output\results.csv');
```

**Available columns (classification):**

| Category | Column Names |
|----------|-------------|
| Always present | `Favorite`, `Model Number` |
| Model info | `Status`, `Model Type`, `Preset` |
| Validation metrics | `Accuracy (Validation)`, `Total Cost (Validation)`, `Error Rate (Validation)`, `Macro Precision (Validation)`, `Micro Precision (Validation)`, `Weighted Precision (Validation)`, `Macro Recall (Validation)`, `Micro Recall (Validation)`, `Weighted Recall (Validation)`, `Macro F1 Score (Validation)`, `Micro F1 Score (Validation)`, `Weighted F1 Score (Validation)` |
| Test metrics | Same as validation with `(Test)` suffix — only available when test data is imported |
| Performance | `Prediction Speed (obs/sec)`, `Training Time (sec)`, `Compact Model Size (bytes)`, `Coder Model Size (bytes)` |
| Configuration | `Hyperparameters`, `Selected Features`, `Feature Ranking Algorithm`, `PCA`, `Costs`, `Optimizer Options` |

**Available columns (regression):**

| Category | Column Names |
|----------|-------------|
| Always present | `Favorite`, `Model Number` |
| Model info | `Status`, `Model Type`, `Preset` |
| Validation metrics | `RMSE (Validation)`, `R-Squared (Validation)`, `MSE (Validation)`, `MAE (Validation)`, `MAPE (Validation)` |
| Test metrics | Same as validation with `(Test)` suffix — only available when test data is imported |
| Performance | `Prediction Speed (obs/sec)`, `Training Time (sec)`, `Compact Model Size (bytes)`, `Coder Model Size (bytes)` |
| Configuration | `Hyperparameters`, `Selected Features`, `Feature Ranking Algorithm`, `PCA`, `Optimizer Options` |

**Notes:** Column names are dynamically determined by the app. Use `getResultsTableAvailableColumns()` to get the exact names for the current session. Classification has a `Costs` column; regression does not.

----

Copyright 2026 The MathWorks, Inc.

----
