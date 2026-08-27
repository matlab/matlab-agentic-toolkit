# Phase 0: Auto-detect MATLAB installations

Skip this phase if both `from:` and `to:` roots were provided as arguments.

## Step 1: Determine platform

Detect the OS to know where MATLAB installs by default:

```bash
uname -s
```

- `Linux` → default install dir: `/usr/local/MATLAB/`
- `Darwin` → default install dir: `/Applications/`
- Windows (MINGW/CYGWIN/MSYS or if uname unavailable) → default install dir: `C:\Program Files\MATLAB\`

## Step 2: Find all installed releases

```bash
# Linux:
ls -d /usr/local/MATLAB/R20* 2>/dev/null | sort

# macOS:
ls -d /Applications/MATLAB_R20*.app 2>/dev/null | sort

# Windows (from Git Bash / MSYS):
ls -d "/c/Program Files/MATLAB/R20"* 2>/dev/null | sort
```

## Step 3: Identify the source release (what the script was written for)

Determine which installed release the script currently targets. Do this by reading the script (Phase 2, which runs in parallel) and then matching its setting paths against each installed release's factory settings library. The release whose settings match the most paths in the script is the source.

Quick heuristics to try first (cheaper than full matching):
- A comment in the script like `% Written for R2025b` or `% R2025b`
- The filename contains a release hint (e.g., `startup_2025b.m`, `prefs_R2026a.m`)

If heuristics fail, do a quick match: pick one or two setting keys from the script and grep them in each release's factory settings SO/DLL. The release that has ALL of them is the source.

## Step 4: Determine the target release

- **If `to:` was provided:** Resolve that release name to its install path.
- **If `to:` was NOT provided:** Default to the **latest** (chronologically newest) installed release that is NOT the source release. This is the most common case — user just installed a new release and wants to update their script.
- **If only the source release is installed (no other releases):** Ask the user to provide the target path manually.

The release sort order is: `R20XXa` < `R20XXb` (e.g., `R2025a` < `R2025b` < `R2026a`).

**Note:** If the user wants to migrate backward (downgrade), they must specify `to:` explicitly. The default always goes to the latest.

---

Copyright 2026 The MathWorks, Inc.
