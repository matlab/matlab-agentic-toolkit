# Known-Schema Patterns

Use this reference when the **node set is fixed at design time** — you have a list of OPC UA nodes (names, types, ranges, units) before the dashboard ever connects. The agent isn't browsing the server; it's wiring a known process to a known UI.

If instead the user asks to *explore* a server and pick nodes interactively, switch to `references/server-agnostic-discovery.md` — the dispatch shape there infers widgets from `class(value)` at runtime and uses per-widget subscriptions.

## When to use

- Customer hands you a node list (e.g., a Yokogawa export, a Siemens DB map, a documented OPC UA address space)
- You're building a screen for one specific station whose I/O is frozen
- The dashboard ships with a fixed list of gauges/lamps/trends, no "Add Node" UI

In these cases, hard-wiring node name → widget is fine and reads more clearly than a generic dispatcher. Node count is small (typically < 30 per screen), names rarely collide, and editing the file is the right way to add a node.

## Multi-node dispatch with a `switch` on node name

```matlab
% Build node list once at startup
nodeList = [findNodeByName(uaClient.Namespace, 'WeldRobot1_Temp', '-once'), ...
            findNodeByName(uaClient.Namespace, 'OvenTemp',         '-once'), ...
            findNodeByName(uaClient.Namespace, 'PressPressure',    '-once')];

sub = subscribe(uaClient, nodeList, @(src, evt) onDataChange(app, src, evt), ...
    PublishInterval = 0.5);
```

```matlab
function onDataChange(app, ~, evt)
    % evt is opc.ua.Notification (R2026a):
    %   evt.Node.Name       - originating node's display name
    %   evt.Data.Value      - current value
    %   evt.Data.Timestamp  - server/source timestamp (see "trend X" note below)
    name    = char(evt.Node.Name);
    val     = evt.Data.Value;
    elapsed = seconds(datetime('now') - app.StartTime);   % wall-clock; see note

    switch name
        case 'WeldRobot1_Temp'
            app.WeldRobot1Gauge.Value = val;
            addpoints(app.WeldRobot1Trace, elapsed, val);
            updateAlarmState(app, 'WeldRobot1', val);
        case 'OvenTemp'
            app.OvenGauge.Value = val;
            addpoints(app.OvenTrace, elapsed, val);
            updateAlarmState(app, 'Oven', val);
        case 'PressPressure'
            app.PressGauge.Value = val;
            addpoints(app.PressTrace, elapsed, val);
            updateAlarmState(app, 'Press', val);
    end
    drawnow limitrate;
end
```

For >10 nodes, replace the `switch` with a `dictionary` keyed on node name to a function handle, so the dispatch doesn't grow into a wall of cases:

```matlab
handlers = dictionary();
handlers('WeldRobot1_Temp') = @(app, t, v) updateWeldRobot1(app, t, v);
handlers('OvenTemp')        = @(app, t, v) updateOven(app, t, v);
handlers('PressPressure')   = @(app, t, v) updatePress(app, t, v);
% in callback:
if isKey(handlers, name)
    h = handlers(name);
    h(app, elapsed, val);   % MATLAB rejects chaining a call after parens-indexed dictionary fetch
end
```

## Why wall-clock for trend X

Pattern 4 in SKILL.md plots elapsed seconds on the X axis. The intuitive source is `evt.Data.Timestamp - app.StartTime`, but some servers (notably Python `asyncua`-based ones) return the **server-side** timestamp as the 1601 epoch when the publisher hasn't supplied a source timestamp. The trend then draws at `elapsed = -large_number` and the user sees an empty axis. `datetime('now')` on the client is robust against this.

If you need true source timing for your application, validate `evt.Data.Timestamp` first:

```matlab
ts = evt.Data.Timestamp;
if year(ts) < 1990
    elapsed = seconds(datetime('now') - app.StartTime);   % fallback
else
    elapsed = seconds(ts - app.StartTime);
end
```

## Subscribe once, never rebuild

For a fixed schema, build the node list once at startup, call `subscribe()` once, and store the resulting `opc.ua.Subscription` on the app. Don't resubscribe — there is no per-subscription cleanup API in R2026a, and rebuilding leaks channel listeners. See `app-designer-gotchas.md` "Repeated `subscribe()` calls leak channel listeners".

----

Copyright 2026 The MathWorks, Inc.

----
