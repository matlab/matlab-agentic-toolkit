# Annotations (uifigure-Compatible)

`annotation()` does NOT work in uifigure. Use these alternatives:

## Reference Lines — xline / yline

```matlab
xl = xline(ax, 5.2, '--r', 'Threshold');
xl.LineWidth = 1.5;
xl.LabelVerticalAlignment = 'top';
xl.LabelHorizontalAlignment = 'left';
```

## Reference Regions — xregion / yregion

```matlab
xr = xregion(ax, 3, 7);
xr.FaceColor = [0.9 0.9 0.1];
xr.FaceAlpha = 0.2;
```

`xline`/`yline` default to `Layer = 'top'` (in front of data). `xregion`/`yregion` default to `Layer = 'bottom'` (behind data).

## Text Labels

```matlab
% In data coordinates (moves with zoom/pan)
t = text(ax, xVal, yVal, 'Peak');
t.FontSize = 11;
t.Color = 'red';
t.HorizontalAlignment = 'center';

% In normalized axes coordinates (stays fixed during zoom/pan)
t = text(ax, 0.05, 0.95, 'R² = 0.97', ...
    'Units', 'normalized', ...
    'VerticalAlignment', 'top', ...
    'FontSize', 10, ...
    'BackgroundColor', [1 1 1 0.8]);
```

## Shapes via patch

```matlab
% Highlight rectangle in data coordinates
patch(ax, [x1 x2 x2 x1], [y1 y1 y2 y2], 'yellow', ...
    'FaceAlpha', 0.3, 'EdgeColor', 'black', 'LineStyle', '--');
```

----

Copyright 2026 The MathWorks, Inc.

----
