# Symunit Workflow

Use `symunit` to work with physical units and constants symbolically. Never hard-code physical constants as numbers.

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `u = symunit` | Access the unit system | R2017a |
| `newUnit(name, definition)` | Create a custom unit | R2017a |
| `removeUnit(name)` | Remove a custom unit | R2017a |
| `unitConvert(expr, targetUnit)` | Convert to target units | R2017a |
| `separateUnits(expr)` | Split into numeric value and unit | R2017a |
| `unitConversionFactor(from, to)` | Get scalar conversion factor | R2017a |
| `checkUnits(expr)` | Verify dimensional consistency | R2017a |

## Physical Constants

Access constants via `u = symunit`:

| Constant | symunit name | Description |
|----------|-------------|-------------|
| Planck constant | `u.hc` | h |
| Reduced Planck constant | `u.hbar` | h-bar |
| Speed of light | `u.c_0` | c in vacuum |
| Electron mass | `u.m_e` | m_e |
| Proton mass | `u.m_p` | m_p |
| Elementary charge | `u.e_SI` | e |
| Boltzmann constant | `u.kB` | k_B |
| Gravitational constant | `u.G_SI` | G |
| Avogadro number | `u.N_A` | N_A |
| Vacuum permittivity | `u.epsilon_0` | epsilon_0 |
| Vacuum permeability | `u.mu_0` | mu_0 |

**Important:** Do NOT guess constant names. If unsure, check with:
```matlab
u = symunit;
disp(u.hc)  % Planck constant
```

## Pattern: Basic Computation with Units

```matlab
u = symunit;

% Define quantities with units
mass = 5 * u.kg;
velocity = 10 * u.m / u.s;

% Compute kinetic energy
KE = 0.5 * mass * velocity^2;

% Convert to desired units
KE_joules = unitConvert(KE, u.J);

% Extract numeric value
[num, unit] = separateUnits(KE_joules);
fprintf('KE = %g J\n', double(num))
```

## Pattern: Create a Custom Dimensionless Unit

```matlab
u = symunit;

% Create a dimensionless custom unit (e.g., photon, count, particle)
newUnit('photon', 1);

% Refresh symunit to pick up the new unit
u = symunit;
flux = 1e15 * u.photon / (u.cm^2 * u.s);

% Convert and extract numeric result
flux_SI = unitConvert(flux, u.photon / (u.m^2 * u.s));

% Clean up when done (pass the symbolic unit, not a string)
removeUnit(u.photon);
```

## Pattern: Photon Energy Calculation

```matlab
u = symunit;

% Physical constants from symunit (NOT hard-coded)
h = u.hc;    % Planck constant
c = u.c_0;   % Speed of light

% Wavelength
lambda = 532 * u.nm;

% Energy per photon: E = hc/lambda
E = h * c / lambda;
E_eV = unitConvert(E, u.eV);
[numE, ~] = separateUnits(E_eV);
fprintf('Photon energy: %.4f eV\n', double(numE))
```

## Pattern: Unit Conversion

```matlab
u = symunit;

% Length conversion
dist = 26.2 * u.mi;
dist_km = unitConvert(dist, u.km);

% Get just the conversion factor
factor = unitConversionFactor(u.mi, u.km);
% factor = 1.609344
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `hbar = 1.0546e-34` | Loses symbolic precision, error-prone value | `u = symunit; hbar = u.hbar;` |
| `u.planck_constant` | Invalid name — will error | `u.hc` (Planck constant) or `u.hbar` (reduced) |
| `u.speed_of_light` | Invalid name | `u.c_0` |
| `newUnit('photon', 1, 'Dimension', 1)` | Too many arguments — newUnit takes exactly 2 | `newUnit('photon', 1)` |
| `syms photon positive` for a unit | Creates a symbolic variable, not a unit | `newUnit('photon', 1)` |
| Forgetting to refresh `symunit` after `newUnit` | New unit won't be accessible | `u = symunit;` after `newUnit(...)` |
| `removeUnit('photon')` with a string | Requires symbolic unit in R2026a | `removeUnit(u.photon)` |

----

Copyright 2026 The MathWorks, Inc.

----
