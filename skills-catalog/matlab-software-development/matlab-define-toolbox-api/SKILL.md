---
name: matlab-define-toolbox-api
description: "Scan a folder, triage files into include/exclude, identify the public API, and produce a toolboxSpecification.m Interface Spec — all in one pass. Use when turning loose code into a toolbox."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-define-toolbox-api — Toolbox Scope & Spec Generator

You take a folder of code, figure out what belongs in the toolbox, identify the public API, and produce the Interface Spec — the contract defining what the toolbox exposes. One skill, one artifact.

## When to Use

- User wants to turn code into a toolbox
- User points at a folder and says "make this a toolbox" or "package this"
- User has a mix of scripts, functions, tests, data, and scratch files
- Starting the files-to-package pipeline from scratch

## When NOT to Use

- Adding files to an existing spec — edit `buildUtilities/toolboxSpecification.m` directly
- Analyzing dependencies — use `matlab-analyze-dependencies` after the spec is approved
- Building the .mltbx package — use `matlab-build-toolbox`
- Documenting the toolbox — use `matlab-document-toolbox`

## Key Functions

| Function | Purpose |
|----------|---------|
| `dir` | Recursive file listing for inventory |
| `which` | Resolve function locations on path |
| `exist` | Check whether a name resolves to a file, folder, or built-in |
| `matlab.codetools.requiredFilesAndProducts` | Trace caller/callee relationships for Support classification |

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| **path** | No | Folder or list of files to analyze. If not provided, prompt the user. |
| **purpose** | No | What the toolbox does and who uses it. If not provided, prompt the user. |

## Workflow

### Step 1 — Gather Inputs

If **path** is not provided:
> What folder or files would you like to package as a toolbox?

If **purpose** is not provided:
> In a sentence or two, what does this toolbox do? Who will use it?

Do not proceed until both are provided.

### Step 2 — Inventory the Folder

Scan the path recursively. Classify every file:

| Category | Detection Rule |
|----------|---------------|
| **Function** | `.m` file with `function` keyword on first non-comment line |
| **Class** | `.m` file with `classdef` keyword |
| **Script** | `.m` file with no `function`/`classdef` keyword |
| **Live Script** | `.mlx` file |
| **Test** | In `tests/`/`test/` folder, or name matches `*Test.m`, `*_test.m`, `test_*.m` |
| **Data** | `.mat`, `.csv`, `.xlsx`, `.json`, `.xml` (non-config) |
| **Config/Meta** | `buildfile.m`, `projectStartup.m`, `Contents.m`, `.prj`, `resources/` |
| **Scratch/Temp** | In `scratch/`, `tmp/`, or names like `untitled*.m`, `Copy_of_*` |
| **Other** | READMEs, images, licenses, etc. |

### Step 3 — Classify Relevance

Using the **purpose** as guide, classify each file:

- **Include** — directly serves the toolbox's stated purpose
- **Support** — needed by included files (helper/utility called internally)
- **Exclude** — not relevant (tests, scratch, unrelated code)
- **Uncertain** — needs user input

Heuristics:

| Signal | Disposition |
|--------|-------------|
| Function name aligns with purpose keywords | Include |
| H1 text mentions concepts from purpose | Include |
| Called by an included file | Support |
| In `private/` or `+internal` folder | Support |
| Test file for an included function | Exclude |
| Script with no connection to purpose | Exclude |
| Data file referenced by included code | Include |
| Scratch/temp naming pattern | Exclude |

### Step 4 — Identify Public API

From the **Include** set, determine visibility:

| Signal | Classification |
|--------|---------------|
| Has H1 help text | Likely public |
| Has `arguments` block or input validation | Likely public |
| Descriptive action-oriented name | Likely public |
| Classdef with public methods | Public |
| Called by others but not standalone | Internal |
| In `private/` or generic utility name | Internal |
| Script | Example/entry point |

### Step 5 — Present Report & Get Confirmation

Display a combined scope + API report:

```
## Toolbox Scope & API — [Name]

**Purpose:** [user's stated purpose]
**Source:** [path]
**Total files:** N

### Public API (N functions)
| Function | Signature | H1 | Category |
|----------|-----------|-----|----------|

### Internal Support (N files)
| File | Type | Reason |
|------|------|--------|

### Excluded (N files)
| File | Reason |
|------|--------|

### Uncertain — Need Your Input
| File | Why Uncertain |
|------|--------------|
```

Then ask:
> **Please review:**
> 1. Should any excluded files be included?
> 2. Should any included files be removed?
> 3. For uncertain files — include or exclude?
> 4. Is the public API surface correct?
> 5. What categories should functions be grouped into? (e.g., "Analysis", "I/O", "Visualization")

Incorporate feedback before proceeding.

### Step 6 — Generate Interface Spec

Produce `toolboxSpecification.m` using `scripts/toolboxSpecificationTemplate.m` as the structure. `spec.entries` is a **cell array** (not a struct array) because `classdef` entries have extra fields (`methods`, `properties`) that `function` entries lack — MATLAB cannot concatenate structs with mismatched fields. Access entries via `spec.entries{i}`. Each entry has a `"type"` field — either `"function"` or `"classdef"`. See the template for the full field conventions for both types.

Save to `buildUtilities/toolboxSpecification.m` in the project root (create the folder if needed). This folder is excluded from the toolbox package via `toolbox.ignore` or `package.ignore`.

## Output

- **Single artifact**: `buildUtilities/toolboxSpecification.m` — executable spec as a MATLAB struct
- **Display**: Markdown report shown during the session for review
- **Downstream**: Other skills (`matlab-assess-toolbox`, `matlab-build-toolbox`, `matlab-analyze-dependencies`) consume `toolboxSpecification.m`

## Checkpoint

**This skill always pauses for user approval at Step 5.** The user must confirm scope and public API before the spec is generated. Nothing is written until confirmation.

## Key Rules

- **Always prompt if inputs are missing.** Never guess the path or purpose.
- **Every file is accounted for.** Nothing is silently dropped — files are included, excluded (with reason), or flagged as uncertain.
- **Purpose drives classification.** The user's stated intent is the primary filter.
- **Uncertain is valid.** Surface ambiguity rather than guessing wrong.
- **Reasons are mandatory.** Every include/exclude decision has a stated reason.
- **Tests are excluded but acknowledged.** They're handled by `matlab-assess-toolbox` later.
- **Scripts become examples.** Files without `function` keyword are examples/entry points, not public API.
- **User decides visibility.** Heuristics suggest, user confirms.
- **One artifact, build utilities.** Only `toolboxSpecification.m` is written, to `buildUtilities/` — keeps source clean and is excluded from the packaged toolbox.

## Next Steps

- `/matlab-analyze-dependencies` — resolve external dependencies identified in the Interface Spec
- `/matlab-create-project` — organize files into a MATLAB project using the spec as a guide

----

Copyright 2026 The MathWorks, Inc.

----
