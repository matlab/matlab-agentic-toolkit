# App Designer Testing

Test MATLAB App Designer applications programmatically using `matlab.uitest.TestCase`, which simulates real user interactions — button presses, dropdown selections, text entry, slider drags — and verifies app behavior.

## Workflow

1. **Inspect the app** — Read the app class to identify components, callbacks, and testable behavior
2. **Design test cases** — Map each user workflow to a test method (arrange state, perform gestures, verify outcome)
3. **Create the test class** — Inherit from `matlab.uitest.TestCase`, launch the app in `TestMethodSetup` with `addTeardown` for cleanup
4. **Write gesture sequences** — Simulate user actions using `matlab.uitest.TestCase` gesture methods (see Key Functions below)
5. **Verify outcomes** — Assert on component values, visibility, plot data, table contents, or app properties
6. **Run and iterate** — Execute via `run_matlab_test_file`, fix failures, add edge cases

## Key Functions

| Category | Functions |
|----------|-----------|
| Test base class | `matlab.uitest.TestCase` |
| Gesture — click | `press(tc, comp)` — buttons, switches, state buttons, spinners, axes |
| Gesture — select | `choose(tc, comp, option)` — dropdowns, list boxes, knobs, tabs, sliders, table cells |
| Gesture — text | `type(tc, comp, value)` — edit fields, text areas, table cells |
| Gesture — drag | `drag(tc, comp, start, stop)` — sliders, knobs, axes |
| Gesture — hover | `hover(tc, comp)`, `hover(tc, comp, location)` — axes, figures |
| Gesture — scroll | `scroll(tc, comp, direction)` — axes, figures (R2024a+) |
| Context menus | `chooseContextMenu(tc, comp, menuItem)` — right-click menus (R2020b+) |
| Dialog — dismiss | `dismissDialog(tc, dialogType, fig)` — close alert dialogs (R2024b+) |
| Dialog — choose | `chooseDialog(tc, dialogType, fig, option)` — select dialog option (R2024b+) |
| Figure unlock | `matlab.uitest.unlock(fig)` — unlock figure for manual interaction after test |
| Interactive use | `matlab.uitest.TestCase.forInteractiveUse` — ad-hoc testing at command window |

## Patterns

### Test Class Structure

Every app test class follows this pattern: store the app in a property, launch in `TestMethodSetup` with `addTeardown` for cleanup, interact via gestures in test methods. The app name (`MyApp`), component names (`RunButton`, `StatusLabel`), and expected values (`'Ready'`) in the example below are example-specific — substitute with the actual app under test.

```matlab
classdef MyAppTest < matlab.uitest.TestCase

    properties (Access = private)
        App
    end

    methods (TestMethodSetup)
        function launchApp(testCase)
            testCase.App = MyApp();
            testCase.addTeardown(@delete, testCase.App);
            drawnow;
        end
    end

    methods (Test)
        function testDefaultState(testCase)
            testCase.verifyEqual(testCase.App.StatusLabel.Text, 'Ready');
        end

        function testButtonPress(testCase)
            press(testCase, testCase.App.RunButton);
            testCase.verifyEqual(testCase.App.StatusLabel.Text, 'Running...');
        end
    end
end
```

### Accessing App Components

The test needs handles to UI components. How you get them depends on the app architecture:

```matlab
% Pattern A: App exposes components as public properties
app = MyApp();
press(testCase, app.RunButton);

% Pattern B: If components are private, make them public for testability.
% App Designer components should be accessible via public properties
% so tests can interact with them directly. Avoid friend-class access
% or testing private implementation details.

% Pattern C: Find components by type/tag from the figure
fig = app.UIFigure;
btns = findobj(fig, 'Type', 'uibutton', 'Text', 'Run');
press(testCase, btns(1));
```

### Verifiable Component Properties

| What to check | Access pattern |
|---------------|---------------|
| Field value | `app.EditField.Value` |
| Label text | `app.Label.Text` |
| Button/component enabled | `app.Button.Enable` |
| Dropdown items | `app.DropDown.Items` |
| Dropdown selection | `app.DropDown.Value` |
| Table data | `app.Table.Data` |
| Panel visibility | `app.Panel.Visible` |
| Plot line data | `findobj(app.UIAxes, 'Type', 'Line')` → `.XData`, `.YData` |
| Image presence | `findobj(app.UIAxes, 'Type', 'Image')` |

### Dialog Handling (R2024b+)

```matlab
function testConfirmSave(testCase)
    % Press a button that triggers a uiconfirm dialog, then accept it
    press(testCase, app.SaveButton);
    chooseDialog(testCase, "uiconfirm", app.UIFigure, "Yes");
    testCase.verifyEqual(app.StatusLabel.Text, 'Saved');
end

function testDismissAlert(testCase)
    % Trigger an alert and dismiss it
    press(testCase, app.ValidateButton);
    dismissDialog(testCase, "uialert", app.UIFigure);
end

% For blocking dialogs, pass the triggering action as a function handle
function testBlockingConfirm(testCase)
    chooseDialog(testCase, "uiconfirm", app.UIFigure, ...
        @() press(testCase, app.DeleteButton), "OK");
end
```

### Testing Async / Long-Running Callbacks

```matlab
function testAsyncAnalysis(testCase)
    press(testCase, app.AnalyzeButton);

    % Wait for callback to complete (poll with timeout)
    maxWait = 10; % seconds
    elapsed = 0;
    while app.StatusLabel.Text ~= "Complete" && elapsed < maxWait
        pause(0.5);
        drawnow;
        elapsed = elapsed + 0.5;
    end

    testCase.verifyEqual(app.StatusLabel.Text, 'Complete', ...
        'Analysis did not complete within timeout');
end
```

## Type-Matching Pitfalls

UI component properties do not always return the types you expect. These mismatches cause `verifyEqual` failures:

| Property | Returns | Wrong comparison | Correct comparison |
|----------|---------|------------------|--------------------|
| `uilabel.Text` | `char` | `verifyEqual(lbl.Text, "Ready")` | `verifyEqual(lbl.Text, 'Ready')` |
| `comp.Enable` | `matlab.lang.OnOffSwitchState` | `verifyEqual(btn.Enable, 'on')` | `verifyEqual(btn.Enable, matlab.lang.OnOffSwitchState.on)` |
| `uidropdown.Value` | `char` or `string` (depends on `Items` type) | — | Cast with `string()` if comparing against string literals |

**Recommended pattern for Enable checks** — define constants to avoid verbose enum names:

```matlab
properties (Constant, Access = private)
    ON = matlab.lang.OnOffSwitchState.on
    OFF = matlab.lang.OnOffSwitchState.off
end

% Then in tests:
testCase.verifyEqual(app.RunButton.Enable, testCase.ON);
```

## Conventions

- Inherit from `matlab.uitest.TestCase`, not `matlab.unittest.TestCase`
- Figures **must be visible** — never set `'Visible', 'off'` on the test figure
- Call `drawnow` after app creation and before the first gesture
- Launch a **fresh app per test** in `TestMethodSetup` to avoid cross-test contamination
- Use `testCase.addTeardown(@delete, app)` immediately after launching the app to ensure cleanup even if the test fails. Prefer this over a separate `TestMethodTeardown` block
- Access components via public properties; use `findobj` as a fallback for private components
- Compare label `.Text` with **char** (`'text'`), not string (`"text"`)
- Compare `.Enable` with `matlab.lang.OnOffSwitchState.on`/`.off`, not `'on'`/`'off'`
- For apps with long callbacks, poll with `pause`/`drawnow` and a timeout — never use a fixed `pause` alone

----

Copyright 2026 The MathWorks, Inc.

----

