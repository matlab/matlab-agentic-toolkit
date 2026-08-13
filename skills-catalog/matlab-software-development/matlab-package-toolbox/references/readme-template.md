# README.md Template

**Location:** Project root (NOT inside `toolbox/` — the README is for developers/GitHub, not end users)

## Structure

```markdown
# Toolbox Name

[![MATLAB](https://img.shields.io/badge/MATLAB-R20XXx+-blue.svg)]()

Short, user-focused summary of what the toolbox does (2-3 sentences).

## Installation

### From File Exchange
Search for "Toolbox Name" in MATLAB's Add-On Explorer, or download the `.mltbx` from [File Exchange](link).

### From Source
1. Clone this repository
2. Open `<toolboxname>.prj` in MATLAB
3. Run `buildtool` to build and test

## Getting Started

Open `toolbox/doc/GettingStarted.m` for an interactive introduction, or run:

```matlab
open GettingStarted
```

## Functions

| Function | Description |
|----------|-------------|
| `functionName` | H1 description |
| `pkg.functionName` | H1 description |

## Examples

See the `toolbox/examples/` folder for Live Script examples:
- `example1.m` — Description
- `example2.m` — Description

## License

See [license.txt](license.txt).

---

## For Contributors

[Development setup, build instructions, test instructions]
```

## Key conventions

- User-focused summary above the fold
- Point to `GettingStarted.m` (the interactive guide for installed users)
- Function table from Contents.m or H1 lines
- Contributor section BELOW the fold (after the `---` separator)
- Store images in `images/` folder to reduce clutter

----

Copyright 2026 The MathWorks, Inc.

----
