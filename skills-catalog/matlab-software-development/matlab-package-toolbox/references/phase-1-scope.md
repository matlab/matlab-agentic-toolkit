# Phase 1: Define Toolbox API

Scan the folder, triage files into include/exclude, identify the public API, and produce the Interface Spec.

## Key Functions

| Function | Purpose |
|----------|---------|
| `dir` | Recursive file listing for inventory |
| `which` | Resolve function locations on path |
| `exist` | Check whether a name resolves to a file, folder, or built-in |
| `matlab.codetools.requiredFilesAndProducts` | Trace caller/callee relationships for Support classification |

## Step 1.1 — Inventory the Folder

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

## Step 1.2 — Classify Relevance

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

## Step 1.3 — Identify Public API

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

## Step 1.4 — Present Report & Get Confirmation

Display a combined scope + API report. This report defines what ends up in the `.mltbx`:
- **Public API** — functions end users will call directly
- **Internal Support** — ships in the toolbox but not user-facing (helpers called by public functions)
- **Included Assets** — ships in the .mltbx but is not callable code (docs, examples, icons, data files, XML metadata)
- **Excluded** — will NOT be in the .mltbx (tests, build infrastructure, scratch files)
- **Uncertain** — ambiguous files that need user input

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

### Included Assets (N files) — ships in .mltbx, not part of callable API
| File | Description |
|------|-------------|

### Excluded (N files) — will NOT be in the .mltbx
| File | Reason |
|------|--------|

### Uncertain — Need Your Input
| File | Why Uncertain |
|------|--------------|
```

Then ask:
> **Please review:**
> 1. Should any excluded files be included (as API, support, or assets)?
> 2. Should any included files be excluded or reclassified?
> 3. For uncertain files — which category?
> 4. Is the public API surface correct?
> 5. What categories should functions be grouped into?

Incorporate feedback before proceeding.

## Step 1.5 — Generate Interface Spec

Produce `toolboxSpecification.m` using `scripts/toolboxSpecificationTemplate.m` as the structure. `spec.entries` is a **cell array** (not a struct array) because `classdef` entries have extra fields (`methods`, `properties`) that `function` entries lack — MATLAB cannot concatenate structs with mismatched fields. Access entries via `spec.entries{i}`. Each entry has a `"type"` field — either `"function"` or `"classdef"`.

Save to `buildUtilities/toolboxSpecification.m` in the project root (create the folder if needed). This folder is excluded from the toolbox package via `toolbox.ignore` or `package.ignore`.

## Rules

- **Always prompt if inputs are missing.** Never guess the path or purpose.
- **Every file is accounted for.** Nothing is silently dropped.
- **Purpose drives classification.** The user's stated intent is the primary filter.
- **Uncertain is valid.** Surface ambiguity rather than guessing wrong.
- **Reasons are mandatory.** Every include/exclude decision has a stated reason.
- **Tests are excluded but acknowledged.** They're handled by Phase 6 later.
- **Scripts become examples.** Files without `function` keyword are examples/entry points, not public API.
- **One artifact, build utilities.** Only `toolboxSpecification.m` is written, to `buildUtilities/`.

----

Copyright 2026 The MathWorks, Inc.

----
