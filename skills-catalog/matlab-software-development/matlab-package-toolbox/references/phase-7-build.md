# Phase 7: Build Toolbox

Execute the build pipeline. Mechanical execution — introspect the plan, run it, report results, stop on failure.

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlab.buildtool.Plan.load` | Introspect the build plan |
| `buildtool` | Execute the pipeline |
| `dir` | Locate and verify `.mltbx` artifact |

## Step 7.1 — Verify Preconditions

1. Confirm `buildfile.m` exists
2. Check pipeline context (`toolboxSpecification.m` and `tbxManifest.m` present = full pipeline)
3. Confirm no blockers from Phase 6

## Step 7.2 — Introspect the Build Plan

```matlab
plan = matlab.buildtool.Plan.load("buildfile.m");
disp({plan.Tasks.Name})
```

Identify the **target task** (priority: user input → `package` task → terminal task producing `.mltbx`).

Report what will execute:
```
Build target: "package"
Dependency chain: check → test → package
```

## Step 7.3 — Execute

```matlab
buildtool <target>
```

| Task Type | On Failure |
|-----------|------------|
| CodeIssuesTask / "check" | Report findings, stop |
| TestTask / "test" | Report failures, stop |
| Coverage | Log warning (does not stop) |
| MexTask | Report error, stop |
| Packaging | Report error, stop |

## Step 7.4 — Verify Artifact

```matlab
mltbxFile = dir(fullfile("release", "*.mltbx"));
assert(~isempty(mltbxFile), "No .mltbx file found in release/");
assert(mltbxFile(1).bytes > 0, "Package file is empty");
fprintf("Package: %s (%.1f KB)\n", fullfile(mltbxFile(1).folder, mltbxFile(1).name), mltbxFile(1).bytes / 1024);
```

## Step 7.5 — Report Results

On success: report package path, size, per-stage results (analysis findings, test counts, coverage %, duration).

On failure — diagnose by category:
- **Test failure**: Show which tests failed and why. Offer to fix and retry.
- **Packaging failure**: Check for missing files, path issues, ignore-file conflicts.
- **Code analysis failure**: Show warnings and offer to fix.

Maximum 3 retries before stopping.

## Rules

- **Introspect first.** Never assume the task name or chain — discover it.
- **Stop on first failure.** Never continue past a failing stage.
- **Report everything.** Counts, percentages, durations.
- **Verify the artifact.** Check exists and non-zero size.
- **No decisions.** Execute the plan. Do not modify code, skip tests, or lower thresholds.

----

Copyright 2026 The MathWorks, Inc.

----
