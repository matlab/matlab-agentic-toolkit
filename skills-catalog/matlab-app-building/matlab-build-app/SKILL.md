---
name: matlab-build-app
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.1"
description: >
  Build MATLAB apps from requirements to working code. Asks discovery questions
  (or skips them when the path is known), recommends UIFigure or UIHTML
  architecture, identifies layout archetype (Dashboard, Explorer, Tabbed, Wizard,
  Canvas), produces an implementation plan, and executes the build. For UIFigure
  apps, optionally serializes as App Designer (.mlapp or plain-text .m + .xml).
  Use when a user wants to build a MATLAB app, create a GUI, make an interactive
  tool, build a uifigure app, build a uihtml app, build an App Designer app,
  build a .mlapp app, build a plain-text App Designer app, or asks which approach
  to use. Also use when user describes spatial layout needs: dashboard, control
  panel, sidebar, tabs, wizard, stepper, canvas, workspace.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# MATLAB Build App

Determine the best architecture for a MATLAB application, produce an implementation plan grounded in internal references, and execute the build. For UIFigure apps, optionally serialize into an App Designer format.

## When to Use This Skill

Use this skill when:
- User wants to build a MATLAB app, GUI, or interactive tool
- User asks "how should I build this app?" or "which approach should I use?"
- User describes an application — with or without specifying an implementation path
- User mentions: MATLAB app, GUI, uifigure, uihtml, interactive tool, dashboard, visualization app, App Designer, .mlapp, plain-text app
- User describes spatial layout needs: dashboard, control panel, sidebar, tabs, wizard, stepper, canvas, workspace
- User has already chosen a path (e.g., "build me a uihtml app") — handle directly

## When Not to Use

- The request is purely about MATLAB computation with no UI component
- The user is asking about an existing app they want to modify → read `references/editing-guide.md`
- The user wants to convert between App Designer formats (e.g., .mlapp to plain-text or vice versa) → tell them to use File > Save As in App Designer. Do NOT attempt the conversion programmatically.

## Critical Rules

- MUST ask discovery questions before recommending a path — unless the user already specified one
- MUST confirm the path choice with the user before producing the implementation plan
- MUST produce an implementation plan grounded in internal references before writing any code
- MUST write the plan to a file (`<app-name>-plan.md`) in the working directory
- NEVER recommend a path without understanding the user's constraints (unless path was pre-specified)
- NEVER apply dark mode, custom colors, or visual themes unless the user explicitly requests them
- ALWAYS present the recommendation as guidance, not a mandate — the user decides
- MUST choose archetype based on the user's primary task, not aesthetics
- NEVER treat two archetypes as equals within one app — one is always the primary container
- UIFigure app: MUST use `uigridlayout` for all structural layout — never `Position`-based sizing
- UIHTML/web app: MUST use CSS Grid or Flexbox for chrome — no absolute positioning for structural panels
- The chrome (header, sidebar, tabs, step indicator) MUST remain spatially stable
- App Designer serialization: MUST read `references/app-designer/agent-guide-shared.md` (covers ownership models, editing discipline, property rules, quoting) plus the format-specific guide (`agent-guide-mlapp.md` or `agent-guide-plaintext.md`) before building. Those docs are the single source of truth; do not attempt to edit app files without reading them first.

## Workflow

```
User request arrives
        │
        ├── Path NOT specified → Full Discovery
        │       │
        │       ▼
        │   Ask Q1-Q4 (purpose, lifespan, polish, team skills)
        │       │
        │       ▼
        │   Identify layout archetype
        │       │
        │       ▼
        │   Recommend UIFigure vs UIHTML based on Q1-Q4
        │       │
        │       ▼
        │   *** STOP: Present recommendation and WAIT for user confirmation ***
        │   (Do NOT produce a plan or read references until user says yes)
        │       │
        │       ▼
        │   Ask Q5 (FINAL): Serialization format? (UIFigure apps only)
        │       │
        │       ├── App Designer → release check, present format choice,
        │       │       continue with UIFigure references + add serialization step
        │       │
        │       └── Standalone programmatic → no extra step
        │       │
        │       ▼
        │   Produce Implementation Plan → write to <app-name>-plan.md
        │       │
        │       ▼
        │   User reviews plan → confirms or adjusts
        │       │
        │       ▼
        │   Begin building (read references per the plan)
        │
        └── Path IS specified
                │
                ├── Serialization explicit (e.g., ".mlapp app", "plain-text app")
                │       → Skip Q5, proceed with stated format
                │       → Ask only missing requirements + archetype if unclear
                │       → Produce Implementation Plan
                │
                ├── Architecture explicit but serialization not stated
                │   (e.g., "build me a uifigure app")
                │       → Still ask Q5 (serialization) before planning
                │       → Ask missing requirements + archetype if unclear
                │       → Produce Implementation Plan
                │
                └── UIHTML or standalone programmatic explicit
                        → Skip Q5 entirely (not applicable)
                        → Ask missing requirements + archetype if unclear
                        → Produce Implementation Plan
```

## Discovery Questions

Ask these conversationally — not as a rigid checklist. Gather requirements and layout intent first; ask the serialization question **last**, once you understand what the app needs to do.

### Core Questions

**1. What does the app do and who is it for?**
> What will this app do? Who will use it?

Listen for archetype signals: "dashboard", "control panel", "step-by-step", "workspace".

**2. Is this a quick tool or something you'll maintain over time?**
> Is this meant to be maintained and evolved, or is it more of a quick, proof-of-concept tool?

- **Maintained** → proceed to remaining questions; team skills matter
- **Ephemeral** → favor UIHTML app path; can skip team question

**3. How polished does the UI need to look?**
> Are standard MATLAB buttons, sliders, tables, and plots enough? Or do you need custom visuals — branded, animated, or visually richer?

- Standard controls sufficient → UIFigure app signal
- Custom visuals needed → UIHTML app signal

**4. Who will work on this app going forward?**
> Will this be maintained by people comfortable only with MATLAB, or by people also comfortable with web technologies?

Only ask for maintained apps.
- MATLAB-only team → UIFigure app
- Web-comfortable team → UIHTML app

**5. (FINAL) How should this app be saved?**
> Do you want this app to open and edit inside App Designer, or do you prefer a standalone programmatic file (no App Designer dependency)?

This is a **serialization** question, not an architecture question. The app's structure (components, layout, callbacks) is designed using UIFigure knowledge regardless of the answer. Q5 only determines how that design is persisted to disk.

- **App Designer** → `.mlapp` or plain-text `.m` + `.xml`. Check release (plain-text needs R2026b+). If Q3 indicated custom visuals, note that App Designer constrains visual customization vs UIHTML and confirm.
- **Standalone programmatic** → programmatic `.m` code, no App Designer dependency. MVVM may warrant multiple files; that is decided at build time.

### Follow-up Probes (only if path isn't clear)

- **Interaction style:** Real-time feedback needed? → slight UIFigure lean
- **Existing work:** Existing MATLAB UI code? → UIFigure. Existing web assets? → UIHTML
- **Distribution:** May need to work outside MATLAB? → UIHTML

## Path Decision Logic

Two stages: first determine architecture (Q1-Q4), then determine serialization format (Q5).

```
Stage A — Architecture (from Q1-Q4):

Ephemeral app? → Strong default to UIHTML app

Maintained app? → Weigh signals:

Strong UIFigure signals:
  ✓ Maintained + MATLAB-only team
  ✓ Standard UI components sufficient
  ✓ Tight real-time interaction
  ✓ Existing MATLAB UI code

Strong UIHTML signals:
  ✓ Ephemeral (regardless of team)
  ✓ Maintained + web-skilled team
  ✓ Custom visuals, branded look, animations
  ✓ Existing web assets
  ✓ Future portability outside MATLAB

UIFigure + uihtml accent:
  Mostly standard app but needs one custom visualization panel.

Stage B — Serialization format (Q5, UIFigure apps only):

Q5 = Standalone → programmatic code (no App Designer). Done.

Q5 = App Designer → adds a serialization layer ON TOP of Stage A.
  UIFigure references still apply in full. Serialization is IN ADDITION TO,
  not instead of, the normal UIFigure build.
  → Check release, present format choice (plain text vs .mlapp).
  → If Stage A indicated UIHTML for custom visuals, surface the trade-off:
    App Designer constrains custom visuals — confirm before committing.
```

**Weighting:** 1. Architecture (Q1-Q4)  2. Serialization (Q5, applies only to UIFigure)

## Paths at a Glance

| Architecture | Key strength |
|------|--------------|
| **UIFigure app** | Single language, any MATLAB dev can maintain |
| **UIHTML app** | Full visual control, rich interactivity |
| **UIFigure + accent** | Best of both when you need one custom visual |

For UIFigure apps, three serialization formats:

| Format | Trade-off |
|------|--------------|
| Programmatic `.m` | Standalone, no App Designer dependency |
| App Designer `.mlapp` | Binary, works on any release, opens in App Designer |
| App Designer plain text `.m` + `.xml` | Source-controllable, AI-editable, R2026b+ |

## Layout Archetype

Pick based on the user's **primary task**:

| Archetype | Primary user task | Structure |
|---|---|---|
| **Dashboard** | Monitor and compare at a glance | KPI cards + charts + table; read-only |
| **Explorer** | Adjust parameters, observe live results | Sidebar controls + live display |
| **Tabbed** | Navigate between independent sections | Tab bar + content panels |
| **Wizard** | Complete a sequential workflow | Step indicator + one-step-at-a-time |
| **Canvas** | Create, inspect, or edit spatial artifacts | Central workspace + tools |

If unclear, ask: "Will users mostly be *watching results* (Dashboard), *tweaking controls* (Explorer), *switching sections* (Tabbed), *going through steps* (Wizard), or *working on a central figure* (Canvas)?"

## Implementation Plan

After confirming path and archetype, produce a plan and write it to `<app-name>-plan.md` in the working directory. Present a concise summary inline with the approval request.

### Plan Template

```
**Implementation Plan: [App Name]**

**Architecture:** [UIFigure app / UIHTML app / UIFigure + accent]
**Serialization:** [Programmatic .m / App Designer .mlapp / App Designer plain text]
**Layout:** [Archetype] — [one sentence describing spatial structure]

**Structure:**
- [Major panel/area — spatial description]
- [e.g., "Left sidebar (220px) with date range picker, category filter, refresh button"]
- [e.g., "Main area with line chart showing filtered results"]

**Key behaviors:**
- [User-visible interaction effects]

**Internal references that will be used:**

| Reference | Role in this app |
|-----------|-----------------|
| `references/path/file.md` | [what it provides] |
| ... | ... |

**External skills:**
- `matlab-build-chart` — [role, if applicable]
- `matlab-apply-theme` — [role, if applicable]

**File organization:**
[app directory tree]

**Implementation sequence:**
1. [First reference read] — [what it establishes]
2. [Next reference] — [what it adds]
3. [...]
```

Each reference pointer carries provenance: `[src: references/uifigure/grid-layout.md §Spanning]`

### Plan Quality Checks

Before presenting:
- [ ] Every reference listed has a concrete role
- [ ] Structure uses spatial terms the user can visualize
- [ ] Behaviors describe user-visible effects
- [ ] Implementation sequence shows a logical build order
- [ ] Plan is specific enough for "yes, that's what I want" or "change X"

## Reference Router

After plan approval, read the relevant internal references to execute the build.

### UIFigure Path

| When building... | Read |
|-----------------|------|
| Grid layout, sizing, components | `references/uifigure/guide.md` |
| Grid details (spanning, collapse) | `references/uifigure/grid-layout.md` |
| Panels, tab groups, nested grids | `references/uifigure/containers.md` |
| Component reference (controls, display) | `references/uifigure/components.md` |
| Callback patterns, data sharing | `references/uifigure/callbacks.md` |
| Layout recipes (sidebar, form, split) | `references/uifigure/layout-patterns.md` |
| MVVM architecture (complex apps) | `references/uifigure/mvvm-guide.md` |
| View binding patterns | `references/uifigure/mvvm-view-binding.md` |
| ViewModel testing | `references/uifigure/mvvm-testing.md` |

### UIHTML Path

| When building... | Read |
|-----------------|------|
| MATLAB-JS bridge, setup(), events | `references/uihtml/bridge-guide.md` |
| Communication patterns (4 patterns) | `references/uihtml/communication-patterns.md` |
| Data type conversion | `references/uihtml/data-types.md` |
| Platform constraints | `references/uihtml/platform-limitations.md` |
| uihtml creation, hybrid layouts | `references/uihtml/setup.md` |
| Error handling (both sides) | `references/uihtml/error-handling.md` |
| JS MVVM architecture | `references/uihtml/mvvm-guide.md` |
| Observable/Computed classes | `references/uihtml/mvvm-observable-classes.md` |
| JS View binding | `references/uihtml/mvvm-view-binding.md` |
| JS coding patterns, modules | `references/uihtml/js-coding-guide.md` |
| JS testing & debugging | `references/uihtml/js-testing-debugging.md` |
| Chart.js setup & patterns | `references/uihtml/charting-guide.md` |
| Chart type selection | `references/uihtml/chart-type-selection.md` |
| Chart.js initialization | `references/uihtml/chartjs-setup.md` |
| Line & bar charts | `references/uihtml/line-bar-charts.md` |
| Doughnut & scatter charts | `references/uihtml/doughnut-scatter-charts.md` |
| Chart data updates | `references/uihtml/chart-updates.md` |
| Chart ↔ bridge integration | `references/uihtml/chart-bridge-integration.md` |
| Chart performance | `references/uihtml/chart-performance.md` |
| CSS styling & tokens | `references/uihtml/styling-guide.md` |
| Component CSS (buttons, inputs) | `references/uihtml/component-styles.md` |
| CSS layout patterns | `references/uihtml/css-layout-patterns.md` |
| Brand design tokens | `references/uihtml/brand-design-tokens.md` |
| Dark mode | `references/uihtml/dark-mode.md` |
| External color schemes | `references/uihtml/external-color-schemes.md` |

### App Designer Serialization (UIFigure apps only)

**Important:** App Designer serialization is an additional step AFTER the normal UIFigure build. You MUST also read the UIFigure path references above (components, grid-layout, callbacks, containers, layout-patterns) to design the app's structure. The serialization references below cover only how to persist that design to disk.

Both formats use the same `AppDesignerAgentInterface` API via the bundled `scripts/` tool; only the file extension passed to `create()`/`open()` differs.

**Read first (both formats):**

| When building... | Read |
|-----------------|------|
| Verbs, build sequence, editing, `save()`/`validate()`/`finalize()`, `inspect()` | `references/app-designer/agent-guide-shared.md` |

**Plain-text (`.m` + `.xml`):**

| When building... | Read |
|-----------------|------|
| Ownership model, `.xml` authoring, flow, gotchas | `references/app-designer/agent-guide-plaintext.md` |
| classdef structure & block ordering rules | `references/app-designer/plaintext/classdef-template.md` |
| XML structure and which properties to set | `references/app-designer/plaintext/xml-template.md` |
| Per-component property names, types, defaults | `references/app-designer/plaintext/property-reference.md` |
| Authoritative XML schema | `references/app-designer/plaintext/matlabAppSchema.xsd` |

**Binary `.mlapp`:**

| When building... | Read |
|-----------------|------|
| Build flow, native property values, `save()`/`finalize()` | `references/app-designer/agent-guide-mlapp.md` |

### Editing an Existing App

| When editing... | Read |
|----------------|------|
| Any existing app (determines format, routes to approach) | `references/editing-guide.md` |

### Archetype References

| Archetype | File |
|-----------|------|
| Dashboard | `references/archetypes/dashboard.md` |
| Explorer | `references/archetypes/explorer.md` |
| Tabbed | `references/archetypes/tabbed.md` |
| Wizard | `references/archetypes/wizard.md` |
| Canvas | `references/archetypes/canvas.md` |

### External Skills (invoked, not read)

- `matlab-build-chart` — when the app includes MATLAB plots (UIFigure path or UIFigure+accent)
- `matlab-apply-theme` — when the app needs dark mode, brand colors, or custom palettes (UIFigure path)

## After Plan Approval

### All UIFigure apps (regardless of serialization format)

1. Read the archetype reference for the spatial skeleton
2. If MVVM warranted (Explorer, Wizard, Canvas, or complex apps): read the architecture reference
3. Read the UIFigure guide to establish layout (grid, components, containers)
4. Layer in path-specific references per the implementation sequence
5. For visual polish: invoke `matlab-apply-theme` (UIFigure) or read styling references (UIHTML accent)
6. For charts: invoke `matlab-build-chart` (UIFigure) or read charting references (UIHTML accent)
7. **If App Designer serialization:** read the app-designer reference docs (shared guide + format-specific guide), then use the `AppDesignerAgentInterface` API to persist the app. The docs contain the complete build flow, property rules, and editing discipline.

### UIHTML path

1. Read the archetype reference for the spatial skeleton
2. If MVVM warranted: read the JS MVVM architecture reference
3. Read the bridge guide to establish the MATLAB-JS connection
4. Layer in path-specific references per the implementation sequence
5. For visual polish: read styling/CSS references
6. For charts: read charting references

### Format Fallback

If the plain text path produces errors that cannot be resolved (e.g., version mismatch, unsupported component), fall back to the `.mlapp` path — the same verbs drive both formats; re-create the handle with a `.mlapp` extension. Only fall back to fully programmatic UIFigure code as a last resort.

## Recommendation Template

**Recommended architecture: [UIFigure app / UIHTML app / UIFigure + accent]**

Based on what you've described:
- [Key signal 1]
- [Key signal 2]
- [Key signal 3, if applicable]

**What this means:** [1-2 sentences on development experience]

**Trade-off:** [Main thing they'd give up vs the other path]

**Serialization (if App Designer):** I'd recommend [.mlapp / plain text] because [reason]. This doesn't change the app's structure, just how it's saved.

Want to proceed with this approach, or would you prefer the other path?

----

Copyright 2026 The MathWorks, Inc.

----
