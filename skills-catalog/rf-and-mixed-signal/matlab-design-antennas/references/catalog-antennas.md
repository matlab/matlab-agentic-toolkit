# Catalog Antenna Design & Pattern Analysis

## Supported Antenna Types

| Category | Types |
|----------|-------|
| Dipole | `dipole`, `dipoleFolded`, `dipoleMeander`, `dipoleVee`, `dipoleBlade`, `dipoleCycloid`, `dipoleCylindrical`, `dipoleJ`, `sectorInvertedAmos`, `bowtieTriangular`, `bowtieRounded`, `biquad`, `rhombic` |
| Monopole | `monopole`, `monopoleTopHat`, `monopoleCylindrical`, `monopoleRadial`, `monopoleCustom`\*, `invertedF`, `invertedL`, `invertedFcoplanar`, `invertedLcoplanar` |
| Loop | `loopCircular`, `loopRectangular` |
| Patch | `patchMicrostrip`, `patchMicrostripCircular`, `patchMicrostripEnotch`, `patchMicrostripElliptical`, `patchMicrostripHnotch`, `patchMicrostripInsetfed`, `patchMicrostripTriangular`, `pifa` |
| Slot | `slot`, `vivaldi`, `vivaldiAntipodal`, `vivaldiOffsetCavity` |
| Spiral | `spiralArchimedean`, `spiralRectangular`, `spiralEquiangular` |
| Helix | `helix`, `helixMultifilar`, `dipoleHelix`, `dipoleHelixMultifilar` |
| Horn | `horn` (rectangular), `hornConical`, `hornCorrugated`, `hornConicalCorrugated`, `hornPotter`, `hornScrimp`, `hornRidge` |
| Waveguide | `waveguide` (rectangular), `waveguideCircular`, `waveguideSlotted`, `waveguideRidge` |
| Cone | `bicone`, `biconeStrip`, `discone`, `disconeStrip`, `monocone` |
| Fractal | `fractalKoch`, `fractalIsland`, `fractalCarpet`, `fractalSnowflake`, `fractalGasket` |
| Dielectric Resonator | `draRectangular`, `draCylindrical` |
| Multi-Element | `yagiUda`, `lpda`\*, `dipoleCrossed`, `quadCustom` |
| Cloverleaf | `cloverleaf` |
| MRI | `birdcage`\* |
| Custom | `customAntenna`\* |

\* Does not support `design()` — see "Antennas Without design()" below.

## Informal Name Mapping

- "patch antenna" / "microstrip patch" -> `patchMicrostrip`
- "circular patch" -> `patchMicrostripCircular`
- "inset-fed patch" -> `patchMicrostripInsetfed`
- "Yagi" / "Yagi-Uda" -> `yagiUda`
- "LPDA" / "log-periodic" -> `lpda`
- "horn" / "rectangular horn" -> `horn`
- "conical horn" -> `hornConical`
- "ridged horn" -> `hornRidge`
- "folded dipole" -> `dipoleFolded`
- "meander dipole" / "meander line" -> `dipoleMeander`
- "crossed dipole" -> `dipoleCrossed`
- "J-pole" / "J antenna" -> `dipoleJ`
- "IFA" / "inverted-F" -> `invertedF`
- "ILA" / "inverted-L" -> `invertedL`
- "PIFA" -> `pifa`
- "bowtie" -> `bowtieTriangular`
- "Vivaldi" / "TSA" -> `vivaldi`
- "multifilar helix" -> `helixMultifilar`
- "DRA" -> `draRectangular` (or `draCylindrical` if cylindrical)
- "birdcage coil" -> `birdcage`

## Design Workflow

```matlab
freq = 2.4e9;
ant = patchMicrostrip;
ant.Substrate = dielectric("FR4");   % set substrate BEFORE design()
ant = design(ant, freq);
figure; show(ant);
```

## Antenna Systems (Structures with Exciters)

Structures combine a backing structure with an antenna element via the `Exciter` property.

### Cavity Structures

| Structure | Default Exciter | Substrate | `design()` |
|-----------|-----------------|-----------|------------|
| `cavity` | `dipole` | Yes | Yes |
| `cavityCircular` | `dipole` | Yes | Yes |

### Planar Reflectors

| Structure | Default Exciter | Substrate | `design()` |
|-----------|-----------------|-----------|------------|
| `reflector` | `dipole` | Yes | Yes |
| `reflectorCircular` | `dipole` | Yes | Yes |
| `reflectorCorner` | `dipole` | No | Yes |
| `reflectorGrid` | `dipole` | No | Yes |
| `reflectorCylindrical` | `dipole` | No | Yes |

### Curved Reflectors

| Structure | Default Exciter | `design()` |
|-----------|-----------------|------------|
| `reflectorParabolic` | `dipole` | Yes |
| `reflectorSpherical` | `dipole` | Yes |
| `cassegrain` | `hornConical` | Yes |
| `cassegrainOffset` | `hornConical` | Yes |
| `gregorian` | `hornConical` | Yes |
| `gregorianOffset` | `hornConical` | Yes |
| `customDualReflectors` | `hornConical` | **No** |

### System Workflow

```matlab
ant = cavity;
ant.Exciter = dipole;
ant.Substrate = dielectric("FR4");
ant = design(ant, freq);

ant = reflectorParabolic;
ant.Exciter = helix;
ant = design(ant, freq);
```

### Probe Feed (EnableProbeFeed)

```matlab
ant = cavity;
ant.Substrate = dielectric("FR4");
ant.Exciter = dipole;
ant = design(ant, freq);
ant.EnableProbeFeed = 1;
if ant.Height <= ant.Spacing
    ant.Height = ant.Spacing + 0.005;
end
```

## Antennas Without design() Support

| Antenna | Fallback |
|---------|----------|
| `birdcage` | Set properties manually |
| `customAntenna` | Build from shapes (see custom-antennas.md) |
| `lpda` | Set properties manually |
| `monopoleCustom` | Set properties manually |

## Substrate Support

Set substrate **before** calling `design()`:

```matlab
ant = patchMicrostrip;
ant.Substrate = dielectric("FR4");
ant = design(ant, freq);
```

**Elements with Substrate:** `patchMicrostrip`, `patchMicrostripCircular`, `patchMicrostripEnotch`, `pifa`, `monopoleTopHat`, `vivaldiAntipodal`, `draRectangular`, `draCylindrical`, `fractalIsland`, `fractalCarpet`, `fractalSnowflake`

**Built-in materials:** `"FR4"` (er=4.8), `"Teflon"` (er=2.1), `"Air"` (er=1.0). Use `openDielectricCatalog` for more.

**Custom substrates:**
```matlab
sub = dielectric(Name="MySubstrate", EpsilonR=2.2, LossTangent=0.0009, Thickness=0.787e-3);
ant.Substrate = sub;
```

**Note:** `design()` may adjust substrate `Thickness`. Always display final properties after design.

**Meshing for substrate antennas:**
```matlab
c = physconst("LightSpeed");
lambda = c / freq;
mesh(ant, MaxEdgeLength=lambda/8);
```

## S-Parameter Interpolation Sweep

Use `SweepOption="interp"` only when antenna has a `Substrate` property:

```matlab
if isprop(ant, "Substrate") && ~isempty(ant.Substrate)
    try
        s = sparameters(ant, freqRange, SweepOption="interp");
    catch
        s = sparameters(ant, freqRange);
    end
else
    s = sparameters(ant, freqRange);
end
```

`SweepOption` is only supported by `sparameters`, not `impedance`.

## Pattern Analysis

### 3D Radiation Pattern

```matlab
figure; pattern(ant, freq);
```

### 2D Cuts with Antenna Metrics

**Angle vector sizes:** `patternAzimuth` returns 361 values over -180:1:180. `patternElevation` also returns 361 values over -180:1:180 (NOT -90:90). Always use `-180:1:180` for both.

```matlab
elCut = 0;
D = patternAzimuth(ant, freq, elCut);
az = -180:1:180;   % 361 values — matches patternAzimuth output
figure;
pp = polarpattern(az, D);
pp.AntennaMetrics = true;
pp.TitleTop = sprintf("Azimuth Pattern (El = %g°) at %.2f GHz", elCut, freq/1e9);
```

```matlab
azCut = 0;
D = patternElevation(ant, freq, azCut);
el = -180:1:180;   % 361 values — patternElevation range is -180:180, NOT -90:90
figure;
pp = polarpattern(el, D);
pp.AntennaMetrics = true;
pp.TitleTop = sprintf("Elevation Pattern (Az = %g°) at %.2f GHz", azCut, freq/1e9);
```

### Pattern Comparison

```matlab
D1 = patternAzimuth(ant1, freq, 0);
D2 = patternAzimuth(ant2, freq, 0);
az = -180:1:180;
figure;
pp = polarpattern(az, D1);
add(pp, az, D2);
pp.AntennaMetrics = true;
pp.LegendLabels = {'Antenna 1', 'Antenna 2'};  % cell array of char vectors
```

### Multi-Frequency Pattern

```matlab
freqs = [freq1, freq2, freq3];
az = -180:1:180;
D1 = patternAzimuth(ant, freqs(1), 0);
figure;
pp = polarpattern(az, D1);
for i = 2:numel(freqs)
    D = patternAzimuth(ant, freqs(i), 0);
    add(pp, az, D);
end
pp.AntennaMetrics = true;
pp.LegendLabels = arrayfun(@(f) sprintf('%.2f GHz', f/1e9), freqs, UniformOutput=false);
```

## Polarization Analysis

```matlab
% Axial ratio (for CP antennas: helix, spiral, cloverleaf)
figure; axialRatio(ant, freq, 0, 0:1:360);

% Polarization-specific pattern
figure; pattern(ant, freq, Type="directivity", Polarization="RHCP");
% Available: "combined", "LHCP", "RHCP", "H", "V"
```

## Key Metric Functions

```matlab
bw = beamwidth(ant, freq, azimuthAngle, elevationAngles);
[peakVal, peakAz, peakEl] = peakRadiation(ant, freq);
```

## polarpattern Properties

| Property | Description | Values |
|----------|-------------|--------|
| `AntennaMetrics` | Show beamwidth, sidelobes, F/B ratio | `true`/`false` |
| `Peaks` | Number of peak markers | integer |
| `LegendLabels` | Labels for overlaid datasets | cell array of char vectors |
| `AngleLim` | Angle range displayed | `[min max]` |
| `MagnitudeLim` | Magnitude axis limits | `[min max]` |
| `NormalizeData` | Normalize to peak | `true`/`false` |

## Analysis Template

```matlab
% TEMPLATE — not executable (replace <design_frequency> with actual value)
freq = <design_frequency>;
bw = 0.2 * freq;
freqRange = linspace(freq - bw/2, freq + bw/2, 51);

figure; impedance(ant, freqRange);

if isprop(ant, "Substrate") && ~isempty(ant.Substrate)
    try s = sparameters(ant, freqRange, SweepOption="interp");
    catch, s = sparameters(ant, freqRange); end
else
    s = sparameters(ant, freqRange);
end
figure; rfplot(s);

figure; pattern(ant, freq);

Z = impedance(ant, freq);
fprintf("Impedance: %.2f + j%.2f ohm\n", real(Z), imag(Z));
```

## Frequency Interpretation

- Parse units: MHz, GHz, Hz. Default to Hz if no unit given.
- For band names ("ISM band", "S-band"), use the standard center frequency.
- Supported range: 10 kHz to 200 GHz.

----

Copyright 2026 The MathWorks, Inc.
