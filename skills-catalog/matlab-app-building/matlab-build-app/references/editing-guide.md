# Editing an Existing App

When a user wants to modify an existing app (not build from scratch), determine the format, then consult the Reference Router in SKILL.md for which docs to read.

## Determine the Format

| What's on disk | Format | Reference Router section |
|---------------|--------|------------------------|
| `AppName.mlapp` (binary) | App Designer .mlapp | App Designer Serialization |
| `AppName.m` + `AppName.xml` (class has `AppConfigFilename` constant property pointing to the `.xml`) | App Designer plain-text | App Designer Serialization |
| `AppName.m` (standalone, calls `uifigure()`, no `AppConfigFilename`) | Programmatic UIFigure | UIFigure Path |
| `AppName.m` + HTML/CSS/JS assets (uses `uihtml()`) | UIHTML | UIHTML Path |

If uncertain: open the `.m` and look for `AppConfigFilename` as a constant property (App Designer plain-text), `uihtml()` calls (UIHTML), or bare `uifigure()` calls with no App Designer class structure (programmatic).

App Designer apps use the UIFigure architecture. For App Designer edits, also consult the UIFigure Path section for component, layout, and callback guidance.

## Adding a background task to an existing programmatic app

Background execution requires a class-structured (MVVM) app: durable per-task state, shared methods, and a `CloseRequestFcn` that cancels in-flight work on close (see `references/background-tasks.md`). Before wiring anything in, classify the existing programmatic app's structure:

| What's on disk | Structure | What to do |
|---------------|-----------|------------|
| Class with a `View`/`ViewModel`/`Model` split, figure property named `UIFigure`, existing `CloseRequestFcn` | MVVM, ready | Wire the task in per `references/uifigure/mvvm-background-tasks.md`. No restructure needed. |
| A class, but not MVVM (single classdef, no View/ViewModel/Model split) | Partial | Restructuring to MVVM is required. **Get consent first** (see below). |
| Flat script or nested-function app (`uifigure()` with local/nested functions, no classdef) | Flat | Restructuring to MVVM is required. **Get consent first** (see below). |

> ### STOP — get consent before restructuring
>
> If the app is not already MVVM-ready, adding a background task means **restructuring the user's working app to MVVM**. This is a large change that touches code the user already relies on.
>
> **You MUST present the restructure and get explicit consent before making any change.** State what will be restructured, that it rewrites existing working code, and the risk. Do NOT restructure silently, and do NOT half-wire the infrastructure into a flat app (it will lack durable state and cleanup, and fail silently at runtime).
>
> Only proceed once the user has agreed. This gate is for **programmatic** apps only. App Designer apps (`.mlapp` / plain-text) are already class-structured, so no consent is needed there: the `addBackgroundTask` verb handles the wiring.
>
> **Back up the app file(s) before restructuring.** The restructure rewrites the user's working code in place and there is no automatic recovery backup for programmatic apps. Once consent is given, copy each file you are about to change to a `.backup` alongside it, then restructure:
>
> ```matlab
> copyfile("myApp.m", "myApp.m.backup");
> ```
>
> Tell the user where the backup was written so they can restore it if the restructured app does not work.

Copyright 2026 The MathWorks, Inc.

----
