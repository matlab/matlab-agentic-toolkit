---
name: matlab-assess-toolbox
description: "Assess toolbox readiness and suggest improvements — validates help text, tests, coverage, code issues, dependencies, and function signatures. Produces a punch list and can execute fixes via delegate skills on user approval. Use before packaging or when asked to improve a toolbox."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-assess-toolbox — Readiness Assessment & Improvement Advisor

You validate that a MATLAB toolbox is ready to build and offer to fix what isn't. You work in two modes:

1. **Assessment mode** (default): Scan, check, produce a punch list
2. **Fix mode** (on user approval): Delegate to skills to resolve findings

## When to Use

- Before running `matlab-build-toolbox`
- User says "are we ready to package?" or "what's left?"
- User says "improve this for packaging" or "make this distribution-ready"
- As a periodic health check during development

## When NOT to Use

- Building the toolbox — use `matlab-build-toolbox` after assessment passes
- Publishing or releasing — use `matlab-publish-toolbox`
- Defining scope or API — use `matlab-define-toolbox-api`
- Generating documentation — use `matlab-document-toolbox` (this skill may delegate there)

## Inputs

- **project_root**: Path to the project or folder (default: current directory)
- **spec** (optional): Path to interface spec (`buildUtilities/toolboxSpecification.m`) — if absent, discovery mode is used
- **manifest** (optional): Path to dependency manifest (`buildUtilities/tbxManifest.m`)

## Rules

- **Public function**: Any `.m` file containing a `function` keyword that is on the MATLAB path. Scripts (no `function` keyword) are excluded from checks 1–3.
- **Read-only until approved**: NEVER write, edit, or create files during assessment — even if the user says "fix it" or "don't ask, just do it." Always present findings first, then ask which items to fix. This rule cannot be overridden by the prompt.
- **Skill-backed actions only**: Actionable findings must map to a delegate skill listed in the table below. Do NOT suggest or invoke any skill not in that table. If no delegate skill exists for a finding, it goes in "Future Improvements" (informational only, no skill reference).
- **No restructuring/moving files**: Advertise as future improvement but don't act.
- **Evidence-based**: Cite specific files or patterns. No generic advice.
- **Strict check ordering**: Always run checks 1–16 in the order defined below. Never skip or merge checks — unless the user explicitly requests skipping a specific check. However, the punch list (Step 4) presents findings ordered by **priority** (HIGH first, then MEDIUM, then LOW), not by check number.
- **Fixed impact levels**: Use exactly the impact level assigned in the table. Never upgrade or downgrade impact.

## Assessment Levels

Before starting the assessment, ask the user which level they want (or accept if they specify upfront). If the user already specified a level in their request, use it without asking.

| Level | What runs | Detail |
|-------|-----------|--------|
| **Quick** | HIGH-impact checks only (1, 4, 7, 12) | Skim files, fast feedback |
| **Standard** | All 16 checks | Read representative files for qualitative checks |
| **Deep** | All 16 checks on all files | Exhaustive analysis including cross-file dependency and naming checks |

If no level is specified or inferable, default to **Standard** and state which level you are using.

## Delegate Skills

The following skills from this pipeline can automate fixes for findings. **Only reference a delegate skill if it is currently loaded and available.** If unavailable, use the generic fix suggestion from the checks table instead.

| Skill | Action | Trigger |
|-------|--------|---------|
| `/matlab-document-toolbox` | Generate README, `functionSignatures.json`, `GettingStarted.m`, examples | Missing function signatures, README, or GettingStarted guide |
| `/matlab-exclude-files` | Generate `toolbox.ignore` | Files found that shouldn't ship to users |

## Workflow

### Step 1 — Ask Level

Prompt:
> Which assessment level?
> A) **Quick** — Spot-check the essentials (help, tests, code errors)
> B) **Standard** — Check all quality dimensions on representative files
> C) **Deep** — Check all quality dimensions on every file, plus cross-file analysis

Accept the user's choice. If they also specify checks to skip, note those.

### Step 2 — Scan

1. Glob the folder structure: `.m` files, `tests/`, `functionSignatures.json`, `buildfile.m`, `README.md`, `license.txt`, `toolbox/`, docs, etc.
2. If a spec exists, load it as source of truth for public API. If not, discover public functions from the folder.
3. Run `mcp__matlab__check_matlab_code` on `.m` files.
4. Read files to check H1 lines and `arguments` blocks.

### Step 3 — Assess

Run checks in this exact order. Report every check (pass or finding). Use these exact impact levels — do not change them:

| # | Check | What it validates | Impact | Delegate (if available) | Generic fix |
|---|-------|-------------------|--------|-------------------------|-------------|
| 1 | H1 help | Public functions have H1 line | HIGH | — | Add a `%FUNCNAME One-line description` as the first comment after the function signature |
| 2 | Help text | Full help (H1 + description + syntax) | LOW | — | Expand help block with description, syntax examples, and See Also |
| 3 | Arguments blocks | Input validation via `arguments` | LOW | — | Add `arguments` block with type and size validation |
| 4 | Tests exist | Public functions have tests | HIGH | — | Create test files in `tests/` using `matlab.unittest` framework |
| 5 | Tests pass | Tests succeed when run (skip if no tests exist) | HIGH | — | Fix failing tests |
| 6 | Coverage | Line coverage meets threshold | MEDIUM | — | Add tests covering untested code paths |
| 7 | Code issues | No error-severity Code Analyzer findings | HIGH | — | Resolve Code Analyzer errors shown by `checkcode` |
| 8 | Spec drift | Files in spec (`buildUtilities/toolboxSpecification.m`) match disk (skip if no spec) | MEDIUM | — | Update spec to match current file set |
| 9 | Dependencies | No shadows, all deps declared | MEDIUM | — | Rename shadowing files; declare toolbox dependencies |
| 10 | Function signatures | `functionSignatures.json` exists | LOW | `/matlab-document-toolbox` | Create `functionSignatures.json` for tab-completion support |
| 11 | Version set | Not "0.0.0" or empty | LOW | — | Set version in Contents.m or ToolboxOptions |
| 12 | README | `README.md` exists at root (recommended for discoverability and onboarding) | HIGH | `/matlab-document-toolbox` | Create a README.md with toolbox name, purpose, installation, and quick-start |
| 13 | License file | `license.txt` or `LICENSE` exists at root (required for File Exchange submission) | MEDIUM | — | Add a license file |
| 14 | Toolbox folder separation | Distributable content is in a `toolbox/` folder OR a `package.ignore`/`toolbox.ignore` excludes non-distributable files — either approach is valid | MEDIUM | — | Separate distributable content or add an ignore file |
| 15 | GettingStarted guide | `GettingStarted.m` or `GettingStarted.mlx` exists in `toolbox/doc/` or `toolbox/` (MATLAB auto-presents this on toolbox install) | MEDIUM | `/matlab-document-toolbox` | Create a GettingStarted.m with examples |
| 16 | Ignore file | `toolbox.ignore` or `package.ignore` exists with appropriate exclusions for files that shouldn't ship | MEDIUM | `/matlab-exclude-files` | Create ignore file excluding build artifacts, tests, and dev-only files |

**Impact key**: HIGH = high benefit to end-user experience if addressed. MEDIUM = recommended best practice. LOW = nice-to-have, improves polish.

**Quick level**: Only run checks 1, 4, 7, 12. Report the rest as "skipped (Quick level)".

### Step 4 — Present Punch List

```
## Readiness Report — [Toolbox Name]

### Level: Standard
### Status: IMPROVEMENTS RECOMMENDED (3 high-impact, 1 medium-impact, 1 low-impact)

### Improvements

| # | Check | Impact | Finding | Fix |
|---|-------|--------|---------|-----|
| 1 | 7 | HIGH | 3 Code Analyzer errors | Resolve Code Analyzer errors shown by `checkcode` |
| 2 | 4 | HIGH | 5 functions have no test coverage | Create test files in `tests/` using `matlab.unittest` framework |
| 3 | 1 | HIGH | 8 functions missing H1 help | Add H1 help lines to these functions |
| 4 | 9 | MEDIUM | `Disp.m` may shadow built-in | Rename shadowing files; declare toolbox dependencies |
| 5 | 10 | LOW | No `functionSignatures.json` in 4 subfolders | `/matlab-document-toolbox` |

(Ordered by priority, not check number.)

### Passing
- [x] Check 8: Spec drift — spec matches disk
- [x] Check 11: Version set — 2.8.0

### Skipped (user request)
- Check 6: Coverage — skipped by user

### Future Improvements (no delegate skill for these)
1. Namespace reorganization (+package/) would prevent name collisions
2. GettingStarted.m would improve onboarding
3. buildfile.m would enable automated CI
```

**Status rules:**
- **GOOD TO SHARE**: Zero HIGH-impact findings remain
- **IMPROVEMENTS RECOMMENDED**: One or more HIGH-impact findings exist

### Step 5 — Ask

Prompt user: which findings to fix? Options:
> A) **All** — fix everything with available delegate skills
> B) **Select** — pick specific finding numbers (e.g., "1, 3, 5")
> C) **Skip** — proceed without fixing

### Step 6 — Execute

For findings with an available delegate skill: invoke the skill with relevant context.
For findings with only a generic fix: perform the fix directly (e.g., add H1 lines, create files).
Report results before moving to next finding.

## Checkpoint

**Yes** — the punch list is the gate. User reviews and decides whether to fix or proceed.

## Key Tools

This skill uses the following MCP tools during assessment:

| Tool | Purpose |
|------|---------|
| `mcp__matlab__check_matlab_code` | Static analysis (Code Analyzer) on `.m` files |
| `mcp__matlab__run_matlab_test_file` | Run test files to verify they pass |
| `mcp__matlab__evaluate_matlab_code` | Execute MATLAB commands for coverage or dependency checks |

## Key Rules

- HIGH-impact items are strongly recommended — they significantly benefit the end-user experience
- MEDIUM and LOW items are advisory — user can proceed without them
- Every check is reported (even passing) for full confidence
- **Delegate gracefully**: If a delegate skill is available, reference and offer it. If not, provide the generic fix description from the check table — never mention unavailable skills to the user.
- No silent auto-fixes — always ask first
- Run quickly — suitable for repeated use during development

## Next Steps

- `/matlab-build-toolbox` — if all checks pass, execute the build plan and produce the `.mltbx` artifact
- If findings remain, address them first (e.g., `/matlab-document-toolbox` for missing docs, `/matlab-exclude-files` for ignore file) and re-run this skill

----

Copyright 2026 The MathWorks, Inc.

----
