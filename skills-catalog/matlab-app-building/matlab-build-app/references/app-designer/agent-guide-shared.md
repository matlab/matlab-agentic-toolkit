# AppDesignerAgentInterface: Shared Guide (read this first)

> **About this API.** `AppDesignerAgentInterface` is an internal API, for agentic use
> only. It exists to be driven by an AI agent (you) through `AppDesignerAgentInterface`; it is
> not a supported, user-facing API. Its surface (verbs, arguments, behavior) may
> change between MATLAB releases without notice. Treat this guide, for the
> release you are running against, as the single source of truth. Do not assume
> any part of the API is permanent or carry assumptions about it across releases.

`AppDesignerAgentInterface` is a stateful MATLAB API that serializes UIFigure apps into
App Designer formats. The app's structure (components, layout, callbacks) is designed
using UIFigure knowledge; this tool handles how that design is persisted to disk.
You call verbs that mutate an in-memory model, then `save()` serializes once.
This file covers the paradigms that are the same for both formats. Then read the
format-specific guide:

- **`.mlapp`** apps: read `agent-guide-mlapp.md`.
- **plain-text** (`.m` + `.xml`) apps: read `agent-guide-plaintext.md`.

The two formats have **different ownership models**, so do not assume a verb behaves
the same in both. The single most important rule: **the tool does exactly what it
was told, nothing more, and tells the truth about what it did.** If something is
wrong it throws a descriptive error rather than silently guessing or "fixing" it.

---

## How you interact with it

Everything runs in MATLAB. A session looks like:

```matlab
addpath('.../matlab-build-app/scripts');    % put the API on the path
appBuilder = AppDesignerAgentInterface.create("C:/path/App.mlapp");   % or .open(...)
appBuilder.setProperty("UIFigure", "Name", "My App");      % ... verbs ...
appBuilder.save();                                    % serialize + gate
```

`appBuilder` is a handle object. All the instance verbs mutate the model it holds. The
factory methods (`create`, `open`, `finalize`) are static (`AppDesignerAgentInterface.create(...)`).

**Format is decided by the file extension** you pass to `create`/`open`:
`.mlapp` -> mlapp path, `.m` -> plaintext path. `ClassName` is derived from the
filename stem, so name the file what you want the app class to be called.

**Converting between formats:** If the user asks to convert an existing app from
`.mlapp` to plain text (or vice versa), do NOT rebuild it from scratch. Tell the
user to open the app in App Designer and use **Save As**, changing the file
extension to `.mlapp` or `.m`. App Designer handles the conversion natively and
preserves all components, callbacks, and properties. Rebuilding wastes tokens and
risks losing fidelity.

---

## Calling conventions (keep a clean workspace)

Every eval you run lands in the base workspace. Follow these rules to avoid
polluting it with temporaries:

1. **Always semicolon-terminate.** Every statement must end with `;`. Without it,
   MATLAB echoes the return value to the console (noisy) and assigns `ans`.
2. **Inline structs into verb calls.** Do not create intermediate variables for
   property structs. Pass them directly:
   ```matlab
   appBuilder.addComponent("Button", "Btn", "UIFigure", struct('Text','Go','FontSize',14));
   ```
   Not:
   ```matlab
   props = struct('Text','Go','FontSize',14);  % BAD — leaves `props` in workspace
   appBuilder.addComponent("Button", "Btn", "UIFigure", props);
   ```
3. **Only `appBuilder` should persist.** It is the one handle you need across calls.
   If a struct is genuinely too complex to inline readably, use it and then
   `clear` it in the same eval: `clear props;`

---

## `save()` vs `finalize()` — what each one is

These are two different things and conflating them leads to invented workarounds.
Get the model straight before the when-to-call rules below.

- **`save()` persists and validates.** It serializes the in-memory model to disk and
  runs the real product loader as a gate. A file that `save()` accepted is **complete,
  valid, and openable** — nothing else is required to make it a real app. This is the
  workhorse: call it whenever you need the model on disk.
- **`finalize()` presents the finished result.** It round-trips the saved file *through
  the live product* (mlapp: bakes the full runnable classdef; plaintext: canonicalizes
  the `.xml`) and leaves the app open so the user sees it rendered. It is a
  **presentational, optional, once-at-completion** step — not part of correctness. A
  `save()`d app is already done in every load-bearing sense; `finalize()` just makes it
  look finished on screen.

**`finalize()` is reversible — it is not a one-way door.** You can always `open()` the
file after finalizing and keep editing (free it from AD first — `open()` for code,
`release()` for plaintext `.xml`, per the iterate-to-preview rule below). **Never avoid
`finalize()` to "preserve editability"** — editability is never lost, so that is not a
real trade-off.

**"finalize" is internal vocabulary — never say it to the user.** To the user this is
just "opening the app in App Designer so they can see it." When you offer it, ask in
their terms ("Want me to open it in App Designer so you can take a look?"), not "should
I finalize it?" — the word sounds like a committing, irreversible step, and it is
neither. Keep `finalize()` as the mechanism you invoke, not a term you expose.

## How to drive it: chunked inline calls, not a script

Run the verbs as **inline calls** in a persistent MATLAB session, grouped into a
few logical chunks. Do **not** write the build out to a temp
`.m` script and run that. Two reasons:

- **The model is a persistent handle.** `appBuilder` lives in the session between calls, so
  each verb builds on the last. This only works against a **persistent MATLAB
  session** (what the connector / MCP server gives you) — the handle has to survive
  from one call to the next. A temp script throws that away and hides the operations
  from the user.
- **Failures stay cheap and local.** Verbs validate *before* they mutate, so a verb
  that throws leaves the model untouched — you fix that one call and continue. Because
  the earlier verbs already applied to the live model, you **never re-emit the whole
  build** to recover from one bad call. A monolithic script forces exactly that
  re-run.

**Chunk by logical unit** — e.g. all of one panel's components in one call, then its
callbacks in the next. Not one verb per round-trip (you pay latency for nothing) and
not one giant block (a failure anywhere makes you hunt). A handful of coherent chunks
gives you failure-pinpointing without the overhead.

**Many cheap verbs, one `save()`.** `save()` is the expensive step (it runs the real
product loader as a gate). Do not `save()` between chunks to "check progress" —
Layer-1 already validated each verb as you called it, and if `save()` does reject
something it names the offending component, which you fix with a single `setProperty`
and re-save. No rebuild.

**Finalize once, when the work is done (both formats).** When you have finished a build
or an edit — not after every intermediate `save()` — make `AppDesignerAgentInterface.finalize(filepath)`
your **last action**. `finalize()` launches App Designer and leaves the app open so the
user sees the finished result with its theme rendered. What it accomplishes differs by
format (mlapp bakes the full runnable classdef; plaintext canonicalizes the `.xml`) —
see each format guide. Do NOT finalize between chunks or after each `save()` in a
multi-step build — that relaunches App Designer every time (~4s each) and churns the UI
the user is watching. Save as many times as the build needs; finalize exactly once at
completion.

**One exception — iterate-to-preview.** If you finalize, then need a small adjustment,
you must free the file from AD before editing it (finalize left it open; editing a file
AD holds triggers a wedging reload dialog). Editing code → `open()` first; editing
plaintext components (the `.xml`) → `release()` first. Then edit, `save()`, and
`finalize()` again. See the plaintext guide's "Editing after finalize" section.

## Recommended build sequence

There are only a few HARD ordering rules; most of what looks ordered is not. In order
of how much they matter:

1. **`create()` first.** Seeds the root `UIFigure`.
2. **Parent before child.** `addComponent` requires the parent to exist, so build the
   tree **top-down**: containers (`Panel`, `GridLayout`, `TabGroup`) before their
   contents. This is the one real constraint inside the "components" step.
3. **A target must exist before you reference it.** `setProperty` and `addCallback`
   need their component present. (Naturally satisfied if you build top-down.)
4. **`save()` last.**

Everything else is FREE — do not over-sequence:

- **Properties are not a separate phase.** Set a component's properties inline in the
  `addComponent` `props` struct. Fewer calls, and coupled-order pairs (like
  `DropDown` `Items`-before-`Value`) are reordered for you (see the mlapp guide).
  Reserve `setProperty` for *edits* to an already-built app, not fresh construction.
- **Code is order-free.** Callback bodies, methods, and `addProperty` reference
  `app.<X>` at *runtime*, not when you call the verb. A callback body may mention a
  component or property you have not declared yet. The only code-side ordering rule is
  that `addCallback` (wiring an event slot) needs the component to exist. Wire
  `StartupFcn` last so it can reference everything.

So a natural mlapp build reads: **create + figure props → component tree top-down
(properties inline) → app-state `addProperty` → behavior (`addCallback` + bodies +
methods, startup last) → `save()` once.** Plaintext is the mirror image — components
live in the hand-authored `.xml`, so the sequence is *author `.xml` tree → code verbs
→ `save()`* (see the plaintext guide).

---

## The verbs (full public surface)

### Factories (static)

| Call | Returns | Notes |
|---|---|---|
| `AppDesignerAgentInterface.create(filepath)` | handle | New empty app. Seeds a root `UIFigure`. For plaintext also seeds a boilerplate `.xml` (see plaintext guide). Releases the file from AD first (posture A). |
| `AppDesignerAgentInterface.open(filepath)` | handle | Load an existing app into a model. Releases the file from AD first (posture A). |
| `AppDesignerAgentInterface.finalize(filepath [, deadlineSeconds])` | (void) | Both formats. Opens in AD, saves through the product, leaves it open for viewing. mlapp bakes runnable code; plaintext canonicalizes the `.xml`. See each format guide. |
| `AppDesignerAgentInterface.release(filepath)` | (void) | Free a file from App Designer before hand-editing its `.xml` (posture A: closes a clean copy, rejects an unsaved one). The escape hatch for editing plaintext components after `finalize()`. See plaintext guide. |

### Component verbs (mutate the UI tree) — **mlapp only**

These edit components. On a **plaintext** model they HARD-ERROR
(`AppDesignerAgentInterface:plaintextComponentsInXml`) because you author plaintext components
in the `.xml` by hand. See the plaintext guide.

| Verb | Signature |
|---|---|
| `addComponent` | `appBuilder.addComponent(type, codeName, parentCodeName, props)` — `props` optional struct |
| `setProperty` | `appBuilder.setProperty(codeName, propName, value)` — supports dot-path for sub-object properties (e.g. `"Title.String"`) |
| `removeComponent` | `appBuilder.removeComponent(codeName)` |
| `moveComponent` | `appBuilder.moveComponent(codeName, newParentCodeName)` |
| `addCallback` | `appBuilder.addCallback(codeName, eventName, callbackName)` — wires an event slot to a function name |

### Code verbs (mutate the `.m` code side) — **both formats**

| Verb | Signature |
|---|---|
| `setCallbackCode` | `appBuilder.setCallbackCode(callbackName, bodyCode)` — the callback *body* text (dedented; no `function` line) |
| `addProperty` | `appBuilder.addProperty(propName, value, access)` — `access` = `"public"` (default) / `"private"` / `"protected"` |
| `addMethod` | `appBuilder.addMethod(name, bodyCode, access)` — `bodyCode` is the FULL `function ... end` text |
| `removeCallback` | `appBuilder.removeCallback(callbackName)` — fully remove a callback: its body AND (mlapp) every component event slot wired to it. Throws `AppDesignerAgentInterface:noSuchCallback` only if the name has neither a body nor any wiring. |
| `removeMethod` | `appBuilder.removeMethod(name)` — remove a method. Throws `AppDesignerAgentInterface:noSuchMethod` if absent. |
| `removeProperty` | `appBuilder.removeProperty(propName)` — remove a property. Throws `AppDesignerAgentInterface:noSuchProperty` if absent. |

**`set`/`add` code verbs REPLACE, they do not append.** `setCallbackCode`,
`addProperty`, and `addMethod` each key on the name. If that name already exists,
the verb **overwrites the whole entry** and emits a warning
(`AppDesignerAgentInterface:overwriteCallback` / `overwriteProperty` / `overwriteMethod`) naming
the key. Nothing is merged. To *modify* rather than replace, use the read-modify-write
pattern below.

### Inspection / lifecycle — **both formats**

| Verb | Returns | Notes |
|---|---|---|
| `inspect()` | struct | Full model projection (see shape below). Read-only. |
| `validate()` | struct array | Dry-run check. Non-throwing, writes nothing. Always a struct array with fields `code`, `message`, one element per problem. **A clean result is a `0x0` struct** (still has the two fields) — test it with `isempty(v)`, which is `true` exactly when there are no problems. |
| `save()` | (void) | Serialize + loadability gate. Throws on failure. |

All string arguments are MATLAB `string` (`"..."`) or char (`'...'`); both work.

---

## `inspect()` output shape

`s = appBuilder.inspect()` returns a struct:

```
s.ClassName    string
s.Format       "mlapp" | "plaintext"
s.StartupFcn   string (name of the startup callback, or "")
s.Nodes        cell array of node structs, in insertion order
s.Callbacks    struct: fieldname = callback name, value = body text
s.Methods      struct: fieldname = method name, value = struct with .Body (full function text) and .Access ("public"|"private")
s.Properties   struct: fieldname = property name, value = default value
```

Each node struct in `s.Nodes`:

```
node.CodeName        string   (the unique identifier for the component)
node.Type            string   (component type, e.g. "Button")
node.ParentCodeName  string
node.Props           struct   (property name -> native value)   << field is "Props", NOT "Properties"
node.Layout          struct   (Row / Column for grid children)
node.Callbacks       struct   (eventName -> wired callback name)
node.Children        string array of child codeNames
```

Gotcha: the node property bag is `node.Props`, not `node.Properties`. To read a
component's Color: `figNode.Props.Color`.

---

## Editing an existing app (read this before you change anything)

The API is **stateful and additive**. You never rebuild an app to change it, and you
never re-run `create()` on a file that already exists. The rule is:

**To edit, `open()` the app and apply the smallest set of verbs that make the change.
Do NOT re-create the app or re-drive the whole build.**

`create()` is for a brand-new file only. Everything else — adding a component,
changing a property, editing code, removing something — is `open()` + a few surgical
verbs + `save()`. The model you open already contains everything the app has; your
verbs mutate it in place.

The disciplined edit loop is **inspect first, then mutate**:

```matlab
appBuilder = AppDesignerAgentInterface.open("C:/path/MyApp.mlapp");
s  = appBuilder.inspect();          % <-- see the CURRENT state before you touch it
% ... decide the minimal change from what you actually see ...
appBuilder.setProperty("GoButton", "Text", "Start");
appBuilder.save();
```

Why `inspect()` first matters:
- **Placement/layout:** before adding a component, read existing node `Position`
  (or `Layout` for grid children) so the new one fits, instead of guessing
  coordinates. See `s.Nodes{k}.Props.Position` / `.Layout`.
- **Avoiding accidental overwrite:** before `setCallbackCode`/`addProperty`/
  `addMethod`, check whether the name already exists in `s.Callbacks` /
  `s.Properties` / `s.Methods`. If it does, the verb REPLACES it (with a warning).
  That is the mechanism behind "it overwrote the callback I already wrote."

### Modifying code (not replacing it): read-modify-write

There is no "append to a callback" verb. The code verbs replace by name. To *add to*
existing code, read the current body, build the new full text yourself, and set it back:

```matlab
s = appBuilder.inspect();
old = s.Callbacks.onGo;                         % current body ("" if unset)
newBody = old + newline + "app.Count = app.Count + 1;";
appBuilder.setCallbackCode("onGo", newBody);            % now holds old + new
```

If you skip the read and just call `setCallbackCode("onGo", "app.Count = ...")`, you
**lose the previous body** and get an `AppDesignerAgentInterface:overwriteCallback` warning. The
warning is your signal that you replaced something — if you did not intend to, you
skipped the read step.

### Removing code

Use the removal verbs (`removeCallback` / `removeMethod` / `removeProperty`). Each
throws if the target does not exist, so a clean call means it was really there and is
now gone. There is **no** verb to partially edit a body down — to shrink a method,
read-modify-write the full replacement text, or remove and re-add.

Removing a **component** is `removeComponent` (mlapp only; plaintext edits the `.xml`).
Removing a component does NOT remove any callback bodies it was wired to — those are
code entries; remove them separately with `removeCallback` if they are now orphaned.

---

## Component types and events are validated from the product (Layer-1)

When you add a component, set a property, or wire a callback, `AppDesignerAgentInterface` validates
against the **real App Designer component registry** — nothing is hardcoded. An
invalid type/property/event throws immediately and mutates nothing.

There are **54 component types**. Use the short name (last segment of the class),
e.g. `"Button"`, `"Label"`, `"NumericEditField"`, `"Slider"`, `"DropDown"`:

```
AirspeedIndicator, Altimeter, ArtificialHorizon, Button, ButtonGroup, CheckBox,
CheckBoxTree, ClimbIndicator, ColorPicker, ContextMenu, DatePicker, DiscreteKnob,
DropDown, EGTIndicator, EditField, Gauge, GridLayout, HTML, HeadingIndicator,
Hyperlink, Image, Knob, Label, Lamp, LinearGauge, ListBox, Menu, NinetyDegreeGauge,
NumericEditField, Panel, PushTool, RPMIndicator, RadioButton, RangeSlider,
RockerSwitch, SemicircularGauge, Slider, Spinner, StateButton, Switch, Tab,
TabGroup, Table, TextArea, TimeScope, ToggleButton, ToggleSwitch, ToggleTool,
Toolbar, Tree, TreeNode, TurnCoordinator, UIAxes, UIFigure
```

Event names are per-type. Examples:
- `Button` -> `ButtonPushedFcn`
- `Slider` -> `ValueChangedFcn`, `ValueChangingFcn`
- `DropDown` -> `ValueChangedFcn`, `DropDownOpeningFcn`, `ClickedFcn`

The app root is always `UIFigure` (seeded by `create`). The app-level startup
callback is wired on `UIFigure` with event name `StartupFcn`.

### Property order is handled for you

You can pass a component's properties in **any order**. Some components have coupled
properties that the product requires be applied in a specific order (e.g. a
`DropDown`'s `Items` before its `Value`), but `AppDesignerAgentInterface` reorders each property bag
into App Designer's own canonical order before applying it, so you never have to
sequence them yourself. This is product-sourced, not a hardcoded list. See the mlapp
guide ("Property order does not matter") for the full set of affected components.

---

## The startup callback

Wire it on the figure, then set its body:

```matlab
appBuilder.addCallback("UIFigure", "StartupFcn", "startupFcn");   % mlapp only; plaintext wires it in .xml
appBuilder.setCallbackCode("startupFcn", "app.CurrentPlayer = ""X"";");
```

`StartupFcn` is always a valid event on `UIFigure`. Use startup to initialize app
state properties (declare them bare via `addProperty(name, "", "private")`, then
assign real values in startup) so the app opens in a known state.

---

## Callback bodies vs. method bodies (easy to get wrong)

- `setCallbackCode(name, body)` takes **just the body**, dedented, no `function`
  line, no `end`. `AppDesignerAgentInterface` generates the `function name(app, event)` wrapper.
  Inside, you have `app` and `event` in scope.
- `addMethod(name, body, access)` takes the **FULL** `function ... end` text,
  including the signature line. Write the whole thing:

```matlab
appBuilder.addMethod("checkWin", strjoin([ ...
  "function tf = checkWin(app)" ...
  "    tf = false;" ...
  "    % ..." ...
  "end" ], newline), "private");
```

Reach components from a callback/method via `app.<CodeName>` (e.g.
`app.StatusLabel.Text = "..."`). Reach app-level properties via `app.<PropName>`.

**Which verb: is it wired to an event, or called from code?** This is the
distinction that decides `setCallbackCode` vs `addMethod`:

- A function that fires from a **component event** (a button push, a value
  change, startup) is a *callback*: wire it with `addCallback`, then give it a
  body with `setCallbackCode`. App Designer only emits a callback that is wired
  to an event slot — **a `setCallbackCode` body that no component wires to is
  silently dropped at save** (it never appears in the generated app). `validate()`
  on an mlapp flags this as `AppDesignerAgentInterface:orphanCallbackBody` so you catch it
  before save.
- A **helper** that other code *calls by name* (including anything you invoke via
  `createCallbackFcn(app, @thing, true)`, or a plain `app.thing()` from another
  callback) is a *method*: add it with `addMethod`. Do **not** create it with
  `setCallbackCode` — an unwired body is dropped, so the call would reference a
  function that does not exist.

**A name cannot be both a callback and a method.** If the same name is wired as a
callback body *and* added as a method, it would be generated as two functions
with the same name (a broken classdef). `AppDesignerAgentInterface` rejects the collision with
`AppDesignerAgentInterface:nameCollision` from whichever verb is called second. To convert a
callback into a method (e.g. you wired it but really want a callable helper),
`removeCallback(name)` first — that removes the body **and** unwires the event
slot — then `addMethod(name, ...)`.

**Body text is treated as opaque code** — it is stored and emitted verbatim, not
interpreted or reformatted. Literal `%`, `$`, quotes, and `sprintf`/`fprintf` format
strings pass through unchanged (e.g. a body containing `sprintf("$%.2f", total)`
round-trips exactly). You do not need to escape anything for `AppDesignerAgentInterface`'s sake; write
the body as the MATLAB code you want to appear in the file. (The usual MATLAB rule
still applies to the *string you hand the verb*: a `"` inside a double-quoted MATLAB
string literal must be doubled `""`, but that is your call's syntax, not an
`AppDesignerAgentInterface` transformation of the body.)

**Quoting patterns for bodies containing single quotes** (transpose `'` or char
literals `'text'`):

```matlab
% Option 1: use a double-quoted string — single quotes pass through unescaped
appBuilder.setCallbackCode("onPress", "x = [1 2 3]';" + newline + "app.Btn.Text = 'done';");

% Option 2: use sprintf with a char vector — escape ' as ''
appBuilder.setCallbackCode("onPress", sprintf('x = [1 2 3]'';\napp.Btn.Text = ''done'';'));
```

Both produce identical stored bodies. Prefer double-quoted strings (option 1) since
single quotes inside them require no escaping.

---

## Shared callbacks (one function, many components)

Wire multiple components to the SAME callback name, then define the body once.
Distinguish which fired using `event.Source`:

```matlab
appBuilder.addCallback("RockButton", "ButtonPushedFcn", "PlayMove");
appBuilder.addCallback("PaperButton", "ButtonPushedFcn", "PlayMove");
appBuilder.setCallbackCode("PlayMove", "move = string(event.Source.Text); ...");
```

---

## save() gates on real loadability — trust the error, don't fight it

`save()` does not just write bytes. It runs the app through the real product loader
(or, for mlapp, a round-trip re-read plus the loader). If the result would not load
cleanly in App Designer, `save()` throws with the loader's own error. Two failure
shapes to know:

1. **Parse/config error** — the file structure is bad (e.g. malformed `.xml`).
2. **Errored components** — the app parses but a component fails to construct
   (usually a bad property value the lexical checks let through, like an out-of-range
   enum). The error names the offending component codeName.

When `save()` throws, read the message: it tells you exactly what the product
rejected. Fix the model/`.xml` and save again. Do not assume a throw means the
`AppDesignerAgentInterface` is broken — it usually means the app really would not load.

---

## Not yet supported

Two feature areas are **out of scope** for `AppDesignerAgentInterface` today:

### Simulink apps

Apps that embed or bind to a Simulink model (signal viewers, dashboard blocks, model
callbacks) are not supported. The plain text format has no representation for Simulink
bindings at all. The mlapp format can encode them, but `AppDesignerAgentInterface`
does not expose verbs for model association, signal routing, or variable binding. Do not attempt to
wire Simulink connections through raw property manipulation; it will not produce a
loadable app.

### User Authored Components (UAC)

UACs (custom component classes authored by the user) cannot be added through
`addComponent`. The plain text format does not support
UACs. For mlapp, the workaround is to instantiate the UAC programmatically in the
app's `StartupFcn` callback:

```matlab
appBuilder.setCallbackCode("startupFcn", ...
    "app.MyCustomGauge = MyGaugeComponent(app.UIFigure);" + newline + ...
    "app.MyCustomGauge.Layout.Row = 2;" + newline + ...
    "app.MyCustomGauge.Layout.Column = 1;");
```

This is a valid App Designer pattern. The UAC will function at runtime but will not
appear in Design View. Alternatively, suggest the user add the UAC in Design View
manually; `AppDesignerAgentInterface` can then access it via `setProperty`/`getProperty` on
subsequent `open()` calls.

---

## Working-session gotchas (for whoever drives MATLAB, incl. me)

- **After editing source** (`AppDesignerAgentInterface.m` / `MlappBackend.m` /
  `PlainTextBackend.m`), run `clear classes; rehash toolboxcache` before the next
  call, or MATLAB keeps the stale class definition. Not needed for test/script edits.
- **`.mlapp` is a zip.** To read the generated code, use
  `appdesigner.internal.serialization.FileReader(path).readMATLABCodeText()` — NOT
  `fileread` (reads raw zip bytes) and there is no `matlabCodeText` struct field.
- **String property values in the plaintext `.xml` must be quoted** (`'text'`) —
  they are parsed as native MATLAB literals. See the plaintext guide. (mlapp props
  are passed as native MATLAB values directly through the verbs, so this only bites
  plaintext.)
- Bounded any App-Designer-touching run with a timeout; a wedged AD can block on an
  unbounded wait.

----

Copyright 2026 The MathWorks, Inc.

----
