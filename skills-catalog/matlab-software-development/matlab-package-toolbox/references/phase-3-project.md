# Phase 3: Create Project

Create a fully configured MATLAB project from the existing folder using `matlab.project.*` APIs via the MATLAB MCP server.

**Skip if:** A MATLAB project already exists (`.prj` file with `resources/project/` folder).

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlab.project.createProject` | Create a new project with specified definition type |
| `openProject` | Open an existing project |
| `addFile` | Add files to the project |
| `addPath` | Add folders to the project path |
| `genpath` | Generate path string for folder tree |

## Critical Rules

1. **NEVER overwrite existing files.** Check before creating.
2. **ALWAYS prompt before creating new folders.** Present recommended folders and wait for confirmation.
3. **Do NOT move or rename any existing files.**

## Step 3.1 — Discover Existing Content

- List all files recursively
- If a `.prj` file exists, ask: (A) This is a MATLAB project → open it, (B) Legacy deploytool file → proceed
- Read `Contents.m` if present for function descriptions
- Identify file types and existing subfolders

## Step 3.2 — Determine Project Identity

- **Name**: From `Contents.m` title line, folder name, or dominant theme
- **Description**: 1–3 sentence summary

## Step 3.3 — Create the MATLAB Project

```matlab
proj = matlab.project.createProject("Folder", '<projectFolder>', ...
    "Name", "<inferred name>", ...
    "DefinitionType", "FixedPathMultiFile");
proj.Description = "<generated description>";
```

**Why FixedPathMultiFile:** Produces `.prj` + `resources/project/` structure that is SCM-friendly.

## Step 3.4 — Add All Existing Files

Add every file in the project folder. Use `dir(..., '**', '*.<ext>')` for recursive discovery.

## Step 3.5 — Configure Project Path

```matlab
if isfolder(fullfile(proj.RootFolder, "toolbox"))
    pathRoot = fullfile(proj.RootFolder, "toolbox");
else
    pathRoot = proj.RootFolder;
end

allFolders = strsplit(genpath(pathRoot), pathsep);
for i = 1:numel(allFolders)
    if ~isempty(allFolders{i}) && ~contains(allFolders{i}, filesep + "internal")
        addPath(proj, allFolders{i});
    end
end
```

**Why this logic:** `genpath` already excludes `+pkg/`, `@class/`, `private/`, and dot-folders — but NOT `internal/` folders. The `internal/` folder uses MATLAB's scoping convention: functions inside are only visible from the parent folder, never from the global path. When `toolbox/` exists, only its contents should be on the MATLAB path.

## Step 3.6 — Create README.md

**Only if README.md does not already exist.** Generate with: title, description, function table grouped by category, Getting Started section.

## Step 3.7 — Suggest Best-Practice Folders

Present recommended folders based on [mathworks/toolboxdesign](https://github.com/mathworks/toolboxdesign):

| Folder | Purpose |
|--------|---------|
| `tests/` | Unit tests using the MATLAB Testing Framework |
| `examples/` | Live Script examples and tutorials |
| `doc/` | Documentation (e.g., `GettingStarted.m`) |
| `toolbox/` | Distributable content separated from dev infrastructure |

**ASK the user:**
> A) **All** — create all recommended folders
> B) **Select** — pick specific folders
> C) **Skip** — don't create any new folders

----

Copyright 2026 The MathWorks, Inc.

----
