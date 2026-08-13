# Phase 6: Assess Readiness

Validate that the toolbox is ready to build. Produce a punch list and offer to fix findings.

## Rules

- **Read-only until approved**: NEVER write, edit, or create files during assessment — even if the user says "fix it" or "don't ask, just do it." Always present findings first.
- **Skill-backed actions only**: Actionable findings must map to a delegate skill in the table below.
- **No restructuring/moving files**: Advertise as future improvement but don't act.
- **Evidence-based**: Cite specific files or patterns.
- **Strict check ordering**: Always run checks 1–16 in order.
- **Fixed impact levels**: Use exactly the impact level assigned in the table.

## Assessment Levels

| Level | What runs | Detail |
|-------|-----------|--------|
| **Quick** | HIGH-impact checks only (1, 4, 7, 12) | Skim files, fast feedback |
| **Standard** | All 16 checks | Read representative files |
| **Deep** | All 16 checks on all files | Exhaustive cross-file analysis |

Default to **Standard** if not specified.

## Step 6.1 — Ask Level (STOP HERE — do not scan yet)

Before reading, globbing, or running any checks on the toolbox, ask the level question and **wait for the user's answer**. Present it as the very first output of Phase 6:

> Which assessment level?
> A) **Quick** — Spot-check the essentials
> B) **Standard** — Check all quality dimensions on representative files
> C) **Deep** — Check everything on every file

Do NOT proceed to Step 6.2 until the user answers A, B, or C. If the user already said "Quick", "Standard", or "Deep" in the current prompt, treat that as the answer — you can skip the question but still confirm the level in one sentence before scanning.

## Step 6.2 — Scan (only after Step 6.1)

1. Glob the folder structure
2. Load spec if exists, otherwise discover public functions
3. Run `mcp__matlab__check_matlab_code` on `.m` files
4. Read files to check H1 lines and `arguments` blocks

## Step 6.3 — Assess (16 Checks)

| # | Check | Impact | Delegate (if available) | Generic fix |
|---|-------|--------|-------------------------|-------------|
| 1 | H1 help | HIGH | — | Add `%FUNCNAME One-line description` |
| 2 | Help text | LOW | — | Expand help block |
| 3 | Arguments blocks | LOW | — | Add `arguments` block |
| 4 | Tests exist | HIGH | — | Create test files in `tests/` |
| 5 | Tests pass | HIGH | — | Fix failing tests |
| 6 | Coverage | MEDIUM | — | Add tests for untested paths |
| 7 | Code issues | HIGH | — | Resolve Code Analyzer errors |
| 8 | Spec drift | MEDIUM | — | Update spec to match disk |
| 9 | Dependencies | MEDIUM | — | Rename shadows; declare deps |
| 10 | Function signatures | LOW | Phase 4 (Document) | Create `functionSignatures.json` |
| 11 | Version set | LOW | — | Set version in Contents.m |
| 12 | README | HIGH | Phase 4 (Document) | Create README.md |
| 13 | License file | MEDIUM | — | Add license file |
| 14 | Toolbox folder separation | MEDIUM | — | Separate content or add ignore file |
| 15 | GettingStarted guide | MEDIUM | Phase 4 (Document) | Create GettingStarted.m |
| 16 | Ignore file | MEDIUM | Exclude Files utility | Create ignore file |

**Impact key**: HIGH = high benefit to end-user experience. MEDIUM = recommended best practice. LOW = nice-to-have.

**Quick level**: Only checks 1, 4, 7, 12. Report rest as "skipped (Quick level)."

## Step 6.4 — Present Punch List

```
## Readiness Report — [Toolbox Name]

### Level: Standard
### Status: IMPROVEMENTS RECOMMENDED (N high, N medium, N low)

### Improvements
| # | Check | Impact | Finding | Fix |
|---|-------|--------|---------|-----|

### Passing
- [x] Check N: description

### Skipped
- Check N: reason
```

**Status rules:**
- **GOOD TO SHARE**: Zero HIGH-impact findings
- **IMPROVEMENTS RECOMMENDED**: One or more HIGH-impact findings

## Step 6.5 — Ask

> A) **All** — fix everything with available delegates
> B) **Select** — pick specific finding numbers
> C) **Skip** — proceed without fixing

## Step 6.6 — Execute Fixes

For findings with a delegate: invoke the relevant phase or utility with context.
For findings with only a generic fix: perform directly.
Report results. **Maximum 3 fix-reassess iterations.** If issues persist after 3 rounds, present remaining and offer (B) proceed or (C) stop.

----

Copyright 2026 The MathWorks, Inc.

----
