# Alarm Patterns

Alarms in an industrial HMI are a **state applied to existing widgets**, not a popup or a separate alarm widget. Every alarm is shown in three places at once: at the source, in a persistent banner, and (on the detail screen) in a list.

## The three required surfaces

1. **At source.** The widget showing the alarming node changes color (gauge `ScaleColors` band, table row background, lamp color, trend trace highlight).
2. **Persistent banner.** A top-row `uilabel` that lists active alarms across the whole HMI, color-coded by highest active severity.
3. **Alarm list (detail screen).** A `uitable` with columns Timestamp, Node, Severity, Value, State (Active/Acknowledged/Cleared).

If any of the three is missing, the alarm is unsafe. Operators on a different screen will not see a source annotation; operators on the source screen will not see siblings; nobody can audit cleared alarms without a list.

## Severity levels

Use exactly three:

| Severity | Color | When |
|----------|-------|------|
| Critical | Red `[0.85 0 0]` | Safety limit exceeded; immediate operator action required |
| Warning  | Amber `[1 0.7 0]` | Approaching limit; pre-trip; advisory action |
| Advisory | Blue `[0.4 0.6 1.0]` | Informational; data quality; non-process |

Audible/visual flash is for **Critical only**. Flashing on warnings desensitizes operators.

## Threshold rules

```
IF value >= high_critical (HH)  → Critical (red)
IF value >= high_warning  (H)   → Warning  (amber)
IF value <= low_warning   (L)   → Warning  (amber)
IF value <= low_critical  (LL)  → Critical (red)
ELSE                            → Normal   (gray-field)
```

## Pattern A — Gauge `ScaleColors` keyed to LL/L/H/HH

> **`ScaleColors` requires `'linear'`** — on `'semicircular'`, `'circular'`, and `'ninetydegree'` gauges these properties are silently ignored (no error, no color bands). Use linear gauges when alarm bands are needed; if the layout demands a non-linear gauge, indicate alarm state with a colored frame, an adjacent lamp, or a status badge instead.

The most important pattern: encode the alarm thresholds **at construction**, so the alarm state is visible in the gauge itself with no runtime logic. The agent does not need to recompute "is this alarm" on every update — the gauge does it visually.

> **Common Mistake — green for "normal".** LLMs default to green for the OK band because of "green = good" priors. ISA-101 forbids it: green is reserved for *operator-verified-OK* states (rare; explicit). The normal band MUST be neutral gray `[0.5 0.5 0.5]`. Using `[0 1 0]`, `[0 0.6 0]`, or `'green'` in `ScaleColors` is a violation. See `references/common-mistakes.md` entry 8.

```matlab
g = uigauge(parent, 'linear', 'Limits', [0 250]);

% Five bands. Order matches ScaleColorLimits rows (low→high).
g.ScaleColors      = [0.85 0   0;     % LL (0–40):    Critical red
                      1    0.7 0;     % L  (40–60):   Warning amber
                      0.5  0.5 0.5;   % normal (60–200): gray-field
                      1    0.7 0;     % H  (200–230): Warning amber
                      0.85 0   0];    % HH (230–250): Critical red
g.ScaleColorLimits = [0   40;
                      40  60;
                      60  200;
                      200 230;
                      230 250];
```

### Three-band fallback — single-sided alarms

Many nodes only have an upper alarm (temperatures that should never overheat) or only a lower alarm (pass-rates that should never drop). Use 3 bands: `normal/H/HH` or `LL/L/normal`. The shape of `ScaleColors` and `ScaleColorLimits` adjusts:

```matlab
% Upper-only alarm — e.g., WeldingRobot1_Temperature with warn=90, alarm=100
g = uigauge(parent, 'linear', 'Limits', [0 150]);
g.ScaleColors      = [0.5  0.5 0.5;    % normal: gray (0–90)
                      1    0.7 0;      % H:      amber (90–100)
                      0.85 0   0];     % HH:     red (100–150)
g.ScaleColorLimits = [0   90;
                      90  100;
                      100 150];

% Lower-only alarm — e.g., PassRate with warn=85, alarm=70
g = uigauge(parent, 'linear', 'Limits', [0 100]);
g.ScaleColors      = [0.85 0   0;      % LL:     red (0–70)
                      1    0.7 0;      % L:      amber (70–85)
                      0.5  0.5 0.5];   % normal: gray (85–100)
g.ScaleColorLimits = [0   70;
                      70  85;
                      85  100];
```

The general rule: drop bands whose width would be zero. Five-band 5-band `[LL,L,normal,H,HH]` is the maximum; degrade to 3-band when one side has no alarm threshold.

## Pattern B — Persistent alarm banner

Reserve row 1 of the top-level grid for the banner. It is part of the gray-field background when no alarms are active.

```matlab
gl = uigridlayout(fig, [3 1]);
gl.RowHeight = {28, '1x', '1x'};
gl.BackgroundColor = [0.78 0.78 0.78];

banner = uilabel(gl, ...
    'Text',                 'No active alarms', ...
    'BackgroundColor',      [0.86 0.86 0.86], ...
    'FontWeight',           'bold', ...
    'FontColor',            [0.2 0.2 0.2], ...
    'HorizontalAlignment',  'center');
banner.Layout.Row = 1;
```

Update logic (called from the data callback whenever an alarm state changes):

```matlab
function refreshBanner(app)
    active = app.AlarmList(arrayfun(@(a) a.State == "Active", app.AlarmList));
    if isempty(active)
        app.Banner.Text            = 'No active alarms';
        app.Banner.BackgroundColor = [0.86 0.86 0.86];
        app.Banner.FontColor       = [0.2 0.2 0.2];
        return
    end
    % Highest severity wins on color; banner text lists all active.
    sev = max([active.SeverityLevel]);   % 3=Critical, 2=Warning, 1=Advisory
    switch sev
        case 3
            app.Banner.BackgroundColor = [0.85 0   0];   % red
            app.Banner.FontColor       = [1 1 1];
        case 2
            app.Banner.BackgroundColor = [1 0.7 0];      % amber
            app.Banner.FontColor       = [0 0 0];
        otherwise
            app.Banner.BackgroundColor = [0.4 0.6 1.0];  % blue
            app.Banner.FontColor       = [1 1 1];
    end
    names = arrayfun(@(a) sprintf('%s=%.1f', a.Node, a.Value), active, ...
        'UniformOutput', false);
    app.Banner.Text = sprintf('ACTIVE (%d): %s', numel(active), strjoin(names, ' | '));
end
```

## Pattern C — Latched alarm with Acknowledge button

A latched alarm keeps the alarm state visible until the operator acknowledges it, even if the underlying value has returned to normal. This is the standard SCADA pattern (matches ISA-18.2).

```matlab
properties (Access = private)
    AlarmLatched (1,1) logical = false   % is the alarm currently latched?
    AlarmActive  (1,1) logical = false   % is the value currently above threshold?
end
```

In the data callback:

```matlab
function onTempChange(app, newValue)
    if newValue >= app.HighCritical
        app.AlarmActive  = true;
        app.AlarmLatched = true;          % latch on rising edge
    else
        app.AlarmActive = false;
        % Do NOT clear AlarmLatched here — only Acknowledge clears the latch.
    end
    refreshBanner(app);
    refreshAckButton(app);
end
```

Acknowledge button callback:

```matlab
function onAcknowledge(app, ~, ~)
    if ~app.AlarmActive
        app.AlarmLatched = false;
    end
    % If still active, ack does nothing — operator must wait for value to clear.
    refreshBanner(app);
    refreshAckButton(app);
end
```

The Ack button should be enabled only when `AlarmLatched && ~AlarmActive` (alarm has cleared but is still latched).

## Anti-pattern: popups for live process alarms

**Never** use `uialert`, `uiconfirm`, or `msgbox` for a repeating process alarm condition. Anti-pattern #7 in the rules doc, also called out by ISA-18.2 (alarm fatigue). The popup fires every poll cycle, blocks the operator's view, and disappears once dismissed — exactly the opposite of what alarm visualization needs to do.

If a popup is unavoidable (e.g., the user explicitly insists), tame it:
- Fire **once on the rising edge**, not every tick.
- Use a non-blocking `CloseFcn`, not modal.
- Always pair with a persistent banner + source annotation, so the alarm survives the operator dismissing the popup.

## Pattern D — Minimal single-alarm screen

When the operator just needs notification on **one** condition (the simplest possible alarm HMI), the full Level-1/2/3 hierarchy is overkill. The minimal screen is: persistent banner, one gauge with `ScaleColors` band, one numeric readout, and an Acknowledge button. Use this layout for single-node monitoring tools, on-call alarm widgets, or test rigs.

```matlab
fig = uifigure('Name','Welder Temp Alarm', ...
    'Color',[0.78 0.78 0.78], 'Theme','light');
gl  = uigridlayout(fig,[3 2], ...
    'RowHeight',    {32, '1x', 40}, ...
    'ColumnWidth',  {'1x', 110}, ...
    'BackgroundColor', [0.78 0.78 0.78], ...
    'Padding', [10 10 10 10]);

% Row 1: banner across both columns
banner = uilabel(gl, 'Text','No active alarms', ...
    'BackgroundColor',[0.86 0.86 0.86],'FontWeight','bold', ...
    'HorizontalAlignment','center');
banner.Layout.Row = 1; banner.Layout.Column = [1 2];

% Row 2 col 1: gauge with alarm band at construction
g = uigauge(gl,'linear','Limits',[0 150]);
g.ScaleColors      = [0.5  0.5 0.5; 1 0.7 0; 0.85 0 0];
g.ScaleColorLimits = [0 90; 90 100; 100 150];
g.Layout.Row = 2; g.Layout.Column = 1;

% Row 2 col 2: precise numeric readout
val = uieditfield(gl,'numeric','Editable','off', ...
    'ValueDisplayFormat','%.1f °C', ...
    'BackgroundColor',[0.86 0.86 0.86], ...
    'HorizontalAlignment','right');
val.Layout.Row = 2; val.Layout.Column = 2;

% Row 3 col 2: Acknowledge button (enabled only when latched && cleared)
ackBtn = uibutton(gl,'Text','Acknowledge','Enable','off');
ackBtn.Layout.Row = 3; ackBtn.Layout.Column = 2;
```

## Cross-references

- Color palette and gray-field background: `references/color-and-layout-rules.md`
- Threshold lines on trend axes: `references/trend-config-reference.md`
- Connection-quality alarms (stale data, subscription lost): use Advisory severity (blue) — same banner mechanism

----

Copyright 2026 The MathWorks, Inc.

----
