---
name: matlab-build-app
description: Build MATLAB apps programmatically using uifigure, uigridlayout, UI components, callbacks, and uihtml for web integration. Use when creating GUIs, dashboards, interactive tools, apps with sliders/buttons/dropdowns, or embedding HTML/JavaScript components.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# App Builder

Build MATLAB desktop apps entirely in code using `uifigure` and `uigridlayout`. Since `.mlapp` files are binary and cannot be created or edited as text, all apps are built as class-based `.m` files.

## When to Use

- User asks to create a GUI, app, dashboard, or interactive tool
- User wants buttons, sliders, dropdowns, or other UI controls
- User needs a visual interface for data exploration or parameter tuning
- User wants to embed HTML/CSS/JavaScript components via `uihtml`

## When NOT to Use

- User needs a simple plot or figure without interactive controls (just use `figure` + `plot`)
- User wants to edit an existing `.mlapp` file (binary format — cannot be text-edited)
- User needs a web app deployed to MATLAB Web App Server (use deployment skills)

## Workflow

1. **Define requirements** — What components, what layout, what data flows
2. **Create the app class** — `handle` class with `uifigure`, `uigridlayout`, component properties
3. **Build the layout** — Grid-based, using `'fit'` and `'1x'` for responsive sizing
4. **Add components** — Place in grid cells, wire callbacks
5. **Implement callbacks** — Respond to user interaction, update display
6. **Verify** — Run the app via `evaluate_matlab_code` to confirm it launches and renders correctly

## Key Components

| Component | Constructor | Key callback |
|-----------|------------|-------------|
| Button | `uibutton(parent)` | `ButtonPushedFcn` |
| Edit field (numeric) | `uieditfield(parent, 'numeric')` | `ValueChangedFcn` |
| Edit field (text) | `uieditfield(parent, 'text')` | `ValueChangedFcn` |
| Dropdown | `uidropdown(parent)` | `ValueChangedFcn` |
| Slider | `uislider(parent)` | `ValueChangedFcn` |
| Checkbox | `uicheckbox(parent)` | `ValueChangedFcn` |
| Label | `uilabel(parent)` | — |
| Axes | `uiaxes(parent)` | — |
| Table | `uitable(parent)` | `CellEditCallback` |
| Panel | `uipanel(parent)` | — |
| Tab group | `uitabgroup(parent)` | `SelectionChangedFcn` |
| HTML | `uihtml(parent)` | `DataChangedFcn` |

## Patterns

### Standard App Template

Every app follows this structure: a `handle` class that creates all components in a dedicated method.

```matlab
classdef MyApp < handle
    %MyApp Short description of the app.

    properties (Access = private)
        UIFigure     matlab.ui.Figure
        GridLayout   matlab.ui.container.GridLayout
        InputField   matlab.ui.control.NumericEditField
        RunButton    matlab.ui.control.Button
        ResultLabel  matlab.ui.control.Label
        PlotAxes     matlab.ui.control.UIAxes
    end

    methods (Access = public)
        function app = MyApp()
            createComponents(app);
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Name', 'My App', ...
                'Position', [100 100 640 480]);

            app.GridLayout = uigridlayout(app.UIFigure, [2 2]);
            app.GridLayout.RowHeight = {'fit', '1x'};
            app.GridLayout.ColumnWidth = {'fit', '1x'};

            app.InputField = uieditfield(app.GridLayout, 'numeric', ...
                'Value', 10, ...
                'Limits', [1 100]);
            app.InputField.Layout.Row = 1;
            app.InputField.Layout.Column = 1;

            app.RunButton = uibutton(app.GridLayout, ...
                'Text', 'Run', ...
                'ButtonPushedFcn', @(~,~) runAnalysis(app));
            app.RunButton.Layout.Row = 1;
            app.RunButton.Layout.Column = 2;

            app.PlotAxes = uiaxes(app.GridLayout);
            app.PlotAxes.Layout.Row = 2;
            app.PlotAxes.Layout.Column = [1 2];
            title(app.PlotAxes, 'Output');
            xlabel(app.PlotAxes, 'X');
            ylabel(app.PlotAxes, 'Y');
        end

        function runAnalysis(app)
            n = app.InputField.Value;
            x = linspace(0, 2*pi, n);
            plot(app.PlotAxes, x, sin(x), 'LineWidth', 1.5);
        end
    end
end
```

### Grid Layout Sizing

Use `'fit'` for rows/columns that should size to content and `'1x'` for those that fill remaining space:

```matlab
gl = uigridlayout(fig, [4 3]);
gl.RowHeight   = {'fit', '1x', '1x', 'fit'};   % toolbar, content, content, statusbar
gl.ColumnWidth = {200, '1x', '1x'};             % sidebar(px), main, main
gl.Padding     = [10 10 10 10];
gl.RowSpacing  = 5;
gl.ColumnSpacing = 5;
```

### Spanning Rows and Columns

```matlab
ax = uiaxes(gl);
ax.Layout.Row = [2 3];       % span rows 2-3
ax.Layout.Column = [2 3];    % span columns 2-3
```

### Callback Patterns

```matlab
% Inline — short logic
btn.ButtonPushedFcn = @(~,~) disp("Clicked");

% Method reference — preferred for anything non-trivial
slider.ValueChangedFcn = @(src, event) sliderChanged(app, event);

function sliderChanged(app, event)
    newValue = event.Value;
    previousValue = event.PreviousValue;
    % Update display
    app.ResultLabel.Text = sprintf('Value: %.1f', newValue);
end
```

### Web Components with uihtml

For rich UI elements beyond native MATLAB components, embed HTML/CSS/JavaScript:

```matlab
h = uihtml(gl);
h.HTMLSource = fullfile(pwd, 'components', 'chart.html');

% Send data from MATLAB to JavaScript
h.Data = struct('values', [1 2 3 4 5], ...
    'labels', {{'A', 'B', 'C', 'D', 'E'}});

% Receive data from JavaScript
h.DataChangedFcn = @(src, ~) handleWebEvent(app, src.Data);
```

**HTML side — minimal template:**

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: system-ui; margin: 0; padding: 16px; }
  </style>
</head>
<body>
  <div id="app"></div>
  <script>
    function setup(htmlComponent) {
      htmlComponent.addEventListener("DataChanged", function() {
        var data = htmlComponent.Data;
        document.getElementById('app').textContent = JSON.stringify(data);
      });
    }
    setup(document.querySelector('html-component') || HTMLComponent());
  </script>
</body>
</html>
```

**Data flow:**

| Direction | Mechanism |
|-----------|-----------|
| MATLAB → JS | Set `h.Data = struct(...)` |
| JS → MATLAB | Set `htmlComponent.Data = {...}` in JavaScript → triggers `DataChangedFcn` |

Always use `struct` (not tables or objects) for MATLAB-to-JavaScript data. Use `fullfile` for HTML source paths.

### Multi-Tab App

```matlab
tabGroup = uitabgroup(gl);
tabGroup.Layout.Row = [1 3];
tabGroup.Layout.Column = [1 2];

tab1 = uitab(tabGroup, 'Title', 'Input');
gl1 = uigridlayout(tab1, [3 2]);

tab2 = uitab(tabGroup, 'Title', 'Results');
gl2 = uigridlayout(tab2, [1 1]);
ax = uiaxes(gl2);
```

## Conventions

- Never use the `appdesigner` GUI tool — always write programmatic code in `.m` files
- Use `uigridlayout` for all layout — never use absolute pixel positioning for components
- Name app files with PascalCase: `MyApp.m`, `DashboardApp.m`
- Use `handle` as the base class (or `matlab.apps.AppBase`)
- Keep `createComponents` focused on layout — put logic in separate private methods
- Include a `delete` method that cleans up the figure
- Use `if nargout == 0; clear app; end` in the constructor for clean command-window usage
- Store component handles as private properties with type annotations
- Use `fullfile()` for cross-platform HTML source paths
- Send `struct` data to `uihtml` — JavaScript receives it as a plain object

----

Copyright 2026 The MathWorks, Inc.

----

