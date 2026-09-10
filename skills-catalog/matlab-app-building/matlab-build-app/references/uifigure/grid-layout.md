# Grid Layouts

`uigridlayout` creates a grid layout manager for an app. It positions child components along the rows and columns of an invisible grid that spans the entire figure or a container it is parented to. Use a grid layout if you do not want to position components by setting pixel values in `Position` vectors. Grid layouts are recommended for responsive apps.

## Basic Grid

```matlab
fig = uifigure(Name="Grid Demo");
gl = uigridlayout(fig,RowHeight={"fit","fit","1x"},ColumnWidth={120,"1x"});
```

## Row/Column Sizing Options

| Value | Meaning | Use When |
|---|---|---|
| `'fit'` | Adjust to content size | Labels, buttons, and other text-based components |
| `'1x'` | Variable size; shares remaining space by weight | Main content areas, axes, tables |
| `'2x'` | Variable size; twice the weight of a `'1x'` | Larger content pane in a split |
| `100` | Fixed pixel size | Sidebars, toolbars, known-size elements |
| `0` | Collapsed (hidden) | Dynamically show/hide rows or columns |

Variable-size rows and columns divide the remaining space by relative weight. The weights work together: two `'2x'` columns share the space equally, just as two `'1x'` columns would, while a `'2x'` column gets twice the space of a `'1x'` column in the same grid.

Use `'fit'` for any row or column containing text-based components (especially `uilabel` and `uibutton`). It sizes the row/column to the text, so it stays big enough even when the app is translated to other languages.

## Spacing and Padding

```matlab
gl.Padding = [10 10 10 10];       % [left bottom right top] in pixels
gl.RowSpacing = 5;                 % Gap between rows
gl.ColumnSpacing = 10;             % Gap between columns
```

To put space between components, use `RowSpacing`, `ColumnSpacing`, and `Padding`. Do not insert empty rows or columns purely as spacers.

## Placing Components in Grid Cells

Every component added to a grid gets a `Layout` property:

```matlab
lbl = uilabel(gl,Text="Frequency");
lbl.Layout.Row = 1;
lbl.Layout.Column = 1;

slider = uislider(gl);
slider.Layout.Row = 1;
slider.Layout.Column = 2;
```

If you add components to the grid but do not specify the `Layout` property of the components, then the grid layout manager adds the components from left to right and then top to bottom.

Do not assign multiple components to the same cell. They will stack on top of each other, making some invisible to the user. To group several components in one area, nest a grid there (see Nesting Grids).

## Spanning Multiple Rows/Columns

```matlab
ax = uiaxes(gl);
ax.Layout.Row = [2 4];       % Span rows 2-4; syntax is [start end]
ax.Layout.Column = [1 2];    % Span columns 1-2
```

## Nesting Grids

Nested grids allow you to manage subsets of components. Treat a grid like any other component and create them as needed. A grid can be parented directly to another grid. Do not insert a `uipanel` unless you specifically want its visual frame or title.

```matlab
outerGrid = uigridlayout(fig,ColumnWidth={220,"1x"});

% Nested grid parented directly to the outer grid — no panel wrapper
sideGrid = uigridlayout(outerGrid,RowHeight={"fit","fit","fit"});
sideGrid.Layout.Row = 1;
sideGrid.Layout.Column = 1;
```

## uiaxes in Grid Layouts

An axes can be parented directly to a grid — no panel needed. If an app contains only axes created by `uiaxes`, use `tiledlayout` instead of `uigridlayout`. However, if your app frequently adds or removes rows/columns by changing `RowHeight`/`ColumnWidth`, place the axes in a `uipanel` parented to a grid for better responsiveness.

## Never Mix Grid Layout with Absolute Positioning

Do not use the `Position` property to place children inside a container that is itself in a grid. Mixing `uigridlayout` with absolute positioning produces unpredictable results. Commit to the grid for everything inside it.

## Dynamic Show/Hide

### Collapse a row (limited, fixed rows)

Set a row's height to `0` to hide it and its contents. Set the height to a value other than `0` to show it again. This works best when the grid has a limited number of rows.

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

### Swap content with Visible

To swap whole sections in and out, toggle the `Visible` property of a `uigridlayout`. This is more performant than unparenting and reparenting the grid.

```matlab
settingsGrid.Visible = "off";   % hide the section
settingsGrid.Visible = "on";    % show it again
```

## Performance

Keep the number of components low — every extra component adds to the app's memory footprint and slows it down. In particular:

- Do not insert a `uipanel` between a grid and its child grid or axes unless you need the panel's visual frame or title.
- Avoid creating many potentially-unused rows, columns, or components (for example, when using row/column collapse to show and hide content).

----

Copyright 2026 The MathWorks, Inc.

----
