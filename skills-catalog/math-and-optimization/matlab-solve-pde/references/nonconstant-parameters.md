# Nonconstant (Function) Parameters — Full Reference

## Function Signatures

Most parameters: `@(location, state) ...`
Initial conditions only: `@(location) ...`

## location Structure

| Field | Available for |
|-------|--------------|
| `.x`, `.y`, `.z` | All parameters |
| `.nx`, `.ny`, `.nz` | Boundary conditions and boundary loads only |

## state Structure — Fields by Analysis Type

### Structural

| Parameter category | state fields received |
|-------------------|---------------------|
| Material properties (E, ν, G, ρ) | none — spatial only |
| BCs and loads (pressure, traction, force, spring, displacement) | `.time` or `.frequency` |
| Initial conditions (displacement, velocity) | one-arg function, no state |

### Thermal

| Parameter category | state fields received |
|-------------------|---------------------|
| Material properties (k, ρ, cp) + internal heat source | `.u`, `.ux`, `.uy`, `.uz`, `.time` |
| Boundary conditions (temperature, heat flux, convection) | `.u`, `.time` |
| Initial temperature | one-arg function, no state |

### Electromagnetic

| Parameter category | state fields received |
|-------------------|---------------------|
| Material properties — electrostatic/dcConduction | none — spatial only |
| Material properties — harmonic EM | `.frequency` |
| Material properties — nonlinear magnetostatic | `.NormFluxDensity`, `.u`, `.ux`, `.uy`, `.uz` |
| Sources (charge density, current density, magnetization) | same as material for that type |
| BCs (voltage, magnetic potential) | none |
| Initial conditions | one-arg (magnetostatic may receive `.NormFluxDensity`) |

## NaN Convention

The solver detects time/state dependence by calling the function with `NaN` in state fields. The function **must** return a `NaN` matrix of the correct output size. If it errors on NaN input, the solver cannot classify the dependence.

Pattern:

```matlab
myLoad = @(location, state) applyLoad(location, state);

function val = applyLoad(location, state)
    Np = numel(location.x);
    if isnan(state.time)
        val = NaN(1, Np);
        return
    end
    val = 1e5*sin(2*pi*100*state.time)*ones(1, Np);
end
```

## Output Size Rules

### Scalar parameters (pressure, temperature, density, etc.)

Return **1×Np** row vector where `Np = numel(location.x)`.

### Vector parameters

| Parameter | 2-D output | 3-D output |
|-----------|-----------|-----------|
| Surface traction | 2×Np | 3×Np |
| Force | 2×Np | 3×Np |
| Spring stiffness | 2×Np | 3×Np |
| Displacement (enforced) | 2×Np | 3×Np |
| Initial displacement/velocity | 2×Np | 3×Np |
| Current density (magnetostatic/harmonic 3-D) | 3×Np | 3×Np |
| Current density (magnetostatic/magneticHarmonic 2-D) | 1×Np | — |
| Current density (electricHarmonic 2-D) | 2×Np | — |
| Magnetization | 2×Np | 3×Np |

### Material vectors (orthotropic structural)

YoungsModulus, PoissonsRatio, ShearModulus: always **3×Np** (both 2-D and 3-D).

### Thermal conductivity (anisotropic)

Rows depend on dimension and form:
- 1 row: isotropic
- Ndim rows: diagonal anisotropy
- Ndim*(Ndim+1)/2 rows: symmetric tensor (upper triangle, column-major)
- Ndim² rows: full tensor

Where Ndim = 2 (2-D) or 3 (3-D). Columns = Np.

## Passing Additional Arguments

Use closures to supply extra data:

```matlab
amplitude = 1e5;
freq = 100;
myPressure = @(location, state) amplitude*sin(2*pi*freq*state.time)*ones(1, numel(location.x));
model.FaceLoad(2) = faceLoad(Pressure=myPressure);
```

Or wrap in a helper:

```matlab
model.FaceLoad(2) = faceLoad(Pressure=@(loc,s) myPressureFcn(loc, s, amplitude, freq));
```

## Summary Table: What Can Be a Function

| Category | Parameters | Depends on |
|----------|-----------|------------|
| Structural materials | E, ν, G, ρ | Space only |
| Structural BCs/loads | Pressure, Traction, Force, Spring, Displacement | Space + time/frequency |
| Thermal materials | k, ρ, cp, HeatSource | Space + temperature + time |
| Thermal BCs | Temperature, HeatFlux, Convection | Space + temperature + time |
| EM materials (static) | εr, μr, σ | Space only |
| EM materials (harmonic) | εr, μr, σ | Space + frequency |
| EM materials (nonlinear) | μr | Space + NormFluxDensity + u |
| EM sources | ChargeDensity, CurrentDensity, Magnetization | Same as material |

----
Copyright 2026 The MathWorks, Inc.
----
