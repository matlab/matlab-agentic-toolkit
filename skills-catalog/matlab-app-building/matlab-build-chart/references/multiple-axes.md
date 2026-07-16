# Multiple Axes

Do NOT use `subplot()` — it does not work reliably in uifigure. Two alternatives:

## Option 1: tiledlayout + nexttile (pure plot grids)

```matlab
fig = uifigure;
tl = tiledlayout(fig, 2, 2);
tl.TileSpacing = 'compact';
tl.Padding = 'compact';

ax1 = nexttile(tl);
plot(ax1, x, y1);
title(ax1, 'Signal 1');

ax2 = nexttile(tl);
plot(ax2, x, y2);
title(ax2, 'Signal 2');

% Spanning multiple tiles
ax3 = nexttile(tl, [1 2]);        % span 1 row, 2 columns
plot(ax3, x, y3);
title(ax3, 'Combined');
```

## Arrangement Options

| Syntax | Behavior |
|---|---|
| `tiledlayout(fig, m, n)` | Fixed m-by-n grid |
| `tiledlayout(fig, "flow")` | Auto-reflows tiles to fit figure size (~4:3 aspect) |
| `tiledlayout(fig, "vertical")` | Stack tiles top-to-bottom (R2023a+) |
| `tiledlayout(fig, "horizontal")` | Stack tiles left-to-right (R2023a+) |

**TileSpacing / Padding values:** `"loose"` (default), `"compact"`, `"tight"`, `"none"`

## Shared Titles, Labels, and Linked Axes

```matlab
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
ax1 = nexttile(tl); plot(ax1, x, y1);
ax2 = nexttile(tl); plot(ax2, x, y2);

% Shared title and axis labels on the layout object
title(tl, 'Experiment Results');
xlabel(tl, 'Time (s)');
ylabel(tl, 'Amplitude');

% Synchronized zoom/pan across axes
linkaxes([ax1, ax2], 'x');
```

## Shared Colorbar or Legend in Peripheral Tile

```matlab
ax1 = nexttile(tl); imagesc(ax1, data1);
ax2 = nexttile(tl); imagesc(ax2, data2);
cb = colorbar(ax2);
cb.Layout.Tile = 'east';          % shared colorbar outside grid
```

## Manual Tile Positioning

```matlab
tl = tiledlayout(fig, 'flow');
ax = nexttile(tl);
ax.Layout.Tile = 4;               % place in tile 4
ax.Layout.TileSpan = [2 3];       % span 2 rows, 3 columns
```

## Option 2: Multiple uiaxes in uigridlayout (plots + UI controls)

```matlab
fig = uifigure;
gl = uigridlayout(fig, [2 2]);
gl.RowHeight = {'1x', '1x'};
gl.ColumnWidth = {'1x', '1x'};

ax1 = uiaxes(gl); ax1.Layout.Row = 1; ax1.Layout.Column = 1;
ax2 = uiaxes(gl); ax2.Layout.Row = 1; ax2.Layout.Column = 2;
ax3 = uiaxes(gl); ax3.Layout.Row = 2; ax3.Layout.Column = [1 2];
```

## When to Use Which

- **`tiledlayout`**: pure plot grids — shared titles/labels, compact spacing, linked axes
- **`uigridlayout`**: plots alongside UI controls, or non-uniform layout mixing components and axes

----

Copyright 2026 The MathWorks, Inc.

----
