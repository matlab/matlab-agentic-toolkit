# MATLAB UIFigure MVVM

Structure MATLAB uifigure apps using the Model-View-ViewModel pattern. This skill provides the architectural layer — class design, data binding via `SetObservable`/`addlistener`, ViewModel commands, and separation of concerns.

## Critical Rules

- MUST separate Model, ViewModel, and View into distinct classes
- MUST use MATLAB package folders (`+AppName/+Models/`, `+ViewModels/`, `+Views/`)
- MUST use `SetObservable` properties on Model and ViewModel for data binding
- MUST bind View to ViewModel via `addlistener(vm, 'Prop', 'PostSet', @cb)`
- MUST clean up all listeners in class destructors (`delete` method)
- NEVER put UI component code in the ViewModel
- NEVER put business logic or data transformation in the View
- NEVER have the Model reference the ViewModel or View
- ALWAYS use `arguments` blocks to validate constructor inputs

## Architecture Overview

```
+AppName/
+-- +Models/
|   +-- DataModel.m            % Data + business logic (handle, SetObservable)
+-- +ViewModels/
|   +-- MainViewModel.m        % Bindable state + commands (handle, SetObservable)
+-- +Views/
|   +-- MainView.m             % uifigure UI + binding (handle)
+-- runApp.m                   % Entry point: wires M -> VM -> V
```

Data flow:
1. User interacts with View (click, type, slide)
2. View calls ViewModel command method
3. ViewModel updates Model or its own observable properties
4. `PostSet` listener fires automatically
5. View callback updates the UI component

```
View --[user action]--> ViewModel --[update]--> Model
View <--[PostSet listener]-- ViewModel <--[PostSet listener]-- Model
```

## Model

The Model holds data and business logic. It extends `handle` and uses `SetObservable` properties so the ViewModel can listen for changes.

```matlab
classdef DataModel < handle
    properties (SetObservable)
        RawData double = []
        ProcessedData double = []
        IsValid logical = false
    end

    methods
        function obj = DataModel()
        end

        function process(obj, method)
            arguments
                obj
                method string {mustBeMember(method, ["linear","quadratic","cubic"])}
            end
            switch method
                case "linear"
                    obj.ProcessedData = obj.RawData * 2;
                case "quadratic"
                    obj.ProcessedData = obj.RawData .^ 2;
                case "cubic"
                    obj.ProcessedData = obj.RawData .^ 3;
            end
            obj.IsValid = ~isempty(obj.ProcessedData);
        end

        function loadFromFile(obj, filepath)
            arguments
                obj
                filepath string {mustBeFile}
            end
            obj.RawData = readmatrix(filepath);
            obj.IsValid = false;
            obj.ProcessedData = [];
        end
    end
end
```

### Model Design Guidelines

- Keep Models pure — no UI references, no ViewModel references
- Models can be tested independently: `m = DataModel(); m.process("linear");`
- Multiple ViewModels can share one Model (useful for split-pane apps)
- Use `SetObservable` on any property the ViewModel needs to react to

## ViewModel

The ViewModel exposes Model data as observable properties and provides command methods the View can call. It listens to Model changes and reformats data for display.

```matlab
classdef MainViewModel < handle
    properties (SetObservable)
        DisplayText string = ""
        StatusMessage string = "Ready"
        IsProcessing logical = false
        CanProcess logical = false
    end

    properties (Access = private)
        Model
        ModelListeners
    end

    methods
        function obj = MainViewModel(model)
            arguments
                model AppName.Models.DataModel
            end
            obj.Model = model;

            obj.ModelListeners = [
                addlistener(model, 'ProcessedData', 'PostSet', ...
                    @(~,~) obj.onModelChanged())
                addlistener(model, 'RawData', 'PostSet', ...
                    @(~,~) obj.onRawDataChanged())
            ];

            obj.syncFromModel();
        end

        function delete(obj)
            delete(obj.ModelListeners);
        end

        %% Commands — called by View

        function processCommand(obj, method)
            obj.IsProcessing = true;
            obj.StatusMessage = "Processing...";
            try
                obj.Model.process(method);
                obj.StatusMessage = "Complete";
            catch ex
                obj.StatusMessage = "Error: " + ex.message;
            end
            obj.IsProcessing = false;
        end

        function loadFileCommand(obj, filepath)
            obj.IsProcessing = true;
            obj.StatusMessage = "Loading...";
            try
                obj.Model.loadFromFile(filepath);
                obj.StatusMessage = sprintf("Loaded %d values", numel(obj.Model.RawData));
            catch ex
                obj.StatusMessage = "Error: " + ex.message;
            end
            obj.IsProcessing = false;
        end
    end

    methods (Access = private)
        function onModelChanged(obj)
            obj.syncFromModel();
        end

        function onRawDataChanged(obj)
            obj.CanProcess = ~isempty(obj.Model.RawData);
            obj.syncFromModel();
        end

        function syncFromModel(obj)
            if obj.Model.IsValid
                obj.DisplayText = sprintf("Result: %.2f (n=%d)", ...
                    mean(obj.Model.ProcessedData), numel(obj.Model.ProcessedData));
            else
                obj.DisplayText = "";
            end
        end
    end
end
```

### ViewModel Design Guidelines

- Every piece of UI state should be a `SetObservable` property
- Commands are plain methods — View calls them, ViewModel does the work
- The ViewModel never references UI components or the View
- Put presentation logic here: formatting, display strings, enabled/disabled state
- Computed state (like `CanProcess`) is updated in reaction to Model changes — recalculate in the listener callback

### Computed Properties Pattern

MATLAB doesn't have auto-tracking dependent properties like JS `Computed`. Instead, recalculate in listener callbacks:

```matlab
% In ViewModel constructor:
addlistener(model, 'RawData', 'PostSet', @(~,~) obj.updateCanProcess());

% Private method:
function updateCanProcess(obj)
    obj.CanProcess = ~isempty(obj.Model.RawData) && ~obj.IsProcessing;
end
```

For properties derived from multiple sources, call the updater from each relevant listener.

## View

The View creates the uifigure UI and binds it to ViewModel observables via `addlistener`. See `mvvm-view-binding.md` for the complete MainView class pattern and View design guidelines.

Key principles:
- All UI creation uses `uigridlayout` patterns
- Bind ViewModel observables to UI updates via `addlistener(vm, 'Prop', 'PostSet', @cb)`
- Store listeners in an array and `delete` them in the destructor
- Wire user events (ButtonPushedFcn, ValueChangedFcn) to ViewModel commands
- The View never talks to the Model directly
- For simple bindings: `@(~,~) set(label, 'Text', vm.Prop)`
- For complex bindings (enable/disable logic): use a private method

## Entry Point

The entry point creates Model, ViewModel, and View in dependency order:

```matlab
function app = runApp()
    model = AppName.Models.DataModel();
    viewModel = AppName.ViewModels.MainViewModel(model);
    view = AppName.Views.MainView(viewModel);
    view.show();

    app.model = model;
    app.viewModel = viewModel;
    app.view = view;
end
```

**Usage:** `app = AppName.runApp();`

The returned struct keeps all objects alive. When the user closes the figure, the View destructor fires, but Model and ViewModel persist for inspection. To fully clean up: `clear app`.

**Do NOT use `assignin('base', ...)`** — it pollutes the base workspace and makes cleanup unpredictable. Return a struct instead.

## Async Commands with parfeval

For long-running operations, keep the UI responsive:

```matlab
% In ViewModel:
function processAsyncCommand(obj, method)
    obj.IsProcessing = true;
    obj.StatusMessage = "Processing...";

    f = parfeval(backgroundPool, @processInBackground, 1, obj.Model.RawData, method);
    afterEach(f, @(result) obj.onAsyncComplete(result), 0);
end
```

```matlab
% Private method in ViewModel:
function onAsyncComplete(obj, result)
    obj.Model.ProcessedData = result;
    obj.Model.IsValid = true;
    obj.StatusMessage = "Complete";
    obj.IsProcessing = false;
end
```

```matlab
% Standalone function (must be self-contained for backgroundPool)
function result = processInBackground(data, method)
    switch method
        case "linear",    result = data * 2;
        case "quadratic", result = data .^ 2;
        case "cubic",     result = data .^ 3;
    end
end
```

The background function cannot reference handle objects — pass raw data in, get raw data out. The `afterEach` callback runs on the main thread and can safely update ViewModel properties.

## Testing the ViewModel

One of MVVM's key benefits — test UI logic without creating any UI. See `mvvm-testing.md` for complete test examples.

Run tests with `runtests('testMainViewModel')` — no figure window needed.

## Composition with Other Skills

| Path | How MVVM Composes |
|------|-------------------|
| **UIFigure app** | View uses `guide.md` layout patterns. Model is pure MATLAB. |
| **UIHTML app** | ViewModel sends bridge events via `sendEventToHTMLSource` instead of updating a MATLAB View. JS View subscribes to bridge events. See `references/uihtml/bridge-guide.md`. |
| **Styling** | View applies `matlab-apply-theme` patterns to components. ViewModel is style-agnostic. |
| **Coding** | Model and ViewModel use `arguments` blocks for validation and structured error handling. |

## Implementation Checklist

- [ ] Package folder structure: `+AppName/+Models/`, `+ViewModels/`, `+Views/`
- [ ] Model extends `handle` with `SetObservable` data properties
- [ ] Model contains business logic only (no UI code)
- [ ] ViewModel extends `handle` with `SetObservable` presentation properties
- [ ] ViewModel listens to Model via `addlistener` and syncs on changes
- [ ] ViewModel commands handle user actions (no UI component references)
- [ ] View creates UI with `uigridlayout` (no `Position`-based layout)
- [ ] View binds to ViewModel via `addlistener` on `PostSet`
- [ ] View stores listeners in an array and deletes them in `delete()`
- [ ] Entry point returns a struct to keep object references alive
- [ ] Heavy computations use `parfeval(backgroundPool, ...)` in async commands
- [ ] ViewModel can be tested without creating a View

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| View not updating when Model changes | ViewModel not listening to Model | Add `addlistener(model, 'Prop', 'PostSet', @cb)` in ViewModel constructor |
| Listener callback not firing | Property not `SetObservable` | Add `SetObservable` attribute to the properties block |
| Objects garbage-collected immediately | No reference held | Return struct from `runApp()`, assign to variable |
| Stale UI after ViewModel change | View not bound to that property | Add `addlistener` in `bindToViewModel()` and initial `syncFromViewModel()` |
| Invalid or deleted object error | Listener fires after View destroyed | Delete listeners in View's `delete()` method |
| Cannot pass handle objects to parfeval | backgroundPool is a separate process | Pass raw data to background function, update handles in `afterEach` callback |
| Circular listener updates | Model change triggers ViewModel triggers Model | Use a guard flag or check value equality before setting |

## References

| Topic | File | Description |
|-------|------|-------------|
| View binding | `mvvm-view-binding.md` | Complete MainView class, addlistener binding, View design guidelines |
| Testing | `mvvm-testing.md` | ViewModel unit tests without UI, test patterns |

----

Copyright 2026 The MathWorks, Inc.

----
