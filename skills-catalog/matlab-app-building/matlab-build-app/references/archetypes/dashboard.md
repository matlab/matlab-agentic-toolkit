# Dashboard Layout

**Primary user task:** Monitor and compare results at a glance — read-only, data computed in advance.

```
┌──────────────────────────────────────────────────────────┐
│  Title                                       [Filters ▼] │  ← header (fixed height ~56px)
├──────────────┬──────────────┬──────────────┬─────────────┤
│   KPI Card   │   KPI Card   │   KPI Card   │  KPI Card   │  ← KPI row (fixed height ~120px)
├──────────────┴──────────────┼──────────────┴─────────────┤
│                             │                            │
│   Primary Chart             │   Secondary Chart          │  ← chart area (fills space)
│   (2/3 or 1/2 width)       │                            │
│                             │                            │
├─────────────────────────────┴────────────────────────────┤
│   Detail Table (sortable, scrollable)                    │  ← table (fixed or min height)
└──────────────────────────────────────────────────────────┘
```

**When to choose:** The user wants to review a snapshot — sales figures, system health, experiment results. No real-time computation; the data is prepared before the UI opens (or fetched once on load).

**Key rules:**
- 2–4 KPI cards at the top; more than 4 → use a second row or switch to a table
- One primary chart (largest area); 1–2 supporting charts beside or below it
- Detail table is optional — omit if the charts tell the full story
- Filters live in the header bar for dashboards; a side panel would make this an Explorer

---

## UIFigure app — uigridlayout Skeleton

```matlab
fig = uifigure('Name', 'Dashboard', 'Position', [100 100 1200 750]);

% Outer grid: header | KPI row | charts | table
outerGrid = uigridlayout(fig, [4 1]);
outerGrid.RowHeight    = {56, 120, '1x', 180};
outerGrid.Padding      = [0 0 0 0];
outerGrid.RowSpacing   = 0;

% ── Header ──────────────────────────────────────────────
header = uipanel(outerGrid);
header.Layout.Row = 1;
% Add title label and filter dropdowns inside a uigridlayout on header

% ── KPI row ─────────────────────────────────────────────
kpiGrid = uigridlayout(outerGrid, [1 4]);
kpiGrid.Layout.Row   = 2;
kpiGrid.ColumnWidth  = repmat({'1x'}, 1, 4);
kpiGrid.Padding      = [12 12 12 12];
kpiGrid.ColumnSpacing = 12;

for i = 1:4
    card = uipanel(kpiGrid);
    card.Layout.Column = i;
    % Add uilabel elements for value + label + change inside each card
end

% ── Chart section ────────────────────────────────────────
chartGrid = uigridlayout(outerGrid, [1 2]);
chartGrid.Layout.Row  = 3;
chartGrid.ColumnWidth = {'2x', '1x'};
chartGrid.Padding     = [12 12 12 12];
chartGrid.ColumnSpacing = 12;

primaryPanel = uipanel(chartGrid);
primaryPanel.Layout.Column = 1;
primaryGrid = uigridlayout(primaryPanel, [1 1]);
ax1 = uiaxes(primaryGrid);

secondaryPanel = uipanel(chartGrid);
secondaryPanel.Layout.Column = 2;
secondaryGrid = uigridlayout(secondaryPanel, [1 1]);
ax2 = uiaxes(secondaryGrid);

% ── Detail table ─────────────────────────────────────────
tablePanel = uipanel(outerGrid);
tablePanel.Layout.Row = 4;
tableGrid = uigridlayout(tablePanel, [1 1]);
tbl = uitable(tableGrid);
```

---

## UIHTML/web app — CSS Grid Skeleton

```css
.dashboard {
    display: grid;
    grid-template-rows: 56px 120px 1fr 200px;
    grid-template-areas:
        "header"
        "kpis"
        "charts"
        "table";
    height: 100vh;
    background: var(--bg-primary);
    gap: 0;
}

.dashboard-header {
    grid-area: header;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 var(--space-4);
    border-bottom: 1px solid var(--border);
}

.kpi-row {
    grid-area: kpis;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    align-items: stretch;
}

.kpi-card {
    background: var(--bg-card, white);
    border-radius: var(--radius-md);
    padding: var(--space-4);
    box-shadow: var(--shadow-xs);
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
}

.chart-section {
    grid-area: charts;
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: var(--space-3);
    padding: 0 var(--space-4) var(--space-3);
    min-height: 0;  /* allow grid children to shrink */
}

.chart-panel {
    background: var(--bg-card, white);
    border-radius: var(--radius-md);
    padding: var(--space-4);
    box-shadow: var(--shadow-xs);
    min-height: 0;
}

.detail-table {
    grid-area: table;
    background: var(--bg-card, white);
    border-top: 1px solid var(--border);
    overflow-y: auto;
    padding: var(--space-3) var(--space-4);
}
```

---

## Common Variations

| Variation | Change |
|---|---|
| No detail table | Remove row 4; set `grid-template-rows: 56px 120px 1fr` |
| 3 equal charts | `grid-template-columns: 1fr 1fr 1fr` in chart section |
| Full-width primary + 2 small side charts | Nest a 2-row grid in the secondary column |
| Sidebar filters (complex filter panel) | Switch to Explorer archetype with a filter sidebar |
| Responsive KPI cards | `grid-template-columns: repeat(auto-fit, minmax(180px, 1fr))` |

---

## Composition

- **UIFigure app:** `matlab-build-chart` for axes setup, colororder, and chart types
- **UIHTML/web app:** `references/uihtml/charting-guide.md` for Chart.js integration (line, bar, doughnut); `references/uihtml/styling-guide.md` for tokens
- **Shared:** Filter logic is app-specific; keep it in a dedicated function/module, not in the chart setup

----

Copyright 2026 The MathWorks, Inc.

----
