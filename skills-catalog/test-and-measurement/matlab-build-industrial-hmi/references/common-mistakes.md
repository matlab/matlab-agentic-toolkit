# Common Mistakes

Wrong/correct code pairs for the bugs that show up most often when wrapping a monitoring script into an HMI. Grouped by domain. Each entry has **Symptom → Wrong → Right → Why**, so the agent can match a user's reported failure mode without re-deriving the fix.

> **Look up one entry — don't read this file top to bottom.** It's a 33-entry lookup table.
> - **Have an error message?** `Grep` this file for a distinctive substring of it — most entries quote the exact string MATLAB prints.
> - **Chasing an anti-pattern by concept** (e.g. "green button", "forgot Theme")? Find it in the index below and `Grep` for its **Grep for** token.
>
> Then read only that one `### N.` block. Entry numbers are **stable** — external references cite them as "entry N", so they are never renumbered.

## Index

**App Designer language gotchas**

| # | Anti-pattern | Grep for |
|---|---|---|
| 1 | Typed `struct` property with no default → empty struct array | `dot name structure` |
| 2 | `function` block before `classdef` in the same file | `Only one class definition` |
| 3 | `delete()` on an `opc.ua.Subscription` | `Cannot access method 'delete'` |
| 4 | Repeated `subscribe()` accumulates channel listeners | `accumulate channel listeners` |
| 5 | Numeric `bitand` on a string `AccessLevelCurrent` (R2026a) | `bitand` |
| 32 | Teardown body on `CloseRequestFcn` instead of `delete(app)` | `Teardown body on` |

**ISA-101 / gray-field violations**

| # | Anti-pattern | Grep for |
|---|---|---|
| 6 | Single-click write to a setpoint / actuator (no confirm) | `Single-click write` |
| 7 | `uialert`/`uiconfirm`/`msgbox` for live process alarms | `alarm-fatigue` |
| 8 | Green for "normal" or "connected" | `Green for "normal"` |
| 9 | Auto-scaling trend `YLim` | `Auto-scaling trend` |
| 29 | Live trend left with its default pan/zoom toolbar | `default pan/zoom toolbar` |
| 10 | 60-second trend window for a process variable | `60-second trend window` |
| 11 | Inverting gray-field to a "dark-field" palette | `dark-field` |
| 12 | `uilabel` for a precise numeric reading | `precise numeric reading` |
| 26 | Green Start / red Stop command buttons | `Green Start` |
| 27 | `BackgroundColor` on a switch / lamp / knob → hard error | `Unrecognized property BackgroundColor` |
| 28 | `FontColor` on a `uitable` / `uipanel` → hard error | `Unrecognized property FontColor` |
| 30 | Alarm banner recolored without setting `FontColor` | `banner without FontColor` |
| 31 | Latched alarm severity with no Acknowledge control | `latched with no Acknowledge` |

**Protocol-specific silent failures**

| # | Anti-pattern | Grep for |
|---|---|---|
| 13 | Modbus `write()` arg order — `serverId`/`'precision'` swapped | `serverId` |
| 14 | MQTT `subscribe` callback as a positional arg | `callback as positional` |
| 15 | MQTT `str2double` on a JSON / CSV payload → `NaN` | `str2double` |
| 16 | Inventing widget labels that don't match node names | `Inventing widget labels` |
| 17 | OPC UA Explorer 3-arg vectorized callback flattened to 2 args, or `notification` read as scalar | `flattened to 2` |
| 18 | Modbus poll timer without `BusyMode='drop'` | `BusyMode` |
| 19 | `evt.Value` instead of `evt.Data.Value` (OPC UA) | `nests value data` |
| 20 | Trend X axis collapses from 1601-epoch server timestamps | `1601` |
| 21 | Live-data handle (subscription, timer, client, trace) in a local variable | `local variable in a classdef` |
| 22 | Trend `XLim` fixed at construction, never scrolled | `never updated in callback` |
| 23 | `ScaleColorLimits` outside the gauge `Limits` (bands silently clipped) | `silently clipped` |
| 24 | Forgetting `Theme='light'` → child widgets stay dark | `near-black` |
| 25 | Direct AFSDK `.NET` calls instead of `piclient`/`afclient` | `AFSDK` |

**Verification and hand-off**

| # | Anti-pattern | Grep for |
|---|---|---|
| 33 | Design-report numbers retyped from intent, or keys renamed / nested / pretty-printed | `re-shaped design-report` |

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

**The one exemption:** when **no range exists to fix it to** — an MQTT topic or a Modbus holding register whose engineering range the source script never states, and the user hasn't given one — autoscale is the honest choice. Leave `YLim` on auto, label the axis `<unit> (no spec range)`, and write that on the spec's trend row so the reviewer can supply the range. This is the only case; a range you could have read off the node, the register table, or the user's prompt is not "no range exists". See `references/server-agnostic-discovery.md`, which routes a rangeless numeric here.

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

**Symptom:** either `Too many input arguments.` (wrong arg count), **or** the callback runs but only the first node ever updates — `notification` was read as a scalar (`notification.Node.Name`) when the Explorer delivers it as a struct array.

**Wrong:**
```matlab
function onDataChange(app, src, evt)        % 2 args (3 if you count `app`)
    % Explorer's vectorized notification doesn't fit here
end
% ...or the right arg count but scalar access — only node 1 updates:
% val = notification.Data.Value;   % ignores notification(2:end)
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

**Why:** Scripts generated by the OPC UA Explorer app pass a 3-argument `dataChangeCallback(subObj, notification, ~)` and `notification` is a struct array (vectorized — one entry per node that changed in the publish cycle). Two things must match, not one: the **arg count** (3, or 4 counting `app`) *and* the **vectorized access** (`notification(:).Node` / iterate `notification(i)`), never scalar `notification.Node`. Match that shape exactly when wrapping an Explorer script. See `references/protocol-cheatsheet.md` §OPC UA.

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

### 21. Live-data handle assigned to a local variable in a classdef

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

**This is not an OPC UA rule — it is the rule for every live-data handle.** The same GC releases a `timer` (it never fires, so a Modbus or PI dashboard sits at its startup values forever), a `modbus`/`piclient`/`mqttclient` client (the next poll errors on a deleted object), and an `animatedline` (`addpoints` throws on an invalid handle, so the trend stays empty). **Every handle the app touches after `startupFcn` returns lives on a property** — client, subscription, timer, and one trace handle per trend. If a widget owns its own subscription or trace, store it on that widget's struct entry (see #4). The spec template has an App-state row for exactly this, and the self-audit box "every timer, client, subscription and line handle has an App state row" is the check.

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

### 23. `ScaleColorLimits` outside the gauge `Limits` (bands silently clipped)

**Symptom:** no error, but the warn/alarm bands never appear — the gauge shows only the normal band, or no band at all. Applies to every gauge style (linear, semicircular, circular, ninetydegree).

**Wrong:**
```matlab
g = uigauge(parent, 'semicircular');            % Limits left at default [0 100]
g.ScaleColors      = [0.5 0.5 0.5; 1 0.7 0; 0.85 0 0];
g.ScaleColorLimits = [0 200; 200 230; 230 250]; % warn/alarm bands lie above 100 - clipped
```

**Right:**
```matlab
g = uigauge(parent, 'semicircular', 'Limits', [0 250]);   % node spec range first
g.ScaleColors      = [0.5 0.5 0.5; 1 0.7 0; 0.85 0 0];
g.ScaleColorLimits = [0 200; 200 230; 230 250];
```

**Why:** the gauge draws only the part of each band that falls inside `Limits`; a band wholly outside is accepted without error and drawn nowhere. `ScaleColors`/`ScaleColorLimits` are honoured by all four gauge styles (verified on R2026a), so the fix is never a different style — it is setting `Limits` to the node's spec range so every threshold band lies inside it. See `references/alarm-patterns.md` Pattern A.

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

### 26. Green Start / red Stop command buttons

**Symptom:** the HMI looks like a consumer app — a green "START" button and a red "STOP" button. On a plant screen this is an ISA-101 violation: it burns the two alarm colors on always-visible chrome, so a genuine red alarm no longer stands out, and a red Stop button reads as "Stop is in an alarm state."

**Wrong:**
```matlab
% Traffic-light / play-button prior — the single most common reflex
uibutton(g, 'Text', 'START', 'BackgroundColor', [0 0.6 0],   'FontColor', [1 1 1]);
uibutton(g, 'Text', 'STOP',  'BackgroundColor', [0.85 0 0],  'FontColor', [1 1 1]);
```

**Right:**
```matlab
% Neutral chrome; differentiate by label. Run/stopped state lives on a separate lamp.
uibutton(g, 'Text', 'START');    % default gray face
uibutton(g, 'Text', 'STOP');     % default gray face
% Equipment state indicator (blue = running, gray = idle) — NOT on the button:
lamp = uilamp(g, 'Color', [0.5 0.5 0.5]);   % gray idle; set blue when running
uilabel(g, 'Text', 'Stopped');
```

**Why:** color means *exception*. Buttons are present on the screen no matter what the process is doing, so they carry no status meaning and must stay neutral gray. Green `[0 0.6 0]` is reserved for operator-verified-OK and red `[0.85 0 0]` for critical alarms; spending them on buttons desensitizes the operator and steals contrast from real alarms. Say *what pressing does* with the label; say *what the equipment is doing* with a separate lamp/badge. The one convention-based exception is a red E-Stop (it mirrors the physical mushroom button operators are trained on) — even then, pair it with a confirm-both-engage-and-release dialog rather than leaning on color. This holds on both the programmatic and the `matlab-build-app` serialization paths. See `references/color-and-layout-rules.md` §"Command buttons and controls are neutral" and `references/write-safeguards-reference.md` for E-Stop.

---

### 27. `BackgroundColor` on a switch, lamp, knob, or checkbox

**Symptom:** construction dies outright — the app never builds:
> `Error using uiswitch`
> `Unrecognized property BackgroundColor for class RockerSwitch`

This is the trap laid by the neutral-chrome rule itself: "switches must be neutral widget gray"
reads as *set `BackgroundColor` to `[0.86 0.86 0.86]`*, and on a switch that property does not
exist.

**Wrong:**
```matlab
% Trying to apply the neutral-chrome palette value to a switch
toggle = uiswitch(g, 'rocker', 'Items', {'Fixed','Auto'}, ...
    'BackgroundColor', [0.86 0.86 0.86]);      % ERRORS — no such property
lamp = uilamp(g, 'BackgroundColor', [0.5 0.5 0.5]);   % ERRORS — lamps use Color
```

**Right:**
```matlab
% Switches are neutral already — don't paint them. Tint the container instead.
wrap   = uigridlayout(g, [1 1], 'BackgroundColor', [0.86 0.86 0.86], 'Padding', [4 4 4 4]);
toggle = uiswitch(wrap, 'rocker', 'Items', {'Fixed','Auto'});

% A lamp's state color is Color, not BackgroundColor — and that IS the ISA-101 signal.
lamp = uilamp(g, 'Color', [0.5 0.5 0.5]);      % gray idle
```

**Why:** verified on R2026a, `BackgroundColor` **does not exist** on `Switch`, `RockerSwitch`,
`ToggleSwitch`, `Lamp`, `CheckBox`, or `Knob`. It **does** exist on `Button`, `StateButton`,
`Spinner`, `DropDown`, `EditField`, `NumericEditField`, `TextArea`, `Label`, `Table`, `Panel`,
`GridLayout`, and the gauges. Unlike a band clipped outside the gauge `Limits` (entry 23), this fails
loudly rather than silently — which is better, but it still costs the whole build. Check
`isprop(h,'BackgroundColor')` if unsure. See `color-and-layout-rules.md` §"Command buttons and
controls are neutral".

---

### 28. `FontColor` on a `uitable` or `uipanel`

**Symptom:** construction dies outright — the app never builds:
> `Error using uitable`
> `Unrecognized property FontColor for class Table.`

Same trap as entry 27, one property over. The gray-field rule says every widget needs an
explicit text-color override, and `FontColor` is the right name on almost every component — so
it gets carried onto the node table, where the property is `ForegroundColor`.

**Wrong:**
```matlab
% Carrying FontColor from the label/button recipes onto a table or panel
app.FlowTable = uitable(g, ...
    'BackgroundColor', [0.86 0.86 0.86], ...
    'FontColor',       [0.10 0.10 0.10]);      % ERRORS — no such property on Table
app.Group = uipanel(g, 'Title', 'Flows', 'FontColor', [0.10 0.10 0.10]);   % ERRORS too
```

**Right:**
```matlab
% Tables and panels spell it ForegroundColor.
app.FlowTable = uitable(g, ...
    'BackgroundColor', [0.86 0.86 0.86], ...
    'ForegroundColor', [0.10 0.10 0.10]);
app.Group = uipanel(g, 'Title', 'Flows', 'ForegroundColor', [0.10 0.10 0.10]);

% Inside uistyle it IS FontColor — that's a style object, not the table.
s = uistyle('BackgroundColor', [0.85 0 0], 'FontColor', [1 1 1]);
addStyle(app.FlowTable, s, 'row', alarmedRows);
```

**Why:** verified on R2026a, `uitable` and `uipanel` are the two components in a typical HMI that
carry `ForegroundColor` and **not** `FontColor`. Everything else you paint — `Label`, `Button`,
`EditField`, `NumericEditField`, `Spinner`, `DropDown`, `ListBox`, `TextArea`, `CheckBox`,
`RockerSwitch`, and both gauge shapes — carries `FontColor` and not `ForegroundColor`. The
`uistyle` object used for conditional row coloring is the confusing case: it takes `FontColor`,
because the style is not the table. Like entry 27 this fails loudly, and like entry 27 it costs
the whole build. Check `isprop(h,'FontColor')` if unsure.

### 29. Live trend left with its default pan/zoom toolbar

**Symptom:** nothing errors and nothing looks wrong. The trend has a correct fixed `YLim`, unit
labels and threshold `yline`s — then an operator brushes the axes, the hover toolbar appears, and
one drag or scroll silently rescales the live trend. From then on the axis lies about the process:
a value above the alarm threshold can sit mid-axis looking unremarkable, the `yline`s move off
screen, and **nothing in the UI records that the view was moved**. The next shift inherits it.

`uiaxes` ships with `Toolbar.Visible = 'on'` and a full `DefaultAxesInteractionSet`, so this is
the default state, not something anyone opted into. It is the same failure as entry 9 — an axis
that no longer means what its labels claim — arriving by interaction instead of by construction,
which is why fixing entry 9 alone does not cover it.

**Wrong:**
```matlab
ax = uiaxes(parent, 'XLim', [0 300], 'YLim', [0 250]);   % fixed limits...
ylabel(ax, 'Temperature (°C)');
yline(ax, 230, '--', 'Color', [0.85 0 0]);
% ...and left interactive: pan, zoom, datatips and restore-view all live
```

**Right:**
```matlab
ax = uiaxes(parent, 'XLim', [0 300], 'YLim', [0 250]);
ylabel(ax, 'Temperature (°C)');
yline(ax, 230, '--', 'Color', [0.85 0 0]);

% A live trend is a read-only instrument.
ax.Toolbar.Visible = 'off';
ax.Interactions    = [];
```

**Why:** verified on R2026a — setting `Toolbar.Visible='off'` and `Interactions=[]` leaves
`YLimMode` at `'manual'` and the limits settable, so the fixed-`YLim` contract is unaffected;
only operator-initiated rescaling goes away. This does not remove exploration, it relocates it:
the sanctioned mechanism is the explicit per-trend autoscale toggle in
`references/trend-config-reference.md`, which is a visible control with a known state an operator
and a reviewer can both read. An ad-hoc drag has neither. Caught by a smoke-test screenshot, not
by any code review — the defect is invisible in source and only shows up in a running app.

---

### 30. Alarm banner recolored without setting `FontColor`

**Symptom:** the banner works. It goes amber on warning and saturated red on critical, lists the
right nodes, spans row 1. Then the one state that matters most is the hardest to read: near-black
text on `[0.85 0 0]`. Nothing errors, a screenshot at full size looks acceptable, and the defect
only bites at the distance a control-room screen is actually read from.

This happens because `BackgroundColor` is state-driven while `FontColor` usually is not, so it gets
set once at construction — or not at all, leaving the default — and then never revisited. A banner
is the one widget whose face crosses from a light neutral to two saturated colors, so it is the one
widget where a fixed font color cannot be right for every state.

**Wrong:**
```matlab
% Constructed once, near-black on panel face — correct for exactly one of four states
app.Banner = uilabel(g, 'FontColor', [0.10 0.10 0.10], ...
    'BackgroundColor', [0.86 0.86 0.86]);
...
app.Banner.BackgroundColor = [0.85 0 0];    % critical: text is now unreadable
```

**Right:**
```matlab
% FontColor moves with BackgroundColor, in the same branch
switch severity
    case "critical"
        app.Banner.BackgroundColor = [0.85 0   0];
        app.Banner.FontColor       = [1 1 1];
    case "warning"
        app.Banner.BackgroundColor = [1 0.7 0];
        app.Banner.FontColor       = [0.10 0.10 0.10];
    otherwise
        app.Banner.BackgroundColor = [0.86 0.86 0.86];
        app.Banner.FontColor       = [0.10 0.10 0.10];
end
```

**Why:** ISA-101 picks a muted red so it does not glare, which also means it is dark — dark enough
that near-black text on it has almost no contrast. White text restores it. The rule generalizes to
any state-colored widget: if `BackgroundColor` is assigned in a branch, `FontColor` belongs in the
same branch. Pattern B in `references/alarm-patterns.md` shows it wired correctly.

---

### 31. Latched alarm severity with no Acknowledge control

**Symptom:** the first alarm of the shift turns the banner red and it never goes back. Values
return to normal, gauges drop into their gray bands, and the banner still reads critical — because
latching is doing exactly what it was asked to do and nothing in the UI can clear it. Operators
learn to ignore the banner, which is the alarm-fatigue failure ISA-18.2 exists to prevent, reached
from the opposite direction to entry 7's popups.

The usual cause is a design document: "latched severity" is written into a spec or a hand-off note
because it is the standard SCADA behavior, while the Acknowledge button that makes it work is left
to be inferred. It never is.

**Wrong:**
```matlab
% Latch on the rising edge, and nothing anywhere clears it
if value >= app.HighCritical
    app.AlarmLatched = true;
end
% ...no Acknowledge button in the layout
```

**Right — pick one deliberately.** Either latch *and* give it a control:
```matlab
app.AckButton = uibutton(g, 'Text', 'ACK', 'BackgroundColor', [0.86 0.86 0.86], ...
    'ButtonPushedFcn', @(~,~) acknowledge(app));
app.AckButton.Enable = matlab.lang.OnOffSwitchState(app.AlarmLatched && ~app.AlarmActive);
```
or do not latch, and track active severity instead:
```matlab
app.AlarmActive = value >= app.HighCritical;   % clears on its own when the value returns
```

**Why:** latching is a promise that something can un-latch it. `AlarmLatched` with no writer that
clears it is a one-way state machine, and the banner becomes a permanent decoration rather than an
indicator. Pattern C in `references/alarm-patterns.md` gives the latched pair; Pattern B gives the
active-severity alternative. In a spec hand-off, the word and the button ship together or neither
does — a consumer building from the document cannot invent the control.

---

### 32. Teardown body on `CloseRequestFcn` instead of `delete(app)`

**Symptom:** the window closes and the app keeps running. A poll timer fires every second against
deleted widgets, so the command window fills with
> `Invalid or deleted object.`

minutes after the operator closed the screen, and `timerfindall` still lists the timer. The client
stays connected, holding its session on the server. Closing by hand seems to work — the leak only
shows up when something closes the app *programmatically*, which is how every test, script, and eval
closes it.

**Wrong:**
```matlab
% Teardown hung off the figure's close callback
app.UIFigure.CloseRequestFcn = @(~,~) shutdown(app);
...
function shutdown(app)
    stop(app.PollTimer);
    delete(app.PollTimer);
    disconnect(app.Client);
    delete(app.UIFigure);
end
```

**Right:**
```matlab
methods (Access = public)
    function delete(app)                    % the destructor owns teardown
        if ~isempty(app.PollTimer) && isvalid(app.PollTimer)
            stop(app.PollTimer);
            delete(app.PollTimer);
        end
        app.Subscription = opc.ua.Subscription.empty;   % no public delete - entry 3
        if ~isempty(app.Client)
            disconnect(app.Client);
        end
        if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
            delete(app.UIFigure);
        end
    end
end
...
app.UIFigure.CloseRequestFcn = @(~,~) delete(app);   % routes only, no body
```

**Why:** `CloseRequestFcn` runs only when something asks the *figure* to close — the window's X, or
`close(fig)`. `delete(app)` deletes the figure directly and never invokes it, so a teardown that
lives there is skipped exactly in the automated path. Putting the body in `delete(app)` covers both
directions: the destructor runs when the object is deleted, cleared, or goes out of scope, and the
one-line `CloseRequestFcn` funnels the operator's click into the same code. This is also why the
verification step in the workflow exercises `delete(app)` rather than `close(fig)` — it is the path
that finds this bug.

---

### 33. A retyped or re-shaped design-report readback

**Symptom:** two shapes, one cause. Either the verification report carries confident numbers that
never came from MATLAB — `figureColor` is `[0.78 0.78 0.78]` because that is what the code *says*,
not because anything read it back — or the report is real but unreadable downstream: keys renamed or
nested, JSON pretty-printed, the file written into a subfolder. In both cases the step that exists
to catch a discrepancy reports none, and a silently clipped alarm band (entry 23) or an autoscaling
trend (entry 9) ships.

**Wrong:**
```matlab
% Numbers from memory of what was written, keys invented on the spot
report.figure.Color = [0.78 0.78 0.78];      % nested: "Color" collides with any earlier Color
report.gauges       = 4;                     % counted by reading the constructor calls
report.callback     = 'polls every second, updates gauge and trend';   % a summary, not the code
fid = fopen(fullfile(pwd, 'reports', 'design-report.json'), 'w');      % subfolder
fwrite(fid, jsonencode(report, 'PrettyPrint', true));
```

**Right:** copy `assets/designReportReadback.m` beside the app **verbatim**, keeping its filename —
it is a function, so there is nothing to edit. Call it with the app class and its spec file:
`designReportReadback("<AppClass>", "<AppClass>-hmi-spec.md")` (inline via `evaluate_matlab_code` is
fine — a function's local functions resolve when the function is called). It constructs the app, reads the
values off the live figure, extracts the callback and the write calls from the source, and writes a
compact flat `design-report.json` at the top level of the working folder, then runs `delete(app)` and
reports leaked figures and timers:
```matlab
report.figureColor = fig.Color;                                  % read back, not declared
report.gaugeCount  = numel(findall(fig, 'Type', 'uilineargauge'));
report.callbackExcerpt = char(capChars(liveDataCallback(src), 3000));   % fileread + regexp
fwrite(fid, jsonencode(report));                                 % compact, PrettyPrint off
```

**Why:** a number typed from memory is the *intent* restated, and intent cannot disagree with itself
— which is the entire value of the readback. `fig.Color` read off the constructed figure can come
back `[0.94 0.94 0.94]` when a theme overrode it; a declared `[0.78 0.78 0.78]` never will. The
shape rules are just as load-bearing, because the report is consumed by exact-key extraction: flat
unique names (a nested `"Color"` is ambiguous with every other `"Color"`), compact encoding, scalars
first with the code excerpt last, top level of the working folder, and no draft printed before the
real file is written. Full contract: `assets/design-report-schema.json`.

**Self-check after every run:** open `design-report.json` and confirm its first key is
`"reportFormat":"hmi-report/1"` and the flat scalars are present (`gaugeCount`,
`writePathsWithConfirm`, `autoscaleTrendAxisCount`, …). If it is nested (a `gauges[]` array, a
`dataWiring` object) or missing keys, it was re-authored — delete it and re-run the **unchanged**
function. Hand-written numbers discard the only check that catches a silently clipped alarm band
(entry 23) or an autoscaled trend (entry 9).

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
