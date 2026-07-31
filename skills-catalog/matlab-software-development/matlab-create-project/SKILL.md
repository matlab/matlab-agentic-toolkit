---
name: matlab-create-project
description: |
  Creates a MATLAB project for an existing folder of MATLAB files using the
  matlab.project.* APIs via MCP. Adds all existing files, configures the project
  path, generates a project name/description, and creates a README.md with a
  function table. Prompts the user before creating any new folders. Never
  overwrites existing files.
  Use when asked: "create a project", "set up a MATLAB project", "initialize
  project", "make this a MATLAB project", "configure project".
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Project Creation

Creates a fully configured MATLAB project from an existing folder of MATLAB code using `matlab.project.*` APIs via the MATLAB MCP server.

## When to Use

- User says "create a project", "set up a MATLAB project", or "initialize project"
- User has a folder of MATLAB files that needs project infrastructure
- Before `matlab-create-buildfile` — a project must exist first

## When NOT to Use

- A MATLAB project already exists (`.prj` file with `resources/project/` folder) — use `openProject` instead
- User wants to create a toolbox spec — use `matlab-define-toolbox-api`
- User wants build automation — use `matlab-create-buildfile` (after the project exists)

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlab.project.createProject` | Create a new project with specified definition type |
| `openProject` | Open an existing project (fallback if one already exists) |
| `addFile` | Add files to the project |
| `addPath` | Add folders to the project path |
| `genpath` | Generate path string for folder tree (excludes +pkg, @class, private) |

## Critical Rules

1. **NEVER overwrite existing files.** Before creating any file (README.md, etc.), check if it already exists. If it does, skip or ask the user.
2. **ALWAYS prompt the user before creating new folders.** Present recommended folders in a table with their purpose and wait for confirmation before `mkdir`.
3. **Do NOT move or rename any existing files.**

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| Project path | Yes | Absolute path to the folder to make into a project |
| Project name | No | Override auto-detected name (default: inferred from code) |

## Workflow

### 1. Discover Existing Content

- List all files in the project folder (recursively)
- If a `.prj` file exists, ask the user — it could be a MATLAB project or a legacy deploytool file:
  > A) **This is a MATLAB project** — open it with `openProject` instead of creating a new one
  > B) **This is a legacy deploytool file** — proceed with creating a new MATLAB project
- Read `Contents.m` if present — it provides authoritative function descriptions and categorization
- If no `Contents.m`, read the H1 line (first `%` comment) of each `.m` file to understand purpose
- Identify file types: `.m` (functions/scripts), data (`.mat`, `.dat`, `.csv`), text (`.txt`), images (`.png`, `.jpg`), other
- Identify any existing subfolders

### 2. Determine Project Identity

Based on the code analysis:
- **Name**: Derive from `Contents.m` title line, folder name, or dominant theme of functions
- **Description**: 1–3 sentence summary covering the scope, domain, and purpose of the code

### 3. Create the MATLAB Project

Use MATLAB MCP (`mcp__matlab__evaluate_matlab_code`) to execute:

```matlab
proj = matlab.project.createProject("Folder", '<projectFolder>', ...
    "Name", "<inferred name>", ...
    "DefinitionType", "FixedPathMultiFile");
proj.Description = "<generated description>";
```

**Why FixedPathMultiFile:** Produces a `.prj` + `resources/project/` structure that is SCM-friendly (isolated XML files, no merge conflicts). This is the target format for toolbox projects.

### 4. Add All Existing Files

Add every file in the project folder to the project. Process by extension category:

```matlab
% Add .m files
mFiles = dir(fullfile(proj.RootFolder, '*.m'));
for i = 1:numel(mFiles)
    addFile(proj, fullfile(mFiles(i).folder, mFiles(i).name));
end

% Repeat for data/text/image/other file extensions found
% Also recursively add files from any existing subfolders
```

**Important:** Use `dir(..., '**', '*.<ext>')` for recursive discovery in subfolders.

### 5. Configure Project Path

Add folders to the project path based on layout:

```matlab
% Determine path root based on project layout
if isfolder(fullfile(proj.RootFolder, "toolbox"))
    % toolbox/ layout — only toolbox content goes on path
    % (project root, tests/, buildUtilities/ stay OFF the path)
    pathRoot = fullfile(proj.RootFolder, "toolbox");
else
    % Flat layout — all subfolders go on path
    pathRoot = proj.RootFolder;
end

allFolders = strsplit(genpath(pathRoot), pathsep);
for i = 1:numel(allFolders)
    if ~isempty(allFolders{i}) && ~contains(allFolders{i}, filesep + "internal")
        addPath(proj, allFolders{i});
    end
end
```

**Why this logic:** `genpath` already excludes `+pkg/`, `@class/`, `private/`, and dot-folders — but NOT `internal/` folders. The `internal/` folder uses MATLAB's scoping convention: functions inside are only visible from the parent folder, never from the global path. The filter above ensures `internal/` is never added via `addPath`. When `toolbox/` exists, only its contents should be on the MATLAB path — this matches what end users get when the toolbox is installed. If `toolbox/` doesn't exist yet (flat layout), adding root and subfolders is correct since the user's code lives at root.

If the user later adopts `toolbox/` (via Step 7), the path should be reconfigured — suggest re-running this skill or manually adjusting path entries.

### 6. Create README.md

**Only if README.md does not already exist** at the project root.

Generate a README.md containing:
- Project title (H1)
- Description paragraph
- Project organization overview
- **Function table** grouped by category (GUI demos, algorithm implementations, utilities, data files, etc.)
  - Each row: `| function_name | one-line description |`
- Getting Started section (how to open/use the project)
- License/copyright note if `license.txt` or copyright info exists

Add the README.md to the project after creation:
```matlab
addFile(proj, fullfile(proj.RootFolder, 'README.md'));
```

### 7. Suggest Best-Practice Folders

Based on [mathworks/toolboxdesign](https://github.com/mathworks/toolboxdesign) conventions, present the user with a table of recommended folders:

| Folder | Purpose |
|--------|---------|
| `tests/` | Unit tests using the MATLAB Testing Framework |
| `examples/` | Live Script examples and tutorials |
| `doc/` | Documentation (e.g., `GettingStarted.m`) |
| `toolbox/` | Distributable content separated from dev infrastructure |

**ASK the user which (if any) they want created.** Do not create them without confirmation. Present as lettered options:
> A) **All** — create all recommended folders
> B) **Select** — pick specific folders (e.g., "tests and examples")
> C) **Skip** — don't create any new folders

When confirmed, create the folders and add them to the project path:
```matlab
mkdir(fullfile(proj.RootFolder, '<folderName>'));
addPath(proj, fullfile(proj.RootFolder, '<folderName>'));
```

### 8. Final Verification

Run a summary check:
```matlab
proj = currentProject;
disp("Name: " + proj.Name);
disp("Files: " + numel(proj.Files));
disp("Path entries: " + numel(proj.ProjectPath));
```

Report the final state to the user.

## Error Handling

- If `matlab.project.createProject` fails because a project already exists, use `openProject` instead and inform the user
- If `addFile` fails for a specific file (e.g., it's already tracked), catch and continue
- If `addPath` fails for a folder, catch the error and report which folder was skipped

## Output

Provide the user with:
1. Confirmation that the project was created
2. Project name, description, file count, and path entries
3. Location of the `.prj` file for opening in MATLAB
4. The recommended-folders prompt (Step 7)

## Next Steps

- `/matlab-document-toolbox` — generate README, function signatures, GettingStarted guide, and examples
- `/matlab-create-buildfile` — define the build plan with code checks, tests, and packaging tasks

----

Copyright 2026 The MathWorks, Inc.

----

