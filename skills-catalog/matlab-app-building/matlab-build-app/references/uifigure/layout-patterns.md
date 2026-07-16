# Common Layout Patterns

## Full-Page Content

```matlab
gl = uigridlayout(fig, [1 1]);
gl.Padding = [0 0 0 0];
% Single component fills the window
```

## Header + Content + Footer

```matlab
gl = uigridlayout(fig, [3 1]);
gl.RowHeight = {'fit', '1x', 'fit'};
% Row 1: toolbar/title
% Row 2: main content (expands)
% Row 3: status bar
```

## Sidebar + Content

```matlab
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {200, '1x'};
% Col 1: sidebar (fixed width)
% Col 2: main content (expands)
```

## Form Layout (Label + Control)

```matlab
gl = uigridlayout(parent, [N 2]);
gl.RowHeight = repmat({'fit'}, 1, N);
gl.ColumnWidth = {120, '1x'};
% Col 1: labels (fixed)
% Col 2: inputs (stretch)
```

## Equal Split

```matlab
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {'1x', '1x'};
% Two equal-width panes
```

## Sidebar + Content Example

```matlab
fig = uifigure('Name', 'Analysis Tool', 'Position', [100 100 900 600]);

mainGrid = uigridlayout(fig, [1 2]);
mainGrid.ColumnWidth = {220, '1x'};
mainGrid.Padding = [0 0 0 0];

% Sidebar
sidePanel = uipanel(mainGrid, 'Title', 'Controls');
sidePanel.Layout.Row = 1;
sidePanel.Layout.Column = 1;

sideGrid = uigridlayout(sidePanel, [5 1]);
sideGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x'};

% Content area
contentGrid = uigridlayout(mainGrid, [2 1]);
contentGrid.Layout.Row = 1;
contentGrid.Layout.Column = 2;
contentGrid.RowHeight = {'1x', 'fit'};

ax = uiaxes(contentGrid);
statusLabel = uilabel(contentGrid, 'Text', 'Ready');
```

----

Copyright 2026 The MathWorks, Inc.

----
