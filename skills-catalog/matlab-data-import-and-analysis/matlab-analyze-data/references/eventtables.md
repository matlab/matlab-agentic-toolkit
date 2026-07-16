# Eventtables

**Contents:** eventtable construction, attaching to timetables, eventfilter, extractevents, syncevents, withtol integration, interval events

An `eventtable` is a timetable of events that you attach to a data timetable. Each event has a time (when), optionally a duration (how long), optionally a label (what), and optionally additional data variables. Once attached, the timetable display annotates rows with their associated event labels, and event-aware functions (`eventfilter`, `syncevents`, `stackedplot`) work automatically.

## When to use eventtable (not state columns)

Use `eventtable` whenever information describes *something that happened* at or during certain times, rather than a continuous measurement. Signals to reach for eventtable:

- The information comes from a different source than the measured data (e.g., storm reports, maintenance logs, alarm systems, manual annotations)
- The information is sparse — only a few rows out of many have events
- Each event carries metadata (type, severity, cause, duration) beyond a simple true/false
- You need to filter, segment, or compare data by event properties
- You want timetable display to show annotations automatically

**Do NOT** add boolean columns (`TT.IsStorm`), string/categorical labels (`TT.EventType`), or numeric codes (`TT.Phase`) to represent events. These anti-patterns:
- Pollute the timetable with mostly-missing columns
- Cannot represent overlapping events or events with different metadata schemas
- Require manual logical indexing instead of `eventfilter` and `withtol`
- Lose the separation between measured data and event metadata

## Entering the eventtable ecosystem

Event info either comes from outside the timetable or is a pattern inside it — either way, get it into an eventtable before doing anything else. Match the entry pathway to how the event information reaches you:

- **Raw times/labels as separate vectors or arrays** (storm dates + storm types, alarm times, marker timestamps) — build with `eventtable(times, EventLabels=labels)` and attach via `TT.Properties.Events = ET`. Do not filter or align these arrays with logical indexing (`stormDates >= t0`, `ismember(TT.Time, stormDates)`) — that leaves you outside the eventtable ecosystem and forces manual work later.
- **A separate timetable of events** (alarm logs, storm reports, fire warnings) with its own metadata columns — pass the timetable directly to `eventtable(...)` and set `EventEndsVariable` if it has end times. Do not build `timerange` windows from the event times to slice the data timetable — attach and use `eventfilter` instead.
- **Patterns inside the data timetable itself** (peaks, threshold crossings, anomalies) — extract with `extractevents`, then attach. Do not add a boolean/label column (`TT.IsAnomaly = condition`) — that gives you a flag, not a reusable event object.

```matlab
% From vectors — the most common entry point
ET = eventtable(stormDates, EventLabels=stormTypes);
TT.Properties.Events = ET;

% Shorthand when you have times only (default labels)
TT.Properties.Events = eventTimes;

% From a separate timetable of events with a duration column
ET = eventtable(fireWarnings, EventEndsVariable="End");
flightData.Properties.Events = ET;

% From patterns inside the data
negEvents = extractevents(TT, TT.ExcessLOD < 0, EventDataVariables="ExcessLOD");
TT.Properties.Events = negEvents;
```

### Interval events (events with duration)

For events that span a time range (alarms, storm windows, maintenance periods) rather than instants:

```matlab
% Specify durations at construction
ET = eventtable(startTimes, EventLabels=labels, EventLengths=durations);

% Or add end times as a variable and declare which variable holds them
ET.EventEnds = endTimes;
ET.Properties.EventEndsVariable = "EventEnds";
```

After attaching, `TT` display shows event labels in the row margin, and `TT.Properties` shows the `Events` field.

## Filtering with `eventfilter`

`eventfilter` creates a row subscript that selects timetable rows occurring at (instantaneous) or during (interval) events.

```matlab
EF = eventfilter(TT);

% All rows at/during any event
TT(EF,:)

% Filter by event label
TT(EF.EventLabels == "Flood",:)

% Filter by any event data variable (dot-notation)
TT(EF.Severity == "High",:)
TT(EF.EngineNumber == 4,:)
```

`eventfilter` is distinct from `rowfilter`. `rowfilter` filters rows of a table/timetable by its own variables; `eventfilter` filters timetable rows by properties of attached events.

```matlab
% rowfilter: filter by the timetable's own variables
TT(rowfilter(TT).Value > 100,:)

% eventfilter: filter by attached event properties
TT(eventfilter(TT).EventLabels == "Storm",:)
```

### With `timerange` and `withtol`

Combine `eventfilter` with `timerange` to scope the timetable to a window defined by events, or with `withtol` to match rows within a tolerance of event times:

```matlab
EF = eventfilter(TT);

% Rows within a time tolerance of event times (± 5 seconds)
TT(withtol(EF, seconds(5)),:)

% Use events as timerange boundaries — "from event A through event B"
% Each endpoint must match exactly one event in the attached eventtable
TR = timerange(EF.EventLabels == "Thunderstorm Wind", EF.EventLabels == "Hail", "closed");
TT(TR,:)
```

## Extracting events from data

Use `extractevents` when the events are patterns in your timetable (threshold crossings, peaks, anomalies) rather than an external list. This is the correct approach when you identify interesting rows and want to mark them for future event-based analysis — do NOT add a boolean column like `TT.IsAnomaly = condition` because that only gives you a flag, not a reusable event object you can attach, filter by properties, or display as annotations.

```matlab
% By logical condition — extract rows where ExcessLOD is negative
negEvents = extractevents(TT, TT.ExcessLOD < 0, EventDataVariables="ExcessLOD");

% By row indices with labels
peaks = find(islocalmax(TT.Smoothed));
troughs = find(islocalmin(TT.Smoothed));
labels = categorical([zeros(size(peaks)); ones(size(troughs))], [0 1], ["peak" "trough"]);
ET = extractevents(TT, [peaks; troughs], EventLabels=labels);

% Two-output form: also returns a timetable with event-source variables removed
[ET, TT2] = extractevents(TT, condition, EventDataVariables="SrcVar");

% After extracting, attach back to the timetable for event-based workflows
TT.Properties.Events = negEvents;
TT(eventfilter(TT),:)           % now you can use eventfilter on extracted events
```

## Leaving the eventtable ecosystem

`syncevents` flattens event data into timetable variables — converting events back into a state representation. Use it only when the next step **cannot see attached event data**:

- **Writing to disk or converting the type**: `writetimetable`, `writetable`, `timetable2table`, or handing off to Python/Excel. `Properties.Events` doesn't survive any of these — flatten first with `syncevents`, then export.
- **Passing event metadata as a grouping key to `groupsummary`** (and similar functions that require the grouping variable to be a real timetable variable, not attached event data).

```matlab
% Export: flatten selected event variables, then write
TT_export = syncevents(TT, EventDataVariables="EventLabels");
writetimetable(TT_export, "weather_storms.csv");

% Group by event label: syncevents first, then groupsummary on the new variable
TT_flat = syncevents(TT, EventDataVariables="EventLabels");
groupsummary(TT_flat, "EventLabels", "mean", "MAX_TEMP");
```

For instantaneous events, only matching rows are filled with event data (others get missing values). For interval events, all rows within each interval are filled with that event's data.

**For everything else — filtering, comparison, visualization — keep events attached and use `eventfilter` / `stackedplot`.** Do not `syncevents` first and then filter on the new variables; that skips the eventfilter ecosystem.

```matlab
% Avoid: flatten, then filter on the new column
TT2 = syncevents(TT, EventDataVariables="EventLabels");
stormRows = TT2(TT2.EventLabels == "Storm",:);

% Avoid: flatten, then build subsets by label
TT2 = syncevents(TT, EventDataVariables="EventLabels");
hailRows = TT2(TT2.EventLabels == "Hail",:);
tornadoRows = TT2(TT2.EventLabels == "Tornado",:);

% Use instead: eventfilter on the attached events
TT(eventfilter(TT).EventLabels == "Storm",:)
TT(eventfilter(TT).EventLabels == "Hail",:)
TT(eventfilter(TT).EventLabels == "Tornado",:)
```

## Visualizing data with attached events

`stackedplot` is event-aware. When you call it on a timetable that has events attached, it automatically overlays them — vertical lines for instantaneous events, shaded regions for interval events — labeled with the event labels. No manual `patch`, `xline`, or `subplot` plumbing needed.

```matlab
% Attach events, then plot — overlays are automatic
TT.Properties.Events = ET;
stackedplot(TT)

% Plot specific variables only
stackedplot(TT, ["OilPressure" "Vibration"])

% Suppress the event overlay if you don't want it
stackedplot(TT, EventsVisible="off")
```

This is the right way to visualize sensor data around alarms, storms, maintenance windows, or any other interval/instant events. The annotations come from the attached eventtable — if you change the events (filter, add new ones, swap labels), the next `stackedplot` call reflects them.

## Avoid

### Do not add state columns to represent events

When you have event information (timestamps with labels, severities, durations), attach it via `eventtable` — do not embed it as timetable variables:

```matlab
% Avoid: boolean state column
TT.IsStorm = ismember(TT.Time, stormDates);

% Avoid: categorical/string state column
TT.StormType = repmat(missing, height(TT), 1);
TT.StormType(ismember(TT.Time, stormDates)) = stormTypes;

% Avoid: multiple state columns for event metadata
TT.EventActive = false(height(TT), 1);
TT.EventSeverity = strings(height(TT), 1);

% Use instead: eventtable (keeps events separate, enables eventfilter/withtol)
ET = eventtable(stormDates, EventLabels=stormTypes);
TT.Properties.Events = ET;
```

### Do not manually construct logical masks on timestamps to find event rows

When events are attached, use `eventfilter` — do not build logical index vectors from timestamp comparisons:

```matlab
% Avoid: logical mask for point events
mask = TT.Time == stormDates(1) | TT.Time == stormDates(2) | TT.Time == stormDates(3);
TT(mask,:)

% Avoid: manual >= / <= for interval events
mask = false(height(TT), 1);
for i = 1:numel(starts)
    mask = mask | (TT.Time >= starts(i) & TT.Time <= ends(i));
end
TT(mask,:)

% Avoid: isbetween loop for interval events
mask = false(height(TT), 1);
for i = 1:numel(starts)
    mask = mask | isbetween(TT.Time, starts(i), ends(i));
end
TT(mask,:)

% Use instead: eventfilter (handles point and interval events, property filtering)
EF = eventfilter(TT);
TT(EF,:)                           % all event rows
TT(EF.EventLabels == "Storm",:)    % filtered by label
```

### Do not use isbetween for approximate event matching

```matlab
% Avoid: manual tolerance window with isbetween
tol = seconds(5);
for i = 1:numel(eventTimes)
    idx = isbetween(TT.Time, eventTimes(i)-tol, eventTimes(i)+tol);
    nearby = TT(idx,:);
end

% Use instead: withtol (declarative, handles multiple events at once)
EF = eventfilter(TT);
TT(withtol(EF, seconds(5)),:)
```

### Do not build manual event overlays on plots

When events are attached, `stackedplot` draws the overlay automatically — do not construct it by hand with `subplot` + `plot` + `patch`/`xline`:

```matlab
% Avoid: manual subplot loop with patch overlays for each event
figure;
for i = 1:numel(vars)
    subplot(numel(vars),1,i);
    plot(TT.Time, TT.(vars{i})); hold on;
    yl = ylim;
    for j = 1:height(ET)
        patch([ET.Start(j) ET.End(j) ET.End(j) ET.Start(j)], ...
              [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.15);
    end
end

% Avoid: xline for each instantaneous event
plot(TT.Time, TT.Value); hold on;
for i = 1:numel(eventTimes)
    xline(eventTimes(i), '--r', labels(i));
end

% Use instead: attach events, then stackedplot
TT.Properties.Events = ET;
stackedplot(TT)
```

## Key behaviors

- An eventtable is a timetable. Functions like `retime`, `sortrows`, `head`, `tail`, and direct subsetting (`ET(ET.EventLabels == "peak",:)`) work on it.
- Adding rows to an eventtable by datetime subscript: `ET(newTime,:) = {label, endTime}`.
- Adding variables to an attached eventtable: `TT.Properties.Events.NewVar = data`.

---

Copyright 2026 The MathWorks, Inc.
