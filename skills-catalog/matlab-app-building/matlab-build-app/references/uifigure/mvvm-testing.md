# Testing the ViewModel

One of MVVM's key benefits — test UI logic without creating any UI. The ViewModel is a plain handle class with observable properties and command methods, so it can be exercised entirely from test code.

## Complete Test Example

```matlab
function tests = testMainViewModel()
    tests = functiontests(localfunctions);
end

function testProcessCommand(testCase)
    model = AppName.Models.DataModel();
    model.RawData = [1 2 3 4 5];
    vm = AppName.ViewModels.MainViewModel(model);

    vm.processCommand("quadratic");

    verifyEqual(testCase, model.ProcessedData, [1 4 9 16 25]);
    verifyEqual(testCase, vm.StatusMessage, "Complete");
    verifyFalse(testCase, vm.IsProcessing);
    verifyTrue(testCase, vm.CanProcess);
end

function testProcessCommandError(testCase)
    model = AppName.Models.DataModel();
    vm = AppName.ViewModels.MainViewModel(model);

    vm.processCommand("linear");

    verifySubstring(testCase, vm.StatusMessage, "Error");
end

function testCanProcessUpdates(testCase)
    model = AppName.Models.DataModel();
    vm = AppName.ViewModels.MainViewModel(model);

    verifyFalse(testCase, vm.CanProcess);

    model.RawData = [1 2 3];
    verifyTrue(testCase, vm.CanProcess);
end
```

Run with `runtests('testMainViewModel')`. No figure window needed.

## Test Patterns

### Testing computed state

```matlab
function testComputedStateReactsToModel(testCase)
    model = AppName.Models.DataModel();
    vm = AppName.ViewModels.MainViewModel(model);

    % Initially no data → can't process
    verifyFalse(testCase, vm.CanProcess);

    % Load data → can process
    model.RawData = rand(1, 10);
    verifyTrue(testCase, vm.CanProcess);
end
```

### Testing async commands

```matlab
function testAsyncCommandSetsProcessingState(testCase)
    model = AppName.Models.DataModel();
    model.RawData = [1 2 3];
    vm = AppName.ViewModels.MainViewModel(model);

    vm.processAsyncCommand("linear");

    % Immediately after calling, should be processing
    verifyTrue(testCase, vm.IsProcessing);
    verifyEqual(testCase, vm.StatusMessage, "Processing...");

    % Wait for background task
    pause(2);
    verifyFalse(testCase, vm.IsProcessing);
    verifyEqual(testCase, vm.StatusMessage, "Complete");
end
```

### Testing Model isolation

```matlab
function testModelHasNoViewReferences(testCase)
    model = AppName.Models.DataModel();
    mc = metaclass(model);

    % Verify no property holds a View or ViewModel reference
    for i = 1:numel(mc.PropertyList)
        p = mc.PropertyList(i);
        if ~p.Dependent && ~p.Constant
            val = model.(p.Name);
            verifyFalse(testCase, isa(val, 'AppName.Views.MainView'));
            verifyFalse(testCase, isa(val, 'AppName.ViewModels.MainViewModel'));
        end
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
