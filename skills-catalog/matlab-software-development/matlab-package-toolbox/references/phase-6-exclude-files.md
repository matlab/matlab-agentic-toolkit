# Utility: Exclude Files (invoked by Phase 6)

Analyze the toolbox folder and suggest which files should be excluded from packaging. Only suggest patterns for files that actually exist.

## Rules

- **Read-only until approved**: Never write without consent.
- **Evidence-based only**: Only suggest patterns for files found in the scan. NEVER mention patterns if no matching file exists.
- **No duplicates**: Only suggest additions not already covered by existing ignore file.
- **Respect MATLAB defaults**: NEVER suggest `.git/`, `.svn/`, `.buildtool/`, `*.asv`, `resources/project/`, `*.prj`.

## Detectable Patterns

| Pattern | Why exclude | Impact |
|---------|------------|--------|
| `*.DS_Store` | OS metadata | HIGH |
| `Thumbs.db` | Windows thumbnail cache | HIGH |
| `.vscode/`, `.idea/` | IDE settings | HIGH |
| `*.log` | Log files | HIGH |
| `*.orig` | Merge conflict leftovers | HIGH |
| `slprj/` | Simulink cache | HIGH |
| `codegen/` | Coder output | HIGH |
| `*.mltbx` | Previously built packages | HIGH |
| `tmp/`, `temp/` | Scratch directories | HIGH |
| `tests/`, `test/` | Test files inside toolbox | MEDIUM |
| `buildUtilities/` | Build scripts | MEDIUM |
| `buildfile.m` | Build automation (if in toolbox) | MEDIUM |
| `*.cpp`, `*.c`, `*.h` | MEX source (when `.mex*` exists) | MEDIUM |
| `.github/`, `.gitlab-ci.yml`, `.circleci/`, `.travis.yml` | CI/CD workflows | MEDIUM |
| `doc/internal/` | Internal docs | MEDIUM |
| `.m` with matching `.p` | Source alongside pcode | MEDIUM |

## Workflow

1. **Scan** — glob toolbox folder recursively
2. **Check existing** — read `toolbox.ignore` or `package.ignore` if present
3. **Detect** — match found files against patterns, excluding already-covered and MATLAB defaults
4. **Present** — grouped by category with evidence:

```
## Ignore Suggestions — [Toolbox Name]

### OS / IDE Metadata
| # | Pattern | Found | Reason |
|---|---------|-------|--------|

### Test Infrastructure
| # | Pattern | Found | Reason |
|---|---------|-------|--------|
```

5. **Ask:**
> A) **All** — include everything
> B) **All HIGH** — only HIGH-impact
> C) **Select** — pick specific numbers
> D) **Skip** — don't create/modify

6. **Write** — create or append to `toolbox.ignore` (or `package.ignore` for R2025a+)

----

Copyright 2026 The MathWorks, Inc.

----
