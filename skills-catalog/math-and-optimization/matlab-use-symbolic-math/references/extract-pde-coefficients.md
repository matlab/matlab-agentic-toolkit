# Extract PDE Coefficients

Use `pdeCoefficients` to automatically extract coefficients from a symbolic PDE for use with PDE Toolbox's `specifyCoefficients`.

## Workflow

1. Define the dependent variable as a symbolic function
2. Write the PDE symbolically using `laplacian`, `diff`, `gradient`, etc.
3. Call `pdeCoefficients(pdeeq, u)` to extract the coefficient struct
4. Pass coefficients to `specifyCoefficients`

## Key Functions

| Function | Purpose | Toolbox | Since |
|----------|---------|---------|-------|
| `pdeCoefficients(pdeeq, u)` | Extract m, d, c, a, f coefficients from symbolic PDE | Symbolic Math | R2021a |
| `pdeCoefficients(..., 'Symbolic', true)` | Keep coefficients in symbolic form | Symbolic Math | R2021a |
| `pdeCoefficientsToDouble(coeffs)` | Convert symbolic coefficients to numeric | Symbolic Math | R2021a |
| `specifyCoefficients(model, ...)` | Apply coefficients to PDE model | PDE Toolbox | — |

## PDE Toolbox Coefficient Form

The PDE Toolbox expects equations in this general form:

```
m * d²u/dt² + d * du/dt - div(c * grad(u)) + a * u = f
```

`pdeCoefficients` automatically maps any symbolic PDE to these coefficients.

## Pattern: Scalar Time-Dependent PDE

```matlab
syms x y t
syms alpha real
syms T(x, y, t)

% Write the PDE using laplacian
pdeeq = diff(T, t) - alpha * laplacian(T, [x y]);

% Extract coefficients (symbolic form)
coeffs = pdeCoefficients(pdeeq, T, 'Symbolic', true);
disp(coeffs)
% coeffs.m = 0, coeffs.d = 1, coeffs.c = alpha, coeffs.a = 0, coeffs.f = 0

% Substitute parameter values, then convert to numeric
alphaVal = 0.5;
coeffs.c = subs(coeffs.c, alpha, alphaVal);
numCoeffs = pdeCoefficientsToDouble(coeffs);
specifyCoefficients(model, 'm', numCoeffs.m, 'd', numCoeffs.d, ...
    'c', numCoeffs.c, 'a', numCoeffs.a, 'f', numCoeffs.f);
```

## Pattern: Steady-State PDE (Poisson)

```matlab
syms x y
syms u(x, y)

% Poisson equation: -laplacian(u) = f(x,y)
f_source = sin(pi*x) * sin(pi*y);
pdeeq = -laplacian(u, [x y]) - f_source;

coeffs = pdeCoefficients(pdeeq, u, 'Symbolic', true);
% coeffs.m = 0, coeffs.d = 0, coeffs.c = 1, coeffs.a = 0, coeffs.f = f_source
```

## Pattern: Schrodinger Equation with symunit Constants

```matlab
syms x y z t
syms V_val  % abstract potential (scalar symbolic variable)
syms Psi(x, y, z, t)

u = symunit;
hbar = u.hbar;  % reduced Planck constant from symunit
m_e = u.m_e;    % electron mass from symunit

% Time-dependent Schrodinger equation
pdeeq = 1i*hbar*diff(Psi, t) + (hbar^2/(2*m_e))*laplacian(Psi, [x y z]) - V_val*Psi;

coeffs = pdeCoefficients(pdeeq, Psi, 'Symbolic', true);
```

## Pattern: System of PDEs

```matlab
syms x y t
syms u1(x, y, t) u2(x, y, t)

% System of two coupled PDEs
eq1 = diff(u1, t) - laplacian(u1, [x y]) + u2;
eq2 = diff(u2, t) - 2*laplacian(u2, [x y]) - u1;

coeffs = pdeCoefficients([eq1; eq2], [u1; u2], 'Symbolic', true);
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Manually reading off m, d, c, a, f | Error-prone, doesn't scale to complex PDEs | `pdeCoefficients(pdeeq, u)` |
| Forgetting `'Symbolic', true` | Returns function handles (harder to inspect) | Pass `'Symbolic', true` when you want to see the symbolic form |

----

Copyright 2026 The MathWorks, Inc.

----
