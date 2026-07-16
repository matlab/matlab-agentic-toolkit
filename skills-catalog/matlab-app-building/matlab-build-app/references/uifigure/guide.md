# MATLAB UIFigure Builder

Build the UI layer of programmatic uifigure apps using grid layouts, containers, interactive controls, and callbacks.

## Critical Rules

- MUST use `uigridlayout` for all layout — NEVER use absolute `Position` or `SizeChangedFcn`
- MUST create the grid layout immediately after the figure, before adding components
- MUST place components into grid cells using `Layout.Row` and `Layout.Column`
- MUST use `arguments` blocks for any function that accepts user-configurable parameters
- NEVER use the `figure()` function — always use `uifigure()`
- NEVER set component `Position` properties inside a grid layout
- ALWAYS clean up timers and listeners in a `CloseRequestFcn` callback
- PREFER `ValueChangedFcn` over `ValueChangingFcn` unless real-time preview needed

## Quick Start

```matlab
function quickStartApp()
    fig = uifigure('Name', 'Quick Start', 'Position', [100 100 700 500]);

    gl = uigridlayout(fig, [2 2]);
    gl.RowHeight = {'fit', '1x'};
    gl.ColumnWidth = {200, '1x'};

    % Controls
    lbl = uilabel(gl, 'Text', 'Frequency (Hz):');
    lbl.Layout.Row = 1;
    lbl.Layout.Column = 1;

    slider = uislider(gl, 'Limits', [1 50], 'Value', 5);
    slider.Layout.Row = 1;
    slider.Layout.Column = 2;

    % Plot
    ax = uiaxes(gl);
    ax.Layout.Row = 2;
    ax.Layout.Column = [1 2];

    % Wire callback
    slider.ValueChangedFcn = @(~,~) updatePlot();
    updatePlot();

    function updatePlot()
        t = 0:0.001:1;
        plot(ax, t, sin(2*pi*slider.Value*t), 'LineWidth', 1.5);
        ax.Title.String = sprintf('%.0f Hz Sine', slider.Value);
        ax.XLabel.String = 'Time (s)';
        grid(ax, 'on');
    end
end
```

## Complete Example: Sidebar App

```matlab
function app = sidebarApp()
    fig = uifigure('Name', 'Analysis Tool', 'Position', [100 100 900 600]);

    % Main split: sidebar | content
    mainGrid = uigridlayout(fig, [1 2]);
    mainGrid.ColumnWidth = {220, '1x'};
    mainGrid.Padding = [0 0 0 0];

    % --- Sidebar ---
    sidePanel = uipanel(mainGrid, 'Title', 'Controls');
    sideGrid = uigridlayout(sidePanel, [6 1]);
    sideGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', '1x'};

    uilabel(sideGrid, 'Text', 'Signal Type:');
    typeDD = uidropdown(sideGrid, 'Items', {'Sine', 'Square', 'Sawtooth'});

    uilabel(sideGrid, 'Text', 'Frequency (Hz):');
    freqSlider = uislider(sideGrid, 'Limits', [1 100], 'Value', 10);

    uibutton(sideGrid, 'Text', 'Reset', ...
        'ButtonPushedFcn', @(~,~) resetControls());

    % --- Content ---
    contentGrid = uigridlayout(mainGrid, [2 1]);
    contentGrid.Layout.Column = 2;
    contentGrid.RowHeight = {'1x', 'fit'};

    ax = uiaxes(contentGrid);
    grid(ax, 'on');
    statusLabel = uilabel(contentGrid, 'Text', 'Ready');

    % --- Callbacks ---
    typeDD.ValueChangedFcn = @(~,~) updatePlot();
    freqSlider.ValueChangedFcn = @(~,~) updatePlot();
    updatePlot();

    app.figure = fig;

    function updatePlot()
        t = 0:0.001:1;
        f = freqSlider.Value;
        switch typeDD.Value
            case 'Sine',     y = sin(2*pi*f*t);
            case 'Square',   y = square(2*pi*f*t);
            case 'Sawtooth', y = sawtooth(2*pi*f*t);
            otherwise,       y = zeros(size(t));
        end
        plot(ax, t, y, 'LineWidth', 1.5);
        ax.Title.String = sprintf('%s at %.0f Hz', typeDD.Value, f);
        ax.XLabel.String = 'Time (s)';
        ax.YLabel.String = 'Amplitude';
        statusLabel.Text = sprintf('Plotted %s, f=%.0f Hz', typeDD.Value, f);
    end

    function resetControls()
        typeDD.Value = 'Sine';
        freqSlider.Value = 10;
        updatePlot();
    end
end
```

## Implementation Checklist

### App Building
- [ ] Figure created with `uifigure` (not `figure`)
- [ ] Top-level `uigridlayout` added immediately after figure
- [ ] All components placed via `Layout.Row` and `Layout.Column`
- [ ] Row heights use `'fit'` for controls, `'1x'` for content
- [ ] Containers have their own nested grids
- [ ] Callbacks use `ValueChangedFcn` unless real-time needed
- [ ] `CloseRequestFcn` cleans up timers and listeners
- [ ] App resizes correctly

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Components overlap or don't resize | Using `Position` instead of grid | Place all components in a `uigridlayout` |
| Controls stretch vertically | Row height is `'1x'` | Use `'fit'` for rows containing controls |
| UI freezes during computation | Blocking the main thread | Use `parfeval(backgroundPool, ...)` |
| Slider sends too many events | Using `ValueChangingFcn` | Switch to `ValueChangedFcn` or throttle |
| `uistyle` not applying | Wrong target type or index | Check `addStyle` targetType matches component |
| Table updates are slow | Updating columns one at a time | Batch: build new table, assign once |

## References

| Topic | File | Description |
|-------|------|-------------|
| Grid layout | `grid-layout.md` | Row/col sizing, spacing, placement, spanning, collapse |
| Containers | `containers.md` | Panels, tab groups, nested grids |
| Components | `components.md` | Controls and display component reference tables |
| Callbacks | `callbacks.md` | ValueChanged vs Changing, data-sharing patterns, waitfor |
| Layout patterns | `layout-patterns.md` | Full-page, header/footer, sidebar, form, equal-split recipes |

----

Copyright 2026 The MathWorks, Inc.

----
