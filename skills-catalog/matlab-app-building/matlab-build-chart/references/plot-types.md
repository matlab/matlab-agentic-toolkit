 # Common Plot Types

For uiaxes differences from traditional axes, see `references/axes-config.md`.

## General Rules

1. **Axes first:** Always pass `ax` as the first argument to any plotting function.
2. **Store the handle:** Assign the output to a variable (e.g., `p = plot(ax, ...)`).
3. **Do not hard-code colors.** Hard-coded RGB values bypass the theming system. To change colors, use `colororder(ax, newColors)`. To match colors across charts, set their `SeriesIndex` to the same value.
4. **Multiple series:** Prefer matrix or table syntax over `hold on` — many charting functions accept a matrix (columns = series) or table input directly, producing more concise code.
5. **Legend:** Use `legend(ax, 'Series 1', 'Series 2')` with explicit labels. Do not use `legend('show')` or `legend('on')` — these are outdated syntaxes.

## Type-Specific Notes

### Line

- `MarkerIndices` controls which points show markers (line-only property):
  ```matlab
  p = plot(ax, x, y, 'Marker', 'o');
  p.MarkerIndices = 1:10:length(x);
  ```

### Scatter / Bar — Per-Element Coloring

- Both use `FaceColor = 'flat'` + `CData`, but the shape differs:
  ```matlab
  % Scatter: CData is a color vector (Nx1) or Nx3 RGB
  s = scatter(ax, x, y, 36, colorVector);
  s.MarkerFaceColor = 'flat';

  % Bar: CData is an Nx3 RGB matrix (one row per bar)
  b = bar(ax, categories, values);
  b.FaceColor = 'flat';
  b.CData = myColorMatrix;
  ```

### Bar — Labels

- Bar charts support labeling individual bars via built-in properties:
  ```matlab
  b = bar(ax, categories, values);
  b.Labels = string(values);
  b.LabelLocation = 'end-outside';  % 'end-outside' | 'end-inside'
  ```

### Histogram

- Use `'probability'` for normalization (not `'normalized'`, which does not exist):
  ```matlab
  h = histogram(ax, data);
  h.Normalization = 'probability';
  ```

### Heatmap

- **Parent must be figure or panel, NOT uiaxes.** Heatmap is a chart object that creates its own axes:
  ```matlab
  hm = heatmap(panel, xLabels, yLabels, dataMatrix);
  ```

### Surface

- 3D axes get default interactions (rotate, zoom, pan) automatically. To restrict or customize interactions, set `Interactions` and `InteractionOptions` on the axes:
  ```matlab
  s = surf(ax, X, Y, Z);
  s.FaceColor = 'interp';
  s.EdgeColor = 'none';

  % Limit interactions to rotate and data tip only
  ax.Interactions = [rotateInteraction dataTipInteraction];
  ```

----

Copyright 2026 The MathWorks, Inc.

----
