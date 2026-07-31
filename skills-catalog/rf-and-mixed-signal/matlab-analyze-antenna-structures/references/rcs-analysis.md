# Radar Cross Section Analysis

## Supported Objects

| Object Type | Examples |
|-------------|---------|
| Platform | `platform` (STL/STEP/IGES geometry) |
| Installed antenna | `installedAntenna` |
| Antenna elements | `dipole`, `horn`, `patchMicrostrip`, `reflectorParabolic`, `cassegrain`, etc. |
| Arrays | `linearArray`, `rectangularArray`, `circularArray` |

## rcs Function Reference

### Syntax

```matlab
% Plot mode (no outputs -- generates polar plot)
rcs(object, freq)
rcs(object, freq, azimuth, elevation)
rcs(___, Name=Value)

% Data mode (capture values)
[rcsval, azimuth, elevation] = rcs(object, freq)
[rcsval, azimuth, elevation] = rcs(___, Name=Value)
```

### Input Arguments

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `object` | platform, antenna, or array | -- | Target |
| `freq` | positive scalar (Hz) | -- | Analysis frequency |
| `azimuth` | scalar or vector (deg) | 0 | Azimuth angle(s) |
| `elevation` | scalar or vector (deg) | 0:5:360 | Elevation angle(s) |

### Name-Value Arguments

| Name | Values | Default | Description |
|------|--------|---------|-------------|
| `Polarization` | `"VV"`, `"HH"`, `"HV"`, `"VH"` | `"VV"` | Tx-Rx polarization |
| `Solver` | `"PO"`, `"MoM"`, `"FMM"` | `"PO"` | EM solver |
| `CoordinateSystem` | `"polar"`, `"rectangular"` | `"polar"` | Plot system |
| `Scale` | `"log"`, `"linear"` | `"log"` | dBsm or m^2 |
| `Type` | `"Magnitude"`, `"Complex"` | `"Magnitude"` | Output type |
| `UseGPU` | `"off"`, `"on"`, `"auto"` | `"off"` | GPU for PO |
| `TransmitAngle` | 2-by-1 [az; el] | `[0; 0]` | Bistatic Tx direction |
| `ReceiveAngle` | 2-by-M [az; el] | -- | Bistatic Rx directions |
| `Range` | positive scalar (m) | far-field | Near-field distance |

## Monostatic RCS

**One of `azimuth` or `elevation` must be scalar.** Cannot sweep both simultaneously.

### Elevation Sweep

```matlab
freq = 10e9;
plat = platform(FileName="plate.stl", Units="m");
az = 0;
el = 0:1:90;

figure;
rcs(plat, freq, az, el, Polarization="HH");

[sigma, ~, ~] = rcs(plat, freq, az, el, Polarization="HH");
```

### Azimuth Sweep

```matlab
az = 0:1:360;
el = 45;
figure;
rcs(plat, freq, az, el, Polarization="VV");
```

### Comparing Polarizations

```matlab
az = 0:1:180;
el = 0;
sigma_hh = rcs(plat, freq, az, el, Polarization="HH");
sigma_vv = rcs(plat, freq, az, el, Polarization="VV");

figure;
plot(az, sigma_hh, az, sigma_vv, LineWidth=1.5);
grid on;
xlabel("Azimuth (deg)");
ylabel("RCS (dBsm)");
legend("HH", "VV", Location="best");
```

### 2D RCS Map

Loop over one angle and collect 1D cuts:

```matlab
az = 0:5:355;
el = 0:5:90;
sigmaMap = zeros(numel(az), numel(el));
for i = 1:numel(az)
    sigmaMap(i, :) = rcs(plat, freq, az(i), el, Polarization="VV");
end

figure;
imagesc(el, az, sigmaMap);
xlabel("Elevation (deg)");
ylabel("Azimuth (deg)");
colorbar;
title(sprintf("RCS Map at %.1f GHz (VV, dBsm)", freq/1e9));
```

## Bistatic RCS

```matlab
txAngle = [0; 90];          % broadside incidence
rxEl = 0:5:360;
rxAngle = [zeros(size(rxEl)); rxEl];

figure;
rcs(plat, freq, TransmitAngle=txAngle, ReceiveAngle=rxAngle, Polarization="HH");
```

`TransmitAngle` is 2-by-1 `[az; el]`. `ReceiveAngle` is 2-by-M.

## Polarization

| Polarization | Description |
|-------------|-------------|
| `"VV"` | Vertical Tx, vertical Rx (co-pol) |
| `"HH"` | Horizontal Tx, horizontal Rx (co-pol) |
| `"HV"` | Horizontal Tx, vertical Rx (cross-pol) |
| `"VH"` | Vertical Tx, horizontal Rx (cross-pol) |

Cross-pol is typically much lower than co-pol for simple shapes.

## Output Options

### Linear Scale

```matlab
sigma_m2 = rcs(plat, freq, 0, 90, Scale="linear", Polarization="HH");
fprintf("RCS: %.4f m^2 (%.2f dBsm)\n", sigma_m2, 10*log10(sigma_m2));
```

### Complex RCS

```matlab
sigma_complex = rcs(plat, freq, 0, 90, Type="Complex", Polarization="HH");
fprintf("Magnitude: %.2f dBsm\n", 10*log10(abs(sigma_complex)^2));
fprintf("Phase: %.2f deg\n", angle(sigma_complex)*180/pi);
```

The complex value is `sqrt(sigma) * exp(j*phi)` where phi is the intrinsic target scattering phase.

## GPU Acceleration

```matlab
try
    hasGPU = canUseGPU();
catch
    hasGPU = false;
end
if hasGPU
    sigma = rcs(plat, freq, az, el, UseGPU="on", Polarization="HH");
else
    sigma = rcs(plat, freq, az, el, Polarization="HH");
end
```

`UseGPU` only applies to the PO solver.

## Near-Field RCS

```matlab
sigma_nf = rcs(plat, freq, 0, 90, Range=100, Polarization="HH");
fprintf("Near-field RCS at 100 m: %.2f dBsm\n", sigma_nf);
```

Far-field boundary: `2*D^2/lambda`.

## Dielectric Targets

Requires FMM solver and a `.mat` file with volumetric mesh.

### .mat File Structure

| Variable | Type | Description |
|----------|------|-------------|
| `Points` | N-by-3 double | Vertex coordinates (meters) |
| `Triangles` | M-by-3 double | Surface triangulation |
| `Tetrahedra` | K-by-4 double | Volumetric mesh |
| `EpsilonR` | scalar double | Relative permittivity |
| `LossTangent` | scalar double | Dielectric loss tangent |

### Workflow

```matlab
freq = 2.58e9;
p = platform;
p.FileName = "dielectric_target.mat";
p.Units = "m";
p.UseFileAsMesh = true;

figure; show(p);
sigma = rcs(p, freq, 0, 0, Solver="FMM", Polarization="HH");
fprintf("RCS: %.1f dBsm\n", sigma);
```

**PO and MoM do not support dielectric targets** and will error.

## Mesh Guidelines

| Solver | Mesh Density | Notes |
|--------|-------------|-------|
| PO | Default mesh adequate | Less sensitive |
| MoM | lambda/10 | Full-wave accuracy |
| FMM | lambda/10 | Full-wave accuracy |

```matlab
c = physconst("LightSpeed");
lambda = c / freq;
mesh(plat, MaxEdgeLength=lambda/10);
```

Check mesh size before MoM or FMM:

```matlab
figure;
m = mesh(plat, MaxEdgeLength=lambda/10);
fprintf("Triangles: %d\n", m.NumTriangles);
```

----

Copyright 2026 The MathWorks, Inc.
