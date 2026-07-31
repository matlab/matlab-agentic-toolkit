# Discovering Config Properties

Codegen config property names, defaults, and per-config availability change across MATLAB releases. Do not memorize them — query the live config object in the user's MATLAB session via `mcp__matlab__evaluate_matlab_code`.

The three config types:

- `coder.MexCodeConfig` — `coder.config('mex')`
- `coder.CodeConfig` — `coder.CodeConfig` (constructed directly; MATLAB Coder only)
- `coder.EmbeddedCodeConfig` — `coder.config('lib')`, `'dll'`, or `'exe'` when Embedded Coder is installed

`coder.config('lib')` returns `coder.EmbeddedCodeConfig` when Embedded Coder is installed and `coder.CodeConfig` otherwise. Use `class(cfg)` to confirm.

## Introspection Commands

Run these against a constructed config object to get the authoritative property list for the user's MATLAB version:

```matlab
cfg = coder.config('lib');     % or 'mex', or coder.CodeConfig

class(cfg)                     % which config class is this?
properties(cfg)                % all property names
disp(cfg)                      % all properties with current values
```

To check whether a candidate property exists on the current config type:

```matlab
isprop(cfg, 'EnableStrengthReduction')
```

For GPU configs, the GPU-specific settings live under `cfg.GpuConfig`:

```matlab
cfg = coder.gpuConfig('lib');
properties(cfg.GpuConfig)
disp(cfg.GpuConfig)
```

## Non-Obvious Behavior

These are interactions and edge cases that are not obvious from each property's individual doc page.

### `EnableVariableSizing` requires compile-time-constant dimensions

Disabling `EnableVariableSizing` requires every colon-range operand and array dimension to be compile-time constant. If the function uses `a:b` where `a` or `b` varies at runtime, either restructure (e.g., reshape into matrix + column indexing) or keep `EnableVariableSizing = true` and disable `EnableDynamicMemoryAllocation` instead — variable-size arrays then stack-allocate at their upper bound (zero heap, larger stack frames).

Compile-time constants can come from `coder.Constant` entrypoint inputs, `coder.const(expr)` calls inside the function, or variables that codegen can constant-fold from the calling context.

System objects from DSP System Toolbox and similar may internally use variable-size operations that prevent `EnableVariableSizing = false` even if the entry-point code is fixed-size.

### `IntegrityChecks = false` (MEX) is unsafe without prior verification

Before disabling, first generate and run the MEX with `IntegrityChecks = true` (the default). Exercise it with all expected runtime inputs and confirm no bounds or dimension errors are reported. Only then disable checks — without them, out-of-bounds access crashes MATLAB with no diagnostic.

### Disabling `SaturateOnIntegerOverflow` silently wraps

Without saturation, integer overflow follows C wrapping behavior. Only disable when overflow is provably impossible across all reachable inputs.

### `EnableDynamicMemoryAllocation = false` shifts cost to the stack

Worst-case array sizes land on the stack. Signal-processing and image code routinely needs `StackUsageMax` >= 512 KB; the default (typically 200000 bytes) is often too low. Codegen warns when the estimate exceeds the budget.

### `PurelyIntegerCode = true` is all-or-nothing

Codegen errors if any floating-point operation remains, including in called library functions. Verify the entire call graph is integer-only before enabling.

### `EnableOpenMP = true` thread count

`NumberOfCpuThreads = 0` uses all available cores at runtime, which is non-deterministic across machines. Set a specific count when reproducibility matters.

### Booleans are `logical`, not char

Every `Enable*` and similar boolean property takes `true` / `false`, never `'On'` / `'Off'`. Use `class(cfg.PropName)` if unsure.

----

Copyright 2026 The MathWorks, Inc.

----
