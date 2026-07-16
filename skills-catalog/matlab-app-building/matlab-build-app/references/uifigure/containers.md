# Containers

## Panels

Group related controls with a titled border:

```matlab
panel = uipanel(gl, 'Title', 'Parameters');
panel.Layout.Row = 1;
panel.Layout.Column = 1;

% Panel needs its own grid for internal layout
panelGrid = uigridlayout(panel, [3 2]);
panelGrid.RowHeight = {'fit', 'fit', 'fit'};
panelGrid.ColumnWidth = {100, '1x'};
```

## Tab Groups

Organize content into switchable tabs:

```matlab
tabGroup = uitabgroup(gl);
tabGroup.Layout.Row = [1 3];
tabGroup.Layout.Column = 2;

tab1 = uitab(tabGroup, 'Title', 'Input');
tab1Grid = uigridlayout(tab1, [2 1]);

tab2 = uitab(tabGroup, 'Title', 'Results');
tab2Grid = uigridlayout(tab2, [1 1]);
```

## Nested Grids

Build complex layouts by nesting grids inside grids:

```matlab
fig = uifigure('Name', 'Nested Layout');
mainGrid = uigridlayout(fig, [1 2]);
mainGrid.ColumnWidth = {200, '1x'};

% Left sidebar
sidebarGrid = uigridlayout(mainGrid, [4 1]);
sidebarGrid.Layout.Row = 1;
sidebarGrid.Layout.Column = 1;
sidebarGrid.RowHeight = {'fit', 'fit', 'fit', '1x'};

% Right content area
contentGrid = uigridlayout(mainGrid, [2 1]);
contentGrid.Layout.Row = 1;
contentGrid.Layout.Column = 2;
contentGrid.RowHeight = {'1x', 'fit'};
```

Every container (panel, tab, nested grid) needs its own `uigridlayout` for internal component placement.

----

Copyright 2026 The MathWorks, Inc.

----
