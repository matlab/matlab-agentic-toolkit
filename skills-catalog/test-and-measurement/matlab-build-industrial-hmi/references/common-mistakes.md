# Common Mistakes

Wrong/correct code pairs for the bugs that show up most often when wrapping a monitoring script into an HMI. Grouped by domain. Each entry has **Symptom → Wrong → Right → Why**, so the agent can match a user's reported failure mode without re-deriving the fix.

If you arrived here from a user error message, search this file for the message text — most entries quote the exact string MATLAB prints.

---

## App Designer language gotchas

### 1. Typed `struct` property without default → empty struct array

**Symptom:** runtime error
> `A dot name structure assignment is illegal when the structure is empty. Use a subscript on the structure.`

**Wrong:**
```matlab
properties (Access = private)
    InfoNodes struct          % defaults to 0×0 struct
end
% ...
function startup(app)
    app.InfoNodes.Robot1 = 1;     % FAILS HERE
end
```

**Right:**
```matlab
properties (Access = private)
    InfoNodes struct = struct()   % scalar struct; fields can be added
end
```
Or build the struct locally and whole-struct assign: `s = struct(); s.Robot1 = 1; app.InfoNodes = s;`.

**Why:** A typed property declaration without a default initializes to the *empty* of that type. For `struct`, "empty" is `0×0 struct` (zero-element array), not a scalar struct with no fields. You cannot dot-name-assign into a zero-element array — there's no element to assign into.

See `references/app-designer-gotchas.md` for both fix variants and which to pick when.

---

### 2. `function` block before `classdef` in the same file

**Symptom:** parse error
> `Only one class definition is allowed per file, and it must come at the head of the file.`

**Wrong:**
```matlab
% MyApp.m
function MyApp                   % wrapper above classdef
    app = MyAppImpl;
    figure(app.UIFigure);
end

classdef MyAppImpl < matlab.apps.AppBase
    % ...
end
```

**Right:**
```matlab
% MyApp.m  — first non-comment statement is classdef; classdef name matches filename
classdef MyApp < matlab.apps.AppBase
    % ...
end
```

**Why:** Common mistake when an agent tries to make the file "runnable as a script" by wrapping `classdef` in a `function`. MATLAB parses the whole file before executing; the parser sees `function` first and refuses to also parse a `classdef`. To launch, the user calls `MyApp()` — App Designer apps are constructible just by invoking the class name.

---

### 3. `delete(sub)` on an `opc.ua.Subscription`

**Symptom:**
> `Cannot access method 'delete' in class 'opc.ua.Subscription'`

**Wrong:**
```matlab
delete(app.Subscription)              % no public delete on opc.ua.Subscription
```

**Right:**
```matlab
app.Subscription = opc.ua.Subscription.empty;   % drop the handle
disconnect(app.UAClient);                       % releases all subscriptions on this client
```

**Why:** `opc.ua.Subscription` does not expose a public `delete` in R2026a, and there's no `unsubscribe()` API. The supported cleanup is to drop your handle and let `disconnect(client)` close the underlying session, which releases all subscriptions attached to that client at once.

---

### 4. Repeated `subscribe()` calls accumulate channel listeners

**Symptom:** warnings firing on every notification, often after several "Add to Dashboard" clicks:
> `Warning: Error occurred while executing the listener callback for event DataChange defined for class opc.ua.Client: Too many input arguments.`

or:
> `Key not found in containers.Map.`

**Wrong — one global subscription, rebuilt on every add:**
```matlab
app.Subscription = subscribe(app.UAClient, [app.AllNodes, newNode], @cb);
```

**Right — subscribe per widget; never resubscribe an existing widget:**
```matlab
idx = numel(app.Widgets);
app.Widgets(idx).Sub = subscribe(app.UAClient, opcNode, ...
    @(src, evt) onDataChange(app, src, evt), ...
    PublishInterval = 0.5);
```

**Why:** Each `subscribe(client, …)` call attaches a fresh listener to the client's `opc.ua.Channel`. There is no public API to release a single subscription before `disconnect(client)`, so prior listeners stay attached and fire on every notification — often with a stale callback signature. The warning text mentions `opc.ua.Client`, not your code, which is what makes it hard to attribute. All accumulated subscriptions release on `disconnect(app.UAClient)`.

---

### 5. Numeric `bitand` on `AccessLevelCurrent` in R2026a

**Symptom:** writable nodes never get setpoint widgets, no error thrown.

**Wrong:**
```matlab
if bitand(uint8(node.AccessLevelCurrent), uint8(2)) > 0
    % treat as writable
end
```

**Right — release-aware check:**
```matlab
function tf = isWritable(node)
    a = node.AccessLevelCurrent;
    if ischar(a) || isstring(a)
        tf = contains(lower(char(a)), 'write');     % R2026a
    else
        tf = bitand(uint8(a), uint8(2)) > 0;        % older releases (bitmask)
    end
end
```

**Why:** R2026a returns `AccessLevelCurrent` as a string (`'read'`, `'read/write'`, `'write'`, `'none'`); older releases return a numeric OPC UA bitmask. A string-to-numeric coercion of `'read/write'` is not the bitmask, so writable nodes silently fail the test.

---

## ISA-101 / gray-field violations

### 6. Single-click write to a setpoint or actuator

**Wrong:**
```matlab
sendBtn = uibutton(panel, 'Text', 'Send', ...
    'ButtonPushedFcn', @(b,e) writeValue(app.UAClient, app.Node, app.Spnr.Value));
```

**Right — confirm dialog showing node + old + new + units, default Cancel:**
```matlab
function sendOvenSetpoint(app, spnr)
    oldVal = app.CurrentOvenSetpoint;
    newVal = spnr.Value;
    if newVal == oldVal, return; end
    msg = sprintf('Write OvenTemp setpoint:\n\n  node:  OvenTemp\n  old:   %d °C\n  new:   %d °C\n  range: 0 - 250 °C', oldVal, newVal);
    sel = uiconfirm(app.UIFigure, msg, 'Confirm setpoint', ...
        'Options', {'Apply','Cancel'}, ...
        'DefaultOption', 'Cancel', 'CancelOption', 'Cancel', 'Icon', 'warning');
    if sel == "Apply"
        try
            writeValue(app.UAClient, app.OvenSetpointNode, newVal);
            app.CurrentOvenSetpoint = newVal;
            flashFeedback(spnr, [0.7 1 0.7]);
        catch ME
            spnr.Value = oldVal;
            flashFeedback(spnr, [1 0.7 0.7]);
            uialert(app.UIFigure, ME.message, 'Write failed');
        end
    end
end
```

**Why:** No safeguard against operator typo or accidental click. Safety-critical writes (E-Stop, setpoints) must be defensive. E-Stop confirms even though it feels redundant — accidental clicks on a touchscreen are the threat. See `references/write-safeguards-reference.md` for the full pattern incl. flash feedback.

---

### 7. `uialert` / `uiconfirm` / `msgbox` for live process alarms

**Symptom:** a popup fires on every poll cycle while the alarm is active; operator can't see anything else.

**Wrong:**
```matlab
function onTempChange(app, value)
    if value > 230
        uialert(app.UIFigure, 'Temp HIGH!', 'Alarm');   % fires every cycle
    end
end
```

**Right — persistent banner + `uigauge.ScaleColors` at source:**
- Top-row `uilabel` banner showing all active alarms, colored by highest severity
- Gauge with red `ScaleColors` band on the HH range, so the alarm is visible at the data
- Latched state with an Acknowledge button (the latch survives the value returning to normal)

**Why:** Popups for repeating conditions are the canonical alarm-fatigue anti-pattern (ISA-18.2). The popup blocks the operator's view, fires every tick, and disappears once dismissed — exactly the opposite of what alarm visualization needs. If a popup is unavoidable, fire **once on the rising edge** with a non-blocking `CloseFcn` plus an Acknowledge button, and always pair with the persistent banner. See `references/alarm-patterns.md`.

---

### 8. Green for "normal" or "connected"

**Wrong:**
```matlab
% Connection lamp goes green when client connects
app.ConnLamp.Color = [0 0.6 0];
% Gauge normal band is green
g.ScaleColors      = [0.85 0 0; 1 0.7 0; 0 0.6 0; 1 0.7 0; 0.85 0 0];
```

**Right:**
```matlab
% Connection lamp: BLUE for "comms up"
app.ConnLamp.Color = [0.4 0.6 1.0];
% Normal band: GRAY (color-as-exception)
g.ScaleColors      = [0.85 0 0; 1 0.7 0; 0.5 0.5 0.5; 1 0.7 0; 0.85 0 0];
```

**Why:** Gray-field philosophy: color means *exception*. If "everything green" is the resting state, operators desensitize to green and miss the green that *does* matter (e.g., "operator must verify yes this is actively OK"). Connection state is communication health, not process health — blue (`[0.4 0.6 1.0]`) is reserved for comms/info; green (`[0 0.6 0]`) is reserved for verified-OK. See `references/color-and-layout-rules.md`.

---

### 9. Auto-scaling trend `YLim`

**Symptom:** gradual drift hides because the axis stretches with the signal; transient excursions lose context.

**Wrong:**
```matlab
ax = uiaxes(parent);                  % YLim = auto by default
animatedline(ax, 'MaximumNumPoints', 300);
```

**Right:**
```matlab
ax = uiaxes(parent, 'XLim', [0 300], 'YLim', [0 250]);   % fixed to sensor spec
yline(ax, 200, '--', 'Color', [1 0.7 0]);                % warn line
yline(ax, 230, '--', 'Color', [0.85 0 0]);               % alarm line
animatedline(ax, 'MaximumNumPoints', 300);
```

**Why:** Operators read trends positionally — "is this near the alarm line?" only works when the alarm line stays put. Auto-scale jumps with the signal and the alarm line moves with it. Provide a per-trend "auto-scale" toggle for exploration, but never as the default. See `references/trend-config-reference.md`.

---

### 10. 60-second trend window for a process variable

**Wrong:** `animatedline(ax, 'MaximumNumPoints', 60)` at 1 s update.

**Right:** `animatedline(ax, 'MaximumNumPoints', 300)` at 1 s update = 5-minute rolling.

**Why:** Process steps often take 1–3 minutes; a 60-second window can miss the entire transient. 5 minutes is the SCADA default. Adjust only when the user explicitly asks for a different window. See `references/trend-config-reference.md` for the buffer-sizing formula.

---

### 11. Inverting gray-field to a "dark-field" palette on a dark-mode request

**Wrong:**
```matlab
fig.Color = [0.12 0.13 0.15];                         % charcoal page
g.ScaleColors(3,:) = [0.25 0.25 0.27];                % dim "normal" band
```

**Right:**
```matlab
fig.Color = [0.78 0.78 0.78];                         % gray-field stays
% If pushed: a slightly dimmer gray-field, never below [0.6 0.6 0.6]
```

**Why:** A charcoal page with desaturated accents is *not* gray-field — it's a different convention that loses the empirical color-as-exception affordance operators expect from gray-field SCADA. ISA-101 doesn't have a dark variant. Reply to a dark-mode request with a one-sentence justification (control-room glare is solved by ambient lighting and monitor brightness, not by inverting the HMI palette) rather than inventing a hybrid.

---

### 12. Using `uilabel` for a precise numeric reading

**Wrong:**
```matlab
val = uilabel(panel, 'Text', sprintf('%.2f bar', currentValue));   % no read-only affordance
```

**Right:**
```matlab
val = uieditfield(panel, 'numeric', ...
    'Editable',           'off', ...
    'ValueDisplayFormat', '%.2f bar', ...
    'BackgroundColor',    [0.86 0.86 0.86], ...
    'HorizontalAlignment','right');
val.Value = currentValue;
```

**Why:** `uieditfield(..., 'Editable', 'off')` carries the read-only numeric affordance — right-aligned, fixed-format, distinguishable from a text label. A `uilabel` looks like metadata text, not a reading.

---

## Protocol-specific silent failures

### 13. Modbus `write()` argument order — `serverId` and `'precision'` swapped

**Symptom:**
> `Expected input number 5, serverId, to be one of these types: double, single, uint8, uint16, ...`

The spinner and confirm dialog work correctly, but the actual write call fails. The most common Modbus HMI write bug.

**Wrong (slots 5/6 swapped):**
```matlab
write(app.ModbusClient, 'holdingregs', addr, newVal, 'uint16', app.ServerId);
```

**Right (`serverId` BEFORE `'precision'`):**
```matlab
write(app.ModbusClient, 'holdingregs', addr, newVal, app.ServerId, 'uint16');
```

**Why:** The supported 6-arg signature is `write(m, target, address, values, serverId, 'precision')`. When `serverId` is the default 1, the 4-arg form `write(m, target, address, values)` is fine — fall back to that to avoid the order trap. See `references/protocol-cheatsheet.md` §Modbus.

---

### 14. MQTT `subscribe(c, topic, @cb)` — callback as positional arg

**Symptom:** subscription succeeds (`subscribe()` returns without error, broker shows the client subscribed), but the callback is never invoked. The live chart stays flat. No error.

**Wrong:**
```matlab
subscribe(app.MqttClient, topic, @(t, m) onMessage(app, t, m));
```

**Right (`Callback=` is a name-value pair):**
```matlab
subscribe(app.MqttClient, topic, ...
    Callback         = @(t, m) onMessage(app, t, m), ...
    QualityOfService = 1);
```

**Why:** `mqttclient`'s `subscribe` takes the callback as a name-value pair, not positional. Forgetting `Callback=` registers the subscription but the messages stay buffered (`read(c)` works, but live updates never fire). Sanity-check with `fprintf` of the topic+message inside the callback — if nothing prints, the registration is wrong. See `references/protocol-cheatsheet.md` §MQTT.

---

### 15. MQTT `str2double` on a JSON or comma-separated payload returns `NaN`

**Symptom:** the callback fires (you can see it logging) but the trace draws nothing.

**Wrong:**
```matlab
function onMessage(app, topic, message)
    val = str2double(message);            % returns NaN on '{"temp":72.5}' or '72.5,2026-06-08'
    addpoints(app.Trace, t, val);         % NaN passed to addpoints — silent no-op
end
```

**Right — decode per payload schema, then guard:**
```matlab
function onMessage(app, topic, message)
    val = str2double(message);            % adjust per payload schema
    if isnan(val), return; end            % skip malformed / non-numeric
    elapsed = seconds(datetime('now') - app.StartTime);
    addpoints(app.Trace, elapsed, val);
    drawnow limitrate;
end
```

For JSON broker payloads:
```matlab
function onMessage(app, topic, message)
    try
        s = jsondecode(message);
    catch
        return    % malformed JSON
    end
    if ~isfield(s, 'temp'), return; end
    addpoints(app.TempTrace, seconds(datetime('now') - app.StartTime), s.temp);
    drawnow limitrate;
end
```

**Why:** MQTT carries bytes — there's no schema layer. `str2double` returns `NaN` for any non-numeric payload, and `addpoints` silently no-ops on `NaN`. Always log the first message to `fprintf` while debugging, then pick the decode strategy that matches the payload.

---

### 16. Inventing widget labels that don't match OPC UA node names

**Symptom:** operator can't cross-reference the HMI with the OPC UA Explorer — the dashboard shows "Tank-level / Temperature / Pressure" but the server's namespace publishes `Sinusoid`, `Square`, `Constant`.

**Wrong:**
```matlab
% Hard-coded labels invented by the agent
makeWidget(app, "Tank-level", node1);
makeWidget(app, "Temperature", node2);
makeWidget(app, "Pressure", node3);
```

**Right — read names from the source:**
```matlab
nodeNames = string({nodes.Name});         % e.g., ["Constant","Square","Sinusoid"]
for i = 1:numel(nodes)
    makeWidget(app, nodeNames(i), nodes(i));
end
% In the data callback, use evt.Node.Name (or notification(i).Node.Name in
% Explorer-generated 3-arg vectorized callbacks) to dispatch.
```

**Why:** The HMI must mirror the source script's identifiers so the operator can cross-reference with the OPC UA server / Explorer. Inventing labels also hurts the agent later — it can't reconcile `"Tank-level"` against any node when the user reports a problem. See `references/protocol-cheatsheet.md` §OPC UA "Resolving Explorer-script identifiers to widget keys".

---

### 17. OPC UA Explorer-generated 3-arg callback flattened to 2 args

**Symptom:**
> `Too many input arguments.`

**Wrong:**
```matlab
function onDataChange(app, src, evt)        % 2 args (3 if you count `app`)
    % Explorer's vectorized notification doesn't fit here
end
```

**Right — match the Explorer's 3-arg vectorized shape:**
```matlab
function onDataChange(app, ~, notification, ~)
    nodes = [notification(:).Node];
    data  = [notification(:).Data];
    names = string({nodes(:).Name});
    vals  = [data(:).Value];
    elapsed = seconds(datetime('now') - app.StartTime);
    for i = 1:numel(names)
        w = app.Widgets(strcmp({app.Widgets.Key}, char(names(i))));
        if isempty(w), continue; end
        w.Display.Value = vals(i);
        if ~isempty(w.Trace), addpoints(w.Trace, elapsed, double(vals(i))); end
    end
    drawnow limitrate;
end
```

**Why:** Scripts generated by the OPC UA Explorer app pass a 3-argument `dataChangeCallback(subObj, notification, ~)` and `notification` is a struct array (vectorized — one entry per node that changed in the publish cycle). Match that shape exactly when wrapping an Explorer script. See `references/protocol-cheatsheet.md` §OPC UA.

---

### 18. Modbus poll timer without `BusyMode='drop'`

**Symptom:** UI stalls under slow Modbus responses; timer callbacks queue up.

**Wrong:**
```matlab
app.PollTimer = timer( ...
    'ExecutionMode', 'fixedSpacing', ...
    'Period',        1, ...
    'TimerFcn',      @(~,~) pollModbus(app));
```

**Right:**
```matlab
app.PollTimer = timer( ...
    'ExecutionMode', 'fixedSpacing', ...
    'BusyMode',      'drop', ...               % drop overlapping ticks
    'Period',        1, ...
    'TimerFcn',      @(~,~) pollModbus(app));
```

**Why:** Without `BusyMode='drop'`, slow Modbus responses queue overlapping callbacks until the GUI thread chokes. `'drop'` discards overlapping ticks instead — the trend gets a gap, but the UI stays responsive.

---

### 19. `evt.Value` instead of `evt.Data.Value` in OPC UA subscribe callback

**Symptom:** callback runs (no error), but no widget updates.

**Wrong:**
```matlab
function onDataChange(app, ~, evt)
    val = evt.Value;                  % undefined in R2026a — returns []
    app.Gauge.Value = val;            % silently does nothing
end
```

**Right (R2026a):**
```matlab
function onDataChange(app, ~, evt)
    val = evt.Data.Value;
    name = char(evt.Node.Name);
    app.Gauge.Value = val;
end
```

**Why:** The R2026a OPC UA `subscribe()` notification struct nests value data under `evt.Data` (`evt.Data.Value`, `evt.Data.Timestamp`, `evt.Data.Quality`) and the originating node under `evt.Node`. Older releases used different shapes — see `references/server-agnostic-discovery.md` for the contract.

---

### 20. Trend X axis collapses to a huge negative number from server-side timestamps

**Symptom:** trend draws an empty axis or a single point at the far left.

**Wrong:**
```matlab
elapsed = seconds(evt.Data.Timestamp - app.StartTime);
addpoints(trace, elapsed, val);            % evt.Data.Timestamp = 1601-01-01 → -large
```

**Right — wall-clock fallback:**
```matlab
elapsed = seconds(datetime('now') - app.StartTime);
addpoints(trace, elapsed, val);
```

Or validate the source timestamp first:
```matlab
ts = evt.Data.Timestamp;
if year(ts) < 1990
    elapsed = seconds(datetime('now') - app.StartTime);
else
    elapsed = seconds(ts - app.StartTime);
end
```

**Why:** Some servers (notably Python `asyncua`-based ones) return server-side timestamps as the 1601 epoch when the publisher hasn't supplied a source timestamp. The trend then draws at a large negative X and the user sees an empty axis. `datetime('now')` on the client is robust against this. See `references/known-schema-patterns.md` "Why wall-clock for trend X".

---

### 21. Subscription handle assigned to a local variable in a classdef

**Symptom:** `subscribe()` returns without error, the connection lamp shows connected, but the data-change callback never fires. No warning, no error.

**Wrong:**
```matlab
function startupFcn(app)
    sub = subscribe(app.UAClient, node, ...
        @(s, e) onDataChange(app, s, e));
    % 'sub' is local; GC'd at function exit → listener detaches → callback stops
end
```

**Right:**
```matlab
properties (Access = private)
    Subscription opc.ua.Subscription
end
% ...
function startupFcn(app)
    app.Subscription = subscribe(app.UAClient, node, ...
        @(s, e) onDataChange(app, s, e));
end
```

**Why:** `opc.ua.Subscription` is a handle whose listener registration on the underlying `opc.ua.Channel` is kept alive only while at least one MATLAB reference to the handle exists. A local variable in a method is GC-eligible the moment the method returns, so the handle is released and the listener detaches — even though the OPC UA session itself is still up. Storing the handle on a property keeps it alive for the life of the app. See `references/app-designer-gotchas.md`.

---

### 22. Trend `XLim` fixed at construction, never updated in callback

**Symptom:** trace draws normally for the first 5 minutes, then appears to "freeze" at the right edge. New points are still being added but the operator sees no movement.

**Wrong:**
```matlab
% Construction
ax = uiaxes(parent, 'XLim', [0 300], 'YLim', [0 250]);
trace = animatedline(ax, 'MaximumNumPoints', 300);
% ...
% Callback — only the buffer rolls; the axis never scrolls
function onChange(app, ~, evt)
    elapsed = seconds(datetime('now') - app.StartTime);
    addpoints(app.Trace, elapsed, evt.Data.Value);
    drawnow limitrate;
end
```

**Right — scroll the axis once past the window:**
```matlab
function onChange(app, ~, evt)
    elapsed = seconds(datetime('now') - app.StartTime);
    addpoints(app.Trace, elapsed, evt.Data.Value);
    if elapsed > 300
        app.TrendAxes.XLim = [elapsed - 300, elapsed];
    end
    drawnow limitrate;
end
```

**Why:** `animatedline`'s `MaximumNumPoints` rolls the *buffer* — old samples are discarded automatically. But the axis `XLim` set at construction never moves. Once `elapsed > 300`, new points are drawn at X coordinates outside `[0 300]` (off to the right of the visible axis), so they never appear. The fix updates `XLim` in the callback so the visible window slides in lock-step with the latest sample. See `references/trend-config-reference.md`.

---

### 23. `ScaleColors` set on a non-linear gauge

**Symptom:** no error, but no color bands appear on the gauge — the alarm thresholds set at construction are silently ignored.

**Wrong:**
```matlab
g = uigauge(parent, 'semicircular', 'Limits', [0 150]);
g.ScaleColors      = [0.5 0.5 0.5; 1 0.7 0; 0.85 0 0];
g.ScaleColorLimits = [0 90; 90 100; 100 150];   % silently ignored
```

**Right:**
```matlab
g = uigauge(parent, 'linear', 'Limits', [0 150]);
g.ScaleColors      = [0.5 0.5 0.5; 1 0.7 0; 0.85 0 0];
g.ScaleColorLimits = [0 90; 90 100; 100 150];
```

**Why:** `ScaleColors`/`ScaleColorLimits` are only honoured by `uigauge('linear')`. The `'semicircular'`, `'circular'`, and `'ninetydegree'` gauge styles accept the assignment without error but render no color bands. If the layout demands a non-linear gauge style and alarm bands are required, indicate alarm state with a colored frame, an adjacent `uilamp`, or a status badge. See `references/alarm-patterns.md` Pattern A.

---

### 24. Forgetting `Theme='light'` on the figure — child widgets stay dark on a dark-themed MATLAB desktop

**Symptom:** the figure background looks gray (because `Color = [0.78 0.78 0.78]` is set), but `uigauge` bodies, `uiaxes` panels, `uitable` rows, and `uieditfield` interiors all render near-black. Tick labels and legend text become unreadable. The dashboard "looks correct on the developer's machine, broken on the operator's machine."

**Wrong:**
```matlab
% Figure is gray, but child widgets inherit dark theme on a dark MATLAB desktop.
app.UIFigure = uifigure('Color', [0.78 0.78 0.78]);
```

**Right:**
```matlab
% Theme='light' blocks the dark-default inheritance on every child widget.
app.UIFigure = uifigure( ...
    'Color', [0.78 0.78 0.78], ...
    'Theme', 'light');
```

**Why:** on R2025b+ dark-themed MATLAB desktops, individual UI components inherit a dark theme from the OS / MATLAB even when the parent figure colour is set explicitly. Setting `BackgroundColor` on every panel does **not** propagate to gauge bodies, axes panels, or table internals — those have their own theme-driven defaults. `Theme='light'` is the single-point fix. The explicit gray-field `Color` keeps the result gray rather than the bright white that `'light'` would otherwise produce.

**Self-check after building:** open the app on the target machine. If any widget body looks darker than the figure background, you forgot `Theme='light'`. See `references/color-and-layout-rules.md` §Dark-theme defense for the rationale.

---

### 25. Direct AFSDK `.NET` calls instead of `piclient` / `afclient`

**Symptom:** the dashboard "talks to PI" but tag and AF-element search runs slowly, write calls error with type-coercion failures, trend axes show raw `System.DateTime` instead of `datetime`, and the code path doesn't work at all on a Linux/Mac developer machine. The script imports `NET.addAssembly('OSIsoft.AFSDK')` and calls into `OSIsoft.AF.PI.PIServers` / `OSIsoft.AF.PISystems`.

**Wrong:**
```matlab
NET.addAssembly('OSIsoft.AFSDK');
piServers = OSIsoft.AF.PI.PIServers();
piServer  = piServers.DefaultPIServer;
piPoint   = OSIsoft.AF.PI.PIPoint.FindPIPoint(piServer, 'Sinusoid');
afVal     = piPoint.CurrentValue();
val       = double(afVal.Value);     % manual .NET → MATLAB coercion
```

**Right:**
```matlab
piClient = piclient("MyPIServer");
matches  = tags(piClient, Name = "*Tank*");      % table — batched search
tt       = read(piClient, matches.Name);         % timetable — batched read

% PI Asset Framework (R2026a+):
afClient = afclient("MyAFServer", Database = "MyPlantDB");
elem     = findElementByName(afClient, "Boiler1");
attrs    = getAttributes(elem);
current  = read(attrs);                           % batched current-value read
hist     = readHistory(attrs(1), datetime("now") - hours(1), datetime("now"), ...
            Interval = seconds(10), AggregateFcn = "average");
```

**Why:** `piclient` (Industrial Communication Toolbox, R2022a+) and `afclient` (R2026a+) wrap the AFSDK and return native MATLAB types (`table`, `timetable`, `datetime`, `duration`), handle permission and connection errors with MATLAB exceptions, batch reads in a single round-trip, and integrate with the OSI PI app under MATLAB's **Apps** ribbon. Direct .NET interop reproduces all of this badly: every value crosses the `NET.System.*` ↔ MATLAB boundary one element at a time, errors surface as opaque `NET.NetException`s, and the code path simply doesn't load on Linux/macOS where the AFSDK isn't installable. The toolbox is also where any future improvements (subscribe-style streaming, server-side filtering) will land.

**Self-check:** verify the toolbox is licensed with `mcp__matlab__detect_matlab_toolboxes`, then `which piclient` and `which afclient`. If `afclient` doesn't resolve, the user is on a release older than R2026a — fall back to `piclient` only and document the dashboard as PI-Data-Archive-only.

See `references/pi-af-cheatsheet.md` for the full polling pattern, AF Attribute → widget mapping, and the AF write-back-via-`PITag` rule (the toolbox does not expose `Attribute.write`).

---

## Cross-references

- Workflow & widget selection: `references/widget-selection-flowchart.md`
- Color palette & layout hierarchy: `references/color-and-layout-rules.md`
- Alarm patterns (banner, source colors, latched + Acknowledge): `references/alarm-patterns.md`
- Trend buffer sizing & threshold lines: `references/trend-config-reference.md`
- Write safeguards (confirm, flash, E-Stop): `references/write-safeguards-reference.md`
- Per-protocol API shapes (OPC UA / Modbus / MQTT): `references/protocol-cheatsheet.md`
- OSI / AVEVA PI Data Archive and PI AF: `references/pi-af-cheatsheet.md`
- Browse-then-add flows: `references/server-agnostic-discovery.md`
- Hard-wired schemas: `references/known-schema-patterns.md`
- Subscription cleanup, listener leaks, `AccessLevelCurrent`: `references/app-designer-gotchas.md`

----

Copyright 2026 The MathWorks, Inc.

----
