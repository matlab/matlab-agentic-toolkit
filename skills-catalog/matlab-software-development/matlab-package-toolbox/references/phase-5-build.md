# Phase 5: Create Build Plan

Generate a `buildfile.m` using MATLAB's `matlab.buildtool` framework.

## Step 5.1 — Assess What Exists

Scan for:
- Source folder (priority: `toolbox/` → `+packagename/` → `source/`/`src/`)
- `tests/` — test files
- MEX source files (`.c`, `.cpp`, `.cxx`, `.F`, `.f90`)
- `toolboxPackaging.prj` — packaging configuration
- Existing `buildfile.m` — update rather than replace
- `buildUtilities/toolboxSpecification.m` — for context

## Step 5.2 — Generate `buildfile.m`

Use built-in task types where they exist:

| Task | Type | Description | Fail condition |
|------|------|-------------|----------------|
| `clean` | CleanTask | Remove derived artifacts | — |
| `check` | CodeIssuesTask | Static analysis (SARIF) | Any error; any warning (strict) |
| `mex` | MexTask | Compile MEX files (if detected) | Compilation fails |
| `test` | TestTask | Run tests + produce coverage | Any test failure |
| `coverage` | Custom | Report coverage, warn if below threshold | — (advisory) |
| `package` | Custom | Build .mltbx | Package file not produced |

**Task strategy rules:**
- **TestTask handles testing AND coverage production.** Use `.addCodeCoverage()` to produce both Cobertura XML and `.mat`.
- **Coverage reporting is a separate custom task.** Loads coverage data, logs per-file results, warns if below threshold. Does NOT fail the build.
- **Coverage task must match actual test output.** Read the test task to determine the actual coverage output path and format.
- **MexTask for MEX compilation.** Use `MexTask.forEachFile` for multiple sources. Output in toolbox/ folder.
- **Custom tasks use `context`.** Always `context.log()` for output, `context.assertTrue()` for failures. NEVER `disp()`, `fprintf()`, `warning()`, or bare `assert()`.
- **Package from PRJ.** Load `ToolboxOptions` from `toolboxPackaging.prj`. Fall back to programmatic if no PRJ exists (see `references/buildfile-variants.md`).
- **Never hardcode version in packageTask.** Read from `toolboxSpecification.m` or PRJ.
- **Output to `release/`.** Replace spaces with underscores in filename.
- **DefaultTasks = ["check" "test" "coverage"].** Packaging is explicit (`buildtool package`).
- **Omit MEX task if no MEX sources.** Don't generate dead code.
- **Include comments explaining design choices** — the buildfile is a teaching artifact.

Use `scripts/buildfile-template.m` as the base template.

## Step 5.3 — Present the Plan

Show task chain, dependencies, artifacts produced, and CI invocation patterns. Ask:
> A) **Approve** — write the buildfile
> B) **Adjust** — modify tasks, thresholds, or dependencies
> C) **Skip** — don't create a buildfile now

## Step 5.4 — Persist

**If `buildfile.m` does NOT exist:** Write to project root.

**If `buildfile.m` already exists:** Show a diff of proposed changes. Wait for explicit user approval before editing.

----

Copyright 2026 The MathWorks, Inc.

----
