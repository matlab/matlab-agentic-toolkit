---
name: matlab-analyze-dependencies
description: "Analyze the effective toolbox file set to produce a Dependency Manifest — classify all transitive dependencies as included, product, add-on, or external-unresolved, then present resolution options with tradeoffs. Use after matlab-define-toolbox-api when the spec is approved."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-analyze-dependencies — Dependency Analyzer

You produce the **Dependency Manifest**: a complete picture of what the toolbox needs at runtime, what ships inside the .mltbx, and what doesn't. For anything that doesn't ship, you explain why and present resolution options.

## When to Use

- After `matlab-define-toolbox-api` spec is approved, or user asks "what does this code depend on?"
- Re-running after code changes to update the manifest

## When NOT to Use

- Writing code or fixing bugs — this skill only analyzes, it does not modify source
- Building the .mltbx — use `matlab-build-toolbox` after dependencies are resolved
- Initial project setup — use `matlab-define-toolbox-api` first to define the toolbox spec

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlab.addons.toolbox.ToolboxOptions` | Determine effective file set (what ships) |
| `matlab.codetools.requiredFilesAndProducts` | Trace transitive file and product dependencies |
| `which` | Resolve namespace-qualified function names |
| `exist` | Check if bare function names resolve |
| `matlab.addons.installedAddons` | Correlate add-on file paths with metadata |

## Critical Pitfalls

These three issues cause **silent failures** — no error is raised, but classification results are wrong. Always apply these fixes.

### Pitfall 1: Path Separator Mismatch (Windows)

On Windows, `fList` returns backslashes regardless of input. If `toolboxRoot` has forward slashes, `startsWith(fList, toolboxRoot)` silently returns false for every file. **Normalize both before any comparison:**

```matlab
toolboxRoot = replace(toolboxRoot, '/', filesep);
fList = replace(fList, '/', filesep);
```

### Pitfall 2: matlabroot File Leak

Files under `matlabroot` (e.g., `toolbox/local/userpath.m`) occasionally appear in `fList` because they live in non-product folder structures. **Filter them out:**

```matlab
mroot = matlabroot;
fList = fList(~startsWith(fList, mroot));
```

### Pitfall 3: Namespace Resolution Requires which()

`exist('pkg.subpkg.func', 'file')` returns **0** even when the function is valid and on the path. For any dotted/namespace-qualified name, use `which()` instead:

```matlab
% exist() FAILS for namespace calls:
exist('statskit.internal.computeRange', 'file')  % returns 0 (wrong!)

% which() WORKS:
which('statskit.internal.computeRange')  % returns full path
```

**Resolution strategy:**
- Bare names (no dots): `exist(name, 'file') > 0 || exist(name, 'builtin') > 0`
- Dotted names: `~isempty(which(name))`

## Core Concepts

**The Packaging Constraint:** An .mltbx can only contain files inside the toolbox root folder. External files cannot be pulled in at install time. The only options are: copy in, declare add-on dependency, Additional Software (URL zip), or refactor.

**The Effective File Set:** All files in toolbox root minus those excluded by the ignore file and default exclusions. Use `ToolboxOptions` to determine this authoritatively. The ignore file may be named `toolbox.ignore` (R2026a and earlier) or `package.ignore` (R2026b+). Check for both — `ToolboxOptions` handles whichever is present.

## Workflow

### Phase 1 — Determine the Effective File Set

```matlab
identifier = matlab.lang.internal.uuid();
opts = matlab.addons.toolbox.ToolboxOptions(toolboxRoot, identifier);
effectiveFiles = opts.ToolboxFiles;
```

Do not reimplement ignore-file logic manually. `ToolboxOptions` handles both file names, default exclusions, and edge cases.

### Phase 2 — Trace Dependencies

```matlab
mFiles = effectiveFiles(endsWith(effectiveFiles, ".m") | endsWith(effectiveFiles, ".mlx"));
[fList, pList] = matlab.codetools.requiredFilesAndProducts(mFiles);
fList = string(fList(:));
```

Apply Pitfall 1 (normalize paths) and Pitfall 2 (filter matlabroot) **immediately after** getting fList, before any classification.

**Classify files in fList:**
- **Included**: starts with `toolboxRoot` and in effective set
- **Add-on**: under `fullfile(getenv('APPDATA'), 'MathWorks', 'MATLAB Add-Ons')`
- **External unresolved**: everything else — requires user decision

**Classify products from pList:**
- `Certain == 1`: confirmed product dependency — declare in metadata
- `Certain == 0`: heuristic guess — flag for user confirmation

**Check ignore conflicts:** Files inside toolbox root that are in `fList` but NOT in `effectiveFiles` — code needs them but they won't ship.

**Check runtime file references:** `fList` never contains data files (.mat, .csv, images, etc.). Scan `.m` files for I/O functions with string-literal path arguments to detect files that code needs at runtime but won't ship. See `references/runtime-file-references.md` for the full function list, regex patterns, and classification logic.

### Phase 2b — Detect Unresolved Symbols

`requiredFilesAndProducts` silently skips unresolvable symbols. A separate detection step is needed.

**Do NOT rely on `checkcode`/`codeIssues`** — MATLAB's static analyzer is intentionally lenient about unresolved functions.

For each file, extract candidate function names (via `mtree` or regex `(?<![%.\w])([a-zA-Z]\w*)\s*\(`). Filter out:
- MATLAB keywords (`if`, `for`, `while`, `switch`, `function`, `arguments`, `end`, `return`)
- The function's own name
- Local functions defined in the same file
- Variables in `arguments` blocks (validation syntax looks like function calls to regex)
- Functions from `localfunctions` pattern (test files)

For dotted identifiers (regex: `([a-zA-Z]\w*(?:\.[a-zA-Z]\w*)*)(?=\s*\()`), apply Pitfall 3 — use `which()`.

Classify unresolved symbols and present with resolution suggestions. See `references/unresolved-symbol-classification.md` for the full classification table and presentation format.

### Phase 3 — Transitive Closure of External Files

For each external file, trace its dependency subtree. At each level classify children. Build the tree showing pull-in cost.

**Early termination:** If subtree exceeds ~15 files across multiple directories, mark as "sprawling" — needs architectural resolution, not file-by-file copying.

**Deduplication:** Use `'toponly'` on each toolbox file to find which externals are directly called. Externals only reached transitively through another external are nested under their parent, not shown as top-level decisions.

**Detect patterns:** Multiple externals from same directory → group them. Parent folder has `.prj` or `resources/project/` → belongs to a MATLAB Project.

### Phase 4 — Present Results

Produce a tree view showing directly-called externals with call chains and transitive cost, plus a summary table. See `references/tree-view-format.md` for formatting guidance.

### Phase 5 — Recommend Resolution Options

Present options with tradeoffs for each unresolved external or group. See `references/resolution-options.md` for the option matrix and outward-refactor handoff template.

This skill **does not perform resolutions**. It presents options so the user (or a downstream skill that handles toolbox structure) can act. Do not copy files, edit ignore files, or refactor code.

### Phase 6 — Persist the Manifest

After the user acknowledges the analysis, save as `buildUtilities/tbxManifest.m`. The manifest records the current state — what ships, what's external, what's unresolved — not the resolution decisions. See `scripts/tbxManifest-template.m` for the template structure.

## Output

- **Primary artifact**: `buildUtilities/tbxManifest.m`
- **Display**: Tree view + summary table + recommendations in conversation

## Scope Boundary

This skill only **analyzes and recommends**. It does not:
- Copy or move files into the toolbox
- Edit ignore files
- Refactor code or fix typos
- Modify the MATLAB path

These actions are the user's responsibility or belong to a downstream skill that understands how the toolbox should be structured. After resolutions are applied externally, re-run this skill to confirm progress.

## Key Rules

- Show the full transitive cost of pulling in any external
- Surface same-folder groups as one architectural decision, not N individual ones
- Present resolution options with tradeoffs — do not execute them
- After resolution (done externally), re-running should show progress (externals become included or add-on)
- Flag ignore conflicts — a needed-but-excluded file is a silent packaging bug

## Next Steps

- `/matlab-create-project` — organize files into a MATLAB project with the resolved dependency structure

----

Copyright 2026 The MathWorks, Inc.

----
