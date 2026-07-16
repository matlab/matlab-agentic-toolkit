# Canvas / Workspace Layout

**Primary user task:** Create, inspect, edit, or navigate a large spatial or visual artifact — the central area dominates.

```
┌─────────────────────────────────────────────────────────┐
│  [File ▼]  [Edit ▼]  [View ▼]  [Tool A] [Tool B] [▶Run]│  ← toolstrip (fixed ~36px)
├───────────┬─────────────────────────────┬───────────────┤
│           │                             │               │
│  Left     │   Canvas / Main Area        │  Properties   │
│  Sidebar  │   (fills remaining space)   │  Panel        │
│  (files,  │                             │  (optional,   │
│  layers,  │   e.g. uiaxes, custom draw  │  fixed width) │
│  tree)    │   area, image, map          │               │
│           │                             │               │
└───────────┴─────────────────────────────┴───────────────┘
```

**When to choose:** The app IS the central artifact — a figure the user interacts with directly, a spatial editor, a map, an image annotator, or a MATLAB plot that is the product, not just output of controls. The surrounding chrome (toolstrip, sidebars, properties) serves the canvas; the canvas is not a panel inside something else.

**Key rules:**
- The canvas column/row takes all remaining space (`'1x'` / `1fr`) — sidebars and toolstrip are fixed
- Toolstrip height is ~36px; sidebar widths are 160–240px; properties panels are 200–280px
- NEVER put the canvas in a scroll container — it should fill and clip, not grow past the viewport
- Both sidebars and the properties panel are optional — use only what the content requires
- If the toolstrip has many tool groups, add separators (`uilabel('Text','|')` in UIFigure app) between groups

---

## UIFigure app — uigridlayout Skeleton

```matlab
fig = uifigure('Name', 'Workspace');

rootGrid = uigridlayout(fig, [2 3]);
rootGrid.RowHeight    = {36, '1x'};
rootGrid.ColumnWidth  = {180, '1x', 220};
rootGrid.Padding      = [0 0 0 0];
rootGrid.RowSpacing   = 0;
rootGrid.ColumnSpacing = 0;

% ── Toolstrip — spans all 3 columns ──────────────────────
toolstrip = uipanel(rootGrid);
toolstrip.Layout.Row    = 1;
toolstrip.Layout.Column = [1 3];
toolstrip.BorderType    = 'none';

toolGrid = uigridlayout(toolstrip, [1 8]);
toolGrid.ColumnWidth = repmat({'fit'}, 1, 8);
toolGrid.Padding     = [4 2 4 2];
toolGrid.ColumnSpacing = 4;

uibutton(toolGrid, 'Text', 'Open',  'Layout', struct('Column', 1));
uibutton(toolGrid, 'Text', 'Save',  'Layout', struct('Column', 2));
% separator
uilabel(toolGrid, 'Text', '│', 'FontColor', [0.7 0.7 0.7]).Layout.Column = 3;
uibutton(toolGrid, 'Text', 'Run',   'Layout', struct('Column', 4));
% ... more tools

% ── Left sidebar ─────────────────────────────────────────
leftPanel = uipanel(rootGrid);
leftPanel.Layout.Row    = 2;
leftPanel.Layout.Column = 1;
leftPanel.BorderType    = 'line';

leftGrid = uigridlayout(leftPanel, [1 1]);
% e.g. a uitree for file browser or layer list
tree = uitree(leftGrid, 'checkbox');

% ── Canvas (central area) ─────────────────────────────────
canvasPanel = uipanel(rootGrid);
canvasPanel.Layout.Row    = 2;
canvasPanel.Layout.Column = 2;
canvasPanel.BorderType    = 'none';

canvasGrid = uigridlayout(canvasPanel, [1 1]);
canvasGrid.Padding = [0 0 0 0];
ax = uiaxes(canvasGrid);
ax.XTick = [];
ax.YTick = [];
ax.Box   = 'on';
% For a true pixel canvas: use a uiimage or custom drawn axes

% ── Properties panel ─────────────────────────────────────
propsPanel = uipanel(rootGrid);
propsPanel.Layout.Row    = 2;
propsPanel.Layout.Column = 3;
propsPanel.BorderType    = 'line';

propsGrid = uigridlayout(propsPanel, [10 2]);
propsGrid.RowHeight   = repmat({'fit'}, 1, 10);
propsGrid.ColumnWidth = {'fit', '1x'};
propsGrid.Padding     = [8 8 8 8];
% Add property label + value pairs
```

### Minimal canvas (toolstrip + central only)

```matlab
fig = uifigure('Name', 'Viewer');

rootGrid = uigridlayout(fig, [2 1]);
rootGrid.RowHeight  = {36, '1x'};
rootGrid.Padding    = [0 0 0 0];
rootGrid.RowSpacing = 0;

toolstrip = uipanel(rootGrid);
toolstrip.Layout.Row = 1;

canvasPanel = uipanel(rootGrid);
canvasPanel.Layout.Row = 2;
canvasGrid = uigridlayout(canvasPanel, [1 1]);
canvasGrid.Padding = [0 0 0 0];
ax = uiaxes(canvasGrid);
```

---

## UIHTML/web app — CSS Grid Skeleton

```css
.workspace {
    display: grid;
    grid-template-rows: 36px 1fr;
    grid-template-columns: 180px 1fr 240px;
    grid-template-areas:
        "toolstrip toolstrip toolstrip"
        "sidebar   canvas    props";
    height: 100vh;
    overflow: hidden;  /* prevent canvas from causing page scroll */
}

.toolstrip {
    grid-area: toolstrip;
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: 0 var(--space-3);
    background: var(--toolstrip-bg, var(--bg-secondary));
    border-bottom: 1px solid var(--toolstrip-border, var(--border));
}

.toolstrip-separator {
    width: 1px;
    height: 20px;
    background: var(--border);
    margin: 0 var(--space-2);
}

.sidebar {
    grid-area: sidebar;
    overflow-y: auto;
    border-right: 1px solid var(--border);
}

.canvas-area {
    grid-area: canvas;
    position: relative;
    overflow: hidden;   /* clip content to bounds */
    background: var(--bg-canvas, var(--bg-primary));
}

/* For an HTML canvas or SVG workspace */
.canvas-area canvas,
.canvas-area svg {
    display: block;
    width: 100%;
    height: 100%;
}

.props-panel {
    grid-area: props;
    overflow-y: auto;
    border-left: 1px solid var(--border);
    padding: var(--space-3);
}

/* Without left sidebar */
.workspace.no-sidebar {
    grid-template-columns: 1fr 240px;
    grid-template-areas:
        "toolstrip toolstrip"
        "canvas    props";
}

/* Without properties panel */
.workspace.no-props {
    grid-template-columns: 180px 1fr;
    grid-template-areas:
        "toolstrip toolstrip"
        "sidebar   canvas";
}

/* Minimal: just toolstrip + canvas */
.workspace.minimal {
    grid-template-columns: 1fr;
    grid-template-areas:
        "toolstrip"
        "canvas";
}
```

---

## Common Variations

| Variation | Change |
|---|---|
| No left sidebar | Omit left column; canvas starts at column 1 (or use `.no-sidebar` variant) |
| No properties panel | Omit right column; canvas fills to right edge |
| Floating toolbar (overlay) | Position toolstrip absolutely over the canvas; reduce root grid to 1 row |
| Status bar at bottom | Add a 3rd row `{24px}` spanning all columns for zoom level, cursor position, etc. |
| Resizable panels | UIHTML app: use CSS resize handle + JS drag; UIFigure app: there is no built-in drag resize in uigridlayout — use a button to toggle sidebar visibility instead |
| Tool palette (icon grid) | Left sidebar as a compact 2-column icon grid for drawing tools |

---

## Composition

- **UIFigure app:** `matlab-build-chart` for the central `uiaxes` — axes config, interaction (ButtonDownFcn, datatip), and all plot rendering; `references/uifigure/mvvm-guide.md` for selection state and tool state (active tool, selected object, properties)
- **UIHTML/web app:** `references/uihtml/bridge-guide.md` if the canvas is a custom JS component inside MATLAB; `references/uihtml/mvvm-guide.md` for selection/tool state management; `references/uihtml/styling-guide.md` for the toolstrip and panel chrome
- **Toolstrip guidance:** MATLAB's built-in `uitoolbar` is for figures, not uifigure — build toolstrip chrome with `uigridlayout` + `uibutton` (UIFigure app) or CSS tokens (UIHTML/web app)

----

Copyright 2026 The MathWorks, Inc.

----
