# AppDesignerAgentInterface: Plain-text (`.m` + `.xml`) Guide

Read `agent-guide-shared.md` first. This file covers what is specific to plain-text
apps. **Plaintext behaves differently from mlapp — do not carry over mlapp habits.**

## Ownership model: YOU own the `.xml`, the tool owns the `.m`

A plain-text app is two files with a **split of ownership**:

| Concern | Owner | How |
|---|---|---|
| Component tree: types, properties, layout, nesting, and callback **wiring** | **YOU (the agent)** | hand-edit the `.xml` on disk directly |
| Code: callback **bodies**, custom properties, methods, `ClassName`, `StartupFcn` body | **the tool** | code verbs -> in-memory model |
| the `.xml` file | **YOU** | tool writes a boilerplate ONCE (at `create`, only if absent); NEVER regenerates it |
| the `.m` file | **the tool** | regenerated at `save()` from (your `.xml` tree) + (the model's code) |

Consequence: **component verbs are disabled for plaintext.** Calling
`addComponent` / `setProperty` / `removeComponent` / `moveComponent` / `addCallback`
on a plaintext model HARD-ERRORS with `AppDesignerAgentInterface:plaintextComponentsInXml`. To
add/remove/reconfigure a component or wire a callback, **edit the `.xml`**. Use the
code verbs (`setCallbackCode`, `addProperty`, `addMethod`) for the `.m`.

Why: `save()` re-reads the `.xml` as the live source of truth for components every
time. A component verb would mutate an in-memory tree that `save()` discards — so it
fails loudly instead of silently no-op'ing.

## The flow (important — differs from mlapp)

You cannot `create()` then `open()`: `create()` writes only the `.xml`; the `.m`
does not exist until `save()`, and `open()` requires the `.m`. **Keep the handle
from `create()`** and drive the whole session on it:

```matlab
% 1. create(): seeds a boilerplate <ClassName>.xml (only if none exists),
%    returns an in-memory handle. Does NOT write the .m.
appBuilder = AppDesignerAgentInterface.create("C:/path/MyApp.m");

% 2. Hand-author the component tree in C:/path/MyApp.xml on disk
%    (see XML format below). This is where components live.

% 3. Code side via verbs on the SAME handle (tool-owned .m):
appBuilder.setCallbackCode("startupFcn", "app.UIFigure.Name = ""Ready"";");
appBuilder.setCallbackCode("onGo", "app.UIFigure.Color = [0.2 0.6 0.9];");
appBuilder.addProperty("ClickCount", 0, "private");
appBuilder.addMethod("reset", strjoin([ ...
    "function reset(app)" ...
    "    app.ClickCount = 0;" ...
    "end" ], newline), "private");

% 4. save(): re-reads the .xml, merges the code, regenerates ONLY the .m,
%    gates on the real product loader. NEVER rewrites the .xml.
appBuilder.save();
```

To edit an existing plaintext app later, `open("C:/path/MyApp.m")` (both `.m` and
`.xml` must exist) and use code verbs; edit the `.xml` on disk for component changes.

### Editing timing: the model is a snapshot, the `.xml` is re-read at save

`open()`/`create()` snapshot the **code** side into the in-memory model. The
**component** side lives only in the `.xml`, which `save()` re-reads fresh from disk.
So the two sides update at different times, and the order that is always safe is:

1. `open()` (or keep the `create()` handle).
2. Edit the `.xml` on disk for any component change.
3. Apply code verbs on the handle for `.m` changes.
4. `save()` — it reads your latest `.xml` from disk and merges the model code.

You do NOT need to re-open after editing the `.xml`; `save()` reads the file, not a
cached copy. `inspect()`, however, reflects the model as loaded — it will not show
`.xml` edits you made after `open()`. Trust the file on disk for components, and
`inspect()` for code.

### Match the existing layout manager before adding a component

Before adding a component to an existing app, look at how the parent lays out its
children in the `.xml`. If the parent's children carry `<Layout>` blocks (a
`GridLayout` parent), your new child needs a `<Layout>` with `<Column>`/`<Row>` too —
a bare `<Position>` will not place correctly under a grid. If children use
`<Position>` (absolute), match that. Do not mix the two under one parent.

## The `.xml` format

`create()` seeds this boilerplate at `<ClassName>.xml`, co-located with the `.m`:

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<MATLABApp schemaVersion='1.0.0' release='R2026b.0' minRelease='R2026b'>
    <UIFigure name='UIFigure'>
    </UIFigure>
    <AppDetails>
        <Name>MyApp</Name>
        <Version>1.0</Version>
    </AppDetails>
    <InternalData>
        <AppId>...</AppId>
    </InternalData>
    <Thumbnail autoCapture='true'></Thumbnail>
</MATLABApp>
```

You fill in the tree. A figure with one wired button:

```xml
    <UIFigure name='UIFigure'>
        <Name>'Mini App'</Name>
        <Position>[100 100 300 200]</Position>
        <Children>
            <Button name='GoButton'>
                <Position>[100 80 100 40]</Position>
                <Text>'Go'</Text>
                <ButtonPushedFcn>onGo</ButtonPushedFcn>
            </Button>
        </Children>
    </UIFigure>
    <AppDetails> ... </AppDetails>
    <InternalData> ... </InternalData>
    <RunConfiguration>
        <StartupFcn>startupFcn</StartupFcn>
    </RunConfiguration>
    <Thumbnail autoCapture='true'></Thumbnail>
```

### XML rules (get these right or the parse/load fails)

1. **Each component is an element named after its type**, with a `name` attribute =
   its codeName: `<Button name='GoButton'>`. Nest children inside `<Children>`.
2. **Property values are parsed as NATIVE MATLAB literals** — this is the big one:
   - string: **single-quoted** — `<Text>'Go'</Text>`, `<Name>'Mini App'</Name>`.
     A bare `<Text>Go</Text>` throws `PlainTextBackend:unparseableValue`.
   - numeric vector / scalar: bare or bracketed — `<Position>[100 80 100 40]</Position>`,
     `<FontSize>14</FontSize>`.
   - cell array: `{...}`.
   - logical: `true` / `false`.
   - escape a literal `'` inside a quoted string by doubling it (`''`).
3. **Callback-wiring tags are the exception — they are bare** (a function name, not a
   parsed value): `<ButtonPushedFcn>onGo</ButtonPushedFcn>`. Wiring tags are detected
   by name (the `*Fcn` event names). Only the wiring lives in the `.xml`; the *body*
   is a code verb (`setCallbackCode`).
4. **Handle-typed properties (component -> component references) use the referenced
   component's codeName as a *quoted string literal*, same as any other string value.**
   The canonical example is attaching a `<ContextMenu>` (declared as a child of the
   figure) to another component:

   ```xml
   <UIFigure name='UIFigure'>
       <Children>
           <ContextMenu name='MyCtx'>
               <Children>
                   <Menu name='Item1'><Text>'Item 1'</Text></Menu>
               </Children>
           </ContextMenu>
           <Button name='MyBtn'>
               <Text>'Right-click me'</Text>
               <ContextMenu>'MyCtx'</ContextMenu>
           </Button>
       </Children>
   </UIFigure>
   ```

   The quotes are non-negotiable — the value goes through the same
   `PlainTextBackend:unparseableValue` gate as any other string. A bare
   `<ContextMenu>MyCtx</ContextMenu>` fails the parse; the product loader resolves
   the quoted codename to the live component handle at load time.
5. **`StartupFcn` is NOT a figure property** — put it under `<RunConfiguration>`, not
   as a `<UIFigure>` child. A `<StartupFcn>` under the figure becomes a bad
   constructor arg and fails to load.
6. **Layout** (for grid children only): a `<Layout>` block with `<Column>` before
   `<Row>`. `<Layout>` is valid **only** when the component's parent is a
   `GridLayout`. The top-level container (the direct child of `UIFigure`) must have
   **no** `<Layout>`. A stray `<Layout>` on a non-grid child loads without error but
   renders a blank canvas.
7. The root is always `<UIFigure name='UIFigure'>`.
8. **NEVER change `<AppId>`.** `create()` seeds a unique `AppId` under `<InternalData>`.
   It is the app's stable identity — leave it exactly as seeded. Do not regenerate,
   edit, blank, or copy it from another app. Editing it can break the product's
   caching/identity tracking. When you hand-author or edit the `.xml`, preserve the
   `<InternalData>`/`<AppId>` block verbatim.

The property/type/event names are the same product-validated set as mlapp — see the
type list and event examples in the shared guide.

## `validate()` — the dry-run you should use before/instead of guessing

For plaintext, `save()` has an unavoidable side effect (it writes the `.m`), so a
side-effect-free check is genuinely useful. `validate()`:
- re-reads your `.xml`, merges the model code, runs the cross-file (Layer-3) reconcile
  in **report** mode,
- returns a struct array of `{code, message}` (empty = coherent), throws nothing,
  writes nothing.

The one real cross-file drift it catches: a callback **wired in the `.xml`** with no
**body in the model** (`AppDesignerAgentInterface:missingCallbackBody`) — a silently broken app
you cannot see by eye. It also flags orphan bodies (a `setCallbackCode` for a
callback nothing wires) as advisory. Run `validate()` after authoring the `.xml` and
setting bodies, before `save()`.

## `save()` for plaintext: write-then-gate, and it NEVER writes the `.xml`

1. Re-read your `.xml` (live component truth) and merge with the model's code.
2. Layer-3 reconcile (throws `AppDesignerAgentInterface:missingCallbackBody` on wired-but-bodyless).
3. Regenerate **only the `.m`** and write it to the real path.
4. Run the **real product loader** on the `.m` + your `.xml`. On failure, the files
   are **left on disk** (they are human-readable and recoverable) and the loader
   errors are thrown — open the files, fix the drift, save again.

The `.xml` is **byte-identical** before and after `save()`. The tool never edits a
file you authored. If a component is wrong, that is a `.xml` edit you make, not
something the tool will "reconcile" for you.

## `finalize()`: canonicalize the `.xml` and open it for viewing

`finalize()` works for plaintext too — same verb, same contract as mlapp (launch App
Designer, save through the product, leave the app open for the user to view with its
theme rendered). What the save accomplishes differs by format:

- **mlapp** bakes the runnable classdef (there is a stub to fill in).
- **plaintext has no stub to bake** — the product regenerates the runnable class on
  load, so the `.m` is left unchanged. The save instead **canonicalizes the `.xml`
  into App Designer's exact form**: it drops default-valued properties (e.g. a
  `<Value>0</Value>` that equals the default disappears) and normalizes element order,
  so an agent-authored app matches what a human's AD session would produce. It also
  gates on the product's real loader, so `finalize()` doubles as an early surface for
  any load issue in the files you wrote.

```matlab
AppDesignerAgentInterface.finalize("C:/path/MyApp.m");            % default 60s deadline
AppDesignerAgentInterface.finalize("C:/path/MyApp.m", 120);       % raise deadline
```

- The `<AppId>` is preserved through the canonicalizing save — the product does not
  touch it (consistent with rule 7).
- Cost: ~3-5s warm, up to ~16s on a cold AD launch.
- Requires a live App Designer / connector session (the save routes through AD's JS
  code engine). Works headless (no `-desktop` needed).
- Only needed when you want the app **viewed** (theme rendered) or the `.xml`
  canonicalized. If you are going to keep editing via `AppDesignerAgentInterface`, you do not need to
  finalize between edits — `save()` alone keeps the files loadable.

### Close-then-open: finalize releases the file from AD first

Like mlapp, `finalize()` runs the **posture-A guard** before it opens: if App Designer
is already holding this file, it **closes** the clean copy first, then **opens** it
fresh. If AD holds the file with **unsaved edits**, `finalize()` **rejects** (never
discards your work) — save or close it in App Designer, then retry. This close-then-open
sequence is why finalize is safe to call on an app you may already have open in AD, as
long as it has no unsaved changes.

### finalize deadline / wedge behavior (know this)

App Designer can wedge (e.g. a modal dialog if a file changed under it), and the
open/save waits have no built-in timeout. `finalize` runs under a hard-deadline
watchdog: if the **open** wait exceeds the deadline it aborts and throws
`AppDesignerAgentInterface:finalizeTimeout` **without closing anything** — recover manually
(close App Designer / the stuck app, then retry, or raise `deadlineSeconds`). A
save-side wedge is rare (save on an already-open, ready app is fast) and is
intentionally NOT force-closed either.

### Editing after `finalize()` — free the file first (avoid the reload wedge)

`finalize()` leaves the app **open in App Designer**. AD is now holding the file. If
you edit that file on disk while AD holds it, AD detects the out-of-band change and
raises a modal "reload?" dialog that **wedges** the client. So before any post-finalize
edit, release the file from AD first. Which verb depends on what you are editing:

- **Editing components (the `.xml`)** → call `AppDesignerAgentInterface.release("C:/path/MyApp.m")`
  first. There is nothing to snapshot (`save()` re-reads the `.xml` fresh), so you just
  need the file freed. Then hand-edit the `.xml`, `save()`, and `finalize()` again to
  re-preview.
- **Editing code (callbacks / properties / methods)** → call
  `AppDesignerAgentInterface.open("C:/path/MyApp.m")` first. `open()` both releases AD **and**
  snapshots the existing `.m` into the model so your code verbs edit real content
  instead of an empty model. Then apply code verbs, `save()`, `finalize()` again.

Both `release()` and `open()` run the same posture-A guard: a **clean** open copy is
closed (disk holds the truth); an open copy with **unsaved edits** is **rejected**
(`AppDesignerAgentInterface:appOpenAndModified`) — save or close it in App Designer first.

`finalize()` is otherwise the **last** action of a build or an edit — you do not
finalize between edits. The only reason to finalize, edit, and finalize again
is the iterate-to-preview loop above (small adjustments after seeing the app).

## Gotchas specific to plaintext

- **Quote your string property values** (rule 2 above). This is the most common
  first mistake coming from the mlapp path, where values are passed natively.
- **Keep the `create()` handle**; do not `create()` then `open()` before the first
  `save()` (the `.m` will not exist yet).
- **Do not call component verbs** — they hard-error. Author components in the `.xml`.
- The `.xml` filename must be `<ClassName>.xml` and co-located with the `.m` (the
  loader resolves `AppConfigFilename` as `./<ClassName>.xml` relative to the `.m`).
- **Never touch `<AppId>`** (rule 7 above) — preserve the seeded value verbatim on
  every edit; it is the app's stable identity.

----

Copyright 2026 The MathWorks, Inc.

----
