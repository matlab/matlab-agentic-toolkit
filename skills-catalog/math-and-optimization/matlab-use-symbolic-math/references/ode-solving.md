# ODE Solving Patterns

Reference patterns for solving ordinary differential equations with the Symbolic Math Toolbox, including closed-form solutions with `dsolve` and the `odeToVectorField` + `matlabFunction` + `ode45` pipeline for numeric simulation.

## Solving Differential Equations with dsolve

```matlab
% First-order ODE
syms y(t)
ode = diff(y,t) == -2*y;
sol = dsolve(ode);                    % C1*exp(-2*t)

% With initial condition
sol = dsolve(ode, y(0) == 5);         % 5*exp(-2*t)

% Second-order ODE
syms y(t)
Dy = diff(y, t);
D2y = diff(y, t, 2);
ode = D2y + 4*Dy + 3*y == 0;
sol = dsolve(ode, y(0) == 1, Dy(0) == 0);  % (3*exp(-t))/2 - exp(-3*t)/2

% System of ODEs
syms x(t) y(t)
eqns = [diff(x,t) == -x + y, diff(y,t) == x - y];
[solx, soly] = dsolve(eqns);

% When dsolve returns empty, use numeric solver:
% dsolve returns sym.empty when no closed-form solution exists
syms y(x)
eqn = diff(y) == (x - exp(-x))/(y + exp(y));
S = dsolve(eqn);
% S is empty — switch to ode45 (see pipeline below)
```

## ODE to Numeric Solver Pipeline (odeToVectorField + matlabFunction + ode45)

This is the standard pipeline for solving ODEs that have no closed-form solution, or for simulating nonlinear systems:

```matlab
syms y(t)
Dy = diff(y, t);
D2y = diff(y, t, 2);

% Define a nonlinear ODE
ode = D2y + 0.5*Dy + sin(y) == cos(2*t);

% Step 1: Convert to first-order system
[V, Subs] = odeToVectorField(ode);
% V = [Y[2]; cos(2*t) - sin(Y[1]) - Y[2]/2]
% Subs = [y; Dy]  (the state variable substitutions)

% Step 2: Generate a MATLAB function handle
odefun = matlabFunction(V, 'Vars', {'t', 'Y'});
% Creates: @(t,Y)[Y(2);-sin(Y(1))+cos(t.*2.0)-Y(2)./2.0]

% Step 3: Solve numerically with ode45
tspan = [0 20];
y0 = [1; 0];    % Initial conditions: y(0)=1, y'(0)=0
[tSol, ySol] = ode45(odefun, tspan, y0);

% Step 4: Plot results
plot(tSol, ySol(:,1))
xlabel('t')
ylabel('y(t)')
title('Nonlinear ODE Solution')
```

**Key Notes on odeToVectorField:**
- Only works with quasi-linear ODEs (highest derivative appears linearly)
- Cannot handle `y''(t)^2 = ...` or `sin(y''(t)) = ...`
- Parameters can remain symbolic; pass them through `matlabFunction` with `'Vars'`

## Parameterized ODE Solving

```matlab
syms y(t) a b

ode = diff(y,t,2) + a*diff(y,t) + b*y == 0;
[V, S] = odeToVectorField(ode);

% Keep a and b as parameters
odefun = matlabFunction(V, 'Vars', {'t', 'Y', 'a', 'b'});

% Solve for specific parameter values
a_val = 0.5; b_val = 4;
[tSol, ySol] = ode45(@(t,Y) odefun(t, Y, a_val, b_val), [0 20], [1; 0]);
```

## Troubleshooting

**Issue**: `dsolve` returns empty
- **Cause**: No closed-form solution exists.
- **Fix**: Use `odeToVectorField` + `matlabFunction` + `ode45` pipeline above.

**Issue**: `odeToVectorField` errors
- **Cause**: ODE is not quasi-linear (highest derivative doesn't appear linearly).
- **Fix**: Manually rewrite the system as a first-order system.

**Issue**: `dsolve` returns complex exponentials for an underdamped system
- **Cause**: MATLAB preserves the complex conjugate-pair form (`exp((-a+bi)*t)`) rather than converting to sinusoidal form.
- **Fix**: Use `real(sol)` before plotting or numeric evaluation. For a symbolic sinusoidal form, apply `rewrite(sol, 'sin')` before substituting numeric values.

----

Copyright 2026 The MathWorks, Inc.
