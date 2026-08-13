# Array Design (Finite & Infinite)

## Finite Array Types

| Array Type | Key Properties | Notes |
|------------|----------------|-------|
| `linearArray` | `Element`, `NumElements`, `ElementSpacing`, `AmplitudeTaper`, `PhaseShift` | 1D uniform |
| `rectangularArray` | `Element`, `Size` ([rows cols]), `RowSpacing`, `ColumnSpacing`, `Lattice` | 2D planar |
| `circularArray` | `Element`, `NumElements`, `Radius` | Circular ring |
| `conformalArray` | `Element` (cell array), `ElementPosition` (Nx3) | Arbitrary geometry |

**Name mapping:** "ULA" -> `linearArray`, "URA"/"planar" -> `rectangularArray`, "UCA" -> `circularArray`

## Array Creation with design()

Always pass element as **third argument** for non-dipole elements:

```matlab
freq = 2.4e9;

% Linear patch array
arr = linearArray;
arr.NumElements = 8;
arr = design(arr, freq, patchMicrostrip);

% Rectangular array with triangular lattice
arr = rectangularArray;
arr.Size = [4, 4];
arr.Lattice = "Triangular";
arr = design(arr, freq, dipole);

% Circular array
arr = circularArray;
arr.NumElements = 6;
arr = design(arr, freq, dipole);
```

**`design(arr, freq)` with only two arguments resets element to `dipole`.**

## Infinite Array

`infiniteArray` models a single unit cell with Floquet boundary conditions.

**Key differences from finite arrays:**
- No `NumElements` or `ElementSpacing` — unit cell size = element's ground plane dimensions
- Always rectangular lattice
- `impedance()` returns scan impedance at current scan angles
- Single port

```matlab
infa = design(infiniteArray, freq, patchMicrostrip);
% Unit cell size = element ground plane dimensions (set by design())
% To override: ensure ground plane >= designed element footprint
% infa.Element.GroundPlaneLength = desiredSpacing;
% infa.Element.GroundPlaneWidth = desiredSpacing;
```

**Do not blindly set ground plane to `lambda/2`** — after `design()`, the element may be wider than `lambda/2`. Ground plane dimensions must be >= the designed element footprint or MATLAB errors with "No part of antenna can be outside unit cell."

### Supported Infinite Array Elements

**Direct elements:** `patchMicrostrip`, `patchMicrostripCircular`, `patchMicrostripEnotch`, `patchMicrostripElliptical`, `patchMicrostripHnotch`, `patchMicrostripTriangular`, `monopole`, `monopoleTopHat`, `monopoleCylindrical`, `invertedL`, `helix`, `fractalSnowflake`, `monocone`

**Reflector-backed elements** (for balanced antennas without ground planes):
```matlab
r = reflector;
r.Exciter = dipole;
infa = design(infiniteArray, freq, r);
```

**Unsupported:** standalone `slot`, `vivaldi`, `invertedF`, `pifa`.

**Element escalation path:** direct element → reflector-wrapped → reflector with Air substrate → report unsupported.

## Conformal Array

```matlab
N = 6;
radius = 0.05;
angles = linspace(0, 2*pi*(1 - 1/N), N);
positions = [radius*cos(angles(:)), radius*sin(angles(:)), zeros(N, 1)];

arr = conformalArray;
arr.ElementPosition = positions;
arr.Element = repmat({elem}, 1, N);
```

`Element` cell array length must equal `ElementPosition` row count.

## Elements with Substrate

Set substrate on element **before** passing to `design()`:

```matlab
elem = patchMicrostrip;
elem.Substrate = dielectric("FR4");
arr = design(linearArray, freq, elem);
mesh(arr, MaxEdgeLength=lambda/8);
```

## Beam Steering

### Finite Arrays

```matlab
ps = phaseShift(arr, freq, [scanAz, scanEl]);
arr.PhaseShift = ps;
```

### Infinite Arrays

```matlab
infa.ScanAzimuth = 30;
infa.ScanElevation = 60;  % 90 = broadside, 0 = endfire
```

## Amplitude Tapering (Finite Only)

```matlab
arr.AmplitudeTaper = [0.5 0.7 0.9 1.0 1.0 0.9 0.7 0.5];

% Window functions (requires Signal Processing Toolbox)
N = arr.NumElements;
try
    arr.AmplitudeTaper = taylorwin(N, 4, -30)';
catch
    arr.AmplitudeTaper = ones(1, N);
end
```

For `rectangularArray`, `AmplitudeTaper` is 1-by-(rows*cols) in **column-major order**:

```matlab
nRows = arr.Size(1);  nCols = arr.Size(2);
rowTaper = taylorwin(nRows, 4, -30);
colTaper = taylorwin(nCols, 4, -30);
taper2D = rowTaper * colTaper';
arr.AmplitudeTaper = taper2D(:)';
```

## Grating Lobe Analysis

No grating lobe condition: `d / lambda < 1 / (1 + |sin(theta_scan)|)`

```matlab
d = arr.ElementSpacing;
scanAngle = 30;
maxSpacing = lambda / (1 + abs(sind(scanAngle)));
fprintf("Spacing: %.2f lambda, Max: %.2f lambda\n", d/lambda, maxSpacing/lambda);

figure; pattern(arr, freq, CoordinateSystem="uv");
```

## Scan Impedance

### Finite Arrays

```matlab
ps = phaseShift(arr, freq, [scanAz, scanEl]);
arr.PhaseShift = ps;
Z = impedance(arr, freq);  % per-element active impedance
```

### Infinite Arrays

```matlab
infa.ScanElevation = 60;
Z = impedance(infa, freq);

% Sweep scan angles
scanEls = 90:-5:10;
zScan = zeros(size(scanEls));
for i = 1:numel(scanEls)
    infa.ScanElevation = scanEls(i);
    zScan(i) = impedance(infa, freq);
end
```

## Scan Blindness Detection

Sweep with 1-degree resolution and look for impedance singularities:

```matlab
scanEls = 90:-1:5;
zScan = zeros(size(scanEls));
for i = 1:numel(scanEls)
    infa.ScanElevation = scanEls(i);
    infa.ScanAzimuth = 0;
    zScan(i) = impedance(infa, freq);
end
thetaScan = 90 - scanEls;
figure; plot(thetaScan, real(zScan), LineWidth=1.5);
xlabel("Scan Angle (deg)"); ylabel("Resistance (Ω)");
grid on; title("Scan Blindness Check");
```

## Mutual Coupling

```matlab
freqRange = linspace(freq*0.9, freq*1.1, 21);
s = sparameters(arr, freqRange);
figure; rfplot(s);

rho = correlation(arr, freq, 1, 2);
fprintf("Correlation (el 1-2): %.4f\n", abs(rho));
```

## Array Factor vs. Pattern vs. Pattern Multiply

| Method | Function | Coupling | Speed |
|--------|----------|----------|-------|
| Array factor | `arrayFactor(arr, freq)` | No | Fastest |
| Pattern multiply | `patternMultiply(arr, freq)` | No | Fast |
| Full-wave | `pattern(arr, freq)` | Yes | Slowest |

### Embedded Element Pattern

```matlab
figure; pattern(arr, freq, ElementNumber=1, Termination=50);
```

## MIMO / Handset Multi-Antenna

Use `conformalArray` for multi-antenna placement:

```matlab
arr = conformalArray;
arr.ElementPosition = [0, 0.05, 0; 0, -0.05, 0];
arr.Element = {ant1, ant2};
arr.Reference = "origin";
```

### Isolation and ECC

```matlab
s = sparameters(arr, freqRange);
figure; rfplot(s);
s12 = 20*log10(abs(rfparam(s, 1, 2)));
fprintf("Worst isolation: %.1f dB\n", max(s12));

rho = correlation(arr, freq, 1, 2);
fprintf("ECC: %.4f\n", abs(rho));
```

### Performance Targets

| Metric | Acceptable | Good |
|--------|-----------|------|
| Isolation (S12) | < -10 dB | < -15 dB |
| ECC | < 0.5 | < 0.3 |
| Total efficiency | > 30% | > 50% |

## Convergence Control (Infinite)

```matlab
numSummationTerms(infa, 20);  % default 10; increase for noisy results
```

## Memory and Performance

- For >16 element finite arrays, use `arrayFactor` or `patternMultiply` first
- Substrate elements: mesh at lambda/8
- Use `SweepOption="interp"` for `sparameters` on substrate arrays

----

Copyright 2026 The MathWorks, Inc.
