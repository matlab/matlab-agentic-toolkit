# Solver Selection Guide

This guide covers solver selection across all structure types: reflectors, installed antennas, reflectarrays, and RCS targets.

## Solver Overview

| Solver | Speed | Accuracy | Memory | Best For |
|--------|-------|----------|--------|----------|
| `"MoM-PO"` | Fast | Good | Low | Large open platforms, reflectors > 5lambda |
| `"PO"` | Fastest | Approximate | Lowest | RCS of large convex metal, quick estimates |
| `"MoM"` | Slowest | Best | O(N^2) | Small structures < 5lambda |
| `"FMM"` | Moderate | Good | Medium | Large closed/concave bodies, dielectrics |

## Decision Tree

```
Is the structure < 5 wavelengths?
├── Yes → MoM (full-wave, direct solver)
└── No → Is it a closed/concave body with multiple reflections?
    ├── Yes → FMM
    └── No → Is it for RCS computation?
        ├── Yes → PO (default for rcs())
        └── No → MoM-PO (default for installed/reflector)
```

## By Application

### Reflector Antennas

| Solver | Use When |
|--------|----------|
| `"MoM-PO"` | Default for `reflectorParabolic`, `cassegrain`, `gregorian`, `reflectorSpherical` |
| `"PO"` | Very large dishes (> 50 lambda), quick estimates |
| `"MoM"` | Small reflectors (`reflectorCorner`, `reflectorCylindrical` -- no SolverType property) |
| `"FMM"` | When MoM-PO is insufficient (complex feed interactions) |

**Note:** `reflectorCorner` and `reflectorCylindrical` do NOT have a `SolverType` property -- they always use MoM.

### Installed Antennas

| Solver | Use When |
|--------|----------|
| `"MoM-PO"` | Default. Large open platforms (plates, vehicle panels) |
| `"FMM"` | Closed bodies (fuselage, sphere), concave features, cavities |
| `"MoM"` | Wavelength-scale platforms only (impractical for large ones) |

**MoM-PO limitation:** Does not model multiple reflections. Concave regions and re-entrant corners need FMM.

### RCS Analysis

| Solver | Use When |
|--------|----------|
| `"PO"` | Default. Large convex metal structures |
| `"MoM"` | Small structures needing full-wave accuracy |
| `"FMM"` | Dielectric targets (required), concave bodies, full-wave on large structures |

**PO limitations:**
- No edge diffraction
- No multiple reflections
- Fails at grazing incidence (returns ~-250 dBsm)
- Supports GPU acceleration (`UseGPU="on"`)

**Dielectric targets require FMM.** PO and MoM error on pure dielectric structures.

### Reflectarrays

Reflectarray unit cells use `infiniteArray` which has its own periodic solver (Floquet mode expansion). No explicit `SolverType` selection needed -- it uses the periodic Green's function internally. Control accuracy via `numSummationTerms(ia, N)` (default N=15).

## FMM Configuration

### Formulations

| Formulation | Geometry | Notes |
|-------------|----------|-------|
| EFIE | Open or closed | Default, works everywhere. Only user-settable formulation. |

**Note:** CFIE exists as an internal class (`em.solvers.CFIE`) but is not user-assignable — `SolverType` only accepts `"MoM"`, `"MoM-PO"`, `"FMM"`, `"PO"`. MFIE does not exist in R2026a.

### Tuning Parameters

```matlab
ant.SolverType = "FMM";
s = solver(ant);
s.Iterations = 200;         % max GMRES iterations (default: 100)
s.RelativeResidual = 1e-4;  % convergence tolerance
s.Precision = 2e-4;         % FMM precision
```

### Convergence Verification

Always verify after FMM analysis:

```matlab
Z = impedance(ant, freq);
s = solver(ant);
figure; convergence(s);
```

If not converged:
1. Increase `Iterations` (200 or 500)
2. Refine mesh (lambda/12 or finer)

## Meshing Guidelines

| Solver | Density | Notes |
|--------|---------|-------|
| MoM-PO | ~lambda/6 | PO region less sensitive |
| FMM | ~lambda/10 | 10 elements per wavelength |
| MoM | ~lambda/10 | Standard MoM requirement |
| PO (RCS) | Default mesh adequate | Insensitive to mesh density |

```matlab
c = physconst("LightSpeed");
lambda = c / freq;

% FMM or MoM
mesh(ant, MaxEdgeLength=lambda/10);

% MoM-PO (coarser acceptable)
mesh(ant, MaxEdgeLength=lambda/6);
```

## Electrical Size Guide

| Size (D/lambda) | Recommended | Notes |
|-----------------|-------------|-------|
| < 5 | MoM | Direct solver, exact |
| 5 - 50 | MoM-PO | Hybrid, good balance |
| > 50 | PO or FMM | PO fastest, FMM for accuracy |

Use `memoryEstimate(ant, freq)` before running large analyses. Note: `memoryEstimate` does not support `installedAntenna` — use it on the standalone element or platform to estimate.

## Solver by Application Table

| Application | Solver Used By |
|-------------|----------------|
| `rcs()` function | PO (default), MoM, FMM |
| `installedAntenna` | MoM-PO (default), MoM, FMM |
| `reflectorParabolic` et al. | MoM-PO (default), PO, FMM |
| `reflectorCorner` | MoM only (no SolverType) |
| `reflectorCylindrical` | MoM only (no SolverType) |
| `infiniteArray` (reflectarray) | Periodic solver (internal) |

----

Copyright 2026 The MathWorks, Inc.
