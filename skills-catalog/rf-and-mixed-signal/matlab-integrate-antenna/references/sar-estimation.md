# SAR Estimation

## SAR Formula

```
SAR = sigma * |E|^2 / (2 * rho)   [W/kg]
```

- sigma = tissue conductivity (S/m)
- |E| = electric field magnitude inside tissue (V/m)
- rho = tissue mass density (kg/m^3)

Conductivity relates to loss tangent: `sigma = omega * eps0 * epsR * tanD`

## Three Approaches

| Approach | Antenna | Tissue Model | Best For |
|----------|---------|--------------|----------|
| `birdcage` + `Phantom` | Birdcage MRI coil only | Volumetric tetrahedral mesh (struct) | MRI SAR with realistic tissue |
| `conformalArray` + `shape.Custom3D` | Any antenna | Surface triangulation with catalog material | Phone/device SAR (antenna outside tissue) |
| Direct `EHfields` + formula | Any antenna | Post-processing only | Implantable antenna SAR |

**Key limitation:** The `dielectric` class enforces `LossTangent <= 0.03`. Real tissue (brain 900 MHz: tanD ~ 0.36) exceeds this. Only `birdcage.Phantom` bypasses this using a custom struct. The direct `EHfields` approach avoids the cap by applying conductivity in the formula only.

## Approach 1: birdcage + Phantom

The `birdcage` antenna is the ONLY object supporting volumetric dielectrics via its `Phantom` property.

### Phantom Data Format

```matlab
phantom = struct( ...
    Points=vertices, ...      % N x 3 (meters)
    Tetrahedra=elements, ...  % M x 4
    EpsilonR=epsR, ...        % scalar
    LossTangent=tanD);        % scalar, no cap
```

### Shipped Phantoms

- `humanheadcoarse.mat` -- 584 vertices, 2818 tetrahedra (fast)
- `humanheadfine.mat` -- finer resolution (slower)

Both provide `P` (vertices) and `T` (tetrahedra). Apply `scaleFactor = 0.003`.

### Workflow

```matlab
freq = 128e6;  % 3T MRI
tissueEpsR = 77;
tissueSigma = 0.51;
tissueRho = 1040;
omega = 2 * pi * freq;
eps0 = 8.854e-12;
tanD = tissueSigma / (omega * eps0 * tissueEpsR);

load humanheadcoarse.mat
scaleFactor = 0.003;
phantom = struct( ...
    Points=scaleFactor * P, ...
    Tetrahedra=T, ...
    EpsilonR=tissueEpsR, ...
    LossTangent=tanD);

bc = birdcage(Phantom=phantom);
figure; show(bc);

gridSpacing = 0.02;
[obsPoints, insideMask] = createObservationGrid(phantom.Points, gridSpacing);
[E, ~] = EHfields(bc, freq, obsPoints');

E_mag_sq = abs(E(1,:)).^2 + abs(E(2,:)).^2 + abs(E(3,:)).^2;
SAR_point = tissueSigma * E_mag_sq / (2 * tissueRho);
```

### birdcage Properties

- `NumRungs` (not NumLegs)
- `CoilRadius` (not Radius)
- `CoilHeight` (not Height)

## Approach 2: conformalArray + shape.Custom3D

Place any antenna alongside a dielectric head phantom. `shape.Custom3D` acts as a passive dielectric scatterer -- no feed required.

```matlab
freq = 2.4e9;
c = physconst("LightSpeed");
lambda = c / freq;

load humanheadcoarse.mat
scaleFactor = 0.003;
pts = scaleFactor * P;
pts = pts * (0.18 / (max(pts(:,1)) - min(pts(:,1))));

TR = triangulation(T, pts);
[surfFaces, surfVertices] = freeBoundary(TR);
headTri = triangulation(surfFaces, surfVertices);

headShape = shape.Custom3D(headTri);
headShape.Dielectric = "TMM10";  % returns a plain string (not a dielectric object)

d = design(dipole, freq);

arr = conformalArray;
arr.Element = {d, headShape};
arr.ElementPosition = [0.10 0 0; 0 0 0];
arr.Reference = "origin";

figure; show(arr);
figure; pattern(arr, freq);

gridSpacing = 0.015;
[obsPoints, insideMask] = createObservationGrid(pts, gridSpacing);
[E, ~] = EHfields(arr, freq, obsPoints');

epsR = 9.8; tanD_mat = 0.0022; rho = 2270;
omega = 2 * pi * freq; eps0 = 8.854e-12;
sigma = omega * eps0 * epsR * tanD_mat;
E_mag_sq = abs(E(1,:)).^2 + abs(E(2,:)).^2 + abs(E(3,:)).^2;
SAR_point = sigma * E_mag_sq / (2 * rho);
```

## Approach 3: Direct EHfields (Implantable)

For antennas **embedded inside tissue**. `conformalArray` cannot be used because the solver rejects intersecting geometries.

**Limitation:** Tissue loading on antenna impedance is not captured. Conductivity is applied only in the SAR formula.

```matlab
freq = 2.4e9;

% Build implantable pcbStack
ant = pcbStack;
ant.BoardShape = antenna.Rectangle(Length=25e-3, Width=25e-3);
ant.BoardThickness = 1.27e-3 + 0.5e-3;
ant.Layers = {sup, patch, sub, ground};
ant.FeedLocations = [Lp/4, 0, 2, 4];
ant.FeedDiameter = 0.6e-3;

% Observation grid in tissue
[X, Y, Z] = meshgrid(xobs, yobs, zobs);
obsPoints = [X(:), Y(:), Z(:)];

[E, ~] = EHfields(ant, freq, obsPoints.');
E_mag_sq = abs(E(1,:)).^2 + abs(E(2,:)).^2 + abs(E(3,:)).^2;

% Power normalization
Z_in = impedance(ant, freq);
P_accepted = 0.5 * real(Z_in) / abs(Z_in)^2;
E_mag_sq_norm = E_mag_sq / P_accepted;

% SAR with real tissue properties
sigma_skin = 1.464;
rho_skin = 1100;
SAR = sigma_skin * E_mag_sq_norm / (2 * rho_skin);
fprintf("Peak point SAR: %.2f W/kg per 1W input\n", max(SAR));
```

## Observation Grid Generation

```matlab
function [obsPoints, insideMask] = createObservationGrid(pts, gridSpacing)
    margin = gridSpacing;
    xVec = (min(pts(:,1))+margin) : gridSpacing : (max(pts(:,1))-margin);
    yVec = (min(pts(:,2))+margin) : gridSpacing : (max(pts(:,2))-margin);
    zVec = (min(pts(:,3))+margin) : gridSpacing : (max(pts(:,3))-margin);
    [Xg, Yg, Zg] = meshgrid(xVec, yVec, zVec);
    allPts = [Xg(:), Yg(:), Zg(:)];

    DT = delaunayTriangulation(pts);
    insideMask = ~isnan(pointLocation(DT, allPts));
    obsPoints = allPts(insideMask, :);
end
```

**`EHfields` expects 3-by-M** -- pass `obsPoints'`.

## Power Normalization

```matlab
Z_in = impedance(ant, freq);
P_accepted = 0.5 * real(Z_in) / abs(Z_in)^2;  % power at 1V
SAR_1W = SAR_point * (1.0 / P_accepted);       % scale to 1W
```

For birdcage (multiple ports): `Z_in = Z_in(1)`.

## Mass-Averaged SAR (10g / 1g)

```matlab
avgMass = 0.010;  % 10g (ICNIRP) or 0.001 (FCC 1g)
avgCubeSide = (avgMass / tissueRho)^(1/3);
halfSide = avgCubeSide / 2;

SAR_avg = zeros(size(SAR_1W));
for i = 1:numel(SAR_1W)
    dx = abs(obsPoints(:,1) - obsPoints(i,1));
    dy = abs(obsPoints(:,2) - obsPoints(i,2));
    dz = abs(obsPoints(:,3) - obsPoints(i,3));
    mask = (dx <= halfSide) & (dy <= halfSide) & (dz <= halfSide);
    SAR_avg(i) = mean(SAR_1W(mask));
end
```

## Power Balance Validation

Two independent methods must agree (Approaches 1 and 2):

```matlab
% Method 1: Efficiency
eta = efficiency(ant, freq);
P_absorbed_eff = P_accepted * (1 - eta);

% Method 2: SAR integral
deltaV = gridSpacing^3;
P_absorbed_SAR = sum(SAR_point) * tissueRho * deltaV;

% Compare
relError = abs(P_absorbed_SAR - P_absorbed_eff) / P_absorbed_eff * 100;
% < 20%: PASS, 20-50%: MARGINAL, > 50%: refine grid
```

**Approach 3 caveat:** For direct EHfields, `efficiency(ant, freq)` reflects the free-space antenna (no tissue loading). The SAR integral will show significantly higher absorbed power than the efficiency method predicts — this is expected behavior, not an error. Report both values and the relative error as a known limitation. Do NOT iterate to reduce it.

## Tissue Properties Reference

| Tissue (freq) | epsR | sigma (S/m) | tan delta | rho (kg/m^3) |
|----------------|------|-------------|-----------|--------------|
| Brain (128 MHz) | 77 | 0.51 | 0.93 | 1040 |
| Brain (900 MHz) | 52 | 0.94 | 0.36 | 1040 |
| Brain (2.4 GHz) | 48 | 1.8 | 0.28 | 1040 |
| Muscle (900 MHz) | 55 | 0.94 | 0.34 | 1040 |
| Skin (900 MHz) | 41 | 0.87 | 0.42 | 1100 |

## Regulatory SAR Limits

| Standard | Limit | Averaging Mass | Region |
|----------|-------|----------------|--------|
| FCC (USA) | 1.6 W/kg | 1 g | Head/body |
| ICNIRP (EU) | 2.0 W/kg | 10 g | Head/trunk |
| ICNIRP (EU) | 4.0 W/kg | 10 g | Limbs |
| IEC 60601-2-33 (MRI) | 3.2 W/kg | 10 g | Head |

## Available Catalog Materials

| Material | epsR | tan delta | Notes |
|----------|------|-----------|-------|
| TMM10 | 9.8 | 0.0022 | Highest permittivity |
| TMM6 | 6.3 | 0.0023 | |
| FR4 | 4.8 | 0.026 | Highest loss tangent |
| Teflon | 2.1 | 0.0002 | Very low loss |

For SAR demonstrations, use **TMM10** to maximize tissue-like behavior within the cap.

## Approach Selection

- **birdcage + Phantom:** MRI coil SAR, realistic tissue (high LossTangent)
- **conformalArray + shape.Custom3D:** Phone/device SAR, antenna outside tissue
- **Direct EHfields:** Implantable antenna, any type, real conductivity in formula

## Key Rules

- `EHfields` expects 3-by-M -- pass `obsPoints'`
- For birdcage, take `Z_in(1)` since impedance returns a vector
- Grid spacing: 20mm for demos, 5mm for publication quality
- Always validate with power balance check (Approaches 1 and 2; for Approach 3, report values but expect large divergence)
- Always normalize to a known input power (typically 1W accepted)
- Warn about the LossTangent cap when tissue properties are requested
- `conformalArray` rejects intersecting geometries (antenna inside tissue fails)
- `shape` objects go directly in `conformalArray.Element` without wrapping in `customAntenna`

----

Copyright 2026 The MathWorks, Inc.
