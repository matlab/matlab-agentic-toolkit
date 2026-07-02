# Electromagnetic Post-Processing Reference

## Electrostatic Results

```matlab
% Direct properties (all N×1)
V = result.ElectricPotential;
Ex = result.ElectricField.Ex;
Ey = result.ElectricField.Ey;
Ez = result.ElectricField.Ez;
Dx = result.ElectricFluxDensity.Dx;
Dy = result.ElectricFluxDensity.Dy;
Dz = result.ElectricFluxDensity.Dz;

% Interpolation — all return FEStruct
Vq = interpolateElectricPotential(result, queryPts);    % scalar(s)
Eq = interpolateElectricField(result, queryPts);        % FEStruct: .Ex, .Ey, .Ez
Dq = interpolateElectricFlux(result, queryPts);         % FEStruct: .Dx, .Dy, .Dz
```

**Method name:** `interpolateElectricFlux` — NOT `interpolateElectricFluxDensity`.

### Maxwell Stress Tensor (Lazy Evaluation)

MST is not computed at solve time — must call explicitly:

```matlab
resultMST = generateMaxwellStressTensor(result);
mst = resultMST.MaxwellStressTensor;  % 3×3×N double
```

`generateMaxwellStressTensor` returns an augmented result object (same class, with MST populated). It does not modify the original.

### Capacitance via Energy Method

```matlab
E = result.ElectricField;
D = result.ElectricFluxDensity;
energyDensity = D.Dx.*E.Ex + D.Dy.*E.Ey + D.Dz.*E.Ez;
W = 0.5 * mean(energyDensity) * domainVolume;
C = 2 * W / voltage^2;
```

## Magnetostatic Results

```matlab
% Direct properties (all N×1)
Bx = result.MagneticFluxDensity.Bx;
By = result.MagneticFluxDensity.By;
Bz = result.MagneticFluxDensity.Bz;
Hx = result.MagneticField.Hx;
Hy = result.MagneticField.Hy;
Hz = result.MagneticField.Hz;
Ax = result.MagneticPotential.Ax;

% |B| magnitude
Bmag = sqrt(result.MagneticFluxDensity.Bx.^2 + ...
            result.MagneticFluxDensity.By.^2 + ...
            result.MagneticFluxDensity.Bz.^2);

% Interpolation — returns FEStruct
Bq = interpolateMagneticFlux(result, queryPts);        % .Bx, .By, .Bz
Hq = interpolateMagneticField(result, queryPts);       % .Hx, .Hy, .Hz
Aq = interpolateMagneticPotential(result, queryPts);   % .Ax, .Ay, .Az
```

**Method name:** `interpolateMagneticFlux` — NOT `interpolateMagneticFluxDensity`.

### Maxwell Stress Tensor

Same lazy-evaluation pattern as electrostatic:

```matlab
resultMST = generateMaxwellStressTensor(result);
mst = resultMST.MaxwellStressTensor;  % 3×3×N
```

### Inductance via Energy Method

```matlab
B = result.MagneticFluxDensity;
H = result.MagneticField;
energyDensity = B.Bx.*H.Hx + B.By.*H.Hy + B.Bz.*H.Hz;
W = 0.5 * mean(energyDensity) * domainVolume;
L = 2 * W / current^2;
```

## DC Conduction Results

`ConductionResults` from `solve()` on a `dcConduction` analysis type. No Maxwell stress tensor for this analysis.

```matlab
% Direct properties (all N×1)
V = result.ElectricPotential;
Ex = result.ElectricField.Ex;
Ey = result.ElectricField.Ey;
Ez = result.ElectricField.Ez;
Jx = result.CurrentDensity.Jx;
Jy = result.CurrentDensity.Jy;
Jz = result.CurrentDensity.Jz;

% Current density magnitude
Jmag = sqrt(result.CurrentDensity.Jx.^2 + ...
            result.CurrentDensity.Jy.^2 + ...
            result.CurrentDensity.Jz.^2);

% Interpolation
Vq = interpolateElectricPotential(result, queryPts);
Eq = interpolateElectricField(result, queryPts);      % FEStruct: .Ex, .Ey, .Ez
Jq = interpolateCurrentDensity(result, queryPts);     % FEStruct: .Jx, .Jy, .Jz
```

**Method name:** `interpolateCurrentDensity` — NOT `interpolateCurrentFlux` or `interpolateJ`.

## Interpolation Method Name Summary

| Analysis | Quantity | Method Name |
|----------|----------|-------------|
| Electrostatic | Potential | `interpolateElectricPotential` |
| Electrostatic | E-field | `interpolateElectricField` |
| Electrostatic | D-field | `interpolateElectricFlux` (NOT FluxDensity) |
| Magnetostatic | Potential | `interpolateMagneticPotential` |
| Magnetostatic | B-field | `interpolateMagneticFlux` (NOT FluxDensity) |
| Magnetostatic | H-field | `interpolateMagneticField` |
| DC Conduction | Potential | `interpolateElectricPotential` |
| DC Conduction | E-field | `interpolateElectricField` |
| DC Conduction | J-field | `interpolateCurrentDensity` (NOT CurrentFlux) |

----
Copyright 2026 The MathWorks, Inc.
----
