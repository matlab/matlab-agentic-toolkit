# API Reference — Explainability

Partial dependence, permutation importance, Shapley (importance, summary, dependence, local), LIME plot configuration, Shapley parameter settings, and explainability plot data getters.

For session setup and model creation, see [`api-session-and-models.md`](api-session-and-models.md).
For metrics and configuration options, see [`api-metrics-and-options.md`](api-metrics-and-options.md).
For standard plots (scatter, confusion, ROC, etc.) and active figure methods (`getCurrentActiveFigureName`, `getCurrentActiveFigure`), see [`api-plots.md`](api-plots.md).
For export and diagnostics, see [`api-export-and-diagnostics.md`](api-export-and-diagnostics.md).

---

## Partial Dependence Plot Configuration (R2022b+)

The Partial Dependence plot must be the active figure.

```matlab
% Set predictor (X-axis)
app.setPartialDependencePredictor('PetalWidth');

% Switch between Training and Test data
app.setPartialDependenceDataMode("Training");
app.setPartialDependenceDataMode("Test");   % Requires test data imported

% Set visible response classes (classification only)
app.setPartialDependenceClassVisibility(["setosa", "versicolor"]);  % Show only these classes
```

## Permutation Importance Plot Configuration (R2025a+)

The Permutation Importance plot must be the active figure.

```matlab
% Switch between Training and Test data
app.setPermutationImportanceDataMode("Training");
app.setPermutationImportanceDataMode("Test");   % Requires test data imported

% Set number of top predictors to display
app.setPermutationImportanceTopPredictors(5);

% Set number of permutations (triggers recomputation)
app.setPermutationImportanceNumPermutations(30);
```

## Shapley Importance Plot Configuration (R2024b+)

The Shapley Importance plot must be the active figure. Requires Shapley values computed.

```matlab
% Set number of top predictors to display
app.setShapleyImportanceTopPredictors(8);

% Set visible response classes (classification only)
app.setShapleyImportanceClassVisibility(["setosa", "versicolor"]);
```

## Shapley Summary Plot Configuration (R2024b+)

The Shapley Summary plot must be the active figure. Requires Shapley values computed.

```matlab
% Set number of top predictors to display
app.setShapleySummaryTopPredictors(8);

% Set plot style
app.setShapleySummaryPlotStyle("swarmplot");   % Swarm chart (default)
app.setShapleySummaryPlotStyle("boxplot");     % Box chart

% Set colormap (swarmplot only)
app.setShapleySummaryColorMap("turbo");

% Set response class (classification only)
app.setShapleySummaryClass("setosa");

% Set jitter mode — depends on current plot style
app.setShapleySummaryJitterMode("density");  % Swarm: "density" | "rand"
app.setShapleySummaryJitterMode("on");       % Box:   "on" | "off"
```

## Shapley Dependence Plot Configuration (R2024b+)

The Shapley Dependence plot must be the active figure. Requires Shapley values computed.

```matlab
% Set X-axis predictor
app.setShapleyDependenceXPredictor('PetalLength');

% Set color predictor (for colorbar)
app.setShapleyDependenceColorPredictor('SepalWidth');

% Set colormap
app.setShapleyDependenceColorMap("turbo");

% Set response class (classification only)
app.setShapleyDependenceClass("setosa");

% Set color range (requires color predictor selected)
app.setShapleyDependenceColorRange(0.5, 3.0);
```

## Local Shapley Plot Configuration (R2023b+)

The Local Shapley plot must be the active figure.

```matlab
% Set query point index
app.setLocalShapleyQueryPointIndex(5);

% Switch between Training and Test data
app.setLocalShapleyDataMode("Training");
app.setLocalShapleyDataMode("Test");

% Set number of top predictors to display
app.setLocalShapleyTopPredictors(6);

% Show/hide query points overlay
app.setLocalShapleyShowQueryPoints(true);
app.setLocalShapleyShowQueryPoints(false);

% Set query point plot X and Y variables (predictor names from dataset)
app.setLocalShapleyQueryPointPlotXVariable("PetalLength");
app.setLocalShapleyQueryPointPlotYVariable("SepalWidth");

% Set query point plot type (regression only): values from dropdown (e.g., "Predicted vs. Actual", "Residuals")
app.setLocalShapleyQueryPointPlotType("Predicted vs. Actual");

% Show/hide data series in query point plot (regression only)
app.setLocalShapleyQueryPointVisibilityRegression('ShowTrue', true, 'ShowPredicted', true, 'ShowErrors', false);

% Switch query point mode: data index vs what-if analysis
app.setLocalShapleyQueryPointMode("dataindex");
app.setLocalShapleyQueryPointMode("whatif");

% Show/hide correct and incorrect predictions (classification only)
app.setLocalShapleyQueryPointVisibility(true, false);  % show correct, hide incorrect

% Set visible response classes in Shapley bar chart (classification only)
app.setLocalShapleyClassVisibility(["setosa", "versicolor"]);

% Set Shapley computation options
app.setLocalShapleyOptions('ShapleyMethod', "interventional");   % "interventional" | "conditional"
app.setLocalShapleyOptions('NumObservationSamples', 100);
app.setLocalShapleyOptions('MaxNumSubsetsMode', "manual", 'MaxNumSubsets', 50);  % "auto" | "manual"

% Set custom predictor values in what-if analysis mode (requires "whatif" mode active)
app.setLocalShapleyCustomPredictorValues(struct('PetalLength', 3.5, 'SepalWidth', 2.8));

% Switch query points section between plot and table view: "plot" | "table"
app.setLocalShapleyQueryPointDisplayMode("plot");
app.setLocalShapleyQueryPointDisplayMode("table");

% Switch Shapley results section between plot and table view: "plot" | "table"
app.setLocalShapleyResultsDisplayMode("plot");
app.setLocalShapleyResultsDisplayMode("table");
```

## LIME Plot Configuration (R2023b+)

The LIME plot must be the active figure.

```matlab
% Set query point index
app.setLIMEQueryPointIndex(10);

% Switch between Training and Test data
app.setLIMEDataMode("Training");
app.setLIMEDataMode("Test");

% Set simple model type: "linear" | "tree"
app.setLIMESimpleModelType("linear");

% Set number of important predictors in simple model
app.setLIMENumImportantPredictors(5);

% Set kernel width (range: 0.001 to 1)
app.setLIMEKernelWidth(0.75);

% Set number of synthetic data samples
app.setLIMENumSyntheticData(5000);

% Set data locality mode: "local" | "global"
app.setLIMEDataLocality("local");

% Set number of neighbors (only when data locality is "local")
app.setLIMENumNeighbors(1500);

% Show/hide query points overlay
app.setLIMEShowQueryPoints(true);
app.setLIMEShowQueryPoints(false);

% Set query point plot X and Y variables (predictor names from dataset)
app.setLIMEQueryPointPlotXVariable("PetalLength");
app.setLIMEQueryPointPlotYVariable("SepalWidth");

% Set query point plot type (regression only): values from dropdown (e.g., "Predicted vs. Actual", "Residuals")
app.setLIMEQueryPointPlotType("Predicted vs. Actual");

% Show/hide data series in query point plot (regression only)
app.setLIMEQueryPointVisibilityRegression('ShowTrue', true, 'ShowPredicted', true, 'ShowErrors', false);

% Switch query point mode: data index vs what-if analysis
app.setLIMEQueryPointMode("dataindex");
app.setLIMEQueryPointMode("whatif");

% Show/hide correct and incorrect predictions (classification only)
app.setLIMEQueryPointVisibility(true, false);  % show correct, hide incorrect

% Set custom predictor values in what-if analysis mode (requires "whatif" mode active)
app.setLIMECustomPredictorValues(struct('PetalLength', 3.5, 'SepalWidth', 2.8));

% Switch query points section between plot and table view: "plot" | "table"
app.setLIMEQueryPointDisplayMode("plot");
app.setLIMEQueryPointDisplayMode("table");

% Switch LIME results section between plot and table view: "plot" | "table"
app.setLIMEResultsDisplayMode("plot");
app.setLIMEResultsDisplayMode("table");
```

## Set Shapley Parameters (R2024b+)

```matlab
% Set on session default (applies to all models without per-model overrides)
app.setShapleyParameters('QueryDataSet', 'training', 'NumQueryPoints', 200)
app.setShapleyParameters('ShapleyMethod', 'conditional', 'NumObservationSamples', 100, 'MaxNumPredictorSubsets', 512)

% Set on a specific model
app.setShapleyParameters('ModelNumber', '4', 'NumQueryPoints', 150, 'ShapleyMethod', 'interventional')
```

| Argument | Type | Description |
|----------|------|-------------|
| `QueryDataSet` | `'training'`, `'test'`, or `'all'` | Data source for selecting query points |
| `NumQueryPoints` | positive integer | Number of query points for Shapley computation |
| `ShapleyMethod` | `'interventional'` or `'conditional'` | Shapley computation method |
| `NumObservationSamples` | positive integer | Number of background samples from training data |
| `MaxNumPredictorSubsets` | positive integer (power of 2) | Maximum predictor subsets for computation |
| `ModelNumber` | string (optional) | Target a specific model; omit for session default |

All arguments are optional name-value pairs. Only provided values are updated; others retain their current settings.

## Reading Explainability Plot Data

All plot data getter methods auto-switch to the correct document if the plot is open but not currently active. If the plot is not open, they throw a descriptive error prompting you to open it first.

```matlab
plotData = app.getPartialDependencePlotData();   % R2022b+
% Fields: Title, SelectedPredictor, IsTrainingSetSelected,
%   SelectedResponseClasses (classification only), DataTipsInfo

plotData = app.getPermutationImportancePlotData();   % R2025a+
% Fields: Title, XLabel, YLabel, SortedPredictorNames, SortedImportanceValues,
%   PlotOptions (IsTrainingDataSelected, NumPermutations, TopNumPredictors), DataTipsInfo

plotData = app.getShapleyImportancePlotData();   % R2024b+
% Fields: Title, XLabel, YLabel, SortedPredictorNames, SortedImportanceValues,
%   PlotOptions (SelectedClasses [classification], ClassNames [classification], NumPredictors),
%   DataTipsInfo

plotData = app.getShapleySummaryPlotData();      % R2024b+
% Fields: Title, XLabel, YLabel, SortedPredictorNames,
%   PlotOptions (IsSwarmChartSelected, SelectedClass [classification], NumPredictors,
%   JitterPoints, Colormap, JitterOutliers), DataTipsInfo

plotData = app.getShapleyDependencePlotData();   % R2024b+
% Fields: Title, XLabel, YLabel, IsScatterPlot,
%   PlotOptions (SelectedClass [classification], XPredictor, ColorPredictor, Colormap,
%   ColorRangeMin, ColorRangeMax), DataTipsInfo

plotData = app.getLocalShapleyPlotData();        % R2023b+
% Fields: IsQueryPointsPlotModeSelected, QueryPointsPlot (Title, XLabel, YLabel,
%   ShowCorrectPointsSelected/ShowIncorrectPointsSelected [classification] or
%   PlotType/ShowTruePointsSelected/ShowPredictedPointsSelected/ShowErrorPointsSelected [regression]),
%   IsShapleyPlotModeSelected, ShapleyPlot (Title, XLabel, YLabel, SortedPredictorNames,
%   SortedImportanceValues), or ShapleyResultsTable (when results table mode selected)

plotData = app.getLIMEPlotData();                % R2023b+
% Fields: IsQueryPointsPlotModeSelected, QueryPointsPlot (Title, XLabel, YLabel,
%   ShowCorrectPointsSelected/ShowIncorrectPointsSelected [classification] or
%   PlotType/ShowTruePointsSelected/ShowPredictedPointsSelected/ShowErrorPointsSelected [regression]),
%   IsLIMEPlotModeSelected, LIMEPlot (Title, XLabel, YLabel, SortedPredictorNames,
%   SortedImportanceValues, WhatIfSortedImportanceValues), or LIMEResultsTable (when results table mode selected)

paramData = app.getShapleyParametersFromDialog();   % R2024b+
% Fields: QueryDataSet, NumQueryPoints, NumObservationSamples, ShapleyMethod,
%   MaxNumPredictorSubsets. Returns [] if dialog is not open.

paramData = app.getShapleyParametersFromPlot();     % R2024b+
% Fields: QueryDataSet ('training'|'test'|'all'), NumQueryPoints, ShapleyMethod
%   ('interventional'|'conditional'), NumObservationSamples, MaxNumPredictorSubsets.
%   Returns [] if no Shapley plot is active.
```

----

Copyright 2026 The MathWorks, Inc.

----
