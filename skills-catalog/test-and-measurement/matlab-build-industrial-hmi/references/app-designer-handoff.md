# App Designer Build & Serialization — Hand-off to `matlab-build-app`

This skill owns **what an industrial HMI is** (gray-field, alarms-at-source, write
safeguards, fixed-range trends, protocol wiring). It does **not** build or serialize the
App Designer app itself — that is the `matlab-build-app` skill's job. Design the HMI here,
write the design into an **HMI spec file the user reviews**, then hand that approved file
over to be built and persisted.

The hand-off is a **file, not a conversation**: fill `assets/hmi-spec-template.md` into
`<AppName>-hmi-spec.md`. That file is the entire contract between the two skills — it can be
reviewed, corrected, version-controlled, and graded on its own, and either side can be tested
without the other.

**`matlab-build-app` owns how the app is built and saved** — creating the components,
applying their properties and callbacks, choosing the file format, and the whole
save/open/edit lifecycle. This skill does not need to know any of that and must not
restate it. Hand it the approved spec file; it consults its own guides for the mechanics
and produces the app.

This file specifies only the **HMI-specific design**: which components to use, which
domain property values make them ISA-101-compliant, where they go, and the domain callback
logic they carry. The spec template is the *form* those decisions are written into; the
recipes below are the *catalog* they are chosen from.

## Availability and fallback

`matlab-build-app` either appears in your available skills or it does not — that check is
free. **Invoke it when it's listed; fall back when it isn't. Never search the filesystem
for it.**

Invoke it **under the exact name it appears as in your available-skills list** — it may be
plugin-scoped (`<plugin-name>:matlab-build-app`) or bare. Only the listed form resolves, so
read the name off the list rather than typing a guessed slash command or hardcoding a prefix.
That same list entry *is* the availability check.

- **Listed → invoke it and hand it the approved spec file.** It owns locating and loading
  its own build tooling, choosing the file format, and the whole save/open/edit lifecycle.
  This skill never names, paths, or loads any of that.
- **Not listed → fall back immediately** to the programmatic `.m` path this skill's other
  references describe. Build it yourself from the same approved spec. No HMI content changes,
  just a different output format — the app runs identically, it just won't open in App
  Designer. Tell the user the `matlab-build-app` skill wasn't available, so the app is a `.m`
  classdef rather than a `.mlapp`, and that enabling the `matlab-app-building` plugin and
  rebuilding from the same spec produces a `.mlapp`.

Do **not** probe the disk for its skill folder. A recursive search across the directories
above this skill can run for tens of minutes on a large or cloud-synced tree and still miss,
because in a normal install `matlab-build-app` ships in a **different plugin**
(`matlab-app-building`) rather than as a sibling of this skill. Absent from your skill list is
a sufficient and final answer.

---

## Division of labor

| Concern | Owner | Notes |
|---|---|---|
| **Writing the HMI spec, and getting it reviewed** | **HMI** | the artifact, the review gate, and the corrections are this skill's |
| Building & serializing the app (components, properties, callbacks, file format, save/open/edit) | **`matlab-build-app`** | hand it the approved spec file; it owns all the mechanics |
| UIFigure structural mechanics (grid, panels, components, callback wiring) | **`matlab-build-app`** | it decides how the spec becomes an app |
| Editing an existing App Designer app | **`matlab-build-app`** | hand it the change; it edits in place rather than rebuilding |
| Layout archetype skeleton | **`matlab-build-app`** | plant overview ≈ **Dashboard**; area/detail ≈ Dashboard/Explorer |
| MVVM for large multi-screen HMIs | **`matlab-build-app`** (optional) | it decides when MVVM is warranted |
| Architecture (UIFigure vs UIHTML) | **short-circuit** | HMI is **always UIFigure** — don't ask |
| Serialization format choice | **short-circuit** | default **`.mlapp`** — don't ask unless the user wants source-controllable app files |
| Theming / colors / dark mode | **HMI — override** | gray-field is mandatory; **never** route to `matlab-apply-theme` |
| Trends | **HMI — override** | `animatedline` + fixed `YLim` + `yline`; **never** route to `matlab-build-chart` |
| Protocol wiring, alarms-at-source, write safeguards, widget selection, quantity caps | **HMI** | pure domain |
| **Component choice + domain property VALUES + placement + callback bodies** | **HMI** | the spec form — *what* to build, never *how* to emit it |

The two overrides are deliberate: `matlab-build-app` would normally delegate color to
`matlab-apply-theme` (which supports dark mode) and plots to `matlab-build-chart`
(general-purpose axes). Both conflict with HMI rules — keep them here.

---

## Hand-off protocol

1. **Design first, here.** Classify nodes → pick widgets → lay out by hierarchy → plan
   alarms, trends, writes, protocol wiring, using this skill's references. Then express the
   result in the spec form, not in prose. `matlab-build-app` never decides HMI content.
2. **Write the spec.** Fill `assets/hmi-spec-template.md` into `<AppName>-hmi-spec.md` next to
   where the app will live. Sections 8 and 7 are filled from the component and behavior recipes
   below; section 5 is self-audited before you present anything. Keep it under 10 KB where
   the app allows — sections 1-6 are a fixed size, so trim section 8 first.
3. **STOP for review.** Present a summary of at most ten lines plus the file path, then **wait**.
   Apply the user's corrections **to the spec** — never to a built app — and re-present. Stamp
   `Review status: APPROVED <date>` once they agree. Proceed without waiting **only** when the
   user has pre-approved the build or the session cannot take a reply (a batch or eval run); in
   that case leave the status `UNREVIEWED` and say so in your summary. "The user seems busy" and
   "the prompt said build it" are **not** bypasses.
4. **Branch on the skill list.** Listed → invoke `matlab-build-app` under its listed name and
   hand it the approved spec file. Not listed → build the programmatic `.m` app yourself from
   that same spec. Either way, **ask that it be shown in App Designer** at the end so the user
   sees it rendered — offer it as "open it in App Designer so you can take a look."

**Editing an existing HMI** is a delta, not a rebuild. Threshold: at most 2 new signals, at
most 3 new or changed components, and no new screen → delta path; anything larger gets a full
spec and a full review.

- **Spec exists** → patch only the affected rows in sections 2/7/8, add a section 9 change-log
  line, and present *just the diff* ("3 rows added, 1 changed — say go") for a one-line confirm.
  Untouched rows are not re-reviewed.
- **No spec exists** (the HMI predates this, or came from elsewhere) → do **not**
  reverse-engineer a full spec. Write a delta spec covering only the touched items, headed
  `Existing app: <file>; components not listed are unchanged.` Then gate on that.

Either way the section 5 self-audit is scoped to the touched rows. The *what to add* is HMI
domain; the *how* is `matlab-build-app`'s job.

---

## Component recipes — fill section 8 of the spec from these

**This is the catalog, keyed by role; `assets/hmi-spec-template.md` section 8 is the instance,
one row per actual component.** Look a role up here, then write the chosen component type and
its property values into the spec. Nothing here is copied into the spec wholesale.

Each recipe gives a *role*, the App Designer *component type* to use, the *domain property
values* that make it ISA-101-compliant, and its *placement*. **These are HMI content
decisions, not build instructions** — the values in the "Domain properties" column are the
part that must not be delegated.

### Gray-field figure

The figure is the single most important compliance surface. Set **both** `Color` and
`Theme`; containers are **not** transparent, so every `GridLayout`/`Panel` also carries
`BackgroundColor` or it paints a default gray block.

| Role | Component type | Domain properties (values) | Placement |
|---|---|---|---|
| Root figure | `UIFigure` | `Color` = `[0.78 0.78 0.78]`; `Theme` = `light`; `Name` = the station/screen title | root |
| Structural grid | `GridLayout` | `BackgroundColor` = `[0.78 0.78 0.78]`; rows/columns per archetype (banner row + content rows) | on the figure |
| Container panel / sub-grid | `Panel` / `GridLayout` | `BackgroundColor` = `[0.78 0.78 0.78]` (or `[0.86 0.86 0.86]` for a visually distinct secondary zone) | nested |

> **`Theme='light'` is mandatory.** Gray-field `Color` alone does **not** satisfy the
> dark-theme defense: on a dark-themed MATLAB desktop, gauge bodies, axes, tables, and
> edit fields inherit dark defaults even with the figure `Color` set, and
> `BackgroundColor` on containers does not propagate into widget bodies. `Theme='light'`
> is the single-point fix. Set **both** on every HMI figure. See
> `color-and-layout-rules.md` §Dark-theme defense and `common-mistakes.md` entry 24.

### ISA-101 palette — the only colors to use

Whatever component the spec calls for, its colors come **only** from the ISA-101 palette.
When specifying a color value, never free-hand "a red" or "a green" — use the exact triplets
in **`color-and-layout-rules.md` §Gray-field palette**, which is the single source for them
(critical, warning, comms blue, neutral gray, verified-OK green, page/panel gray). Read them
there rather than re-copying, so the two files can't drift. The rule that matters for the
spec: **color means exception** — blue (not green) for connection, gray for normal, green
reserved for operator-verified-OK only. (The gray-field page/panel values appear literally
in the figure rows above because they are the figure's defining build property, not a
per-component color choice.)

### Process values, alarms, controls, status

| Role | Component type | Domain properties (values) | Placement |
|---|---|---|---|
| **Alarm gauge (at source)** | `LinearGauge` | `Limits` = node range; `ScaleColors` = `{normal, warn, crit}` — **normal band is the neutral-gray palette color, never green**; warn is the warning color, crit is the critical color; `ScaleColorLimits` = one row per band matching the node's warn/alarm thresholds | center / primary visualization grid |
| **Analog readout, no alarm** | `LinearGauge` | `Limits` = node range; single neutral-gray band over the full range | center grid |
| **Binary state (valve, pump, run)** | `Lamp` | `Color` = neutral gray idle; comms blue when on/connected; **never green for "running"**. Always pair with an adjacent `Label` | with its label |
| **Writable setpoint** | `Spinner` | `Limits` = node range; `Value` = current; confirm-before-write in the callback (default option **Cancel**) | **secondary zone** (right/bottom panel), never the center grid |
| **Command button** | `Button` | `Text` differentiates (e.g. `START`/`STOP`); **neutral face** — default or panel gray, **no green Start, no red Stop**. Run state lives on a separate lamp, not the button | control zone |
| **Status lamp (comms/running)** | `Lamp` | `Color` = neutral gray idle → comms blue when up (**never green**). Always pair with a `Label` (e.g. "Disconnected") | status grid |
| **Alarm banner** | `Label` | `Text` = `SYSTEM NORMAL` (present even with no alarms); `FontWeight` = `bold`; `HorizontalAlignment` = `center`; `BackgroundColor` = neutral panel gray → critical color on active alarm; spans full width of **row 1** | top row, spanning all columns |
| **Alarm-list table** | `Table` | `ColumnName` = `{Timestamp, Node, Severity, Value, State}`; `Data` driven from code | detail zone |
| **High-count homogeneous readouts** (> gauge cap) | `Table` | one row per node; conditional `BackgroundColor` styling for out-of-range | detail zone |
| **Multi-area navigation** | `TabGroup` + `Tab` | one `Tab` per plant area, plus an Overview tab; each area tab carries its own gauges **and its own trend axes** | on the main grid |
| **Trend** | `UIAxes` | created as a component, then drawn into from code per `trend-config-reference.md`, with **all four** of: `animatedline`; **fixed `YLim` matching the sensor spec** (never left on autoscale); an **axis unit label** (`ylabel` with units, `xlabel` time); **no interactive axes toolbar** — `Toolbar.Visible='off'` and `Interactions=[]`, set in **startup code, never as a component property**: `Toolbar` is a handle to an `AxesToolbar` object, so an App Designer `.mlapp` save rejects it with `MATLAB:class:RequireClass` (`Value must be 'matlab.graphics.Graphics'`). Put it on the trend-rendering behavior row of spec section 7, not in a section 8 row; and — whenever the trended node has alarm thresholds — **threshold `yline`s at the same warn/alarm values as the source gauge's `ScaleColorLimits`** (`'HandleVisibility','off'`). A trend of an alarmed node with no threshold lines or no unit label is incomplete. **Never** route to `matlab-build-chart` | spans the trend row |

> **Bands must lie inside `Limits`.** `LinearGauge` is the default alarm gauge, but every
> gauge style renders `ScaleColors`. Whatever the type, `Limits` must cover every
> `ScaleColorLimits` row — a band outside it is silently clipped. Full rationale:
> `common-mistakes.md` entry 23.

> **Command buttons carry no status color** — neutral face, no green Start / red Stop; run
> state lives on a lamp. The lone exception is a red **E-Stop** with a confirm dialog. Full
> rule + rationale: `color-and-layout-rules.md` §Command buttons and controls are neutral;
> confirm dialog in `write-safeguards-reference.md`. Disable write controls when
> disconnected (`Enable` = `off`) in the disconnect handler.

### Behavior recipes — fill section 7 of the spec from these

These are **the MATLAB the app should contain** — domain behavior this skill owns. You
supply each body and its role; how it gets installed is `matlab-build-app`'s job. The role
tells it how to wire the body: an **event handler** on a component event (e.g. a setpoint's
value-changed callback), a **method** invoked by handle (e.g. a `subscribe` data-change
callback passed as `@app.onData`), or app state held as **private properties** initialized
in `startupFcn`. The code for each already lives in a reference file — read it there and hand
`matlab-build-app` the body with its role; do not restate the code here.

Spell the **data-wiring contract** out on the spec's live-data row, because it is the part a
builder cannot infer and a reviewer needs to check: the update mechanism (subscription, or a
polling timer and its period), the callback's argument shape, how one notification is
dispatched to the right signal, and the call used to append a point to a trend.

- **Confirm-before-write** — an **event handler** on a setpoint `Spinner`'s
  `ValueChangedFcn`; default option Cancel, echo old/new value and units, then a **desaturated
  flash that reverts** — `[0.7 1 0.7]` on success, `[1 0.7 0.7]` on failure, back to the normal
  face after ~0.4 s. Not verified-OK green `[0 0.6 0]` and not alarm red `[0.85 0 0]`: those are
  reserved, and a control left recolored reads as status rather than acknowledgement. Body +
  rationale: `write-safeguards-reference.md`.
- **Live data handler** — a `subscribe` data-change callback invoked by handle, so a
  **method** (`@app.onData`), wired in `startupFcn`; the client/subscription/timer it touches
  are **private properties**. Body + OPC UA notification contract:
  `app-designer-gotchas.md`.
- **Teardown** — the **body belongs in `delete(app)`** (stop and delete timers, drop the
  subscription handle, disconnect the client); the figure's `CloseRequestFcn` is a one-line event
  handler that *routes* to it, `@(~,~) delete(app)`. Specify it that way round on the spec row:
  putting the body on `CloseRequestFcn` leaks everything on programmatic close, which is how every
  test and eval closes the app. Body + lifecycle rules: `app-designer-gotchas.md`.

Trends (`animatedline`, fixed `YLim`, threshold `yline`s) are drawn into the `UIAxes`
component from `startupFcn`/handlers per `references/trend-config-reference.md` — not
configured as gauge properties.

---

## Compliance self-audit

The compliance checklist is **section 5 of the spec** (`assets/hmi-spec-template.md`) — tick
every box there before presenting the spec for review. A build check confirms *loadability, not
HMI correctness*: every ISA-101 violation on that list still saves cleanly. If a box won't
tick, **fix the spec, not the built app.**

After the app is built, **read it back rather than re-reading the spec**: copy
`assets/designReportReadback.m` beside the app **verbatim** (keep the filename — do not edit,
rename or re-author it), and call the function with the app class and its spec file:
`designReportReadback("<AppClass>", "<AppClass>-hmi-spec.md")` (inline via `evaluate_matlab_code`
is fine — a function's local functions resolve when it is called). It constructs the app, pulls the ISA-101 values off the live figure, extracts the
live-data callback and the protocol write lines from the source, emits `design-report.json`, and
exercises `delete(app)` — so the teardown check above happens inside the same run, and leaked
figures and timers are counted rather than assumed.

The readback closes the gap this section opens: the spec's section 5 is what the design *claims*,
and the checklist is ticked before anything exists. The report is what the app *is*. Where they
disagree the report wins and the app gets fixed — the two ways to lose that check are hand-writing
the numbers and renaming or nesting the keys (`common-mistakes.md` #33). Key names, sentinel
values, and the four emission rules: `assets/design-report-schema.json`.

---

Copyright 2026 The MathWorks, Inc.
