---
name: matlab-design-antennas
description: >
  Design antennas, arrays, and PCB antennas using MATLAB Antenna Toolbox.
  Covers catalog antenna design and pattern analysis, custom antenna construction
  (customAntenna + shape.*), PCB antenna design (pcbStack + antenna.*), finite and
  infinite array design, AI-accelerated design exploration (AIAntenna, patternFromAI),
  and optimization (SADEA/TR-SADEA). Use when the user wants to design, create, model,
  analyze, optimize, or fabricate an antenna or array.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Antenna and Array Design

Design, analyze, and optimize antennas and arrays using MATLAB Antenna Toolbox —
from catalog elements to custom shapes, PCB fabrication, AI-accelerated exploration,
and surrogate-assisted optimization.

## When to Use

**Catalog antenna design**
- Design a standard antenna at a frequency (dipole, patch, horn, helix, Yagi, etc.)
- Analyze radiation pattern (3D, 2D cuts, polarization, beamwidth, sidelobes)
- Compute impedance, S-parameters, or return loss
- Set substrate material before design
- Compare patterns across antennas or frequencies

**Custom antenna design**
- Build non-catalog antennas from geometric primitives (shape.*)
- Construct 3D structures (waveguides, horns, cavities) via extrusion
- Import STL/CAD geometry and add feeds
- Configure delta-gap or probe feeds on custom structures

**PCB antenna design**
- Build multi-layer PCB antenna stackups (pcbStack)
- Create custom metal patterns with boolean operations (antenna.*)
- Configure probe, edge, or aperture-coupled feeds
- Export Gerber files for fabrication
- Convert catalog antennas to pcbStack

**Array design**
- Design linear, rectangular, circular, or conformal arrays
- Beam steering, amplitude tapering, grating lobe analysis
- Infinite array analysis (scan impedance, scan blindness, Floquet BC)
- MIMO/handset multi-antenna isolation and ECC
- Mutual coupling analysis

**AI-accelerated design**
- Rapid parametric sweeps with AIAntenna surrogate models
- Reconstruct 3D patterns from 2D slices (patternFromAI)
- Full-factorial design space exploration
- Export AI-tuned designs for full-wave validation

**Optimization**
- Optimize antenna dimensions for gain, bandwidth, SLL, or F/B ratio
- Built-in optimize() for catalog antennas with string objectives
- SADEA/TR-SADEA with custom evaluation functions for pcbStack/customAntenna
- Geometric constraints (linear and nonlinear)

## When NOT to Use

- Reflector antennas, reflectarrays, installed antennas, or RCS — use `matlab-analyze-antenna-structures`
- Impedance matching networks, measuredAntenna, RF propagation, or SAR — use `matlab-integrate-antennas`

## Must-Follow Rules

### Catalog Antennas
- **Prefer catalog antennas over `customAntenna`** — use `customAntenna` only when no catalog antenna or system antenna matches the requested geometry
- **Always use `design()`** unless user provides explicit dimensions or antenna lacks design() support
- **Set substrate BEFORE `design()`** — design() adapts dimensions to the substrate
- **Mesh at lambda/8** for substrate antennas after design() and before analysis
- **Use `SweepOption="interp"`** only with `sparameters` (not `impedance`) on substrate antennas

### Custom Antennas (customAntenna)
- **Use `shape.*` namespace** (NOT `antenna.*`) with `customAntenna`
- **All dimensions in meters** — not mm or cm
- **Always define a feed** — `customAntenna` without `createFeed` cannot be analyzed
- **Feed must be at a geometric discontinuity** — not middle of flat plate
- **Extrude first, rotate second** — `extrudeLinear` requires XY-plane shapes
- **Shapes are handle objects** — use `copy()` to preserve before transforming

### PCB Antennas (pcbStack)
- **Set `BoardThickness` BEFORE `Layers`** — otherwise dielectric gets wrong thickness
- **Use `antenna.*` namespace** (NOT `shape.*`) for pcbStack metal patterns
- **Layer indices are cell array positions** — in `{M,D,M}`, ground is index 3
- **`design()` does not work on pcbStack** — design catalog antenna first, then convert
- **Gerber `Filename` must be char** (`'single quotes'`), not "string"

### Arrays
- **Always pass element as 3rd argument** to `design(arr, freq, element)` — omitting resets to dipole
- **`AmplitudeTaper` for rectangularArray is column-major** order
- **Infinite arrays have no NumElements/ElementSpacing** — unit cell = ground plane size
- **Use `phaseShift()` for finite** steering, `ScanAzimuth/ScanElevation` for infinite

### AI Workflows
- **Use `design(..., ForAI=true)`** — direct `em.ai.AIAntenna()` constructor not supported
- **Only 12 antenna types** have pretrained AI models
- **Input slices for `patternFromAI` must be row vectors** with 1-degree integer spacing
- **Always validate** AI predictions with `exportAntenna` + full-wave simulation

### Optimization
- **Start from `design()`** to get physically reasonable initial dimensions
- **Tier 1 bounds: cell array** `{lb1,lb2; ub1,ub2}`, **Tier 2 bounds: numeric matrix** `[lb;ub]`
- **Negate metrics for maximization** in custom evaluation functions (SADEA minimizes)
- **Wrap custom eval in try/catch** — return 1e6 penalty for invalid geometry
- **Set `FrequencyRange` explicitly** for bandwidth optimization (default +/-5% may not match target)

## Workflow

### 1. Catalog Antenna Design

1. **Parse** — Identify antenna type, frequency, substrate, constraints
2. **Create** — Set substrate (if any), call `design(ant, freq)`
3. **Mesh** — `mesh(ant, MaxEdgeLength=lambda/8)` for substrate antennas
4. **Analyze** — Impedance, S-parameters, 3D pattern, 2D cuts with `polarpattern`
5. **Report** — Key metrics with units (Z, BW, gain, beamwidth)

### 2. Custom Antenna Design

1. **Build shapes** — `shape.*` primitives (Rectangle, Box, Cylinder, Polygon)
2. **Transform** — `translate`, `rotate`, `scale` (handle objects — copy first)
3. **Combine** — Boolean: `+` (union), `-` (subtract), `&` (intersect)
4. **Extrude** — `extrudeLinear` (taper) or `extrudeRotate` (revolution)
5. **Assemble** — `customAntenna(Shape=...)`, `createFeed(ant, loc, numEdges)`
6. **Mesh & analyze** — `mesh(ant, MaxEdgeLength=lambda/6)`, impedance, pattern

### 3. PCB Antenna Design

1. **Define stackup** — `pcbStack`, set `BoardThickness` FIRST, then `Layers`
2. **Create patterns** — `antenna.*` shapes with boolean operations
3. **Configure feed** — `FeedLocations = [x, y, sigLayer, gndLayer]`
4. **Analyze** — S-parameters (with `SweepOption="interp"`), pattern
5. **Export** — `gerberWrite` with PCBWriter, PCBServices, PCBConnectors

### 4. Array Design

1. **Build array** — Set type, size/elements, then `design(arr, freq, element)`
2. **Steer** — `phaseShift()` finite, `ScanAzimuth/ScanElevation` infinite
3. **Taper** — `AmplitudeTaper` (column-major for rectangular)
4. **Analyze** — `arrayFactor` (fast) → `patternMultiply` → `pattern` (accurate)
5. **Coupling** — `sparameters`, `correlation`, isolation metrics

### 5. AI-Accelerated Design

1. **Create** — `design(ant, freq, ForAI=true)` for supported types
2. **Explore** — `tunableRanges`, parametric sweep, `resonantFrequency`, `bandwidth`
3. **Validate** — `exportAntenna` + full-wave impedance/pattern
4. **Reconstruct** — `patternFromAI` from 2D slices (row vectors, 1-deg spacing)

### 6. Optimization

1. **Formulate** — Choose objective, design variables, bounds, constraints
2. **Select tier** — Catalog + built-in objective → Tier 1; else → Tier 2
3. **Run** — `optimize()` or `OptimizerSADEA`/`OptimizerTRSADEA`
4. **Extract** — `getBestMemberData`, `showConvergenceTrend`, `isConverged`
5. **Validate** — Full analysis sweep on optimized design

## Key Classes

| Class | Purpose |
|-------|---------|
| `design()` | Scale catalog antennas to frequency |
| `customAntenna` | Arbitrary geometry from shape.* primitives |
| `pcbStack` | Multi-layer PCB antenna with antenna.* shapes |
| `linearArray` / `rectangularArray` / `circularArray` | Finite arrays |
| `conformalArray` | Arbitrary element positions (MIMO, custom) |
| `infiniteArray` | Unit cell with Floquet BC |
| `em.ai.AIAntenna` | Pretrained surrogate for instant prediction |
| `patternFromAI` | 3D pattern from 2D slices |
| `optimize()` | Built-in SADEA for catalog antennas |
| `OptimizerSADEA` / `OptimizerTRSADEA` | Custom optimization |

## Conventions

### Coding Standards
- 4-space indentation, lowerCamelCase variables, UpperCamelCase Name-Value args
- `"double quotes"` for strings (except Gerber `Filename` which requires `'char'`)
- `fprintf` for formatted output
- Do not add titles to Antenna Toolbox plots (`pattern`, `show`, `rfplot`, `impedance`)
- **Do** add titles to manual `plot` figures and `TitleTop` to `polarpattern`
- Show all plots in separate figures. Include units in all output.
- Use `physconst("LightSpeed")` — never hardcode 3e8

### Script-First Workflow
For design, analysis, or sweep tasks — write code to `.m` files, run via `run_matlab_file`, iterate by editing and re-running. Use inline `evaluate_matlab_code` for quick one-off checks.

### References

| Load when... | Reference |
|-------------|-----------|
| Designing catalog antennas (types, design(), substrate, patterns) | `references/catalog-antennas.md` |
| Building custom antennas (shape.*, extrusion, feeds, substrate) | `references/custom-antennas.md` |
| Designing PCB antennas (pcbStack, layers, boolean, Gerber) | `references/pcb-antennas.md` |
| Designing arrays (finite, infinite, steering, taper, MIMO) | `references/arrays.md` |
| AI design exploration (AIAntenna, patternFromAI, surrogates) | `references/ai-antenna-workflows.md` |
| Optimizing antennas (SADEA, bounds, constraints, custom eval) | `references/optimization.md` |

----

Copyright 2026 The MathWorks, Inc.
