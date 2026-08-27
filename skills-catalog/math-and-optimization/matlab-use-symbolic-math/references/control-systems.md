# Control Systems Patterns

Reference patterns for deriving transfer functions, converting to state-space, and performing Laplace-domain analysis with Symbolic Math Toolbox. All patterns require numeric conversion before passing to Control System Toolbox functions (`tf`, `ss`, `bode`).

## Transforms

```matlab
syms t s x w n z

% Laplace transform
laplace(exp(-2*t), t, s)             % 1/(s + 2)
laplace(sin(3*t), t, s)             % 3/(s^2 + 9)
laplace(t^2*exp(-t), t, s)          % 2/(s + 1)^3

% Inverse Laplace
ilaplace(1/(s^2 + 4), s, t)         % sin(2*t)/2

% Fourier transform
fourier(exp(-t^2), t, w)

% Inverse Fourier
ifourier(2*exp(-abs(w)), w, t)

% Z-transform
ztrans(2^n, n, z)                    % z/(z - 2)
iztrans(z/(z - 2), z, n)            % 2^n
```

## Deriving Transfer Functions from Differential Equations

This is a very common use case. The approach is:
1. Define the ODE symbolically
2. Take the Laplace transform
3. Solve for Y(s)/U(s) with zero initial conditions

```matlab
%% Transfer function of a mass-spring-damper system
% m*y'' + c*y' + k*y = F(t)
syms y(t) F(t) s Y U m c k

% Define the ODE
ode = m*diff(y,t,2) + c*diff(y,t) + k*y == F;

% Take Laplace transform
ode_laplace = laplace(ode, t, s);

% Substitute Laplace-domain variables and zero initial conditions
ode_s = subs(ode_laplace, ...
    [laplace(y(t), t, s), laplace(F(t), t, s), ...
     subs(diff(y(t), t), t, 0), y(0)], ...
    [Y, U, 0, 0]);

% Solve for Y in terms of U
Y_sol = solve(ode_s, Y);

% Transfer function G(s) = Y(s)/U(s)
G = simplify(Y_sol / U)
% Result: 1/(m*s^2 + c*s + k)

%% Convert to numeric tf object (requires Control System Toolbox)
% Substitute numeric parameter values first
G_num = subs(G, [m, c, k], [1, 2, 5]);
[num_coeffs, den_coeffs] = numden(G_num);
num_poly = sym2poly(num_coeffs);
den_poly = sym2poly(den_coeffs);
tf_sys = tf(num_poly, den_poly);
```

## Alternative: Direct Symbolic Transfer Function

If you already know the transfer function form, work directly in the s-domain:

```matlab
syms s K wn zeta

% Standard second-order system
G = K * wn^2 / (s^2 + 2*zeta*wn*s + wn^2);

% Substitute numeric values
G_numeric = subs(G, [K, wn, zeta], [1, 10, 0.5]);

% Convert to tf object
[n, d] = numden(G_numeric);
sys = tf(sym2poly(n), sym2poly(d));
```

## Converting Symbolic State-Space to Numeric (A, B, C, D Matrices)

```matlab
syms s Y U

% From transfer function to state-space
G = 6 / (s^3 + 6*s^2 + 11*s + 6);

% Method 1: Use Control System Toolbox directly
[n, d] = numden(G);
sys_tf = tf(sym2poly(n), sym2poly(d));
sys_ss = ss(sys_tf);  % Converts to state-space
[A, B, C, D] = ssdata(sys_ss);

% Method 2: Use symbolic ODE + odeToVectorField
syms y(t) u(t)
Dy = diff(y,t);
D2y = diff(y,t,2);
D3y = diff(y,t,3);
DEq = D3y + 6*D2y + 11*Dy + 6*y == 6*u;

[V, Subs] = odeToVectorField(DEq);
% V contains the right-hand sides of the first-order system
% Subs shows the substitution variables
% From V, you can read off the A and B matrices for linear systems
```

## Laplace Transform for Control Systems Analysis

A full workflow for going from time-domain ODE to Bode plot:

```matlab
%% System: RLC circuit
% L*di/dt + R*i + (1/C)*integral(i dt) = V(t)
% In terms of charge q: L*q'' + R*q' + q/C = V(t)

syms t s q(t) V(t) L R C Q Vs

% Define ODE
ode = L*diff(q,t,2) + R*diff(q,t) + q/C == V;

% Take Laplace transform
ode_L = laplace(ode, t, s);

% Substitute for zero ICs and Laplace variables
ode_s = subs(ode_L, ...
    [laplace(q(t),t,s), laplace(V(t),t,s), q(0), subs(diff(q(t),t),t,0)], ...
    [Q, Vs, 0, 0]);

% Solve for transfer function G(s) = Q(s)/Vs(s)
Q_sol = solve(ode_s, Q);
G = simplify(Q_sol / Vs)
% Result: 1/(R*s + L*s^2 + 1/C)

% Substitute numeric values and create tf
G_num = subs(G, [L, R, C], [1e-3, 100, 1e-6]);
[n, d] = numden(G_num);
sys = tf(sym2poly(n), sym2poly(d));
bode(sys)
```

## Working with the Laplace Transform Manually

The `laplace` function does NOT accept initial conditions directly (unlike `dsolve`). You must substitute them manually:

```matlab
syms y(t) s Y

% ODE: y'' + 3y' + 2y = 0, y(0) = 1, y'(0) = -1
ode = diff(y,t,2) + 3*diff(y,t) + 2*y == 0;

% Take Laplace transform
ode_L = laplace(ode, t, s);

% The result contains laplace(y(t),t,s), y(0), and D(y)(0)
% Substitute known values
ode_s = subs(ode_L, ...
    [laplace(y(t),t,s), y(0), subs(diff(y(t),t), t, 0)], ...
    [Y, 1, -1]);

% Solve for Y(s)
Y_sol = solve(ode_s, Y);

% Inverse Laplace to get y(t)
y_sol = ilaplace(Y_sol, s, t);
% simplify if needed
y_sol = simplify(y_sol)
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `laplace(ode)` with initial conditions | `laplace` does not accept ICs; use `subs` after |
| `tf(sym_num, sym_den)` | `tf` does not accept symbolic; convert with `sym2poly` first |

## Checklist

- [ ] Converting symbolic to numeric (`double`, `sym2poly`, `matlabFunction`) before passing to Control System Toolbox functions (`tf`, `ss`, `bode`)

## Troubleshooting

**Issue**: `laplace` returns unevaluated `laplace(...)` in the output
- **Cause**: Transform cannot be computed in closed form.
- **Try**: Simplify the input expression, or use numeric methods.

----

Copyright 2026 The MathWorks, Inc.
