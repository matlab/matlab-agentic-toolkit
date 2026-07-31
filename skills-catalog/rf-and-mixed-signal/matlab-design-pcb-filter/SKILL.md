---
name: matlab-design-pcb-filter
description: "Bandpass, lowpass, bandstop filter design — hairpin, coupled-line, combline, stub, SIW for frequency selection and harmonic rejection. TRIGGER: user asks to design, create, or analyze any RF filter (bandpass, lowpass, highpass, bandstop, hairpin, coupled-line, combline, stub, SIW). Invoke BEFORE writing code — filter class names differ from what you would guess. SKIP: EM simulation/S-parameter extraction of an existing filter (use matlab-analyze-em), general PCB layout assembly (use matlab-assemble-pcb-layout), material/stackup setup only (use matlab-manage-pcb-material), optimization sweeps (use matlab-optimize-pcb-design)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Designing RF Filters

## When to Use

- Designing bandpass filters (coupled-line, hairpin, open-loop, combline, interdigital, SIW)
- Designing lowpass filters (stepped-impedance)
- Designing bandstop or notch filters (spurline, stub-based)
- Extracting coupling matrices from measured S-parameter data (measuredFilter)
- Selecting a filter topology for a given bandwidth, selectivity, or size requirement

## When NOT to Use

- Designing transmission lines for impedance control — use `matlab-design-pcb-txline`
- Designing couplers or splitters — use `matlab-design-pcb-coupler`
- Designing passive components (inductors, capacitors, baluns) — use `matlab-design-pcb-passive`
- Setting up substrate or conductor materials — use `matlab-manage-pcb-material`
- Optimizing filter dimensions after design — use `matlab-optimize-pcb-design`

## Typical Workflow

1. **Before:** `matlab-manage-pcb-material` — set up substrate and conductor
2. **This skill:** Design the filter (catalog object or custom geometry)
3. **Check mesh/memory:** `memoryEstimate(obj, fc, 'RetainMesh', true)` — inspect auto-mesh density before committing to a full solve
4. **After:** `matlab-analyze-em` — validate S-parameters → `matlab-optimize-pcb-design` — tune dimensions → `matlab-write-pcb-layout` — export Gerber

## Quick Reference — Filter Selection

| Filter Object | Type | Poles | Best For |
|---------------|------|-------|----------|
| `filterCoupledLine` | Bandpass | 2–8 | General microstrip BPF |
| `filterHairpin` | Bandpass | 2–8 | Compact BPF, folded resonators |
| `filterOpenLoop` | Bandpass | 4/6/8 | Compact quasi-elliptic |
| `filterCombline` | Bandpass | 2–6 | Narrow-band, high-Q |
| `filterInterdigital` | Bandpass | 2–8 | Wideband, good stopband |
| `filterStepImpedanceLowPass` | Lowpass | 3–9 | Distributed LPF |
| `filterStub` | LP/HP/BS | N stubs | Flexible stub topology |
| `filterSpurline` | Bandstop | 1–2 | Compact notch filter |
| `SIWFilter` | Bandpass | 2–6 | High-Q waveguide-in-PCB |
| `measuredFilter` | Bandpass | N | Model extraction from measurements |

## Bandpass Filters

### Coupled-Line Filter

```matlab
f = filterCoupledLine;
f = design(filterCoupledLine, 3e9);    % Design at 3 GHz
show(f);
sp = sparameters(f, linspace(1e9, 5e9, 101), 'SweepOption', 'interp');
rfplot(sp);
```

Key properties: `FilterOrder`, `CoupledLineLength`, `CoupledLineWidth`, `CoupledLineSpacing`, `PortLineLength`, `PortLineWidth`.

### Hairpin Filter

Folded coupled-line resonators for compact size:

```matlab
f = design(filterHairpin, 3e9);
show(f);
memoryEstimate(f, 3e9, 'RetainMesh', true);  % Check mesh density before solving
sp = sparameters(f, linspace(1e9, 5e9, 101), 'SweepOption', 'interp');
rfplot(sp);
```

Key properties: `FilterOrder`, `CoupledLineLength`, `CoupledLineWidth`, `CoupledLineSpacing`, `PortLineLength`, `PortLineWidth`, `Spacing`, `ResonatorOffset`, `FeedOffset`.

### Chebyshev Response

Pass `FilterType` and `RippleFactor` to `design()` for equiripple passband response:

```matlab
f = design(filterHairpin, 1.8e9, FBW=10, FilterType='Chebyshev', RippleFactor=0.5);
```

`FilterType` options: `'Butterworth'` (default), `'Chebyshev'`. `FBW` sets fractional bandwidth (%). `RippleFactor` sets passband ripple in dB (default 0.5) — only applies to Chebyshev.

### Fifth-Order Hairpin

```matlab
f = filterHairpin;
f.FilterOrder = 5;
f = design(f, 2.4e9);
show(f);
```

### Open-Loop Filter

Quasi-elliptic response with cross-coupling:

```matlab
f = filterOpenLoop;
f.NumPoles = 6;
f.FeedOffset = 0.5e-3;
show(f);
sp = sparameters(f, linspace(1e9, 5e9, 101), 'SweepOption', 'interp');
rfplot(sp);
```

**Key Properties:** `NumPoles` (4/6/8), `ResonatorLength`, `ResonatorWidth`, `SplitGap`, `GapHorizontal`, `GapVertical`, `FeedOffset`, `CoupledResonatorGap`, `QuadrupletGap`, `QuadrupletOffset`.

### Combline Filter

Short-circuited resonators, excellent for narrow-band. **Note:** `filterCombline` does not have a `design` function — set properties manually:

```matlab
f = filterCombline;
f.FilterOrder = 3;
f.Height = 1.6e-3;
show(f);
```

**Key Properties:** `FilterOrder`, `ResonatorLength` (scalar or vector), `ResonatorWidth`, `ResonatorSpacing` (scalar or vector), `ResonatorOffset`, `FeedOffset`, `Capacitor` (loading capacitance — distinctive to combline).

### Interdigital Filter

Alternating short-circuited resonators, wideband. **Note:** `filterInterdigital` does not have a `design` function — set properties manually:

```matlab
f = filterInterdigital;
f.FilterOrder = 4;
f.Height = 1.6e-3;
show(f);
sp = sparameters(f, linspace(3e9, 7e9, 101), 'SweepOption', 'interp');
rfplot(sp);
```

**Key Properties:** `FilterOrder`, `ResonatorLength` (scalar or vector), `ResonatorWidth` (scalar or vector), `ResonatorSpacing` (scalar or vector), `ResonatorOffset`, `ViaDiameter` (scalar or vector — distinctive to interdigital), `FeedOffset`, `IsShielded`, `Connector`.

## Lowpass Filters

### Stepped-Impedance Lowpass

```matlab
f = filterStepImpedanceLowPass;
f = design(filterStepImpedanceLowPass, 2.5e9);
show(f);
sp = sparameters(f, linspace(0.1e9, 5e9, 101), 'SweepOption', 'interp');
rfplot(sp);
```

Key properties: `FilterOrder`, `HighZLineWidth`, `LowZLineWidth`, `HighZLineLength`, `LowZLineLength`.

## Bandstop / Notch Filters

### Spurline Filter

Compact notch using coupled-line section on one side:

```matlab
f = filterSpurline;
show(f);
sp = sparameters(f, linspace(1e9, 6e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

Double spurline for deeper rejection:

```matlab
f = filterSpurline;
f.LineType = 'Double';
show(f);
```

**Key Properties:** `LineType` (`'Single'`/`'Double'`), `CoupledLineLength`, `CoupledLineWidth`, `CoupledLineSpacing`, `LineGap` (gap between coupled line and output line — distinctive to spurline), `IsShielded`, `Connector`.

### Stub Filters (Open/Short)

The `filterStub` object supports open-circuit stubs (bandstop) and short-circuit stubs (highpass):

```matlab
f = filterStub;
f.StubLength = [6e-3 6e-3 6e-3];
f.StubWidth = [0.5e-3 0.5e-3 0.5e-3];
f.StubOffsetX = [-6e-3 0 6e-3];
f.StubShort = [0 0 0];         % 0=open (bandstop), 1=short (highpass)
f.StubDirection = [0 0 0];     % 0=below, 1=above trace
f.SeriesLineWidth = 1.8e-3;
f.SeriesLineLength = 12e-3;
show(f);
```

**Key Properties:** `StubLength` (vector), `StubWidth` (vector), `StubFeedOffsetX` (vector), `StubShort` (0=open, 1=short; vector), `StubDirection` (0=down, 1=up; vector), `SeriesLineLength`, `SeriesLineWidth`, `IsShielded`, `Connector`.

### Radial Stub

```matlab
rs = stubRadialShunt;
rs = design(stubRadialShunt, 5e9);
show(rs);
```

## SIW Bandpass Filter

`SIWFilter` uses `NumResonators` (not `FilterOrder`), and `Substrate` is read-only (set via internal resonator objects):

```matlab
f = SIWFilter;
f.NumResonators = 4;
show(f);
sp = sparameters(f, linspace(8e9, 14e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

## Measured Filter Extraction

`measuredFilter` extracts a coupled-resonator circuit model (coupling matrix, external Q, unloaded Q) from measured or simulated 2-port S-parameter data. This enables filter tuning, diagnosis, and comparison against ideal synthesis targets.

**Key Properties:**
- `Sparameters` — 2-port S-parameters data (`sparameters` object)
- `FilterOrder` — Number of resonators in the model
- `CenterFrequency` — Passband center frequency (Hz)
- `BandWidth` — 3-dB bandwidth (Hz)
- `CouplingMatrix` — Extracted N+2 coupling matrix (populated after extraction)
- `QualityFactor` — Unloaded quality factor (populated after `qualityfactor()`)

**Key Methods:**
- `residue(mf)` — Extract lowpass admittance residues and poles from S-parameter data
- `transversalMat(mf)` — Calculate transversal coupling matrix from residues
- `canonicalCouplingMat(mf)` — Rotate transversal matrix to canonical (folded) form
- `optimize(mf)` — Isospectral optimization of the coupling matrix
- `sparameters(mf, freq)` — Synthesize S-parameters from the extracted circuit model
- `qualityfactor(mf)` — Calculate unloaded quality factor

### Complete Workflow

```matlab
% Step 1: Load measured S-parameters and inspect visually
S_meas = sparameters('measured_filter.s2p');
rfplot(S_meas);
% Identify center frequency and bandwidth from the plot

% Step 2: Create measuredFilter with matching initial guess
mf = measuredFilter(Sparameters=S_meas, ...
    FilterOrder=8, ...
    CenterFrequency=2114.6e6, ...
    BandWidth=9.6e6);

% Step 3: Extract residues and poles
residue(mf);

% Step 4: Build transversal matrix, then rotate to canonical form
transversalMat(mf);
M = canonicalCouplingMat(mf);
disp(mf.CouplingMatrix);

% Step 5: Optimize coupling matrix (isospectral flow)
mf = optimize(mf);

% Step 6: Compare extracted model vs measured data
freq = linspace(2.08e9, 2.15e9, 501);
S_model = sparameters(mf, freq);
rfplot(S_meas); hold on;
rfplot(S_model, '--');
legend('Measured', 'Extracted Model');

% Step 7: Quality factor
Q = qualityfactor(mf);
disp(mf.QualityFactor);
```

## Custom Filter Assembly

For topologies not in the catalog, build with `pcbComponent`:

```matlab
% Example: custom 2-pole open-loop filter from shape primitives
sub = dielectric("FR4");
sub.Thickness = 1.6e-3;
cond = metal("Copper");

% Build resonator shapes using traceLine, traceRectangular, Boolean ops
% (see matlab-assemble-pcb-layout skill)

pcb = pcbComponent;
pcb.Layers = {filterShape, sub, groundPlane};
pcb.BoardShape = groundPlane;
pcb.BoardThickness = sub.Thickness;
pcb.Conductor = cond;
pcb.FeedDiameter = feedWidth/2;
pcb.FeedLocations = [x1 y1 1 3; x2 y2 1 3];
```

## Multi-Layer Filters

All filter catalog objects support multi-layer dielectrics:

```matlab
f = design(filterCoupledLine, 3e9);
sub = dielectric("FR4", "Teflon");
sub.Thickness = [0.8e-3 0.4e-3];   % Set Thickness BEFORE assigning to filter
f.Substrate = sub;
f.Height = 1.2e-3;
show(f);
```

## Filter Selection Guide

| Need | Recommended Filter | Notes |
|---|---|---|
| Bandpass, compact | `filterHairpin` | Folded resonators save board area |
| Bandpass, standard | `filterCoupledLine` | Supports `design()`, easiest starting point |
| Bandpass, high selectivity | `filterInterdigital` | Good stopband rejection, wideband |
| Bandpass, capacitively loaded | `filterCombline` | Narrow-band, high-Q, short resonators |
| Bandpass, cross-coupling / TZs | `filterOpenLoop` | Quasi-elliptic, transmission zeros; supports `design()` |
| Bandpass, SIW technology | `SIWFilter` | High-Q waveguide-in-PCB |
| Lowpass, stepped impedance | `filterStepImpedanceLowPass` | Supports `design()` |
| Bandstop, notch | `filterSpurline` | Very compact, single or double |
| Bandpass/Bandstop, stub-based | `filterStub` | Flexible open/short stub topology; **no `design()`** |
| Model extraction from data | `measuredFilter` | Coupling matrix from measurements |

## Design Adjustments

| Problem | Adjust | Direction |
|---|---|---|
| Passband too wide | `FilterOrder`, `Spacing` | Increase order, decrease spacing |
| Insertion loss too high | `Conductor` thickness | Use real metal, increase thickness |
| Rejection too shallow | `FilterOrder` | Increase |
| Center freq shifted | Re-run `design(filt, freq)` | -- |
| Return loss poor | `FeedOffset`, `FeedType` | Tune feed position |

## Pitfalls

1. **Use interpolating sweep for S-parameters**: Always use `sparameters(obj, freq, 'SweepOption', 'interp')` for MoM solves. Direct sweeps solve at every frequency point individually and are significantly slower.

2. **Check mesh density before solving**: Catalog filters generate dense auto-meshes that dominate runtime. Always run `memoryEstimate(obj, fc, 'RetainMesh', true)` before `sparameters()`. If memory is excessive, coarsen: `mesh(obj, 'MaxEdgeLength', lambda/6)`. See `matlab-analyze-em` for full mesh inspection workflow.

3. **FilterOrder vs NumPoles**: Some objects use `FilterOrder`, others use `NumPoles`. Check the specific object's properties.

4. **PortLineLength affects response**: The port feed line length contributes phase and can shift the filter's apparent center frequency. Ensure sufficient length for proper excitation.

5. **design() sets all dimensions**: After `design(obj, fc)`, all geometric parameters are overwritten. Customize properties after calling `design`, not before.

6. **Coupled-line filter bandwidth**: Controlled by `CouplingSpacing` — smaller gaps = tighter coupling = wider bandwidth, but fabrication-limited.

7. **StubShort convention**: In `filterStub`, `StubShort=0` means open-ended stub (creates bandstop); `StubShort=1` means short-circuited (creates highpass). This is counterintuitive.

8. **No design() for combline/interdigital/stub**: `filterCombline`, `filterInterdigital`, and `filterStub` do not support `design()`. Set dimensions manually based on resonator theory.

9. **SIWFilter Substrate is read-only**: You cannot directly set `SIWFilter.Substrate`. The substrate is controlled through the internal resonator and transmission line element objects.

10. **measuredFilter initial guess matters.** The `CenterFrequency` and `BandWidth` must closely match the actual passband of the measured data. Poor initial values cause `residue()` to extract incorrect poles. Inspect the S-parameter data visually first.

11. **ResonatorSpacing vector length = FilterOrder - 1**: For combline, interdigital, and hairpin filters, `ResonatorSpacing` specifies gaps *between* resonators. An N-th order filter has N resonators but only N-1 gaps. Do NOT pass N elements — pass N-1.

12. **GroundPlaneLength is read-only on most filters**: `GroundPlaneLength` and `GroundPlaneWidth` are auto-computed from resonator dimensions on `filterCombline`, `filterHairpin`, and `filterInterdigital`. Do NOT attempt to set them.

## Related Skills

- `matlab-manage-pcb-material` — Substrate selection for filter performance
- `matlab-analyze-em` — S-parameter extraction and field visualization
- `matlab-optimize-pcb-design` — Optimizing filter dimensions
- `matlab-assemble-pcb-layout` — Custom filter topologies via pcbComponent
- `matlab-design-pcb-passive` — Resonators, baluns, split-ring structures for filters

----

Copyright 2026 The MathWorks, Inc.
