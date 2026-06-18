# Unit Conversion Guide

## Universal Signature

All Aerospace Toolbox unit conversion functions share the same calling pattern:

```matlab
output = convXXX(value, 'fromUnit', 'toUnit')
```

- `value` can be scalar, vector, or matrix (element-wise conversion)
- Unit strings are case-sensitive — use exactly as listed below

## Complete Unit String Tables

### Length — `convlength`

| String | Unit |
|--------|------|
| `'ft'` | Feet |
| `'m'` | Meters |
| `'km'` | Kilometers |
| `'in'` | Inches |
| `'naut mi'` | Nautical miles |

### Velocity — `convvel`

| String | Unit |
|--------|------|
| `'ft/s'` | Feet per second |
| `'m/s'` | Meters per second |
| `'km/s'` | Kilometers per second |
| `'in/s'` | Inches per second |
| `'km/h'` | Kilometers per hour |
| `'mph'` | Miles per hour |
| `'kts'` | Knots (nautical miles per hour) |
| `'ft/min'` | Feet per minute |

### Angle — `convang`

| String | Unit |
|--------|------|
| `'deg'` | Degrees |
| `'rad'` | Radians |
| `'rev'` | Revolutions (full turns) |

### Acceleration — `convacc`

| String | Unit |
|--------|------|
| `'ft/s^2'` | Feet per second squared |
| `'m/s^2'` | Meters per second squared |
| `'km/s^2'` | Kilometers per second squared |
| `'in/s^2'` | Inches per second squared |
| `'km/h-s'` | Kilometers per hour per second |
| `'mph/s'` | Miles per hour per second |
| `'G''s'` | Standard gravitational acceleration (note escaped quote) |

### Angular Acceleration — `convangacc`

| String | Unit |
|--------|------|
| `'deg/s^2'` | Degrees per second squared |
| `'rad/s^2'` | Radians per second squared |
| `'rpm/s'` | Revolutions per minute per second |

### Angular Velocity — `convangvel`

| String | Unit |
|--------|------|
| `'deg/s'` | Degrees per second |
| `'rad/s'` | Radians per second |
| `'rpm'` | Revolutions per minute |

### Force — `convforce`

| String | Unit |
|--------|------|
| `'N'` | Newtons |
| `'lbf'` | Pounds-force |

### Mass — `convmass`

| String | Unit |
|--------|------|
| `'kg'` | Kilograms |
| `'lbm'` | Pounds-mass |
| `'slug'` | Slugs |

### Pressure — `convpres`

| String | Unit |
|--------|------|
| `'Pa'` | Pascals |
| `'psi'` | Pounds per square inch |
| `'psf'` | Pounds per square foot |
| `'atm'` | Standard atmospheres |

### Temperature — `convtemp`

| String | Unit |
|--------|------|
| `'K'` | Kelvin |
| `'R'` | Rankine |
| `'F'` | Fahrenheit |
| `'C'` | Celsius |

### Density — `convdensity`

| String | Unit |
|--------|------|
| `'kg/m^3'` | Kilograms per cubic meter |
| `'slug/ft^3'` | Slugs per cubic foot |
| `'lbm/ft^3'` | Pounds-mass per cubic foot |
| `'lbm/in^3'` | Pounds-mass per cubic inch |

## Chaining Conversions

For derived units not directly supported, chain conversions:

```matlab
% Convert force from lbf to N, then to kN
force_lbf = 500;
force_N = convforce(force_lbf, 'lbf', 'N');   % to Newtons
force_kN = force_N / 1000;                     % scale to kN
```

## Common Gotchas

- **`'G''s'` requires escaped quote** — in MATLAB strings, use two single quotes: `convacc(1, 'G''s', 'm/s^2')`
- **`'naut mi'` has a space** — easy to forget
- **`convtemp` is not a simple scale** — Celsius/Fahrenheit have offsets, not just ratios
- **Unit strings are case-sensitive** — `'Pa'` works, `'pa'` does not
- **`convang` vs `deg2rad`/`rad2deg`** — both work; `convang` is consistent with the family, `deg2rad` is shorter for the common case

## When to Use `convXXX` vs MATLAB Built-ins

| Task | Use | Reason |
|------|-----|--------|
| Degrees ↔ radians only | `deg2rad` / `rad2deg` | Shorter, clearer intent |
| Any other unit conversion | `convXXX` family | Only option, consistent API |
| Mixed unit pipeline | `convXXX` throughout | Consistency, self-documenting |

----

Copyright 2026 The MathWorks, Inc.

----
