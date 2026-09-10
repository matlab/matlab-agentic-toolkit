# Background Tasks — Standalone Programmatic (MVVM) reference

> **Read `references/background-tasks.md` first** (what/when, callback signatures,
> limitations — shared by both formats). This doc is the manual wiring reference only.
>
> **Standalone programmatic apps only** (plain `.m`, no App Designer). If your app is
> a `.mlapp` or plain-text App Designer app, STOP — use the `addBackgroundTask` verb
> (`references/app-designer/background-tasks.md`). Never hand-wire this into one.

No verb exists on this path, so you wire the pattern in by hand. Background execution
requires a class-structured app, so use MVVM (read `references/uifigure/mvvm-guide.md`
and `references/uifigure/mvvm-view-binding.md` first). The five infra methods drop into
the **View** verbatim from the template files under
`scripts/+module/+backgroundtask/templates/` — transcribe each without editing, except
omit its trailing `% Copyright` line.

## Where each piece lives

| Piece | Class | Why |
|-------|-------|-----|
| Compute function (`Fcn`) | **Model**, static | Business logic, runs on the worker as `@ModelClass.fcn`, touches no UI |
| Per-task struct property | **View** | Infra reads/writes it as `app.(taskName)` |
| Infra methods (`startBackground`, `cancelBackground`, `handleBackgroundComplete`, `safeProgress`, `cleanupBackground`) | **View** | Call `uialert(app.UIFigure, ...)`; MVVM forbids the Model referencing the View |
| Completion / progress callbacks | **View** | Update components (or push through the ViewModel) |
| `CloseRequestFcn` | **View** | Must cancel in-flight futures before the figure is destroyed |

## Setup

1. **Name the View's figure property `UIFigure`** (infra calls `uialert(app.UIFigure, ...)`).
   Keep the infra methods' receiver arg named `app`, matching the templates, even though a
   View conventionally uses `obj`.

2. **Per-task struct property** (private, one per task):

   ```matlab
   TrainingTask = struct('Fcn', [], 'CompleteFcn', [], 'ProgressFcn', [], ...
       'Future', [], 'Queue', [], 'Running', false, 'StopRequested', false);
   ```

3. **Drop the four template methods** into the View's private methods verbatim (omitting
   each file's trailing `% Copyright` line):
   `startBackground`, `cancelBackground`, `handleBackgroundComplete`, `safeProgress`.
   Write `cleanupBackground` with one cancel line per task:

   ```matlab
   function cleanupBackground(app)
       if ~isempty(app.TrainingTask.Future); cancel(app.TrainingTask.Future); end
       % ... one line per task ...
   end
   ```

4. **CloseRequestFcn** cancels work before teardown:

   ```matlab
   app.UIFigure = uifigure('CloseRequestFcn', @(~,~) app.onClose());
   function onClose(app); app.cleanupBackground(); delete(app); end
   ```

5. **Wire handles at construction** (the verb's StartupFcn equivalent):

   ```matlab
   app.TrainingTask.Fcn = @MyApp.Models.TrainingModel.trainModel;  % static, on the Model
   app.TrainingTask.CompleteFcn = @app.onTrainingComplete;         % View method
   app.TrainingTask.ProgressFcn = @app.onTrainingProgress;         % omit if no progress
   ```

6. **Compute function on the Model** (static, thread-worker compatible):

   ```matlab
   methods (Static)
       function result = trainModel(data, sendProgress)
           for i = 1:data.NumEpochs
               result = trainOneEpoch(data, i);
               sendProgress(struct('Epoch', i, 'Loss', result.loss));
           end
       end
   end
   ```

7. **Start / cancel from View handlers** (wired to buttons):

   ```matlab
   function onTrainClicked(app); app.startBackground('TrainingTask', app.ViewModel.getTrainingData()); end
   function onCancelClicked(app); app.cancelBackground('TrainingTask'); end
   ```

Completion/progress callbacks are ordinary View methods with the signatures in the
hub's "Callback signatures". Update components directly or route through the ViewModel.

Copyright 2026 The MathWorks, Inc.

----
