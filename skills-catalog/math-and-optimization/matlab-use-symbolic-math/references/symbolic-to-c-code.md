# Symbolic to C Code Generation

Use `matlabFunction` to write an optimized MATLAB function file from a symbolic expression, then `codegen` to compile it to C/C++.

## Workflow

1. Create or simplify the symbolic expression
2. Use `matlabFunction(..., 'File', 'myFunc.m')` to generate an optimized `.m` file
3. Use `codegen` to compile the `.m` file to C/C++ code or a MEX file
4. Verify the generated code

## Key Functions

| Function | Purpose | Toolbox | Since |
|----------|---------|---------|-------|
| `matlabFunction(expr, 'File', path)` | Convert symbolic expression to optimized `.m` function file | Symbolic Math | R2008b |
| `codegen funcName -args {...}` | Generate C/C++ code from MATLAB function | MATLAB Coder | R2011a |
| `ccode(expr)` | Generate C code string (single expression only) | Symbolic Math | — |

## Why Not Just `ccode`?

`ccode` converts a single symbolic expression to a C code string. It does NOT:
- Handle multi-output functions
- Optimize common subexpressions across a full function
- Generate a complete, compilable C program
- Handle input/output argument marshalling

`matlabFunction` + `codegen` is the supported, scalable pipeline.

## Pattern: Full Pipeline

```matlab
% Step 1: Define symbolic expression
syms x y z real
expr = sin(x^2 + y^2) * exp(-z) + cos(x*y*z);

% Step 2: Generate optimized MATLAB function file
matlabFunction(expr, 'File', 'mySymExpr.m', ...
    'Vars', [x y z], ...
    'Optimize', true);

% Step 3: Generate C code (as static library)
cfg = coder.config('lib');
cfg.GenerateReport = true;
codegen -config cfg mySymExpr -args {0, 0, 0}

% Step 4: Or generate MEX for fast in-MATLAB execution
codegen -config:mex mySymExpr -args {0, 0, 0}
```

## Pattern: Vector/Matrix Output

```matlab
syms t real
syms A gamma omega phi real

% Damped oscillator: position and velocity
pos = A * exp(-gamma*t) * cos(omega*t + phi);
vel = diff(pos, t);

% Generate function with multiple outputs
matlabFunction(pos, vel, 'File', 'oscillator.m', ...
    'Vars', [t A gamma omega phi], ...
    'Outputs', {'position', 'velocity'}, ...
    'Optimize', true);

% Generate C code
codegen oscillator -args {0, 0, 0, 0, 0} -config:lib
```

## Pattern: Large Expression with Optimization

```matlab
syms x1 x2 x3 x4 x5 real

% Large expression from symbolic computation
bigExpr = jacobian([x1^2*x2 + sin(x3*x4); exp(x1*x5) + x2*x3], [x1 x2 x3 x4 x5]);

% matlabFunction with Optimize=true handles common subexpression elimination
matlabFunction(bigExpr, 'File', 'myJacobian.m', ...
    'Vars', [x1 x2 x3 x4 x5], ...
    'Optimize', true);

% Compile to MEX for fast numerical evaluation
codegen -config:mex myJacobian -args {zeros(1,5)}
```

## When to Use `ccode` Instead

`ccode` is appropriate only when:
- You need a single C expression to embed in an existing C program
- You are generating code for a very specific, non-MATLAB target
- The expression is simple enough that no optimization is needed

```matlab
syms x real
expr = x^2 + 2*x + 1;
cStr = ccode(expr);  % Returns: "t0 = (x+1.0)*(x+1.0);"
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `ccode` + manually writing a C file | Brittle, doesn't optimize, doesn't scale | `matlabFunction(...,'File',...)` then `codegen` |
| Using `matlabFunction` without `'File'` | Creates a function handle, not a file — can't use with `codegen` | Always pass `'File'` when targeting C generation |
| Forgetting `'Optimize', true` | Misses common subexpression elimination | Always pass `'Optimize', true` for C targets |
| Not specifying `-args` with `codegen` | `codegen` needs input types to generate C | Always provide `-args` with example inputs |

----

Copyright 2026 The MathWorks, Inc.

----
