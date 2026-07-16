# Explorer / Control Panel Layout

**Primary user task:** Adjust parameters and observe results — user drives computation in real time.

```
┌────────────────┬─────────────────────────────────────────┐
│                │                                         │
│  Controls      │   Main Display                          │
│  ─────────     │   (plot, table, output, or tabbed)      │
│  [Slider]      │                                         │
│  [Dropdown]    │                                         │
│  [Input]       │                                         │
│  [Button]      │                                         │
│                │                                         │
│  (fixed width) │   (fills remaining width)               │
└────────────────┴─────────────────────────────────────────┘
```

**When to choose:** The user controls the computation — they tweak parameters and observe what changes in the output area. The sidebar is constant; the display area updates in response.

**Key rules:**
- Sidebar width is fixed (180–280 px); the display area takes `'1x'` / `1fr`
- Controls stack vertically in the sidebar — one concern per row, clearly labeled
- The display area can itself be tabbed (multiple output views) without changing the archetype
- Horizontal variant (controls at top, output below) works when controls are few and wide

---

## UIFigure app — uigridlayout Skeleton

```matlab
fig = uifigure('Name', 'App');

rootGrid = uigridlayout(fig, [1 2]);
rootGrid.ColumnWidth  = {220, '1x'};
rootGrid.Padding      = [0 0 0 0];
rootGrid.ColumnSpacing = 0;

% ── Sidebar ──────────────────────────────────────────────
sidebar = uipanel(rootGrid);
sidebar.Layout.Column = 1;

sideGrid = uigridlayout(sidebar, [8 1]);
sideGrid.RowHeight    = repmat({'fit'}, 1, 8);
sideGrid.Padding      = [12 12 12 12];
sideGrid.RowSpacing   = 10;

% Controls — add to sideGrid rows 1–N
uilabel(sideGrid, 'Text', 'Parameter A');
sld = uislider(sideGrid, 'Limits', [0 100], 'Value', 50);
sld.ValueChangedFcn = @(src, evt) updateDisplay(src, evt, ax);

uilabel(sideGrid, 'Text', 'Category');
dd = uidropdown(sideGrid, 'Items', {'Option 1', 'Option 2', 'Option 3'});
dd.ValueChangedFcn = @(src, evt) updateDisplay(src, evt, ax);

uibutton(sideGrid, 'Text', 'Run', ...
    'ButtonPushedFcn', @(src, evt) runCompute(src, evt, ax));

% ── Main display ─────────────────────────────────────────
mainPanel = uipanel(rootGrid);
mainPanel.Layout.Column = 2;

mainGrid = uigridlayout(mainPanel, [1 1]);
mainGrid.Padding = [8 8 8 8];
ax = uiaxes(mainGrid);
```

### With optional toolbar above sidebar + display

```matlab
rootGrid = uigridlayout(fig, [2 2]);
rootGrid.RowHeight    = {40, '1x'};
rootGrid.ColumnWidth  = {220, '1x'};
rootGrid.Padding      = [0 0 0 0];
rootGrid.RowSpacing   = 0;
rootGrid.ColumnSpacing = 0;

toolbar = uipanel(rootGrid);
toolbar.Layout.Row    = 1;
toolbar.Layout.Column = [1 2];   % spans both columns

sidebar = uipanel(rootGrid);
sidebar.Layout.Row    = 2;
sidebar.Layout.Column = 1;

mainPanel = uipanel(rootGrid);
mainPanel.Layout.Row    = 2;
mainPanel.Layout.Column = 2;
```

---

## UIHTML/web app — CSS Grid Skeleton

```css
.app {
    display: grid;
    grid-template-columns: 240px 1fr;
    height: 100vh;
}

/* Optional toolbar variant */
.app.with-toolbar {
    grid-template-rows: 40px 1fr;
    grid-template-columns: 240px 1fr;
    grid-template-areas:
        "toolbar toolbar"
        "sidebar main";
}
.toolbar { grid-area: toolbar; }

.sidebar {
    grid-area: sidebar;
    overflow-y: auto;
    border-right: 1px solid var(--border);
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
}

.control-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
}

.control-group label {
    font-size: var(--text-sm);
    color: var(--text-secondary);
    font-weight: var(--fw-semi);
}

.main-area {
    grid-area: main;
    overflow: auto;
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
}
```

---

## Common Variations

| Variation | Change |
|---|---|
| Controls on the right | Swap column order: `grid-template-columns: 1fr 240px` |
| Tabbed output area | Place `uitabgroup` (UIFigure app) or tab component (UIHTML/web app) in the main panel |
| Multiple output panels | Split main area into a 2×1 or 1×2 inner grid |
| Collapsible sidebar | Toggle sidebar width between 0 and 220px; use `uigridlayout` column resize |
| Controls at top (horizontal) | `grid-template-rows: auto 1fr` instead of side-by-side columns |
| Status bar at bottom | Add a 3rd row `{24}` spanning both columns for status messages |

---

## Composition

- **UIFigure app:** `matlab-build-chart` for axes, colororder, all plot types; `references/uifigure/mvvm-guide.md` for binding control values to the display
- **UIHTML/web app:** `references/uihtml/bridge-guide.md` for the MATLAB↔JS bridge; `references/uihtml/mvvm-guide.md` for state binding between controls and chart; `references/uihtml/styling-guide.md` for sidebar and control styling
- **Callbacks:** Use `ValueChangedFcn` not `ValueChangingFcn` for most controls — only use `ValueChangingFcn` for real-time preview sliders where lag is noticeable

----

Copyright 2026 The MathWorks, Inc.

----
