---
name: matlab-exclude-files
description: "Analyze a toolbox folder and generate a toolbox.ignore file — detects files that should not ship to end users based on what actually exists in the folder. Only suggests patterns for files found. Advisory: presents suggestions with reasons before writing."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-exclude-files — Ignore File Generator

You analyze a MATLAB toolbox folder and suggest which files should be excluded from packaging. You only suggest patterns for files that actually exist — no generic templates or boilerplate.

## When to Use

- User asks to create an ignore file or exclude files from packaging
- User says "what shouldn't ship?" or "clean up my packaging"
- Before `matlab-build-toolbox` when no ignore file exists
- After `matlab-assess-toolbox` flags packaging concerns (check 16)

## When NOT to Use

- User wants to exclude files from the MATLAB project (not the package) — use project settings
- User wants to define the toolbox scope or public API — use `matlab-define-toolbox-api`
- A `toolbox.ignore` already fully covers the project — this skill reports "no additional exclusions"

## Inputs

- **toolbox_folder**: Path to the toolbox content folder (default: `toolbox/` or current directory)

## Rules

- **Read-only until approved**: Never write files without explicit user consent.
- **Evidence-based only**: Only suggest patterns for files that actually exist in the scan. NEVER mention or include a pattern if the matching file/folder is not present — not even as "commonly excluded" or "you might also want." If nothing to exclude is found, say so and stop.
- **No duplicates**: If `toolbox.ignore` or `package.ignore` already exists, only suggest additions not already covered.
- **Respect MATLAB defaults**: NEVER suggest patterns that MATLAB already auto-excludes: `.git/`, `.svn/`, `.buildtool/`, `*.asv`, `resources/project/`, `*.prj`. These must not appear in your suggestions or in the generated ignore file.
- **Cite evidence**: For each suggestion, name the specific file(s) found.

## Detectable Patterns

Only suggest these if the matching files are found in the scan:

| Pattern | Why exclude | Impact |
|---------|------------|--------|
| `*.DS_Store` | OS metadata, not useful to users | HIGH |
| `Thumbs.db` | Windows thumbnail cache | HIGH |
| `.vscode/` | VS Code settings | HIGH |
| `.idea/` | JetBrains IDE settings | HIGH |
| `*.log` | Log files from dev/test runs | HIGH |
| `*.orig` | Merge conflict leftovers | HIGH |
| `slprj/` | Simulink project cache | HIGH |
| `codegen/` | MATLAB Coder generated output | HIGH |
| `*.mltbx` | Previously built packages | HIGH |
| `tmp/`, `temp/` | Scratch directories | HIGH |
| `tests/`, `test/` | Test files (if inside toolbox folder) | MEDIUM |
| `buildUtilities/` | Build scripts | MEDIUM |
| `buildfile.m` | Build automation (if inside toolbox folder) | MEDIUM |
| `*.cpp`, `*.c`, `*.h` | MEX source (when compiled `.mex*` binaries exist) | MEDIUM |
| `doc/internal/` | Internal documentation not for end users | MEDIUM |
| `CHANGELOG.md`, `CONTRIBUTING.md` | Developer-facing docs | MEDIUM |
| `*.mat` in test directories | Test fixtures | MEDIUM |
| `.m` files with matching `.p` | Source alongside pcode — excluding protects IP but removes `help` access unless pcode was generated with help preservation | MEDIUM |

## Workflow

### Step 1 — Scan

Glob the toolbox folder recursively. Collect all file paths and folder names.

### Step 2 — Check Existing

Look for `toolbox.ignore` or `package.ignore` in the folder. If one exists, read it and note which patterns are already covered.

### Step 3 — Detect

For each file found in the scan, check if it matches a known ignorable pattern from the table above. Only report matches for files that actually exist. For pcode pairs, check if a `.p` file has a corresponding `.m` file with the same name in the same directory.

Exclude from results:
- Patterns already covered by an existing ignore file
- Patterns already auto-excluded by MATLAB (`.git/`, `.svn/`, `.buildtool/`, `*.asv`, `resources/project/`, `*.prj`)

### Step 4 — Present

Only show new suggestions — files that exist, are not already excluded, and should be. Do not list what's already handled or what wasn't found. Do not show internal reasoning, verification notes, or commentary about the detection process. Group suggestions under named category headings:

```
## Ignore Suggestions — [Toolbox Name]

### OS / IDE Metadata
| # | Pattern | Found | Reason |
|---|---------|-------|--------|
| 1 | *.DS_Store | 3 files | OS metadata not useful to end users |
| 2 | .vscode/ | 1 folder | IDE settings |

### Test Infrastructure
| # | Pattern | Found | Reason |
|---|---------|-------|--------|
| 3 | tests/ | 12 files | Test files inside toolbox folder |

### Source Protection
| # | Pattern | Found | Reason |
|---|---------|-------|--------|
| 4 | myFunc.m | paired with myFunc.p | Source alongside pcode — excluding protects IP but removes help text access |
```

If no new suggestions are found, simply state: "No additional exclusions to recommend."

For pcode suggestions, include this note:
> Excluding `.m` files that have matching `.p` files protects source code from distribution. However, `help functionName` will not work for end users unless the pcode was generated with help preservation (`pcode -inplace` from an .m containing the help block).

### Step 5 — Ask

Prompt: which suggestions to include?
> A) **All** — include everything suggested
> B) **All HIGH** — only HIGH-impact items
> C) **Select** — pick specific numbers (e.g., "1, 2, 4")
> D) **Skip** — do not create/modify the ignore file

### Step 6 — Write

Create or append to `toolbox.ignore` with selected patterns, grouped by category using MATLAB-style comments (`%`).

**Note:** In MATLAB R2025a+, `toolbox.ignore` triggers a deprecation warning. If the user prefers, offer to name the file `package.ignore` instead.

Example output:

```
% toolbox.ignore
% Files excluded from toolbox packaging

% OS metadata
*.DS_Store

% IDE settings
.vscode/

% Test files (not distributed to end users)
tests/

% Source excluded (distributed as pcode)
myFunc.m
```

## Checkpoint

**Yes** — always present suggestions and wait for user selection before writing anything.

## Key Rules

- Never suggest ignoring files that don't exist in the toolbox folder
- Never suggest patterns already handled by MATLAB's default exclusions
- If an existing ignore file covers a pattern, skip it
- Pcode trade-off explanation is always shown when .p/.m pairs are found
- The generated file uses `%` for comments (MATLAB convention)
- Running again on a folder with an existing ignore file only suggests additions

----

Copyright 2026 The MathWorks, Inc.

----

