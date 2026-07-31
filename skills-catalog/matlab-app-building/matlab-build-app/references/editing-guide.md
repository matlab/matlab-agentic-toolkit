<!-- Copyright 2026 The MathWorks, Inc. -->
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
