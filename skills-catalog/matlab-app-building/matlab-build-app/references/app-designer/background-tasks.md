# Background Tasks — App Designer API reference

> **Read `references/background-tasks.md` first** (what/when, callback signatures,
> limitations — shared by both formats). This doc is the App Designer verb reference only.
>
> **App Designer apps only** (`.mlapp` or plain-text via `AppDesignerAgentInterface`).
> Standalone programmatic apps: use `references/uifigure/mvvm-background-tasks.md` instead.

**MUST** scaffold background execution with `appBuilder.addBackgroundTask(...)` — the
only supported way. **NEVER** hand-write `parfeval` / `backgroundPool` / `DataQueue` /
`afterEach` / `afterAll` or the `startBackground` / `cancelBackground` /
`handleBackgroundComplete` / `safeProgress` / `cleanupBackground` methods, **NEVER**
`addMethod` those infra methods by hand to route around the verb, and **NEVER** copy
the standalone-programmatic wiring into an App Designer app.

## `addBackgroundTask`

```matlab
appBuilder.addBackgroundTask(name, "Fcn", fcn, "CompleteFcn", completeFcn)
appBuilder.addBackgroundTask(name, "Fcn", fcn, "CompleteFcn", completeFcn, "ProgressFcn", progressFcn)
```

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Property name for the task struct (e.g., `"TrainingTask"`) |
| `"Fcn"` | Yes | Name of the static method to run in the background |
| `"CompleteFcn"` | Yes | Name of the completion callback |
| `"ProgressFcn"` | No | Name of the progress callback. Omit if no streaming. |

**Generates** (per call): private struct property (`Fcn`, `CompleteFcn`, `ProgressFcn`,
`Future`, `Queue`, `Running`, `StopRequested`); StartupFcn handle wiring; a static
`Fcn` stub; a `CompleteFcn` stub (pre-filled with cancel/error guards); a `ProgressFcn`
stub (only if specified); a cleanup line in `cleanupBackground`.

**Idempotent infrastructure:** the first call also generates `startBackground`,
`cancelBackground`, `handleBackgroundComplete`, `safeProgress`, `cleanupBackground`,
and a `CloseRequestFcn`. Later calls reuse them and add only the new task's specifics.

**Duplicate rejection:** an existing `name` throws
`AppDesignerAgentInterface:duplicateTask`. Do not re-call for an existing task.

## Build order

1. `create()` / `open()`
2. Add components
3. `addBackgroundTask(...)` per workflow
4. Fill `Fcn` body: `addMethod(fcn, body, "static")`
5. Fill `CompleteFcn` / `ProgressFcn` bodies: `addMethod(name, body, "private")`
6. Wire start/cancel buttons: `setCallbackCode(...)`
7. `save()`

Filling a stub overwrites it and emits an `overwriteMethod` warning — expected, harmless.

## Example (progress + cancel)

```matlab
appBuilder.addBackgroundTask("TrainingTask", ...
    "Fcn", "trainModel", "CompleteFcn", "onTrainingComplete", "ProgressFcn", "onTrainingProgress");

% Background compute: sendProgress injected as last arg
appBuilder.addMethod("trainModel", sprintf([ ...
    'function result = trainModel(data, sendProgress)\n' ...
    'for i = 1:data.NumEpochs\n' ...
    '    result = trainOneEpoch(data, i);\n' ...
    '    sendProgress(struct(''Epoch'', i, ''Loss'', result.loss));\n' ...
    'end\n' ...
    'end']), "static");

appBuilder.addMethod("onTrainingProgress", sprintf([ ...
    'function onTrainingProgress(app, data)\n' ...
    'app.StatusLabel.Text = sprintf("Epoch %%d, Loss: %%.4f", data.Epoch, data.Loss);\n' ...
    'end']), "private");

appBuilder.addMethod("onTrainingComplete", sprintf([ ...
    'function onTrainingComplete(app, result, error, wasCancelled)\n' ...
    'app.TrainButton.Enable = "on"; app.CancelButton.Enable = "off";\n' ...
    'if wasCancelled; app.StatusLabel.Text = "Cancelled."; return; end\n' ...
    'if ~isempty(error); uialert(app.UIFigure, error.message, "Error"); return; end\n' ...
    'plot(app.UIAxes, result.loss);\n' ...
    'end']), "private");

% Start / cancel wiring
appBuilder.setCallbackCode("TrainButtonPushed", ...
    sprintf('app.TrainButton.Enable = "off"; app.CancelButton.Enable = "on";\napp.startBackground(''TrainingTask'', app.getTrainingData());'));
appBuilder.setCallbackCode("CancelButtonPushed", "app.cancelBackground('TrainingTask');");
```

For a no-progress task, omit `"ProgressFcn"` and drop the `sendProgress` arg from the
static `Fcn`. Pass task inputs after the name: `app.startBackground('ExportTask', config)`.

## Multiple tasks

Call `addBackgroundTask` once per workflow; infrastructure is idempotent.

```matlab
appBuilder.addBackgroundTask("TrainingTask", "Fcn", "trainModel", "CompleteFcn", "onTrainDone", "ProgressFcn", "onTrainProgress");
appBuilder.addBackgroundTask("ExportTask", "Fcn", "exportData", "CompleteFcn", "onExportDone");
```

## Editing an existing app

Infrastructure and stubs are already in the model. Replace a task's logic with
`addMethod`. Add a new task with `addBackgroundTask` (idempotent). Never re-call it for
an existing task name.

Copyright 2026 The MathWorks, Inc.

----
