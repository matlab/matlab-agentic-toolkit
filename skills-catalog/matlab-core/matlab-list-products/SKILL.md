---
name: matlab-list-products
description: "Show all installed MATLAB products and support packages for a given MATLAB installation folder. Use when listing, checking, or verifying what products or support packages are in a MATLAB installation."
license: "MathWorks BSD-3-Clause"
metadata:
  author: MathWorks
  version: "1.0"
---

# Show Installed MATLAB Products

Use this skill when asked to show, list, or check what MATLAB products or support packages are installed in a given MATLAB installation.

$ARGUMENTS

## When to Use

- User asks what products, toolboxes, or support packages are installed in a MATLAB installation
- User wants to verify a specific product is installed
- User asks to list or check their MATLAB installation contents
- User provides a matlabroot path or release name and wants to see what's there

## When NOT to Use

- User wants to install new products (use `matlab-install-products` instead)
- User wants to check MATLAB license status or activation (different workflow)
- User wants to manage or update Add-Ons from within MATLAB
- User asks about MATLAB version/release info only (use `ver` or `version` in MATLAB)

## Input

The user may provide a matlabroot path or a release name, and optionally a platform. Resolve the matlabroot as follows:

- **Path provided** (e.g. `C:\Program Files\MATLAB\R2025a`, `/usr/local/MATLAB/R2025a`, `/Applications/MATLAB_R2025a.app`): use it as-is. Infer the platform from the path format (backslash / drive letter -> Windows; `/Applications/MATLAB_` prefix -> macOS; other Unix path -> Linux).
- **Release name provided** (e.g. `R2025a`, or shorthand like `25a`): expand shorthand to full form (`25a` -> `R2025a`, `26a` -> `R2026a`, etc.) and construct the default path for the detected or specified platform:
  - **Windows:** `C:\Program Files\MATLAB\<release>`
  - **Linux:** `/usr/local/MATLAB/<release>`
  - **macOS:** `/Applications/MATLAB_<release>.app`
- **Nothing provided**: ask the user for the release name and, if ambiguous, the platform before proceeding.

If the platform cannot be inferred from the path, assume Windows.

## Protocol

> **Important:** Execute all steps below silently. Do not narrate, describe, or show progress to the user. Output only the final formatted result from Step 6.

### Step 1 -- Extract release name

Take the last component of the matlabroot path as the release name. Strip any trailing `.app` suffix for macOS paths.

Examples:
- `C:\Program Files\MATLAB\R2025a` -> release = `R2025a`
- `/usr/local/MATLAB/R2025a` -> release = `R2025a`
- `/Applications/MATLAB_R2025a.app` -> release = `R2025a`

**Fallback:** If the last path component does not match `R20\d{2}[ab]` (e.g. custom installs like `L:\prod25b`), read `{matlabroot}/VersionInfo.xml` and extract the release from the `<release>` element. If that file is missing, ask the user for the release name.

### Step 2 -- Read installed products from matlabroot

Read the file (use forward slashes on Linux/macOS, backslashes on Windows):
```
{matlabroot}/appdata/prodcontents.json
```

This is a single-line JSON object. Parse it as JSON and extract the **keys** — these are the installed product names (e.g. `"MATLAB 25.1 win64"`, `"MATLAB 25.1 glnxa64"`, `"MATLAB 25.1 maca64"`). The values (XML paths) are not needed.

### Step 3 -- Read installed support packages

Derive the support package root based on platform:

- **Windows:** `C:\ProgramData\MATLAB\SupportPackages\{release}`
- **Linux:** `/usr/local/MATLAB/SupportPackages/{release}`
- **macOS:** `~/Library/Application Support/MathWorks/MATLAB/SupportPackages/{release}`

Read the file:
```
{supportpkgroot}/appdata/prodcontents.json
```

If the file does not exist, note that no support packages are installed and skip this section.

### Step 4 -- Clean up product names

Each key in `prodcontents.json` looks like `"MATLAB 25.1 win64"` or `"MATLAB Support Package for USB Webcams 25.1.0 win64"`.

Strip the trailing version number and platform token to get a clean display name:
- Remove the version suffix: one or two numeric segments followed by an optional third (e.g. `25.1`, `25.1.0`, `25.2`)
- Remove the platform token: `win64`, `glnxa64`, `maci64`, `maca64`, or `common`
- Trim any trailing whitespace

Examples:
| Raw key | Display name |
|---|---|
| `MATLAB 25.1 win64` | `MATLAB` |
| `Simulink 25.1 win64` | `Simulink` |
| `Datafeed Toolbox 25.1 win64` | `Datafeed Toolbox` |
| `Motor Control Blockset 25.1 win64` | `Motor Control Blockset` |
| `MATLAB Documentation 25.1.0 win64` | `MATLAB Documentation` |
| `MATLAB Support Package for USB Webcams 25.1.0 win64` | `MATLAB Support Package for USB Webcams` |

### Step 5 -- Sort products

Sort the cleaned product names using **MATLABabetical order**:

1. `MATLAB`
2. `MATLAB Copilot`
3. `Simulink`
4. `Simulink Copilot`
5. All remaining products in standard alphabetical order

Any of the four anchor products that are not installed are simply omitted. Products not in the anchor list are sorted alphabetically after them.

Sort support packages in standard alphabetical order.

### Step 6 -- Display results

Show the release name as a heading, the installation folder, then two separate tables.

Use this exact format:

---

## {Release Name}

**Installed at:** `{matlabroot}`
**Support packages at:** `{supportpkgroot}`

### Products

| **Installed Products** |
|---|
| MATLAB |
| Simulink |
| ... |

### Support Packages

| **Installed Support Packages** |
|---|
| MATLAB Support Package for USB Webcams |
| ... |

---

If no support packages are installed, show the heading and a single line: `No support packages installed.`

## Key Functions and Patterns

| Pattern | Purpose |
|---|---|
| `{matlabroot}/appdata/prodcontents.json` | JSON file listing installed products (keys = product names) |
| `{supportpkgroot}/appdata/prodcontents.json` | JSON file listing installed support packages |
| MATLABabetical sort | MATLAB, MATLAB Copilot, Simulink, Simulink Copilot first, then alphabetical |
| Version/platform stripping | Remove trailing `25.1 win64` etc. from raw keys |

----

Copyright 2026 The MathWorks, Inc.

----

