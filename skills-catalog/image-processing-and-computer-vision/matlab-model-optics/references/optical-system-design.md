# Optical System Design Optimization

Use this reference when the user wants to optimize an optical system's performance by varying design parameters. The reference teaches how to decompose any optimization request into a standard problem structure.

## Problem Structure

Every optical design optimization maps to this structure:

```
User Request → Design Variables + Ranges + Goal → x2opsys + Merit Function → Optimizer
```

Your job is to identify each piece from the user's request and assemble them.

## Step 1: Identify Design Variables

From the user's request, determine **what can change**. Pack these into a flat numeric vector `x`.

Examples of how user language maps to variables:

| User says... | Design variables |
|---|---|
| "optimize the lens shape" | Radii of curvature |
| "find the best thickness" | Lens center thicknesses |
| "adjust spacing between elements" | Air gaps |
| "find the best glass" | Refractive index (Nd), Abbe number (Vd) |
| "optimize the whole system" | All of the above |

These are common cases — the user's request may suggest other variables not listed here.

```matlab
% Pack into a vector
x = [radii, thicknesses, gaps, materials];
```

Record how to unpack `x` back into named parameters (indices into the vector).

## Step 2: Define Ranges

Every design variable needs physical bounds. These prevent the optimizer from exploring unphysical or unfabricable designs.

Suggested starting ranges (adjust based on system scale and user context):

| Parameter | Typical Range | Rationale |
|-----------|--------------|-----------|
| Radius of curvature | ±5 mm to ±500 mm | Near-zero = infinite power (singularity) |
| Lens thickness | 1 mm to 15 mm | Must be positive and fabricable |
| Air gap | 0.5 mm to 30 mm | Must be positive |
| Refractive index (Nd) | 1.45 to 1.85 | Range of common optical glasses |
| Abbe number (Vd) | 20 to 80 | Low = flint, high = crown |

```matlab
lb = [...];  % Lower bounds for each element of x
ub = [...];  % Upper bounds for each element of x
```

## Step 3: Define the Goal

The goal is the central organizing concept. It bundles together:

- **Metrics** — what to measure (focal length, spot RMS, distortion, track length, MTF, etc.)
- **Field points** — where to evaluate those metrics (on-axis, intermediate, full-field edge)
- **Targets** — what values the metrics should achieve
- **Weights** — relative importance of each metric

Extract these from the user's request. Examples:

| User says... | Metrics | Field points |
|---|---|---|
| "sharper image across the field" | Spot RMS | On-axis + intermediate + edge |
| "wider field of view" | Spot RMS, distortion | Multiple angles up to new FOV |
| "match this focal length at f/4" | Focal length, F-number | On-axis |
| "minimize chromatic aberration" | Spot RMS at multiple wavelengths | On-axis + edge |
| "compact design" | Track length + spot RMS | On-axis + edge |

The user's request may involve metrics or field point strategies not shown above — use domain knowledge to identify the right combination.

```matlab
goal.Metrics = {...};           % What to measure
goal.FieldPoints = fieldPoint(...);  % Where to evaluate
goal.Targets = [...];           % What values to achieve
goal.Weights = [...];           % Relative importance
```

**Weight guidelines:**
- Hard constraints (must be met exactly): high weight (5–10)
- Primary performance (the user's main ask): medium-high weight (1–3)
- Soft constraints (nice to have): low weight (0.1–0.5)

## Step 4: Write the Conversion Function (x2opsys)

This function maps the numeric vector `x` back into a fully constructed `opticalSystem`. It is called at every optimizer iteration.

```matlab
function opsys = x2opsys(x, design, goal)
    % Unpack x into named parameters
    radii       = x(1:design.NumRadius);
    thicknesses = x(...);
    gaps        = x(...);

    % Build system
    opsys = opticalSystem(Wavelengths=design.Wavelengths);

    % Add surfaces using unpacked parameters
    for i = 1:design.NumLenses
        addRefractiveSurface(opsys, Radius=radii(2*i-1), ...
            Material=..., DistanceToNext=thicknesses(i));
        addRefractiveSurface(opsys, Radius=radii(2*i), ...
            DistanceToNext=gaps(i));
    end

    addImagePlane(opsys);

    % Apply any system-level constraints from the goal
    % (e.g., updateSemiDiameters if aperture is fixed, set field points, etc.)
end
```

The conversion function must produce a valid, analyzable system for any `x` within bounds.

## Step 5: Write the Merit Function

The merit function evaluates the system against the goal. It returns:
- A **vector of weighted residuals** (for `lsqnonlin`) — one residual per metric per field point
- Or a **scalar** (for `fmincon`) — single combined error

```matlab
function F = meritFunction(opsys, goal)
    F = [];

    % For each metric in the goal, evaluate at the goal's field points
    % Compare to targets, weight, and append to residual vector

    % Example: focal length error
    pInfo = paraxialInfo(opsys);
    focalErr = goal.Weights.Focal * (pInfo.FocalLength - goal.Targets.FocalLength) / goal.Targets.FocalLength;
    F = [F, focalErr];

    % Example: spot RMS at each field point
    spotResults = spot(opsys, FieldPoint=goal.FieldPoints);
    spotErr = goal.Weights.Spot .* ([spotResults.RMS] - goal.Targets.SpotRMS) / goal.Targets.SpotRMS;
    F = [F, spotErr];
end
```

The merit function is where the goal struct drives the evaluation — metrics, field points, targets, and weights all come from it.

## Step 6: Choose and Run the Optimizer

| Scenario | Optimizer | Why |
|----------|-----------|-----|
| Multiple metrics (focal + spot + distortion) | `lsqnonlin` | Handles vector residuals natively |
| Single scalar objective | `fmincon` | General constrained minimization |
| Many local minima (glass search, many elements) | `ga` or `surrogateopt` | Global search |
| Interactive exploration | Optimization Explorer app | Visual, supports multiple solvers |

```matlab
x0 = (lb + ub) / 2;  % or extract from the starting system

meritFcn = @(x) meritFunction(x2opsys(x, design, goal), goal);

options = optimoptions('lsqnonlin', Display='iter', MaxFunctionEvaluations=5000);
[xOpt, resnorm] = lsqnonlin(meritFcn, x0, lb, ub, options);

% Reconstruct optimized system
opsysOpt = x2opsys(xOpt, design, goal);
```

## Verifying Results

After optimization, verify against the goal:

```matlab
pInfo = paraxialInfo(opsysOpt);
spotResult = spot(opsysOpt, FieldPoint=goal.FieldPoints);
spotDiagram(spotResult);
view2d(opsysOpt);
```

## Mapping User Requests — Examples

| User request | Variables | Goal metrics | Goal field points |
|---|---|---|---|
| "Optimize Cooke triplet for wider FOV" | Radii, gaps | Spot RMS, focal length | On-axis + new edge angle |
| "Find best glass for a doublet at f/5" | Nd, Vd | Chromatic spot RMS | On-axis + 10° |
| "Minimize total track length" | Thicknesses, gaps | Track length, spot RMS | On-axis + edge |
| "Sharpen the edges without hurting center" | Radii, gaps | Spot RMS | Edge-heavy weights |
| "Design a 50mm f/1.8 with <20µm spot" | All | Focal length, F-number, spot RMS | Multiple field angles |

## Reference Example

See the MATLAB example **"Optimize Monochromatic Camera Lens System for Type 2/3 Sensor"** for a complete end-to-end workflow.

----

Copyright 2026 The MathWorks, Inc.

----
