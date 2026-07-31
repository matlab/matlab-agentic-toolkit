---
name: matlab-export-session-script
description: "Export conversation MATLAB code to a clean, runnable .m script. Use when asked to save or export session work. TRIGGER: user asks to save, export, or generate a script from the current session's MATLAB code. Also when asked for a reproducible script or clean version of what was run."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Exporting a Session to a MATLAB Script

Extracts all MATLAB code executed during the current conversation, assembles it into a well-documented, runnable `.m` script, and saves it to the working directory.

## Quick Reference

| Step | Action |
|------|--------|
| 1. Scan | Walk assistant messages chronologically; extract each executed MATLAB code block |
| 2. Deduplicate | Keep only the final successful version of repeated blocks |
| 3. Order | Arrange into logical workflow order (setup, model, config, analysis, visualization) |
| 4. Format | Add `%%` section headers, consolidate parameters at top |
| 5. Save | Write to `Results/<descriptive_name>.m` under the working directory |

## When to Use

- User says "export this session as a script"
- User says "create a script from what we did"
- User says "save the MATLAB code from this conversation"
- At the end of any MATLAB workflow session when deliverables are requested

## When NOT to Use

- Writing new MATLAB code from scratch — just write the code directly
- Exporting non-MATLAB content (Python, shell scripts, etc.)
- Creating Live Scripts (.mlx) — this skill produces plain .m files only

## Extraction Rules

### Include

- All MATLAB code that produced meaningful results (analysis, design, visualization)
- Variable assignments, function calls, plotting commands
- `addpath` calls needed for utility functions used during the session

### Exclude

- Shell commands: PowerShell, Bash, OS commands, `sbm` wrappers
- MCP tool call metadata and framework boilerplate
- Exploratory one-liners that were debugging dead ends
- Agent-only `fprintf` statements used to relay info back (keep user-facing ones)
- `'Visible','off'` on figures -- the exported script is for interactive use

### Deduplicate

When the same block was run multiple times (e.g., to fix an error), keep only the **final successful version**. Do not include intermediate failed attempts or parameter corrections -- use the values that worked.

## Script Assembly

### 1. Scan the Conversation

Walk through all assistant messages chronologically. For each MATLAB code block that was executed (via MCP, `-batch`, or similar), extract the MATLAB portion and note:
- What it accomplished (this becomes the section comment)
- Whether it succeeded or was superseded by a later version
- Its logical position in the workflow

### 2. Order Logically

Arrange extracted code into a natural workflow order, which may differ from execution order:
1. Setup (paths, parameters, imports)
2. Data loading / model creation
3. Configuration
4. Analysis / computation
5. Visualization / results

### 3. Format as Sections

```matlab
%% <Title> -- <One-line summary>
% <Multi-line description of what this script does.>
% <Key context: what design, what board, what analysis, etc.>
%
% Required toolboxes: <list only what was actually used>

%% Step 1: <Description>
% <Why this step matters>
<code>

%% Step 2: <Description>
<code>
```

### Formatting Conventions

- **`%%` section breaks** for each logical step (creates foldable sections in MATLAB Editor)
- **One comment line** before each section explaining intent
- **Consolidate parameters** into the setup section rather than scattering through the script
- **Preserve variable names** exactly as used in the session
- **Escape underscores** in `title()` / `xlabel()` TeX strings: `\_` not `_`

## Output

### File Naming

Derive from the session's primary task. Use lowercase with underscores:
- `openrex_core_rail_dc_analysis.m`
- `hairpin_filter_design_2p4ghz.m`
- `via_crosstalk_sweep.m`

### File Location

Save to `Results/` under the working directory. Create the folder if it doesn't exist.

### After Saving

Tell the user:
- The file name and path
- How many sections / lines the script contains
- That it is ready to run in MATLAB with the required toolboxes

## Common Patterns

- **One script per session** -- consolidate all related work into a single script, even if it spans multiple design iterations. Multiple scripts are only warranted for unrelated workflows in the same session.
- **Parameters at the top** -- gather all user-configurable values (`freq`, `substrate`, dimensions) into the setup section so the user can modify them without hunting through the script.
- **Suppress figures in batch** -- if the script may be run non-interactively, wrap plotting in `if ~exist('BATCH_MODE', 'var')` guards. But default to showing figures for interactive use.
- **Path management** -- if the script uses files (Touchstone, board files), place file paths in variables at the top of the setup section. Use `fullfile()` for cross-platform paths. Never hard-code absolute paths.
- **Batch mode header** -- for scripts that may be run via `matlab -batch`, add at the top:
  ```matlab
  %% Configuration
  BATCH_MODE = exist('BATCH_MODE', 'var') || ~usejava('desktop');
  if ~BATCH_MODE, close all; clc; end
  ```
- **Results directory** -- save outputs to a `Results/` subfolder:
  ```matlab
  resultsDir = fullfile(pwd, 'Results');
  if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end
  ```

## Pitfalls

1. **Do not include shell commands.** Only MATLAB code belongs in the exported script. PowerShell, Bash, and `sbm` wrapper invocations must be stripped. If a shell step is essential (e.g., downloading a file), replace it with a comment noting the prerequisite.

2. **Do not keep failed iterations.** When a code block was re-run after fixing an error, only the final successful version should appear. Including intermediate failures makes the script unrunnable.

3. **Do not scatter parameters.** Hard-coded values buried inside analysis or plotting sections are difficult to find and modify. Always hoist user-configurable parameters (`freq`, `substrate`, dimensions, file paths) into the setup section at the top.

4. **Do not hard-code absolute paths.** Paths like `C:\Users\viyer\...` break on other machines. Use `fullfile()` and relative paths, or place path variables in the setup section.

5. **Do not leave `'Visible','off'` on figures.** Agent sessions suppress figure windows for non-interactive execution, but exported scripts are meant for interactive use. Remove `'Visible','off'` arguments from `figure()` calls.

6. **Escape underscores in TeX strings.** MATLAB interprets `_` as a subscript in `title()`, `xlabel()`, `ylabel()`, and `legend()` calls by default. Use `\_` or set `'Interpreter','none'`.

----

Copyright 2026 The MathWorks, Inc.
