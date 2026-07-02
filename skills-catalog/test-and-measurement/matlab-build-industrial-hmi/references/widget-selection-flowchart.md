# Widget Selection Flowchart

Use this when picking widgets for a list of OPC UA nodes (or Modbus / MQTT items). Walk every node through the decision tree and check the result against the quantity caps.

## Decision tree

```
For each node:

  Is the data binary (2 states — on/off, open/closed, running/stopped)?
    YES → uilamp + adjacent uilabel
    NO  ↓

  Is it enumerated (3+ states — Idle/Running/Fault/Maintenance)?
    YES → styled uilabel with colored background
    NO  ↓

  Is the node writable (operator setpoint or command)?
    YES → uispinner or uieditfield('numeric') + Limits + Send button
          (See references/write-safeguards-reference.md)
    NO  ↓

  Does the node have a defined min/max range AND fit on the screen?
    YES → Is the user's goal "monitor at a glance"?
            YES → uigauge ('semicircular' single KPI, 'linear' for side-by-side rows)
                  ⚠ If the node has alarm thresholds (LL/L/H/HH) → use 'linear' only:
                  only `uigauge('linear')` supports `ScaleColors`/`ScaleColorLimits`.
            NO  → uieditfield('numeric','Editable',false) for precise reading
    NO  ↓

  Did the user say "monitor", "track", "trend", or "over time"?
    YES → uiaxes + animatedline
          (See references/trend-config-reference.md)
    NO  ↓

  Are there more than 8 similar nodes to display together?
    YES → uitable with conditional row coloring
    NO  → uiaxes + animatedline (default to trend)
```

## Widget-by-data-type quick reference

### Analog values

| Condition | Widget | Notes |
|-----------|--------|-------|
| Single value, known range, glance-monitoring | `uigauge('linear')` or `uigauge('semicircular')` | `Limits` = sensor spec range, not observed range. Only `'linear'` supports `ScaleColors`/`ScaleColorLimits` — choose linear when the node has alarm thresholds and color bands are required; semicircular/circular/ninetydegree have no alarm-band support. |
| Single value, trend matters more than current reading | `uiaxes` + `animatedline` | Set `MaximumNumPoints` from `WindowSeconds / UpdatePeriod` |
| Single value, precise digits matter (setpoints, calculated outputs) | `uieditfield('numeric','Editable',false)` | `ValueDisplayFormat` for units and precision |
| Setpoint + actual shown together | Gauge with setpoint marker (yline overlay) OR adjacent numeric pair | Operator must see deviation without mental math |
| Multiple same-unit values for comparison | Horizontal `uigauge('linear')` row OR grouped bar | Enables rank-ordering and outlier spotting |
| Multiple different-unit values | Separate trends OR `yyaxis` plot | Never mix units on one axis |

### Discrete / binary values

| Condition | Widget | Notes |
|-----------|--------|-------|
| Binary (running/stopped, open/closed) | `uilamp` + adjacent `uilabel` | Lamp `Color` follows state; never color-only — pair with the label text |
| Enumerated (3+ states) | `uilabel` with `BackgroundColor` keyed to state | Text disambiguates; color reinforces |
| Writable command toggle (start/stop, enable/disable) | `uiswitch` or `uistatebutton` + `uiconfirm` | Confirmation is mandatory for actuation |

### Collections

| Condition | Widget | Notes |
|-----------|--------|-------|
| >8 monitored nodes | `uitable` with conditional row coloring | Pick which to plot via row-click callback |
| ≤8 nodes, all analog, same context | Grid of gauges OR overlaid trends with legend | Direct visual comparison without scrolling |
| Hierarchical equipment structure | `uitree` + `uitreenode` | Mirrors OPC UA namespace; never use a flat list |

## Quantity caps per screen

| Widget type | Max | If exceeded |
|-------------|-----|-------------|
| Gauges | 6 | Switch to `uitable` + selectable trend |
| Trend plots (separate axes) | 4 | Tabbed panels OR overlay with legend |
| Status lamps | 20 | Group into a status grid or summary indicator |
| Numeric displays | 12 | Use a `uitable` instead |
| Alarm banners | 1 (priority-based) | Stack into an alarm list on the detail screen |

## Like-typed analogs in the same panel must use like widgets

If the panel shows multiple analog nodes of the same kind (all temperatures, all pressures), use the **same** widget for all of them. Don't show one as a gauge and another as a numeric label — the inconsistency forces operators to switch reading modes.

```matlab
% BAD: ConveyorSpeed and ConveyorTorque side by side, different widgets
% conveyorSpeedGauge  = uigauge(panel, 'linear', 'Limits', [0 1.5]);
% conveyorTorqueLabel = uilabel(panel, 'Text', '12.4 Nm');

% GOOD: both as gauges
conveyorSpeedGauge  = uigauge(panel, 'linear', 'Limits', [0 1.5]);
conveyorTorqueGauge = uigauge(panel, 'linear', 'Limits', [0 50]);
```

## Mini code patterns

### Status lamp + label

```matlab
gl   = uigridlayout(panel, [1 2], 'ColumnWidth', {30, '1x'});
lamp = uilamp(gl, 'Color', [0.5 0.5 0.5]);   % gray = unknown/idle
lbl  = uilabel(gl, 'Text', 'Idle', 'FontWeight', 'bold');

% State change handler (e.g., from subscription callback):
%   lamp.Color = [0 0.6 0]; lbl.Text = 'Running';
%   lamp.Color = [0.85 0 0]; lbl.Text = 'Fault';
```

### Multi-state badge (enumerated label)

```matlab
badge = uilabel(panel, ...
    'Text',             'IDLE', ...
    'BackgroundColor',  [0.5 0.5 0.5], ...
    'FontColor',        [1 1 1], ...
    'FontWeight',       'bold', ...
    'HorizontalAlignment', 'center');

% On state change: set both Text and BackgroundColor.
%   badge.Text = 'RUNNING'; badge.BackgroundColor = [0 0.6 0];
%   badge.Text = 'FAULT';   badge.BackgroundColor = [0.85 0 0];
```

### Read-only numeric display

```matlab
val = uieditfield(panel, 'numeric', ...
    'Editable',           'off', ...
    'ValueDisplayFormat', '%.2f bar', ...
    'BackgroundColor',    [0.86 0.86 0.86], ...
    'HorizontalAlignment','right');
```

### Table for >8 nodes

```matlab
nodeTable = uitable(panel, ...
    'ColumnName',  {'Node','Value','Units','State','Updated'}, ...
    'RowStriping', 'off', ...
    'BackgroundColor', [0.86 0.86 0.86]);

% Conditional row coloring (set in update callback):
%   s = uistyle('BackgroundColor',[0.85 0 0],'FontColor',[1 1 1]);
%   addStyle(nodeTable, s, 'row', alarmedRows);
```

----

Copyright 2026 The MathWorks, Inc.

----
