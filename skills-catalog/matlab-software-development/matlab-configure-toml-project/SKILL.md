---
name: matlab-configure-toml-project
description: |
  Use whenever "project" or "matlab.toml" is mentioned in a MATLAB context.
  This includes creating, editing, organizing, or configuring MATLAB projects,
  declaring MATLAB package dependencies or reference projects, setting up paths,
  lifecycle scripts, shortcuts, MATLAB packages, or asking about project structure.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab.toml Projects

`matlab.toml` is a TOML-based configuration file for MATLAB projects. It defines project structure, dependencies, lifecycle scripts, shortcuts, labels, packaging, deployment, and Simulink settings. Every section is optional — the schema mandates no top-level field — but always set `name`, which supplies the project's display name.

`matlab.toml` must be placed at the project root folder — the same folder that would contain a `.git/` folder or be the top-level working folder for the project.

For MATLAB R2026b and later, prefer `matlab.toml` for new projects. Existing `.prj`
projects remain supported and can be converted in either direction with:

```matlab
matlab.project.convertDefinitionFiles(pwd, "Toml")
```

Opening a project with `openProject`, `buildtool`, or `runtests` activates its
configuration. The project's `[folders].path` entries then control the MATLAB path,
so do not spread `addpath` calls through source and test files.

- Use **`matlab-use-package-manager`** for MATLAB packages.
- Use **`matlab-package-toolbox`** to author and build `.mltbx` MATLAB packages.
- @references/format-reference.md — complete field documentation with examples, plus the validation rules that govern the whole file
- @references/deployment-reference.md — the `[compiler]` deployment targets

## When to Use

- The user mentions `matlab.toml`, or "project" in a MATLAB context (creating, editing, or inspecting a MATLAB project's configuration).
- Setting up MATLAB path folders, test folders, lifecycle scripts, shortcuts, package dependencies, reference projects, file labels, export profiles, MATLAB package metadata, deployment targets, or Simulink project settings.
- Auditing an existing `matlab.toml` for schema violations before they cause silent failures.

## When NOT to Use

- The user wants to drive project state through the MATLAB object API directly (`matlab.project.createProject`, `proj.addPath`, etc.) rather than author or edit the file — that is a legitimate but different task; this skill's workflows assume the file is the artifact being produced.
- The task is editing a `.prj`-format project definition. Do not carry `.prj` keys or concepts over into `matlab.toml` — the schemas are not equivalent. A reference project may still target a `.prj` project.
- The task only concerns `[compiler.*]` deployment target internals in depth — read @references/deployment-reference.md directly rather than following the Creation/Editing workflows below, which are file-level, not per-target.

## Key Functions

| Function | Purpose |
|----------|---------|
| `openProject` | Loads a `matlab.toml` (or `.prj`) as the current project. **Does not validate the schema** — unrecognized keys, missing files, and wrong types all load silently. Use it to confirm the file parses, never as a correctness check. |
| `currentProject` | Returns the currently open `Project` object; use its `Name`, `PathFolders`, `TestFolders`, `StartupFiles`, etc. properties to verify a round-trip after writing the file. |
| `matlab.project.createProject` | Creates a new project through the imperative API instead of authoring the file. Avoid this as the mechanism for producing `matlab.toml` — write the TOML directly (see Creation Workflow, step 3). |

## Creation Workflow

When a user wants to create a new `matlab.toml` (no existing file), follow this scan-first approach:

1. **Ask for the project name.** This is the only required field.

2. **Scan the current folder** for existing structure:
   - Find subfolders containing `.m`, `.mlx`, `.slx`, or `.mlapp` files. Propose these as `[folders].path` entries.
   - Identify folders whose names contain "test" (e.g., `tests/`, `test/`, `unitTests/`). Propose these as `[folders].test` entries.
   - Look for scripts matching `*startup*` or `*setup*` patterns — propose as `startup-files`.
   - Look for scripts matching `*shutdown*` or `*cleanup*` or `*teardown*` patterns — propose as `shutdown-files`.
   - Exclude hidden folders (`.git`, `.svn`, etc.) and common output folders (`derived/`, `results/`, `build/`).

3. **Generate a draft** starting minimal — name, folders, and any discovered lifecycle scripts. Present it to the user.

4. **Ask about optional sections** as needed, not as a checklist:
   - MATLAB packages (not MathWorks products) and reference projects
   - Shortcuts to frequently-used scripts
   - File labels and export profiles (only if used in code or explicitly requested)
   - MATLAB package metadata (`[[package]]`) if the project ships as an `.mltbx`
   - Deployment targets (`[compiler.*]`) if the project builds a standalone app, library, or language package
   - Simulink settings (if `.slx` files are present)

5. **After generating the TOML file**, ask the user if they want the folders listed in `[folders]` to be created on disk (for nonexistent folders in new projects).

Start minimal and let the user add sections incrementally. One focused question at a time is better than a long questionnaire.

## Editing Workflow

When a `matlab.toml` already exists and the user wants to modify it:

1. **Read the existing `matlab.toml`** to understand the current configuration.

2. **Map the user's request to schema sections.** Identify which section(s) need changes — refer to @references/format-reference.md for valid fields and formats.

3. **Make targeted edits.** Modify only the sections the user asked about. Do not restructure, reformat, or reorder untouched sections. Preserve any user comments (`#` lines) in the file.

4. **Validate against the schema yourself.** `openProject` does **not** report schema violations — unknown keys, missing files, and wrong value types all load silently and are simply ignored. A successful `openProject` is not evidence the file is correct, so check every key against @references/format-reference.md rather than relying on MATLAB errors and warnings:
   - Dependency values must use one of the three supported formats (package version string, package version with ID, or reference-project path).
   - Array-of-tables (`[[project.profile]]`, `[[package]]`, `[[matlab.test.test-suite]]`, `[[compiler.*]]`) syntax must be correct.
   - **No unknown keys.** Every table except `[user]` is closed. Do not invent keys or carry over keys from `.prj` files.
   - **Path keys must resolve.** Most path values must point at files that exist and live inside the project root. Few paths (`startup-folder`, dependency `path`) can be outside the project root. Output paths (cache folders, build output) do not need to exist. The reference annotates each key. Confirming a path means listing the folder and seeing the entry — a truncated, filtered, or `head`-limited listing that fails to show it is not a confirmation, and neither is a `ls` of a guessed name that returns nothing.
   - Required fields must be present: `id` and `package-root` in `[[package]]`, `name` in `[[compiler.standalone]]`, `path` in project-path dependencies and shortcuts, `version` in version-with-ID dependencies, and both `category` and `label` in every label filter.

5. **Present the change** — show the user what will be modified before writing the file.

## Conventions

- **Author the TOML directly.** Do not produce `matlab.toml` by driving `matlab.project.createProject` and reading back what MATLAB wrote — write the file yourself, with the sections in the order given above.
- **Tables are closed.** Every table except `[user]` rejects unrecognized keys. Never invent a key or carry one over from a `.prj` file; check every key against @references/format-reference.md.
- **`openProject` is not a validator.** A file that opens cleanly may still contain silently-ignored schema violations — the only way to be sure a key is correct is to look it up.
- **Path values must be confirmed, not guessed.** Listing a folder and seeing the entry is a confirmation; a truncated, filtered, or `head`-limited listing that fails to show it is not, and neither is an `ls` of a guessed name that returns nothing.
- **MathWorks products are never `[dependencies]` entries.** `[dependencies]` accepts any key, so a product name loads silently and wrongly. Record product requirements elsewhere (e.g. `[project].summary`, `[[package]].product-dependencies`, or a comment).
- **Preserve what the user didn't ask you to touch.** Comments and section order in an existing file survive an edit unless the user's request required changing them.

## Quick Reference

| Section | Purpose | Key Fields |
|---------|---------|------------|
| `name` | Project name (always set it) | string |
| `[user]` | Free-form custom data | any keys/nested tables |
| `[folders]` | MATLAB path and test folders | `path`, `test` (arrays) |
| `[dependencies]` | Declare MATLAB packages (not MathWorks products) or reference projects | packages: version string or `{version, id}`; references: `{path, absolute}` |
| `[project]` | Lifecycle and metadata | `summary`, `startup-folder`, `startup-files`, `shutdown-files`, `custom-tasks` |
| `[project.dependency-analyzer]` | Dependency analysis cache | `cache-file` |
| `[project.shortcuts]` | Named script shortcuts | `{path, icon}` per shortcut; can be grouped |
| `[project.labels.Category]` | File categorization | `LabelName = ["file.m", "dir/"]` |
| `[[project.profile]]` | Export/filter profiles | `name`, `included-files`, `excluded-files`, `excluded-labels` |
| `[project.dashboards]` | Dashboard label groupings | `component`, `unit` (label references) |
| `[project.digital-thread]` | Traceability settings | `tool-output-tracking`, `ignore` |
| `[[package]]` | Build a MATLAB package | `id` (required), `package-root` (required), `name`, `version`, `summary`, `description`, `folders`, `apps`, `provider` |
| `[compiler.*]` | Deployment build targets | 10 targets: `standalone` (`name` required), `web-app`, `excel-add-in`, `dot-net-assembly`, `c-shared-library`, `cpp-shared-library`, `production-server-archive`, `com-component`, `java-package`, `python-package` — see @references/deployment-reference.md |
| `[matlab.test]` | Test runner configuration | `coverage-setting`, `test-suite` |
| `[simulink]` | Simulink settings | `start-simulink`, `cache-folder`, `codegen-folder`, `refresh-customizations` |
| `[simulink.process-advisor]` | Process Advisor settings | `incremental-build`, `enable-model-caching`, 9 more string properties |

`[[package]]` can include MATLAB code, Simulink models, apps, documentation, and other
project content in the resulting MATLAB package. Use `matlab-package-toolbox` for the
authoring and build workflow, or `matlab-use-package-manager` to install a completed
package.

## Package Dependencies and Reference Projects

Each key under `[dependencies]` names either a MATLAB package or a reference project.
MathWorks products are not packages and must not be listed here.

**Package dependency: version string** — for a MATLAB package:
```toml
mytoolbox = "3.*"
```

**Package dependency: version with ID** — when the package ID is available:
```toml
motor = {version = "*", id = "9b9e5bc2-a583-4d79-98c5-d2b9af135697"}
```

**Reference project** — for a project at a filesystem path (`absolute` is optional and
defaults to relative):
```toml
shared-utils = {path = "../shared_utils_lib"}
```
The referenced project can use either a legacy `.prj` definition or a `matlab.toml`
definition. The key is a display label chosen by the user and is unrelated to the folder
on disk. Confirm `path` by listing the candidate parent folder — never derive it from the
dependency name or from the other project's `name`.

## Examples

### Minimal

```toml
name = "My Project"
```

### Typical

```toml
name = "Signal Analyzer"

[folders]
path = [
    "src",
    "utilities",
]
test = [
    "tests",
]

[dependencies]
signal-processing = "2.*"

[project]
startup-files = [
    "setup/initialize.m",
]

[project.shortcuts]
"Run Analysis" = {path = "scripts/analyze.m"}
```

----

Copyright 2026 The MathWorks, Inc.

----
