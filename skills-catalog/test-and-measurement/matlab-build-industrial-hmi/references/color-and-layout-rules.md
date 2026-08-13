# Color and Layout Rules

The single load-bearing principle: **color means exception**. The dashboard is mostly gray. Operators learn to ignore the gray, so anything not gray earns immediate attention.

## Gray-field palette

| Role | RGB | Hex | Notes |
|------|-----|-----|-------|
| Page background | `[0.78 0.78 0.78]` | `#C7C7C7` | The screen baseline. 80%+ of pixels should be this. |
| Panel / card background | `[0.86 0.86 0.86]` | `#DBDBDB` | Slightly lighter than page; defines visual groups without lines. |
| Command button / control face | `[0.86 0.86 0.86]` | `#DBDBDB` | Buttons, spinners, switches — neutral chrome. **Never** green Start / red Stop; differentiate by label. See "Command buttons and controls are neutral". |
| Normal-state widget | `[0.5 0.5 0.5]` | `#808080` | Gauge normal band, lamp idle, badge default. |
| Primary text / numerics | `[0.10 0.10 0.10]` | `#1A1A1A` | High-contrast on gray background. |
| Secondary text / labels | `[0.30 0.30 0.30]` | `#4D4D4D` | Range labels, units, metadata. |
| Critical alarm | `[0.85 0   0  ]` | `#D90000` | Red. HH/LL bands, critical banner, fault state. |
| Warning | `[1    0.7 0  ]` | `#FFB300` | Amber. H/L bands, advisory. |
| Communication / info | `[0.4  0.6 1.0]` | `#6699FF` | **Blue**. Connection lamp, data quality, advisory severity. |
| Confirmed-good (sparingly) | `[0   0.6 0  ]` | `#009900` | Green. Reserved for "operator must verify yes this is OK" — not for "it's running" or "connected". |
| Stale / uncertain | `[0.6  0.2 0.7]` | `#9933B3` | Magenta/purple. Subscription lost, data age exceeded. |

### Application rules

- **Never use color as the sole differentiator.** Always pair with text or shape (lamp + label, badge with text, threshold line + dashed style).
- **80%+ of the screen is gray.** If everything is green when "all good", nothing stands out when something goes red.
- **Alarm color belongs to the source widget**, not a separate alarm widget. Color the gauge band, the table row, the trend trace highlight — not a popup.
- **At most 5 saturated-color elements on screen at once.** If more nodes go critical simultaneously, the banner counts as one and the source widgets share attention.
- **Connection state is BLUE.** Green is reserved for "operator must verify yes this is actively OK" — a process state, not a comms state.

## Command buttons and controls are neutral

Push buttons (Start, Stop, Reset, E-Stop), spinners, switches, and dropdowns are **chrome, not state** — they are present on the screen at all times regardless of what the process is doing, so they carry **no** alarm or status meaning and must stay neutral widget gray (leave the default button face, or `[0.86 0.86 0.86]`).

- **Never a green Start / red Stop.** This is the single most common reflexive violation (traffic-light / play-button priors). Green `[0 0.6 0]` and red `[0.85 0 0]` are the two *exception* colors — spending them on always-visible buttons means when a value actually goes critical, the real red alarm no longer stands out against a screen that already has a red button. It also mis-signals: a red Stop button reads as "Stop is in an alarm state," which is meaningless.
- **Differentiate controls by their label**, position, and grouping — `START` / `STOP` / `E-STOP` text — not by color.
- **Run/stopped state is a separate indicator.** If the operator needs to see whether the pump is running, show it on a `uilamp` + label or a status badge next to the control, not by coloring the button. The button says *what pressing it does*; the lamp says *what the equipment is doing*.
- **E-Stop is the one allowed exception to a colored control**, and only as a physical-affordance convention: a red E-Stop *may* use red because it mirrors the physical mushroom button operators are trained on. Even then, prefer a distinct shape/size and a confirm-both-engage-and-release dialog (see `write-safeguards-reference.md`) over relying on the color. If in doubt, keep it gray.

This applies identically whether the app is built programmatically or serialized to a real App Designer file via `matlab-build-app` — see `app-designer-handoff.md` for the verb recipe.

## Dark-theme defense

On a dark-themed MATLAB desktop, child widgets inherit dark defaults from the OS/MATLAB theme even when you set the figure colour explicitly. Operators end up with dark text on dark widgets inside a (correctly) gray-field figure — unreadable, and a clash with the gray-field philosophy.

The two-line fix is **both** of these — neither alone is enough:

```matlab
fig = uifigure( ...
    'Color', [0.78 0.78 0.78], ...   % gray-field page background
    'Theme', 'light');                % neutralize inherited dark-theme defaults on widgets
```

- `Theme = 'light'` blocks dark-theme inheritance on all child widgets (gauges, lamps, edit fields, axes ticks). Without it, every widget needs explicit `FontColor`/`BackgroundColor` overrides.
- The explicit gray-field `Color` on the figure (and `BackgroundColor` on panels and grids) keeps the result gray-field rather than the bright white that `'light'` would otherwise produce. ISA-101 has no white-field variant — keep the gray.

Minimal classdef construction snippet that combines them:

```matlab
function createComponents(app)
    app.UIFigure = uifigure( ...
        'Color',    [0.78 0.78 0.78], ...
        'Theme',    'light', ...
        'Position', [100 100 1200 700], ...
        'Name',     'Plant Overview');

    app.MainGrid = uigridlayout(app.UIFigure, [3 1]);
    app.MainGrid.RowHeight       = {28, 120, '1x'};
    app.MainGrid.BackgroundColor = [0.78 0.78 0.78];

    % Panels still get the lighter gray; Theme handles the inherited child defaults.
    app.KpiPanel = uipanel(app.MainGrid, ...
        'BackgroundColor', [0.86 0.86 0.86], ...
        'BorderType',      'none');
end
```

If a user explicitly asks for a "dark dashboard", reply with the one-sentence justification from the SKILL.md Must-Follow Rules: ISA-101 has no dark variant; gray-field with color-as-exception is the standard, and dark-mode inverts that contrast.

See `common-mistakes.md` entry 24 for the visible failure mode (gauge bodies and axes go near-black) when `Theme='light'` is forgotten.

## Layout hierarchy — three levels

Operators navigate a SCADA HMI by drilling down. The skill must produce all three levels for non-trivial plants; for a single-station HMI, Level 1 collapses into the Level 2 view.

```
Level 1 — Plant Overview
  Question:  "Is anything wrong?"
  Content:   KPI summary cards, alarm count badge, equipment status grid
  Widgets:   uilamp, uieditfield numeric (KPIs), mini sparklines (animatedline)
  Trigger:   Default landing screen when the app opens.

Level 2 — Area / Unit View
  Question:  "What is happening in this system?"
  Content:   4-6 gauges or trend plots for one subsystem (e.g., WeldShop)
  Widgets:   uigauge, uiaxes + animatedline, uilamp, uilabel (status)
  Trigger:   Operator clicks an area tile from Level 1.

Level 3 — Detail / Diagnostic
  Question:  "What are the exact values and history?"
  Content:   Full trend history, node table, write controls, alarm list
  Widgets:   Scrollable trend, uitable, uispinner + uibutton, alarm list
  Trigger:   Operator clicks a station / node from Level 2.
```

A `uitabgroup` is the standard widget for the Level 1 → Level 2 → Level 3 transitions when everything is in one window.

## Spatial layout rules

```
+--------------------------------------------------------------+
| ALARM BANNER (row 1, persistent across all levels)           |  ← never empty when alarms active
+----------+---------------------------------------------------+
|          |                                                   |
|   NAV    |   PRIMARY VISUALIZATION                           |
|   TREE   |   (gauges, trends, tables — Level 2/3 content)    |
|          |                                                   |
| (uitree, |                                                   |
| optional)|                                                   |
|          +---------------------------------------------------+
|          | WRITE CONTROLS / DETAIL PANEL                     |  ← visually separated
|          | (setpoints, buttons, alarm list)                  |
+----------+---------------------------------------------------+
```

- **Top strip (row 1, persistent):** Alarm banner. Visible across all screens. Always present in the layout — gray when no alarms, red/amber when active.
- **Left panel (column 1, optional):** `uitree` mirroring the OPC UA namespace or plant hierarchy. For a single-area HMI, this can be replaced by `uitabgroup` along the top.
- **Center area:** Primary visualization — gauges, trends, tables.
- **Right or bottom panel:** Setpoints, write controls, alarm list. **Visually separated** from the center: different background color (`[0.86 0.86 0.86]` panel vs `[0.78 0.78 0.78]` page), border, or a row gap.
- **Never place write controls in the center area.** Setpoints and actuation must be in a secondary zone to prevent accidental activation.

## Pattern: Level 1 plant overview

Tile-based plant overview with KPI cards and station status grid:

```matlab
fig = uifigure('Color', [0.78 0.78 0.78], 'Theme', 'light', ...
    'Position', [100 100 1200 700]);

gl = uigridlayout(fig, [3 1]);
gl.RowHeight       = {28, 120, '1x'};
gl.BackgroundColor = [0.78 0.78 0.78];

% Row 1: Alarm banner (see references/alarm-patterns.md)
banner = uilabel(gl, 'Text', 'No active alarms', ...
    'BackgroundColor', [0.86 0.86 0.86], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');
banner.Layout.Row = 1;

% Row 2: KPI tiles (4 across)
kpiRow = uigridlayout(gl, [1 4]);
kpiRow.Layout.Row = 2;
kpiRow.BackgroundColor = [0.78 0.78 0.78];
kpiRow.Padding = [10 10 10 10];

makeKpiTile(kpiRow, 'Bodies / hr',   '42', [0.86 0.86 0.86]);
makeKpiTile(kpiRow, 'Pass rate',     '97.3%', [0.86 0.86 0.86]);
makeKpiTile(kpiRow, 'Active alarms', '0',  [0.86 0.86 0.86]);
makeKpiTile(kpiRow, 'Uptime (h)',    '72', [0.86 0.86 0.86]);

% Row 3: Station status grid (2x2 of stations: Body, Paint, Assembly, QC)
stationGrid = uigridlayout(gl, [2 2]);
stationGrid.Layout.Row = 3;
stationGrid.BackgroundColor = [0.78 0.78 0.78];
stationGrid.Padding = [10 10 10 10];

makeStationTile(stationGrid, 'Body Shop',   'Running', [0 0.6 0]);
makeStationTile(stationGrid, 'Paint Shop',  'Running', [0 0.6 0]);
makeStationTile(stationGrid, 'Assembly',    'Idle',    [0.5 0.5 0.5]);
makeStationTile(stationGrid, 'Quality',     'Running', [0 0.6 0]);
```

Reference implementations for the two tile constructors:

```matlab
function tile = makeKpiTile(parent, titleText, valueText, bgColor)
    tile = uigridlayout(parent, [2 1], ...
        'RowHeight',       {18, '1x'}, ...
        'BackgroundColor', bgColor, ...
        'Padding',         [8 8 8 8], ...
        'RowSpacing',      4);
    uilabel(tile, ...
        'Text',                titleText, ...
        'FontSize',            11, ...
        'FontColor',           [0.3 0.3 0.3], ...
        'HorizontalAlignment', 'left');
    uilabel(tile, ...
        'Text',                valueText, ...
        'FontSize',            22, ...
        'FontWeight',          'bold', ...
        'FontColor',           [0.10 0.10 0.10], ...
        'HorizontalAlignment', 'left');
end

function tile = makeStationTile(parent, stationName, statusText, lampColor)
    tile = uigridlayout(parent, [2 2], ...
        'RowHeight',       {'1x', 24}, ...
        'ColumnWidth',     {'1x', 24}, ...
        'BackgroundColor', [0.86 0.86 0.86], ...
        'Padding',         [10 10 10 10]);

    nameLbl = uilabel(tile, ...
        'Text',                stationName, ...
        'FontSize',            16, ...
        'FontWeight',          'bold', ...
        'HorizontalAlignment', 'left');
    nameLbl.Layout.Row = 1; nameLbl.Layout.Column = [1 2];

    statusLbl = uilabel(tile, ...
        'Text',                statusText, ...
        'FontSize',            12, ...
        'FontColor',           [0.3 0.3 0.3], ...
        'HorizontalAlignment', 'left');
    statusLbl.Layout.Row = 2; statusLbl.Layout.Column = 1;

    lamp = uilamp(tile, 'Color', lampColor);
    lamp.Layout.Row = 2; lamp.Layout.Column = 2;
end
```

Wire click-to-drill-down on a station tile by adding a `ButtonDownFcn` to the tile's grid layout (or wrapping in a `uibutton` styled to look like a tile).

## Like-typed analogs use like widgets in the same panel

If a panel shows multiple temperatures, all should be gauges OR all should be numeric readouts — never mixed. (Heuristic H4.) Mixing forces operators to switch reading modes.

## Keep tick density readable at the rendered size

Default tick density on a small `uigauge` produces overlapping labels. If the gauge is rendered <150 px wide, set `MajorTicks` and `MinorTicks` explicitly:

```matlab
g = uigauge(panel, 'linear', 'Limits', [0 250], ...
    'MajorTicks',      [0 100 200 250], ...
    'MinorTicks',      0:50:250, ...
    'MajorTickLabels', {'0','100','200','250'});
```

(Heuristic H8 — minimalist design.)

## Don't put rarely-changing counters in prime real estate

Production counters that update once per cycle (e.g., "bodies completed today") should not occupy the same visual slot as fast-changing process variables. Group them in a footer or sidebar, not the center grid. (Heuristic H8.)

----

Copyright 2026 The MathWorks, Inc.

----
