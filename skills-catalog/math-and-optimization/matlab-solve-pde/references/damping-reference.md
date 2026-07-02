# Structural Damping Reference

Three damping forms are available, each for different analysis types.

## Hysteretic Damping

Material-level loss factor. Reduces resonance peaks. Only for `structuralFrequency` (direct solve).

```matlab
model.MaterialProperties = materialProperties(YoungsModulus=210e9, ...
    PoissonsRatio=0.3, MassDensity=7800, HystereticDamping=0.05);
```

## Rayleigh Damping (Proportional)

C = alpha*M + beta*K. Set on femodel (defaults 0). Works with `structuralTransient` and `structuralFrequency`.

```matlab
model.DampingAlpha = 10;   % Mass-proportional (damps low frequencies)
model.DampingBeta = 0.002; % Stiffness-proportional (damps high frequencies)
```

## Modal Damping (DampingZeta)

Damping ratio passed at solve time with modal superposition. Scalar (uniform) or function handle (frequency-dependent). Works for transient or frequency response via modal results.

```matlab
% First compute modes
Rm = solve(model, FrequencyRange=[-Inf, 2*pi*500]);

% Transient with uniform 2% damping ratio
model.AnalysisType = "structuralTransient";
R = solve(model, tlist, ModalResults=Rm, DampingZeta=0.02);

% Frequency-dependent damping
zetaFcn = @(omega) 0.01 + 0.001*(omega/2/pi/100);
R = solve(model, flist, ModalResults=Rm, DampingZeta=zetaFcn);
```

## Summary Table

| Form | Where set | Applies to |
|------|-----------|------------|
| Hysteretic | `materialProperties(..., HystereticDamping=eta)` | `structuralFrequency` (direct solve) |
| Rayleigh | `model.DampingAlpha=a; model.DampingBeta=b;` | `structuralTransient`, `structuralFrequency` |
| Modal | `solve(model, tlist, ModalResults=Rm, DampingZeta=zeta)` | Transient/frequency via modal superposition |

## When to Use Each

- **Hysteretic:** Simplest for frequency sweeps. One material parameter. Does not apply to transient.
- **Rayleigh:** Two coefficients. Approximate real damping over a limited frequency band. Choose alpha and beta to match measured damping at two target frequencies.
- **Modal:** Most flexible. Requires prior modal solve. Can assign different damping per mode if needed (function handle form).

----
Copyright 2026 The MathWorks, Inc.
----
