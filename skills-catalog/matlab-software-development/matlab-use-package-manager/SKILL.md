---
name: matlab-use-package-manager
description: >
  Manage MATLAB packages with the in-product MATLAB Package Manager (mpm) on
  MATLAB R2026b or later: install, uninstall, update, search, or inspect
  packages; declare package dependencies in a matlab.toml project; install a
  shareable .mltbx package; or manage repositories. Covers dependency-resolution
  errors and anything involving mpminstall / mpmuninstall / mpmupdate / mpmlist /
  mpmsearch / mpmAddRepository / matlab.mpm.*. MATLAB *packages* are distinct from MathWorks
  products, toolboxes, and support packages: a bare "what packages are installed?"
  means MPM packages (mpmlist / matlab.mpm.Package) — this skill — unless the user
  explicitly says products, toolboxes, or support packages. NOT for installing
  MATLAB, Simulink, or toolboxes from a shell via the standalone mpm executable
  (the OS-level product installer), nor for listing installed products / toolboxes
  (ver, installedAddons) — use matlab-install-products for those.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Use the MATLAB Package Manager (mpm)

Manage MATLAB packages from inside a running MATLAB session with the in-product
MATLAB Package Manager — the `mpm*` command family and the `matlab.mpm.*` classes.
Targets **MATLAB R2026b or later** (declared in `manifest.yaml`) and encodes the
non-obvious behavior that trips up agents: the interactive-prompt trap, project
provisioning, destructive flags, and safe package-property inspection.

Run all code through the MATLAB MCP tools. For project structure, `matlab.toml`
schema, and reference projects, use the **`matlab-configure-toml-project`** skill.

This is **in-product mpm** — `mpm*` commands run *inside* a MATLAB session. The
identically-named OS-level `mpm` shell executable that installs MATLAB, Simulink,
and toolboxes is a different tool (→ `matlab-install-products`).

## When to Use

- Install, uninstall, update, search, or list any MATLAB package
- Ask "what packages are installed?", "what does X depend on?", "where does X live?", or "what versions exist?"
- Resolve a known package name or check the installation status of a package declared in a `matlab.toml` project
- Install a shareable `.mltbx` package
- Add, remove, or list a repository, or diagnose "Unable to locate dependency" errors

## When NOT to Use

- **Installing MATLAB, Simulink, or toolboxes from a shell** (`mpm install --products …`) — use `matlab-install-products`. Same acronym, different binary.
- **The full `.mltbx` authoring pipeline** (define API → analyze deps → project → document → build → publish) — use `matlab-package-toolbox`.
- **Editing project configuration or using reference projects** — use `matlab-configure-toml-project`. A `{ path, absolute }` dependency makes another project's source available; it does not install a package.
- **Code-file / product dependency analysis** via `requiredFilesAndProducts` — a different concern from declared package dependencies.
- **MATLAB namespaces** (`+folder`) with no mpm involvement, or licensed toolboxes (use `ver`).
- **MATLAB older than R2026b** — the in-product `mpm*` workflow isn't the intended path; suggest the Add-On Manager GUI.

## Critical Rules

These apply to EVERY workflow below; violating any one causes a failure.

1. **Always pass `Prompt=false`** to `mpminstall`, `mpmuninstall`, `mpmupdate`, and `openProject`. The interactive confirmation can't be answered in a non-interactive session (MCP / `-batch`) and hangs — surfacing as a misleading "Array indices must be positive integers" error, not a question.
2. **Only `mpmsearch(Name=…)` is case-sensitive.** Everything else (`mpminstall`/`mpmuninstall`/`mpmupdate`, `mpmsearch(PackageSpecifier=…)`) matches names case-insensitively.
3. **Use `mpmsearch` only to search indexed repositories.** File Exchange and custom/service-backed (Artifactory/MPRS) repos are **not** indexed, so an empty result never means "not found". Discover a File Exchange submission by keyword through the MathWorks search endpoint and install its `package_name` (Recipe C); enumerate a custom/service-backed repo through its REST API (Recipe C) or try package names with `mpminstall(..., DryRun=true, Prompt=false)`.
4. **Use `mpminstall(..., DryRun=true, Prompt=false)` to resolve package names.** It searches every configured repository and reports the selected repository without installing anything. Prefer this command over `mpmsearch` to confirm a package name or version.
5. **Use projects and `matlab.toml` for reproducibility.** A `-batch` install does not persist because of MATLAB settings, and a long-lived MCP session can cache its registry at startup. In R2026b, opening a TOML project with `Prompt=false` additively installs missing declared packages, so declare the project environment instead of relying on an earlier session's install.
6. **Package files and the MATLAB path are separate.** Packages typically live under `%APPDATA%\MathWorks\MATLAB Add-Ons\` on Windows, `~/Library/Application Support/MathWorks/MATLAB Add-Ons/` on macOS, and `~/MATLAB Add-Ons/` on Linux. Installing makes their folders available on the MATLAB path. `mpmuninstall` removes that package exposure but leaves files on disk unless `Delete=true` is supplied. `Temporary=true` is not ephemeral and has no queryable property.
7. **All package installs are global.** There is no project-scoped package store. A project's `[dependencies]` declaration is provisioned when the TOML project opens; use `mpmlist` to inspect the installed global package.
8. **Keep packages separate from reference projects.** Use the project package form `{ version = "…", id = "…" }` for packages. Use `matlab-configure-toml-project` for `{ path, absolute }` reference projects.
9. **`Force=true` is destructive.** On install it can remove other installed packages; on uninstall it cascades to dependents. Confirm with the user and say what will be removed first.

## Router

| The user wants to… | Recipe |
|--------------------|--------|
| Install / acquire a package to use it | A. Consume a package |
| Know what's installed / what a package is / what it depends on | B. Inspect package info |
| Search indexed repositories / find a File Exchange submission / enumerate a custom repo / list every available version | C. Search & enumerate versions |
| Build a shareable MATLAB package (`.mltbx`) | D. MATLAB package authoring |
| Declare / edit / read dependencies in `matlab.toml` | E. Project (matlab.toml) dependencies |
| Upgrade an installed package | F. Update a package |
| Fix "Unable to locate dependency" / add a repository | G. Repository setup |
| Work on cloned package code | Use a reference project through `matlab-configure-toml-project` |
| Remove packages / reclaim disk | H. Uninstall & cleanup |

Load `references/api-and-gotchas.md` when a recipe points there or an unexpected error appears.

## A. Consume a Package

**In a project (recommended for R2026b and later):**

Declare the package in the project's `matlab.toml`, then open the project with
`Prompt=false`. MATLAB additively installs missing declared packages.
See [E](#e-project-matlabtoml-dependencies) and use `matlab-configure-toml-project` for the full
project schema.

**Without a project:**

```matlab
mpminstall("Battery", DryRun=true, Prompt=false)   % probe the name resolves
mpminstall("Battery@1.1.0", Prompt=false)          % install a specific version
mpmlist("Battery")                                  % confirm it landed
```

`InstallDependencies=true` is the default (transitive deps come along). Specify as much as
reproducibility needs: `"Name"`, `"Name@Version"`, or `"Name@Version@id"` for an
exact match.

## B. Inspect Package Info

**Answer "what packages / what does X depend on" via `mpmlist` and
`matlab.mpm.Package`** — never `matlab.addons.installedAddons`,
`installedToolboxes`. Package properties are authoritative. Only the Package object
surfaces the source `Repository`, resolved dependency versions, and the
`DirectlyInstalled` / `Installed` flags.

```matlab
pkgs = mpmlist;                 % all installed -> matlab.mpm.Package array
pkg  = mpmlist("Battery");      % filter to one
```

Read properties directly, for example `pkg.Name`, `pkg.Version`, `pkg.ID`, and
`pkg.PackageRoot`. For dependency values, index `pkg.Dependencies` and read the needed
properties such as `.Name`, `.VersionRange`, `.ResolvedVersion`, and `.ID`.
**Displaying is the trap:** `string(pkg)` / `fprintf("%s",…)` on a `Package`, or on an
object-valued property (`Provider`, `Dependencies`, `Repository`, `Folders`), **throws** —
read the scalar leaf field instead (`pkg.Folders(1).Path`, not `string(pkg.Folders)`).
Scalar `disp(pkg)` works; converting a whole object array does not.
`pkg.MissingDependencies` empty ⇒ all resolved. Don't use `proj.Dependencies` for
packages — that's the file-dependency digraph (empty until Dependency Analyzer runs).
The property list and display caveats are in `references/api-and-gotchas.md`.

## C. Search & Enumerate Versions

### In MATLAB (mpmsearch)

`mpmsearch` has three query forms — pick by what you have:

```matlab
found = mpmsearch("battery");                                      % 1. free-text KEYWORD search (positional)
found = mpmsearch(Name="Battery", VersionSelectionPolicy="all");   % 2. exact name — every version
found = mpmsearch(PackageSpecifier="Battery@1.1.0");               % 3. a name@version specifier
% loop found(k): .Name, .Version, .Repository.Name (as in Recipe B — don't disp the array)
```

- **Keyword** (positional) when you don't know the name; **`PackageSpecifier=`** (or `Name=` + `VersionRange=`) for a name+version — never a composite `Name="Battery@1.1.0"` (throws).
- `VersionSelectionPolicy="all"` is **required** to list every version (default `"highestByRepository"` hides older ones). Filter by repo with `Repository=` (**singular** — `Repositories=` errors); other filters: `VersionRange=`, `ID=`, `Provider=`, `CompatibleWithRelease=`.
- FX and custom/service-backed repos aren't indexed — empty ≠ "not found" (Rule 3). Resolve a known package with `mpminstall(..., DryRun=true, Prompt=false)` before concluding it is unavailable.

### File Exchange keyword discovery (the search endpoint)

`mpmsearch` never returns File Exchange results. Discover an FX submission by keyword
through the MathWorks search endpoint
(`.../searchresults/results?…&request_handler=select`) and read its **`package_name`** —
that is the identifier `mpminstall` needs. A submission's page title, the URL's numeric
id, and its slug are **not** installable specifiers, and `uuid` only disambiguates
same-titled submissions. File Exchange is a default repository in R2026b, so once you
have the name:

```matlab
mpminstall("knownPackageName", DryRun=true, Prompt=false)   % confirm it resolves
mpminstall("knownPackageName", Prompt=false)                % or "knownPackageName@1.2.0" for a version
```

FX versions can't be enumerated programmatically; `DryRun` reports the version the
registry *resolves*, which can lag the FX web page (the result `url` is the current
source). For the `curl`, the `fl=` field list, and the response schema, see
`references/api-and-gotchas.md` § Finding a File Exchange submission.

### Custom / service-backed repositories (REST)

A custom or Artifactory-backed (MPRS) repository isn't indexed either, so `mpmsearch`
returns empty with no error — that is by design, not a missing package. Query the
service's REST API directly: `/v1/packages/by-name/<name>.json` for a candidate name,
`/v1/packages/index.json` to enumerate everything, with an `Authorization: Bearer`
header whose token comes from the environment and never a literal. Discovery only —
install still goes through `mpminstall` once the repo is registered (Recipe G). The
endpoints, the in-MATLAB `webread` form, the manifest fields, and the
by-name-vs-index rule are in `references/api-and-gotchas.md`
§ Searching a custom repository.

## D. MATLAB Package Authoring

Build shareable MATLAB packages as `.mltbx` files through
**`matlab-package-toolbox`**. It owns the authoring pipeline, including package
metadata, declared package dependencies, documentation, and build validation.

Use this skill after authoring to install a resulting `.mltbx` with `mpminstall`
and verify it with `mpmlist`.

## E. Project (matlab.toml) Dependencies

Declare a package dependency, then open the project with `Prompt=false` so MATLAB
additively installs any missing packages.

```toml
[dependencies]
Battery = { version = ">=1.1.0", id = "c1438758-4eaf-438f-b04f-6a7279735de5" }
```

Use the inline `{ version, id }` package form. For reference projects
(`{ path, absolute }`) and the full `matlab.toml` schema, use `matlab-configure-toml-project`.

```matlab
proj = openProject("/path/to/proj", Prompt=false);   % auto-installs declared deps
reload(proj)                                          % re-resolve after editing matlab.toml
runChecks(proj)                                       % treat any Missing/Unresolved as failure
```

To **read** declared package dependencies, parse the `[dependencies]` section directly,
then cross-reference `mpmlist` for install status — do not open the project just to list
them. After editing, `proj.ProjectDependencies` should show resolved package identity and
version. A **stale open project silently suppresses auto-install** — if another project is
already open, `openProject` is a no-op for provisioning; `close(currentProject)` first.

## F. Update a Package

Update an installed package with `mpmupdate`:

```matlab
mpmupdate("Edge", DryRun=true, Prompt=false)    % preview first — changes nothing on disk
mpmupdate("Edge", Prompt=false)                 % newest available version
mpmupdate("Edge", "3.2.10", Prompt=false)       % specify exact version (plain string, not ">=")
```

The version range defaults to `"*"` (any version newer than installed — no
within-major ceiling). Dependency handling *is* conservative: `UpdateDependencies`
defaults to `"necessary"`, so transitive deps move only when required. Update
**won't** cross package identity — a version with a **different ID/provider** is a
different package sharing the name; swap it deliberately with
`mpminstall("Edge@3.2.10", AllowVersionReplacement=true, Prompt=false)`.

## G. Repository Setup

```matlab
repos = mpmListRepositories;                               % loop repos to read Name + Location
mpmAddRepository("File Exchange", matlab.mpm.FileExchange) % not configured by default everywhere
mpmAddRepository("myRepo", "/path/to/repo")                % folder repo (UNC on Windows)
mpmRemoveRepository("myRepo")
```

**Custom/authenticated repository (Artifactory, etc.):** register it from a
`repo-config.json` via `matlab.mpm.RepositoryConfiguration`:

```matlab
% Consumer: set the token env var first (ARTIFACTORY_TOKEN), then:
jsonFile = "/path/to/repo-config.json";
cfg = matlab.mpm.RepositoryConfiguration(jsonFile);
mpmAddRepository(cfg)
```

Each entry in the file's `repository_configuration` array (`schema_version "1.0.0"`)
has `name`, `url` (the Package Repository Service base URL — **not** raw Artifactory),
`type "custom"`, and an `auth.access_token` that is an **env-var placeholder**
`"${ARTIFACTORY_TOKEN}"`, never a literal token (resolved at runtime, or from a
`setSecret` secret) — safe to share. See `references/api-and-gotchas.md`
§ repo-config.json schema for the annotated JSON.

`Unable to locate dependency '…'` almost always means the hosting repository isn't
registered — check `mpmListRepositories` first. `mpminstall` has **no `Repository`
argument** (it resolves across all registered repos); scope by repo only on `mpmsearch`.

## H. Uninstall & Cleanup

```matlab
mpmuninstall("Pkg", Prompt=false)                          % remove package from the MATLAB path; leave files on disk
mpmuninstall("Pkg", Prompt=false, Delete=true)             % explicitly remove package files from disk
installed = mpmlist;
mpmuninstall(installed([installed.Name] ~= "mpmUtilities"), Prompt=false, Delete=true)  % filtered batch
```

`mpmuninstall` accepts a `matlab.mpm.Package` array — filter and pass it, do not loop.
`KeepUnusedDependencies` defaults to `false` (orphaned dependencies are auto-removed);
`Delete=true` is what actually reclaims disk. Never use `matlab.addons.uninstall`.

## Key Functions

All available in the baseline, **MATLAB R2026b or later**.

| Function | Purpose |
|----------|---------|
| `mpminstall` | Install package(s) from configured repositories or a completed `.mltbx` file (resolves deps) |
| `mpmuninstall` | Remove package(s); `Delete=true` clears disk |
| `mpmupdate` | Update to the newest available version (deps only as necessary) |
| `mpmlist` | List installed packages as a `matlab.mpm.Package` array |
| `mpmsearch` | Search configured repositories; enumerate versions |
| `mpmAddRepository` / `mpmRemoveRepository` / `mpmListRepositories` | Manage the repository search list |
| `matlab.mpm.RepositoryConfiguration` | Load a `repo-config.json` for authenticated/custom repos |
| `matlab.mpm.Package` | Installed-package metadata object (20 properties) |
| `openProject` | Open a TOML project and additively provision declared packages |

## Conventions

Beyond the Critical Rules: preview package installation and updates with `DryRun=true`,
then re-check with a fresh `mpmlist` / `runChecks(proj)`; use
`VersionSelectionPolicy="all"` to list every version; keep `Verbosity` to
`"quiet"`/`"normal"`/`"detailed"`. **Ask first**
before adding/removing a repository or installing a package the user did not name
(supply-chain risk).

For the complete gotcha list (`Repositories=` plural, `Temporary` without cleanup, and
more), see `references/api-and-gotchas.md`.

## References

- `references/api-and-gotchas.md` — exact MPM syntax, package-property display caveats,
  the File Exchange search endpoint, the custom-repository REST API, and the full
  package-manager gotcha catalog. Load for a lookup or unexpected error.
- **`matlab-configure-toml-project` skill** — for TOML schema, project references, project
  paths, and conversion between project definition formats.
- **`matlab-read-documentation` skill** — for exact `mpm*` / `matlab.mpm.*` syntax.

----

Copyright 2026 The MathWorks, Inc.

----
