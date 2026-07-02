# Optical Coating Design Optimization

Use this reference when the user wants to design or optimize thin-film optical coatings. The reference teaches how to decompose any coating optimization request into a standard problem structure.

## Problem Structure

Every coating design optimization maps to this structure:

```
User Request → Materials + Layer Structure + Spectral Goals → x2opticalCoating + Merit Function → Optimizer
```

Your job is to identify each piece from the user's request and assemble them.

## Step 1: Identify Materials and Layer Structure

From the user's request, determine **what materials** to use and how they alternate.

Examples of how user language maps to material choices:

| User says... | Materials |
|---|---|
| "anti-reflection coating" | Low-index (MgF₂, SiO₂) + high-index (TiO₂, Ta₂O₅) |
| "visible range filter" | SiO₂ / TiO₂ pairs |
| "IR coating" | ZnSe / Ge or similar IR-transparent materials |
| "rugged / durable" | Thicker protective top layer |

The user's request may involve materials not listed here — use domain knowledge to select appropriate coating materials.

```matlab
design.Materials = [pickCoatingMaterial("SiO2"), pickCoatingMaterial("TiO2")];
design.NumberOfLayers = 48;
design.LayerMaterialIndex = repmat([2 1], [1 design.NumberOfLayers/2]);
design.Substrate = pickGlass("N-BK7");
```

- `LayerMaterialIndex` maps each layer to a material (alternating high/low is typical but not required)
- Number of layers depends on how sharp the spectral transitions need to be

## Step 2: Define Design Variables and Ranges

The design variables are the **layer thicknesses** (one per layer), packed into a numeric vector `x`.

Suggested starting ranges (adjust based on materials and application):

| Parameter | Typical Range | Rationale |
|-----------|--------------|-----------|
| Low-index layer (SiO₂, MgF₂) | 20–200 nm | Minimum fabricable, max before stress issues |
| High-index layer (TiO₂, Ta₂O₅) | 20–150 nm | High-index layers are typically thinner |
| Protective top layer | 20–1000 nm | Thicker for durability |
| Number of layers | 10–100 | More = sharper transitions, harder to fabricate |

```matlab
lb = repmat(20, [1 design.NumberOfLayers]);
ub = repmat([150 50], [1 design.NumberOfLayers/2]);  % [high-n, low-n]
```

## Step 3: Define Spectral Goals

The goal is the central organizing concept. It bundles together:

- **Spectral bands** — wavelength regions of interest
- **Response targets** — what the coating should do in each band (transmit, reflect, block)
- **Incident angles** — at what angles the coating must perform
- **Weights** — relative importance of each band

Extract these from the user's request. Examples:

| User says... | Bands | Targets |
|---|---|---|
| "block UV, pass visible" | UV (300–400 nm), VIS (420–700 nm) | UV: Ta ≤ 0.01, VIS: Ta ≥ 0.98 |
| "longpass filter cutting at 550 nm" | Stop (350–545 nm), Pass (555–750 nm) | Stop: Ta ≤ 0.01, Pass: Ta ≥ 0.98 |
| "narrow bandpass at 632 nm" | Reject (outside), Pass (625–640 nm) | Reject: Ta ≤ 0.01, Pass: Ta ≥ 0.95 |
| "AR coating for 400–700 nm" | VIS (400–700 nm) | Ra ≤ 0.005 |

The user's request may involve spectral goals not shown above — use domain knowledge to define appropriate bands and targets.

```matlab
goals.Bands(1).ResponseFcn = @(fq) fq.Ta;       % What to measure
goals.Bands(1).Wavelengths = linspace(350, 545, 100);  % Where
goals.Bands(1).DesiredRange = [0.01 0];          % [max allowed, target]
goals.Bands(1).IncidentAngles = [0 5];           % At what angles
goals.Bands(1).Weight = 3;                       % How important
```

**Weight guidelines:**
- Stop bands (rejection): higher weight — harder to achieve
- Pass bands (transmission): lower weight — easier to achieve
- Angular performance: include multiple angles if the user needs off-normal operation

## Step 4: Write the Conversion Function (x2opticalCoating)

This function maps the thickness vector `x` back into a fully constructed `opticalCoating`. It is called at every optimizer iteration.

```matlab
function oc = x2opticalCoating(x, design)
    oc = opticalCoating(...
        CoatingMaterials=design.Materials, ...
        LayerMaterialIndex=design.LayerMaterialIndex, ...
        LayerThickness=x, ...
        Substrate=design.Substrate);
end
```

## Step 5: Write the Merit Function

The merit function evaluates the coating against the spectral goals. It returns weighted residuals — one per wavelength per band per angle.

```matlab
function totres = coatingMeritFunc(oc, goals)
    totres = [];
    for i = 1:numel(goals.Bands)
        band = goals.Bands(i);

        % Query spectral response
        fq = fresnelCoefficients(oc, ...
            Wavelengths=band.Wavelengths, ...
            IncidentAngles=band.IncidentAngles);
        actResponse = band.ResponseFcn(fq);

        % Compute residuals vs desired range
        if band.DesiredRange(1) > band.DesiredRange(2)
            % Pass band: penalize values below minimum
            residuals = max(0, band.DesiredRange(2) - actResponse);
        else
            % Stop band: penalize values above maximum
            residuals = max(0, actResponse - band.DesiredRange(1));
        end

        totres = [totres; band.Weight * residuals(:)];
    end
end
```

## Step 6: Choose and Run the Optimizer

| Scenario | Optimizer | Why |
|----------|-----------|-----|
| Multi-band spectral targets | `lsqnonlin` | Handles vector residuals natively |
| Single scalar metric (e.g., average reflectance) | `fmincon` | General constrained minimization |
| Many layers, many local minima | `ga` or `surrogateopt` | Global search avoids local traps |
| Interactive exploration | Optimization Explorer app | Visual, supports multiple solvers |

```matlab
x0 = (lb + ub) / 2;

meritFcn = @(x) coatingMeritFunc(x2opticalCoating(x, design), goals);

options = optimoptions('lsqnonlin', Display='iter', MaxFunctionEvaluations=10000);
[xOpt, resnorm] = lsqnonlin(meritFcn, x0, lb, ub, options);

% Reconstruct optimized coating
ocOpt = x2opticalCoating(xOpt, design);
```

## Spectral Response Properties

`fresnelCoefficients` returns a struct with:

| Property | Description |
|----------|-------------|
| `Ta` | Total transmittance |
| `Ra` | Total reflectance |
| `Ts` | S-polarization transmittance |
| `Tp` | P-polarization transmittance |
| `Rs` | S-polarization reflectance |
| `Rp` | P-polarization reflectance |

Use the appropriate property in `band.ResponseFcn` based on what the user cares about (unpolarized → `Ta`/`Ra`, polarization-sensitive → `Ts`/`Tp`/`Rs`/`Rp`).

## Verifying Results

After optimization, visualize the spectral response:

```matlab
fq = fresnelCoefficients(ocOpt, Wavelengths=linspace(300, 800, 500));
figure;
plot(linspace(300, 800, 500), fq.Ta);
xlabel("Wavelength (nm)");
ylabel("Transmittance");
title("Optimized Coating Response");
```

## Mapping User Requests — Examples

| User request | Materials | Variables | Goal bands |
|---|---|---|---|
| "Longpass filter at 550 nm" | SiO₂/TiO₂ | Layer thicknesses | Stop < 545 nm, pass > 555 nm |
| "Broadband AR for visible" | MgF₂/TiO₂ | Layer thicknesses | Minimize Ra over 400–700 nm |
| "Notch filter rejecting 532 nm" | SiO₂/TiO₂ | Layer thicknesses | Reject 525–540 nm, pass rest |
| "Dual-band pass (red + NIR)" | SiO₂/Ta₂O₅ | Layer thicknesses | Pass 620–660 + 800–850 nm |

## Reference Example

See the MATLAB example **"Optimize Coating Design for Longpass Optical Filter"** for the complete end-to-end workflow including the Optimization Explorer app and parallel computing.

----

Copyright 2026 The MathWorks, Inc.

----
