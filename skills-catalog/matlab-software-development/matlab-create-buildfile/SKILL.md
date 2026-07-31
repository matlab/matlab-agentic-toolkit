---
name: matlab-create-buildfile
description: "Generate a MATLAB buildfile.m with tasks for static analysis, testing, coverage reporting, and packaging. Use after matlab-create-project when the project structure is in place and you need repeatable build automation."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-create-buildfile — Build Plan Generator

You generate a `buildfile.m` that defines the repeatable build/test/package pipeline using MATLAB's `matlab.buildtool` framework.

## When to Use

- After `matlab-create-project` has set up the project structure
- User says "set up the build" or "create a buildfile"
- Project has code and tests but no build automation

## When NOT to Use

- A `buildfile.m` already exists and works — use `matlab-build-toolbox` to execute it
- User wants to run the build, not create it — use `matlab-build-toolbox`
- No MATLAB project exists yet — use `matlab-create-project` first

## Inputs

- **project_root**: Path to the project (default: current directory)
- **coverage_threshold** (optional): Line-coverage percentage to warn below (default: 80)
- **warning_threshold** (optional): Max warnings before check fails (default: 0 = strict)

## Workflow

### Step 1 — Assess What Exists

Scan the project for:
- Source folder — one of (in priority order):
  1. `toolbox/` — the standard toolbox-design-guidelines layout (everything that ships)
  2. `+packagename/` — namespace-package layout (from matlab-create-project)
  3. `source/` or `src/` — generic source folder
- `tests/` — test files to run
- MEX source files — C/C++/Fortran files (`.c`, `.cpp`, `.cxx`, `.F`, `.f90`) in folders like `mex/`, `src/mex/`, `c_src/`, or at the project root. Presence indicates the project needs a `MexTask`.
- `toolboxPackaging.prj` — packaging configuration (produced by Toolbox Packaging Tool)
- Existing `buildfile.m` — update rather than replace
- `buildUtilities/toolboxSpecification.m` — interface spec (for context on what the toolbox exposes)

Record the detected structure — the generated buildfile must reference actual paths.

### Step 2 — Generate `buildfile.m`

Use built-in task types (`CodeIssuesTask`, `CleanTask`, `TestTask`, `MexTask`) where they exist, and custom function-based tasks only where built-in tasks lack needed behavior (coverage reporting, packaging).

**Task strategy:**
- **`clean`** — built-in `CleanTask`
- **`check`** — built-in `CodeIssuesTask` (SARIF output, threshold enforcement)
- **`mex`** — built-in `MexTask` (only if MEX source files detected in Step 1). Use `MexTask.forEachFile` when multiple MEX sources exist. Output folder is `toolbox/` (or source folder) so MEX files ship with the toolbox.
- **`test`** — built-in `TestTask` with `.addCodeCoverage()`. Produces JUnit XML test results AND a `.mat` coverage file for programmatic inspection by the coverage task. The built-in task supports incremental builds — it skips when source/tests are unchanged.
- **`coverage`** — custom function-based task that loads the `.mat` coverage results from the test task, logs per-file coverage, and warns if below the threshold. It does NOT fail the build — coverage is advisory, not a gate.
- **`package`** — custom function-based task (no built-in equivalent for toolbox packaging).

**Include comments in the generated buildfile** that explain design choices — particularly why a task is custom vs. built-in, what tradeoffs that creates, and how the user could switch approaches.

Use `scripts/buildfile-template.m` as the base template. Apply these adaptation rules:
- Replace `"toolbox"` with the actual source folder detected in Step 1
- Replace `"tests"` if tests live elsewhere
- Replace `0.80` with the user's coverage threshold (as a decimal)
- Replace `0` in `WarningThreshold` with the user's warning threshold
- If MEX source files were detected, add a `MexTask` with appropriate source paths and output folder. Set `plan("test").Dependencies` to include `"mex"` so tests run after MEX compilation.
- If no MEX source files exist, omit the `mex` task entirely (don't generate dead code).
- If no `toolboxPackaging.prj` exists, use the programmatic variant from `references/buildfile-variants.md`
- Set `plan("package").Outputs` to match the actual output path

### Step 3 — Present the Plan

```
## Build Plan — [Toolbox Name]

| Task | Type | Description | Dependencies | Fail condition |
|------|------|-------------|--------------|----------------|
| clean | CleanTask | Remove derived artifacts | — | — |
| check | CodeIssuesTask | Static analysis (SARIF output) | — | Any error; any warning (strict) |
| mex | MexTask | Compile MEX files (if detected) | — | MEX compilation fails |
| test | TestTask | Run tests + produce coverage | check, mex (if present) | Any test failure |
| coverage | Custom | Report coverage, warn if below threshold | test | — (advisory only) |
| package | Custom | Build .mltbx from toolboxPackaging.prj | coverage | Package file not produced |

Default: `buildtool` → runs check + test + coverage
Full pipeline: `buildtool package` → check → [mex] → test → coverage → package
List tasks: `buildtool -tasks`
CI invocation: `matlab -batch "buildtool check test coverage package"`

### Artifacts Produced

| File | Format | Consumer |
|------|--------|----------|
| results/code-issues.sarif | SARIF v2.1.0 | GitHub Code Scanning, VS Code |
| results/test-results.xml | JUnit XML | CI test reporting |
| results/coverage.xml | Cobertura XML | CI coverage tools |
| results/coverage.mat | MAT-file | Coverage report task (programmatic) |
| release/My_Toolbox.mltbx | Toolbox installer | End users |

How would you like to proceed?
> A) **Approve** — write the buildfile as shown
> B) **Adjust** — modify tasks, thresholds, or dependencies
> C) **Skip** — don't create a buildfile now
```

### Step 4 — Persist

**If `buildfile.m` does NOT exist:** Write it to the project root. Add `results/` and `release/` to `.gitignore` if it exists.

**If `buildfile.m` already exists:** Do NOT edit it directly. Instead:
1. **Read the existing test task** to determine where coverage data is produced (path and format). The existing test task may write Cobertura XML, `.mat`, or both — and may use a different output directory (e.g., `reports/` vs. `results/`). The coverage report task MUST reference the actual output path and format produced by the test task.
2. Show a diff or code block of the proposed additions/modifications (new tasks, updated dependencies, new local functions).
3. Explain what each change does and why.
4. **Wait for explicit user approval** ("yes", "go ahead", "looks good") before applying any edits.
5. Only after the user confirms, apply the changes to the existing `buildfile.m`.

This approval gate prevents surprising edits to working build automation that the user may have customized.

## Output

- `buildfile.m` — the complete build plan

## Checkpoint

**Yes** — user reviews the task chain before it's written. They can adjust order, thresholds, and which tasks are included.

## Key Rules

- **Comment design decisions in the generated code.** Every task should have a comment explaining whether it's built-in or custom and WHY. For custom tasks, explain what the built-in alternative lacks and what tradeoff the custom approach introduces. Include a commented-out snippet showing how to switch to the simpler alternative. The buildfile is a teaching artifact — the user must be able to understand and maintain it without re-running this skill.
- **Use built-in tasks where they exist.** `CodeIssuesTask`, `CleanTask`, `TestTask`, and `MexTask` are battle-tested — don't reimplement them as function tasks.
- **TestTask handles testing AND coverage production.** Use the built-in `TestTask` with `.addCodeCoverage()` to produce both Cobertura XML (for CI) and `.mat` (for programmatic threshold checking). This gives incremental build support — the task skips when source/tests are unchanged.
- **Coverage reporting is a separate custom task.** The `coverageTask` loads coverage data, logs per-file results, and warns if below threshold — but does NOT fail the build. Coverage is advisory. To make it a hard gate, the user can replace the warning `context.log` with `context.assertTrue`.
- **Coverage task must match actual test output.** When adding a coverage task to an existing buildfile, read the test task (or its helper) to determine the actual coverage output path and format. If the test task produces Cobertura XML (e.g., `reports/codecoverage.xml`), parse the `line-rate` attribute from the XML root. If it produces `.mat` (from `TestTask.addCodeCoverage`), use `coverageSummary`. Never hardcode `results/coverage.mat` without verifying that the test task actually writes it.
- **MexTask for MEX compilation.** When MEX source files are detected, use the built-in `MexTask` (or `MexTask.forEachFile` for multiple sources). Place output in the source/toolbox folder so compiled MEX files ship with the toolbox. Tests must depend on the mex task.
- **Custom tasks use `context`.** Always accept the `context` argument and use `context.log()` for output, `context.assertTrue()` for failure conditions. NEVER use `disp()`, `fprintf()`, or `warning()` for status output in task functions — always `context.log()`. NEVER use bare `assert()` for failures — always `context.assertTrue()`.
- **Single test run.** The built-in `TestTask` with `.addCodeCoverage()` instruments coverage in the same run that checks pass/fail — never run tests twice.
- **Package from PRJ.** Load `ToolboxOptions` from `toolboxPackaging.prj` — this is the single source of truth for toolbox identity, files, and metadata. Only fall back to programmatic construction if no PRJ exists.
- **Never hardcode the version in packageTask.** The version must be read from `buildUtilities/toolboxSpecification.m` (if it exists) or from the PRJ file — never written as a literal string in `buildfile.m`. Hardcoded versions create drift: `matlab-publish-toolbox` updates `toolboxSpecification.m` before packaging, but a hardcoded `opts.ToolboxVersion = "1.0.0"` silently overrides it. The spec is the single source of truth for version.
- **Output to `release/`.** The `.mltbx` goes in `release/` (not source-controlled). Replace spaces with underscores in the filename for cross-platform compatibility.
- **Produce CI artifacts.** Always emit SARIF (code issues), JUnit XML (test results), Cobertura XML (coverage), and `.mat` (for coverage reporting) — these are the standard formats consumed by GitHub Actions, Azure DevOps, Jenkins, and the coverage task.
- **Declare outputs on package task.** Setting `.Outputs` lets `CleanTask` know what to delete and enables incremental build support.
- **`DefaultTasks = ["check" "test" "coverage"]`.** Running bare `buildtool` should validate code quality including coverage. Packaging is an explicit action (`buildtool package`).
- **Update, don't replace.** If `buildfile.m` already exists, add missing tasks rather than overwriting existing customization. Always propose changes as a plan and wait for user approval before editing.
- **Detect structure, don't assume.** The source folder varies (`toolbox/`, `+pkg/`, `source/`). Always verify what exists before generating.
- **Omit MEX task if no MEX sources.** Don't generate a mex task with placeholder paths — only include it when C/C++/Fortran source files are actually detected.

## Next Steps

- `/matlab-assess-toolbox` — validate readiness across all checks before building
- `/matlab-build-toolbox` — execute the build plan and produce the `.mltbx` artifact

----

Copyright 2026 The MathWorks, Inc.

----

