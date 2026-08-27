# matlabFunction Patterns

Reference patterns for converting symbolic expressions to efficient MATLAB function handles or files using `matlabFunction`.

## Function Handle (Most Common)

To create a callable function handle from a symbolic expression, use `matlabFunction` with only `'Vars'`:

```matlab
syms A omega zeta t phi
y = A*exp(-zeta*omega*t)*sin(omega*sqrt(1 - zeta^2)*t + phi);
y_fun = matlabFunction(y, 'Vars', [A omega zeta t phi]);
% Returns @(A,omega,zeta,t,phi) ... — ready to call with numeric values
% No other options needed. Do not add 'Optimize'.
```

This is the correct and complete pattern for function handles — no additional options are needed regardless of expression complexity.

## File Output (When You Need Optimization or Piecewise)

Write to a `.m` file when you need code optimization or have piecewise expressions:

```matlab
matlabFunction(y, 'Vars', [A omega zeta t phi], 'File', 'dampedResponse');
% Generates dampedResponse.m with optimized intermediate variables t0, t1, ...
% 'Optimize' is true by default when 'File' is specified
```

## Critical Rule: 'Optimize' Only Works with 'File'

`'Optimize', true` generates intermediate variable assignments (`t0`, `t1`, ...) that cannot exist inside an anonymous function. Passing `'Optimize', true` without `'File'` **throws an error**. Since the "Function Handle" pattern above never uses `'Optimize'`, this error cannot occur if you follow it.

## Critical Rule: Piecewise Expressions Require a File

Anonymous functions cannot contain `if-else` branching, so `matlabFunction` **cannot convert a `piecewise(...)` expression to an anonymous function handle**. This is a separate issue from the `'Optimize'` flag — it applies even without optimization.

**WRONG (will error):**
```matlab
syms eps E sigy K n
sigma = piecewise(E*eps <= sigy, E*eps, symtrue, sigy + K*(eps - sigy/E)^n);
sigma_fun = matlabFunction(sigma, 'Vars', {eps, E, sigy, K, n});
% Error: cannot generate anonymous function from piecewise expression
```

**CORRECT — Option A: Write to a file (recommended):**
```matlab
matlabFunction(sigma, 'File', 'sigma_fun', 'Vars', {eps, E, sigy, K, n});
% Generates sigma_fun.m with if-else branching
% Call as: result = sigma_fun(0.01, 200e9, 250e6, 500e6, 0.3)
% NOTE: The generated file function accepts only SCALAR inputs
```

**CORRECT — Option B: Use `subs` for one-off evaluation:**
```matlab
% If you only need a few evaluations, skip matlabFunction entirely
result = double(subs(sigma, {eps, E, sigy, K, n}, {0.01, 200e9, 250e6, 500e6, 0.3}));
```
## Critical Rule: `'Vars'` Must Include ALL Free Symbols

When you specify `'Vars'`, `matlabFunction` requires **every free symbolic variable** in the expression to appear in the list. It does NOT treat unlisted variables as constants — it throws an error.

**WRONG:**
```matlab
syms V rho Malpha Mde Mq Zalpha Zde
wn_Vrho = sqrt(Malpha*Zalpha - Mq*Zalpha*V + ...);  % contains 7 free symbols

% Attempting to make a function of only V and rho:
wn_fun = matlabFunction(wn_Vrho, 'Vars', [V, rho]);
% Error: Free variables 'Malpha,Mde,Mq,Zalpha,Zde' must be included in 'Vars' value.
```

**CORRECT — Option A: Include all free variables in `'Vars'`:**
```matlab
% Use symvar to discover all free symbols
symvar(wn_Vrho)   % Returns: [Malpha, Mde, Mq, V, Zalpha, Zde, rho]

% Include them all — control the order with 'Vars'
wn_fun = matlabFunction(wn_Vrho, 'Vars', [V, rho, Malpha, Mde, Mq, Zalpha, Zde]);
% Call as: wn_fun(V_val, rho_val, Ma_val, Mde_val, Mq_val, Za_val, Zde_val)
```

**CORRECT — Option B: Substitute constants BEFORE calling `matlabFunction`:**
```matlab
% If Malpha, Mde, etc. are known numeric parameters, substitute first
wn_sub = subs(wn_Vrho, [Malpha, Mde, Mq, Zalpha, Zde], [-2.5, -0.8, -1.1, -300, -25]);
wn_fun = matlabFunction(wn_sub, 'Vars', [V, rho]);
% Now it's truly a function of only V and rho
```

**CORRECT — Option C: Group parameters into a vector input:**
```matlab
% Keep all symbols but organize them logically
wn_fun = matlabFunction(wn_Vrho, 'Vars', {[V, rho], [Malpha, Mde, Mq, Zalpha, Zde]});
% Call as: wn_fun([V_val, rho_val], [Ma_val, Mde_val, Mq_val, Za_val, Zde_val])
```

**Best practice:** Always call `symvar(expr)` before `matlabFunction` to see what free symbols exist. This prevents surprises from symbols that propagated through earlier symbolic computation.

## Basic Usage

```matlab
syms x y z

% Function handle (anonymous function)
f = x^2 + y^2 + z^2;
fh = matlabFunction(f);
% Creates: @(x,y,z) x.^2 + y.^2 + z.^2

% Control variable order
fh = matlabFunction(f, 'Vars', {x, y, z});

% Group variables into vectors
fh = matlabFunction(f, 'Vars', {[x, y, z]});
% Creates: @(in1) in1(:,1).^2 + in1(:,2).^2 + in1(:,3).^2

% Write to file instead of returning handle
% NOTE: Optimization is automatic when writing to file.
% Do NOT use 'Optimize', true without 'File' — it will error.
matlabFunction(f, 'File', 'myFunction', 'Vars', {x, y, z});
% Creates myFunction.m on disk with optimized intermediate variables

% Multiple outputs
syms a b
expr1 = a + b;
expr2 = a * b;
fh = matlabFunction(expr1, expr2, 'Vars', {a, b});
% Creates: @(a,b) deal(a+b, a.*b)
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `matlabFunction(..., 'Optimize', true)` without `'File'` | Either add `'File', 'myFunc'` or remove `'Optimize'` |
| `matlabFunction(expr, 'Vars', [x y])` when expr has more symbols | Use `symvar(expr)` first; include all, or `subs` constants out |
| `matlabFunction(piecewise_expr)` to anonymous | Piecewise requires `'File'` output, or use manual logical indexing |

## Checklist

- [ ] Using `matlabFunction` with `'Vars'` to control argument order
- [ ] When input arguments to `matlabFunction` are a combination of scalar and vector variables, specifying the Vars name-value argument as a cell array
- [ ] NOT using `'Optimize', true` with `matlabFunction` unless `'File'` is also specified
- [ ] Calling `symvar(expr)` before `matlabFunction` to ensure `'Vars'` includes all free symbols
- [ ] Using `'File'` output for `matlabFunction` when dealing with piecewise expressions

## Troubleshooting

**Issue**: "Free variables '...' must be included in 'Vars' value" from `matlabFunction`
- **Cause**: The expression contains symbolic variables not listed in `'Vars'`. `matlabFunction` requires ALL free symbols.
- **Fix**: Run `symvar(expr)` to see all free symbols. Either include them all in `'Vars'`, or substitute numeric values for the "constants" with `subs` before calling `matlabFunction`.

----

Copyright 2026 The MathWorks, Inc.
