# OSI / AVEVA PI Cheatsheet — PI Data Archive & PI Asset Framework

Use this when wrapping a script that talks to an **OSIsoft / AVEVA PI Data Archive** (`piclient`) or **PI Asset Framework** server (`afclient`) into an HMI. The Industrial Communication Toolbox provides first-party MATLAB clients for both — **always use those, not direct .NET AFSDK calls**.

If you only have time to read one section, read **Don't get this wrong** below.

## Decision rule

| User has a script using… | Pattern |
|---|---|
| `piclient(...)`, `tags(c, ...)`, `read(c, tag)`, `read(c, tag, DateRange=, Interval=, AggregateFcn=)` | §PI Data Archive — flat tag list, polling-timer trends |
| `afclient(...)`, `getRootElements`, `getChildren`, `getAttributes`, `Attribute.read`, `Attribute.readHistory` | §PI Asset Framework — hierarchical drill-down, write-back routes through `Attribute.PITag` to the PI client |
| `NET.addAssembly('OSIsoft.AFSDK')`, `OSIsoft.AF.PI.PIServers`, `OSIsoft.AF.PISystems` | **Replace it.** See "Don't get this wrong" #1 — convert to the toolbox client before doing anything else |

The PI client (`piclient`) is in the Industrial Communication Toolbox since **R2022a**; the AF client (`afclient`) since **R2026a**. Confirm with `mcp__matlab__detect_matlab_toolboxes` and `which afclient`/`which piclient` before relying on either.

## Don't get this wrong

1. **Use `piclient` / `afclient`. Do not call `NET.addAssembly('OSIsoft.AFSDK')` from MATLAB.** The toolbox wraps the AFSDK, returns native MATLAB types (`timetable`, `table`, `datetime`, `duration`), handles permission errors, and integrates with the OSI PI app on the **Apps** tab. Direct .NET interop reproduces all of that worse: tag/element search runs slowly because batch reads are bypassed, write calls fail on type-coercion edges, and trend axes show raw `System.DateTime`. Convert any `OSIsoft.AF.*` line you see to the corresponding toolbox call before moving on.
2. **No `subscribe()` on PI or AF.** Both clients are pull-based. Drive live HMI updates with a polling `timer(BusyMode='drop', ExecutionMode='fixedSpacing')` — same shape as Modbus, **not** OPC UA. Mixing in a fictional `subscribe(piClient, ...)` is a common hallucination — there is no such method.
3. **Reads return `timetable` / `table`, not raw arrays.** `pi.Client.read()` (snapshot or with `DateRange` / `Interval` / `AggregateFcn` for archive/aggregated reads) and `Attribute.readHistory` return `timetable` (rows = timestamps); `Attribute.read` returns a `table`. Index by row time / variable name, not by `numel(values)`.
4. **`Earliest` and `DateRange` on `pi.Client.read` are different modes.** Pass at most one: omit both for the latest snapshot, set `Earliest=true` for the first archived value, or `DateRange=[t0 t1]` for a window. Combining them is undefined.
5. **AF current-value writes are not exposed by the toolbox.** `icomm.af.Attribute` has no `write` method. To write a setpoint that the operator changed in the HMI, resolve the underlying PI tag via `attribute.PITag` and call the PI client's `write(piClient, attribute.PITag, value, TimeInstance=datetime("now"))`. Never invent `write(attribute, ...)` or `attribute.write(...)`.
6. **Connect on a Windows host with valid credentials.** The default `piclient(server)` / `afclient(server)` constructor uses the current Windows session. Add `Username`, `Password`, `Domain` name-values when the operator runs as a different identity. The toolbox is AFSDK-backed on Windows; confirm reachability on the deployment host with `which piclient` and a minimal `tags(c)` round-trip before building the dashboard.

## PI Data Archive

### Connect

```matlab
% Default: current Windows session
piClient = piclient("MyPIServer");

% Explicit Windows credentials (a different operator identity)
piClient = piclient("MyPIServer", ...
    Username = "operatorA", ...
    Password = "...", ...
    Domain   = "PLANT");
```

`piClient` is an `icomm.pi.Client` with public properties `ServerName` and `Domain`. Store it on the App: `app.PIClient = piClient;`.

### Search and list tags

```matlab
% Wildcard search → table with one row per matching tag
matches = tags(piClient, Name = "Sinusoid*");
% matches has columns including Name, Description, EngineeringUnits,
% PointSource, Zero, Span, Compressing, ...

% Single-tag lookup — pass an exact name to the same tags() call
oneTag = tags(piClient, Name = "Sinusoid");
```

`tags` returns a **table**; pass `matches.Name` (string array) directly into `read` for a batched current-value request — one round-trip rather than N.

### Read current value(s)

```matlab
% Single tag, latest snapshot → 1-row timetable
tt = read(piClient, "Sinusoid");
val = tt.Value(end);
ts  = tt.Time(end);

% Multiple tags in one call → timetable, one variable per tag
tt = read(piClient, ["Sinusoid", "SinusoidU", "CDT158"]);

% Earliest archived value
ttFirst = read(piClient, "Sinusoid", Earliest = true);
```

### Read interpolated / aggregated / archive history

`read(piClient, tag, ...)` is the **single public API** for archive and aggregated history — pass `DateRange` plus the appropriate name-value pairs. There is no `getInterpolatedValues`, `getRecordedValues`, or `getStartTimeOfTags`; treat any code that calls them as wrong and rewrite to `read`.

```matlab
% Raw archive points over the last 5 minutes (default AggregateFcn="none")
ttRaw = read(piClient, "Sinusoid", ...
    DateRange = [datetime("now") - minutes(5), datetime("now")]);

% Evenly spaced 1-second interpolated samples over the last 5 minutes
ttInterp = read(piClient, "Sinusoid", ...
    DateRange       = [datetime("now") - minutes(5), datetime("now")], ...
    Interval        = seconds(1), ...
    CalculationMode = "time");

% 1-minute average over the last hour
ttAvg = read(piClient, "Sinusoid", ...
    DateRange       = [datetime("now") - hours(1), datetime("now")], ...
    Interval        = minutes(1), ...
    AggregateFcn    = "average", ...
    CalculationMode = "time");
```

`AggregateFcn` accepts `"none" | "total" | "average" | "minimum" | "maximum" | "range" | "standard-deviation" | "population-standard-deviation" | "count" | "percent-good"`.
`CalculationMode` accepts `"event" | "time" | "time-continuous" | "time-discrete" | "event-exclude-recent" | "event-exclude-earliest" | "event-include-ends"`.

### Polling pattern (mirrors Modbus)

```matlab
% In startupFcn, after constructing the client and laying out widgets:
app.TagList   = ["Sinusoid", "SinusoidU", "CDT158"];
app.StartTime = datetime("now");

app.PollTimer = timer( ...
    ExecutionMode = "fixedSpacing", ...
    BusyMode      = "drop", ...
    Period        = 1, ...
    TimerFcn      = @(~,~) pollPI(app));
start(app.PollTimer);
```

```matlab
function pollPI(app)
    try
        tt = read(app.PIClient, app.TagList);   % batched → one round-trip
    catch ME
        app.StatusLabel.Text = "Read failed: " + ME.message;
        return
    end
    elapsed = seconds(datetime("now") - app.StartTime);
    for k = 1:numel(app.TagList)
        name = app.TagList(k);
        v    = tt.(name)(end);
        w    = app.Widgets(strcmp({app.Widgets.Key}, name));
        if isempty(w), continue; end
        w.Display.Value = v;
        if ~isempty(w.Trace)
            addpoints(w.Trace, elapsed, double(v));
        end
        updateAlarmState(app, name, v);
    end
    drawnow limitrate;
end
```

`BusyMode = "drop"` is mandatory — without it, slow archive responses queue up timer callbacks and the UI stalls. Stop and delete `app.PollTimer` in `delete(app)` (see `app-designer-gotchas.md`).

### Write (setpoint) with safeguards

```matlab
function applySetpoint(app)
    tag    = app.WriteTag;          % e.g. "SP_TankLevel"
    newVal = app.SetpointSpinner.Value;

    msg = sprintf("Write PI tag:\n\n  tag:   %s\n  value: %g", tag, newVal);
    sel = uiconfirm(app.UIFigure, msg, "Confirm Write", ...
        Options       = ["Apply","Cancel"], ...
        DefaultOption = "Cancel", ...
        CancelOption  = "Cancel", ...
        Icon          = "warning");
    if sel ~= "Apply", return, end

    try
        write(app.PIClient, tag, newVal, ...
            TimeInstance = datetime("now"));
        flashFeedback(app.SetpointSpinner, [0.7 1 0.7]);
    catch ME
        flashFeedback(app.SetpointSpinner, [1 0.7 0.7]);
        uialert(app.UIFigure, ME.message, "Write Failed");
    end
end
```

`pi.Client.write` is **R2024a+**. On older releases, write-back is not supported by the toolbox; either upgrade or document the dashboard as read-only. The confirm + flash + range-label pattern is identical to `write-safeguards-reference.md` — only the API call inside the `try` block differs.

### Built-in viewer (companion app)

`viewer(piClient)` launches the OSI PI viewer for ad-hoc browsing. Useful as a side window during HMI development, but the dashboard itself should not depend on it.

## PI Asset Framework

The AF model is hierarchical: **Database → Element (tree) → Attribute (per element)**. Mappings to HMI:

- **Database** ↔ choose at startup (`selectDatabase` or via the constructor name-value).
- **Root Elements** ↔ Level 1 plant overview tabs.
- **Child Elements** (`getChildren`) ↔ Level 2 area panels.
- **Attributes** of a leaf element (`getAttributes`) ↔ widgets on a Level 3 detail screen.

### Connect

```matlab
afClient = afclient("MyAFServer", Database = "MyPlantDB");

% Or pick the database after connecting:
afClient = afclient("MyAFServer");
dbs      = listDatabases(afClient);     % string array
selectDatabase(afClient, "MyPlantDB");
```

`afClient` is an `icomm.af.Client` with public properties `ServerName`, `Database`, `Domain`, `ServerTimeZone`.

### Browse the tree

```matlab
roots = getRootElements(afClient);            % icomm.af.Element array
boilers = findElementByName(afClient, "Boiler*");
b1 = findElementByPath(afClient, "\Plant1\Boilers\Boiler1");
allReactors = findElementByTemplate(afClient, "ReactorTemplate");

% Drill down
children = getChildren(boilers(1));           % child elements
attrs    = getAttributes(boilers(1));         % attributes on this element
attrTemp = getAttributes(boilers(1), "Temperature");
```

Each `Element` exposes `Name`, `Path`, `Database`, `Categories`, `Template`, `Description`, `NumChildren`, `NumAttributes`. Use `Path` as the widget key — it survives renames better than `Name` alone in deep trees.

### Read attributes

```matlab
% Current value → 1-row table with Name + Value (+ unit metadata)
attrs   = getAttributes(b1);
current = read(attrs);

% In a specific unit
inDegC  = read(attrs(1), Unit = "degree C");

% Historical → timetable
hist = readHistory(attrs(1), ...
    datetime("now") - hours(1), datetime("now"), ...
    Interval     = seconds(10), ...
    AggregateFcn = "average");

% What units does this attribute support?
units = listSupportedUnits(attrs(1));
```

### AF Attribute → widget mapping

Use the public properties on `icomm.af.Attribute` to classify each attribute the same way OPC UA HMIs classify nodes. Don't infer from the name.

| Attribute property                                                | Widget                                          |
|---|---|
| `HasTimeSeriesData = true`, numeric `ServerDataType`              | `uigauge` + `animatedline` trace + threshold lines |
| `HasTimeSeriesData = true`, boolean `ServerDataType`              | `uilamp`                                        |
| `HasTimeSeriesData = false`                                       | `uilabel` (static metadata — operator reference) |
| `WriteAccess` non-empty + numeric                                 | `uispinner` with `Limits`, **plus** confirm + flash (writes go via `attribute.PITag` + PI client) |
| `WriteAccess` non-empty + boolean                                 | `uistatebutton` + confirm + flash               |
| `DefaultUnit` non-empty                                           | Unit suffix label adjacent to the widget        |
| `listSupportedUnits(a)` returns multiple                          | Unit dropdown driving `read(a, Unit=...)`       |

### Write back to an AF attribute (route via PI)

`icomm.af.Attribute` has **no `write` method**. The supported route is to fetch the underlying PI point and write through the PI client:

```matlab
function applyAFSetpoint(app)
    a      = app.SetpointAttribute;       % icomm.af.Attribute
    newVal = app.SetpointSpinner.Value;

    if isempty(a.PITag) || a.PITag == ""
        uialert(app.UIFigure, ...
            "This AF attribute has no underlying PI tag — write not supported.", ...
            "Write Failed");
        return
    end
    if a.WriteAccess == ""
        uialert(app.UIFigure, ...
            "Attribute is not writable for this user.", "Write Failed");
        return
    end

    msg = sprintf("Write AF attribute:\n  element: %s\n  attribute: %s\n  PI tag: %s\n  value: %g %s", ...
        a.ElementName, a.Name, a.PITag, newVal, a.DefaultUnit);
    sel = uiconfirm(app.UIFigure, msg, "Confirm Write", ...
        Options       = ["Apply","Cancel"], ...
        DefaultOption = "Cancel", ...
        CancelOption  = "Cancel", ...
        Icon          = "warning");
    if sel ~= "Apply", return, end

    try
        write(app.PIClient, a.PITag, newVal, TimeInstance = datetime("now"));
        flashFeedback(app.SetpointSpinner, [0.7 1 0.7]);
    catch ME
        flashFeedback(app.SetpointSpinner, [1 0.7 0.7]);
        uialert(app.UIFigure, ME.message, "Write Failed");
    end
end
```

Both clients are needed when AF attributes are writable: keep `app.PIClient` and `app.AFClient` on the same App. If the deployment uses an AF web service backend without an associated PI Data Archive, document the dashboard as read-only for AF.

### Polling pattern for AF

```matlab
function pollAF(app)
    try
        currentVals = read(app.LeafAttributes);   % batched → one table
    catch ME
        app.StatusLabel.Text = "AF read failed: " + ME.message;
        return
    end
    elapsed = seconds(datetime("now") - app.StartTime);
    for k = 1:height(currentVals)
        name = currentVals.Name(k);
        v    = currentVals.Value(k);
        w    = app.Widgets(strcmp({app.Widgets.Key}, name));
        if isempty(w), continue; end
        w.Display.Value = v;
        if ~isempty(w.Trace)
            addpoints(w.Trace, elapsed, double(v));
        end
        updateAlarmState(app, name, v);
    end
    drawnow limitrate;
end
```

`read(attributeArray)` is batched — a single round-trip. Don't loop `read(a)` per attribute.

## Archive reads — where they belong in the HMI

Archive reads (`read(piClient, tag, DateRange=…, Interval=…, AggregateFcn=…)` and `Attribute.readHistory`) are **slow** compared to current-value reads. Place them on a "Trend Explorer" detail screen the operator opens deliberately, never on the always-on overview. The persistent banner, gauges, and 5-minute live trends all use the polling pattern above against current values; archive reads back-fill the trend on screen-open and respond to range changes from a date picker.

```matlab
% Open detail screen → fetch the configured window
function openTrendDetail(app, tag)
    t1 = datetime("now");
    t0 = t1 - app.HistoryWindow;       % e.g. hours(8)
    tt = read(app.PIClient, tag, ...
        DateRange       = [t0 t1], ...
        Interval        = app.HistorySampleEvery, ...   % e.g. seconds(10)
        CalculationMode = "time");
    plot(app.HistoryAxes, tt.Time, tt.(tag));
end
```

## Cross-references

- `widget-selection-flowchart.md` — once the AF-attribute or PI-tag classification is done, the widget choice is the same as for OPC UA / Modbus / MQTT.
- `write-safeguards-reference.md` — confirm + flash + range-label pattern; same shape for `write(piClient, …)`, `write(modbus, …)`, `writeValue(opcua, …)`. The PI write block above is the protocol-specific call inside the `try`.
- `protocol-cheatsheet.md` — the Modbus polling-timer block applies verbatim to PI / AF; cross-reference there for `BusyMode='drop'` rationale.
- `app-designer-gotchas.md` — timer cleanup in `delete(app)`, struct property defaults, listener leaks. PI/AF dashboards are timer-driven, so the cleanup gotcha matters.
- `common-mistakes.md` #25 — direct AFSDK `.NET` calls vs `piclient` / `afclient`.

----

Copyright 2026 The MathWorks, Inc.

----
