---
name: roadrunner-core
description: "Foundation skill for all RoadRunner workflows: MATLAB path setup, connection, project/scene/scenario lifecycle, world settings, handle management, status, and close. Use when connecting to RoadRunner, managing projects/scenes/scenarios, setting world origin, checking status, closing RoadRunner, or when any downstream RoadRunner skill needs initialization."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
  matlab_version: ">=R2022a"
  products:
    - Automated Driving Toolbox
    - RoadRunner
---

# RoadRunner Core

Foundation skill for all RoadRunner agent workflows. Manages the RoadRunner connection, project/scene/scenario lifecycle, and handle management from MATLAB. Produces the `rrApp` handle used by all downstream RoadRunner skills.

Execution: all MATLAB code runs via `evaluate_matlab_code` MCP tool. Never `matlab -batch`.

## When to Use

- Connecting to or launching RoadRunner from MATLAB
- Creating, opening, or saving projects, scenes, or scenarios
- Setting world origin or scene extents
- Checking RoadRunner status
- Closing RoadRunner safely
- Any downstream RoadRunner skill needs `rrApp` initialization

## When NOT to Use

- **RoadRunner is not installed** — this skill requires a working RoadRunner installation; it cannot install the product
- **MATLAB version below R2022a** — the `roadrunner` class and related APIs are not available in earlier releases
- **`rrApp` already exists and is valid** — re-running `rrCoreInitialize` is safe (it's idempotent) but unnecessary; prefer checking `exist('rrApp','var')` first to avoid the overhead
- **User has not provided installation or project paths** when first-time setup is needed — ask the user first, do not guess paths
- **RoadRunner is intentionally closed** — do not reconnect or relaunch without explicit user permission

---

## 1. How the Agent Uses This Skill

### First-time setup (once per machine — two-tier resolution)

`rrCoreInitialize` handles setup automatically using a two-tier approach:

| Tier | Condition | What happens |
|------|-----------|--------------|
| 1 | Settings valid + `roadrunner` class on path | Setup skipped — already configured |
| 2 | Agent has `installFolder` and `projectPath` variables | Programmatic setup: `addpath`, `savepath`, writes MATLAB settings. No GUI. |

**Just run `rrCoreInitialize`.** The script automatically:
1. Connects to a running instance (`roadrunner.connect()`)
2. If that fails, launches a new instance (`roadrunner()`) using saved settings
3. If not configured, errors with `PathsRequired` — then ask the user for `installFolder` and `projectPath`, set them, and re-run

Once setup succeeds, it persists forever (across MATLAB sessions). Never needed again.

**No GUI dialogs.** This skill never calls `roadrunnerSetup`. All configuration is done programmatically.

### First call in a session

1. **Add the skill scripts to the MATLAB path** (required before `rrCoreInitialize` can be found):
   ```matlab
   addpath("<absolute-path-to-this-skill>/scripts");
   ```
   Replace `<absolute-path-to-this-skill>` with the actual filesystem path to this skill's directory (the folder containing this SKILL.md file).
2. Run `rrCoreInitialize` → it handles everything: connects to a running instance, or launches one using saved settings, or errors with a clear message if not configured.
3. If it errors with `PathsRequired` → ask the user for `installFolder` and `projectPath`, set them as variables, re-run `rrCoreInitialize`.
4. Proceed with the user's request.

### Subsequent calls

1. Check `exist('rrApp','var')` — if missing, re-run `rrCoreInitialize`
2. Look up the operation in the Decision Logic table (Section 3)
3. Copy the exact pattern from `scripts/rrCoreCommands.m` under the matching `%%` heading
4. Substitute placeholders with actual values
5. Execute via `evaluate_matlab_code`

### Key principle

**Never improvise API calls.** Before every RoadRunner operation, **read the matching `%%` section** from `rrCoreCommands.m` and reproduce it exactly. Do not guess function names, argument syntax, or parameter orders from memory. This prevents hallucinated function names, missing guard rails, and forgotten handle invalidation.

If you are unsure of the correct syntax for any operation, **stop and read the pattern file** before attempting the call.

---

## 2. Files

| File | Role |
|------|------|
| `scripts/rrCoreInitialize.m` | **Runs directly.** Bootstraps path + connection + validation. |
| `scripts/rrCoreCommands.m` | **Pattern reference.** Agent reads `%%` section, substitutes placeholders, executes. |

### Deployment

On first use, the agent ensures the RoadRunner API is on the MATLAB path (one-time `savepath`). The scripts in this skill are pattern references — the agent reads them and reproduces the patterns via `evaluate_matlab_code`.

---

## 3. Decision Logic

| User Intent | Pattern (`%%` section) | Placeholders to substitute |
|-------------|------------------------|---------------------------|
| Connect / initialize | `INIT` | — |
| Connect without launching | `CONNECT_ONLY` | — (errors if no instance running) |
| Create a new project | `NEW_PROJECT` or `NEW_PROJECT_WITH_ASSETS` | `projectPath` — **ask user** whether to include base assets (asset library). Always `rrCoreInitialize` first (RoadRunner must be running with any project before `newProject` can be called). |
| Open an existing project | `OPEN_PROJECT` | `projectPath` |
| Save the project | `SAVE_PROJECT` | — |
| Create a new scene | `NEW_SCENE` | — |
| Open a scene | `OPEN_SCENE` | `sceneName` — if not found, use `LIST_SCENES` and present options |
| List available scenes | `LIST_SCENES` | — |
| Save the scene | `SAVE_SCENE` or `SAVE_SCENE_AS` | **Ask user**: "Save in place, or save with a new name?" If new name → use `SAVE_SCENE_AS` with `sceneName` |
| Create a new scenario | `NEW_SCENARIO` | — |
| Open a scenario | `OPEN_SCENARIO` | `scenarioName` — if not found, use `LIST_SCENARIOS` and present options |
| List available scenarios | `LIST_SCENARIOS` | — |
| Save the scenario | `SAVE_SCENARIO` | — |
| Set world origin | `CHANGE_WORLD_ORIGIN` | `lat`, `lon` |
| Set scene center and extents | `CHANGE_SCENE_BOUNDS` | `x`, `y`, `w`, `h` |
| Set scene center only | `CHANGE_SCENE_CENTER` | `x`, `y` |
| Set scene extents only | `CHANGE_SCENE_EXTENTS` | `w`, `h` |
| Clear world projection | `CLEAR_WORLD_PROJECTION` | — |
| Check status | `STATUS` | — |
| Close RoadRunner | `CLOSE` | — |

> **Available From:** `changeWorldSettings` requires **R2023b** or later. All other operations are available from R2022a.

### Launch (handled by `rrCoreInitialize`)

After first-time setup, `rrCoreInitialize` automatically launches RoadRunner using saved defaults if no instance is running. Manual launch is only needed for non-default modes:

```matlab
rrApp = roadrunner(ProjectFolder=projectPath, InstallationFolder=installFolder);
```

| Mode | Add this argument |
|------|-------------------|
| Headless (no UI) | `NoDisplay=true` |
| No desktop + graphics | `NoDesktop=true` |
| Custom ports | `Ports=[apiPort, cosimPort]` |

Manual launch still requires explicit user permission.

---

## 4. Placeholders

These are the variable names used in `rrCoreCommands.m`. The agent substitutes them with actual values before executing.

| Placeholder | Type | Example |
|-------------|------|---------|
| `SKILL_SCRIPTS_DIR` | `string` | *(absolute path to this skill's `scripts/` folder)* |
| `rrApp` | `roadrunner` | *(from rrCoreInitialize, never reassigned)* |
| `projectPath` | `string` | `"D:/Projects/HighwayProject"` |
| `sceneName` | `string` | `"FourWaySignal.rrscene"` |
| `scenarioName` | `string` | `"CutInScenario"` |
| `lat` | `double` | `42.3021` |
| `lon` | `double` | `-71.3747` |
| `x`, `y` | `double` | `1445`, `1237` |
| `w`, `h` | `double` | `160`, `465` |
| `installFolder` | `string` | `"C:/Program Files/RoadRunner R2026a"` |

---

## 5. Handle Management

This skill produces `rrApp` via `rrCoreInitialize`. Operations that change state (`NEW_SCENE`, `OPEN_SCENE`, `NEW_SCENARIO`, `OPEN_SCENARIO`, `OPEN_PROJECT`, `CLOSE`) include `clear` statements to remove stale handles.

---

## 6. Path Setup

RoadRunner API path is added to MATLAB's saved path on first use. No config files or environment variables needed.

The agent runs `savepath` after adding the API path — this persists across MATLAB sessions. If the user upgrades RoadRunner, the agent detects the failure (`roadrunner` class missing or version mismatch) and asks for the new installation folder.

---

## 7. Critical Rules

1. **Always `rrCoreInitialize` first** — never call RoadRunner APIs without a validated `rrApp`
2. **Never launch without permission** — ask the user before `roadrunner(ProjectFolder=...)`
3. **One `rrApp` per session** — never create a second connection
4. **Read the pattern before every call** — open `rrCoreCommands.m`, find the `%%` section, reproduce it exactly. Do not guess syntax from memory.
5. **Never auto-save** — `NEW_SCENE`, `NEW_SCENARIO`, and `CLOSE` patterns detect unsaved changes but do NOT save automatically. Always ask the user whether to save, save-as, or discard. Saving with the same name overwrites the original and can break backwards compatibility if the file was created with an older version.
6. **Verify version after connect** — check `rrApp.Version` and report it. If the user requested a specific version, warn if it doesn't match.
7. **Ask before save** — when saving is needed (new scene/scenario, close, or explicit save request), ask the user whether to save in place, save with a new name, or discard changes
8. **List on not-found** — if `openScene` or `openScenario` fails because the name doesn't exist, list available scenes/scenarios using `dir` and present options to the user
9. **Relative scene paths** resolve to `<project>/Scenes/`
10. **Unicode not supported** in paths
11. **Handle invalidation is automatic** — patterns include `clear` statements
12. **All execution via MCP** — never `matlab -batch`
13. **`close(rrApp)` terminates RoadRunner entirely** — the process exits. After close, `roadrunner.connect()` will fail. A fresh `roadrunner()` launch is required to reconnect.
14. **Scene is NOT restored on relaunch** — after close + relaunch, RoadRunner opens the project but shows a blank scene. The agent must explicitly reopen the desired scene.

---

## 8. Anti-Patterns

- Do not launch RoadRunner without user permission
- Do not call `roadrunner(ProjectFolder=...)` when already connected — this launches a duplicate instance
- Do not pass two arguments to `roadrunner.connect(port, port)` — use single port
- Do not call any function on a closed/invalid `rrApp`
- Do not skip `clear` statements from the patterns
- Do not invent function calls not present in `rrCoreCommands.m` (e.g., no `save(rrApp)`, no `saveSceneAs`, no `switchScenario`, no `Latitude=lat`)
- Do not hardcode installation paths — use the resolution chain in `rrCoreInitialize`
- Do not save a scene without asking the user — `saveScene(rrApp, name)` silently overwrites existing files
- Do not confuse "close MATLAB" with "close RoadRunner" — they are independent processes
- Do not assume scene is restored after relaunch — it is not; always reopen explicitly

---

## 9. Project Structure

```
<RoadRunner Project>/
├── Assets/              3D models, materials, textures
├── Scenes/              .rrscene files
├── Scenarios/           .rrscenario files
├── Exports/             Exported output
├── Project/             Project metadata
└── Scripts/             User scripts (optional)
```

---

## 10. API Behavior Notes

### Project

- `newProject` creates any missing parent folders
- The folder name becomes the project name
- If `openProject` targets an already-open project, a new blank scene is still created

### Scene

- Relative paths resolve to `<project>/Scenes/`
- `.rrscene` extension is optional — RoadRunner appends it if missing
- If the scene belongs to a different project, RoadRunner switches to that project
- If modified assets exist during save, the project is also saved
- `saveScene(rrApp, name)` silently overwrites if the name already exists — no confirmation
- `saveScene(rrApp)` on an unnamed (new) scene errors — must provide a name
- Subfolder paths work (e.g., `"Scenarios/subfolder/Name"`)

### Scenario

- `newScenario`, `openScenario`, `saveScenario` available since R2022a
- Opening a new scene automatically closes the active scenario
- Scenarios can be opened even on a blank (unsaved) scene

### World Settings

| Parameter | Type | Description |
|-----------|------|-------------|
| `WorldOrigin` | `[lat lon]` | Geospatial world origin |
| `SceneCenter` | `[x y]` | Center of scene workspace |
| `SceneExtents` | `[w h]` | Scene workspace dimensions |
| `ClearWorldProjection` | logical | Clear current projection |

Available since R2023b.

### Status Properties

```matlab
rrStatus = status(rrApp);
rrStatus.Project.Filename         % Current project path
rrStatus.Project.UnsavedChanges   % true/false
rrStatus.Scene.Filename           % Current scene path
rrStatus.Scene.UnsavedChanges     % true/false
rrStatus.Scenario.Filename        % Current scenario path
rrStatus.Scenario.UnsavedChanges  % true/false
```

| Property | Description |
|----------|-------------|
| `rrApp.InstallationFolder` | RoadRunner install path |
| `rrApp.Version` | Version string |
| `rrApp.NoDisplay` | Console mode flag |
| `rrApp.NoDesktop` | No-desktop mode flag |

### Close

- `close(rrApp)` does **NOT** prompt to save — always save before closing
- Deletes the associated `roadrunner` object — do not reuse the variable after closing
- **Terminates the RoadRunner process entirely** — it is not just a disconnect
- After close, `roadrunner.connect()` will fail (nothing to connect to)
- On relaunch via `roadrunner()`, the project is restored but the **scene is NOT** — a blank scene appears
- Port validation enforces range 1024–65535

### Connection

```matlab
rrApp = roadrunner.connect();           % Default port 35707
rrApp = roadrunner.connect(portNumber); % Explicit port
```

| Mode | Syntax | Use case |
|------|--------|----------|
| GUI (default) | `roadrunner(ProjectFolder=...)` | Interactive use |
| Headless | `roadrunner(ProjectFolder=..., NoDisplay=true)` | Batch/CI, no UI |
| No desktop + graphics | `roadrunner(ProjectFolder=..., NoDesktop=true)` | Export needing render |
| Custom ports | `roadrunner(ProjectFolder=..., Ports=[apiPort, cosimPort])` | Multi-instance |

----

Copyright 2026 The MathWorks, Inc.

----
