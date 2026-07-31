---
name: matlab-analyze-antenna-structures
description: >
  Design and analyze electrically large antenna structures using MATLAB Antenna Toolbox.
  Covers reflector antennas (parabolic, Cassegrain, Gregorian, offset, corner, cylindrical,
  spherical, custom STL), reflectarrays and reconfigurable intelligent surfaces (RIS),
  antennas installed on platforms (vehicles, aircraft, ships, satellites), and radar cross
  section (RCS) analysis. Includes solver selection (MoM-PO, PO, MoM, FMM), mesh control,
  and GPU acceleration. Use when the user wants to design a dish/reflector antenna,
  reflectarray, analyze an antenna on a platform, or compute RCS.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Antenna Structure Design and Analysis

Design, analyze, and visualize electrically large antenna structures — reflector antennas,
reflectarrays/RIS, platform-installed antennas, and radar cross section — using MATLAB
Antenna Toolbox with appropriate EM solvers for each problem class.

## When to Use

**Reflector antennas**
- Design a parabolic dish, satellite dish, or prime-focus reflector
- Design a Cassegrain or Gregorian dual-reflector system
- Design an offset-fed reflector (no blockage)
- Design a corner reflector, cylindrical or spherical reflector
- Use reflectorCalculator for trade studies
- Import custom reflector geometry from STL files

**Reflectarrays and RIS**
- Design a reflectarray antenna with unit cell phase control
- Design a reconfigurable intelligent surface (RIS) with quantized phases
- Characterize unit cell reflection phase (S-curve)
- Synthesize an aperture phase distribution for beam steering
- Verify pattern via pattern multiplication

**Installed antennas on platforms**
- Mount an antenna on a vehicle, aircraft, ship, satellite, or large structure
- Analyze installed antenna patterns, coupling, or efficiency
- Load platform geometry from STL/STEP/IGES files
- Generate platform geometry programmatically

**Radar cross section**
- Compute monostatic or bistatic RCS
- Analyze RCS of a platform, antenna, or array
- Compare RCS across polarizations (HH, VV, HV, VH)
- Compute RCS of a dielectric target

## When NOT to Use

- Designing standalone antenna elements or arrays (no platform) — use `matlab-design-antennas`
- Optimizing antenna dimensions with SADEA/TR-SADEA — use `matlab-design-antennas`
- Impedance matching, measured antenna objects, RF propagation, or SAR — use `matlab-integrate-antennas`
- A flat `reflector` backing a dipole — use `matlab-design-antennas` (catalog element)

## Must-Follow Rules

### Reflectors
- **Set Exciter BEFORE design()** — `design(obj, freq)` takes two arguments only for reflectors
- **`cavity` is NOT a valid exciter** — it will error
- **`reflectorCorner` and `reflectorCylindrical` have no `SolverType` property** — always MoM
- **Array as exciter:** design the array first, assign to Exciter, do NOT call design() on reflector afterward

### Reflectarrays
- **`infiniteArray` only supports pcbStack with exactly 3 layers** (metal-dielectric-metal)
- **Set `BoardThickness` before `Layers`** on pcbStack — order matters
- **Feed offset:** Use `[Lp/4, 0, 1, 3]` — not `[0 0 1 3]`
- **Always unwrap phase** with `unwrap()` and normalize magnitude (peak = 1)
- **Pattern multiplication adds dB** — element pattern (dB) + array factor (dB), NOT linear multiplication

### Installed Antennas
- **`installedAntenna` only supports pure metal antennas** — no dielectric substrates
- **Platform `Units` must be explicit** — defaults to "mm" but ElementPosition is always in meters
- **Set `ElementPosition` before `Element`** for multi-element setups
- **Always mesh explicitly before analysis** — uncontrolled density causes inaccurate results

### RCS
- **One of azimuth or elevation must be scalar** for monostatic sweeps
- **Dielectric targets require FMM solver** — PO and MoM will error
- **`UseFileAsMesh = true`** required for dielectric .mat files
- **PO fails at grazing incidence** — returns artificially low values (~-250 dBsm)

### Solver Selection (All Workflows)
- **Default:** MoM-PO for installed/reflectors, PO for RCS
- **Use FMM for:** closed bodies, concave features, dielectric targets
- **Verify FMM convergence** with `solver()` then `convergence()` after analysis
- **Mesh density:** lambda/10 for MoM/FMM, lambda/6 for MoM-PO, default for PO

## Workflow

### 1. Reflector Antenna Design

1. **Parse** — Identify reflector type, frequency, exciter, f/D ratio, constraints
2. **Create** — Set exciter first (if non-default), then call `design(obj, freq)`
3. **Customize** — Adjust Radius, FocalLength, FeedOffset for custom f/D
4. **Analyze** — Pattern, gain, beamwidth, impedance
5. **Report** — Key metrics with units, f/D ratio, aperture in wavelengths

For trade studies, use `reflectorCalculator` first (instant), then `createAntenna` for full-wave.

### 2. Reflectarray / RIS Design

1. **Design unit cell** — Parameterized `pcbStack` (3 layers) with variable patch size
2. **Characterize S-curve** — Sweep patch size via `planeWaveExcitation` + `infiniteArray` + `EHfields`
3. **Synthesize aperture phase** — Compute required phase (path delay + beam steering gradient)
4. **Map phase to geometry** — Invert S-curve via interpolation; quantize for RIS
5. **Build geometry** — `conformalArray` with unique elements at each position
6. **Verify pattern** — Element pattern + array factor via `patternCustom`

### 3. Installed Antenna Analysis

1. **Create platform** — Load from STL/STEP/IGES or generate programmatically
2. **Install element(s)** — Set Platform, ElementPosition, Element, SolverType
3. **Mesh** — `mesh(ant, MaxEdgeLength=lambda/N)` per solver guidelines
4. **Analyze** — Pattern, impedance, S-parameters (coupling), efficiency
5. **Report** — Metrics with units; verify FMM convergence if used

### 4. RCS Analysis

1. **Create target** — Load platform from file or use antenna/array object directly
2. **Select solver** — PO (default, fast), MoM (small, accurate), FMM (dielectric/concave)
3. **Compute** — `rcs(obj, freq, az, el, Polarization=..., Solver=...)`
4. **Report** — Peak RCS (dBsm), angular location, polarization

## Key Classes

| Class | Purpose |
|-------|---------|
| `reflectorParabolic` | Prime-focus parabolic dish |
| `cassegrain` / `gregorian` | Symmetric dual-reflector systems |
| `cassegrainOffset` / `gregorianOffset` | Offset dual-reflector (no blockage) |
| `reflectorCorner` | Corner reflector (90/60/45 deg) |
| `reflectorCylindrical` / `reflectorSpherical` | Fan-beam / wide-scan reflectors |
| `customDualReflectors` | Custom STL reflector surfaces |
| `reflectorCalculator` | Gaussian-beam analytical design (R2026a) |
| `installedAntenna` | Antenna mounted on conducting platform |
| `platform` | 3D geometry loader (STL/STEP/IGES) |
| `infiniteArray` | Periodic boundary conditions for unit cells |
| `planeWaveExcitation` | Plane wave illumination for S-curve/RCS |
| `conformalArray` | Arbitrary element positions (reflectarray geometry) |
| `pcbStack` | Unit cell structure (3-layer for reflectarrays) |
| `rcs` | Radar cross section function |

## Conventions

### Coding Standards
- 4-space indentation, lowerCamelCase variables, UpperCamelCase Name-Value args
- `"double quotes"` for strings, `fprintf` for formatted output
- Do not add titles to Antenna Toolbox plots (`show`, `pattern`, `rcs` auto-plot)
- **Do** add titles to manual `plot`, `imagesc`, `subplot`, and `TitleTop` to `polarpattern`
- Show all plots in separate figures. Include units in all output.

### Script-First Workflow
For design, analysis, or sweep tasks — write code to `.m` files, run via `run_matlab_file`, iterate by editing and re-running. Use inline `evaluate_matlab_code` for quick one-off checks.

### References

| Load when... | Reference |
|-------------|-----------|
| Designing any reflector antenna (parabolic, dual, corner, custom STL) | `references/reflector-antennas.md` |
| Designing a reflectarray or RIS (unit cells, S-curve, phase synthesis) | `references/reflectarrays.md` |
| Installing antennas on platforms (STL loading, multi-element, conformalArray workaround) | `references/installed-antennas.md` |
| Computing monostatic/bistatic RCS (polarization, dielectric targets, GPU) | `references/rcs-analysis.md` |
| Choosing between MoM-PO, PO, MoM, FMM for any application | `references/solver-selection.md` |

----

Copyright 2026 The MathWorks, Inc.
