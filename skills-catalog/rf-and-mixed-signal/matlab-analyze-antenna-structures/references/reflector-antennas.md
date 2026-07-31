# Reflector Antenna Design

## Reflector Types

| Type | Description | Default Exciter | Solver |
|------|-------------|-----------------|--------|
| `reflectorParabolic` | Prime-focus parabolic dish | `dipole` | MoM-PO |
| `cassegrain` | Symmetric dual-reflector (hyperbolic sub) | `hornConical` | MoM-PO |
| `gregorian` | Symmetric dual-reflector (ellipsoidal sub) | `hornConical` | MoM-PO |
| `cassegrainOffset` | Offset Cassegrain (no blockage) | `hornConical` | MoM-PO |
| `gregorianOffset` | Offset Gregorian (no blockage) | `hornConical` | MoM-PO |
| `reflectorCorner` | Corner reflector (directional) | `dipole` | MoM |
| `reflectorCylindrical` | Cylindrical reflector (fan beam) | `dipole` | MoM |
| `reflectorSpherical` | Spherical reflector (wide scan) | `dipole` | MoM-PO |
| `customDualReflectors` | Custom surface geometry | `hornConical` | MoM-PO |

**Name mapping:**
- "dish antenna" / "parabolic dish" / "satellite dish" --> `reflectorParabolic`
- "Cassegrain" / "dual reflector" --> `cassegrain` or `cassegrainOffset`
- "Gregorian" --> `gregorian` or `gregorianOffset`
- "corner reflector" --> `reflectorCorner`
- "offset feed" / "no blockage" --> `cassegrainOffset` or `gregorianOffset`
- "shaped reflector" / "custom surface" --> `customDualReflectors`

## Creating Reflector Antennas

### design() for Reflectors

Reflector antennas use `design(obj, freq)` with **two arguments only**. Set the exciter on the object before calling `design()`:

```matlab
freq = 10e9;

% Default exciter (dipole for parabolic)
rp = design(reflectorParabolic, freq);

% Custom exciter -- set BEFORE design
rp = reflectorParabolic;
rp.Exciter = hornConical;
rp = design(rp, freq);
```

**Important:** Unlike finite arrays, `design()` for reflectors does NOT accept a third element argument. Always set `Exciter` property first.

### Supported Exciters

| Exciter | Works With | Notes |
|---------|-----------|-------|
| `dipole` | All reflectors | Simple, linearly polarized |
| `horn` | Parabolic, dual-reflectors | Rectangular horn |
| `hornConical` | All except corner/cylindrical | Best for dishes (circular symmetry) |
| `helix` | Parabolic, spherical | Circular polarization |
| `spiralArchimedean` | Parabolic, spherical | Wideband CP |
| `vivaldi` | Parabolic | Wideband, linear pol |
| `patchMicrostrip` | Parabolic | Compact feed |
| `cavity` | **NOT supported** | Cannot be set as Exciter |

## Prime-Focus Parabolic Dish

```matlab
freq = 10e9;
c = physconst("LightSpeed");
lambda = c / freq;

% Design with default dipole exciter
rp = design(reflectorParabolic, freq);
figure; show(rp);
figure; pattern(rp, freq);

% Key dimensions
fprintf("Radius: %.4f m (%.1f lambda)\n", rp.Radius, rp.Radius/lambda);
fprintf("Focal length: %.4f m\n", rp.FocalLength);
fprintf("f/D ratio: %.2f\n", rp.FocalLength / (2*rp.Radius));
```

### With Horn Exciter (Higher Gain)

```matlab
freq = 10e9;
rp = reflectorParabolic;
rp.Exciter = hornConical;
rp = design(rp, freq);
figure; show(rp);
figure; pattern(rp, freq);

[bw, angles] = beamwidth(rp, freq, 0, 1:360);
fprintf("3-dB beamwidth: %.1f deg\n", bw);
```

### Custom f/D Ratio

```matlab
freq = 12e9;
c = physconst("LightSpeed");
lambda = c / freq;

rp = reflectorParabolic;
rp.Exciter = hornConical;
rp.Radius = 10 * lambda;           % 10-lambda aperture radius
rp.FocalLength = 10 * lambda;      % f/D = 0.5
rp.FeedOffset = [0 0 0];
figure; show(rp);
figure; pattern(rp, freq);
```

## Cassegrain and Gregorian (Symmetric Dual-Reflector)

```matlab
freq = 10e9;

% Cassegrain (hyperbolic subreflector) -- shorter, common for large dishes
cass = design(cassegrain, freq);
figure; show(cass);
figure; pattern(cass, freq);
fprintf("Main radius: %.4f m, Sub radius: %.4f m\n", cass.Radius(1), cass.Radius(2));

% Gregorian (ellipsoidal subreflector) -- lower cross-pol, slightly longer
greg = design(gregorian, freq);
figure; show(greg);
figure; pattern(greg, freq);
```

Both use `hornConical` as default exciter. Properties: `Radius` (1-by-2), `FocalLength` (1-by-2).

## Offset Dual-Reflector (No Feed Blockage)

```matlab
freq = 10e9;

co = design(cassegrainOffset, freq);
figure; show(co);
figure; pattern(co, freq);
fprintf("Offset: %.4f m, InterAxialAngle: %.1f deg\n", co.MainReflectorOffset, co.InterAxialAngle);

go = design(gregorianOffset, freq);
figure; show(go);
```

**Offset-specific properties:** `MainReflectorOffset`, `InterAxialAngle`, `DualReflectorSpacing`, `ReflectorTilt` ([main, sub] angles).

## Corner Reflector

| Corner Angle | Image Sources | Approx. Gain |
|---|---|---|
| 90 | 3 (total 4) | ~10 dBi |
| 60 | 5 (total 6) | ~12 dBi |
| 45 | 7 (total 8) | ~13 dBi |

```matlab
freq = 1e9;
rc = design(reflectorCorner, freq);
rc.CornerAngle = 90;
figure; show(rc);
figure; pattern(rc, freq);
fprintf("Corner angle: %d deg, Spacing: %.4f m\n", rc.CornerAngle, rc.Spacing);
```

## Cylindrical and Spherical Reflectors

```matlab
freq = 1e9;

% Cylindrical -- fan beam (narrow in one plane, wide in other)
rcyl = design(reflectorCylindrical, freq);
figure; show(rcyl);
figure; pattern(rcyl, freq);

% Spherical -- wide-angle scanning by moving the feed
rs = design(reflectorSpherical, freq);
figure; show(rs);
figure; pattern(rs, freq);
fprintf("Radius: %.4f m, Depth: %.4f m\n", rs.Radius, rs.Depth);
```

`reflectorCylindrical` has `EnableProbeFeed` property for probe feed through the reflector surface.

## Array as Exciter

Any array object can be assigned as the `Exciter`. Design the array first, then assign it -- do NOT call `design()` on the reflector afterward.

```matlab
freq = 10e9;
c = physconst("LightSpeed");
lambda = c / freq;

arr = circularArray;
arr.NumElements = 4;
arr.Element = spiralArchimedean;
arr = design(arr, freq);

rp = reflectorParabolic;
rp.Exciter = arr;
rp.Radius = 5*lambda;
rp.FocalLength = 5*lambda;   % f/D = 0.5
figure; show(rp);
figure; pattern(rp, freq);
```

## Custom Reflector Surfaces from STL Files

Import arbitrary reflector geometry using `stlread` + `customDualReflectors`.

### Single Custom Reflector

```matlab
freq = 2e9;
tri = stlread("MyCustomReflector.stl");

cdr = customDualReflectors;
cdr.MainReflector = tri;
cdr.Exciter = dipole(Length=0.15, Width=0.015, Tilt=90, TiltAxis=[0 1 0]);
cdr.FeedOffset = [0 0 0.05];
cdr.RemeshReflectors = true;
figure; show(cdr);
figure; pattern(cdr, freq);
```

### Dual Custom Reflectors

```matlab
freq = 10e9;
mainTri = stlread("main_reflector.stl");
subTri = stlread("sub_reflector.stl");

cdr = customDualReflectors;
cdr.MainReflector = mainTri;
cdr.SubReflector = subTri;
cdr.Exciter = hornConical;
cdr.ReflectorOffset = [0 0 0; 0 0 0.1];
cdr.FeedOffset = [0 0 0.15];
figure; show(cdr);
figure; pattern(cdr, freq);
```

**Properties:**
- `MainReflector`: N-by-3 matrix or triangulation object
- `SubReflector`: optional, same format
- `ReflectorOffset`: 2-by-3 matrix [main offset; sub offset] -- additive translation
- `FeedOffset`: 1-by-3 vector -- exciter position
- `ReflectorTilt`: [main, sub] tilt angles
- `RemeshReflectors`: true/false

**Coordinate system:** `customDualReflectors` preserves the coordinate system of the input data. If surfaces overlap, use `ReflectorOffset` to apply correct relative positioning.

## Reflector Calculator (Gaussian-Beam Analysis)

`reflectorCalculator` (R2026a) provides fast analytical design -- no full-wave solve required.

### Feed Types

| FeedType | Description | Key Properties |
|----------|-------------|----------------|
| `"singlefed"` | Single horn feed | `RadiatingElement`, `RadiatorAperture` |
| `"arrayfed"` | Array of horns | `NumRadiators`, `Spacing` |
| `"patternfed"` | External pattern file | `FileName` (`.txt` or `.csv` only) |

### Usage

```matlab
freq = 12e9;
rc = reflectorCalculator;
rc.Diameter = 1;
rc.FocalLength = 0.9;
rc.ClearanceHeight = 0.1;
rc.FeedType = "singlefed";
rc.RadiatingElement = "horn";
s = solve(rc, freq);           % returns 18-metric table instantly
ant = createAntenna(rc, freq); % bridge to customDualReflectors for full-wave
```

### Solve Output

`solve(rc, freq)` returns an 18-row table: focal length, diameter, clearance height (in lambda), feed tilt angle, half-angle, edge angles, efficiency (%), peak directivity/gain (dBi), half-power beamwidth (deg), first sidelobe level (dB), illumination taper, scan loss, surface RMS loss, feed loss.

### When to Use

| | `reflectorCalculator` | `reflectorParabolic` |
|---|---|---|
| Method | Gaussian-beam (analytical) | Full-wave MoM-PO |
| Speed | Instant | Minutes to hours |
| Use case | Trade studies, sizing, feed selection | Final verification, near-field |

**Workflow:** Use `reflectorCalculator` for rapid iteration, then `createAntenna` for full-wave validation.

## f/D Ratio Design Guide

| f/D | Subtended Half-Angle | Characteristics |
|-----|---------------------|-----------------|
| 0.25 | 90 | Deep dish, wide feed beamwidth needed, compact |
| 0.35 | 69 | Common compromise |
| 0.50 | 53 | Shallow dish, narrow feed beamwidth, less spillover |
| 0.75 | 37 | Very shallow, minimal spillover, lower illumination |

**Optimal f/D:** Match feed -10 dB beamwidth to dish subtended angle. Use `thetaEdge = 2*atand(1/(4*fOverD))`.

## Design Rules of Thumb

| Parameter | Typical Range | Notes |
|-----------|---------------|-------|
| f/D ratio | 0.25 - 0.75 | 0.35-0.5 most common |
| Aperture (D/lambda) | 5 - 100+ | Higher = narrower beam, higher gain |
| Aperture efficiency | 50-70% | Includes spillover + illumination + blockage |
| Feed taper at edge | -10 to -12 dB | Good spillover/illumination compromise |
| Gain (dBi) | ~20*log10(D/lambda) + 8 | Rough estimate for eta=55% |
| Beamwidth (deg) | ~70*lambda/D | Half-power beamwidth estimate |

## Feed Offset and Tilt

```matlab
% Beam squint via feed offset (small offsets only)
rp.FeedOffset = [0.02 0 0];
figure; pattern(rp, freq);

% Mechanical steering via tilt
rp.Tilt = 30;
rp.TiltAxis = [0 1 0];
figure; pattern(rp, freq);
```

For significant beam steering, use offset configurations rather than feed offset.

----

Copyright 2026 The MathWorks, Inc.
