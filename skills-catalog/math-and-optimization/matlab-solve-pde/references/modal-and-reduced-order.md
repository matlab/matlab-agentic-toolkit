# Modal Solve and Reduced-Order Methods

## FrequencyRange Rules

1. Use `-Inf` as lower bound when the user specifies a single frequency, a number of modes, or doesn't specify a lower bound — this captures rigid body modes at 0 Hz. If the user specifies an explicit frequency range (e.g., "modes between 500–2000 Hz"), respect their lower bound.
2. Never use `Inf` as upper bound (Lanczos solver errors)
3. Start small, widen iteratively

```matlab
result = solve(model, FrequencyRange=[-Inf, 1000]);
freqs = result.NaturalFrequencies;  % Column vector (Hz)
```

## Iterative Strategy for N Modes

```matlab
model.AnalysisType = "structuralModal";
numModesNeeded = 5;
upperBounds = [100, 1000, 10000, 100000];
for i = 1:numel(upperBounds)
    result = solve(model, FrequencyRange=[-Inf, upperBounds(i)]);
    if numel(result.NaturalFrequencies) >= numModesNeeded
        break;
    end
end
```

## Why `-Inf` Matters

Unconstrained structures have rigid body modes at 0 Hz. Using `[0, upper]` may miss them.

## Why Not Large Ranges

Dense meshes + wide ranges → "Found too many eigenvalues in an interval" error. Use coarser meshes or narrower ranges when iterating.

## Structural Modal Transient

```matlab
% 1. Base model
model = femodel(AnalysisType="structuralStatic", Geometry=gm);
model.MaterialProperties = materialProperties(YoungsModulus=200e9, ...
    PoissonsRatio=0.3, MassDensity=7800);
model.EdgeBC(fixedEdge) = edgeBC(Constraint="fixed");
model = generateMesh(model);

% 2. Compute modes
model.AnalysisType = "structuralModal";
modalResults = solve(model, FrequencyRange=[-Inf, 5000]);

% 3. Modal transient
model.AnalysisType = "structuralTransient";
model.FaceIC = faceIC(Displacement=[0;0], Velocity=[0;0]);
model.VertexLoad(tipVtx) = vertexLoad(Force=@(loc,state) pulseForce(state.time));
result = solve(model, tlist, ModalResults=modalResults);
```

## Thermal Modal Transient — Eigenvalue Method

```matlab
% Compute thermal decay modes
model.AnalysisType = "thermalModal";
modalResults = solve(model, DecayRange=[-Inf, 5]);

% Modal transient
model.AnalysisType = "thermalTransient";
model.CellIC = cellIC(Temperature=25);
result = solve(model, tlist, ModalResults=modalResults);
```

**`DecayRange` tuning:** Use `-Inf` as lower bound. Start with small upper bound (e.g., 5). Widen to 20 if accuracy is poor. Too wide → thousands of modes, no speedup.

## Thermal POD (Snapshots)

```matlab
% Solve at coarse times
model.AnalysisType = "thermalTransient";
coarseTlist = linspace(0, 40, 10);
snapshotResult = solve(model, coarseTlist);

% Fine resolution using snapshots as POD basis
fineTlist = linspace(0, 40, 200);
result = solve(model, fineTlist, Snapshots=snapshotResult.Temperature);
```

## When to Use Modal Transient

- Parametric studies (varying loads, same geometry)
- Optimization loops requiring many solves
- Long time histories where direct integration is expensive

Offline cost (modal solve) amortized across multiple transient evaluations.

----
Copyright 2026 The MathWorks, Inc.
----
