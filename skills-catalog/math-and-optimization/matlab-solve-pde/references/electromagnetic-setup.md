# Electromagnetic Model Setup

## Required Vacuum Constants

| Analysis | Required Constants |
|---|---|
| `electrostatic` | `VacuumPermittivity` |
| `magnetostatic` | `VacuumPermeability` |
| `dcConduction` | Neither (conductivity only) |
| `electricHarmonic` | Both `VacuumPermittivity` AND `VacuumPermeability` |
| `magneticHarmonic` | Both `VacuumPermittivity` AND `VacuumPermeability` |

```matlab
model.VacuumPermittivity = 8.854187817e-12;  % F/m
model.VacuumPermeability = 4*pi*1e-7;        % H/m
```

## Material Properties per Analysis

```matlab
% Electrostatic
model.MaterialProperties = materialProperties(RelativePermittivity=4);

% Magnetostatic
model.MaterialProperties = materialProperties(RelativePermeability=1);

% DC Conduction
model.MaterialProperties = materialProperties(ElectricalConductivity=5.8e7);

% Harmonic (all three required)
model.MaterialProperties = materialProperties(RelativePermittivity=4, ...
    RelativePermeability=1, ElectricalConductivity=0.01);
```

## EM Boundary Conditions

```matlab
model.FaceBC(faces) = faceBC(Voltage=100);                    % Electrostatic
model.FaceBC(faces) = faceBC(MagneticPotential=[0;0;0]);      % 3-D: vector [Ax;Ay;Az]
model.EdgeBC(edges) = edgeBC(MagneticPotential=0);            % 2-D: scalar
model.FaceBC(faces) = faceBC(ElectricField=[1;0;0]);          % Harmonic
model.FaceBC(faces) = faceBC(MagneticField=[Hx;Hy;0]);       % Tangential to face
model.FaceBC(outer) = faceBC(FarField=farFieldBC(Thickness=0.1));  % Absorbing BC
```

**MagneticPotential:** 3-D requires a 3-element vector `[Ax;Ay;Az]`; 2-D takes a scalar.

**MagneticField orientation:** Nedelec elements enforce tangential H only. Normal component is ignored. Orient H tangential to the face.

## CurrentDensity Format

The format depends on analysis type and dimensionality:

| Analysis | 2-D (faceLoad) | 3-D (cellLoad) | Function return |
|----------|----------------|-----------------|-----------------|
| `magnetostatic` | Scalar (Jz only) | 3-element vector or `ConductionResults` | 1×N (2-D) or 3×N (3-D) |
| `electricHarmonic` | 2-element vector | 3-element vector | 2×N (2-D) or 3×N (3-D) |
| `magneticHarmonic` | Scalar (Jz only) | 3-element vector | 1×N (2-D) or 3×N (3-D) |

```matlab
% Magnetostatic 2-D — scalar (Jz component only, applied out-of-plane)
model.FaceLoad(coilFace) = faceLoad(CurrentDensity=1e6);

% Magnetostatic 3-D — vector or function (3×N return)
model.CellLoad(coilCell) = cellLoad(CurrentDensity=[0; 0; 1e6]);
model.CellLoad(coilCell) = cellLoad(CurrentDensity=@applyJ);

% Magnetostatic 3-D — from DC conduction results (coupling)
model.CellLoad(coilCell) = cellLoad(CurrentDensity=conductionResults);

function J = applyJ(location, ~)
    x = location.x; y = location.y;
    r = sqrt(x.^2 + y.^2);
    J0 = 1e6;
    J = [-J0.*y./r; J0.*x./r; zeros(1, numel(x))];  % 3×N
end
```

**Key rule:** In 2-D magnetostatic/magneticHarmonic, current flows out-of-plane (z-direction only), so only a scalar Jz is needed. In 3-D, you specify the full vector.

## Nonlinear B-H Curve (Magnetostatic)

Two-step workflow: solve linear first, use result as initial guess for nonlinear.

```matlab
% Step 1: Linear solve with constant high muR
model.MaterialProperties(ironFace) = materialProperties(RelativePermeability=5000);
Rlin = solve(model);

% Step 2: Replace with nonlinear muR from tabulated B-H data
B = [0 0.3 0.8 1.12 1.32 1.46 1.54 1.62 1.74];
H = [0 29.8 79.6 159.2 318.3 795.8 1591.6 3376.7 7957.8];
HofB = griddedInterpolant(B, H, "makima", "linear");
mu0 = 4*pi*1e-7;
muRfcn = @(Bval) Bval ./ HofB(Bval) / mu0;

model.MaterialProperties(ironFace) = materialProperties(...
    RelativePermeability=@(~,s) muRfcn(s.NormFluxDensity));

% Use linear solution as initial guess for nonlinear solver
model.FaceIC = faceIC(MagneticVectorPotential=Rlin);
Rnonlin = solve(model);
```

**Key patterns:**
- Function handle signature: `@(location, state)` — use `state.NormFluxDensity`
- `griddedInterpolant` for B-H interpolation (not `interp1` inside the function)
- Linear result passed directly to `faceIC(MagneticVectorPotential=...)` as initial guess
- Without initial guess, nonlinear solver may fail with singular Jacobian

## Harmonic EM Solve

Frequency is positional (NOT a named argument):

```matlab
freqs = linspace(1e6, 1e9, 20);
result = solve(model, freqs);  % NOT Frequency=freqs
```

### CurrentDensity for Harmonic — Coordinate-Dependent Only

| Analysis | 2-D | 3-D |
|---|---|---|
| `electricHarmonic` | 2-element vector | 3-element vector or fn(coordinates) |
| `magneticHarmonic` | Scalar (Jz) | 3-element vector or fn(coordinates) |

```matlab
model.CellLoad(coil) = cellLoad(CurrentDensity=[0;0;1e4]);       % electricHarmonic 3-D
model.FaceLoad(coil) = faceLoad(CurrentDensity=1e4);             % magneticHarmonic 2-D
```

----
Copyright 2026 The MathWorks, Inc.
----
