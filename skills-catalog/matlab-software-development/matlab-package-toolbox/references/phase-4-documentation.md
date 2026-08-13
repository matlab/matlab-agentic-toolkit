# Phase 4: Generate Documentation

Produce all documentation artifacts: README, function signatures, getting started guide, examples, and demos.xml. Follows [mathworks/toolboxdesign](https://github.com/mathworks/toolboxdesign) conventions.

**Skip if:** User explicitly declines documentation when asked.

## Rules

- **NEVER overwrite existing files.** Show what you'd change and ask.
- **Evidence-based only.** Only document functions that actually exist.
- **Read-only until approved.** Present the full plan, wait for confirmation.
- **Flag misplaced docs.** If a documentation artifact (README, GettingStarted) exists but outside the toolbox folder, flag it and ask the user: move it into the toolbox folder, or generate a new one there. `Readme` and `ToolboxGettingStartedGuide` must be under `ToolboxFolder` and in `ToolboxFiles` — otherwise `packageToolbox` either fails or installs to a wrong path.

## Step 4.1 — Discover Project Structure

Determine the toolbox folder:
1. If `toolbox/` subfolder exists → that's the toolbox folder
2. Otherwise → the project root IS the toolbox folder

## Step 4.2 — Analyze Functions

For each `.m` file in the toolbox folder:
- Extract function name, signature, H1 line, input/output arguments
- Read `arguments` blocks for type constraints
- Classify: public, private, internal, namespaced
- Identify categories

## Step 4.3 — Present Plan

```
## Documentation Plan — [Toolbox Name]

| # | Artifact | Location | Status |
|---|----------|----------|--------|
| 1 | README.md | <root>/README.md | NEW / EXISTS (skip) |
| 2 | functionSignatures.json | <toolbox>/resources/functionSignatures.json | NEW / EXISTS |
| 3 | GettingStarted.m | <toolbox>/doc/GettingStarted.m | NEW / EXISTS (skip) |
| 4 | Examples (N scripts) | <toolbox>/examples/ | NEW |
| 5 | demos.xml | <toolbox>/examples/demos.xml | NEW |

Which artifacts to generate?
> A) **All** — generate everything listed
> B) **Select** — pick specific numbers
> C) **Skip existing** — generate only NEW artifacts
```

## Step 4.4 — Generate Artifacts

- **README.md** at project root (NOT in toolbox/) — developer/GitHub-facing. See `references/readme-template.md`.
- **functionSignatures.json** — see `references/function-signatures-rules.md` for placement and extraction rules. Always include `"_schemaVersion": "1.0.0"`. Validate with `validateFunctionSignaturesJSON`.
- **GettingStarted.m** in `toolbox/doc/` — MATLAB auto-presents on install. Must run < 5s without interaction. Use `scripts/getting-started-template.m`.
- **Examples** in `toolbox/examples/` as plain-text `.m` with `%%` section breaks. See `references/examples-conventions.md`.
- **demos.xml** in `toolbox/examples/` — integrates with Help Browser. See `references/demos-xml-template.xml`.

## Key Rules

- README at root, not in toolbox/
- GettingStarted.m in `toolbox/doc/` (exact path for `ToolboxGettingStartedGuide`)
- functionSignatures.json in `resources/` (placement differs for namespaces — goes in parent of `+pkg/`)
- Everything must run without error or user interaction
- Accuracy over completeness for signatures

----

Copyright 2026 The MathWorks, Inc.

----
