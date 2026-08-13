# Phase 2: Analyze Dependencies

Produce the Dependency Manifest: a complete picture of what the toolbox needs at runtime, what ships inside the .mltbx, and what doesn't.

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlab.addons.toolbox.ToolboxOptions` | Determine effective file set (what ships) |
| `matlab.codetools.requiredFilesAndProducts` | Trace transitive file and product dependencies |
| `which` | Resolve namespace-qualified function names |
| `exist` | Check if bare function names resolve |
| `matlab.addons.installedAddons` | Correlate add-on file paths with metadata |

## Critical Pitfalls

**Pitfall 1: Path Separator Mismatch (Windows)**

On Windows, `fList` returns backslashes regardless of input. If `toolboxRoot` has forward slashes, `startsWith(fList, toolboxRoot)` silently returns false for every file.

```matlab
toolboxRoot = replace(toolboxRoot, '/', filesep);
fList = replace(fList, '/', filesep);
```

**Pitfall 2: matlabroot File Leak**

Files under `matlabroot` occasionally appear in `fList`. Filter them out:

```matlab
mroot = matlabroot;
fList = fList(~startsWith(fList, mroot));
```

**Pitfall 3: Namespace Resolution Requires which()**

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

**The Packaging Constraint:** An .mltbx can only contain files inside the toolbox root folder. External files cannot be pulled in at install time. Options: copy in, declare add-on dependency, Additional Software (URL zip), or refactor.

**The Effective File Set:** All files in toolbox root minus those excluded by the ignore file and default exclusions. Use `ToolboxOptions` to determine this authoritatively. The ignore file may be named `toolbox.ignore` (R2026a and earlier).

## Step 2.1 — Determine the Effective File Set

```matlab
identifier = matlab.lang.internal.uuid();
opts = matlab.addons.toolbox.ToolboxOptions(toolboxRoot, identifier);
effectiveFiles = opts.ToolboxFiles;
```

Do not reimplement ignore-file logic manually.

## Step 2.2 — Trace Dependencies

```matlab
mFiles = effectiveFiles(endsWith(effectiveFiles, ".m") | endsWith(effectiveFiles, ".mlx"));
[fList, pList] = matlab.codetools.requiredFilesAndProducts(mFiles);
fList = string(fList(:));
```

Apply Pitfall 1 and Pitfall 2 **immediately after** getting fList.

**Classify files in fList:**
- **Included**: starts with `toolboxRoot` and in effective set
- **Add-on**: under `fullfile(getenv('APPDATA'), 'MathWorks', 'MATLAB Add-Ons')`
- **External unresolved**: everything else — requires user decision

**Classify products from pList:**
- `Certain == 1`: confirmed product dependency — declare in metadata
- `Certain == 0`: heuristic guess — flag for user confirmation

**Check ignore conflicts:** Files inside toolbox root that are in `fList` but NOT in `effectiveFiles` — code needs them but they won't ship.

**Check runtime file references:** `fList` never contains data files (.mat, .csv, images, etc.). Scan `.m` files for I/O functions with string-literal path arguments. See `references/runtime-file-references.md`.

## Step 2.3 — Detect Unresolved Symbols

`requiredFilesAndProducts` silently skips unresolvable symbols. For each file, extract candidate function names (via `mtree` or regex `(?<![%.\w])([a-zA-Z]\w*)\s*\(`). Filter out MATLAB keywords, the function's own name, local functions, variables in `arguments` blocks.

For dotted identifiers, apply Pitfall 3 — use `which()`.

See `references/unresolved-symbol-classification.md` for classification and presentation.

## Step 2.4 — Transitive Closure of External Files

For each external file, trace its dependency subtree. At each level classify children. Build the tree showing pull-in cost.

**Early termination:** If subtree exceeds ~15 files across multiple directories, mark as "sprawling."

**Deduplication:** Use `'toponly'` on each toolbox file to find which externals are directly called.

**Detect patterns:** Multiple externals from same directory → group them.

## Step 2.5 — Present Results

Produce a tree view showing directly-called externals with call chains and transitive cost. See `references/tree-view-format.md`.

## Step 2.6 — Recommend Resolution Options

Present options with tradeoffs for each unresolved external or group. See `references/resolution-options.md`.

This phase **does not perform resolutions**. It presents options so the user can decide.

## Step 2.7 — Persist the Manifest

Save as `buildUtilities/tbxManifest.m`. See `scripts/tbxManifest-template.m`.

## Rules

- Show the full transitive cost of pulling in any external
- Surface same-folder groups as one architectural decision, not N individual ones
- Present resolution options with tradeoffs — do not execute them
- Flag ignore conflicts — a needed-but-excluded file is a silent packaging bug

----

Copyright 2026 The MathWorks, Inc.

----
