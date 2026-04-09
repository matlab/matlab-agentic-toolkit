# Diagnostic Scripts

Two utility scripts for non-interactive debugging via MCP eval. Deploy them to the user's MATLAB path when needed.

## captureAtLines

Script: [scripts/captureAtLines.m](../scripts/captureAtLines.m)

Capture all workspace variables at specified line numbers without modifying the original source file. Creates a temporary instrumented copy, runs it, collects snapshots, and cleans up.

### Usage

```matlab
% 1. View code to pick capture points
dbtype myFunction

% 2. Capture workspace at lines 18, 19, and 22
[result, snapshots] = captureAtLines('src/myFunction.m', [18; 19; 22], arg1, arg2);

% 3. Inspect each snapshot (struct with 'line' field + all workspace variables)
snapshots{1}   % workspace after line 18
snapshots{2}   % workspace after line 19
snapshots{3}   % workspace after line 22
```

## dumpVars

Script: [scripts/dumpVars.m](../scripts/dumpVars.m)

Print variable names, sizes, classes, and values at a point in execution without pausing.

### Usage

```matlab
dumpVars('Before filter', 'signal', signal, 'fs', fs, 'order', order);
```

Output:
```
=== Before filter ===
  signal: [1000x1 double]
  fs: [1x1 double] = 44100
  order: [1x1 double] = 8
```
