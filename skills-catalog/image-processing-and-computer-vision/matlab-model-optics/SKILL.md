---
name: matlab-model-optics
description: >
  Build, import, analyze, tolerate, and optimize optical systems using the Optical Design and Simulation Library.
  Use when the user asks about optical systems, ray tracing, geometric optics, Zemax import, optical coatings, tolerancing, or optical design optimization.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Optical Design and Simulation Library

Use this skill when the user is working with the **Optical Design and Simulation Library** to build, import, analyze, tolerate, or optimize optical systems in MATLAB.

This library may also be referred to as:
- **Optical Design and Simulation Library**
- **Optics Support Package**
- **Optics Add-On**
- **Optics Library**
- **Optics Toolbox**

Use **Optical Design and Simulation Library** as the canonical name in responses unless the user explicitly uses a different name.

## When to Use

Use this skill when the user asks about:
- Optical Systems
- Ray Tracing
- Geometric Optics based analysis like lens distortion, spot diagrams, chromatic aberration, astigmatism and ray fans
- Paraxial Optics
- Optical Coatings
- Polarization or EM analysis (computing Fresnel Coefficients)
- Glass Materials and Glass Catalogs
- Zemax import
- Optical Tolerancing
- Optical System Design and Optimization
- Dynamic optical systems in Simulink (see `references/dynamic-optical-systems-simulink.md`)

## When NOT to Use

Do **not** use this skill when:
- The user is working with physical optics or wave optics (diffraction, interference, coherence)
- The user is working with fiber optics or photonics
- The user needs image processing or computer vision (use Image Processing Toolbox instead)
- The task is purely about Simulink modeling without optical system involvement

## First Steps

When helping a user who is new to the library, start with discovery:
```matlab
help optics
```

To get more details for a specific function:
```matlab
help lensDistortion
doc lensDistortion
```

Many optics APIs are class methods. For class methods, use:
```matlab
help className/functionName
doc className/functionName
```

Example:
```matlab
help opticalSystem/add
```

Use examples in the documentation when the user asks for a larger end-to-end workflow.

## Sample ZMX Files

The Optical Design and Simulation Library ships sample Zemax (`.zmx`) files in the `opticsdata` folder within the support package install location. To find the path:

```matlab
spkgRoot = fullfile(matlabshared.supportpkg.getSupportPackageRoot, "toolbox", "images", "supportpackages", "opticsdata");
dir(fullfile(spkgRoot, "*.zmx"))
```

When a user asks to work with a standard optical system (e.g., "a Cooke triplet", "a doublet", "a telephoto lens") but does not provide their own file:
1. List the available `.zmx` files in the `opticsdata` folder
2. Pick the sample system that best matches the user's request
3. Import it using `zmximport`

This avoids asking the user for a file path when a suitable sample already exists.

## Core Concepts

### opticalSystem

`opticalSystem` is the central object representing a physical optical system.
```matlab
opsys = opticalSystem(Wavelengths=[486.134 587.562 656.281]);
```

### opticalMaterial

`opticalMaterial` represents a glass or optical material.
```matlab
mat = opticalMaterial([1.5168 64.17]);
mat = pickGlass("N-BK7");
```

### opticalCoating

`opticalCoating` represents a thin-film coating applied to surfaces.
```matlab
oc = opticalCoating(CoatingMaterial=["MgF2" "TiO2"], LayerMaterialIndex=[1 2 1 2], LayerThickness=[1 0.5 1 0.5], PrimaryWavelength=550);
oc = pickCoating("AR_MgF2_VIS");
addCoating(opsys, oc);
addCoating(opsys, oc, CoatingSide="front");
```

## Coordinate Systems

Refer to the MATLAB Documentation page called **"Coordinate Systems in Optical Design"** to learn about the coordinate system conventions used to construct optical systems.

### Field Point Angle Convention

When creating a field point with `fieldPoint(Angles=[Hy Hx])`:
- `Hy` — vertical field angle (degrees)
- `Hx` — horizontal field angle (degrees)

Example — a field point at 10 degrees vertical:
```matlab
fp = fieldPoint(Angles=[10 0]);
```

A field point at 10 degrees horizontal:
```matlab
fp = fieldPoint(Angles=[0 10]);
```

### TiltAngles Convention

`TiltAngles=[Rx Ry Rz]` specifies rotations in degrees about each axis:
- `Rx` (first element) — rotation about the X-axis
- `Ry` (second element) — rotation about the Y-axis
- `Rz` (third element) — rotation about the Z-axis

Example — a mirror tilted 45 degrees about the X-axis:
```matlab
addMirror(opsys, TiltAngles=[45 0 0]);
```

## Common Interaction Patterns

### Pattern: Build → Visualize → Analyze

Many user requests follow this sequence:
1. Build or import an optical system
2. Define field points and wavelengths
3. Run an analysis function
4. Inspect returned values
5. Visualize results

```matlab
%% 1. Build
opsys = opticalSystem(Wavelengths=587.562);
addRefractiveSurface(opsys, Radius=50, Material=pickGlass("N-BK7"), SemiDiameter=10, DistanceToNext=5);
addRefractiveSurface(opsys, Radius=-50, SemiDiameter=10, DistanceToNext=20);
addImagePlane(opsys, SemiDiameter=10);
opsys.FieldPoints = fieldPoint(Angles=[0 0; 10 0]);

%% 2. Visualize
h2 = view2d(opsys);

%% 3. Analyze
tra = rayAberration(opsys);
hra = show(tra);
```

### Pattern: Compute → Show

Many analyses follow a **compute first, visualize second** pattern.
```matlab
spotResult = spot(opsys);
spotDiagram(spotResult);
```

```matlab
ldResult = lensDistortion(opsys);
show(ldResult);
```

Use this pattern when the user wants both a numeric result and a plot.

### Pattern: Fresh Copy of Optical System

Explicitly create a fresh copy of the original system if you want to use it as a starting point for multiple different changes. This is particularly useful for tolerancing and sensitivity analysis, where parameters of the original system are mutated repeatedly.
```matlab
newSys = copy(opsys);
```

This avoids accumulating perturbations across trials unless accumulation is explicitly intended.

## Task: Construct Optical System from Prescription Table

Sequential optical systems are often specified as **prescription tables** (common in patent documents, textbooks, and optical design references).

Each row represents a surface or optical element, with columns such as:
- Radius of curvature
- Thickness to next surface
- Material (name or [nd, vd])
- Surface type (implicit or explicit, e.g., stop or image plane)

Users may provide this data as a screenshot, an Excel sheet, or a manually entered table.

### Example Prescription Table (Explicit Stop Surface)

| Surface | Radius | Thickness | Material | Type |
|--------|--------|----------|----------|------|
| 1 | 50  | 5   | N-BK7 | Refractive |
| 2 | -50 | 5   | Air   | Refractive |
| 3 | —   | 5   | —     | Stop       |
| 4 | 40  | 5   | N-BK7 | Refractive |
| 5 | -40 | 20  | Air   | Refractive |
| 6 | Inf | 0   | Image | ImagePlane |

### Pattern: Table → Optical System

1. Create `opticalSystem`
2. Iterate over rows
3. For each row:
   - Refractive → `addRefractiveSurface`
   - Stop → `addDiaphragm`
   - ImagePlane → `addImagePlane`
4. Use thickness as `DistanceToNext` for preceding element

### Example Code

```matlab
opsys = opticalSystem(Wavelengths=587.562);

% Surface 1
addRefractiveSurface(opsys, Radius=50, Material=pickGlass("N-BK7"), DistanceToNext=5);
% Surface 2
addRefractiveSurface(opsys, Radius=-50, DistanceToNext=5);
% Stop (explicit element)
addDiaphragm(opsys, DistanceToNext=5);
% Surface 4
addRefractiveSurface(opsys, Radius=40, Material=pickGlass("N-BK7"), DistanceToNext=5);
% Surface 5
addRefractiveSurface(opsys, Radius=-40,DistanceToNext=20);
% Image plane
addImagePlane(opsys);

h2initial = view2d(opsys, Parent=figure);
```

### Update Semi Diameters of Surfaces

The semi-diameters of all the surfaces is set to the default value because the table does not provide this value. Instead, system descriptions usually provide a field of view (FOV).

#### Pattern: Set Semi-Diameters from Field of View

After building the optical system:
1. Use the field of view to define the target field angle
2. Identify the aperture constraint from the system description. See `help updateSemiDiameters` for valid constraint options.
3. Call updateSemiDiameters to compute semi-diameters for all surfaces

```matlab
FOV = 20;   % degrees
targetFieldAngle = FOV / 2;
updateSemiDiameters(opsys, "EntryPupilRadius", 5, TargetFieldAngle=targetFieldAngle);
h2Final = view2d(opsys, Parent=figure);
```

## Task: Create systems using components

Users often build optical systems by combining **off-the-shelf components** (e.g., vendor-provided designs such as singlets, doublets, or lens groups).

This workflow involves:
- importing existing designs
- modifying system structure
- explicitly managing **gaps between components**

### Pattern: Extend System with Component

1. Load the components or systems that will be used to construct the base system
2. Remove terminal components if needed (e.g., image plane)
3. Explicitly update gaps as removing components does not update the gap
4. Create the base system opticalSystem
5. Add loaded components one by one to the base system and set the gap between components suitably

### Example Code

```matlab
% Load existing system
opsysCooke = zmximport("CookeTriplet.zmx");
% Step 1: Remove image plane (if present)
remove(opsysCooke);
% Step 2: Removing a component does NOT remove the gap. Zero out the trailing gap
changeGap(opsysCooke, numel(opsysCooke.Components), 0);

% Step 3: Import singlet component
opsysSinglet = zmximport("singlet.zmx");

% Step 4: Create a new optical System with these two
opsys = opticalSystem(Name="Combined System");
add(opsys, opsysCooke);
changeGap(opsys, numel(opsys.Components), 3, GapLocation="after");

% Step 4: Append singlet to system
add(opsys, opsysSinglet);

h2 = view2d(opsys);
```

## Task: Add Mirrors or Folded Geometry

Use `addMirror` when the user wants to model reflective systems.

### Example: Periscope system with mirrors at 45 degrees

This periscope folds the beam in the Y-Z plane using X-axis rotations:
```matlab
opsys = opticalSystem();
addMirror(opsys, Radius=0, SemiDiameter=10, TiltAngles=[45 0 0]);
addGap(opsys, 50);
addMirror(opsys, Radius=0, SemiDiameter=10, TiltAngles=[-45 0 0]);
addGap(opsys, 20);
addImagePlane(opsys, SemiDiameter=10);

h = view2d(opsys);
addRays(h);
```

To fold in the X-Z plane instead, use Y-axis rotations: `TiltAngles=[0 45 0]`.

## Task: Use Ray Data

Use this when the analysis user is looking for is not available out of the box and the user has to derive it themselves using the RayData that is available as part of the RayBundle.

Pattern — plot incident angles on a specific surface using pupil coordinates:
```matlab
% Import a Cooke triplet
opsys = zmximport("CookeTriplet.zmx");

% Trace from 10-degree field point with incident angle data
fp = fieldPoint(Angles=[10 0]);
sg = samplingGrid("Hexapolar", 8);
rb = traceRays(opsys, FieldPoints=fp, Wavelengths=587.562, SamplingGrid=sg, RayProperties="IncidentAngle");
rd = rb(1).RayData;

% OrientedGrid gives normalized pupil XY for each ray
xy = rd.OrientedGrid;
% Incident angles on surface 4
angles = rd.IncidentAngle(:, 4);

% Scatter plot: position from pupil grid, size and color from angle
figure;
scatter(xy(:,1), xy(:,2), abs(angles)*5, angles, 'filled');
colorbar;
xlabel("Pupil X"); ylabel("Pupil Y");
title("Incident Angle on Surface 4 — Field Angle 10°");
axis equal;
```

## Task: Optimize a Design

Use design optimization when the user wants to improve performance starting from an initial optical system. See `references/optical-system-design.md` for detailed patterns, code templates, and optimizer selection guidance.

General workflow:
1. Define an initial optical system
2. Pack design variables (radii, thicknesses, materials, gaps) into a numeric vector
3. Create a helper function (`x2opsys`) to convert the vector back to an `opticalSystem`
4. Define a merit function using weighted performance metrics (focal length, spot RMS, track length)
5. Run a bounded optimizer (`lsqnonlin` for multi-objective, `fmincon` for scalar)
6. Reconstruct the optimized system and verify with `paraxialInfo`, `spot`, and `view2d`

Always call `updateSemiDiameters` inside the parameter-to-system conversion to maintain the aperture constraint after every parameter change.

## Task: Optical Coating Design

Use this when the user wants to design, analyze, or optimize thin-film optical coatings (AR coatings, bandpass filters, longpass/shortpass filters, notch filters). See `references/optical-coating-design.md` for detailed patterns and optimization templates.

General workflow:
1. Define coating materials using `pickCoatingMaterial`
2. Specify layer structure via `LayerMaterialIndex` (alternating high/low index)
3. Create the coating with `opticalCoating` and layer thicknesses
4. Query spectral response with `fresnelCoefficients`
5. For optimization: pack thicknesses into a vector, define spectral band goals, run a bounded optimizer

Key functions:
- `pickCoatingMaterial("SiO2")` — load a coating material
- `opticalCoating(...)` — create multi-layer coating
- `fresnelCoefficients(oc, Wavelengths=..., IncidentAngles=...)` — compute transmittance/reflectance
- Access `fq.Ta` (total transmittance), `fq.Ra` (total reflectance), or polarization-resolved properties

## Task: Optical Coating Tolerancing

Use this when the user wants to evaluate manufacturing sensitivity or yield of a coating design. See `references/optical-coating-tolerance.md` for detailed patterns and Monte Carlo templates.

General workflow:
1. Define the nominal coating design
2. Specify manufacturing tolerances (thickness sigma per material, refractive index sigma)
3. Choose analysis type:
   - **Sensitivity**: perturb each layer individually, measure impact on performance
   - **Monte Carlo yield**: run N randomized trials with Gaussian perturbations, compute pass rate
4. Evaluate each sample against a pass/fail spec using `fresnelCoefficients`
5. Compute yield percentage and visualize tolerance envelope

Key considerations:
- Use `parfor` for Monte Carlo trials (each trial is independent)
- Model thickness and refractive index variations as independent Gaussian perturbations
- Material-specific sigma values (high-index materials typically have larger variability)
- 400+ trials for reliable yield estimates; 1000+ for final qualification

## Additional Notes
- `imref2d` can be useful when converting physical locations on a 2D plane into pixel locations.
- For dynamic optical systems in Simulink, see `references/dynamic-optical-systems-simulink.md`

### Embedding view3d / view2d in UI Apps

When placing `view3d` or `view2d` inside a `uifigure` layout, use a `uigridlayout` (not a `uipanel`) as the parent so the viewer chart fills the available space:

```matlab
gl = uigridlayout(parentContainer, [1 1], Padding=[0 0 0 0]);
osv3d = view3d(opsys, Parent=gl);
```

Chart objects auto-stretch to fill grid layout cells but do not auto-resize inside plain `uipanel` containers.

----

Copyright 2026 The MathWorks, Inc.

----
