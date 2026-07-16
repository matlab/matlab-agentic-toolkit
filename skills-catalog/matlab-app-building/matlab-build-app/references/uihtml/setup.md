# Setup Guide

Comprehensive setup reference for the MATLAB and JavaScript sides of a uihtml app, plus hybrid layout patterns.

## MATLAB: Creating the uihtml Component

### Full-Figure uihtml (most common)

Use a 1×1 grid with zero padding to fill the entire figure:

```matlab
function app()
    fig = uifigure('Name', 'My App', 'Position', [100 100 800 600]);
    gl = uigridlayout(fig, [1 1]);
    gl.Padding = [0 0 0 0];

    h = uihtml(gl);
    h.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'app.html');
    h.HTMLEventReceivedFcn = @(src, event) handleEvent(src, event);
end
```

**Always use `fullfile(fileparts(mfilename('fullpath')), ...)` to resolve the HTML path.** This ensures the path is correct regardless of the current working directory when the function is called.

### Partial-Figure uihtml

To place uihtml in one region of a multi-component figure:

```matlab
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {'1x', 300};

h = uihtml(gl);
h.Layout.Column = 1;
h.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'app.html');
h.HTMLEventReceivedFcn = @(src, event) handleEvent(src, event);
```

### Passing Initial Data

Set `h.Data` after assigning `HTMLSource`. The JS side reads it in the `DataChanged` listener:

```matlab
h.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'app.html');
h.Data = struct('config', struct('maxPoints', 100, 'unit', 'Hz'));
```

## JavaScript: The setup() Function

Every uihtml HTML file MUST implement a global `setup(htmlComponent)` function. uihtml calls it automatically once the component is ready.

```javascript
function setup(htmlComponent) {
    // 1. Store reference globally for use in other functions
    window.htmlComponent = htmlComponent;

    // 2. Register DataChanged listener if using h.Data
    htmlComponent.addEventListener('DataChanged', function(event) {
        const data = htmlComponent.Data;
        initializeUI(data);
    });

    // 3. Register listeners for custom events from MATLAB
    htmlComponent.addEventListener('resultReady', function(event) {
        displayResult(event.Data);
    });

    // 4. Always register an Error listener
    htmlComponent.addEventListener('error', function(event) {
        console.error('MATLAB error:', event.Data);
        showUserError(event.Data);
    });

    // 5. Trigger initial data load if needed
    requestInitialData();
}
```

**Rules:**
- The function must be named exactly `setup` and be in the global scope (not inside a module)
- If using ES modules, assign it explicitly: `window.setup = function(htmlComponent) { ... }`
- All `addEventListener` calls must happen inside `setup()` or after it has been called

## Hybrid Layout: uihtml + Native MATLAB Components

A uihtml component can coexist with native MATLAB UI components in the same figure:

```matlab
function hybridApp()
    fig = uifigure('Name', 'Hybrid App', 'Position', [100 100 900 600]);
    gl = uigridlayout(fig, [2 1]);
    gl.RowHeight = {'1x', 200};
    gl.RowSpacing = 0;
    gl.Padding = [0 0 0 0];

    % Web frontend in the top area
    h = uihtml(gl);
    h.Layout.Row = 1;
    h.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'controls.html');
    h.HTMLEventReceivedFcn = @(src, event) handleEvent(src, event, ax);

    % MATLAB axes in the bottom area
    ax = uiaxes(gl);
    ax.Layout.Row = 2;
    title(ax, 'MATLAB Plot');
    grid(ax, 'on');
end

function handleEvent(src, event, ax)
    try
        switch event.HTMLEventName
            case 'updatePlot'
                x = 0:0.01:2*pi;
                y = sin(event.HTMLEventData.freq * x);
                plot(ax, x, y, 'LineWidth', 1.5);
        end
    catch ME
        sendEventToHTMLSource(src, 'error', ME.message);
    end
end
```

**When to use hybrid layout:** web controls are better for complex forms or styled widgets; MATLAB axes are needed for full MATLAB graphics capability. Pass the `ax` handle to the event handler via a closure or `fig.UserData`.

----

Copyright 2026 The MathWorks, Inc.

----
