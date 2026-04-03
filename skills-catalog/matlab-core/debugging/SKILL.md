---
name: debugging
description: Diagnose MATLAB errors and unexpected behavior via MCP eval. Programmatic breakpoints (dbstop/dbclear), error traps, diagnostic instrumentation, workspace inspection, and common error patterns. Use when debugging functions, tracing errors, inspecting variables, setting breakpoints, or diagnosing runtime failures.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Debugging

Diagnose MATLAB errors and unexpected behavior by combining MCP-based execution with diagnostic instrumentation and structured error analysis.

## When to Use

- User encounters an error message or unexpected result
- User wants to set breakpoints or step through code
- User needs to inspect variable state at a specific point in execution
- Tracing why a function produces wrong output
- NaN/Inf values appearing unexpectedly

## When NOT to Use

- Code quality review without a runtime problem — use `reviewing-code` instead
- Performance profiling — use performance optimization skills
- Writing tests for correctness — use `testing` instead

## Critical: Agent vs. User Debugging

**NEVER use `dbstop` line breakpoints when you (the agent) need to see results.** Line breakpoints pause MATLAB in the desktop and block the MCP eval channel — your eval call will hang indefinitely until the user manually continues in MATLAB.

**Default to diagnostic instrumentation** (`fprintf`, `try/catch`, `captureAtLines`). This lets you run code, see output, and iterate — all through MCP eval.

**Only set `dbstop` line breakpoints when the user explicitly asks to debug interactively in the MATLAB desktop.** In that case, set the breakpoints and tell the user to run the command themselves. Do NOT attempt to run the code via eval after setting breakpoints.

| You need to...                          | Use                              |
|-----------------------------------------|----------------------------------|
| See variable values at a line           | `captureAtLines` or `fprintf`    |
| Find where an error occurs              | `try/catch` with stack trace     |
| Trace execution flow                    | `fprintf` breadcrumbs            |
| Let the user step through interactively | `dbstop` + user runs in desktop  |

## MCP Debugging Model

All debugging commands run through `evaluate_matlab_code`:

- **Setup commands** (`dbstop`, `dbclear`, `dbstatus`, `dbtype`) execute and return immediately
- **Code that hits a breakpoint** pauses MATLAB in the desktop — the eval call blocks until the user continues
- **Agent-driven debugging MUST use diagnostic instrumentation**, not breakpoints

| Scenario | Approach | Runs via eval? |
|----------|----------|---------------|
| Inspect variables at a line | `captureAtLines` or `fprintf` diagnostics | Yes |
| Find where an error occurs | `try/catch` with stack trace dump | Yes |
| Trace execution flow | `fprintf` breadcrumbs | Yes |
| Wrong results | Assertions + diagnostic output | Yes |
| NaN/Inf appearing | `fprintf` checks or `dbstop if naninf` | Yes / No (user) |
| User wants to step through | `dbstop` line breakpoints | No — user runs in desktop |

## Workflow

1. **Get the error** — Read the error message and full stack trace
2. **View the code** — `dbtype` to see code with line numbers
3. **Analyze statically** — Run `check_matlab_code` for obvious issues
4. **Instrument and run** — Add diagnostic output (`fprintf`, `captureAtLines`), run via eval, analyze results. This is the default for all agent-driven debugging.
5. **Iterate** — Refine diagnostics based on what you learn, re-run
6. **Identify root cause** — Propose a fix based on diagnostic output
7. **Clean up** — Remove any diagnostic instrumentation

Only fall back to breakpoints (step 4 alt) if the user explicitly requests interactive desktop debugging.

## Key Functions

| Category | Functions |
|----------|-----------|
| Breakpoints | `dbstop`, `dbclear`, `dbstatus` |
| Navigation | `dbstep`, `dbcont`, `dbquit`, `dbup`, `dbdown` |
| Inspection | `dbstack`, `dbtype`, `whos`, `disp` |
| Error traps | `dbstop if error`, `dbstop if warning`, `dbstop if naninf` |

## Patterns

### View Code with Line Numbers

Always start here — you need line numbers to target diagnostics:

```matlab
dbtype myFunction
dbtype myFunction 15:30
```

### Capture Variables at a Line (Agent-Driven)

Deploy [scripts/captureAtLines.m](scripts/captureAtLines.m) to the user's project or `tempdir` to inspect workspace at specific lines without modifying the original source:

```matlab
% 1. View code to pick capture points
dbtype myFunction

% 2. Capture workspace at lines 16 and 17
[result, snapshots] = captureAtLines('src/myFunction.m', [16; 17], arg1, arg2);

% 3. Inspect each snapshot (struct with 'line' field + all workspace variables)
snapshots{1}   % workspace after line 16
snapshots{2}   % workspace after line 17
```

See [reference/diagnostic-scripts-guidance.md](reference/diagnostic-scripts-guidance.md) for full usage details.

### Inline Diagnostics (Agent-Driven)

When the agent needs to see results through MCP eval, add diagnostic output instead of breakpoints:

```matlab
fprintf('[DEBUG] size(data) = [%s]\n', num2str(size(data)));
fprintf('[DEBUG] class(data) = %s\n', class(data));
fprintf('[DEBUG] range: [%.4g, %.4g]\n', min(data(:)), max(data(:)));
fprintf('[DEBUG] NaN count: %d, Inf count: %d\n', ...
    sum(isnan(data(:))), sum(isinf(data(:))));
```

Deploy [scripts/dumpVars.m](scripts/dumpVars.m) for a reusable helper:

```matlab
dumpVars('Before filter', 'signal', signal, 'fs', fs, 'order', order);
```

### Try/Catch with Full Diagnostics (Agent-Driven)

Wrap suspicious code to capture detailed error context:

```matlab
try
    result = myFunction(inputData);
    fprintf('[OK] myFunction returned %s of size [%s]\n', ...
        class(result), num2str(size(result)));
catch ME
    fprintf('Error: %s\n', ME.message);
    fprintf('Identifier: %s\n', ME.identifier);
    for k = 1:numel(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    if ~isempty(ME.cause)
        for j = 1:numel(ME.cause)
            fprintf('Caused by: %s\n', ME.cause{j}.message);
        end
    end
end
```

### Trace Execution Flow (Agent-Driven)

Add breadcrumbs to understand which code paths execute:

```matlab
fprintf('[TRACE] Entering %s\n', mfilename);

if useMethod1
    fprintf('[TRACE] Taking method1 branch\n');
else
    fprintf('[TRACE] Taking method2 branch\n');
end

% Sample in loops to avoid flooding
for k = 1:N
    if mod(k, 100) == 0
        fprintf('[TRACE] Iteration %d/%d\n', k, N);
    end
end
```

### Performance Profiling (Agent-Driven)

When the bug is "it's too slow" rather than "it's wrong":

```matlab
profile on
result = myFunction(data);
profInfo = profile('info');
profile off

[~, idx] = sort([profInfo.FunctionTable.TotalTime], 'descend');
for k = 1:min(5, numel(idx))
    ft = profInfo.FunctionTable(idx(k));
    fprintf('%s: %.3f s (%d calls)\n', ft.FunctionName, ...
        ft.TotalTime, ft.NumCalls);
end
```

---

### Interactive Breakpoints (User-Driven — Fallback Only)

> **Use only when the user explicitly requests interactive debugging.**
> After setting breakpoints, tell the user to run the command in the
> MATLAB Command Window. Do NOT run the code via eval.

#### Line Breakpoints

Set breakpoints via eval, then instruct the user to run in MATLAB desktop:

```matlab
dbstop in myFunction at 15
dbstop in myFunction at 28
dbstatus myFunction
```

Tell the user:
1. Run `result = myFunction(args)` in the MATLAB Command Window
2. At each breakpoint, inspect: `whos`, `size(data)`, `min(data)`, `max(data)`
3. Use `dbstep` to advance, `dbcont` to continue, `dbquit` to exit
4. After debugging: `dbclear all`

#### Conditional Breakpoints

Break only when a condition is met — essential for debugging loops:

```matlab
dbstop in myFunction at 22 if k == 50
dbstop in myFunction at 35 if temperature > 100
dbstop in myFunction at 18 if any(isnan(result))
```

#### Error and Warning Traps

Stop MATLAB at the exact moment an error or warning occurs:

```matlab
dbstop if error
dbstop if error MATLAB:singularMatrix
dbstop if warning
dbstop if naninf
```

#### Manage Breakpoints

```matlab
dbstatus                    % list all breakpoints
savedBP = dbstatus;         % save for restoration
dbclear all                 % clear everywhere
dbstop(savedBP);            % restore saved
```

## Common Error Patterns

| Error | Likely cause | Diagnostic |
|-------|-------------|-----------|
| `Index exceeds array dimensions` | Off-by-one, empty array, wrong size | `fprintf('size: [%s]', num2str(size(x)))` before the failing line |
| `Undefined function 'foo'` | Missing toolbox, not on path, typo | `which foo`, `ver` to check toolbox |
| `Matrix dimensions must agree` | Mismatched sizes in operation | Print `size()` of both operands |
| `Not enough input arguments` | Calling with wrong arg count | `dbtype` the function signature |
| `Subscript indices must be real positive integers` | Zero or negative index, logical vs numeric confusion | Print the index value and class |
| `Out of memory` | Array too large | `whos` to check workspace, `memory` for available RAM |

## Conventions

- **Default to instrumentation, not breakpoints.** Breakpoints block MCP eval. Only use `dbstop` for line breakpoints when the user explicitly requests interactive desktop debugging.
- Always use `dbtype` to view code with line numbers before targeting diagnostics
- Use `dbstatus` to verify breakpoints after setting them
- Always clean up with `dbclear all` when debugging is complete
- Prefer `dbstop if error` as the first step — it catches the exact failure point
- Use `[DEBUG]` or `[TRACE]` prefixes to distinguish diagnostic output from normal output
- Never leave `keyboard` statements in production code
- Sample diagnostic output in loops (every Nth iteration) to avoid flooding
- When modifying user files for diagnostics, clearly mark additions for later removal
