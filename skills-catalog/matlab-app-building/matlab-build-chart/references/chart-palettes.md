# Chart Color Palettes

## Custom Brand Palette via Theme Struct

```matlab
% Set on specific axes
colororder(ax, theme.plotColors);

% Or set on figure (affects all axes)
colororder(fig, theme.plotColors);
```

## Named Palettes (R2023b+)

```matlab
colororder("gem")     % Light theme default (7 colors)
colororder("glow")    % Dark theme default
colororder("sail")    % Cool blue tones
colororder("reef")    % Warm earth tones
colororder("meadow")  % Green/natural tones
colororder("earth")   % Muted earth
colororder("dye")     % Vibrant saturated
```

## Theme-Adaptive Plots with SeriesIndex

For plots that auto-adapt between light/dark without custom colors:

```matlab
fig = uifigure;
ax = uiaxes(fig);
hold(ax, 'on');
p1 = plot(ax, data1);  % SeriesIndex = 1 (auto)
p2 = plot(ax, data2);  % SeriesIndex = 2 (auto)
% When theme switches: gem[1] → glow[1], gem[2] → glow[2] automatically
```

**Important:** Do NOT set line colors explicitly if you want adaptive behavior. `plot(ax, data, 'r')` forces `ColorMode = "manual"`.

## colororder vs colormap

- **`colororder`** — discrete series (lines, bars, scatter groups). Set via palette name or Nx3 matrix.
- **`colormap`** — continuous scalar-to-color mapping (heatmaps, surfaces, contours). Set via `colormap(ax, "parula")` etc.

----

Copyright 2026 The MathWorks, Inc.

----
