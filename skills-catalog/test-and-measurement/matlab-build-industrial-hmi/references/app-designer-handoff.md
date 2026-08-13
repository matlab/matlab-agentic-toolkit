# App Designer Build & Serialization — Hand-off to `matlab-build-app`

This skill owns **what an industrial HMI is** (gray-field, alarms-at-source, write
safeguards, fixed-range trends, protocol wiring). It does **not** own the mechanics of
building and serializing an App Designer app — that belongs to the `matlab-build-app`
skill, which bundles the `AppDesignerAgentInterface` tool. Design the HMI here; hand the
finished design to the parent to persist it.

**The parent is the single source of truth for all serialization mechanics.** Everything
about *how* to drive `AppDesignerAgentInterface` — the verb reference, which file format
to emit (`.mlapp` vs plain-text `.m`), release requirements, `save()`/`validate()`/
`finalize()` semantics, chunked-call discipline, editing an existing app, and the
callback-vs-method rules — lives in the parent's
`references/app-designer/agent-guide-shared.md` (then the format-specific
`agent-guide-mlapp.md`). Read it before driving the API; it may change per release, so do
not rely on any mechanic restated from memory. This file covers only what is
**HMI-specific** and must not be delegated.

**Fallback:** when the parent is unavailable, fall back to the programmatic-`.m` path the
other references describe — no HMI content changes, just a different output format. The
generated app runs identically; it just won't open in App Designer.

---

## Division of labor

| Concern | Owner | Notes |
|---|---|---|
| Serialization, file format, lifecycle, verb API | **parent** | `references/app-designer/agent-guide-shared.md` — the authority |
| UIFigure structural mechanics (grid, panels, components, callback wiring) | **parent** | parent `references/uifigure/*` |
| Editing an existing App Designer app | **parent** | `open()` + `inspect()` + minimal verbs + `save()` |
| Layout archetype skeleton | **parent** | plant overview ≈ **Dashboard**; area/detail ≈ Dashboard/Explorer |
| MVVM for large multi-screen HMIs | **parent** (optional) | parent `references/uifigure/mvvm-guide.md` |
| Architecture (UIFigure vs UIHTML) | **short-circuit** | HMI is **always UIFigure** — don't ask |
| Serialization format choice | **short-circuit** | default **`.mlapp`** — don't ask unless the user wants source-controllable app files |
| Theming / colors / dark mode | **HMI — override** | gray-field is mandatory; **never** route to `matlab-apply-theme` |
| Trends | **HMI — override** | `animatedline` + fixed `YLim` + `yline`; **never** route to `matlab-build-chart` |
| Protocol wiring, alarms-at-source, write safeguards, widget selection, quantity caps | **HMI** | pure domain |

The two overrides are deliberate: the parent delegates color to `matlab-apply-theme` (which
supports dark mode) and plots to `matlab-build-chart` (general-purpose axes). Both
conflict with HMI rules — keep them here.

---

## Hand-off protocol

1. **Design first, here.** Classify nodes → pick widgets → lay out by hierarchy → plan
   alarms, trends, writes, protocol wiring, using this skill's references. The parent
   never decides HMI content.
2. **Read the parent's docs before driving the API.** The parent's
   `references/app-designer/agent-guide-shared.md` (then `agent-guide-mlapp.md`) is the
   single source of truth for the verbs, file-format decision, and lifecycle. For
   structure, parent `references/uifigure/*` and `references/archetypes/dashboard.md`.
3. **Drive `AppDesignerAgentInterface`** per the parent guide, applying the HMI→verb
   mapping below for the domain-specific choices (gray-field, alarm bands, palette).
4. **Open it in App Designer once** at the very end so the user sees it rendered. (The
   parent guide calls this `finalize()`; never say "finalize" to the user — offer it as
   "open it in App Designer so you can take a look.")

**Editing an existing HMI** — to add alarms/writes/trends to an app that already exists,
do not rebuild it: `open()` + `inspect()` + minimal verbs + `save()`. The *what to add*
is HMI domain (below); the *how* is the parent's editing discipline — see its shared
guide.

---

## HMI → verb mapping

The snippets below apply the HMI domain rules through `AppDesignerAgentInterface`. `ab` is
the handle returned by the parent's `create(...)`/`open(...)`. **For verb syntax and
gotchas — `Layout` as a struct, cell-valued props, `setCallbackCode` vs `addMethod`,
property ordering — the parent's `agent-guide-shared.md` and `agent-guide-mlapp.md` are
authoritative.** What follows is HMI content, not an API reference.

**Gray-field figure** — set both `Color` **and** `Theme`; containers are **not
transparent**, so set `BackgroundColor` on every `GridLayout`/`Panel` too or they paint
default gray blocks:

```matlab
ab.setProperty("UIFigure", "Color", [0.78 0.78 0.78]);
ab.setProperty("UIFigure", "Theme", "light");   % mandatory — see note below
ab.setProperty("UIFigure", "Name", "Pump Station Overview");
ab.addComponent("GridLayout", "MainGrid", "UIFigure", struct( ...
    'RowHeight', {{40, '1x'}}, 'ColumnWidth', {{'1x','1x','1x'}}, ...
    'BackgroundColor', [0.78 0.78 0.78]));
```

> **`Theme='light'` is mandatory.** Gray-field `Color` alone does **not** satisfy the
> dark-theme defense: on a dark-themed MATLAB desktop, gauge bodies, axes, tables, and
> edit fields inherit dark defaults even with the figure `Color` set, and
> `BackgroundColor` on containers does not propagate into widget bodies. `Theme='light'`
> is the single-point fix. Set **both** on every HMI figure. See
> `color-and-layout-rules.md` §Dark-theme defense and `common-mistakes.md` entry 24.

**Use only the ISA-101 palette — don't free-hand colors.** When driving verbs it is easy
to reach for "a red" or "a green"; use these exact values (from
`color-and-layout-rules.md`) and nothing else:

| Role | RGB | Use |
|---|---|---|
| Critical / alarm | `[0.85 0 0]` | HH/LL band, critical banner, fault |
| Warning | `[1 0.7 0]` | H/L band, advisory |
| Connection / info | `[0.4 0.6 1.0]` | comms lamp, data quality — **blue, not green** |
| Normal / neutral | `[0.5 0.5 0.5]` | gauge normal band, idle lamp, control chrome |
| Confirmed-good (rare) | `[0 0.6 0]` | green — **only** operator-verified-OK, never "running"/"connected" |
| Page / panel | `[0.78 0.78 0.78]` / `[0.86 0.86 0.86]` | figure / container backgrounds |

**Alarm gauge at source** — use a **linear** gauge for color bands; the normal band is
neutral gray `[0.5 0.5 0.5]`, never green:

```matlab
ab.addComponent("LinearGauge", "FlowGauge", "MainGrid", struct( ...
    'Limits', [0 100], ...
    'ScaleColors', {{[0.85 0 0],[0.5 0.5 0.5],[0.85 0 0]}}, ...
    'ScaleColorLimits', [0 20; 20 80; 80 100], ...
    'Layout', struct('Row',2,'Column',1)));
```

> **Bands only work on `LinearGauge`.** Adding `ScaleColors` to a `Gauge` (circular),
> `SemicircularGauge`, or `NinetyDegreeGauge` is **accepted by the verb without error but
> silently inert** — the bands never render. If a design needs alarm bands, the widget
> must be `LinearGauge`; otherwise indicate alarm state with an adjacent lamp or colored
> frame.

**Writable setpoint** — `Spinner` with `Limits`; confirm the write in the callback, and
place write controls in a **secondary zone** (a right or bottom panel visually separated
from the center visualization), never in the center grid where an accidental click lands:

```matlab
ab.addComponent("Spinner", "SetpointSpinner", "MainGrid", struct( ...
    'Limits',[0 100], 'Value',50, 'Layout', struct('Row',2,'Column',3)));
ab.addCallback("SetpointSpinner", "ValueChangedFcn", "onSetpoint");
ab.setCallbackCode("onSetpoint", strjoin([ ...
    "newVal = app.SetpointSpinner.Value;" ...
    "sel = uiconfirm(app.UIFigure, sprintf(""Set setpoint to %g %%?"", newVal), ...
        ""Confirm Write"", ""Options"", {""Apply"",""Cancel""}, ""DefaultOption"", 2, ""CancelOption"", 2);" ...
    "if sel == ""Apply""" ...
    "    % writeValue(app.Client, node, newVal);" ...
    "    app.SetpointSpinner.BackgroundColor = [0 0.6 0];   % success flash (verified-OK green)" ...
    "end" ], newline));
```

**Command buttons — neutral gray, differentiate by label.** `Button` carries no status
meaning; **never** a green Start / red Stop (that spends the two alarm colors on
always-visible chrome — see `common-mistakes.md` entry 26). Leave the default face or use
`[0.86 0.86 0.86]`; distinguish by `Text`. Run/stopped state goes on a separate lamp,
not the button:

```matlab
ab.addComponent("Button", "StartButton", "ControlGrid", struct( ...
    'Text','START', 'Layout', struct('Row',1,'Column',1)));   % neutral face — no color
ab.addComponent("Button", "StopButton",  "ControlGrid", struct( ...
    'Text','STOP',  'Layout', struct('Row',1,'Column',2)));   % neutral face — no color
ab.addCallback("StartButton", "ButtonPushedFcn", "onStart");
```

> The one convention-based exception is a red **E-Stop** (it mirrors the physical
> mushroom button) — even then pair it with a confirm-both-engage-and-release dialog
> (`write-safeguards-reference.md`) rather than relying on the color. Disable write
> controls when disconnected (`Enable` `"off"`) in the disconnect handler.

**Status lamp — blue for comms, gray idle; pair with a label.** Green is reserved for
operator-verified-OK, so a "connected" or "running" lamp is **blue `[0.4 0.6 1.0]`** (or
gray `[0.5 0.5 0.5]` when idle), never green. A lamp alone is ambiguous — always add an
adjacent `Label`:

```matlab
ab.addComponent("Lamp",  "ConnLamp",  "StatusGrid", struct( ...
    'Color',[0.5 0.5 0.5], 'Layout', struct('Row',1,'Column',1)));   % gray idle; blue when up
ab.addComponent("Label", "ConnLabel", "StatusGrid", struct( ...
    'Text','Disconnected', 'Layout', struct('Row',1,'Column',2)));
```

**Alarm banner** — a `Label` spanning row 1 across the full width, present even when there
are no alarms:

```matlab
ab.addComponent("Label", "AlarmBanner", "MainGrid", struct( ...
    'Text','SYSTEM NORMAL', 'FontWeight','bold', 'HorizontalAlignment','center', ...
    'BackgroundColor',[0.75 0.75 0.75], 'Layout', struct('Row',1,'Column',[1 3])));
```

**Alarm-list table** — a `Table` (uitable) with the standard alarm columns. Set
`ColumnName`; drive `Data` from a `cell`/`table` in code. Keep it in the detail zone:

```matlab
ab.addComponent("Table", "AlarmList", "MainGrid", struct( ...
    'ColumnName', {{'Timestamp','Node','Severity','Value','State'}}, ...
    'Layout', struct('Row',3,'Column',[1 3])));
```

**Protocol handler and cleanup** — a `subscribe` data-change handler is called by handle
(`@app.onData`), so it is a method; declare app state bare and initialize it in
`startupFcn`; stop timers and drop subscriptions on close:

```matlab
ab.addProperty("Client", "", "private");
ab.addProperty("Subscription", "", "private");
ab.addProperty("PollTimer", "", "private");

ab.addMethod("onData", strjoin([ ...
    "function onData(app, ~, notification)" ...
    "    v = notification.Data.Value;   % R2026a OPC UA contract" ...
    "    app.FlowGauge.Value = v;" ...
    "end" ], newline), "private");
% In startupFcn: app.Subscription = subscribe(app.Client, nodeList, @app.onData);

ab.addCallback("UIFigure", "CloseRequestFcn", "onClose");
ab.setCallbackCode("onClose", strjoin([ ...
    "if ~isempty(app.PollTimer) && isvalid(app.PollTimer); stop(app.PollTimer); delete(app.PollTimer); end" ...
    "app.Subscription = opc.ua.Subscription.empty;   % no public delete; drop the handle" ...
    "delete(app);" ], newline));
```

**Trends** (`animatedline`, fixed `YLim`, threshold `yline`s) are created in code, not as
a gauge component — build a `UIAxes` component via the parent, then draw into it from
`startupFcn`/handlers per `references/trend-config-reference.md`.

---

## Pre-serialize domain-compliance checklist

The parent's `validate()`/`save()` check **loadability, not HMI correctness** — every
ISA-101 violation below still saves cleanly. Before you serialize (and before you open it
in App Designer), self-audit the design against these build-time rules (each is a real
failure observed on this path):

- [ ] **`Theme='light'` set on the figure** (not just `Color`) — `inspect()` and confirm `UIFigure.Props` lists `Theme`.
- [ ] **Command buttons/controls are neutral gray** — no green Start, no red Stop. Run state is on a lamp, not the button.
- [ ] **Only ISA-101 palette colors used** — critical `[0.85 0 0]`, warning `[1 0.7 0]`, comms blue `[0.4 0.6 1.0]`, neutral `[0.5 0.5 0.5]`; no free-handed reds/greens.
- [ ] **Connection/running indicators are blue or gray, not green** — green is reserved for operator-verified-OK.
- [ ] **Gauge normal band is gray `[0.5 0.5 0.5]`**, and any `ScaleColors` gauge is a `LinearGauge` (bands are silently inert on circular).
- [ ] **Alarm banner spans row 1**, present even when there are no alarms.
- [ ] **Write controls are in a secondary zone**, not the center visualization.
- [ ] **Quantity caps:** ≤ 6 gauges, ≤ 4 trend axes, ≤ 12 numeric readouts, ≤ 5 saturated-color elements on screen.
- [ ] **Like-typed analogs use like widgets** — don't mix a gauge and a numeric field for two temperatures in one panel.
- [ ] **Every writable field has a range label and confirm-before-write** (default option Cancel).

If any box is unchecked, fix it with a verb before serializing — not after.

After serializing, confirm the app instantiates and tears down cleanly (`app = MyHmi;`
then `delete(app);` — no leaked timers, subscriptions, or figures).

---

Copyright 2026 The MathWorks, Inc.
