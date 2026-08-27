# Rewrite and Combine Expressions

Use `rewrite` to express a symbolic expression in terms of a target function. Use `combine` to merge multiple calls of the same function into one. These are distinct operations — do not confuse them.

## Key Functions

| Function | Purpose |
|----------|---------|
| `rewrite(expr, target)` | Rewrite expr using target function form |
| `combine(expr, target)` | Combine terms of the same function into one |
| `expand(expr)` | Distribute and expand (algebraic, trig, exp) |
| `simplify(expr)` | Apply general simplification heuristics |
| `factor(expr)` | Factor polynomial into irreducible factors |
| `collect(expr, var)` | Group terms by powers of var |
| `horner(expr)` | Convert polynomial to nested evaluation form |
| `partfrac(expr, var)` | Partial fraction decomposition |
| `simplifyFraction(expr)` | Combine fractions into single numerator/denominator |

## Valid Targets for `combine`

**Only these 7 targets are valid:**

| Target | Effect | Example |
|--------|--------|---------|
| `'sincos'` | Products/powers of sin/cos → multiple angles | `sin(x)*cos(x)` → `sin(2*x)/2` |
| `'exp'` | Products of exp → single exp | `exp(x)*exp(y)` → `exp(x+y)` |
| `'log'` | Sum of logs → single log (needs `'IgnoreAnalyticConstraints', true`) | `log(x)+log(y)` → `log(x*y)` |
| `'atan'` | Sum of atan → single atan | `atan(x)+atan(y)` → combined form |
| `'gamma'` | Products of gamma → single gamma | Gamma function combinations |
| `'int'` | Sum of integrals → single integral | `int(f)+int(g)` → `int(f+g)` |
| `'sinhcosh'` | Products/powers of sinh/cosh → multiple arguments | Similar to sincos for hyperbolic |

**INVALID targets for `combine` (will error):**
- `'power'` — DOES NOT EXIST
- `'sqrt'` — DOES NOT EXIST
- `'tan'` — DOES NOT EXIST
- Any target not in the list above

## Valid Targets for `rewrite`

These are the common valid targets:

| Target | Rewrites to |
|--------|-------------|
| `'exp'` | Exponential form (Euler's formula for trig) |
| `'sincos'` | Sine and cosine |
| `'sin'` | Sine only |
| `'cos'` | Cosine only |
| `'tan'` | Tangent (half-angle) |
| `'log'` | Logarithmic form (for inverse trig) |
| `'sinhcosh'` | Hyperbolic sine and cosine |
| `'sqrt'` | Square root form |
| `'heaviside'` | Heaviside step function |
| `'piecewise'` | Piecewise form |

**INVALID targets for `rewrite`:**
- `'pow'` — DOES NOT EXIST
- `'power'` — DOES NOT EXIST

## When to Use Which Function

| Goal | Function |
|------|----------|
| Express sin/cos as exponentials | `rewrite(expr, 'exp')` |
| Express exponentials as sin/cos | `rewrite(expr, 'sincos')` |
| Merge `sin(x)*cos(x)` into `sin(2x)/2` | `combine(expr, 'sincos')` |
| Merge `exp(a)*exp(b)` into `exp(a+b)` | `combine(expr, 'exp')` |
| Expand `(x+y)^n` or `sin(x+y)` | `expand(expr)` |
| Factor `x^3 - x` into `x*(x-1)*(x+1)` | `factor(expr)` |
| Group by powers of x | `collect(expr, x)` |
| Nested form for evaluation | `horner(expr)` |
| Decompose rational function | `partfrac(expr, x)` |
| General simplification | `simplify(expr)` |

## Important: `'IgnoreAnalyticConstraints'`

`combine(log(x) + log(y), 'log')` does **not** simplify by default because `log(xy) = log(x) + log(y)` only holds for positive reals. To force it:

```matlab
combine(log(x) + log(y), 'log', 'IgnoreAnalyticConstraints', true)
% Result: log(x*y)
```

## Pattern: Rewriting Trigonometric Expressions

```matlab
syms x

% Trig to exponential (Euler's formula)
rewrite(sin(x), 'exp')
% Result: (exp(1i*x) - exp(-1i*x)) / (2i)

% Exponential to trig
rewrite(exp(1i*x), 'sincos')
% Result: cos(x) + 1i*sin(x)

% Half-angle tangent substitution
rewrite(sin(x), 'tan')
% Result: (2*tan(x/2)) / (1 + tan(x/2)^2)
```

## Pattern: Combining Trigonometric Products

```matlab
syms x

% Product to double angle
combine(sin(x)*cos(x), 'sincos')
% Result: sin(2*x)/2

% Power to double angle
combine(cos(x)^2 - sin(x)^2, 'sincos')
% Result: cos(2*x)

% Identity
combine(sin(x)^2 + cos(x)^2, 'sincos')
% Result: 1
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `combine(expr, 'power')` | Not a valid target — will error | No equivalent; use `simplify` or `rewrite` |
| `combine(expr, 'sqrt')` | Not a valid target | Use `rewrite(expr, 'sqrt')` instead |
| `rewrite(expr, 'pow')` | Not a valid target | Use `simplify` for power simplification |
| Using `simplify` when a specific form is needed | `simplify` picks its own "simplest" form | Use `rewrite` or `combine` with explicit target |
| `combine(log(x)+log(y), 'log')` without IgnoreAnalyticConstraints | Won't combine (analytically unsafe) | Add `'IgnoreAnalyticConstraints', true` |

----

Copyright 2026 The MathWorks, Inc.

----
