---
name: matlab-review-fi-code
description: Reviews MATLAB fixed-point (fi) code for performance, code generation efficiency, and correctness. Identifies antipatterns and suggests idiomatic improvements. Use when reviewing fi, fimath, numerictype, or quantizenumeric code.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# fi Best Practices Review

Reviews MATLAB code for fixed-point (`fi`) best practices and suggests improvements for performance, code generation efficiency, and correctness.

## When to Use

- Reviewing MATLAB code that uses `fi`, `fimath`, `numerictype`, or `quantizenumeric`
- Optimizing fixed-point simulation speed
- Preparing fixed-point code for C or hardware code generation

## When Not to Use

- Code using only built-in integer types (`int8`, `uint16`, etc.) without `fi`
- Pure floating-point algorithms with no fixed-point intent
- Simulink-only workflows where fixed-point is configured through block dialogs (use Fixed-Point Tool instead)

## Checklist

When reviewing code, check for ALL of the following:

### 1. Vectorize fi() Calls

**Problem**: Scalar `fi()` in a loop is slow due to per-element object construction overhead.

**Fix**: Pass entire arrays to `fi()` at once.

```matlab
% BAD — slow: per-element fi object construction
for k = 1:N
    x_fi(k) = fi(x(k), 1, 18, 16, F);
end

% GOOD — fast: single vectorized call, bit-true identical result
x_fi = fi(x, 1, 18, 16, F);
```

### 2. Separate Data Types from Algorithm

**Problem**: Hardcoding fi types inside algorithm code makes it impossible to switch between float/fixed or compare configurations.

**Fix**: Use a types table with empty prototypes and `cast(...,'like',...)`.

```matlab
% Types table (separate function)
function T = mytypes(dt)
  switch dt
    case 'double'
      T.b = double([]);  T.x = double([]);  T.y = double([]);
    case 'single'
      T.b = single([]);  T.x = single([]);  T.y = single([]);
    case 'fixed16'
      F = fimath('RoundingMethod','Floor','OverflowAction','Wrap', ...
                 'ProductMode','KeepLSB','ProductWordLength',32, ...
                 'SumMode','KeepLSB','SumWordLength',32);
      T.b = fi([], 1, 16, 15, F);
      T.x = fi([], 1, 16, 15, F);
      T.y = fi([], 1, 16, 14, F);
  end
end

% Algorithm — no hardcoded types
function [y,z] = myfilter(b, x, z, T)
  y = zeros(size(x), 'like', T.y);
  for n = 1:length(x)
    z(:) = [x(n); z(1:end-1)];
    y(n) = b * z;
  end
end

% Entrypoint — wraps types + cast + algorithm
function [y,z] = entrypoint(dt, b, x)
  T = mytypes(dt);
  b = cast(b, 'like', T.b);
  x = cast(x, 'like', T.x);
  z = zeros(size(b'), 'like', T.x);
  [y,z] = myfilter(b, x, z, T);
end
```

**Validation**: Run with `'double'` first, then `'single'` (catches single-precision issues early — important for embedded targets where double is unavailable or slow), then `'fixed16'`.

### 3. Prevent Bit Growth with Subscripted Assignment

**Problem**: `acc = acc + x(n)` overwrites `acc` with a new fi object whose type may change due to FullPrecision word growth.

**Fix**: Use `acc(:) = acc + x(n)` to retain the original data type.

```matlab
% BAD — acc type may grow each iteration
acc = fi(0, 1, 32, 16);
for n = 1:numel(x)
    acc = acc + x(n);
end

% GOOD — preserves acc's declared type
acc = fi(0, 1, 32, 16);
for n = 1:numel(x)
    acc(:) = acc + x(n);
end
```

### 4. Configure fimath for Your Target

**Problem**: Default fimath (Nearest rounding, Saturate overflow, FullPrecision) generates bloated code. A simple `a + b` can produce many lines of C with sign-extension and overflow checks.

**Fix**: Choose fimath settings based on your code generation target.

```matlab
% For C targets (MATLAB Coder) — models integer truncation behavior
F_c = fimath('RoundingMethod','Floor', 'OverflowAction','Wrap', ...
             'ProductMode','KeepLSB', 'ProductWordLength',32, ...
             'SumMode','KeepLSB', 'SumWordLength',32);

% For DSP processor targets — models shift-right behavior
F_dsp = fimath('RoundingMethod','Floor', 'OverflowAction','Wrap', ...
               'ProductMode','KeepMSB', 'ProductWordLength',32, ...
               'SumMode','KeepMSB', 'SumWordLength',32);

% For FPGA/hardware targets — use the built-in helper
% hdlfimath = Floor/Wrap/FullPrecision (hardware coder manages bit widths internally)
F_hw = hdlfimath;
x_fi = fi(x, 1, 18, 16, F_hw);
```

**Product/Sum mode selection**:

| Mode | Behavior | Use when |
|------|----------|----------|
| `KeepLSB` | Keep least significant bits (C integer truncation) | Targeting C/C++ (MATLAB Coder) |
| `KeepMSB` | Keep most significant bits (shift-right) | Targeting DSP processors |
| `FullPrecision` | Retain all bits (word growth) | Hardware coder (manages widths internally), or debugging |
| `SpecifyPrecision` | Manual word/fraction lengths | Custom precision requirements |

**Note**: `hdlfimath` returns Floor/Wrap/FullPrecision. The hardware coder manages bit widths through its own pipeline — do not use `KeepLSB` or `KeepMSB` with it unless explicitly required by your design constraints.

**Rounding efficiency** (most to least efficient for codegen):
1. `Floor` — two's complement truncation, no extra logic
2. `Zero` — truncation toward zero
3. `Nearest` — ties to +inf (default)
4. `Convergent` — ties to nearest even
5. `Round` — ties away from zero (most expensive)

**Overflow**: `Wrap` (no logic) vs `Saturate` (requires comparison).

**Slope-bias scaling**: If your fi objects use slope-bias (non-power-of-two slope or non-zero bias):
- `ProductMode` and `SumMode` must be `'SpecifyPrecision'` with `CastBeforeSum` set to `true`
- Hardware code generation and DSP System Toolbox do not support slope-bias — use binary-point for hardware targets
- Slope-bias maximizes accuracy per bit when values are bunched away from zero (e.g., sensor ranges like 273–283 K)
- Match net scaling so operations resolve to shifts; non-zero bias makes multiplication costlier, but zero-bias with non-power-of-two slope can still produce shift-only code

### 5. Preallocate fi Arrays

**Problem**: Growing fi arrays inside loops causes quadratic memory and time growth.

**Fix**: Preallocate using `zeros(...,'like',...)` with a prototype.

```matlab
T = fi([], 1, 18, 16, F);       % empty prototype
Y = zeros(N, 1, 'like', T);     % preallocated output

for k = 1:N
    Y(k) = cast(x(k), 'like', T);
end
```

### 6. Avoid Division in Fixed-Point

**Problem**: Division is expensive in fixed-point hardware and generates complex code.

**Fix**: Replace with bit shifts (power-of-2) or inverse multiplication (constants).

```matlab
% BAD
y = x / 8;
y = x / 5;

% GOOD — bit shift for power-of-2
y = bitsra(x, 3);  % x/8

% GOOD — multiply by precomputed inverse
inv5 = fi(0.2, 1, 16, 15);
y = x * inv5;      % x/5
```

### 7. Replace Expensive Functions with Lookup Tables or CORDIC

Functions like `sin`, `cos`, `sqrt`, `exp`, `log` generate inefficient code for fi inputs and may not be supported for C or hardware code generation.

**Choose replacement strategy based on your target:**

| Target | Recommended approach | Why |
|--------|---------------------|-----|
| C/C++ (MATLAB Coder) | Lookup tables via `FunctionApproximation.Problem` | Direct table indexing is fast and predictable on MCUs; no iterative overhead |
| FPGA/hardware | CORDIC | Iterative shift-add maps efficiently to hardware; no large ROM needed |
| DSP processors | Either — profile both | Depends on available memory vs. cycle budget |

**Recommended for C targets — `FunctionApproximation.Problem`** (Fixed-Point Designer, R2018a+):

```matlab
% 1. Define the problem: function, input range, input type
problem = FunctionApproximation.Problem('sin');
problem.InputTypes = numerictype(1, 16, 14);
problem.InputLowerBounds = -pi;
problem.InputUpperBounds = pi;

% 2. (Optional) Configure options
problem.Options.WordLengths = [8 16];            % allowed word lengths
problem.Options.ApproximateSolutionType = 'MATLAB'; % or 'Simulink'

% 3. Solve — finds optimal breakpoints and output type
solution = solve(problem);

% 4. Inspect — compare approximation accuracy
compare(solution);

% 5. Generate — produces a lookup table MATLAB function or Simulink block
approximate(solution, 'Name', 'mysin_lut');
```

This workflow automatically selects breakpoints, word lengths, and interpolation methods to meet accuracy requirements. It generates codegen-ready MATLAB functions or Simulink blocks.

**Recommended for FPGA/hardware targets — CORDIC** (iterative, no ROM, maps to shift-add logic):

```matlab
y = cordicsin(theta, nIterations);
y = cordiccos(theta, nIterations);
y = cordicatan2(y_in, x_in, nIterations);
```

CORDIC is best suited to FPGA/hardware targets where iterative shift-add pipelines are cheap and ROM-based lookup tables are expensive. For C code targeting embedded processors, lookup tables are generally more efficient — CORDIC's iterative loops add cycle overhead that a direct table read avoids.

**Last resort** — cast to single, compute, cast back (loses fixed-point bit-trueness but stays efficient on embedded targets):

```matlab
y = cast(sin(single(x)), 'like', T.y);
```

Do **not** cast to `double` for this purpose — `single` is sufficient for intermediate computation and is far more efficient on embedded processors (many MCUs/DSPs lack double-precision hardware, making `double` ops significantly slower).

**Detection**: Flag code that uses `sin`, `cos`, `sqrt`, `exp`, `log`, or similar transcendental functions on fi inputs, OR code that mentions using lookup tables without actually implementing them via `FunctionApproximation.Problem` or CORDIC.

### 8. Scaled Doubles for Overflow Detection (Optional, Advanced)

Scaled doubles can detect overflows by retaining floating-point range while tracking fixed-point scaling. However, they add significant complexity and have pitfalls — use them only when you have a specific overflow concern that simpler methods (comparing fixed vs. double output, checking saturation counts) cannot diagnose.

**Quick check using global override** (simplest approach):

```matlab
fipref('DataTypeOverride', 'ScaledDoubles');
y = myAlgorithm(x, T);
fipref('DataTypeOverride', 'ForceOff');
```

**Pitfalls to be aware of**:
- Global `fipref` override affects ALL fi objects in the session — can produce misleading results if other code runs concurrently
- Scaled doubles do not model wrap behavior — overflow is detected but the algorithm path may differ from actual fixed-point execution
- Adding a `'ScaledDouble'` case to the types table (duplicating every fi prototype with `'DataType','ScaledDouble'`) creates maintenance burden for limited additional insight over simply comparing double vs. fixed outputs

**When scaled doubles are worth it**: Debugging a specific overflow in a deep computation chain where you need to know *which intermediate* overflowed, not just that the final output differs from the double baseline.

**When to skip**: For most workflows, comparing `double` output to `fixed` output and inspecting the difference is simpler and sufficient. If the difference is large, increase word length or adjust scaling — no need for the scaled-double intermediate step.

### 9. fi Constructor Best Practices

**Use positional or numerictype syntax** — the name-value pair constructor is slower due to string parsing overhead.

```matlab
% SLOW — name-value pairs
x = fi(v, 'Signed', 1, 'WordLength', 16, 'FractionLength', 14);

% FAST — positional (sign, wordLength, fractionLength)
x = fi(v, 1, 16, 14);

% FAST — pre-built numerictype (best for repeated use)
T = numerictype(1, 16, 14);
x = fi(v, T);

% FAST — with fimath
x = fi(v, T, F);
```

**Additional rules**:
- `fi()` always uses Nearest/Saturate for initial quantization regardless of globalfimath.
- Non-finite values (Inf, NaN) require fully specified numerictype.
- For codegen, numerictype properties must be compile-time constants.

### 10. Use quantizenumeric for Double-Based Quantization

**Problem**: Converting to fi objects just to model quantization effects adds unnecessary overhead when your algorithm otherwise stays in double.

**Fix**: Use `quantizenumeric` — quantizes values in-place, output remains double.

```matlab
% Quantize to signed 16-bit, 13 fractional bits
y = quantizenumeric(x, 1, 16, 13);                    % nearest, saturate
y = quantizenumeric(x, 1, 16, 13, 'floor', 'wrap');   % floor + wrap

% Works on arrays — no loop needed
q_data = quantizenumeric(data, 1, 8, 6, 'floor', 'wrap');
```

**When to use `quantizenumeric` vs `fi`**:

| Use `quantizenumeric` | Use `fi` |
|-----------------------|----------|
| Algorithm stays in double | Need fi arithmetic rules (product/sum types) |
| Only injecting quantization at specific points | Need full fixed-point simulation |
| Prototyping quantization effects | Preparing for C or hardware code generation |
| Want to avoid fi object overhead | Need DataTypeOverride / instrumentation |

**Legacy alternative** — manual floor-mode quantization (fastest, but limited):

```matlab
% Only correct for floor rounding, no overflow handling
x_quantized = floor(x * 2^FL) * 2^-FL;
```

Prefer `quantizenumeric` (R2016a+) which handles all rounding/overflow modes.

### 11. Manage Floating-Point in Fixed-Point Algorithms

For efficient code generation, minimize floating-point variables in the algorithm body. However, not everything benefits from fixed-point conversion.

**Convert to fixed-point when**:
- Dynamic range is bounded and well-characterized
- The function has fi-compatible replacements
- Code generation requires it

**Leave in floating-point when**:
- Dynamic range exceeds 40 dB
- Code is sensitive to round-off errors
- No suitable fixed-point replacement exists

**Pattern**: Isolate floating-point sections with explicit casts. Prefer `single` over `double` for embedded targets (many MCUs/DSPs lack double-precision FPU):

```matlab
function y = myAlgorithm(x_fi, T)
  % Fixed-point path
  filtered = myFIRFilter(x_fi, T);

  % Isolated floating-point section (high dynamic range)
  scaled = single(filtered);
  compressed = log2(abs(scaled) + 1);

  % Back to fixed-point
  y = cast(compressed, 'like', T.y);
end
```

Loop indices are exempt — MATLAB Coder automatically converts them to integers.

### 12. Profile and Accelerate fi Code

**Common fi performance bottlenecks** (in order of typical cost):

| Source | Mitigation |
|--------|------------|
| fi object construction in loops | Vectorize (Check 1); use `cast(...,'like',proto)` |
| fimath resolution per operation | Attach local fimath to operands before loops |
| Method dispatch overhead | Use `fiaccel` for tight loops |
| Mixed local/global fimath | Standardize fimath on all operands |

**Acceleration options** (from least to most effort):

1. **Vectorize** — eliminate scalar fi loops, significantly faster
2. **`fiaccel`** — compile to MEX, faster execution, no Coder license needed
3. **`quantizenumeric`** — stay in double, inject quantization only where needed (Check 10)
4. **`buildInstrumentedMex`** — MEX with logging for type proposals

```matlab
% Benchmark with timeit
f_fi = @() myAlgorithm(x_fi, T);
f_dbl = @() myAlgorithm(x_dbl, T_dbl);
fprintf('fi/double ratio: %.1fx\n', timeit(f_fi) / timeit(f_dbl));
```



## Output Format

When reviewing code, report findings using these categories:

```
[PERF] Line XX: <description> (Check N)
[CODEGEN] Line XX: <description> (Check N)
[CORRECTNESS] Line XX: <description> (Check N)
[PATTERN] Line XX: <description> (Check N)
[DEBUG] Line XX: <description> (Check N)
```

**Examples**:

```
[PERF] Line 42: Scalar fi() in loop — vectorize (Check 1)
[PERF] Line 88: Name-value fi constructor in hot path — use positional or numerictype (Check 9)
[CODEGEN] Line 15: Default fimath generates bloated C — use Floor/Wrap/KeepLSB (Check 4)
[CODEGEN] Line 67: Division in fixed-point — use bitsra or inverse multiply (Check 6)
[CORRECTNESS] Line 33: Missing subscripted assignment — accumulator type will grow (Check 3)
[PATTERN] Line 20: Hardcoded fi type — separate into types table (Check 2)
[PATTERN] Line 55: High dynamic range forced to fixed-point — isolate in floating-point (Check 11)
[DEBUG] Line 40: Output diverges from double — check for overflow (Check 8)
```

Report every applicable check. Omit checks with no findings.

----

Copyright 2026 The MathWorks, Inc.

----
