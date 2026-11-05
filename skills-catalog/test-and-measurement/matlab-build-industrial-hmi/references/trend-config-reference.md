# Trend Configuration Reference

Production HMI trends differ from exploratory MATLAB plots in three load-bearing ways: the **window is fixed at 5 minutes**, the **Y-axis is fixed to the sensor spec**, and **threshold lines are drawn at construction**. Auto-scaling is for offline analysis, not operator screens.

## Defaults table

| Parameter | Default | Why |
|-----------|---------|-----|
| Time window | 5 minutes (rolling) | Long enough to see trends, short enough to see transients |
| Y-axis | Fixed range matching sensor spec | Auto-scale hides gradual drift; fixed axis reveals abnormality |
| Y-axis override | Per-trend "auto-scale" toggle | Lets the operator escape the fixed axis for exploration |
| Grid lines | On, subtle gray | Aids precise reading without visual clutter |
| Setpoint line | `yline` dashed at target value | Anchors the operator's expectation of "normal" |
| Alarm threshold lines | `yline` amber dashed (warn), red dashed (critical) | Operator sees how close to limit without mental math |
| Legend | Always visible when ≥ 2 traces | Never rely on color alone to identify traces |
| Update rate | Match subscription interval; default 1 s | Faster than 100 ms flickers; slower than 5 s feels laggy |

## Buffer sizing

Use this formula every time:

```
MaximumNumPoints = WindowSeconds / UpdatePeriodSeconds
```

| Window | Update | `MaximumNumPoints` |
|--------|--------|---------------------|
| 5 min  | 1 s    | **300** (default for HMI trends) |
| 5 min  | 0.5 s  | 600 |
| 5 min  | 2 s    | 150 |
| 60 s   | 1 s    | 60 (too short — only use if explicitly asked) |
| 30 min | 1 s    | 1800 (use sparingly — memory + redraw cost) |

## Pattern: 5-minute trend with thresholds

**Every production trend carries all five of these — none is optional:** (1) a fixed `YLim`
matching the sensor spec (never left on autoscale), (2) a unit `ylabel` and a time `xlabel`,
(3) an `animatedline` trace, (4) — whenever the trended node has alarm thresholds —
threshold `yline`s at the **same warn/alarm values as the source gauge's `ScaleColorLimits`**,
and (5) **no interactive axes toolbar**: `ax.Toolbar.Visible = 'off'` and `ax.Interactions = []`.
A `uiaxes` ships with a visible toolbar and a full default interaction set, so an operator can
pan or zoom a live trend and silently defeat the fixed `YLim` — the axis then lies about the
process while looking normal, and nothing in the UI says it was moved. Exploration belongs on
the explicit per-trend toggle below, which is auditable; an ad-hoc drag is not.
A trend of an alarmed node rendered with an autoscaled axis, no unit label, or no threshold
lines is incomplete, not a minimal-but-acceptable default. The thresholds and the gauge bands
must agree — they describe the same physical limits.

```matlab
% Construct the axis with fixed limits matching the sensor spec.
ax = uiaxes(parent, 'XLim', [0 300], 'YLim', [0 250]);
xlabel(ax, 'Time (s)');
ylabel(ax, 'Temperature (°C)');
grid(ax,  'on');
ax.GridColor = [0.7 0.7 0.7];

% A live trend is a read-only instrument: no toolbar, no pan, no zoom.
ax.Toolbar.Visible = 'off';
ax.Interactions    = [];

% Threshold lines: drawn ONCE at construction. They persist for the life of the app.
% Set 'HandleVisibility','off' so a later legend('show') does NOT pick them up as
% generic 'data1'/'data2' entries — the on-line 'Label' already identifies them.
% 'LabelHorizontalAlignment','left' puts the label text in the axes' upper-left region.
% If this trend also carries a legend, that is where the legend goes too — see
% "Threshold labels and the legend collide" below before keeping both on the left.
yline(ax, 200, '--', 'Color', [1 0.7 0],  'LineWidth', 1.2, ...
    'Label', 'Warn 200°C', 'LabelHorizontalAlignment', 'left', ...
    'HandleVisibility', 'off');
yline(ax, 230, '--', 'Color', [0.85 0 0], 'LineWidth', 1.5, ...
    'Label', 'Alarm 230°C', 'LabelHorizontalAlignment', 'left', ...
    'HandleVisibility', 'off');

% Optional: setpoint line, different style so operators can tell it apart.
yline(ax, 180, ':', 'Color', [0.4 0.6 1.0], 'LineWidth', 1.0, ...
    'Label', 'Setpoint', 'LabelHorizontalAlignment', 'right', ...
    'HandleVisibility', 'off');

% The trace: 300 points at 1 s update = 5 min rolling window.
trace = animatedline(ax, 'MaximumNumPoints', 300, ...
    'Color', [0 0 0], 'LineWidth', 1.2);
```

In the data callback (subscribe or timer):

```matlab
addpoints(trace, t, value);
```

`animatedline` with `MaximumNumPoints` automatically discards old points as new ones arrive — no manual ring-buffer management.

## Multi-trace trend

For 2 traces with the same units, overlay on one axis with a legend:

```matlab
ax = uiaxes(parent, 'XLim', [0 300], 'YLim', [0 250]);
xlabel(ax, 'Time (s)'); ylabel(ax, 'Temperature (°C)'); grid(ax, 'on');

t1 = animatedline(ax, 'MaximumNumPoints', 300, 'Color', [0   0   0  ], ...
    'DisplayName', 'WeldRobot1');
t2 = animatedline(ax, 'MaximumNumPoints', 300, 'Color', [0.2 0.2 0.7], ...
    'DisplayName', 'WeldRobot2');
% Legend OUTSIDE the plot box: it cannot cover the live trace (which lives at the
% right edge of a rolling window) and it cannot collide with the threshold labels
% (which sit at the left). See "Threshold labels and the legend collide" below.
legend(ax, 'show', 'Location', 'northoutside', 'Orientation', 'horizontal');
% Give every trace a 'DisplayName' and hide non-trace lines from the legend
% ('HandleVisibility','off' on threshold/setpoint ylines above). Otherwise
% legend('show') auto-labels the unnamed lines 'data1', 'data2', … and the
% legend fills with threshold clutter instead of just the traces.
```

### Threshold labels and the legend collide

`'HandleVisibility','off'` keeps the `yline`s out of the legend's *entries*, but it does nothing
about where their **label text** is drawn. A `yline` label with
`'LabelHorizontalAlignment','left'` lands in the axes' upper-left — the same place
`'Location','northwest'` puts the legend box. On a short HMI trend they overlap and the
threshold value becomes unreadable.

Pick one of these; don't leave both on the left:

| Trend has | Do this |
|---|---|
| Legend **and** threshold labels | `legend(…,'Location','northoutside','Orientation','horizontal')` — outside the plot box, so it can collide with neither the labels nor the trace |
| Threshold labels, single trace (no legend) | Keep labels `'left'`; nothing to collide with |
| Legend inside the axes, by preference | Then set the threshold labels `'LabelHorizontalAlignment','right'` instead, and keep the legend at `'northwest'` |

Avoid `'Location','northeast'` for an inside legend on a rolling trend — the newest samples are
at the right edge, which is exactly what the operator is watching.

For 2 traces with **different units**, use `yyaxis`. For 3+ different-unit traces, use separate panels — never cram different-unit traces onto a `yyaxis` plot.

## Per-trend auto-scale toggle (the escape hatch)

The fixed-axis rule has one escape: let the operator switch a single trend to auto-scale for exploration. Don't make this the default.

```matlab
toggle = uiswitch(parent, 'rocker', ...
    'Items',           {'Fixed','Auto'}, ...
    'Value',           'Fixed', ...
    'ValueChangedFcn', @(s,e) onAxisModeChange(app, ax, s.Value));

function onAxisModeChange(app, ax, mode)
    switch mode
        case 'Fixed'
            ax.YLimMode = 'manual';
            ax.YLim     = app.NodeSpecRange;   % e.g., [0 250]
        case 'Auto'
            ax.YLimMode = 'auto';
    end
end
```

## Wiring data updates

For OPC UA, the trend update lives in the `subscribe()` callback (preferred). For non-OPC sources (MQTT, Modbus polling), use a `timer` with `BusyMode='drop'`, `ExecutionMode='fixedSpacing'`. See `references/widget-selection-flowchart.md` for `subscribe` vs `timer` selection.

```matlab
% In the subscribe callback:
function onNodeChange(app, ~, evt)
    val = evt.Data.Value;
    elapsed = seconds(datetime('now') - app.StartTime);
    addpoints(app.TempTrace, elapsed, val);

    % Rolling X axis: keep the last 5 min visible once we're past 300 s.
    % MaximumNumPoints rolls the buffer; the axis itself doesn't scroll
    % unless XLim is updated here.
    if elapsed > 300
        app.TempAxes.XLim = [elapsed - 300, elapsed];
    end
    drawnow limitrate;       % critical: limit the redraw rate
end
```

Always use `drawnow limitrate` in trend callbacks. Plain `drawnow` blocks until the figure is repainted, which can stack up if updates arrive faster than the GUI thread can render.

### Why the `XLim` update is needed

`animatedline`'s `MaximumNumPoints` rolls the *buffer* — old points are discarded automatically. But the axis `XLim` set at construction (`[0 300]`) never moves on its own. After 300 s, new points still get added at increasing X coordinates, but those coordinates are off-screen to the right. The trace appears to "freeze" at the right edge while the buffer keeps rolling silently.

The rolling-XLim block above keeps `[0 300]` for the first 5 minutes (so the axis isn't blank during initial fill), then scrolls in lock-step with the latest sample. Combined with the bounded buffer, the visible window always shows exactly the last 5 minutes.

## Common mistakes specific to trends

| Mistake | Why it's wrong | Fix |
|---------|----------------|-----|
| `plot(ax, t, y)` to refresh the trend | Replots the entire history every update; performance degrades quickly | `animatedline` + `addpoints` |
| Auto-scale `YLim` left as default | Gradual drift hidden by axis jumping with the signal | `YLim = sensorSpec` at construction |
| 60-second window for a process trend | Too short to spot transients in process context | `MaximumNumPoints = 300` at 1 s |
| Threshold drawn dynamically every tick | Jitter, redraw cost, occasional disappearance | `yline` once at construction; persists forever |
| Threshold `yline`s left with default handle visibility | `legend('show')` pulls them in as `data1`/`data2`… — the legend fills with threshold clutter, not traces | `'HandleVisibility','off'` on every threshold/setpoint `yline`; the on-line `'Label'` already names it |
| Threshold labels `'left'` **and** legend `'northwest'` | Both land in the axes' upper-left; the label text renders under the legend box and the threshold value is unreadable. `HandleVisibility` doesn't help — it governs legend *entries*, not label placement | Move the legend outside: `'Location','northoutside','Orientation','horizontal'` (or keep it `'northwest'` and set the labels `'LabelHorizontalAlignment','right'`) |
| `XLim` fixed at construction, never updated in callback | After the window expires, new points are drawn off-screen — the trace appears to freeze at the right edge | Update `XLim = [elapsed-300, elapsed]` in the data callback once `elapsed > 300` |
| Mixing units on a single axis | Operator misreads the magnitude | `yyaxis` for two units; separate panels for more |
| `drawnow` (no `limitrate`) in callback | Updates stack up under high node activity | `drawnow limitrate` |

----

Copyright 2026 The MathWorks, Inc.

----
