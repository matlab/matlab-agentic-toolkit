# Numerical Accuracy, Correctness, and Coding Style

## Numerical Accuracy

Prefer `cospi(x)`/`sinpi(x)` over `cos(pi*x)`/`sin(pi*x)`. These are codegen-supported and eliminate floating-point error from multiplying by `pi`. Especially important in signal processing where exact values at half/quarter cycles matter.

```matlab
% BAD: floating-point error from pi multiplication
y = cos(2*pi*f*t);    % cos(pi) ≈ -1 + eps

% GOOD: exact at special values, no pi multiplication error
y = cospi(2*f*t);     % cospi(1) == -1 exactly
```

**Guard `log()` against zero/near-zero arguments:**

```matlab
% BAD: log(0) produces -Inf — hard to debug in generated C/C++
y = log(x);

% GOOD: clamp to smallest representable value
y = log(max(realmin, x));
```

In generated C/C++ code, `-Inf` propagation can be harder to debug and may trigger undefined behavior in subsequent operations. Defensive clamping at the source is cheaper than checking downstream.

**Prefer `x.*x` over `x.^2` for squaring** — avoids a `pow()` function call in generated code:

```matlab
% BAD: generates pow(x, 2.0) call in C
energy = x.^2;

% GOOD: simple multiplication — faster generated code
energy = x .* x;
```

**Codegen-supported numeric constants:** `realmin`, `realmax`, `eps`, `Inf`, `NaN`, `pi` are all available in generated code.

## NaN-Safe Zero Checks — Use `== 0` Not `~x`

In MATLAB, `~NaN` evaluates to `true` (logical 1). Using logical negation (`~x`) as a zero check will incorrectly trigger for NaN values, silently killing NaN propagation.

```matlab
% BAD: ~x is true for BOTH zero AND NaN — NaN won't propagate
if ~weight
    slope = 0;  % Executes when weight is NaN — wrong!
end

% GOOD: only catches actual zero, NaN propagates correctly
if weight == 0
    slope = 0;
else
    slope = (w1*d1 + w2*d2) / weight;  % NaN in weight -> NaN output (correct)
end
```

**Why this matters for codegen specifically:**
- In MATLAB, NaN propagation bugs may go unnoticed because downstream code often handles NaN gracefully
- In generated C/C++ code, silent NaN suppression produces subtly wrong numerical results with no warning
- Division-by-zero guards are common in numerical algorithms — every one is a potential NaN propagation bug if written with `~x`

**Rule:** When guarding against division by zero where inputs may contain NaN, always use `x == 0` (or `x ~= 0`), never `~x`.

```matlab
% Common pattern: weighted average with zero-weight guard
w = abs(d2 - d1) + abs(d2 + d1) / 2;
if w == 0
    result = 0;
else
    result = (w1*s1 + w2*s2) / w;
end
```

## Intentional Floating-Point Equality — MISRA Justification Comments

When floating-point equality checks are used intentionally (e.g., returning exact data values at grid nodes), add a MISRA justification comment. The C/C++ code generator propagates MATLAB comments to the generated code, and static analysis tools will flag `==` on floats unless justified.

```matlab
% GOOD: intentional equality check with MISRA justification
if r == 0  %#ok  % Intentional exact comparison: return data value without arithmetic
    Vq(k) = y(n);
elseif r == 1  %#ok  % Intentional exact comparison: return data value without arithmetic
    Vq(k) = y(n+1);
else
    Vq(k) = (1 - r)*y(n) + r*y(n+1);
end

% GOOD: equality check to avoid arithmetic when neighbors are identical
if y1 == y2  % Intentional: guarantees exact output when interpolating between equal values
    Vq(k) = y1;
else
    Vq(k) = (1 - r)*y1 + r*y2;
end
```

**When to use this pattern:**
- Returning an exact data value at a grid node
- Short-circuiting interpolation when neighboring values are identical
- Checking if a weight or denominator is exactly zero before division

**The comment should state:**
1. The comparison is intentional (not accidental)
2. Why it doesn't violate numerical correctness

## Conditional Output Computation

`nargout`-based branching is codegen-supported. Use it to skip expensive computations for unrequested outputs:

```matlab
function [yc, ys] = modulate(ye, fc, t) %#codegen
    yc = ye .* cospi(2*fc*t);
    if nargout > 1
        ys = ye .* sinpi(2*fc*t);  % only compute when requested
    end
end
```

The code generator eliminates the unreachable branch when the caller doesn't request the second output.

## MATLAB Coding Style (codegen context)

Adhere to the [MathWorks MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines):

### Functions
- Use `arguments` block for input validation
- Use `validateattributes` for validating internal variables — it is codegen-supported
- Terminate all functions with `end`
- Filename matches top-level function name

### Error Handling (codegen-specific)
- `try`/`catch` is NOT supported — use status flags or error codes instead
- Use `coder.target` to conditionally include error handling for MATLAB-only paths

```matlab
function [result, status] = safeCompute(x) %#codegen
    status = int32(0);
    result = zeros(size(x));
    if any(x < 0)
        status = int32(-1); % error code instead of error()
        return;
    end
    result = sqrt(x);
end
```

----

Copyright 2026 The MathWorks, Inc.

----
