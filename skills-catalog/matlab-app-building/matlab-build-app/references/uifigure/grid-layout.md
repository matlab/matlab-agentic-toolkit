# Grid Layouts

`uigridlayout` is the foundation of responsive uifigure apps. It sizes and positions child components automatically — no pixel math needed.

## Basic Grid

```matlab
fig = uifigure('Name', 'Grid Demo');
gl = uigridlayout(fig, [3 2]);
gl.RowHeight = {'fit', 'fit', '1x'};
gl.ColumnWidth = {120, '1x'};
```

## Row/Column Sizing Options

| Value | Meaning | Use When |
|---|---|---|
| `'fit'` | Shrink to content size | Labels, buttons, fixed controls |
| `'1x'` | Fill remaining space equally | Main content areas, axes, tables |
| `'2x'` | Fill with 2x weight | Larger content pane in a split |
| `100` | Fixed pixel size | Sidebars, toolbars, known-size elements |
| `0` | Collapsed (hidden) | Dynamically show/hide rows or columns |

## Spacing and Padding

```matlab
gl.Padding = [10 10 10 10];       % [left bottom right top] in pixels
gl.RowSpacing = 5;                 % Gap between rows
gl.ColumnSpacing = 10;             % Gap between columns
```

## Placing Components in Grid Cells

Every component added to a grid gets a `Layout` property:

```matlab
lbl = uilabel(gl, 'Text', 'Frequency:');
lbl.Layout.Row = 1;
lbl.Layout.Column = 1;

slider = uislider(gl);
slider.Layout.Row = 1;
slider.Layout.Column = 2;
```

## Spanning Multiple Rows/Columns

```matlab
ax = uiaxes(gl);
ax.Layout.Row = [2 3];       % Span rows 2-3
ax.Layout.Column = [1 2];    % Span columns 1-2
```

## Dynamic Show/Hide with Row Collapse

Toggle visibility of a settings panel by collapsing its row:

```matlab
gl.RowHeight = {'fit', 100, '1x'};  % Row 2 = settings panel

function toggleSettings(gl, visible)
    if visible
        gl.RowHeight{2} = 100;
    else
        gl.RowHeight{2} = 0;
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
