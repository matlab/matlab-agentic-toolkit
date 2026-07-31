# AppDesignerAgentInterface: `.mlapp` Guide

Read `agent-guide-shared.md` first. This file covers what is specific to binary
`.mlapp` apps.

## Ownership model: the tool owns everything

For `.mlapp`, the tool owns the whole app — the component tree AND the code. You
build the entire app through verbs; nothing is hand-edited on disk (a `.mlapp` is a
single binary file). So **all verbs are available**, including the component verbs
(`addComponent`, `setProperty`, `removeComponent`, `moveComponent`, `addCallback`).

This is the opposite of plaintext, where you hand-author the component tree in `.xml`.

## Build flow

```matlab
appBuilder = AppDesignerAgentInterface.create("C:/path/MyApp.mlapp");

% Figure (root, already exists as "UIFigure")
appBuilder.setProperty("UIFigure", "Position", [100 100 320 400]);
appBuilder.setProperty("UIFigure", "Name", "My App");

% Components
appBuilder.addComponent("Label", "StatusLabel", "UIFigure", struct( ...
    'Position', [20 350 280 30], 'Text', 'Hello', 'FontSize', 16));
appBuilder.addComponent("Button", "GoButton", "UIFigure", struct( ...
    'Position', [110 175 100 32], 'Text', 'Go'));

% Callbacks: wire the event, then set the body
appBuilder.addCallback("GoButton", "ButtonPushedFcn", "onGo");
appBuilder.setCallbackCode("onGo", "app.StatusLabel.Text = ""Clicked!"";");

% App-level state + startup
appBuilder.addProperty("Count", "", "private");
appBuilder.addCallback("UIFigure", "StartupFcn", "startupFcn");
appBuilder.setCallbackCode("startupFcn", "app.Count = 0;");

% Helper methods (FULL function text)
appBuilder.addMethod("reset", strjoin([ ...
    "function reset(app)" ...
    "    app.Count = 0;" ...
    "end" ], newline), "private");

appBuilder.save();
```

### Property values are native MATLAB values

Unlike plaintext `.xml`, mlapp props go straight through the verb as real MATLAB
values. Pass them natively:
- color: `[0.2 0.6 0.9]` (RGB triplet, or a column vector is coerced)
- string: `'Go'` or `"Go"`
- numeric: `28`
- logical: `true`

No quoting-inside-a-string dance — that is a plaintext-only concern.

**Cell-valued properties need DOUBLE braces in the `struct(...)` call.** A property
whose value is itself a cell array (e.g. a `DropDown`/`ListBox` `Items` list) is a
MATLAB `struct()` trap: `struct()` treats a single cell array as *struct-array
construction*, so `struct('Items', {'10%','20%'})` builds a **1x2 struct array**, not
one struct with a two-element `Items`. Wrap the cell in an outer brace to keep it as a
scalar struct field:

```matlab
% WRONG — makes a 1x2 struct array, not what you want:
%   struct('Items', {'10%','20%'})
% RIGHT — double brace keeps Items as one cell-array value on one struct:
appBuilder.addComponent("DropDown", "TipDrop", "UIFigure", struct( ...
    'Position', [20 20 120 22], 'Items', {{'10%','20%'}}, 'Value', '20%'));
```

This applies to any cell-valued property (`Items`, `ItemsData`, etc.). Scalar values
(numbers, chars, RGB triplets, logicals) need no such wrapping.

**Exactly DOUBLE braces — never triple.** The outer brace is consumed by `struct()`;
one pair leaves the flat cell you want. A *third* pair over-wraps it into a cell
containing a cell, which stores silently and then fails at `save()`. This is easy to
hit with a mixed cell like a grid's `RowHeight`:

```matlab
% WRONG — triple brace over-wraps to {{80 '1x' 60}} (a cell holding a cell):
%   struct('RowHeight', {{{80, '1x', 60}}})
% RIGHT — double brace gives the flat {80, '1x', 60}:
appBuilder.addComponent("GridLayout", "Grid", "UIFigure", struct( ...
    'RowHeight', {{80, '1x', 60}}, 'ColumnWidth', {{'1x', '1x'}}));
```

For the known flat-cell props (`RowHeight`, `ColumnWidth`, `Items`, `ItemsData`) the
`AppDesignerAgentInterface` **rejects** the over-wrapped form with `AppDesignerAgentInterface:overWrappedCell` rather
than letting it fail opaquely at save.

### Property order does not matter (coupled properties handled for you)

Some components have **coupled properties that must be applied in a specific order**.
The classic case: a `DropDown`'s `Value` must be one of its `Items`, so `Items` has to
be set before `Value`. If you set `Value` first, the product rejects it
(`'Value' must be an element defined in the 'Items' property`).

**You do not have to worry about this.** Pass properties in whatever order is natural
in your struct — the tool reorders them into App Designer's own canonical order at
materialization time, using the same ordering the product uses for code generation
(`VisualComponentAdapter.getCodeGenPropertyNames`). So both of these are equivalent
and both work:

```matlab
% Value listed before Items in the struct — still fine:
appBuilder.addComponent("DropDown", "ModeDrop", "UIFigure", struct( ...
    'Position', [20 20 120 22], 'Value', 'Fast', 'Items', {{'Slow','Fast'}}));
```

This also means a `save() -> open() -> save()` round-trip on an app containing one of
these components no longer fails (an earlier version reordered the property bag on
reopen and broke re-save; that is fixed).

The components with order-dependent property pairs, grouped by pattern (the tool
handles all of them; this is reference, not a checklist you must follow):

| Coupling pattern | Components | Rule the tool enforces |
|---|---|---|
| Selection list -> selected value | `DropDown`, `ListBox`, `Switch`, `ToggleSwitch`, `RockerSwitch`, `DiscreteKnob` | `Items` / `ItemsData` before `Value` |
| Numeric range -> value | `Slider`, `Knob`, `NumericEditField`, `Spinner` | `Limits` (and ticks / `Step`) before `Value` |
| Gauge range -> value | `Gauge`, `LinearGauge`, `SemicircularGauge`, `NinetyDegreeGauge` | `Limits` / `MajorTicks` / `MajorTickLabels` before `Value` |
| Date range -> value | `DatePicker` | `Limits` / `DisabledDates` / `DisplayFormat` before `Value` |

Two notes for the curious: `ValueIndex` is ignored by codegen for `DropDown`/`Switch`
(the `Items`-before-`Value` constraint is enforced at set-time, not via an index), and
`ButtonGroup` has no `Value` at all (its selection is `SelectedObject`, a child handle).
None of this changes what you do — set properties in any order.

## `save()` for mlapp: atomic, gate-then-write

Because a partial write to a binary file is unrecoverable corruption, mlapp `save()`
is atomic:

1. Materialize the model into live component objects **once**.
2. Write to a unique temp path.
3. Round-trip re-read it (serialization integrity), then run the **real product
   loader** on the temp (the same strict gate as opening it in App Designer).
4. Only if both pass, atomically copy onto the real path.

If the gate fails, the real file is **never touched** and `save()` throws
(`MlappBackend:loadFailed` or `MlappBackend:erroredComponents`, naming the component).

## `finalize()`: bake it runnable and open it for viewing

**mlapp only.** `save()` writes a lightweight **stub**: component handle properties,
callback bodies, custom props/methods, and a bare `AppBase` constructor — but NOT
the runnable body (`createComponents`, `registerApp`, callback wiring,
`runStartupFcn`). App Designer regenerates that body itself. `finalize()` automates
exactly that, headlessly:

```matlab
AppDesignerAgentInterface.finalize("C:/path/MyApp.mlapp");            % default 60s deadline
AppDesignerAgentInterface.finalize("C:/path/MyApp.mlapp", 120);       % raise deadline
```

It launches App Designer, waits until the app is fully open and ready, saves (AD
bakes the full runnable classdef to disk), and **leaves the app open in App Designer
for the user to view** — baking it runnable and showing it are the same action. It
does not close the app.

- Cost: ~3-5s warm, up to ~16s on a cold AD launch.
- Requires a live App Designer / connector session (the save routes through AD's JS
  code engine). Works headless (no `-desktop` needed).
- Only needed when you want the app to **run directly** or be **viewed**. If you are
  going to keep editing via `AppDesignerAgentInterface`, you do not need to finalize between edits —
  `save()` alone keeps the file loadable in App Designer.
- **Reopening after finalize is safe — keep editing freely.** Because finalize saves
  *through the live product*, App Designer bakes the live component state into the file,
  including read-only runtime properties (e.g. `UIAxes.NextSeriesIndex`). `open()`
  filters those out (it only reads publicly-settable props), so a
  `finalize() -> open() -> edit -> save()` cycle round-trips cleanly. Finalize is never
  a dead end, and you never need to rebuild from scratch to edit a finalized app.

### finalize deadline / wedge behavior (know this)

App Designer can wedge (e.g. a modal dialog if a file changed under it), and the
open/save waits have no built-in timeout. `finalize` runs under a hard-deadline
watchdog:
- If the **open** wait exceeds the deadline, it aborts and throws
  `AppDesignerAgentInterface:finalizeTimeout` **without closing anything** — you recover
  manually (close App Designer / the stuck app, then retry, or raise
  `deadlineSeconds`).
- A save-side wedge is rare (save on an already-open, ready app is fast); it is
  intentionally NOT force-closed either, to honor the "never close an app the caller
  did not ask us to touch" rule.

## Posture-A guard: editing an app the user may have open

`create()` and `open()` release the file from App Designer **before** touching disk
(AD holding a stale copy while the file is rewritten triggers a wedging reload
dialog). The guard:
- If AD holds the file with **unsaved edits** -> it **rejects** (never discards your
  work): close or save it in App Designer first, then retry.
- If AD holds a **clean** copy -> it closes that copy and proceeds.

So it is safe to `open()` and edit an app that is currently open in App Designer, as
long as it has no unsaved changes.

**Where unsaved changes come from — do NOT blame `finalize()`.** `finalize()` saves the
app *through* the product and leaves it open **clean** (no pending edits). So a reject
on `AppDesignerAgentInterface:appOpenAndModified` after a finalize means the **user** edited the
app in App Designer since then — not that finalize failed to save. Tell the user that
plainly ("the app has unsaved edits in App Designer; save or close it and I'll
continue"), and never say the changes came from the finalize step. The recovery is the
same either way (user saves/closes, you retry), but the cause you report must be
correct.

## The edit path (open an existing mlapp)

```matlab
appBuilder = AppDesignerAgentInterface.open("C:/path/MyApp.mlapp");
appBuilder.setProperty("UIFigure", "Color", [0.13 0.12 0.23]);
appBuilder.setProperty("GoButton", "BackgroundColor", [0.20 0.72 0.68]);
appBuilder.save();
```

`open()` reads the binary, converts the live object graph to a plain model, and hands
you a normal editable handle. There is no cross-file consistency check for mlapp (one
binary file, no drift); the loadability guarantee is the `save()` gate.

**Do not re-`create()` to edit an existing `.mlapp`, and do not rebuild the app from
scratch to make a change.** Edit = `open()` + the minimal verbs + `save()`. Call
`inspect()` first to see current geometry and existing code names before you mutate —
see "Editing an existing app" in the shared guide, which covers inspect-first,
read-modify-write for code, and the overwrite warning. All component verbs
(`addComponent`, `setProperty`, `removeComponent`, `moveComponent`, `addCallback`) are
available on the opened model.

### Sub-object properties (UIAxes Title, XLabel, YLabel, etc.)

Some component properties hold handle objects that cannot be replaced wholesale. On
UIAxes: `Title`, `XLabel`, `YLabel`, `ZLabel`, `Subtitle` are all
`matlab.graphics.primitive.Text` objects. Use **dot-path syntax** to set their
sub-properties individually:

```matlab
appBuilder.setProperty("UIAxes", "Title.String", "Revenue");
appBuilder.setProperty("UIAxes", "Title.FontSize", 14);
appBuilder.setProperty("UIAxes", "XLabel.String", "Quarter");
appBuilder.setProperty("UIAxes", "YLabel.String", "Amount ($)");
```

Do NOT pass a struct for these properties. This will error with guidance:
```matlab
% WRONG: throws subObjectRequiresDotPath
appBuilder.setProperty("UIAxes", "Title", struct('String', 'Revenue'));
```

## Known-good patterns (verified)

- Shared callback across many buttons via `event.Source` (e.g. a 3x3 board all wired
  to one `CellPushed`) — dedupes to one generated function.
- RGB triplets, `FontWeight`, color props all pass Layer-1 and the loader gate.
- **Containers are NOT transparent — color them explicitly.** A `GridLayout` has its own
  `BackgroundColor` and a `Panel` its own `BackgroundColor`; they do not show the figure
  `Color` through. If you set `UIFigure.Color` for a themed look, the grid/panel sitting
  on top still paints its default gray unless you set its `BackgroundColor` too. To carry
  one color across the app, set it on the figure AND every `GridLayout`/`Panel` in the
  tree (a bare figure `Color` alone leaves visible gray blocks).
- **`addProperty` defaults are VALUES, not code.** A char/string default is emitted as a
  quoted literal, so `addProperty("InputType", "Step")` yields `InputType = 'Step'` (the
  string `'Step'`), and `addProperty("Count", 0)` yields the number `0`. A string is NEVER
  treated as a code expression: `addProperty("Buf", "zeros(1,10)")` gives the char
  `'zeros(1,10)'`, NOT a numeric array. To initialize richer state (a computed value, an
  array, a handle, a timer), declare the property bare with `addProperty(name, "", "private")`
  and assign it in `startupFcn` (e.g. `app.Buf = zeros(1,10);`). That is the App Designer
  idiom: property defaults are for literal values, startup code is for everything computed.
- **User Authored Components (UAC) are not supported.** You cannot `addComponent` a
  UAC. The workaround: instantiate it in `StartupFcn` (e.g.
  `app.MyGauge = MyGaugeComponent(app.UIFigure);`) and set layout/properties there. It
  will work at runtime but will not appear in Design View. If the user needs it visible
  in Design View, suggest they add it manually in App Designer; on subsequent `open()`
  calls `AppDesignerAgentInterface` can access it normally via `setProperty`/`getProperty`.

## Backup and recovery

`open()` copies the existing `.mlapp` file to `<filepath>.backup` **before any
mutation**. This is a single rolling recovery point — overwritten on every `open()`
call. It is NOT created on first `create()`.

### If the user reports their app looks broken

**Do NOT call `open()` again.** Calling `open()` on the corrupted file will overwrite
`.backup` with the corrupted state, destroying the only recovery point.

Instead, diagnose without opening:

1. Check the error output from the failed session — what did `open()` or `save()`
   report?
2. If the error mentions unparseable code, the app's editable section likely has
   invalid MATLAB syntax (missing `...` continuations, unclosed brackets, etc.). The
   user must fix this manually in App Designer before the API can open the file.
3. If the edit session completed without error but the app looks wrong, inspect the
   file non-destructively (e.g., read the generated code via `FileReader`) to
   understand what changed.

Only as a **last resort** — when the app is irrecoverably broken and no targeted fix
is possible — restore from backup:

```matlab
copyfile('MyApp.mlapp.backup', 'MyApp.mlapp');
```

After restoring, the user should reopen in App Designer to confirm correctness before
any further programmatic edits.

----

Copyright 2026 The MathWorks, Inc.

----
