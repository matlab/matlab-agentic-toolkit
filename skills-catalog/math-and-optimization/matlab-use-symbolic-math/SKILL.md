---
name: matlab-use-symbolic-math
description: >
  Generate correct MATLAB code using the Symbolic Math Toolbox. Use when the user
  asks for symbolic computations, analytical solutions, symbolic differentiation/integration,
  equation solving, or converting symbolic results to numeric MATLAB functions. Also use
  when converting differential equations to transfer functions or state-space form, extracting
  PDE coefficients (pdeCoefficients), symbolic-to-C code generation (matlabFunction + codegen),
  symbolic matrix variables (symmatrix), physical units and constants (symunit, newUnit),
  or rewriting/combining algebraic expressions (rewrite, combine).
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Symbolic Math Toolbox

This skill provides guidelines, correct syntax, and common patterns for generating MATLAB® code that uses Symbolic Math Toolbox.

## When to Use This Skill

- Creating or manipulating symbolic variables, expressions, and functions
- Performing symbolic differentiation, integration, limits, or summation
- Simplifying, factoring, expanding, or collecting symbolic expressions
- Computing Laplace, Fourier, or Z-transforms and their inverses
- Deriving transfer functions or state-space equations from differential equations
- Displaying or plotting symbolic expressions
- Using variable precision arithmetic (VPA)
- Generating MATLAB functions, Simulink function blocks, Simscape equations, and C code from symbolic expressions
- Extracting PDE coefficients for use with PDE Toolbox
- Converting symbolic expressions to C code or standalone executables
- Matrix-level (atomic, textbook-style) symbolic linear algebra with `symmatrix`
- Using physical units or constants in symbolic computations with `symunit`
- Rewriting or combining algebraic expressions into specific forms

## When NOT to Use This Skill

- Purely numeric computation with no symbolic variables (use standard MATLAB numeric functions)
- Statistics, machine learning, or data analysis on numeric datasets
- Image processing, signal processing, or other toolbox-specific workflows that don't involve symbolic math
- String manipulation or file I/O operations
- When the user explicitly asks for numeric approximations only (use `double` or numeric solvers directly)
- PDE Toolbox mesh generation, boundary conditions, or solving (downstream of coefficient extraction)
- Numeric linear algebra (use standard MATLAB matrix operations)

## Critical Rules

### 1. NEVER Pass Strings or Character Vectors to Symbolic Functions

**WRONG (deprecated — warns today, errors in a future release; the single `=` in `solve` errors now):**
```matlab
solve('x^2 + 2*x - 3 = 0')
dsolve('Dy = -a*y')
```

**CORRECT:**
```matlab
syms x
solve(x^2 + 2*x - 3 == 0, x)

syms y(t) a
dsolve(diff(y,t) == -a*y)
```

### 2. Use `syms` for Interactive Work, `sym` for Functions and Constants

- **`syms x y z`** — Creates fresh symbolic variables and clears any prior assumptions. Use for interactive scripts and Live Scripts.
- **`x = sym('x')`** — Refers to a symbolic variable. Inherits existing assumptions. Required inside MATLAB functions (not scripts) because `syms` dynamically creates workspace variables.
- **`sym(pi)`** — Converts numeric to exact symbolic. Use for symbolic constants.
- **`sym('pi')`** — Creates a symbolic *variable named* `pi`, NOT the mathematical constant π. This is a common source of confusion.

**WRONG:**
```matlab
% Inside a function:
function result = myFunc()
    syms x          % Error or unreliable in compiled/nested functions
    result = x^2;
end

% Creating symbolic constant pi:
p = sym('pi');      % Creates variable named "pi", NOT the constant
```

**CORRECT:**
```matlab
% Inside a function:
function result = myFunc()
    x = sym('x');   % Use sym inside functions
    result = x^2;
end

% Creating symbolic constant pi:
p = sym(pi);        % Converts numeric pi to exact symbolic π
```

### 3. Assumption Management

Assumptions persist in the symbolic engine even after `clear`. This is a frequent source of subtle bugs.

```matlab
% Setting assumptions
syms x real                  % x is real (clears prior assumptions)
syms n positive integer      % n is a positive integer
assume(x > 0)                % x is positive (REPLACES all prior assumptions on x)
assumeAlso(x < 10)           % ADDS assumption: 0 < x < 10

% Checking assumptions
assumptions(x)               % Shows assumptions on x
assumptions                  % Shows ALL assumptions in workspace

% Clearing assumptions — two correct ways:
syms x                       % Recreate with syms: clears assumptions
assume(x, 'clear')           % Explicitly clear assumptions on x
reset(symengine)             % Nuclear option: clears EVERYTHING
```

**Best Practice:** Use `syms x` to clear assumptions (it resets the variable fresh). Use `assume(x, 'clear')` when you need to reset a specific variable mid-script. The MATLAB `clear` command only removes workspace variables — it has no effect on the symbolic engine's assumption store.

### 4. `subs` Does Not Modify In-Place

The `subs` function returns a new expression. It does NOT modify the original.

**WRONG:**
```matlab
syms x
f = x^2 + 3*x;
subs(f, x, 2);         % Result is discarded!
disp(f)                % Still x^2 + 3*x
```

**CORRECT:**
```matlab
syms x
f = x^2 + 3*x;
f_val = subs(f, x, 2);    % Assign the result
% or: f = subs(f, x, 2);  % Overwrite f
```

### 5. Do Not Wrap Numeric Literals in `sym()` Inside Symbolic Expressions

AI tools frequently over-wrap every numeric literal in `sym()`.
When any operand in an arithmetic expression is symbolic, MATLAB automatically promotes all numeric literals in that expression to symbolic. Wrapping literals in `sym()` adds clutter and can cause errors.
**When you DO need `sym()`:** Only when creating a standalone symbolic number with NO symbolic variables present in the expression.

```matlab
% No symbolic variable involved — sym() IS needed:
half = sym(1/2);                % Exact 1/2, not 0.5 double
half = sym(1)/2;                % Exact 1/2, declaring sym(1) promotes all numeric literals to symbolic
piExact = sym(pi);              % Exact π, not 3.14159...

% Symbolic variable already present — sym() is NOT needed:
syms x
f = x/2 + 1/3;                 % Automatically exact: x/2 + 1/3
g = exp(-x^2/2) / sqrt(2*pi);  % All literals promoted by x
```

## Core Workflow Patterns

### Creating Variables and Expressions

```matlab
% Multiple variables at once
syms a b c

% Variables with assumptions
syms a b c real
syms n positive integer
syms x
assume(x > 2)


% Symbolic matrices with auto-generated elements
syms A [3 3]                 % Creates A = [A1_1 A1_2 A1_3; ...]

% Symbolic vector
syms a [1 3]                 % Creates row vector a = [a1 a2 a3]

% Symbolic numbers (exact)
a = sym(1/3);           % Exact 1/3
piSym = sym(pi);        % Exact π
```

### Solving Algebraic Equations

```matlab
syms x y

% Single equation
sol = solve(x^2 - 5*x + 6 == 0, x);   % Returns [2; 3]

% System of equations
[solx, soly] = solve(x + y == 10, x - y == 2, x, y);

% Return all solutions along with the parameters in the solution and the conditions on the solution
[sol, params, conds] = solve(sin(x) == 0, x, 'ReturnConditions', true);

% Numerical solutions when analytic not possible
solN = vpasolve(x^5 - 3*x^4 + x - 1 == 0, x);
```

### Calculus

```matlab
syms x t n

% Differentiation
diff(sin(x), x)             % cos(x)
diff(x^3, x, 2)             % 6*x  (second derivative)

% Integration
int(x^2, x)                 % x^3/3  (indefinite)
int(x^2, x, 0, 1)           % 1/3    (definite, from 0 to 1)

% Limits
limit(sin(x)/x, x, 0)       % 1
limit(1/x, x, 0, 'right')   % Inf
limit(1/x, x, 0, 'left')    % -Inf

% Summation
symsum(1/n^2, n, 1, Inf)     % pi^2/6

% Taylor series
taylor(exp(x), x, 0, 'Order', 6)   % x^5/120 + x^4/24 + x^3/6 + x^2/2 + x + 1 

% Gradient, Hessian, Jacobian, Laplacian, Divergence, Curl — use dedicated functions, not manual diff
syms x y z
f = x^2*y + y^3;
gradient(f, [x, y])              % [2*x*y; x^2 + 3*y^2]
hessian(f, [x, y])               % [2*y, 2*x; 2*x, 6*y]
laplacian(f, [x, y])             % 2*y + 6*y = 8*y (trace of Hessian)
g = [x^2*y; 5*x + sin(y)];
jacobian(g, [x, y])              % [2*x*y, x^2; 5, cos(y)]
V = [x^2*y; y^2*z; z^2*x];
divergence(V, [x, y, z])         % 2*x*y + 2*y*z + 2*z*x
curl(V, [x, y, z])               % [-y^2; -z^2; -x^2]
```

### Matrix Operations

```matlab
syms a b c d
A = [a b; c d];

% Determinant
det(A)                   % a*d - b*c

% Inverse
inv(A)                   % Symbolic inverse

% Eigenvalues and eigenvectors
[V, D] = eig(A)

% Characteristic polynomial
charpoly = det(A - sym('lambda')*eye(2))

% Jacobian of a coordinate change
syms r(t) phi(t) theta(t);  % polar coordinates that are a function of time
R = [r*sin(phi)*cos(theta), r*sin(phi)*sin(theta), r*cos(phi)] % coordinate transform from spherical to Cartesian
jacobian(R,[r,phi,theta])
```

## Application Patterns

For detailed workflows, see the reference files below. Read the relevant file when the user's task matches:

- **`references/simplification-and-polynomials.md`** — `simplify`/`expand`/`factor`/`collect`/`partfrac`/`rewrite`, `sym2poly` vs `coeffs`, variable-precision arithmetic (VPA)
- **`references/control-systems.md`** — Deriving transfer functions from ODEs, `tf`/`ss` derivation from first principles, Laplace/Fourier/Z-transform, Bode plots from symbolic models
- **`references/ode-solving.md`** — `dsolve` syntax, `odeToVectorField` + `matlabFunction` + `ode45` pipeline, parameterized ODE solving
- **`references/plotting-and-display.md`** — `fplot`/`fsurf`/`fmesh`/`fcontour`/`fimplicit`/`fanimator` family, `disp()` vs `pretty()`, symbolic plotting best practices
- **`references/matlabFunction-patterns.md`** — Converting symbolic expressions to function handles/files, `'Vars'`/`'Optimize'`/`'File'` options, piecewise handling, critical error-prevention rules
- **`references/extract-pde-coefficients.md`** — `pdeCoefficients` workflow for extracting PDE Toolbox coefficients, `pdeCoefficientsToDouble`, systems of PDEs
- **`references/symbolic-to-c-code.md`** — `matlabFunction(..., 'File', ...)` + `codegen` pipeline for C/C++ generation, when to use `ccode` vs full pipeline
- **`references/symmatrix-workflow.md`** — Atomic symbolic matrices with `symmatrix`, `symmatrix2sym` conversion, `symfunmatrix`, supported vs unsupported operations
- **`references/symunit-workflow.md`** — Physical units/constants via `symunit`, `newUnit`/`removeUnit`, correct constant names (`u.hc`, `u.c_0`), unit conversion
- **`references/rewrite-combine-expressions.md`** — Valid targets for `rewrite` and `combine`, `IgnoreAnalyticConstraints` for log combination, when to use which function

## Common Mistakes and Fixes

| Mistake | Fix |
|---------|-----|
| `solve('x^2=1')` | `syms x; solve(x^2 == 1, x)` |
| `dsolve('Dy = y')` | `syms y(t); dsolve(diff(y,t) == y)` |
| `subs(f,x,2)` without assigning | `f = subs(f,x,2)` |
| Attempting to clear assumptions with the `clear` command | `syms x` or `assume(x,'clear')` — only these reset the symbolic engine |
| Using `syms` inside a function | Use `x = sym('x')` inside functions |
| Manually extracting PDE coefficients by inspection | Use `pdeCoefficients(pdeeq, u)` |
| Computing Laplacian as sum of second derivatives | Use `laplacian(f, vars)` |
| Using `ccode()` and manually building C files | Use `matlabFunction(..., 'File', ...)` then `codegen` |
| Using `sym('A', [n n])` for matrix-level algebra | Use `symmatrix('A', [n n])` |
| Hard-coding physical constants as numbers | Use `u = symunit; u.hc; u.c_0; u.m_e` |
| Using `combine(expr, 'power')` | Invalid target — valid: `'atan'`, `'exp'`, `'gamma'`, `'int'`, `'log'`, `'sincos'`, `'sinhcosh'` |
| Computing gradient/Hessian/Jacobian/Laplacian/divergence/curl manually with `diff` | Use `gradient`, `hessian`, `jacobian`, `laplacian`, `divergence`, `curl` |
| Manually building numeric arrays to plot a symbolic expression | Use `fplot(f, [a b])`, `fsurf`, `fmesh`, `fcontour`, or `fanimator` — they accept symbolic directly |
| Adding `'Optimize'` to `matlabFunction` for a function handle | For handles: `matlabFunction(expr, 'Vars', {...})` — nothing else needed. `'Optimize'` is only for `'File'` output |
| Keeping everything symbolic for a parametric sweep | Convert to numeric: use `matlabFunction` then loop, or `subs`+`double` in a loop |

See also: application-specific mistakes in each reference file.

## Conventions for Modern Features

- Use `gradient`, `hessian`, `jacobian`, `laplacian`, `divergence`, and `curl` when computing these standard vector calculus objects — do not manually assemble them from `diff` calls
- Prefer `pdeCoefficients()` for extracting PDE Toolbox coefficients when the PDE is in a supported form
- Prefer physical constants from `symunit` (e.g., `u.hc`, `u.c_0`) when available; hard-code only if the constant is not in the symunit catalog
- Use `symmatrix` when the user asks for atomic/textbook-style matrices
- Never pass an invalid target to `combine` or `rewrite` — consult the reference for valid targets

## Checklist Before Generating Symbolic Code

- [ ] Using `syms` (not string-based `sym('...')`) for variable creation in scripts
- [ ] Using `==` for equations, not `=`
- [ ] Using `diff(y, t, n)` for derivatives, not `D` notation
- [ ] Using `gradient`, `hessian`, `jacobian`, `laplacian`, `divergence`, `curl` instead of manual `diff` when computing these objects
- [ ] Specifying the independent variable explicitly in `diff`, `int`, `laplace`
- [ ] Assigning `subs(...)` output to a variable
- [ ] NOT wrapping numeric literals in `sym()` when a symbolic variable is already in the expression
- [ ] Setting assumptions with `assume`/`assumeAlso`, clearing with `syms x` or `assume(x,'clear')`
- [ ] Using `fplot`/`fsurf`/`fanimator` for symbolic plots (they accept symbolic expressions directly)
- [ ] For parametric sweeps: converting to numeric (`matlabFunction` or `subs`+`double` in a loop)

## Troubleshooting

**Issue**: `solve` returns empty or unexpected results
- **Check**: Are there assumptions restricting the domain? Use `assumptions` to check.
- **Try**: `solve(eqn, x, 'ReturnConditions', true)` to see conditions on solutions.
- **Try**: `vpasolve` for numeric solutions when no closed form exists.

**Issue**: Stale assumptions causing wrong results
- **Fix**: Add `syms <varname>` at the top of your script to clear assumptions.
- **Nuclear option**: `reset(symengine)` clears everything.

See also: application-specific troubleshooting in each reference file.

----

Copyright 2026 The MathWorks, Inc.
