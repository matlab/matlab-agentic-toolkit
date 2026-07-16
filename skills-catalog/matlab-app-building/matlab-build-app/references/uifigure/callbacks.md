# Callbacks

## ValueChangedFcn vs ValueChangingFcn

| Callback | Fires | Use When |
|---|---|---|
| `ValueChangedFcn` | Once, after user commits value | Heavy computation, data updates |
| `ValueChangingFcn` | Repeatedly, during interaction | Live preview, real-time feedback |

**Prefer `ValueChangedFcn`** unless you need real-time feedback. `ValueChangingFcn` fires many times per second for sliders and knobs.

## Sharing Data Between Callbacks

Three recommended patterns, from simplest to most scalable:

### 1. Nested Functions (simple single-file apps)

Callbacks defined inside the main function share its workspace automatically:

```matlab
function myApp()
    fig = uifigure('Name', 'Demo');
    gl = uigridlayout(fig, [2 1]);
    gl.RowHeight = {'fit', '1x'};

    slider = uislider(gl, 'Limits', [1 100], 'Value', 10);
    ax = uiaxes(gl);

    slider.ValueChangedFcn = @onSliderChanged;
    onSliderChanged();  % Initial plot

    function onSliderChanged(~, ~)
        t = 0:0.001:1;
        plot(ax, t, sin(2*pi*slider.Value*t));
        ax.Title.String = sprintf('%.0f Hz', slider.Value);
    end
end
```

### 2. Callback Input Arguments (explicit dependencies)

Pass only the data each callback needs using cell array syntax:

```matlab
slider.ValueChangedFcn = {@updatePlot, ax, model};

function updatePlot(src, event, ax, model)
    model.frequency = event.Value;
    plot(ax, model.time, sin(2*pi*model.frequency*model.time));
end
```

### 3. UserData Property (multi-component apps)

Store app state on `fig.UserData` — centralized, accessible from any callback via `ancestor`:

```matlab
% During setup
fig.UserData.model = model;
fig.UserData.ax = ax;
fig.UserData.statusLabel = statusLabel;

slider.ValueChangedFcn = @onSliderChanged;

function onSliderChanged(src, event)
    fig = ancestor(src, 'figure', 'toplevel');
    fig.UserData.model.frequency = event.Value;
    plot(fig.UserData.ax, fig.UserData.model.time, ...
         sin(2*pi*fig.UserData.model.frequency*fig.UserData.model.time));
    fig.UserData.statusLabel.Text = sprintf('Freq: %.0f Hz', event.Value);
end
```

**Do NOT use `guidata`** — legacy pattern. Use `UserData` for the same purpose.

## Blocking User Input with waitfor

Pause program execution until a user completes an action:

```matlab
fig = uifigure('Position', [500 500 300 150]);
gl = uigridlayout(fig, [3 1]);

lbl = uilabel(gl, 'Text', 'Enter your name:');
ef = uieditfield(gl);
btn = uibutton(gl, 'Text', 'OK', ...
    'ButtonPushedFcn', @(src, ~) set(src, 'UserData', 'clicked'));

waitfor(btn, 'UserData', 'clicked');
userName = ef.Value;
delete(fig);
```

## Throttling ValueChangingFcn

If you need real-time preview with `ValueChangingFcn`, throttle updates:

```matlab
slider.ValueChangingFcn = @(src, event) onSliderMoving(src, event, ax);

function onSliderMoving(src, event, ax)
    persistent lastUpdate
    now = tic;
    if isempty(lastUpdate) || toc(lastUpdate) > 0.05  % Max 20 fps
        lastUpdate = now;
        ax.Title.String = sprintf('Value: %.1f', event.Value);
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
