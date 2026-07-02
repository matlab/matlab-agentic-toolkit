# Time-Dependent Loads and NaN Convention

## How the NaN Probe Works

1. Solver calls function with `state.time = NaN`
2. If function returns `NaN` → coefficient is time-dependent (re-evaluated every step)
3. If function returns numeric → treated as constant for entire simulation

## When You Need Explicit isnan Check

Any function with **conditional logic** (if/else, piecewise):

```matlab
function F = pulseForce(t)
    if isnan(t)
        F = NaN;
        return
    end
    if t <= 0.005
        F = -5000 * sin(pi * t / 0.005);
    else
        F = 0;
    end
end
```

Without check: `NaN <= 0.005` → false → returns 0 → solver uses constant 0 forever.

```matlab
function h = rampConvection(t)
    if isnan(t)
        h = NaN;
    elseif t < 5
        h = 10 + 18*t;
    else
        h = 100;
    end
end
```

## When NaN Propagates Automatically

**Pure arithmetic** (no conditionals):

```matlab
heat = @(location, state) 100 * sin(2*pi*state.time) * ones(1, numel(location.x));
flux = @(location, state) state.time * 500 * ones(1, numel(location.x));
```

**Interpolation objects** (`griddedInterpolant` with `'none'` extrapolation):

```matlab
heatInterp = griddedInterpolant(tData, qData, 'linear', 'none');
heatFcn = @(location, state) heatInterp(state.time) * ones(1, numel(location.x));
```

## Vectorization Requirement

Load functions must return **1×N row vector** (N = number of evaluation points):

```matlab
% WRONG: scalar
heat = @(location, state) 500;

% CORRECT: 1×N
heat = @(location, state) 500 * ones(1, numel(location.x));

% CORRECT: spatially varying (location fields are already 1×N)
heat = @(location, state) 500 * location.y / maxY;
```

## Full Pattern (conditional + vectorized)

```matlab
function q = timeVaryingHeat(location, state)
    nPts = numel(location.x);
    t = state.time;
    if isnan(t)
        q = NaN(1, nPts);
    elseif t < 2
        q = 1000 * t/2 * ones(1, nPts);
    else
        q = 1000 * ones(1, nPts);
    end
end
```

## Applies to ALL Time-Dependent Quantities

- `faceLoad(Heat=@fcn)` — thermal heat flux
- `faceLoad(ConvectionCoefficient=@fcn)` — time-varying convection
- `vertexLoad(Force=@fcn)` — structural concentrated force
- `faceLoad(Pressure=@fcn)` — structural pressure
- `faceLoad(SurfaceTraction=@fcn)` — structural traction
- `cellLoad(Heat=@fcn)` — volumetric heat generation
- Any other function-handle coefficient in the femodel workflow

## Debugging Symptom

If transient results show:
- Zero displacement/temperature change despite applied loads
- Constant results that don't vary with time
- Results that look like steady-state

→ Check conditional load functions for missing `isnan` handling.

----
Copyright 2026 The MathWorks, Inc.
----
