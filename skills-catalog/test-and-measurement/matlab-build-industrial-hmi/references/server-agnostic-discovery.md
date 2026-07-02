# Server-Agnostic Discovery

Use this reference when the user wants the dashboard to **explore an unknown OPC UA server** and pick nodes interactively, instead of being wired to a fixed node schema. The widget for each node is inferred from the value's MATLAB class (and `EURange`, if the server publishes one), not from a node list known up front.

If the node list *is* known up front, use `references/known-schema-patterns.md` instead — `switch`-on-name is clearer there.

## When to use

- User says "browse the server", "let me pick nodes", "I don't know the schema", or asks for a generic SCADA explorer.
- You're building a one-off operator screen against a server you didn't write (a customer's PLC, a third-party device, an `asyncua` simulator).
- The server's namespace will be walked at runtime via `client.Namespace` rather than read from a documented address map.

## Discovery flow

1. **Connect.** `client = opcua(host, port); connect(client);`. Surface connection state in a top-corner lamp (blue when up — green is reserved for verified-OK process state).
2. **Walk the namespace into a `uitree`.** Recurse `client.Namespace`; create a `uitreenode` per OPC UA node whose `NodeClass` is `Variable`. Stash the underlying `opc.ua.Node` in `uitreenode.NodeData` so you can recover it on selection. Object/Folder nodes become parent tree nodes but aren't selectable for widgets.
3. **On node selection, do a one-shot `readValue`.** Use the returned value's class (and the node's `EURange` if present) to populate a "Widget type" dropdown with only the choices that fit. Use the [Widget-by-MATLAB-class](#widget-by-matlab-class) table below.
4. **Use `AccessLevelCurrent` to mark writable nodes.** A read-only node should not surface setpoint/toggle widgets in the dropdown. R2026a returns this as a string — see `app-designer-gotchas.md` for the release-aware writability check.
5. **On "Add to Dashboard", subscribe per widget.** Build the widget UI, append to `app.Widgets`, then call `subscribe(client, opcNode, …)` and store the resulting `opc.ua.Subscription` on the widget. **Never** rebuild a single global subscription — that leaks channel listeners (`app-designer-gotchas.md` "Repeated `subscribe()` calls leak channel listeners").

## Node property names (R2026a)

When you stash and recall an `opc.ua.Node`, use these property names:

| Property | Holds |
|---|---|
| `Name` | Display name (string) |
| `Identifier` | OPC UA node identifier (**not** `NodeId`) |
| `NamespaceIndex` | Namespace index |
| `NodeClass` | `'Variable'`, `'Object'`, `'Method'`, etc. |
| `AccessLevelCurrent` | `'read'` / `'read/write'` / ... (string in R2026a) |
| `EURange` | Engineering-unit range, when published (struct with `Low`/`High`) |

The `Identifier` name trips agents that expect `NodeId` from older docs. `node.NodeId` errors with *"No public field NodeId"*.

## Widget-by-MATLAB-class

The dropdown of widget options is computed from `class(readValue(client, node))` and writability:

| `class(val)` | Read-only options | Writable options |
|---|---|---|
| `logical` | Lamp, Status Badge | Toggle Switch (with `uiconfirm`) |
| `numeric` (with `EURange`) | Gauge (linear/semicircular), Trend (5-min, fixed YLim), Numeric Readout | Setpoint spinner (`Limits=EURange`) + Send button + `uiconfirm` |
| `numeric` (no range) | Numeric Readout, Trend (auto-Y, marked "no spec range") | Numeric edit field + `uiconfirm` |
| `char` / `string` | Status Badge | Read-only label (writable strings are rare in process I/O — surface but warn) |
| `int*` enum-like (≤ 6 distinct values seen in a short sampling) | Status Badge styled per value | Dropdown of seen values + `uiconfirm` |
| `datetime` | Numeric Readout (formatted) | (not typical — usually informational) |
| anything else | Numeric Readout (auto-coerced via `string(val)`) | (no writable widget by default) |

**EURange detection.** Some servers publish a `Range` or `EURange` property as a child node alongside the value; others expose it as a node attribute. Probe with `getProperties(node)` (Industrial Communication Toolbox) and fall back to "no range" if absent. Don't auto-pick a Gauge for a numeric without a known range — gauges without limits look broken.

**Enum heuristic.** "Enum-like" is detected by sampling: if a numeric/integer value's distinct readings stay ≤ 6 unique values across the first N notifications, offer Status Badge. This is heuristic, not authoritative — OPC UA `Enumeration` types should ideally be detected via `DataType`, but many servers don't surface it cleanly.

## Per-widget subscription pattern

```matlab
properties (Access = private)
    % Each widget owns its Subscription; cleanup happens via disconnect(client).
    Widgets struct = struct( ...
        'Key', {}, 'Node', {}, 'Type', {}, 'Card', {}, ...
        'Display', {}, 'Trace', {}, 'Axes', {}, ...
        'Limits', {}, 'Units', {}, 'StartTime', {}, ...
        'UpdatedLabel', {}, 'Sub', {});
end

function onAddNode(app, opcNode, widgetType)
    w = buildWidget(app, opcNode, widgetType);   % constructs the UI card
    app.Widgets(end+1) = w;
    idx = numel(app.Widgets);
    relayoutDashboard(app);

    try
        app.Widgets(idx).Sub = subscribe(app.UAClient, opcNode, ...
            @(src, evt) onDataChange(app, src, evt), ...
            PublishInterval = 0.5);
    catch ME
        uialert(app.UIFigure, ME.message, 'Subscribe failed');
    end
end
```

## Discovery-friendly data callback

The dispatcher matches incoming notifications back to the widget by node name:

```matlab
function onDataChange(app, ~, evt)
    % evt is opc.ua.Notification (R2026a). evt.Node is the originating node.
    name    = char(evt.Node.Name);
    val     = evt.Data.Value;
    elapsed = seconds(datetime('now') - app.StartTime);   % see note

    w = app.Widgets(strcmp({app.Widgets.Key}, name));
    if isempty(w), return; end

    switch w.Type
        case 'Lamp'
            w.Display.Color = onOffColor(val);
        case 'Status Badge'
            w.Display.Text  = formatBadge(val);
            w.Display.BackgroundColor = badgeColor(val);
        case {'Gauge (linear)', 'Gauge (semicircular)'}
            w.Display.Value = val;
        case 'Trend (5-min)'
            addpoints(w.Trace, elapsed, double(val));
        case 'Numeric Readout'
            w.Display.Value = double(val);
    end
    if ~isempty(w.UpdatedLabel)
        w.UpdatedLabel.Text = char(datetime('now'), 'HH:mm:ss');
    end
    drawnow limitrate;
end
```

**Wall-clock for trend X.** Some servers (notably Python `asyncua`) return server-side timestamps as the 1601 epoch when the publisher doesn't supply a source timestamp. `evt.Data.Timestamp - app.StartTime` then yields a large negative number and trends draw outside the X window. Default to `datetime('now')` and only switch to the source timestamp after validating it's plausible (e.g., `year(ts) >= 1990`).

## Common discovery mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Treating `evt.Value` as the value | Callback runs but no widget updates; no error thrown | Use `evt.Data.Value` (R2026a) |
| Treating `src` as the node and reading `src.Name` | "No public property 'Name'" or it returns the subscription's name | Read `evt.Node.Name` |
| Numeric `bitand` on `AccessLevelCurrent` | Writable nodes never get setpoint widgets | String-aware `isWritable()` from `app-designer-gotchas.md` |
| Single global `Subscription`, rebuilt on each add | "Too many input arguments" warnings on every notification after the second add | Subscribe per widget, store `Sub` on the widget |
| `delete(sub)` to clean up | "Cannot access method 'delete' in class 'opc.ua.Subscription'" | Drop the handle; let `disconnect(client)` clean up at app close |
| Auto-pick Gauge for numeric with no range | Gauge displays with `[0 1]` default limits and looks broken | Require `EURange`; otherwise default to Numeric Readout or Trend with auto-Y |
| Picking widget from `node.DataType` only | Misclassifies servers that publish `Variant` everywhere | Drive widget selection from `class(readValue(...))`, with `DataType` as a tiebreaker |

## Cross-references

- Pattern 6 in SKILL.md — the discovery-friendly callback shape used as the inline default.
- `app-designer-gotchas.md` — `AccessLevelCurrent` string handling, subscription cleanup, listener-leak gotcha.
- `widget-selection-flowchart.md` — semantic (process-domain) widget selection; complements this file's class-driven table when range/units are known after browsing.

----

Copyright 2026 The MathWorks, Inc.

----
