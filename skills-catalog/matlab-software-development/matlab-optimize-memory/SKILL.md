---
name: matlab-optimize-memory
description: "Guides the 7-step MATLAB memory optimization workflow: baseline, profile, identify, optimize, measure, verify, report. Use when asked to reduce MATLAB memory usage, find memory bottlenecks, fix out-of-memory errors, or optimize memory-intensive code."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# MATLAB Memory Optimization Workflow

Systematic 7-step workflow for finding and fixing memory bottlenecks in MATLAB code.

## When to Use

- User gets out-of-memory errors running MATLAB code
- User wants to reduce memory usage of their MATLAB program
- User wants to process larger datasets without running out of memory
- User asks to profile or measure memory allocations

## When NOT to Use

- The bottleneck is execution speed, not memory (use `matlab-optimize-performance`)
- The memory issue is in compiled C/MEX code that can't be changed at the M-code level
- Memory usage is dominated by I/O buffers (memory-mapped files, database connections)

## The 7-Step Workflow

### Step 1: Establish Memory Baseline

Measure current memory usage before making changes.

```matlab
m0 = memory;
targetFunction(inputs);
m1 = memory;
deltaBytes = m1.MemUsedMATLAB - m0.MemUsedMATLAB;
fprintf('Memory delta: %.2f MB\n', deltaBytes / 1e6);
```

When `memory` errors (Linux/macOS), use `whos` for variable sizes or Java runtime for heap:
```matlab
info = whos('result');
fprintf('Variable size: %.2f MB\n', info.bytes / 1e6);
```

### Step 2: Profile Memory Allocations

Find where memory is being allocated.

```matlab
profile('-memory', 'on');
for iter = 1:5
    targetFunction(inputs);
end
profile off;
p = profile('info');
ft = p.FunctionTable;
[~, idx] = sort([ft.TotalMemAllocated], 'descend');
for i = 1:min(15, numel(idx))
    f = ft(idx(i));
    fprintf('%-40s %10.2f MB\n', f.FunctionName, f.TotalMemAllocated/1e6);
end
```

If `TotalMemAllocated` fields are zero, fall back to `whos` snapshots before/after each function call.

**Key things to look for:**
- Functions with high "Allocated" but low "Freed" — memory is retained
- Functions called many times with moderate allocations — total adds up
- Large gaps between Allocated and Freed — temporaries accumulating

### Step 3: Identify Optimization Opportunities

Based on profiling, identify which patterns apply. See `references/memory-patterns.md` for code examples.

| Pattern | Typical Reduction | Look For |
|---------|-------------------|----------|
| Cell collection + `vertcat` | O(N²) → O(N) | `[arr; newRow]` inside loops |
| Implicit expansion over `repmat` | Eliminates full copy | `repmat(A, [1 1 K])` for broadcasting |
| Clear variables when done | Immediate reclamation | Large arrays used only in early steps |
| Break chained expressions | 1 fewer peak temporary | `a.*b.*c./d` all alive at once |
| Reuse variables (overwrite in-place) | Avoids output allocation | Separate variables for each step |
| `max`/`min` instead of masking | Eliminates logical temporary | `x .* (x > 0)` pattern |
| `zeros(...,'like',x)` | Eliminates temporaries | `0 * x` to create zeros |
| Copy-on-write sharing | Shares backing memory | Same array assigned to multiple places |
| Dense → sparse | O(N²) → O(N·bw) | `zeros(N,N)` where N > 10000 |

### Step 4: Implement Optimizations

Apply the identified patterns. Focus only on the hotspots identified in Step 2 — do not apply patterns everywhere.

### Step 5: Measure Optimized Memory

Re-measure using the same method as Step 1:

```matlab
m0 = memory;
optimizedFunction(inputs);
m1 = memory;
deltaOpt = m1.MemUsedMATLAB - m0.MemUsedMATLAB;
reduction = 1 - deltaOpt / deltaBytes;
fprintf('Optimized: %.2f MB (%.0f%% reduction)\n', deltaOpt/1e6, reduction*100);
```

### Step 6: Verify Correctness

Every optimization must produce the same results:

```matlab
original = originalFunction(inputs);
optimized = optimizedFunction(inputs);
maxErr = max(abs(original(:) - optimized(:)));
fprintf('Max error: %.2e\n', maxErr);
assert(maxErr < 1e-10, 'Results differ!');
```

### Step 7: Report Results

Summarize the memory optimization with baseline, optimized, reduction percentage, correctness check, and patterns applied.

## Key Rules

1. **Never propose optimizations based solely on reading source code** — always measure and profile first
2. **Verify correctness** — memory optimizations must produce identical results
3. **Clear variables early** — free memory as soon as data is no longer needed
4. **Avoid growing arrays** — preallocate or use cell collection
5. **Break chains** — sequential assignment reduces peak memory vs chained expressions
6. **Watch for copies** — MATLAB copies on write; reuse variables to avoid duplicates

## Platform Notes

- **Windows:** `memory` command returns full statistics (`MemUsedMATLAB`, etc.)
- **Linux/macOS:** `memory` errors ("not supported on this platform"). Use `whos` for variable sizes, Java `Runtime.getRuntime` for heap usage, or OS-level RSS via `system('ps ...')`
- **`profile -memory`:** Works on all platforms but is undocumented since R2016a. When unavailable, use `whos` snapshots before/after function calls.

Copyright 2026 The MathWorks, Inc.
