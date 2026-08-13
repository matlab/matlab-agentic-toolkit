# Phase 8: Publish Toolbox

Version-stamp, re-package with the release version baked in, and distribute.

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlab.addons.toolbox.ToolboxOptions` | Load config and set version |
| `matlab.addons.toolbox.packageToolbox` | Package with version baked in |

## Step 8.0 — Confirm with User

**ALWAYS** present what you're about to do and wait for explicit "yes":

```
I'm about to publish this toolbox:

- Toolbox: <name>
- Identifier: <UUID>
- Version: <version>
- Output: release/<version>/<Name>.mltbx
- Target: <distribution target>

This will:
1. Re-package the toolbox with version "<version>" baked in
2. Update version in all project locations
3. [Distribute to target]

This action is not easily reversible. Proceed? [yes/no]
```

## Step 8.1 — Validate Version

If not provided, ask. Validate by assigning to `ToolboxOptions.ToolboxVersion`:
- Minimum: `"1.0"`
- Standard: `"1.2.3"` (MAJOR.MINOR.PATCH)
- Extended: `"1.2.3.4"` (with build number)

## Step 8.2 — Update Version Everywhere (BEFORE Packaging)

**MANDATORY — do this BEFORE packaging.** Update in ALL locations:

| Location | What to update |
|----------|---------------|
| `buildUtilities/toolboxSpecification.m` | `spec.toolbox.version = "X.Y.Z"` |
| `buildfile.m` | `opts.ToolboxVersion` if hardcoded in packageTask |
| `Contents.m` | Version line: `% Version X.Y.Z DD-Mon-YYYY` |
| `toolboxPackaging.prj` | Version XML element (if PRJ-based) |

Grep for the OLD version string to find any other locations.

## Step 8.3 — Re-package with Release Version

```matlab
if isMATLABReleaseOlderThan("R2025a")
    opts = matlab.addons.toolbox.ToolboxOptions("toolboxPackaging.prj");
else
    opts = matlab.addons.toolbox.ToolboxOptions("<projectname>.prj");
end

opts.ToolboxVersion = "<version>";

releaseDir = fullfile("release", "<version>");
if ~isfolder(releaseDir), mkdir(releaseDir); end
opts.OutputFile = fullfile(releaseDir, "<Toolbox_Name>.mltbx");
opts.ToolboxGettingStartedGuide = fullfile("toolbox", "doc", "GettingStarted.m");

matlab.addons.toolbox.packageToolbox(opts);
```

Verify: file exists, non-zero size.

## Step 8.4 — Distribute

| Target | Action |
|--------|--------|
| **local** | Done — report path |
| **github** | `gh release create v<ver> release/<ver>/Name.mltbx` (only if explicitly requested) |
| **internal** | Copy to shared location |

**No File Exchange API** — guide user to browser upload.
**No git/VCS operations unless explicitly requested.**

## Rules

- **Never auto-publish.** Always confirm.
- **Version must be explicit.** Don't guess.
- **Re-package for release.** Cannot just rename a `.mltbx`.
- **UUID is identity.** Never change it between versions.
- **Output in `release/<version>/`.** Prevents overwriting previous releases.
- **Filename uses underscores.** Replace spaces for cross-platform compatibility.
- **Version updated everywhere before packaging.** A mismatch is a bug.
- **Do NOT interact with git** (tag, push, commit, .gitignore checks) unless the user explicitly asks. VCS operations are the user's responsibility.

----

Copyright 2026 The MathWorks, Inc.

----
