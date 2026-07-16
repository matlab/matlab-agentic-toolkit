# API Reference — Export & Diagnostics

All export methods (workspace, Simulink, Coder, Experiment Manager, Production Server, code generation, plot data/figure), command logging, and diagnostics.

For session setup and model creation, see [`api-session-and-models.md`](api-session-and-models.md).
For metrics and configuration options, see [`api-metrics-and-options.md`](api-metrics-and-options.md). For toolstrip button equivalents of these export methods (secondary/fallback — use only when the programmatic method fails or the user explicitly requests the interactive dialog), see [`api-metrics-and-options.md#toolstrip-button-clicks`](api-metrics-and-options.md#toolstrip-button-clicks).
For plots, results table (including `exportResultsTableToWorkspace` and `exportResultsTableToFile`), and active figure methods (`getCurrentActiveFigureName`, `getCurrentActiveFigure`), see [`api-plots.md`](api-plots.md).
For explainability plots (Shapley, LIME, PDP, permutation importance), see [`api-explainability.md`](api-explainability.md).

---

## Programmatic Export Methods

### Export Model to Workspace

```matlab
app.exportModelToWorkspace()                                    % default 'trainedModel'
app.exportModelToWorkspace('VariableName', 'myModel')
app.exportModelToWorkspace('IncludeTrainingData', false)        % compact model
```

### Generate Code

```matlab
app.clickGenerateCodeToolstripButton()          % creates file and opens in MATLAB editor (preferred)
code = app.generateCode()                       % returns training function code as char only
code = app.generateCode('OpenInEditor', true)   % returns code as char and opens in editor
```

### Export Partitions and DataSets (R2026a+)

```matlab
app.exportPartitionsAndDataSets()
app.exportPartitionsAndDataSets('IncludeTestData', true, 'IncludeTestPartition', true)
app.exportPartitionsAndDataSets('IncludeFullDataset', true, 'VariableName', 'myPartitions')
```

### Export Plot Data

```matlab
app.exportPlotData()                           % default 'plotData'
app.exportPlotData('VariableName', 'myPlot')
```

### Export Plot to Figure

Exports the current active plot to a new standalone MATLAB figure window. Returns the figure handle.

```matlab
hFig = app.exportPlotToFigure()
```

### Export Model to Simulink (R2024a+)

**Constraint:** Models trained with categorical predictors cannot be exported to Simulink. The export button will be disabled with the error: "Feature is not supported when model is trained with categorical predictors." To export to Simulink, retrain using only numeric predictors or encode categoricals as numeric before loading data into the app.

```matlab
app.exportModelToSimulink('MyModel.slx')
app.exportModelToSimulink('MyModel.slx', 'TargetWorkspace', 'Simulink')
app.exportModelToSimulink('MyModel.slx', 'ShowOutputScores', true)
app.exportModelToSimulink('MyModel.slx', 'RunSimulation', true)
```

### Export Model to Coder (R2025a+)

```matlab
app.exportModelToCoder('C:\MyCoderProject')
app.exportModelToCoder('C:\MyCoderProject', 'EntryPointFunctionName', 'classifyData')
app.exportModelToCoder('C:\MyCoderProject', 'ModelFileName', 'MyModel')
app.exportModelToCoder('C:\MyCoderProject', 'InputType', 'SeparatePredictors')
app.exportModelToCoder('C:\MyCoderProject', 'OpenCoderApp', true)
app.exportModelToCoder('C:\MyCoderProject', 'GenerateMEX', true)
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `EntryPointFunctionName` | string | `'predict'` | Name of generated entry point function |
| `ModelFileName` | string | auto-generated | Base name for .mat model file |
| `PredictorDataFileName` | string | `'PredictorData'` | Name of predictor data .mat file |
| `InputType` | `'SingleDataset'` or `'SeparatePredictors'` | `'SingleDataset'` | Entry point function input style |
| `OpenCoderApp` | logical | `false` | Open MATLAB Coder app after export |
| `GenerateMEX` | logical | `false` | Compile coder project to generate MEX file |

### Create Experiment (R2022a+)

```matlab
app.createExperiment()
app.createExperiment('TrainingDataFileName', 'myTrainingData')
app.createExperiment('ConditionalConstraintsFileName', 'myConstraints')
app.createExperiment('DeterministicConstraintsFileName', 'myDetConstraints')
```


## Command Logging

Record all public method calls for audit, replay, and reproducibility.

```matlab
% Enable logging (preserves any existing log entries)
app.enableCommandLog();

% ... perform actions ...
app.createModelType('ClassificationFineTree');
app.trainCurrentModel();
app.waitForTrainingToComplete();
app.exportModelToWorkspace('VariableName', 'myModel');

% Retrieve the log
log = app.getCommandLog();
% Returns struct array with fields: Timestamp, Method, Args, Duration
% log(1).Method = "createModelType"
% log(1).Args   = {'ClassificationFineTree'}

% Print log as executable MATLAB code
app.printCommandLog();
% Output:
%   mlearnapp.internal.appcontroller.AppController.openApp('classification', Tbl, 'Species');
%   app.createModelType('ClassificationFineTree');
%   app.trainCurrentModel();
%   app.waitForTrainingToComplete();
%   app.exportModelToWorkspace('VariableName', 'myModel');

% Check if logging is active
tf = app.isCommandLogEnabled();

% Clear log entries without disabling
app.clearCommandLog();

% Disable logging (preserves existing entries)
app.disableCommandLog();

% Replay a saved log on another app instance
app2 = mlearnapp.internal.appcontroller.AppController.openApp('classification', Tbl, 'Species');
app2.replayCommandLog(log);
```

**Notes:**
- All public methods are logged (both getters and actions) to provide a complete trace of how an agent made decisions.
- `openApp` is always recorded in the log (even before `enableCommandLog` is called), so the full session history is captured.
- Non-scalar data arguments (tables, matrices, vectors) are logged by variable name when available via `inputname`. When data is passed directly without a variable, a size/class descriptor is logged (e.g., `<150x5 table>`).
- `enableCommandLog` does NOT clear the log — only `clearCommandLog` does. This preserves the `openApp` entry.
- During `replayCommandLog`, logging is temporarily disabled to avoid recording replayed commands.
- Methods that delegate internally (e.g., `trainCurrentModel`) suppress logging of their sub-calls to keep the log flat and readable.
- The `Args` field contains a cell array of the arguments as passed (positional args and name-value pairs flattened).

## Diagnostics

### Find Web Dialogs

```matlab
dialogs = app.findAllWebDialogs()          % all web dialogs in AppContainer
dialogs = app.findAllWebAlertDialogs()     % only alert-style dialogs (with icon)
```

Each element is a struct with fields:
- `Title` — dialog title bar text
- `Buttons` — cell array of button labels
- `Index` — 1-based position among all dialogs
- `Message` — (alert dialogs only) dialog content text

### Dismiss Dialogs

```matlab
app.dismissUIAlert()                % dismiss last web dialog (clicks first button)
app.dismissUIAlert('Title')         % dismiss web dialog by title
app.dismissUIAlert('Title', 2)      % click 2nd button of named dialog
```

Note: `clickGenerateCodeToolstripButton`, `clickTestSelectedModelToolstripButton`, and `clickTestAllModelsToolstripButton` automatically dismiss their respective dialogs.

### List and Select Documents

```matlab
documents = app.getAllOpenDocuments()       % all documents in the app
documents = app.getAllOpenDocuments('7')    % only documents for model 7
app.selectDocument('MLearnAppModel7-TestConfusionMatrixPlot')  % bring document to focus
```

Returns a struct array of open documents within the app (result plots, summary tabs, results table, etc.). Each element has fields:
- `Title` — document title (e.g., "Test Confusion Matrix", "Results Table", "Summary")
- `Tag` — internal tag (e.g., "MLearnAppModel7-TestConfusionMatrixPlot")
- `GroupTag` — document group tag (e.g., "MlearnAppPlotGroupModel7")

## Key Internal Details

- Toolstrip buttons are found via `iFindToolstripButtonInApp(hAppContainer, buttonTag)` which searches the app container's tab group
- Model gallery buttons are found via `getToolstripModelGalleryButton(modelType)` which looks up the gallery popup
- Plot gallery buttons are found via `getToolstripPlotGalleryButton(buttonTag)` which looks up the plot gallery popup
- `GalleryModels.getTag(modelType)` maps enum name to internal gallery item ID
- The `openApp` static method uses a `WindowReady` listener to process initialization steps after the app UI is ready

## Supporting Classes

The following classes support the main `AppController` (exposes the public API) and are loaded at runtime from `scripts/+mlearnapp/+internal/+appcontroller/`:

  - `AppControllerBase` — base class for all controllers
  - `AlertDialogController` — handles alert dialog interactions
  - `AutoDismissConfirmDialogController` — auto-dismiss confirmation dialogs
  - `SessionController` — session management
  - `ImportController` — data import operations
  - `ExportController` — model export operations
  - `ExplainPlotController` — explainability plot operations
  - `ResultsPlotController` — results visualization
  - `ModelOptionsController` — model option configuration
  - `CustomModelController` — custom model handling
  - `NewSessionDialogController` — new session dialog handling
  - `ToolstripController` — toolstrip button interactions
  - `CoderExportStubs` — MATLAB Coder export support
  - `ExperimentExportStub` — Experiment Manager export support
  - `ImportTestDataStubView` — test data import support

All ship as P-coded files; this listing is for documentation purposes only — the agent interacts exclusively with `AppController`.

----

Copyright 2026 The MathWorks, Inc.

----
