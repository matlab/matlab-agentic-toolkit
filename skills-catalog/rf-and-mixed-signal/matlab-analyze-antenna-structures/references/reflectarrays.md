# Reflectarray and RIS Design

## Unit Cell Design with pcbStack

A reflectarray unit cell is a `pcbStack` with three layers: **patch (metal) + substrate (dielectric) + ground (metal)**.

```matlab
f0 = 5.8e9;
c0 = physconst("LightSpeed");
lambda = c0 / f0;
cellSize = 0.5 * lambda;
Lp = 8e-3;
subHeight = 1.524e-3;

sub = dielectric(Name="RO4003C", EpsilonR=3.55, LossTangent=0.0027, Thickness=subHeight);
boardGnd = antenna.Rectangle(Length=cellSize, Width=cellSize);
patch = antenna.Rectangle(Length=Lp, Width=Lp);

uc = pcbStack;
uc.BoardShape     = boardGnd;
uc.BoardThickness = subHeight;
uc.Layers         = {patch, sub, boardGnd};
uc.FeedLocations  = [Lp/4, 0, 1, 3];    % offset feed for proper excitation
```

### Critical Constraints

- **`infiniteArray` only supports pcbStack with exactly 3 layers** (metal-dielectric-metal). Multi-layer stacks throw: *"Multilayer Substrate is not supported for Infinite arrays."*
- **Set `BoardThickness` before `Layers`** -- setting Layers first causes MATLAB to silently overwrite dielectric thickness.
- **Feed offset:** Use `[Lp/4, 0, 1, 3]` for proper patch excitation -- not `[0 0 1 3]`.
- **`BoardShape` must match the ground plane** -- this defines the unit cell boundary.

### Shape Objects for Metal Patterns

All shapes are in the `antenna` namespace:

```matlab
% Cross-shaped patch
crossPatch = antenna.Rectangle(Length=armLen, Width=armWid) + ...
             antenna.Rectangle(Length=armWid, Width=armLen);

% Ring patch
ring = antenna.Circle(Radius=Ro) - antenna.Circle(Radius=Ri);

% Slotted patch
slotted = antenna.Rectangle(Length=Lp, Width=Wp) - antenna.Rectangle(Length=Ls, Width=Ws);
```

### Substrate Selection

| Material | EpsilonR | LossTangent | Use Case |
|----------|----------|-------------|----------|
| Custom `"RO4003C"` | 3.55 | 0.0027 | Recommended for reflectarrays |
| `"Teflon"` | 2.1 | 0.0002 | Low-loss, moderate phase range |
| `"TMM3"` | 3.45 | 0.002 | Higher permittivity, wider phase range |
| `"FR4"` | 4.8 | 0.026 | Prototyping only (high loss) |

## Phase Characterization (S-Curve)

Use `planeWaveExcitation` + `infiniteArray` + `EHfields` to extract reflection phase vs. geometry parameter.

**Important:** `EHfields` returns only the field scattered by the patch currents. The magnitude peaks at resonance (maximum patch re-radiation). The **relative phase variation** across patch sizes is correct for reflectarray design because the ground plane contribution is spatially constant and cancels when computing inter-element phase differences.

```matlab
f0 = 5.8e9;
c0 = physconst("LightSpeed");
lambda = c0 / f0;
k0 = 2*pi / lambda;
cellSize = 0.5 * lambda;
subHeight = 1.524e-3;
epsR = 3.55;
tanD = 0.0027;

sub = dielectric(Name="RO4003C", EpsilonR=epsR, LossTangent=tanD, Thickness=subHeight);
boardGnd = antenna.Rectangle(Length=cellSize, Width=cellSize);

patchSize0 = lambda / (2*sqrt(epsR));
patchSizes = linspace(0.3*patchSize0, 1.4*patchSize0, 20);

AF = 4*pi*cellSize^2 / lambda^2;
obsRadius = 100 * lambda;

reflMag   = zeros(size(patchSizes));
reflPhase = zeros(size(patchSizes));

for idx = 1:numel(patchSizes)
    ps = patchSizes(idx);
    patch = antenna.Rectangle(Length=ps, Width=ps);

    uc = pcbStack;
    uc.BoardShape     = boardGnd;
    uc.BoardThickness = subHeight;
    uc.Layers         = {patch, sub, boardGnd};
    uc.FeedLocations  = [ps/4, 0, 1, 3];

    ia = infiniteArray(Element=uc);
    ia.ScanAzimuth   = 0;
    ia.ScanElevation = 90;
    numSummationTerms(ia, 15);

    pw = planeWaveExcitation;
    pw.Element      = ia;
    pw.Direction    = [0 0 -1];
    pw.Polarization = [1 0 0];

    obsLoc = [0; 0; obsRadius];
    [Eo, ~] = EHfields(pw, f0, obsLoc);
    Eo = Eo * AF;
    Eco = dot(Eo, [1; 0; 0]);

    reflMag(idx)   = abs(Eco);
    reflPhase(idx) = angle(Eco);
end

reflMag = reflMag / max(reflMag);
reflPhaseUnwrap = unwrap(reflPhase);

figure;
subplot(2,1,1);
plot(patchSizes*1e3, reflMag, "b-o", LineWidth=1.5, MarkerSize=4);
ylabel("Reflection Magnitude |R|");
title(sprintf("Unit Cell S-Curve (%.1f GHz)", f0/1e9));
grid on;

subplot(2,1,2);
plot(patchSizes*1e3, rad2deg(reflPhaseUnwrap), "r-o", LineWidth=1.5, MarkerSize=4);
xlabel("Patch Side Length (mm)");
ylabel("Reflection Phase (deg)");
grid on;

phaseRange = max(reflPhaseUnwrap) - min(reflPhaseUnwrap);
fprintf("Phase range: %.0f degrees\n", rad2deg(phaseRange));
```

### S-Curve Quality Criteria

- **Phase range >= 300 degrees** (ideally 360). If less, increase substrate thickness or permittivity.
- **Smooth, monotonic variation** -- no abrupt jumps or flat regions.
- **Normalized magnitude near unity** across most sizes.

### Sweep Range

Start with `0.3 * patchSize0` to `1.4 * patchSize0` where `patchSize0 = lambda / (2*sqrt(epsR))`.

## Aperture Phase Synthesis

### Required Phase Formula

```matlab
% Element positions (centered grid)
xIdx = (-(Nx-1)/2 : (Nx-1)/2);
yIdx = (-(Ny-1)/2 : (Ny-1)/2);
[Xgrid, Ygrid] = meshgrid(xIdx * cellSize, yIdx * cellSize);

% Feed-to-element distances
dx = elemX - feedPos(1);
dy = elemY - feedPos(2);
dz = 0 - feedPos(3);
Rmn = sqrt(dx.^2 + dy.^2 + dz.^2);
phiPath = k0 * Rmn;

% Beam steering phase
u0 = sin(deg2rad(theta0)) * cos(deg2rad(phi0));
v0 = sin(deg2rad(theta0)) * sin(deg2rad(phi0));
phiBeam = k0 * (elemX * u0 + elemY * v0);

% Required reflection phase
phiReq = mod(phiPath - phiBeam, 2*pi);
```

### S-Curve Inversion (Phase to Patch Size)

```matlab
[phaseSorted, sortIdx] = sort(scurve.reflPhase);
patchSorted = scurve.patchSizes(sortIdx);
[phaseSorted, uniqIdx] = unique(phaseSorted);
patchSorted = patchSorted(uniqIdx);

phaseMin = min(phaseSorted);
phaseMax = max(phaseSorted);
phaseRange = phaseMax - phaseMin;
phiReqWrap = phaseMin + mod(phiReq - phaseMin, phaseRange);

elemPatchSize = interp1(phaseSorted, patchSorted, phiReqWrap, "pchip", "extrap");
elemPatchSize = max(min(elemPatchSize, max(scurve.patchSizes)), min(scurve.patchSizes));
```

## Feed Illumination Model

```matlab
thetaFeed = atan2(sqrt(dx.^2 + dy.^2), abs(dz));
feedIllum = (cos(thetaFeed).^qFeed) ./ Rmn;
elemAmp   = feedIllum .* elemReflMag;
elemAmp   = elemAmp / max(elemAmp);
elemTotalPhase = elemReflPhase - phiPath;
```

## Geometry Visualization with conformalArray

```matlab
elements = cell(1, nElem);
for ii = 1:nElem
    ps = elemPatchSize(ii);
    patch = antenna.Rectangle(Length=ps, Width=ps);
    uc = pcbStack;
    uc.BoardShape     = boardGnd;
    uc.BoardThickness = subHeight;
    uc.Layers         = {patch, sub, boardGnd};
    uc.FeedLocations  = [ps/4, 0, 1, 3];
    elements{ii} = uc;
end

elemPositions = [elemX, elemY, zeros(nElem, 1)];
raGeom = conformalArray(Element=elements, ElementPosition=elemPositions, Reference="origin");
figure; show(raGeom);
figure; layout(raGeom);
```

## Pattern Verification (Pattern Multiplication)

**Angle convention:** Use theta (0:180, from z-axis). `patternCustom` expects theta convention.

### Element Pattern

```matlab
thetaGrid = 0:1:180;
phiGrid   = 0:1:360;
elGrid    = 90 - thetaGrid;
dElem = pattern(unitCell, f0, phiGrid, elGrid);
dElem = dElem.';
```

### Array Factor

```matlab
[THG, PHG] = meshgrid(deg2rad(thetaGrid), deg2rad(phiGrid));
AF = zeros(size(THG));
for ii = 1:numel(THG)
    u = sin(THG(ii)) * cos(PHG(ii));
    v = sin(THG(ii)) * sin(PHG(ii));
    phaseProg = k0 * (elemX * u + elemY * v);
    AF(ii) = abs(sum(elemAmp .* exp(1j * (elemTotalPhase + phaseProg))));
end
AF_dB = 20*log10(AF / max(AF(:)));
AF_dB(AF_dB < -60) = -60;
```

### Pattern Multiplication and Display

```matlab
dElemNorm = dElem - max(dElem(:));
totalPattern_dB = dElemNorm + AF_dB;
totalPattern_dB = totalPattern_dB - max(totalPattern_dB(:));

figure;
patternCustom(totalPattern_dB, thetaGrid, phiGrid);
```

## RIS Phase Quantization

```matlab
Nbits = 2;
Nstates = 2^Nbits;
phaseStep = 2*pi / Nstates;
phiQuantized = round(phiReq / phaseStep) * phaseStep;

sincVal = sin(pi/Nstates) / (pi/Nstates);
quantEff = sincVal^2;
fprintf("Quantization loss: %.1f dB\n", 10*log10(quantEff));
```

| Bits | States | Efficiency | Loss |
|------|--------|------------|------|
| 1 | 2 | 0.405 | -3.9 dB |
| 2 | 4 | 0.811 | -0.9 dB |
| 3 | 8 | 0.950 | -0.2 dB |

## Design Parameters

- **Unit cell size:** `lambda/2` (default). Grating lobe limit: `cellSize < lambda/(1 + sin(theta_max))`.
- **f/D ratio:** 0.8 (default). Range: 0.5-1.5.
- **Feed exponent q:** `q = -10 / (20*log10(cos(atan(D/(2*F)))))` for -10 dB edge taper.
- **Patch sweep range:** `0.3*patchSize0` to `1.4*patchSize0` where `patchSize0 = lambda/(2*sqrt(epsR))`.

----

Copyright 2026 The MathWorks, Inc.
