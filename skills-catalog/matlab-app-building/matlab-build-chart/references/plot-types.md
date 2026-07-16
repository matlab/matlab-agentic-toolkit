# Common Plot Types

Always pass `ax` as the first argument. For uiaxes differences from traditional axes, see `references/axes-config.md`.

## Line Plot

```matlab
p = plot(ax, x, y, 'LineWidth', 1.5);
p.Color = [0.2 0.4 0.8];
p.LineStyle = '--';
p.Marker = 'o';
p.MarkerSize = 6;
p.MarkerFaceColor = 'auto';
p.MarkerIndices = 1:10:length(x);  % markers at every 10th point
p.DisplayName = 'Signal A';        % legend label
```

**Multiple series:**
```matlab
hold(ax, 'on');
p1 = plot(ax, x, y1, 'DisplayName', 'Series 1');
p2 = plot(ax, x, y2, 'DisplayName', 'Series 2');
hold(ax, 'off');
legend(ax, 'show');
```

## Scatter Plot

```matlab
s = scatter(ax, x, y, 36, colorVector);  % size=36, color by data
s.MarkerFaceColor = 'flat';              % fill with CData colors
s.MarkerFaceAlpha = 0.6;                 % transparency
s.MarkerEdgeColor = 'none';              % no outline
```

**Per-point sizing:**
```matlab
s = scatter(ax, x, y, sizeVector);  % sizeVector in pt^2
```

## Bar Chart

```matlab
b = bar(ax, categories, values);
b.FaceColor = 'flat';
b.CData = myColorMatrix;  % Nx3 RGB for per-bar coloring
b.EdgeColor = 'none';
b.BarWidth = 0.6;
```

**Grouped bars:**
```matlab
b = bar(ax, groupedData);  % matrix: rows=groups, cols=series
legend(ax, 'A', 'B', 'C');
```

## Histogram

```matlab
h = histogram(ax, data);
h.NumBins = 30;
h.Normalization = 'probability';
h.FaceColor = [0.2 0.4 0.8];
h.FaceAlpha = 0.7;
h.EdgeColor = 'white';
```

## Heatmap

**Parent is figure or panel, NOT uiaxes:**

```matlab
hm = heatmap(panel, xLabels, yLabels, dataMatrix);
hm.Colormap = parula;
hm.ColorLimits = [0 100];
hm.CellLabelFormat = '%0.1f';
hm.GridVisible = 'off';
hm.Title = 'Correlation Matrix';
```

## Surface Plot

```matlab
[X, Y] = meshgrid(-5:0.25:5);
Z = sin(sqrt(X.^2 + Y.^2));

s = surf(ax, X, Y, Z);
s.FaceColor = 'interp';
s.EdgeColor = 'none';
s.FaceAlpha = 0.9;

% Enable 3D rotation
ax.Interactions = [rotateInteraction dataTipInteraction];
```

----

Copyright 2026 The MathWorks, Inc.

----
