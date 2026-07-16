# Axes Configuration

## uiaxes vs Traditional axes

| Feature | Traditional `axes` | `uiaxes` |
|---|---|---|
| `gcf`/`gca` | Work | Don't work (`HandleVisibility = 'off'`) |
| `annotation()` | Full support | Not supported |
| `ginput()` | Works | Not supported |
| `ButtonDownFcn` on axes | Works | Unreliable — use on plot objects |
| `FontUnits` default | `'points'` | `'pixels'` |
| `NextPlot` default | `'replace'` | `'replacechildren'` |
| Export | `saveas`, `print` | `exportgraphics()`, `exportapp()` |
| Heatmap parent | `axes` or `figure` | Must use `figure`/`panel`, not `uiaxes` |

## Creating uiaxes

```matlab
fig = uifigure;
gl = uigridlayout(fig, [1 1]);
ax = uiaxes(gl);
```

Always pass axes as the first argument to plot functions:
```matlab
p = plot(ax, x, y);
s = scatter(ax, x, y);
b = bar(ax, categories, vals);
```

## Labels, Title, Grid

```matlab
ax.Title.String = 'Signal Analysis';
ax.Subtitle.String = 'Filtered output';    % R2020b+
ax.XLabel.String = 'Time (s)';
ax.YLabel.String = 'Amplitude (V)';

grid(ax, 'on');
ax.GridLineStyle = '--';
ax.GridAlpha = 0.3;
ax.Layer = 'top';          % grid on top of data
ax.XMinorGrid = 'on';
```

## Limits and Scale

```matlab
xlim(ax, [0 10]);
ylim(ax, [-1 1]);
ax.YScale = 'log';
ax.XDir = 'reverse';
ax.YLimitMethod = 'tight';  % no padding beyond data range
```

## Ticks

```matlab
ax.XTick = 0:2:10;
ax.XTickLabel = {'0s','2s','4s','6s','8s','10s'};
ax.XTickLabelRotation = 45;
ax.YAxis.Exponent = 0;      % prevent scientific notation
ax.XMinorTick = 'on';
ax.TickDir = 'out';
```

## Font and Appearance

```matlab
ax.FontSize = 12;
ax.FontName = 'Arial';
ax.TitleFontSizeMultiplier = 1.3;
ax.Box = 'on';
ax.DataAspectRatio = [1 1 1];      % equal axes
ax.PlotBoxAspectRatio = [4 3 1];   % 4:3 plot area
```

## Legend

```matlab
lg = legend(ax, 'show');
lg.Location = 'northwest';
lg.FontSize = 10;
lg.Box = 'off';
lg.NumColumns = 2;
```

## Exporting Graphics

`saveas`/`print` do NOT work with uifigure. Use:

```matlab
exportgraphics(ax, 'plot.png', 'Resolution', 300);
exportgraphics(ax, 'plot.pdf', 'ContentType', 'vector');
exportapp(fig, 'app_screenshot.png');
```

----

Copyright 2026 The MathWorks, Inc.

----
