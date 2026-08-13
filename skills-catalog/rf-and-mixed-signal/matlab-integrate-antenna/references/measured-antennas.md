# Measured Antenna Creation

## measuredAntenna Object

`measuredAntenna` wraps simulated or measured antenna data into an object compatible with Antenna Toolbox analysis functions, `txsite`/`rxsite`, satellite scenarios, and beam steering.

## Workflow Selection

| Goal | Workflow | Key Property |
|------|----------|-------------|
| Preserve full E-field data | E-field | `E` = P-by-3-by-F |
| Use with `txsite`/`rxsite`/`coverage` | Directivity-only | `Directivity` = P-by-F, `E = []` |
| Tilted antenna for satellite uplink | Directivity-only with tilt | `Directivity` = P-by-F, `E = []` |
| Array with per-element beam steering | EmbeddedE | `EmbeddedE` = P-by-3-by-N-by-F |
| Use as element in a larger array | Element-in-array | `E` = P-by-3, use `patternMultiply` |
| Import from CST (.ffs files) | ffsReader (R2026a+) | `ffsReader("file.ffs")` |

## Critical: Azimuth-Fast Data Ordering

`measuredAntenna` expects data with **azimuth as the fast-varying index**. `meshgrid` produces el-fast by default. **Always transpose after meshgrid:**

```matlab
[phi, elv] = meshgrid(az, el);
phi = phi';   % Transpose: now az-by-el
elv = elv';   % Transpose: now az-by-el
% phi(:) and elv(:) are now az-fast column vectors
```

### pattern() output is el-fast

```matlab
[pat, ~, ~] = pattern(ant, freq, az, el, Type="directivity");
pat1 = pat';       % Transpose to az-by-el
D = pat1(:);       % Flatten az-fast
```

### EHfields output is 3-by-P

```matlab
[e, ~] = EHfields(ant, freq, points);
E = e.';  % P-by-3
```

## FieldCoordinate

| Value | E columns (P-by-3) | Source |
|-------|---------------------|--------|
| `"rectangular"` | Ex, Ey, Ez | `EHfields` output (default) |
| `"polar"` | Ephi, Etheta, Er | HFSS .ffd imports |

## Workflow 1: Single-Element E-Field (Multi-Frequency)

```matlab
f0 = 2.4e9;
c0 = physconst("LightSpeed");
lambda = c0 / f0;
ant = design(patchMicrostrip, f0);

az = -180:5:180;
el = -90:5:90;
R = 100 * lambda;

[phi, elv] = meshgrid(az, el);
phi = phi'; elv = elv';
numPoints = numel(phi);

[x, y, z] = sph2cart(deg2rad(phi(:)), deg2rad(elv(:)), R);
points = [x, y, z].';     % 3-by-P for EHfields

Direction = [phi(:) elv(:) R*ones(numPoints, 1)];

fieldFreqs = [2.2e9, 2.4e9, 2.6e9];
numFreqs = numel(fieldFreqs);

E_data = zeros(numPoints, 3, numFreqs);
for k = 1:numFreqs
    [e, ~] = EHfields(ant, fieldFreqs(k), points);
    E_data(:, :, k) = e.';
end

sParams = sparameters(ant, fieldFreqs);

mAnt = measuredAntenna( ...
    E = E_data, ...
    Direction = Direction, ...
    FieldFrequency = fieldFreqs(:), ...
    FieldCoordinate = "rectangular", ...
    Azimuth = az, ...
    Elevation = el, ...
    Sparameters = sParams);

figure; pattern(mAnt, f0);
```

- `E` is P-by-3-by-F (F = number of frequencies). Single-frequency: P-by-3.
- `Sparameters` is optional but enables impedance queries.

## Workflow 2: Directivity-Only for txsite/rxsite

**`txsite`/`rxsite` require `E = []` and `Directivity` populated.**

```matlab
f0 = 2.4e9;
c0 = physconst("LightSpeed");
lambda = c0 / f0;
ant = design(patchMicrostrip, f0);

az = -180:5:180;
el = -90:5:90;
R = 100 * lambda;

[phi, elv] = meshgrid(az, el);  % NO transpose for Direction
numPoints = numel(phi);
Direction = [phi(:) elv(:) R*ones(numPoints, 1)];

fieldFreqs = [2.2e9, 2.4e9, 2.6e9];
numFreqs = numel(fieldFreqs);

D_data = zeros(numPoints, numFreqs);
for k = 1:numFreqs
    [pat, ~, ~] = pattern(ant, fieldFreqs(k), az, el, Type="directivity");
    pat1 = pat';
    D_data(:, k) = pat1(:);
end

mAntSite = measuredAntenna( ...
    E = [], ...
    Directivity = D_data, ...
    Direction = Direction, ...
    FieldFrequency = fieldFreqs(:), ...
    Azimuth = az, Elevation = el);

tx = txsite(Antenna = mAntSite, AntennaHeight = 30, ...
    TransmitterFrequency = f0, TransmitterPower = 10);
coverage(tx, SignalStrengths=[-60 -70 -80 -90], MaxRange=5000);
```

- `Directivity` is P-by-F in dBi.
- No `Sparameters` needed for site planning.

## Workflow 3: Tilted Antenna for Satellite

```matlab
antTilted = design(patchMicrostrip, f0);
antTilted.Tilt = 90;
antTilted.TiltAxis = [0 1 0];
```

Then follow Workflow 2 using `antTilted`. Mount transmitter on a `gimbal` for satellite tracking.

## Workflow 4: EmbeddedE for Array Beam Steering

```matlab
f0 = 2.4e9;
arr = linearArray(Element = design(patchMicrostrip, f0), ...
    NumElements = 4, ElementSpacing = lambda/2);

% Extract embedded E-field per element
EmbE = zeros(numPoints, 3, numElements, numFreqs);
for k = 1:numFreqs
    for n = 1:numElements
        [e, ~] = EHfields(arr, fieldFreqs(k), points, ElementNumber=n);
        EmbE(:, :, n, k) = e.';
    end
end

mAntArray = measuredAntenna( ...
    E = [], ...
    EmbeddedE = EmbE, ...
    Direction = Direction, ...
    NumPorts = numElements, ...
    FieldFrequency = fieldFreqs(:), ...
    FieldCoordinate = "rectangular", ...
    Azimuth = az, Elevation = el, ...
    Sparameters = sParamsArr, ...
    CalculateTotalField = true);

% Beam steering
steerAz = 30;
ps = phaseShift(arr, f0, [steerAz, 0]);
mAntArray.PhaseShift = ps;
figure; pattern(mAntArray, f0);
```

- `EmbeddedE` is P-by-3-by-N-by-F.
- `CalculateTotalField = true` is required.
- Use `phaseShift(originalArray, freq, [az, el])` -- do not compute manually.

## Workflow 5: measuredAntenna as Element in Array

```matlab
mesAnt = measuredAntenna( ...
    E = E0.', ...
    Direction = Direction, ...
    NumPorts = 1, ...
    Azimuth = az, Elevation = el, ...
    FieldCoordinate = "rectangular", ...
    FieldFrequency = f0);

rectArray = design(rectangularArray, f0, ant);
rectArrayMes = copy(rectArray);
rectArrayMes.Element = mesAnt;

% ONLY patternMultiply works (not pattern)
figure; patternMultiply(rectArrayMes, f0);
```

## Workflow 6: Import from CST (.ffs) via ffsReader (R2026a+)

```matlab
mAnt = ffsReader("antenna_pattern.ffs");

% With S-parameters from Touchstone
mAnt = ffsReader("antenna.ffs", SparametersFile = "antenna.s1p");

% Scale E-fields to match S-parameter power
mAntScaled = scaleEField(mAnt);

% Selective import (multi-port/frequency)
mAnt = ffsReader("array.ffs", PortList = [1 2], FrequencyList = [2.4e9, 2.5e9]);
```

For `txsite` usage after ffsReader, extract directivity and rebuild with `E = []`.

## Workflow 7: Import from HFSS (.ffd)

Use `loadData` helper from `openExample("antenna/VisualizeRadiationPatternDataFromFFDFileExample")`. Key points:
- `FieldCoordinate = "polar"` (HFSS exports Etheta/Ephi)
- E column order is `[Ephi, Etheta, Er]` -- not `[Etheta, Ephi, Er]`
- Er is zero in the far field

## Visualization: patternCustom and fieldsCustom

### patternCustom -- 3D Pattern from Raw Data

Uses **spherical coordinates (theta, phi)**, not azimuth/elevation.

```matlab
% Matrix form: patternCustom(magE_matrix, theta_vec, phi_vec)
% magE_matrix: Nphi-by-Ntheta
figure; patternCustom(pat.', theta, phi);
```

Coordinate conversion: `theta = 90 - elevation`, `phi = azimuth`.

### fieldsCustom -- E-Field Quiver Plot

```matlab
[e, ~] = EHfields(ant, f0, points);
figure; fieldsCustom(e, points);
```

Both `field` and `points` are 3-by-P (same format as EHfields I/O).

## Key Rules

- Failing to transpose after meshgrid produces silently wrong patterns
- `txsite` errors if `E` contains field data -- must be `[]`
- Do not use `pattern(..., Type="directivity")` when the `Directivity` property is empty — use `pattern(mAnt, f, az, el)` without `Type` keyword instead, or populate `Directivity` first
- Only `patternMultiply` works when `measuredAntenna` is the `Element` of an array
- `phaseShift` and `AmplitudeTaper` are 1-by-N vectors
- EmbeddedE extraction is O(numElements x numFreqs x numPoints) -- warn for > 8 elements
- `ffsReader` requires R2026a or later

----

Copyright 2026 The MathWorks, Inc.
