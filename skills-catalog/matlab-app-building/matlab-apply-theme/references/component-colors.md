# Component Colors & uistyle

## Component Color Properties Reference

Only set these on components that need brand customization. Leave everything else to the Theme API.

| Component | BackgroundColor | FontColor | ForegroundColor | Notes |
|---|---|---|---|---|
| `uibutton` | Yes | Yes | — | Most common branded component |
| `uilabel` | Yes | Yes | — | Use for status text color |
| `uipanel` | Yes | — | Yes (title text) | ForegroundColor = title color |
| `uitabgroup` / `uitab` | Yes | — | Yes | — |
| `uieditfield` | Yes | Yes | — | Usually leave auto |
| `uidropdown` | Yes | Yes | — | Usually leave auto |
| `uislider` | — | Yes (label) | — | Limited styling |
| `uitable` | Yes | Yes | — | Prefer uistyle for cells |
| `uitextarea` | Yes | Yes | — | Usually leave auto |
| `uicheckbox` | — | Yes | — | — |
| `uiaxes` | Yes (plot bg) | — | — | Usually leave auto |

## Table/Tree Styling with uistyle

Use `uistyle` for conditional formatting in tables, trees, listboxes, and dropdowns (not for general components).

```matlab
% Highlight error rows
s = uistyle('BackgroundColor', theme.error, 'FontColor', theme.onPrimary);
errorRows = find(tableData.Status == "Error");
addStyle(uit, s, 'row', errorRows);

% Bold header column
s2 = uistyle('FontWeight', 'bold');
addStyle(uit, s2, 'column', 1);

% Status icon in cells
s3 = uistyle('Icon', 'success');
addStyle(uit, s3, 'cell', [successRows, repmat(statusCol, numel(successRows), 1)]);
```

Available `uistyle` properties: `BackgroundColor`, `FontColor`, `FontWeight`, `FontAngle`, `FontSize`, `FontName`, `Icon`, `IconAlignment`, `Interpreter`, `HorizontalAlignment`.

**Managing styles:**
- `addStyle(component, style, targetType, targetIndex)` — targetType: `"row"`, `"column"`, `"cell"`, `"node"`, `"item"`
- `removeStyle(component, styleIndex)` — remove by index
- `getStyle(component)` — list applied styles
- Last style applied wins on overlap

----

Copyright 2026 The MathWorks, Inc.

----
