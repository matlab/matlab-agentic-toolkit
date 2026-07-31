# AI-Accelerated Antenna Design

## AIAntenna Overview

`em.ai.AIAntenna` creates a pretrained surrogate model of a catalog antenna. Once created:
- Tune geometric parameters with instant performance predictions (milliseconds vs. minutes)
- Explore full design space without MoM simulations
- Export tuned parameters to real antenna for full-wave validation

**Requirements:** Antenna Toolbox + Statistics and Machine Learning Toolbox

### Supported Antenna Types

| Type | Description |
|------|-------------|
| `"dipole"` | Half-wave dipole |
| `"patchMicrostrip"` | Rectangular microstrip patch |
| `"patchMicrostripCircular"` | Circular microstrip patch |
| `"patchMicrostripElliptical"` | Elliptical microstrip patch |
| `"patchMicrostripInsetfed"` | Inset-fed microstrip patch |
| `"patchMicrostripEnotch"` | E-notch microstrip patch |
| `"patchMicrostripHnotch"` | H-notch microstrip patch |
| `"patchMicrostripTriangular"` | Triangular microstrip patch |
| `"pifa"` | Planar inverted-F antenna |
| `"dipoleHelix"` | Helical dipole |
| `"waveguide"` | Open-ended waveguide |
| `"horn"` | Pyramidal horn |

**Only these 12 types** have pretrained AI models.

### Creation

Always use `design` with `ForAI=true`. The direct `em.ai.AIAntenna()` constructor is not supported.

```matlab
freq = 2.4e9;
antAI = design(patchMicrostrip, freq, ForAI=true);
```

### Core Workflow

```matlab
freq = 1e9;
antAI = design(horn, freq, ForAI=true);

defaults = defaultTunableParameters(antAI);
ranges = tunableRanges(antAI);
figure; show(antAI);

fRes = resonantFrequency(antAI);
[bw, fL, fU, matching] = bandwidth(antAI);
fprintf("Resonant: %.3f GHz, BW: %.1f MHz, %s\n", fRes/1e9, bw/1e6, matching);
```

### Tuning Parameters

Properties match catalog antenna dimensions:

```matlab
antAI.Length = 0.055;
antAI.Width = 0.075;
antAI.Height = 0.0012;

fRes = resonantFrequency(antAI);
[bw, fL, fU, matching] = bandwidth(antAI);
reset(antAI);  % restore defaults
```

### Tunable Ranges

```matlab
ranges = tunableRanges(antAI);           % default: "all" bounds
ranges = tunableRanges(antAI, "strict"); % tighter (higher accuracy)
ranges = tunableRanges(antAI, "loose");  % wider (may reduce accuracy)
```

Use `"strict"` for best accuracy.

### Peak Radiation and Beamwidth

```matlab
[peakGain, az, el] = peakRadiation(ai, freq);
[hpbw, angles, plane] = beamwidth(ai, freq);
```

### Parametric Sweep

```matlab
ranges = tunableRanges(ai, "strict");
lengthRange = linspace(ranges.Length(1), ranges.Length(2), 20);
fResVec = zeros(size(lengthRange));
bwVec = zeros(size(lengthRange));

for k = 1:numel(lengthRange)
    ai.Length = lengthRange(k);
    fResVec(k) = resonantFrequency(ai);
    bwVec(k) = bandwidth(ai);
end

figure;
yyaxis left; plot(lengthRange*1e3, fResVec/1e9, "-o"); ylabel("fRes (GHz)");
yyaxis right; plot(lengthRange*1e3, bwVec/1e6, "-s"); ylabel("BW (MHz)");
xlabel("Patch Length (mm)"); grid on;
title("Design Space: Patch Length vs. Performance");
```

### Export and Validation

```matlab
ant = exportAntenna(ai);
figure; impedance(ant, linspace(2e9, 3e9, 51));
figure; pattern(ant, 2.4e9);
```

### Full-Factorial Sweep

```matlab
a = 0.85:0.1:1.15;
kc = combinations(a, a, a, a, a);
k = table2array(kc);
% Loop: scale params by k(i,:), evaluate, filter results
```

### Matching Status Check

Always verify before trusting `resonantFrequency`:

```matlab
[~, ~, ~, matching] = bandwidth(antAI);
switch string(matching)
    case "Matched"
        fRes = resonantFrequency(antAI);
    case {"Almost", "Not Matched"}
        fRes = NaN;
end
```

### OptimizerTRSADEA with AIAntenna

```matlab
Bounds = [0.85*defaults; 1.15*defaults];
s = OptimizerTRSADEA(Bounds);
s.CustomEvaluationFunction = @myFitness;
s.GeometricConstraints = struct(A=[0 -1 0 0 1], b=0);
s.optimize(50);
bestData = s.getBestMemberData;
```

## patternFromAI Overview

Reconstructs a complete 3D radiation pattern from two orthogonal 2D slices using a trained neural network. Requires Antenna Toolbox + Deep Learning Toolbox (R2024a+).

### Input Format

| Argument | Size | Description |
|----------|------|-------------|
| `magVertSlice` | 1-by-360 or 1-by-361 | Vertical pattern magnitude (dBi) |
| `angleVertSlice` | 1-by-360 or 1-by-361 | Vertical plane angles (degrees) |
| `magHorizSlice` | 1-by-360 or 1-by-361 | Horizontal pattern magnitude (dBi) |
| `angleHorizSlice` | 1-by-360 or 1-by-361 | Horizontal plane angles (degrees) |

All inputs must be **row vectors**. Angles must be integer-valued with 1-degree spacing.

### Name-Value Arguments

| Name | Default | Description |
|------|---------|-------------|
| `AngleConvention` | `"phi-theta"` | `"phi-theta"` or `"az-el"` |
| `MinMaxMagnitude` | auto | `[min max]` for normalization |

### Workflow: From Simulated Antenna

```matlab
freq = 2.4e9;
ant = design(dipole, freq);

magVert = patternElevation(ant, freq, 0).';
angVert = -180:1:180;
magHoriz = patternAzimuth(ant, freq, 0).';
angHoriz = -180:1:180;

figure;
patternFromAI(magVert, angVert, magHoriz, angHoriz, AngleConvention="az-el");

[p3D, elOut, azOut] = patternFromAI(magVert, angVert, magHoriz, angHoriz, AngleConvention="az-el");
```

### Workflow: From Measured Data

```matlab
dataVert = readmatrix("elevation_cut.csv");
dataHoriz = readmatrix("azimuth_cut.csv");
magVert = dataVert(:,2).';
angVert = dataVert(:,1).';
magHoriz = dataHoriz(:,2).';
angHoriz = dataHoriz(:,1).';

% Force intersection consistency
idx_el0 = find(angVert == 0);
idx_az0 = find(angHoriz == 0);
magHoriz(idx_az0) = magVert(idx_el0);

figure;
patternFromAI(magVert, angVert, magHoriz, angHoriz, AngleConvention="az-el");
```

### Intersection Consistency

Vertical slice at el=0 should agree with horizontal slice at az=0 within 3 dB.

## patternFromSlices (Geometric Alternative)

Uses geometric interpolation (R2019a+). Phi-theta convention only. Works best with **directional antennas** (patch, horn) where both slices pass through the main beam — omnidirectional antennas (dipole) produce degraded reconstruction accuracy.

```matlab
theta = 0:1:180;
phi = 0:1:360;
magVert = pattern(ant, freq, 0, theta);
magHoriz = pattern(ant, freq, phi, 90);

[p3D, thetaOut, phiOut] = patternFromSlices(magVert, theta, magHoriz, phi);
```

Methods: `"Summing"` (default), `"CrossWeighted"`.

## Custom Surrogate Training (fitrauto)

For antennas not in the AIAntenna catalog:

```matlab
% 1. Sample design space
params = lhsdesign(200, 4);
% 2. Full-wave for each sample
for k = 1:N
    ant = buildAntenna(params(k,:));
    fRes(k) = findResonance(ant, freqRange);
end
% 3. Train surrogate
mdl = fitrauto(data, "fRes", Learners=["gp","svm","net"]);
% 4. Predict
fPred = predict(mdl, newParams);
```

Requires Statistics and Machine Learning Toolbox.

----

Copyright 2026 The MathWorks, Inc.
