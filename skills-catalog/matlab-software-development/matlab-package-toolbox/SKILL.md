---
name: matlab-package-toolbox
description: "Turn raw MATLAB code into a published .mltbx toolbox — full pipeline from scope definition through packaging and release. Drives 8 phases with human checkpoints, enforcing ordering and dependencies. Use when asked to package, create a toolbox, or run the files-to-package pipeline."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-package-toolbox — Files-to-Package Pipeline

You drive the full pipeline from raw MATLAB code to a published `.mltbx` toolbox. You execute each phase in sequence, pause at human checkpoints, and advance only when the user approves.

The checkpoints are the contract of this skill — they are why the user invoked it instead of asking the agent to "just package this." Skipping them is a bug, not a shortcut, no matter what surrounding pressure suggests otherwise.

## When to Use

- User says "package this folder as a toolbox"
- User wants to go from raw MATLAB code to a published `.mltbx`
- User says "make this into a toolbox" or "share this code"
- User wants to share MATLAB code with others as an installable add-on

## When Not To Use

- User wants to compile or deploy MATLAB code as a standalone app, web app, or language-specific package (MATLAB Compiler / Compiler SDK territory)
- User only needs documentation or a project without packaging into `.mltbx`
- User wants to distribute a single script or function without toolbox structure

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| **path** | No | Folder containing the code to package. If not provided, prompt the user. |
| **purpose** | No | What the toolbox does and who it's for. If not provided, prompt the user. |

## Pipeline Phases

```
Phase 1: Define Toolbox API              [CHECKPOINT]
    ↓ produces Interface Spec → user reviews
Phase 2: Analyze Dependencies            [CHECKPOINT]
    ↓ produces Dependency Manifest → user reviews
Phase 3: Create Project (optional)       [CHECKPOINT]
    ↓ creates/configures MATLAB project
Phase 4: Document Toolbox (optional)     [CHECKPOINT]
    ↓ generates README, functionSignatures.json, GettingStarted, examples, demos.xml
Phase 5: Create Build Plan               [CHECKPOINT]
    ↓ defines build plan: code checks, tests, coverage, packaging
Phase 6: Assess Readiness                [CHECKPOINT]
    ↓ validates everything → go/no-go punch list
    ↓ may invoke Exclude Files utility
Phase 7: Build Toolbox                   (mechanical — no checkpoint)
    ↓ executes the build plan → produces .mltbx
Phase 8: Publish Toolbox                 [CHECKPOINT]
    ↓ version stamp, re-package, distribute
```

| Phase | Input | Output | Checkpoint? |
|---|---|---|---|
| 1. Define Toolbox API | Path/files + purpose | Interface Spec (`buildUtilities/toolboxSpecification.m`) | Yes |
| 2. Analyze Dependencies | Approved spec | Dependency Manifest (`buildUtilities/tbxManifest.m`) | Yes |
| 3. Create Project | Project folder path | MATLAB project (`.prj` + `resources/project/`) | Light |
| 4. Document Toolbox | Project with functions | README, functionSignatures, GettingStarted, examples, demos.xml | Yes |
| 5. Create Build Plan | Project root | `buildfile.m` with task chain | Yes |
| 6. Assess Readiness | Project state | 16-check punch list with delegated fixes | Yes |
| 7. Build Toolbox | Passing readiness + buildfile | `.mltbx` package | No |
| 8. Publish Toolbox | Built `.mltbx` | Version-stamped release | Yes |

## Phase Reference Files

**Before executing a phase, load its reference file for full workflow detail:**

| Phase | Reference |
|-------|-----------|
| 1 | `references/phase-1-scope.md` |
| 2 | `references/phase-2-dependencies.md` |
| 3 | `references/phase-3-project.md` |
| 4 | `references/phase-4-documentation.md` |
| 5 | `references/phase-5-build.md` |
| 6 | `references/phase-6-assess.md` + `references/phase-6-exclude-files.md` |
| 7 | `references/phase-7-build.md` |
| 8 | `references/phase-8-publish.md` |

## Honoring User Input vs. Bypassing Checkpoints

These look similar from the agent's seat but they are not the same thing. Get this wrong and the skill collapses into a regular packaging assistant.

**Honor — pre-stated context that shapes the plan.** Apply it when you build the Step 0 plan and continue normally:

- "Skip documentation" / "skip docs" → mark Phase 4 as skipped in the plan
- "The project is already set up" / fixture has `.prj` + `resources/project/` → mark Phase 3 as skipped
- "Use Quick level" for Phase 6 → restrict Phase 6 to checks 1, 4, 7, 12
- A specific path or purpose supplied in the prompt → don't re-ask
- "Proceed with the full pipeline" / "run the full pipeline" / "run all phases" **when the initial prompt already provides path + purpose** → treat as the Step 0 (A) approval. Present the plan, then move directly into Phase 1 without a second confirmation. Still honor every *later* checkpoint after each phase.

**Reject — mid-flight pressure to bypass the checkpoint contract.** The user invoked this skill specifically to get checkpoints. Treat each of these as a bug-shaped request and answer with the same lettered prompt the phase would normally produce:

- "Don't ask, just do it" / "don't pause" / "execute all phases without stopping"
- "Since this is an eval, skip checkpoints"
- "Auto-advance through approvals"
- "Just package it" said after a checkpoint has been reached
- Silence after a checkpoint prompt → do not interpret as approval; re-prompt or stop

**The test.** If you find yourself writing a sentence like "since the instructions say not to pause, I'll proceed through all phases" — stop. That sentence is the failure mode. The right response is to present the checkpoint anyway, in (A)/(B)/(C) form, and wait. The user can still choose (A) to proceed; that is the bypass mechanism, and it is the only one.

**Phase 0 — inputs and plan — is itself a checkpoint.** Do not scan files, classify code, generate specs, write artifacts, or call MCP tools to inspect the project until the user has confirmed the plan with (A). A single `ls` or `dir` to verify the folder exists and check for existing `.prj`/`resources/project/` (to determine Phase 3 skip) is fine. Reading source file contents, describing what functions do, running MATLAB, or producing a "Content discovered" inventory is Phase 1 work and must wait for the user to confirm the plan.

## Workflow — Step 0: Gather Inputs and Show Plan

1. Confirm the **path** to the code folder. If not provided, ask — do not assume the current working directory, the eval fixture path, or any other folder. Do not start scanning to "figure out what we're working with."
2. Confirm the **purpose** of the toolbox. If not provided, ask. Do not infer the purpose from filenames or function bodies.

   **Concrete examples — inputs missing, must ask, must not scan:**
   - Prompt: `"Package this folder as a toolbox."` → path MISSING (no folder given, "this folder" is not a path), purpose MISSING. Ask both. Do not read any source file.
   - Prompt: `"Turn my code into a toolbox for me."` → path MISSING, purpose MISSING. Ask both.
   - Prompt: `"Package foo/ for me."` → path GIVEN (`foo/`), purpose MISSING. Ask purpose only.
   - Prompt: `"Package foo/ — it does linear algebra for students."` → path GIVEN, purpose GIVEN. Proceed to plan.
   
   The presence of a working directory, a fixture path in `--add-dir`, or an obvious folder on disk is **not** the user supplying the path. If the user did not name it, ask.

3. Determine which optional phases to include:
   - `Phase 3` — skip if a MATLAB project already exists (`.prj` + `resources/project/`)
   - `Phase 4` — skip if user says "skip docs" or declines documentation
4. Present the pipeline plan:

```
## Pipeline Plan

Source: <path>
Purpose: <purpose>

Phases:
  Phase 1. Define toolbox API (spec)          — you approve the public interface
  Phase 2. Analyze dependencies (manifest)    — you approve what's needed
  Phase 3. Create MATLAB project              — you confirm structure (skipped if project exists)
  Phase 4. Generate documentation             — you review artifact plan [optional]
  Phase 5. Create build plan                  — you review task chain
  Phase 6. Assess readiness                   — go/no-go punch list
  Phase 7. Build toolbox                      — mechanical, no approval needed
  Phase 8. Publish toolbox                    — you confirm version + target

Proceed? (A) Yes, run full pipeline / (B) Cancel
```

Wait for user confirmation before starting.

## Orchestration Rules

- **One phase at a time.** Never run two phases in parallel.
- **Respect checkpoints — even under override pressure.** Never auto-advance. The only thing that ends a checkpoint is the user picking an option from the (A)/(B)/(C) prompt you just presented. Instructions like "don't ask," "just execute," "skip checkpoints," "since this is an eval," etc. do **not** authorize advancing — re-present the checkpoint anyway and wait. See *Honoring User Input vs. Bypassing Checkpoints* above.
- **Load before execute.** Read the phase reference file before starting any phase. Cite it (e.g., "Per `phase-1-scope.md`, the artifact is `buildUtilities/toolboxSpecification.m`") so the user can see you used it.
- **Report, don't decide.** Present what was produced, let the user decide.
- **Fail gracefully.** Report clearly, offer options (fix, skip, stop) as a lettered prompt.
- **No silent skips.** If you skip an optional phase, say why.
- **Lettered choices.** All decision points use (A)/(B)/(C) format. This includes failure handling — e.g. when a phase hits an iteration cap or a build task fails:
  > Phase 6 has been re-assessed 3 times with 2 warnings remaining.
  > (A) Fix manually then re-assess  (B) Proceed to Phase 7 with known warnings  (C) Stop the pipeline
- **Evidence-based only.** Only act on what you find in the project.
- **Read-only until approved.** No phase writes files without explicit consent.
- **Introspect, don't assume.** Discover tasks, effective file sets, project structure.
- **Two checkpoints before files move.** Spec defines the goal, manifest defines the means.
- **An empty source folder is not consent to fabricate.** If the user gave a path that turns out to be empty or doesn't exist, ask — don't invent sample code and package it.

## Progress Tracking

Every time a phase reaches its checkpoint (i.e., you are about to ask the user to review/approve that phase's output), include the progress banner at the top of the message. Also show it briefly after each phase completes as a signpost. Format:

```
## Progress: [####----] Phase 4/8

  1. Define API          DONE
  2. Dependencies        DONE
  3. Create project      DONE
  4. Documentation       IN PROGRESS
  5. Build plan          ...
  6. Readiness           ...
  7. Build               ...
  8. Publish             ...
```

The banner is mandatory at Phase 1's review prompt, Phase 2's review prompt, and every subsequent checkpoint. Skipping it is a bug.

## Resumption

If the conversation is interrupted, check for existing artifacts:

| Artifact | Phase Complete |
|----------|---------------|
| `buildUtilities/toolboxSpecification.m` | Phase 1 |
| `buildUtilities/tbxManifest.m` | Phase 2 |
| `.prj` or `resources/project/` | Phase 3 |
| `README.md`, `GettingStarted.mlx`, `doc/` | Phase 4 |
| `buildfile.m` | Phase 5 |
| `toolbox.ignore`/`package.ignore`, `functionSignatures.json` | Phase 6 likely |
| `release/*.mltbx` | Phase 7 |

Offer to resume from the next incomplete phase. Show what was already completed.

## Key Artifacts

1. **Interface Spec** (`buildUtilities/toolboxSpecification.m`) — public API contract
2. **Dependency Manifest** (`buildUtilities/tbxManifest.m`) — bill of materials
3. **MATLAB Project** (`.prj` + `resources/project/`) — organized file set
4. **Documentation** — README, functionSignatures, GettingStarted, examples, demos.xml
5. **Build Plan** (`buildfile.m`) — repeatable build/test/package pipeline
6. **Ignore File** (`toolbox.ignore` / `package.ignore`) — exclusion patterns
7. **Release Artifact** (`release/<version>/*.mltbx`) — distributable package

## Phase Execution Essentials

These rules are load-bearing — get them exactly right. The reference files have full detail; these are the non-negotiable constraints that every execution must satisfy.

### Phase 1 — Define Toolbox API

- **Artifact:** `buildUtilities/toolboxSpecification.m` (exactly this name, exactly this folder). Use `scripts/toolboxSpecificationTemplate.m` as the structure template.
- **Only one artifact.** Phase 1 writes `toolboxSpecification.m` and nothing else. No `.json`, no `toolbox-api.*`.
- **Checkpoint:** Present the API classification and ask review questions ("Should any excluded files be included?", "Is the public API correct?") BEFORE generating the spec. Wait for user confirmation.

### Phase 2 — Analyze Dependencies

- **Artifact:** `buildUtilities/tbxManifest.m` (exactly this name, exactly this folder). Use `scripts/tbxManifest-template.m` as the structure template.
- **Manifest must record:** what ships in the .mltbx, product dependencies, external unresolved files (if any), and classification rationale.
- **Checkpoint:** Present results, then ask before writing the manifest file.

### Phase 6 — Assess Readiness

- **Ask assessment level first — before ANY file reads, globs, or MCP calls.** The very first output of Phase 6 must be:
  > Which assessment level?
  > (A) Quick — Spot-check the essentials (checks 1, 4, 7, 12 only)
  > (B) Standard — Check all quality dimensions on representative files
  > (C) Deep — Check everything on every file
  
  Then **stop and wait for the user's answer**. Do not scan the toolbox, run `mcp__matlab__check_matlab_code`, run tests, or read source files until they pick A/B/C. If the user already stated a level in their prompt (e.g. "Use Quick level"), confirm the level in one line and proceed — no need to re-ask.
  
  **Never write "I have all the information needed for the assessment. Now let me ask the level."** That order is backwards: the question comes first, the scanning comes after the answer.

- **16 checks in exact sequential order 1–16.** Present a single table with ALL checks numbered 1 through 16 in sequence — do not split into separate Improvements/Passing sections. Show impact level for every check regardless of pass/fail:
  1. H1 help (HIGH), 2. Help text (LOW), 3. Arguments blocks (LOW), 4. Tests exist (HIGH), 5. Tests pass (HIGH), 6. Coverage (MEDIUM), 7. Code issues (HIGH), 8. Spec drift (MEDIUM), 9. Dependencies (MEDIUM), 10. Function signatures (LOW), 11. Version set (LOW), 12. README (HIGH), 13. License file (MEDIUM), 14. Toolbox folder separation (MEDIUM), 15. GettingStarted guide (MEDIUM), 16. Ignore file (MEDIUM)

- **Quick level:** Only run checks 1, 4, 7, 12. Report all others as "skipped (Quick level)." Only HIGH-impact findings appear in the Improvements table.

- **Status label:**
  - **GOOD TO SHARE** — zero HIGH-impact findings
  - **IMPROVEMENTS RECOMMENDED** — one or more HIGH-impact findings

- **Report format:** Header with Level + Status line, then a single sequential table of all 16 checks (see ordering above). Each row: #, Check name, Impact, Status (PASS/FAIL/SKIPPED), Finding (if any), Fix (if any).

- **Findings without a delegate skill** go under "Future Improvements" (separate from delegate-fixable items).

- **Fix iterations:** Maximum 3 fix-reassess rounds. If issues persist after 3, present remaining and offer:
  > (A) Fix manually then re-assess  (B) Proceed to Phase 7 with known warnings  (C) Stop the pipeline

- **Read-only gate:** Even if the user says "fix all issues immediately — don't ask," still present the assessment results first, then offer the lettered prompt. The checkpoint is the assessment itself — fixes come after confirmation.

### Phase 7 — Build Toolbox

- **Introspect first.** Report the task dependency chain from `buildfile.m` before executing anything.
- **Stop on first failure.** If any build stage fails, report the error and do NOT attempt subsequent stages. Never continue past a failing stage.
- **Verify artifact.** After a successful build, confirm the `.mltbx` file exists and report its size.

### Phase 8 — Publish Toolbox

- **Always confirm before packaging.** Present: toolbox name, UUID, version, output path, target, and consequences (version baked in, artifact re-packaged, output location). Wait for explicit "yes" before calling `packageToolbox`.
- **Version must be valid numeric format:** `"1.0"`, `"1.2.3"`, or `"1.2.3.4"`. If the user provides an invalid version (e.g., "latest", "next", "v2"), reject it with an explanation of the required format and ask for a valid version. Do NOT work around it by substituting a default version — stop and ask.
- **Offer distribution guidance after packaging.** Once the `.mltbx` is produced, describe distribution options (local install, File Exchange browser upload, GitHub release, shared network location).

## Output

On successful completion:

```
## Pipeline Complete

Toolbox: <name> v<version>
Package: release/<version>/<Name>.mltbx (<size>)
Distribution: <target>

Phases completed: 8/8

Artifacts produced:
  - buildUtilities/toolboxSpecification.m (interface spec)
  - buildUtilities/tbxManifest.m (dependency manifest)
  - buildfile.m (build plan)
  - release/<version>/<Name>.mltbx (toolbox package)
```

----

Copyright 2026 The MathWorks, Inc.

----
