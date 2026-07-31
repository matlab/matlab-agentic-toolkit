---
name: matlab-publish-toolbox
description: "Version-stamp, re-package, and distribute the .mltbx toolbox. Sets version in ToolboxOptions, re-runs packageToolbox, and guides distribution. Requires explicit user confirmation."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-publish-toolbox — Release Publisher

You handle the final release step: version stamping, re-packaging with the release version baked in, and distribution. This is an irreversible action — you always confirm with the user before proceeding.

## When to Use

- After `matlab-build-toolbox` produces a verified `.mltbx`
- User says "publish this" or "release it"
- As the final step in the full pipeline

## When NOT to Use

- The toolbox has not been built yet — use `matlab-build-toolbox` first
- User wants to iterate on packaging or fix issues — use `matlab-assess-toolbox`
- User wants to update the spec or API — use `matlab-define-toolbox-api`
- User wants to do a dry-run build without publishing — use `matlab-build-toolbox`

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlab.addons.toolbox.ToolboxOptions` | Load packaging configuration and set version |
| `matlab.addons.toolbox.packageToolbox` | Package the toolbox with version baked in |
| `matlab.addons.install` | Install a toolbox from `.mltbx` (for verification/distribution) |

## Inputs

- **project_root**: Path to the project (default: current directory)
- **version** (optional): Version to release (e.g., `"1.2.0"`). Must be valid semver — minimum `"1.0"`, accepts `"1.2.3"` or `"1.2.3.4"`.
- **target** (optional): Where to distribute — `"local"`, `"github"`, `"internal"`

## Workflow

### Step 0 — Confirm with User

**ALWAYS** present what you're about to do and wait for explicit confirmation:

```
I'm about to publish this toolbox:

- Toolbox: My Toolbox
- Identifier: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
- Version: 1.2.0
- Output: release/1.2.0/My_Toolbox.mltbx
- Target: [where it's going]

This will:
1. Re-package the toolbox with version "1.2.0" baked in
2. Update version in all project locations (toolboxSpecification, buildfile, Contents.m)
3. [Distribute to target]

This action is not easily reversible. Proceed? [yes/no]
```

**Do NOT proceed without explicit "yes" from the user.**

### Step 1 — Validate Version

If version was not provided, ask the user. Never guess.

Validate the version string by assigning it to `ToolboxOptions.ToolboxVersion` — this accepts all formats MATLAB supports:
- Minimum: `"1.0"`
- Standard: `"1.2.3"` (MAJOR.MINOR.PATCH)
- Extended: `"1.2.3.4"` (with build number)
- Prerelease: `"1.0.0-beta"` (semver prerelease tag)

```matlab
% Validate by attempting assignment — errors if format is invalid
opts.ToolboxVersion = version;
```

Follow semantic versioning: MAJOR = breaking API changes, MINOR = new functionality (backwards-compatible), PATCH = bug fixes.

### Step 2 — Confirm Readiness

This skill does not re-check documentation, help text, or spec drift — that is `matlab-assess-toolbox`'s job. Simply confirm that readiness has passed:

1. If `buildUtilities/toolboxSpecification.m` exists, confirm `matlab-assess-toolbox` reported no blockers
2. If no pipeline context, confirm the user has verified their project is release-ready

If readiness has not been run, direct the user to `matlab-assess-toolbox` before proceeding.

### Step 3 — Update Version Everywhere (BEFORE Packaging)

**MANDATORY — do this BEFORE packaging.** The version must be consistent across all source files before the `.mltbx` is built. If `buildfile.m` reads the version from `toolboxSpecification.m` or has it hardcoded, it must already be correct when `packageToolbox` runs.

Update the version string in ALL of the following locations that exist:

| Location | What to update | How to find it |
|----------|---------------|----------------|
| `buildUtilities/toolboxSpecification.m` | `spec.toolbox.version = "X.Y.Z"` | Always present if pipeline was used |
| `buildfile.m` | `opts.ToolboxVersion = "X.Y.Z"` in the `packageTask` function (if version is hardcoded there) | Read the package task and check for a literal version string |
| `Contents.m` | Version line (format: `% Version X.Y.Z DD-Mon-YYYY`) | At project root or in `toolbox/` |
| `toolboxPackaging.prj` | Version XML element | Only if PRJ-based packaging is used |

**Search strategy:** Grep the project for the OLD version string to find any other locations that hardcode it (README badges, CITATION files, etc.). Update those too.

```bash
# Find all files containing the old version
grep -r "1.0.0" . --include="*.m" --include="*.md" --include="*.prj"
```

Do NOT skip this step. Do NOT defer it to after packaging. A released toolbox with version "1.1.0" in its `.mltbx` metadata but "1.0.0" in `buildfile.m` or `toolboxSpecification.m` will produce the wrong version on the next build.

### Step 4 — Re-package with Release Version

Version is baked into the `.mltbx` at packaging time. After updating all source files (Step 3), package:

```matlab
% Load packaging configuration
if isMATLABReleaseOlderThan("R2025a")
    opts = matlab.addons.toolbox.ToolboxOptions("toolboxPackaging.prj");
else
    opts = matlab.addons.toolbox.ToolboxOptions("<projectname>.prj");
end

% Set the release version
opts.ToolboxVersion = "1.2.0";

% Set output to release/<version>/ with underscored filename
% Including version in the path prevents overwriting previous releases
% and makes it easy to find/distribute a specific version.
releaseDir = fullfile("release", "1.2.0");
if ~isfolder(releaseDir), mkdir(releaseDir); end
opts.OutputFile = fullfile(releaseDir, "<Toolbox_Name>.mltbx");

% Set Getting Started guide (use the actual filename — .m or .mlx — found in the project)
opts.ToolboxGettingStartedGuide = fullfile("toolbox", "doc", "GettingStarted.m");

% Package with version baked in
matlab.addons.toolbox.packageToolbox(opts);
```

After packaging, verify:

```matlab
mltbxFile = opts.OutputFile;
assert(isfile(mltbxFile), "Package not created");
info = dir(mltbxFile);
assert(info.bytes > 0, "Package file is empty");
fprintf("Package: %s (%.1f KB)\n", mltbxFile, info.bytes / 1024);
fprintf("Identifier: %s\n", opts.Identifier);
```

### Step 5 — Distribute

| Target | Action |
|--------|--------|
| **local** | Done — `.mltbx` is in `release/`. Report path. |
| **github** | Only if user explicitly requests: `gh release create v1.2.0 release/1.2.0/Toolbox_Name.mltbx --title "v1.2.0" --notes "..."` |
| **internal** | Copy to shared network location or artifact repository |

**File Exchange**: There is no programmatic upload API. If the user wants to publish to File Exchange, guide them to upload manually via the browser.

**Do NOT interact with git (tag, push, commit, .gitignore checks) unless the user explicitly asks.** VCS operations are the user's responsibility.

### Step 6 — Report

```
## Published

- Toolbox: My Toolbox v1.2.0
- Identifier: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
- Artifact: release/1.2.0/My_Toolbox.mltbx (142.3 KB)
- Target: [where it was published]
- Version updated in: toolboxSpecification.m, buildfile.m, Contents.m

### Installation
Users can install with:
  matlab.addons.install("release/1.2.0/My_Toolbox.mltbx")

### Suggested Next Steps
- Tag the release in version control (e.g., `git tag -a v1.2.0 -m "Release v1.2.0"`)
- Announce the release
- If using File Exchange: upload via browser
- Start next version development
```

## Output

- Version-stamped `.mltbx` in `release/` directory
- Distribution to the specified target
- Release report

## Checkpoint

**Yes — always.** Publishing is irreversible. Never auto-execute. The user must explicitly confirm the version, target, and intent.

## Key Rules

- **Never auto-publish.** This is the most irreversible action in the pipeline. Always confirm.
- **Version must be explicit.** Don't guess — ask the user if not provided. Validate by assigning to `ToolboxOptions.ToolboxVersion` (errors on invalid format).
- **Re-package for release.** Version is baked in at packaging time. You cannot just rename a `.mltbx` — you must call `packageToolbox` with the release version set.
- **UUID is identity.** The `Identifier` (UUID) is what makes MATLAB recognize updates vs. new toolboxes. Never change it between versions. Always report it.
- **Output goes in `release/<version>/`, not source control.** The `.mltbx` is a derived artifact placed in a version-specific subdirectory (e.g., `release/1.2.0/Toolbox_Name.mltbx`). This prevents overwriting previous releases and makes it trivial to find/distribute a specific version.
- **Filename uses underscores.** Replace spaces in the display name with underscores for the `.mltbx` filename (cross-platform compatibility).
- **Version must be updated everywhere.** Before packaging, grep for the OLD version string and update ALL locations: `toolboxSpecification.m`, `buildfile.m` (if it hardcodes the version in `packageTask`), `Contents.m`, README badges, etc. A version mismatch between the packaged `.mltbx` and the source files is a bug. This is not optional — it is a mandatory step before packaging.
- **No File Exchange API.** Do not pretend you can upload programmatically. Guide the user to the browser.
- **No git/VCS operations unless explicitly requested.** Do not create tags, push, commit, check `.gitignore`, or run any VCS command. Suggest VCS actions in the report's "Next Steps" but never execute them automatically.
- **Report the installation command.** Use the modern `matlab.addons.install` API.

----

Copyright 2026 The MathWorks, Inc.

----

