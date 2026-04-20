---
name: matlab-debugging
description: Diagnose MATLAB errors and unexpected behavior. Breakpoints, workspace inspection, try-catch diagnostics, and common error patterns. Use when debugging functions, tracing errors, inspecting variables, or diagnosing runtime failures.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "2.0"
---

# Investigating and Debugging MATLAB Code with MCP Tools

You have access to a live MATLAB session via MCP tools. Use them to actively
investigate code — whether debugging errors, understanding behavior, or answering
questions about how MATLAB code works. Don't just guess from code alone.

## When to Use

- User encounters a MATLAB error message or unexpected result
- User wants to set breakpoints or inspect variable state
- Tracing why a function produces wrong output
- NaN/Inf values appearing unexpectedly
- A MATLAB MCP tool returns an error or exception — including runtime errors, syntax errors, undefined function/variable errors, or failed test results
- User asks "why is my MATLAB code not working", "help me debug", or shares a MATLAB stack trace

## When NOT to Use

- Code quality review without a runtime problem — use `matlab-reviewing-code` instead
- Performance profiling — use performance optimization workflows
- Writing tests for correctness — use `matlab-testing` instead
- Understanding MATLAB APIs or language features without a specific bug

## Static Analysis vs Runtime Debugging

Not every issue needs the live MATLAB session. Choose the right approach:

- **Static analysis is enough** when: syntax errors, unused variables, obvious
  logic mistakes, or issues visible from reading the source code alone. Use the
  `Read` tool and `check_matlab_code`.
- **Runtime debugging is needed** when:
  - The error depends on actual data values, types, or dimensions
  - The output is wrong but the code looks correct
  - The user says "it doesn't work" but the code looks fine — check actual data
  - You need to know what variables contain at a specific point in execution

When in doubt, start with static analysis. Escalate to runtime debugging when
you can't determine the root cause from source alone.

## Auto-Trigger on MATLAB Errors

When a MATLAB MCP tool returns an error (runtime error, syntax error, undefined
function/variable, dimension mismatch, failed assertion, etc.), **do not silently
move on or guess at a fix**. Instead:

1. **Recognize the error** — Look for patterns like `Error using ...`,
   `Undefined function or variable`, `Index exceeds ...`, `Error in ...`,
   MATLAB stack traces, or failed test results in MCP tool output.
2. **Ask the user for permission** — Before launching into investigation, offer:
   > "I noticed a MATLAB error: `<brief error summary>`. I can use the
   > matlab-debugging skill to dig into this — inspect variables, trace the
   > call stack, and identify the root cause. Want me to investigate?"
3. **Proceed only after confirmation** — Once the user agrees, follow the
   investigation workflow below.

This applies whether the error came from the user running code, or from you
running code on the user's behalf (e.g., verifying a fix, running tests).

## Available Tools

| Tool | Use For |
|------|---------|
| `mcp__matlab__run_matlab_file` | **Run .m scripts** — prefer this for executing user scripts and verifying fixes |
| `mcp__matlab__evaluate_matlab_code` | Quick diagnostics: inspect variables, evaluate expressions, test small snippets |
| `mcp__matlab__check_matlab_code` | Static analysis of .m files (warnings, unused vars, potential issues) |
| `mcp__matlab__run_matlab_test_file` | Run a MATLAB test file |
| `mcp__matlab__detect_matlab_toolboxes` | List installed toolboxes — use when "Undefined function" may be a missing toolbox |

**Prefer `run_matlab_file` over `evaluate_matlab_code` for running scripts.** Only
use `evaluate_matlab_code` for short diagnostic commands (checking a variable,
testing an expression, etc.) — not for re-running entire scripts inline.

## Workflow

### 1. Understand the Goal

Determine what the user needs:
- **Debugging** — runtime error, wrong output, unexpected behavior
- **Understanding** — how does this code work, what does this function do
- **Investigating** — why does this variable have this value, where does this data come from
- **Exploring** — what functions are available, how is this codebase structured

### 2. Gather Information via MATLAB

Use `mcp__matlab__evaluate_matlab_code` to run diagnostic commands.

**Read source code:** Use the `Read` tool for .m files on disk — not MATLAB's
`type` or `dbtype`. Only use MATLAB's `which` to locate files you haven't
found yet, and `which -all` to check for shadowing.

**Preview large data:** Use `varName(1:min(5,end),:)` or `head(T)` to preview
slices instead of dumping entire variables.

**Runtime debugging — check desktop mode first:**

Before using breakpoints, check if MATLAB has a desktop:
```matlab
desktop('-inuse')  % true = desktop mode, false = no-desktop
```

**Desktop mode (`desktop('-inuse')` returns `true`):**

Use the full breakpoint workflow:

1. **Set a breakpoint before running:**
   ```matlab
   dbstop if error          % Pause on any error
   dbstop if caught error   % Pause on error inside try-catch (silent failures)
   dbstop if warning        % Pause when a warning is issued
   dbstop if naninf         % Pause on NaN or Inf
   dbstop in file at line   % Pause at a specific line
   ```
2. **Run the code** via `run_matlab_file` — MATLAB pauses at the breakpoint.
3. **Inspect the call stack:**
   ```matlab
   dbstack                  % See full call stack with file names and line numbers
   ```
4. **`whos` to see what's in scope** — check variable names, sizes, and types
   before inspecting any values. For large arrays/tables, preview a slice
   (`varName(1:5,:)`, `head(T)`) instead of displaying the whole thing.
5. **Navigate frames and inspect variables in each scope:**
   ```matlab
   dbup                     % Move up one frame (toward caller)
   dbdown                   % Move back down (toward callee)
   ```
   After `dbup`/`dbdown`, variable inspection commands operate in that
   frame's local scope — use this to check inputs/outputs at each level.
6. **Resume or exit:**
   ```matlab
   dbcont                   % Continue execution to next breakpoint or end
   dbquit                   % Exit debug mode entirely
   dbclear all              % Remove all breakpoints when done
   ```

**Note:** Interactive stepping (`dbstep`) is unreliable via MCP — each
`evaluate_matlab_code` call is a separate command, so step state may not
persist.

**No-desktop mode (`desktop('-inuse')` returns `false`):**

**Do NOT use `dbstop if error`, `dbstop if naninf`, `dbstop if warning`, or
any breakpoint that pauses execution.** In no-desktop mode, pausing breakpoints
cause the MCP eval to hang indefinitely.

Use these strategies instead:

1. **try-catch wrappers** — Wrap suspect code to capture the error and
   inspect state after failure:
   ```matlab
   try
       result = suspectFunction(data);
   catch ME
       fprintf('Error: %s\n', ME.message);
       fprintf('In: %s line %d\n', ME.stack(1).name, ME.stack(1).line);
       whos  % Show variables in scope at failure
   end
   ```

2. **Tracer conditional breakpoints** — Use `dbstop` with a condition
   that always returns `false` so MATLAB never actually pauses, but prints
   the value as a side effect. Define a tracer function:
   ```matlab
   function out = tracer(val)
       disp(val);
       out = false;
   end
   ```
   Then set a conditional breakpoint that calls it:
   ```matlab
   dbstop in myScript at 42 if tracer(myVar)
   ```
   When line 42 executes, MATLAB evaluates `tracer(myVar)`, which prints
   the value and returns `false` — execution continues without pausing.
   This probes variables at specific lines without modifying the source file.
   Remove tracer breakpoints when done: `dbclear all`

3. **Run then inspect** — For scripts, run via `run_matlab_file`, then use
   `evaluate_matlab_code` to inspect workspace variables after execution.
   The base workspace persists across MCP calls within a session.

### 3. Investigate Iteratively

This is the core of debugging — use your judgment:

- **Read the relevant source code** to understand intent
- **Inspect variables** that appear on or near the failing line
- **Evaluate sub-expressions** to isolate which part fails
- **Test hypotheses** by running small snippets in MATLAB
- **Be selective** — don't dump the entire workspace. Only inspect what is relevant
  to the problem. If there are 7 variables in scope but only 2 are used on the
  failing line, inspect those 2.

When the error occurs inside a MathWorks built-in function, the bug is almost
always in the **user's code that called it**. Walk up the stack to user code.

### 4. Question the Diagnosis

The user's description of the problem may not match the actual problem. Before
fixing what they say is broken, verify it yourself:

- **Test the claimed failure directly** — If the user says `ismember` or `strcmp`
  doesn't work, run it yourself with their actual data. Often the operation works
  fine and the real issue is the logic around it.
- **Check data before blaming code** — When operations on data "don't work,"
  inspect the data: types (`class`), actual values (sample a few), whitespace
  (`strtrim`), hidden characters (`double(str)`), and dimensions (`size`).
- **Verify what the code does vs what the user describes** — Read the code and
  confirm which variables and columns are actually being used. The user may
  describe their intent but the code may do something different.
- **Consider whether the approach itself is wrong** — Sometimes the code has no
  bug per se, but the approach is unnecessarily complex or fragile. Suggest
  idiomatic MATLAB alternatives: table joins instead of manual loops, vectorized
  operations instead of element-wise comparisons, built-in functions instead of
  hand-rolled logic.


## Common Errors — What to Check First

| Error Pattern | Diagnostic Steps |
|---------------|-----------------|
| `Undefined function or variable 'X'` | `which X`, `exist('X','file')`, `exist('X','var')`, check `path`, use `detect_matlab_toolboxes` to verify toolbox is installed |
| `Index exceeds array dimensions` / `Index exceeds the number of array elements` | `size(arr)` and inspect the index expression — often off-by-one or empty array |
| `Not enough input arguments` | Check how the function is called at the call site, `nargin` inside the function, compare with function signature |
| `Too many input arguments` | Same as above — caller passing extra args, or calling a script as if it were a function |
| `Matrix dimensions must agree` / `Dimension mismatch` | `size(A)`, `size(B)` for both operands — often one is row and the other column |
| `Subscript indices must either be real positive integers or logicals` | Check index variable: `class(idx)`, `min(idx)`, look for 0 or negative values, NaN, or floating-point indices |
| `Dot indexing is not supported for variables of this type` | `class(var)` — usually accessing a struct field on a non-struct (cell, array, table) |
| `Unable to perform assignment` | Check `class` and `size` of both sides of the assignment |
| `Out of memory` | `whos` to find large variables, check for accidental array growth in loops |
| `Maximum recursion limit` | Check for missing base case or infinite mutual recursion — `dbstack` at error point |
| NaN propagation / wrong branch taken | In desktop mode, use `dbstop if naninf` to catch where NaN is first created. In no-desktop mode, use `dbstop in file at line if tracer(suspect)` to probe values without pausing. NaN comparisons (`>`, `<`, `==`) are always `false`, so `if` takes the wrong branch silently. Trace upstream: check for `0/0`, `Inf-Inf`, or NaN in input data. Use `any(isnan(var))` to test. |

## Gotchas

- **Pausing breakpoints hang in no-desktop mode.** When `desktop('-inuse')`
  returns `false`, `dbstop if error`, `dbstop if naninf`, `dbstop if warning`,
  and unconditional line breakpoints cause MCP eval to hang indefinitely. Always
  check desktop mode first. In no-desktop mode, use tracer conditional
  breakpoints or try-catch wrappers instead (see no-desktop strategies above).
- **`dbstep` does not work reliably via MCP.** Each `evaluate_matlab_code` call
  is a separate command, so step state may not persist between calls. Use
  breakpoints (`dbstop in file at line`) to pause at specific locations instead
  of trying to step through code. For tracing execution flow, insert temporary
  `fprintf()` statements or use try-catch blocks.
- **Do not use `type` or `dbtype` to read source code.** Use the `Read` tool
  instead — it's faster and doesn't consume MATLAB session output bandwidth.
  Only use `which` to locate files you haven't found yet.
- **Always `dbclear all` when done debugging.** Leftover breakpoints from a
  previous session will cause unexpected pauses in later runs.
- **`dbup`/`dbdown` scope is per-call.** Each `evaluate_matlab_code` invocation
  resets to the current frame. Chain `dbup` with variable inspection in the
  same `evaluate_matlab_code` call:
  ```matlab
  dbup; whos; myVar(1:min(5,end),:)
  ```
  A separate `evaluate_matlab_code` call after `dbup` will be back in the
  original frame.
- **Never run `restoredefaultpath`.** It removes the MCP server's own packages
  from the MATLAB path, breaking the eval channel (`mcpEval` not found). If this
  happens, the only recovery is to restart MATLAB entirely.
- **No toolboxes required.** This skill uses only base MATLAB debugging commands.

## Key Principles

- **Use the tools** — You have a live MATLAB session. Run commands, inspect
  state, test hypotheses. Don't debug from code reading alone.
- **Be selective** — Request only what's relevant. Don't dump all variables or
  read every file in the stack.
- **Check size before fetching data** — Always know the dimensions before
  displaying a variable. Never blindly `disp` an unknown variable.
- **Focus on user code** — Errors surfacing in built-in functions are almost
  always caused by bad inputs from user code.
- **Read before fixing** — Always read the actual source code before suggesting
  changes. Never guess what code looks like.
- **Verify fixes** — When practical, run the corrected code in MATLAB to confirm.

----

Copyright 2026 The MathWorks, Inc.

----
