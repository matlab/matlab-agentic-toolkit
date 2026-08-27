# Plotting and Displaying Symbolic Expressions

Reference patterns for plotting symbolic expressions and displaying results in the MATLAB® Live Editor and the command window.

## Displaying Symbolic Results

```matlab
syms x
f = (x^2 + 3*x + 2)/(x^3 - 1);

% In Live Scripts: use disp() for typeset mathematical rendering
disp(f)                          % Renders as formatted math in Live Editor

% displayFormula — renders a labeled equation in Live Scripts
displayFormula(f == 0)           % Displays: (x^2 + 3*x + 2)/(x^3 - 1) == 0
displayFormula(diff(f, x))       % Displays the derivative as typeset math

% pretty() prints ASCII art to the Command Window — useful in plain .m scripts
pretty(f)                        % Text-based formatted output

% For LaTeX export
latex(f)                         % Returns LaTeX string representation
```

**In Live Scripts, use `disp()` or `displayFormula()` instead of `pretty()`.**
Live Scripts render `disp()` output in mathematical typeset. `displayFormula` additionally renders symbolic equations and expressions as labeled, formatted equations — ideal for showing intermediate derivation steps. The `pretty()` function produces plain-text ASCII formatting designed for the command window. Reserve `pretty()` for plain `.m` scripts or command window sessions.

## 2-D Plotting

Symbolic Math Toolbox provides dedicated plotting functions that accept symbolic expressions directly. **Use these instead of converting to numeric data and calling `plot()`** — they automatically handle domain selection, singularity avoidance, and adaptive sampling.

```matlab
syms x
f = sin(x)/x;

% fplot — the symbolic equivalent of plot()
fplot(f)                              % Auto-selects [-5, 5] range
fplot(f, [-10 10])                    % Specify range
fplot([sin(x), cos(x)], [0 2*pi])   % Multiple expressions

% Implicit equations (curves defined by f(x,y) = 0)
syms x y
fimplicit(x^2 + y^2 == 1)           % Unit circle
fimplicit(x^2 - y^2 == 1, [-3 3 -3 3])  % Hyperbola with range

% Polar coordinates
syms theta
fpolarplot(1 + cos(theta))           % Cardioid
```

## 3-D Plotting

```matlab
syms x y u v

% Surface plot
fsurf(sin(x)*cos(y))                 % Auto range
fsurf(sin(x)*cos(y), [-pi pi -pi pi])

% Mesh plot
fmesh(x^2 - y^2, [-3 3 -3 3])

% Contour plot
fcontour(x^2 + y^2, [-3 3 -3 3], 'LevelList', 1:5)

% 3-D parametric curve
fplot3(cos(u), sin(u), u, [0 6*pi])

% 3-D implicit surface (f(x,y,z) = 0)
syms x y z
fimplicit3(x^2 + y^2 + z^2 == 4)    % Sphere of radius 2
```

## Animation

```matlab
syms x t
% Create animated plot of a traveling wave
fanimator(@fplot, sin(x - t), [-2*pi 2*pi])
playAnimation
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `pretty(f)` in Live Scripts | Use `disp(f)` — Live Scripts render it as typeset math |
| Manually converting symbolic to numeric arrays for plotting | Use `fplot(f)` directly — it accepts symbolic expressions with no conversion |

**Additional notes:**
- `fplot` accepts symbolic expressions directly — no numeric grid or `matlabFunction` conversion needed.
- For symbolic expressions, always use `fplot(f)` / `fsurf` / `fmesh` — they handle domain selection and adaptive sampling automatically.
- All `f*` plotting functions support standard MATLAB graphics options like `'LineWidth'`, `'Color'`, etc.
- Use `fimplicit` for equations — `fplot` only handles explicit functions `y = f(x)`.

## Checklist

- [ ] Using `disp()` instead of `pretty()` when generating Live Scripts
- [ ] Using `fplot`/`fsurf`/`fmesh`/`fcontour`/`fimplicit` for symbolic plotting instead of manual numeric conversion

----

Copyright 2026 The MathWorks, Inc.
