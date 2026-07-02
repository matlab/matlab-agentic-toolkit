# Optical Coating Tolerance and Yield Analysis

Use this reference when the user wants to evaluate manufacturing sensitivity or yield of an optical coating design. The reference teaches how to decompose any tolerancing request into a standard problem structure.

## Problem Structure

Every coating tolerance analysis maps to this structure:

```
User Request → Parameters to Perturb + Ranges + Metric + Pass/Fail Criterion → Monte Carlo or Sensitivity Analysis
```

Your job is to identify each piece from the user's request and assemble them.

## Step 1: Identify Parameters to Perturb

From the user's request, determine **what varies during manufacturing**. Each parameter gets its own perturbation model.

Examples of what can vary:

| User says... | Parameters to perturb |
|---|---|
| "how sensitive to thickness errors" | Layer thicknesses |
| "what if refractive index drifts" | Refractive index (Nd) per material |
| "manufacturing tolerance study" | Both thickness and refractive index |
| "deposition uniformity" | Layer thicknesses (spatially correlated) |

The user's request may involve perturbation sources not listed here — use domain knowledge to identify what matters for their process.

```matlab
% Define which parameters to perturb
perturb.Thickness = true;
perturb.RefractiveIndex = true;
```

## Step 2: Define Perturbation Ranges

Each parameter needs a sigma (standard deviation) for the Gaussian perturbation model. These are typically **material-specific** — different materials have different process stability.

Suggested starting values (adjust based on the user's deposition method):

| Parameter | Evaporation | Sputtering | Rationale |
|-----------|-------------|------------|-----------|
| Thickness sigma (low-n, e.g., SiO₂) | 1.5–3 nm | 0.5–1.5 nm | Low-n more stable |
| Thickness sigma (high-n, e.g., TiO₂) | 2–4 nm | 1–2 nm | High-n more variable |
| Refractive index sigma (SiO₂) | 0.002–0.005 | 0.001–0.003 | Process-dependent |
| Refractive index sigma (TiO₂) | 0.005–0.010 | 0.003–0.007 | More sensitive to conditions |

The user may specify their own sigma values or deposition method — use those if provided.

```matlab
% Material-specific sigmas
thicknessSigma = [2.0, 1.5];   % [TiO2, SiO2] in nm — indexed by material
NdSigma = [0.008, 0.004];      % [TiO2, SiO2] refractive index
```

## Step 3: Define the Metric to Evaluate

Determine **what spectral response property** the user cares about. This comes from `fresnelCoefficients`.

| Property | Description | Typical use |
|----------|-------------|-------------|
| `Ta` | Total transmittance | Filters, bandpass |
| `Ra` | Total reflectance | AR coatings, mirrors |
| `Ts` | S-polarization transmittance | Polarization-sensitive applications |
| `Tp` | P-polarization transmittance | Polarization-sensitive applications |
| `Rs` | S-polarization reflectance | Polarizing beam splitters |
| `Rp` | P-polarization reflectance | Brewster angle devices |

Extract from the user's request. Examples:

| User says... | Metric | Wavelengths | Angles |
|---|---|---|---|
| "AR coating must stay below 0.5% reflection" | `Ra` | Design band | 0° |
| "filter must block OD2 in stop band" | `Ta` | Stop band wavelengths | 0°, 5° |
| "polarization extinction ratio" | `Ts` and `Tp` | Operating wavelength | Design angle |
| "mirror reflectivity" | `Ra` | Design band | Incidence angle |

```matlab
% Define evaluation conditions
eval.ResponseFcn = @(fq) fq.Ra;          % What to measure
eval.Wavelengths = linspace(400, 700, 100);  % Where
eval.IncidentAngles = [0 5];              % At what angles
```

## Step 4: Define Pass/Fail Criterion

The pass/fail criterion determines whether a perturbed sample is acceptable. It applies the metric from Step 3 against a threshold.

```matlab
% Pass/fail: coating passes if metric meets spec across all wavelengths/angles
eval.PassFcn = @(response) all(response(:) <= 0.005);  % e.g., Ra ≤ 0.5%
```

Examples:

| Application | Pass criterion |
|---|---|
| AR coating | `max(Ra(:)) <= 0.005` |
| Longpass filter (stop band) | `max(Ta(stopBand)) <= 0.01` |
| Longpass filter (pass band) | `min(Ta(passBand)) >= 0.95` |
| Mirror | `min(Ra(:)) >= 0.99` |

For multi-band coatings, combine criteria: pass only if ALL bands meet their specs.

## Step 5: Run the Analysis

Two analysis types — choose based on what the user wants:

### Sensitivity Analysis (which layers matter most)

Perturb each layer individually by a fixed amount. Identifies critical layers.

```matlab
perturbation = 2;  % nm
sensitivity = zeros(1, numel(oc.LayerThickness));

for i = 1:numel(oc.LayerThickness)
    thicknesses = oc.LayerThickness;
    thicknesses(i) = thicknesses(i) + perturbation;

    ocPerturbed = opticalCoating(...
        CoatingMaterials=oc.CoatingMaterials, ...
        LayerMaterialIndex=oc.LayerMaterialIndex, ...
        LayerThickness=thicknesses, ...
        Substrate=oc.Substrate);

    fq = fresnelCoefficients(ocPerturbed, ...
        Wavelengths=eval.Wavelengths, ...
        IncidentAngles=eval.IncidentAngles);
    response = eval.ResponseFcn(fq);
    sensitivity(i) = max(response(:)) - nominalMax;
end

bar(sensitivity);
xlabel("Layer Number");
ylabel("Change in metric");
```

### Monte Carlo Yield (what percentage passes)

Run N randomized trials to estimate manufacturing yield.

```matlab
numTrials = 400;
passCount = 0;

parfor k = 1:numTrials
    % Perturb thicknesses
    perturbedThickness = oc.LayerThickness + ...
        randn(size(oc.LayerThickness)) .* thicknessSigma(oc.LayerMaterialIndex);

    % Perturb refractive indices (per material)
    perturbedMaterials = oc.CoatingMaterials;  % Copy, then modify Nd per material

    % Create perturbed coating
    ocSample = opticalCoating(...
        CoatingMaterials=perturbedMaterials, ...
        LayerMaterialIndex=oc.LayerMaterialIndex, ...
        LayerThickness=perturbedThickness, ...
        Substrate=oc.Substrate);

    % Evaluate
    fq = fresnelCoefficients(ocSample, ...
        Wavelengths=eval.Wavelengths, ...
        IncidentAngles=eval.IncidentAngles);
    response = eval.ResponseFcn(fq);

    if eval.PassFcn(response)
        passCount = passCount + 1;
    end
end

yieldPercent = passCount / numTrials * 100;
```

## Yield Interpretation

| Yield | Assessment | Suggested action |
|-------|-----------|-----------------|
| > 95% | Production-ready | Proceed to manufacturing |
| 80–95% | Acceptable with screening | Tighten critical layers or add inspection |
| 50–80% | Marginal | Redesign or relax spec |
| < 50% | Unmanufacturable | Fundamental redesign needed |

## Performance Tips

- Use `parfor` for Monte Carlo trials — each trial is independent
- 400+ trials for reliable yield estimates (±2–3% confidence)
- Start with 100 trials during design iteration; use 1000+ for final qualification
- Pre-allocate results outside the parfor loop

## Mapping User Requests — Examples

| User request | Perturb | Metric | Pass/fail |
|---|---|---|---|
| "Will my AR coating survive ±2 nm thickness errors?" | Thickness (σ=2 nm) | Ra | Ra ≤ 0.5% across band |
| "Yield estimate for this bandpass filter" | Thickness + Nd | Ta | Stop ≤ 0.01, Pass ≥ 0.95 |
| "Which layers are most critical?" | Each layer individually | Ra or Ta | Sensitivity ranking |
| "Can we relax tolerance on the SiO₂ layers?" | SiO₂ thickness only | Ta | Compare yield at different sigmas |

## Reference Example

See the MATLAB example **"Sensitivity and Yield Analysis of Optical Coating Using Monte Carlo Simulation"** for the complete workflow including parallel execution and visualization.

----

Copyright 2026 The MathWorks, Inc.

----
