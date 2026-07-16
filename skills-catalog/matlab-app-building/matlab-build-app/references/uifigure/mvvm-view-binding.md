# View Binding Pattern

Complete MainView class demonstrating how to bind a MATLAB uifigure View to a ViewModel using `addlistener` on `SetObservable` properties.

## MainView Class

```matlab
classdef MainView < handle
    properties (Access = private)
        Figure
        ViewModel
        Listeners

        % UI components that need updating
        ResultLabel
        StatusLabel
        ProcessButton
        MethodDropdown
    end

    methods
        function obj = MainView(viewModel)
            arguments
                viewModel AppName.ViewModels.MainViewModel
            end
            obj.ViewModel = viewModel;
            obj.Listeners = listener.empty;

            obj.createUI();
            obj.bindToViewModel();
            obj.syncFromViewModel();  % Initial state
        end

        function delete(obj)
            delete(obj.Listeners);
            if isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end

        function show(obj)
            obj.Figure.Visible = 'on';
        end
    end

    methods (Access = private)
        function createUI(obj)
            obj.Figure = uifigure('Name', 'MVVM App', ...
                'Position', [100 100 500 300], ...
                'Visible', 'off', ...
                'CloseRequestFcn', @(~,~) delete(obj));

            gl = uigridlayout(obj.Figure, [4 2]);
            gl.RowHeight = {'fit', 'fit', 'fit', '1x'};
            gl.ColumnWidth = {120, '1x'};
            gl.Padding = [10 10 10 10];

            % Row 1: Method selection
            uilabel(gl, 'Text', 'Method:');
            obj.MethodDropdown = uidropdown(gl, ...
                'Items', {'linear', 'quadratic', 'cubic'});

            % Row 2: Buttons
            uibutton(gl, 'Text', 'Load File...', ...
                'ButtonPushedFcn', @(~,~) obj.onLoadClicked());
            obj.ProcessButton = uibutton(gl, 'Text', 'Process', ...
                'ButtonPushedFcn', @(~,~) obj.onProcessClicked());

            % Row 3: Result
            uilabel(gl, 'Text', 'Result:');
            obj.ResultLabel = uilabel(gl, 'Text', '');

            % Row 4: Status bar spanning both columns
            obj.StatusLabel = uilabel(gl, 'Text', 'Ready');
            obj.StatusLabel.Layout.Column = [1 2];
            obj.StatusLabel.HorizontalAlignment = 'center';
        end

        function bindToViewModel(obj)
            vm = obj.ViewModel;
            obj.Listeners(end+1) = addlistener(vm, 'DisplayText', 'PostSet', ...
                @(~,~) set(obj.ResultLabel, 'Text', vm.DisplayText));
            obj.Listeners(end+1) = addlistener(vm, 'StatusMessage', 'PostSet', ...
                @(~,~) set(obj.StatusLabel, 'Text', vm.StatusMessage));
            obj.Listeners(end+1) = addlistener(vm, 'IsProcessing', 'PostSet', ...
                @(~,~) obj.onIsProcessingChanged());
            obj.Listeners(end+1) = addlistener(vm, 'CanProcess', 'PostSet', ...
                @(~,~) obj.onCanProcessChanged());
        end

        function syncFromViewModel(obj)
            obj.ResultLabel.Text = obj.ViewModel.DisplayText;
            obj.StatusLabel.Text = obj.ViewModel.StatusMessage;
            obj.onIsProcessingChanged();
            obj.onCanProcessChanged();
        end

        %% ViewModel -> View (property change handlers)

        function onIsProcessingChanged(obj)
            busy = obj.ViewModel.IsProcessing;
            obj.ProcessButton.Enable = ~busy;
            obj.MethodDropdown.Enable = ~busy;
        end

        function onCanProcessChanged(obj)
            obj.ProcessButton.Enable = obj.ViewModel.CanProcess ...
                && ~obj.ViewModel.IsProcessing;
        end

        %% View -> ViewModel (user action handlers)

        function onProcessClicked(obj)
            obj.ViewModel.processCommand(obj.MethodDropdown.Value);
        end

        function onLoadClicked(obj)
            [file, path] = uigetfile('*.csv;*.txt;*.mat', 'Select data file');
            if file ~= 0
                obj.ViewModel.loadFileCommand(fullfile(path, file));
            end
        end
    end
end
```

## View Design Guidelines

- All UI creation and `uigridlayout` patterns come from `guide.md`
- Use `addlistener` to bind ViewModel observables to UI updates
- Store listeners in an array and `delete` them in the destructor
- Wire user events (ButtonPushedFcn, ValueChangedFcn) to ViewModel commands
- The View never talks to the Model directly
- For simple bindings, use inline `set()`: `@(~,~) set(label, 'Text', vm.Prop)`
- For complex bindings (enable/disable logic), use a private method

## Binding Patterns

### Simple binding (one property → one component)

```matlab
addlistener(vm, 'StatusMessage', 'PostSet', ...
    @(~,~) set(obj.StatusLabel, 'Text', vm.StatusMessage));
```

### Complex binding (multiple properties → component state)

```matlab
addlistener(vm, 'IsProcessing', 'PostSet', ...
    @(~,~) obj.updateButtonState());

function updateButtonState(obj)
    canAct = obj.ViewModel.CanProcess && ~obj.ViewModel.IsProcessing;
    obj.ProcessButton.Enable = canAct;
    if obj.ViewModel.IsProcessing
        obj.ProcessButton.Text = "Processing...";
    else
        obj.ProcessButton.Text = "Process";
    end
end
```

### Initial sync

Always call a `syncFromViewModel()` method after binding to set initial UI state from current ViewModel values — listeners only fire on *change*, not on initial value.

----

Copyright 2026 The MathWorks, Inc.

----
