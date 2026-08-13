---
name: matlab-integrate-antenna
description: >
  Integrate antennas into RF systems using MATLAB Antenna Toolbox and RF Toolbox.
  Covers impedance matching network design (L/Pi/Tee topologies, evaluation parameters,
  Richards transformation), measured antenna creation (E-field, directivity-only, EmbeddedE,
  ffsReader import), RF propagation and site planning (txsite/rxsite, coverage, SINR,
  ray tracing, link budget), and SAR estimation (birdcage+Phantom, conformalArray+Custom3D,
  direct EHfields). Use when the user wants to match an antenna, create a measuredAntenna,
  compute coverage or signal strength, perform ray tracing, or estimate SAR.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Antenna Integration and Deployment

Integrate designed antennas into RF systems -- impedance matching, data exchange via
measuredAntenna, RF propagation/site planning, and SAR compliance -- using MATLAB
Antenna Toolbox and RF Toolbox.

## When to Use

**Impedance matching**
- Match an antenna to 50 ohm (or other impedance)
- Improve return loss or VSWR
- Design L, Pi, or Tee matching network
- Convert lumped matching to distributed (Richards transformation)
- Compare 2-element vs 3-element bandwidth

**Measured antenna creation**
- Create a `measuredAntenna` from pattern data or simulation
- Use an antenna with `txsite`/`rxsite` for propagation
- Import antenna data from CST (.ffs) or HFSS (.ffd)
- Steer a beam with phase shifts on a measured array
- Use a measuredAntenna as element in a larger array

**RF propagation and site planning**
- Compute signal strength, coverage, or path loss between sites
- Analyze SINR, interference, or frequency reuse
- Perform ray tracing for 5G/mmWave propagation
- Determine link budget or link closure
- Plan wireless network transmitter/receiver placement

**SAR estimation**
- Compute SAR from an antenna near or inside biological tissue
- Assess RF exposure compliance (FCC/ICNIRP limits)
- Model a birdcage coil for MRI SAR analysis
- Compute point SAR or mass-averaged SAR (1g/10g)
- Design an implantable antenna and estimate SAR

## When NOT to Use

- Designing antenna elements or arrays (geometry, optimization) -- use `matlab-design-antenna`
- Reflector antennas, reflectarrays, installed antennas, or RCS -- use `matlab-analyze-antenna-structures`

## Must-Follow Rules

### Matching Networks
- **Set `CenterFrequency` BEFORE `LoadImpedance`** for frequency-dependent loads -- errors otherwise
- **Property is `Bandwidth`** not `BandWidth` -- case-sensitive
- **`addEvaluationParameter` requires all 5 args:** parameter, comparison, targetdB, band, weight
- **Prefer `sparameters(ant, freqRange)` as load** over raw antenna object (avoids repeated EM solves)
- **Default to `Components = 2`** unless fractional BW > 5% (then use 3)

### Measured Antennas
- **Always transpose after `meshgrid`** for az-fast ordering -- silently wrong patterns otherwise
- **`txsite`/`rxsite` require `E = []`** -- errors if E-field data is present
- **Only `patternMultiply` works** when measuredAntenna is the Element of an array (not `pattern`)
- **`CalculateTotalField = true`** is required for EmbeddedE workflow
- **EHfields returns 3-by-P** -- transpose to P-by-3 for measuredAntenna

### RF Propagation
- **Do not call `show(tx)` in headless environments** -- use analysis functions directly
- **`sigstrength(rxArray, txArray, pm)`** returns numTX-by-numRX matrix
- **`pathloss` with ray tracing returns cell arrays** -- sum powers in linear domain
- **`SurfaceMaterial`** is for cartesian scenes; `BuildingsMaterial`/`TerrainMaterial` for geographic
- **Ray tracing requires buildings or scene data** -- no value without geometry

### SAR
- **`EHfields` expects 3-by-M** -- pass `obsPoints'`
- **`dielectric` class enforces `LossTangent <= 0.03`** -- only birdcage.Phantom and direct EHfields bypass
- **Always validate** SAR with power balance check (efficiency vs SAR integral)
- **Always normalize** to a known input power (typically 1W accepted)
- **`conformalArray` rejects intersecting geometries** -- cannot place antenna inside tissue

## Workflow

### 1. Impedance Matching

1. **Parse** -- Identify load (antenna, impedance, file), frequency, bandwidth, topology
2. **Create** -- Set `CenterFrequency` FIRST, then `LoadImpedance`, `Bandwidth`, `Components`
3. **Evaluate** -- `addEvaluationParameter` for gammain or Gt goals
4. **Inspect** -- `circuitDescriptions` returns ranked candidates
5. **Visualize** -- `rfplot` (S11/gain), `smithplot` (impedance transformation)
6. **Export** -- `exportCircuits` for RF Toolbox circuit; `richards` for distributed elements

### 2. Measured Antenna Creation

1. **Parse** -- Identify source antenna/array, frequency, intended use case
2. **Select workflow** -- E-field, Directivity-only, EmbeddedE, element-in-array, or ffsReader
3. **Generate grid** -- Spherical grid with correct transpose for az-fast ordering
4. **Extract data** -- `EHfields` (3-by-P, transpose to P-by-3) or `pattern` (el-by-az, transpose)
5. **Build** -- Construct measuredAntenna with correct property combination
6. **Verify** -- Compare pattern against original antenna/array

### 3. RF Propagation & Site Planning

1. **Parse** -- Identify analysis type (coverage, SINR, ray tracing, link budget), frequency, environment
2. **Create sites** -- `txsite`/`rxsite` with location, antenna, frequency, power
3. **Select model** -- Choose propagation model based on environment
4. **Analyze** -- `sigstrength`, `coverage`, `sinr`, `raytrace`, or `los`
5. **Report** -- Signal strength (dBm), path loss (dB), SINR (dB), link margin

### 4. SAR Estimation

1. **Select approach** -- birdcage+Phantom, conformalArray+Custom3D, or direct EHfields
2. **Build tissue model** -- Phantom struct, shape.Custom3D with catalog material, or post-processing
3. **Compute E-fields** -- `EHfields(ant, freq, obsPoints')` (3-by-M format)
4. **Calculate SAR** -- Apply formula with tissue sigma and rho; normalize to input power
5. **Validate** -- Power balance check (efficiency method vs SAR integral)

## Key Classes

| Class | Purpose |
|-------|---------|
| `matchingnetwork` | L/C matching network synthesis and ranking |
| `measuredAntenna` | Wraps field/pattern data for interoperability |
| `txsite` / `rxsite` | Transmitter/receiver sites for propagation |
| `propagationModel` | Path loss model selection (freespace, raytracing, etc.) |
| `propagationData` | Import/visualize RF measurement data |
| `siteviewer` | Map visualization (geographic or cartesian) |
| `birdcage` | MRI coil with Phantom support |
| `conformalArray` | Arbitrary element positions (antenna + dielectric body) |
| `shape.Custom3D` | Passive dielectric scatterer for SAR |
| `ffsReader` | Import CST .ffs far-field data (R2026a+) |

## Conventions

### Coding Standards
- 4-space indentation, lowerCamelCase variables, UpperCamelCase Name-Value args
- `"double quotes"` for strings, `fprintf` for formatted output
- Do not add titles to Antenna Toolbox plots (`pattern`, `show`, `rfplot`, `smithplot`)
- **Do** add titles to manual `plot`, `scatter3`, `imagesc` figures
- Do not call `show(tx)` without siteviewer in headless environments
- Show all plots in separate figures. Include units in all output.

### Script-First Workflow
For design, analysis, or sweep tasks -- write code to `.m` files, run via `run_matlab_file`, iterate by editing and re-running. Use inline `evaluate_matlab_code` for quick one-off checks.

### References

| Load when... | Reference |
|-------------|-----------|
| Designing a matching network (topologies, evaluation, export, Richards) | `references/matching-networks.md` |
| Creating measuredAntenna (E-field, directivity, EmbeddedE, ffsReader, HFSS) | `references/measured-antennas.md` |
| RF propagation, coverage, SINR, ray tracing, link budget, path loss | `references/rf-propagation.md` |
| Computing SAR (birdcage, conformalArray, EHfields, power balance) | `references/sar-estimation.md` |

----

Copyright 2026 The MathWorks, Inc.
