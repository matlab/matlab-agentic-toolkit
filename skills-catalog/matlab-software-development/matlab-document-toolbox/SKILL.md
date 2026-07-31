---
name: matlab-document-toolbox
description: |
  Generates all documentation artifacts for a MATLAB toolbox: README.md,
  functionSignatures.json, GettingStarted.m, and publishable examples with
  demos.xml help integration. Follows mathworks/toolboxdesign best practices.
  Use when asked: "document this toolbox", "create documentation", "add examples",
  "generate function signatures", "getting started guide", "README",
  "make this ready to share", "add tab completion".
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-document-toolbox — Toolbox Documentation Generator

You produce all documentation artifacts needed for a well-documented MATLAB toolbox: README, function signatures, getting started guide, and examples. You follow the [mathworks/toolboxdesign](https://github.com/mathworks/toolboxdesign) conventions throughout.

## When to Use

- After `matlab-create-project` has set up the project structure
- User says "document this toolbox" or "add documentation"
- User says "create examples" or "generate function signatures"
- User says "getting started guide" or "README"
- Before `matlab-assess-toolbox` to satisfy documentation checks (1, 2, 10, 12, 15)
- User says "make this ready to share"

## When NOT to Use

- Writing or fixing MATLAB code — this skill generates documentation only
- Building or packaging the toolbox — use `matlab-build-toolbox`
- Assessing readiness — use `matlab-assess-toolbox` (which may delegate here)
- Writing tests — tests are handled by test-generation skills, not documentation

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| Project path | Yes | Absolute path to the toolbox project root |
| Scope | No | Which artifacts to generate: `all` (default), `readme`, `signatures`, `gettingstarted`, `examples` |
| Toolbox folder | No | Path to the distributable content folder (default: auto-detected — `toolbox/`, or project root if no `toolbox/` exists) |

## Rules

- **NEVER overwrite existing files.** Before creating any file, check if it already exists. If it does, show what you'd change and ask the user.
- **Never move or rename existing files.**
- **Evidence-based only.** Only document functions that actually exist. Never fabricate function names, signatures, or descriptions.
- **Follow mathworks/toolboxdesign layout.** README at project root; `GettingStarted.m` in `toolbox/doc/` (or `doc/` if no `toolbox/` folder); examples in `toolbox/examples/` (or `examples/`); `functionSignatures.json` in `resources/` per placement rules.
- **Read-only until approved.** Present the full plan of what will be created, wait for user confirmation before writing anything.

## Workflow

### Step 1 — Discover Project Structure

Scan the project to understand what exists:

```
- Project root: README.md? license.txt? images/?
- Toolbox folder location: toolbox/ or project root?
- Existing docs: GettingStarted.m or GettingStarted.mlx? demos.xml? info.xml?
- Function signatures: resources/functionSignatures.json?
- Examples: examples/ folder? *.m or *.mlx examples?
- Source files: .m functions (public, private, internal, namespaced)
- Contents.m: authoritative function list and categories?
```

Determine the toolbox folder:
1. If `toolbox/` subfolder exists → that's the toolbox folder (design-guidelines layout)
2. Otherwise → the project root IS the toolbox folder (flat layout)

### Step 2 — Analyze Functions

For each `.m` file in the toolbox folder:
- Extract function name, signature, H1 line, input/output arguments
- Read `arguments` blocks for type constraints and validators
- Classify: public (on path), private (`private/`), internal (`internal/` or `+pkg.internal`), namespaced (`+pkg/`)
- Identify categories from `Contents.m`, folder structure, or function themes
- Note which functions are scripts vs. functions vs. classdefs

### Step 3 — Present Plan

Show the user what will be generated:

```
## Documentation Plan — [Toolbox Name]

### Artifacts to Generate

| # | Artifact | Location | Status |
|---|----------|----------|--------|
| 1 | README.md | <root>/README.md | NEW / EXISTS (skip) |
| 2 | functionSignatures.json | <toolbox>/resources/functionSignatures.json | NEW / EXISTS (merge?) |
| 3 | GettingStarted.m | <toolbox>/doc/GettingStarted.m | NEW / EXISTS (skip) / .mlx EXISTS (skip) |
| 4 | Examples (N scripts) | <toolbox>/examples/ | NEW |
| 5 | demos.xml | <toolbox>/examples/demos.xml | NEW |

### Functions Covered

| Function | Category | Example? | Signature Entry? |
|----------|----------|----------|-----------------|
| add | Arithmetic | Yes | Yes |
| multiply | Arithmetic | Yes | Yes |
| helperFormat | (internal) | No | No |

Which artifacts to generate?
> A) **All** — generate everything listed above
> B) **Select** — pick specific artifact numbers (e.g., "1, 2, 5")
> C) **Skip existing** — generate only NEW artifacts, skip those marked EXISTS
```

Wait for user confirmation before generating anything.

### Step 4 — Generate README.md

Use `references/readme-template.md` for the structure and conventions. Key points:
- README at project root, NOT inside `toolbox/`
- User-focused summary above the fold
- Function table from Contents.m or H1 lines
- Point to `GettingStarted.m`

### Step 5 — Generate functionSignatures.json

See `references/function-signatures-rules.md` for placement rules, type mapping, extraction from `arguments` blocks, and validation.

Key points:
- Always include `"_schemaVersion": "1.0.0"` at the top level
- Placement depends on namespacing (regular vs. `+pkg` vs. `@class`)
- Validate with `validateFunctionSignaturesJSON` via MATLAB MCP
- Accuracy over completeness — omit `type` rather than guess

### Step 6 — Generate GettingStarted.m

**Location:** `toolbox/doc/GettingStarted.m` (MATLAB auto-presents this on toolbox install via `ToolboxGettingStartedGuide`)

If a `GettingStarted.mlx` already exists, skip this step — the existing `.mlx` is valid and should not be replaced.

If the project has no `toolbox/` folder, use `doc/GettingStarted.m` at the project root level.

Use `scripts/getting-started-template.m` as the starting structure. Key rules:
- Must run without user interaction
- Keep computations fast (< 5 seconds total)
- Show the most impactful 3-5 functions, not all functions
- Include at least one visualization if the toolbox produces visual output
- Use `%%` section breaks (renders as rich document in the Live Editor)
- Name it exactly `GettingStarted.m` (case-sensitive — MATLAB looks for this name)

### Step 7 — Generate Examples

See `references/examples-conventions.md` for naming, structure, conversion, and rules.

### Step 8 — Generate demos.xml

Use `references/demos-xml-template.xml` for the structure. Key rules:
- `<source>` is the filename WITHOUT the `.m`/`.mlx` extension
- Group examples into logical `<demosection>` categories
- Use descriptive `<label>` text (include the function name in parentheses)
- Order sections: Getting Started first, then fundamental → advanced
- Include the GettingStarted guide as the first demo item

### Step 9 — Add to MATLAB Project

If a MATLAB project exists, add all generated files:

```matlab
proj = openProject(projectRoot);
% Add new files and doc/examples folders to the project path
```

### Step 10 — Report Results

```
## Documentation Complete — [Toolbox Name]

### Generated Artifacts

| Artifact | Location | Functions Covered |
|----------|----------|-------------------|
| README.md | <root>/README.md | All (summary table) |
| functionSignatures.json | toolbox/resources/functionSignatures.json | N public functions |
| GettingStarted.m | toolbox/doc/GettingStarted.m | Top 5 functions |
| Examples (M files) | toolbox/examples/*.m | N functions |
| demos.xml | toolbox/examples/demos.xml | All examples |

### Validation
- functionSignatures.json: VALID (N functions, 0 errors)
- GettingStarted.m: Runs without error
- Examples: M/M run successfully

### Packaging Integration
- ToolboxGettingStartedGuide → toolbox/doc/GettingStarted.m
- All artifacts inside toolbox/ folder → will ship in .mltbx
- README.md at project root → will NOT ship (developer-facing)

### Next Steps
- Review generated examples for accuracy
- Run `matlab-assess-toolbox` to check remaining gaps
- Customize GettingStarted.m with domain-specific narrative
```

## Checkpoint

**Yes** — presents the full plan (Step 3) before generating anything. User can select which artifacts to generate, skip existing ones, or customize the scope.

## Key Rules

- **README at root, not in toolbox/.** The README is for GitHub/developers. End users get `GettingStarted.m` inside the toolbox.
- **GettingStarted.m in `toolbox/doc/`.** This exact path is what `ToolboxGettingStartedGuide` points to. MATLAB auto-presents it on install.
- **Examples in `toolbox/examples/`.** They ship inside the .mltbx and appear in the Help Browser via `demos.xml`.
- **functionSignatures.json in `resources/`.** Follows MATLAB's resource folder convention. Placement rules differ for namespaces — the JSON goes in the parent of `+pkg/`.
- **Plain-text `.m` for user-facing docs.** Write as plain-text `.m` with `%%` section breaks — these render as rich documents in the Live Editor and are version-control friendly.
- **Everything must run.** GettingStarted and all examples must execute without error or user interaction.
- **Don't fabricate.** Only document functions that exist. Only generate signatures for arguments you can verify from the source.
- **Accuracy over completeness.** An incomplete but correct `functionSignatures.json` is better than a complete but wrong one. Omit `type` rather than guess.
- **Single pass.** Generate all documentation in one workflow. Don't require the user to invoke separate skills for each artifact.
- **Respect existing work.** If README, signatures, or examples already exist, show what you'd add/change and ask first.

## Next Steps

- `/matlab-create-buildfile` — define the build plan with code checks, tests, and packaging tasks
- `/matlab-assess-toolbox` — validate readiness across all checks before building

----

Copyright 2026 The MathWorks, Inc.

----

