# Image Registration

Register and align 2-D images and 3-D volumes using intensity-based, deformable, groupwise, and surface-based methods.

> **Often loaded with:** `geometric-transforms.md` (applying transforms via `imwarp`), `image-io.md` (loading image pairs), `quality-assessment.md` (scoring a pair only after it is aligned).

## When NOT to Use This Reference

- Point cloud registration for non-medical data → use Computer Vision Toolbox (`pcregistericp`)

## Strategy Selection

| Scenario | Function | Toolbox | Speed |
|----------|----------|---------|-------|
| Feature-based (panorama, mosaic, large viewpoint change) | `detectSIFTFeatures` + `estgeotform2d` | CVT | Fast |
| Rigid/affine, same modality | `imregister` or `imregtform` + `imwarp` | IPT | Moderate |
| Rigid/affine, different modalities | `imregtform` with `"multimodal"` config | IPT | Moderate |
| Control-point (landmarks, fiducials) | `cpselect` + `fitgeotform2d` / `fitgeotform3d` (R2024a+) | IPT | Fast |
| Quick translation/rotation estimate | `imregcorr` | IPT | Fast |
| Fast similarity alignment (moment-based) | `imregmoment` | MIT | Very fast |
| Deformable (demons algorithm) | `imregdemons` | IPT | Slow |
| Deformable (total variation) | `imregdeform` | MIT | Moderate |
| Groupwise slice-to-slice | `imreggroupwise` | MIT | Moderate |
| Surface-based (ICP) | `extractIsosurface` + `imregicp` | MIT | Moderate |

IPT = Image Processing Toolbox, CVT = Computer Vision Toolbox, MIT = Medical Imaging Toolbox.

**When Medical Imaging Toolbox is available**, prefer the MIT functions — they are faster (`imregmoment`), more robust (`imregdeform`), or handle workflows that IPT doesn't cover (`imreggroupwise`, surface-based).

## Feature-Based Registration (Computer Vision Toolbox)

> **Requires:** Computer Vision Toolbox

### Workflow: Detect → Extract → Match → Estimate Transform

```matlab
% 1. Detect features in both images
pointsFixed = detectSIFTFeatures(im2gray(fixed));
pointsMoving = detectSIFTFeatures(im2gray(moving));

% 2. Extract descriptors
[featuresFixed, validPtsFixed] = extractFeatures(im2gray(fixed), pointsFixed);
[featuresMoving, validPtsMoving] = extractFeatures(im2gray(moving), pointsMoving);

% 3. Match descriptors
indexPairs = matchFeatures(featuresFixed, featuresMoving);
matchedFixed = validPtsFixed(indexPairs(:,1));
matchedMoving = validPtsMoving(indexPairs(:,2));

% 4. Estimate geometric transform with RANSAC
tform = estgeotform2d(matchedMoving, matchedFixed, "projective");

% 5. Apply transform
registered = imwarp(moving, tform, OutputView=imref2d(size(fixed)));
```

### Detector Selection

| Function | Type | Scale-Invariant | Rotation-Invariant | Best for |
|----------|------|-----------------|-------------------|----------|
| `detectSIFTFeatures` | Blob | Yes | Yes | General purpose, most robust |
| `detectSURFFeatures` | Blob | Yes | Yes | Faster than SIFT, good default |
| `detectKAZEFeatures` | Blob | Yes | Yes | Non-linear scale space, sharper boundaries |
| `detectBRISKFeatures` | Corner | Yes | Yes | Fast binary descriptor |
| `detectORBFeatures` | Corner | Yes | Yes | Fastest, binary descriptor |
| `detectMSERFeatures` | Region | Yes | Yes | Uniform-intensity regions, text |
| `detectHarrisFeatures` | Corner | No | No | Simple corners, known scale |
| `detectMinEigenFeatures` | Corner | No | No | Shi-Tomasi corners |
| `detectFASTFeatures` | Corner | No | No | Real-time corner detection |

**Decision guide:**
- Default choice → `detectSIFTFeatures` (most reliable across conditions)
- Need speed → `detectSURFFeatures` or `detectORBFeatures`
- Known scale (no zoom change) → `detectHarrisFeatures` or `detectFASTFeatures`
- Text / uniform regions → `detectMSERFeatures`

### Descriptor Extraction

`extractFeatures` selects the descriptor method automatically based on the point type, or you can specify explicitly:

| Method | Binary | Descriptor Size | Best paired with |
|--------|--------|----------------|-----------------|
| `"SIFT"` | No | 128 floats | `detectSIFTFeatures` |
| `"SURF"` | No | 64 floats | `detectSURFFeatures` |
| `"KAZE"` | No | 64 floats | `detectKAZEFeatures` |
| `"FREAK"` | Yes | 64 bytes | Any point type |
| `"BRISK"` | Yes | 64 bytes | `detectBRISKFeatures` |
| `"ORB"` | Yes | 32 bytes | `detectORBFeatures` |
| `"Block"` | No | Variable | Simple patch comparison |

Binary descriptors use Hamming distance in `matchFeatures` (selected automatically).

### Transform Estimation

| Function | Use case |
|----------|----------|
| `estgeotform2d` | 2-D: similarity, affine, or projective (with RANSAC) |
| `estgeotform3d` | 3-D point correspondences |
| `estimateFundamentalMatrix` | Epipolar geometry between views |

```matlab
% Similarity (4 DOF): translation + rotation + uniform scale
tform = estgeotform2d(matchedMoving, matchedFixed, "similarity");

% Affine (6 DOF): adds shear and non-uniform scale
tform = estgeotform2d(matchedMoving, matchedFixed, "affine");

% Projective (8 DOF): full perspective (homography)
tform = estgeotform2d(matchedMoving, matchedFixed, "projective");
```

### Panorama Stitching Pattern

```matlab
% Stitch multiple images into a panorama
I1 = imread("scene1.jpg");
I2 = imread("scene2.jpg");

% Detect and match (SURF is fast enough for panoramas)
pts1 = detectSURFFeatures(im2gray(I1));
pts2 = detectSURFFeatures(im2gray(I2));
[f1, vp1] = extractFeatures(im2gray(I1), pts1);
[f2, vp2] = extractFeatures(im2gray(I2), pts2);
pairs = matchFeatures(f1, f2);

% Estimate projective transform
tform = estgeotform2d(vp2(pairs(:,2)), vp1(pairs(:,1)), "projective");

% Compute output limits by transforming image corners
[xlimOut, ylimOut] = outputLimits(tform, [1 size(I2,2)], [1 size(I2,1)]);
xMin = min(1, xlimOut(1));
xMax = max(size(I1,2), xlimOut(2));
yMin = min(1, ylimOut(1));
yMax = max(size(I1,1), ylimOut(2));

% Create output canvas and warp
outputRef = imref2d([ceil(yMax-yMin) ceil(xMax-xMin)], [xMin xMax], [yMin yMax]);
warped = imwarp(I2, tform, OutputView=outputRef);
```

### When to Use Feature-Based vs Intensity-Based

| Criterion | Feature-based | Intensity-based (`imregtform`) |
|-----------|--------------|-------------------------------|
| Large displacement / viewpoint change | Preferred | May not converge |
| Moving is subimage/crop of fixed | Preferred | Fails (metric dominated by non-overlap) |
| No texture (uniform regions) | Fails | Preferred |
| Different modalities (CT vs MRI) | Fails | Use multimodal metric |
| Speed for many image pairs | Fast | Slow (iterative) |
| Sub-pixel accuracy | Moderate | High |
| 3-D volumes | Limited | Full support |
| Panorama / mosaic | Preferred | Not suitable |

**Subimage matching:** When the moving image is a crop of the fixed image, `MeanSquares` fails because non-overlapping pixels dominate the metric. Use feature-based registration (SURF or MSER work well for this). If you must use intensity-based, switch to `MattesMutualInformation` + `OnePlusOneEvolutionary` — these are more robust to partial overlap than the default monomodal config.

## Critical: Spatial Referencing

**Always provide spatial referencing when data is anisotropic or volumes have different voxel spacings.** Without `imref2d`/`imref3d`, registration assumes unit spacing (1×1×1). This is fine for isotropic same-resolution pairs (e.g., 2-D camera images, volumes with identical spacing), but silently produces wrong results when voxels are non-cubic or images differ in resolution.

### Building `imref3d` — Dimension Order Gotcha

Get voxel spacing from relevant file metadata when available. `imref3d` expects `(imageSize, xSpacing, ySpacing, zSpacing)` where **x = columns, y = rows, z = slices** — this differs from the row-major order most metadata provides:

```matlab
% NIfTI: PixelDimensions is [rowSpacing colSpacing sliceSpacing]
info = niftiinfo(niftiFile);
ref = imref3d(info.ImageSize, ...
    info.PixelDimensions(2), ...   % x = col spacing
    info.PixelDimensions(1), ...   % y = row spacing
    info.PixelDimensions(3));      % z = slice spacing

% DICOM: PixelSpacing is [rowSpacing colSpacing], SliceThickness is scalar
info = dicominfo(dicomFile);
ref = imref3d(imageSize, ...
    info.PixelSpacing(2), ...      % x = col spacing
    info.PixelSpacing(1), ...      % y = row spacing
    info.SliceThickness);          % z = slice spacing
```

Getting the order wrong silently produces misaligned registrations.

## Intensity-Based Registration (IPT)

### Configuration

```matlab
% Same modality (MRI-to-MRI, CT-to-CT)
[optimizer, metric] = imregconfig("monomodal");
% optimizer: RegularStepGradientDescent, metric: MeanSquares

% Different modalities (CT-to-MRI, PET-to-CT)
[optimizer, metric] = imregconfig("multimodal");
% optimizer: OnePlusOneEvolutionary, metric: MattesMutualInformation
```

### Transform Type Selection

| Transform | DOF (2-D / 3-D) | Use when |
|-----------|------------------|----------|
| `"translation"` | 2 / 3 | Only shift, no rotation |
| `"rigid"` | 3 / 6 | Same-patient, no deformation (most common) |
| `"similarity"` | 4 / 7 | Need uniform scale change |
| `"affine"` | 6 / 12 | Need shear and non-uniform scale |

**Grayscale requirement:** `imregtform` and `imregister` accept only single-channel (grayscale) images. For RGB input, convert first with `im2gray(img)`. For multi-channel volumes, extract the channel of interest before registering.

### Full Workflow

```matlab
% 1. Read data
fixedData = niftiread(fixedFile);
fixedInfo = niftiinfo(fixedFile);
movingData = niftiread(movingFile);
movingInfo = niftiinfo(movingFile);

% 2. Build spatial referencing
fixedRef = imref3d(size(fixedData), ...
    fixedInfo.PixelDimensions(2), ...  % x = col spacing
    fixedInfo.PixelDimensions(1), ...  % y = row spacing
    fixedInfo.PixelDimensions(3));     % z = slice spacing

movingRef = imref3d(size(movingData), ...
    movingInfo.PixelDimensions(2), ...
    movingInfo.PixelDimensions(1), ...
    movingInfo.PixelDimensions(3));

% 3. Configure optimizer
[optimizer, metric] = imregconfig("monomodal");

% 4. Compute transform
tform = imregtform(movingData, movingRef, fixedData, fixedRef, "rigid", optimizer, metric);

% 5. Apply transform
registered = imwarp(movingData, movingRef, tform, OutputView=fixedRef);
```

**Gotcha:** `imregister` returns the resampled image directly but does NOT give you the transform. Use `imregtform` + `imwarp` when you need the transform (e.g., to apply to other volumes or to chain transforms).

### Optimizer Tuning

Multimodal registration often needs tuning:

```matlab
[optimizer, metric] = imregconfig("multimodal");
optimizer.InitialRadius = 0.001;     % Decrease for more precise search
optimizer.MaximumIterations = 200;   % Increase for convergence
```

**`RegularStepGradientDescent`** (monomodal):

| Parameter | Default | Effect | Adjust when |
|-----------|---------|--------|-------------|
| `MaximumIterations` | 100 | More iterations for convergence | Increase to 200–300 for large deformations |
| `MaximumStepLength` | 0.0625 | Step size per iteration | Decrease for fine alignment |
| `MinimumStepLength` | 1e-5 | Convergence threshold | Default usually fine |

**`OnePlusOneEvolutionary`** (multimodal):

| Parameter | Default | Effect | Adjust when |
|-----------|---------|--------|-------------|
| `MaximumIterations` | 100 | More iterations for convergence | Increase to 200–300 for large deformations |
| `InitialRadius` | 0.00625 | Initial search radius | Decrease to 0.001 for finer search |
| `GrowthFactor` | 1.05 | Search radius growth rate | Default usually fine |

### `imregtform` Name-Value Arguments

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `PyramidLevels` | `3` | Number of multi-resolution levels — increase for large misalignments |
| `InitialTransformation` | identity | Seed transform for refinement (hierarchical registration) |
| `DisplayOptimization` | `false` | Print iteration info — useful for debugging convergence |

### Hierarchical Registration (Coarse-to-Fine)

When `imregtform` fails to converge, use a simpler transform as a starting point for a more complex one:

```matlab
[optimizer, metric] = imregconfig("multimodal");
optimizer.InitialRadius = 0.001;
optimizer.MaximumIterations = 300;

% Step 1: Estimate similarity (4 DOF — more likely to converge)
tformSimilarity = imregtform(moving, movingRef, fixed, fixedRef, ...
    "similarity", optimizer, metric);

% Step 2: Refine with affine using similarity result as seed
tformAffine = imregtform(moving, movingRef, fixed, fixedRef, ...
    "affine", optimizer, metric, ...
    InitialTransformation=tformSimilarity);

registered = imwarp(moving, movingRef, tformAffine, OutputView=fixedRef);
```

This pattern resolves most convergence failures — the simpler model captures gross alignment, then the complex model refines local distortions.

## Correlation-Based — `imregcorr`

Fastest method for 2-D translation/rotation estimation. No optimizer tuning needed:

```matlab
tform = imregcorr(moving, fixed, "rigid");
registered = imwarp(moving, tform, OutputView=imref2d(size(fixed)));
```

**R2024b: gradient correlation is the default** — more accurate, more robust to noise, and more consistent than phase correlation. Do NOT specify `Method="phasecorr"` unless reproducing legacy results. Always use the default `"gradcorr"`.

**Limitations:** 2-D only. No affine. Unreliable on images with repetitive patterns (correlation peak is ambiguous). Best as a fast initial estimate for refinement with `imregtform`.

## Control-Point Registration

Use when you have known corresponding landmarks — manually selected points, fiducial markers, or matched keypoints without RANSAC.

### Interactive Selection with `cpselect`

```matlab
% Launch interactive tool for manual point selection
cpselect(moving, fixed);
% After selecting points and exporting, variables movingPoints and fixedPoints
% are created in the workspace (File > Export Points to Workspace)
```

### Compute Transform from Point Pairs

```matlab
% fitgeotform2d — modern API (R2022b+)
tform = fitgeotform2d(movingPoints, fixedPoints, "affine");
registered = imwarp(moving, tform, OutputView=imref2d(size(fixed)));

% Transform types: "similarity", "affine", "projective"
% Minimum points: similarity=2, affine=3, projective=4
```

**`fitgeotform2d` vs `estgeotform2d`:** `fitgeotform2d` fits all points (least-squares, no outlier rejection). `estgeotform2d` uses RANSAC to reject outliers — use it when matches may contain incorrect pairs (e.g., from `matchFeatures`). Use `fitgeotform2d` when all correspondences are known-good (manual selection, fiducials).

### Non-Rigid: Local Weighted Mean

For local deformations that a single global transform cannot capture:

```matlab
tform = fitgeotform2d(movingPoints, fixedPoints, "lwm", 12);
% 12 = number of points per local neighborhood
registered = imwarp(moving, tform, OutputView=imref2d(size(fixed)));
```

## Deformable Registration — `imregdemons` (IPT)

For non-rigid deformations (breathing motion, tissue deformation):

```matlab
% Convert to double and match histogram for better convergence
fixedD = double(fixedData);
movingD = double(movingData);

% Multi-resolution pyramid: [coarsest ... finest] iterations
[D, registered] = imregdemons(movingD, fixedD, [500 400 200], ...
    AccumulatedFieldSmoothing=1.3);
% D is M×N×P×ndim displacement field (2 for 2-D, 3 for 3-D)
```

| Parameter | Effect | Typical value |
|-----------|--------|---------------|
| Iteration vector `[500 400 200]` | Multi-resolution levels, coarse to fine | 3 levels, more iterations at coarse |
| `AccumulatedFieldSmoothing` | Regularization (higher = smoother) | 1.0–2.0 (default 1.0) |

**Gotcha — iteration vector length:** The length of the iteration vector must equal the number of pyramid levels (default 3). Using `[500 400]` (2 elements) with default 3 levels will error.

## Medical Imaging Toolbox Functions

### `imregmoment` — Fast Moment-Based Similarity Alignment

Computes a similarity transform (rotation + uniform scale + translation) using image moments. 20–30× faster than iterative `imregtform`.

**When to use:** First-pass alignment, fast similarity registration, or when `imregtform` is too slow.

```matlab
% Preferred: with spatial referencing (handles different voxel spacings correctly)
fixedRef = imref3d(size(fixedData), fixedSpacing(2), fixedSpacing(1), fixedSpacing(3));
movingRef = imref3d(size(movingData), movingSpacing(2), movingSpacing(1), movingSpacing(3));
[tform, registered] = imregmoment(movingData, movingRef, fixedData, fixedRef);

% Without spatial referencing (only when volumes share identical voxel spacing)
[tform, registered] = imregmoment(movingData, fixedData);
```

**Output:** `affinetform3d` (3-D) or `affinetform2d` (2-D) + registered result.

**Name-value pairs:**
- `MedianThresholdBitmap` (logical, default `false`) — set to `true` for multimodal registration or when images have different intensity levels (different sensors). Uses median-based thresholding for moment computation.

**Limitations:** Works best for roughly aligned volumes. For large misalignments, use as initialization then refine with `imregtform`. Always pass spatial referencing when volumes have different voxel spacings — without it, `imregmoment` assumes uniform unit spacing.

### `imregdeform` — Total Variation Deformable

```matlab
% Basic usage (defaults)
[D, registered] = imregdeform(movingData, fixedData);

% With tuning parameters
[D, registered] = imregdeform(movingData, fixedData, ...
    GridSpacing=[4 4 4], ...
    PixelResolution=voxelSpacing, ...
    NumPyramidLevels=3, ...
    GridRegularization=0.11, ...
    DisplayProgress=false);
```

**Output:** Displacement field `D` (MxNxPx3 for 3-D, MxNx2 for 2-D) + registered image/volume.

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `GridSpacing` | `[4 4]` (2-D), `[4 4 4]` (3-D) | Control point spacing — smaller = more flexible |
| `PixelResolution` | `[1 1]` or `[1 1 1]` | Physical voxel spacing in mm — **order is [row col slice]**, not [x y z] |
| `NumPyramidLevels` | `3` | Multi-resolution levels — more = better large-motion handling |
| `GridRegularization` | `0.11` | Smoothness constraint — higher = smoother deformation |
| `DisplayProgress` | `true` | Show iteration progress |

**vs `imregdemons`:** Uses total variation regularization (better edge preservation), while `imregdemons` uses Gaussian smoothing. Prefer `imregdeform` when available.

### `imreggroupwise` — Groupwise Slice Registration

Registers all slices in a series simultaneously to reduce inter-slice motion. Single function call replaces manual iterative loops.

**When to use:** Correcting breathing motion between slices, inter-slice misalignment in a volume acquired slice-by-slice.

```matlab
% Basic usage (defaults)
[D, registered] = imreggroupwise(sliceStack);

% With tuning parameters
[D, registered] = imreggroupwise(sliceStack, ...
    GridSpacing=[4 4], ...
    PixelResolution=[rowRes colRes], ...
    NumPyramidLevels=3, ...
    DisplayProgress=false);
```

**Output:** 4-D displacement field + registered 3-D slice series.

**Why not per-slice `imregdemons`:** Groupwise registration finds a consensus alignment across all slices simultaneously, avoiding bias toward any single reference. Manual per-slice loops produce inferior results and destroy anatomy.

**Performance:** 512×512×20 stack completes in under 60 seconds; 512×512×167 may take 20+ minutes. For large stacks, reduce `NumPyramidLevels` to 2 or increase `GridSpacing` to `[8 8]`.

### Surface-Based Registration — `extractIsosurface` + `imregicp`

```matlab
% 1. Extract isosurfaces from volumes
[~, fixedVerts] = extractIsosurface(fixedData, isovalue);
[~, movingVerts] = extractIsosurface(movingData, isovalue);

% 2. Scale vertices to physical coordinates
fixedVerts = fixedVerts .* voxelSpacing;
movingVerts = movingVerts .* voxelSpacing;

% 3. Align using ICP
[regSurface, tform, rmse] = imregicp(movingVerts, fixedVerts, ...
    Metric="pointToPlane", DistanceThreshold=50, MaxIterations=50);
```

**`DistanceThreshold` scaling — critical:** The default (0.1) assumes small-scale coordinates. For medical volumes in mm (typically spanning 100–500 mm), set `DistanceThreshold` to 10–50 to ensure enough inlier correspondences. Too small a threshold produces near-zero fitness and an identity transform.

**Do NOT confuse with `pcregistericp`** from Computer Vision Toolbox — use `imregicp` for medical image surface registration.

## Complete Example: Rigid + Deformable Pipeline

```matlab
% Read volumes
fixedVol = medicalVolume("/path/to/fixed/dicom");
movingVol = medicalVolume("/path/to/moving/dicom");

% Build spatial referencing
fixedRef = imref3d(size(fixedVol.Voxels), ...
    fixedVol.VoxelSpacing(2), fixedVol.VoxelSpacing(1), fixedVol.VoxelSpacing(3));
movingRef = imref3d(size(movingVol.Voxels), ...
    movingVol.VoxelSpacing(2), movingVol.VoxelSpacing(1), movingVol.VoxelSpacing(3));

% Fast rigid alignment first
[tformRigid, rigidResult] = imregmoment( ...
    double(movingVol.Voxels), movingRef, ...
    double(fixedVol.Voxels), fixedRef);

% Deformable refinement if needed
[D, deformResult] = imregdeform(double(rigidResult), double(fixedVol.Voxels), ...
    PixelResolution=fixedVol.VoxelSpacing, ...
    DisplayProgress=false);

% Evaluate
midSlice = round(size(fixedVol.Voxels, 3) / 2);
imshowpair(fixedVol.Voxels(:,:,midSlice), deformResult(:,:,midSlice), "falsecolor");
title("Registration Result");
```

## Evaluating Registration Quality

### Programmatic Composite — `imfuse`

`imfuse` creates a composite image for saving or further processing (unlike `imshowpair` which only displays):

```matlab
C = imfuse(fixed, registered, "falsecolor");     % Default: overlay in different color bands
C = imfuse(fixed, registered, "blend");           % Alpha blending
C = imfuse(fixed, registered, "diff");            % Difference image
C = imfuse(fixed, registered, "checkerboard");    % Alternating rectangular regions

% With spatial referencing (for images of different sizes/resolutions)
[C, RC] = imfuse(fixed, fixedRef, moving, movingRef, "falsecolor");
```

Methods: `"falsecolor"` (default), `"blend"`, `"checkerboard"`, `"diff"`, `"montage"`.

### Visual and Quantitative Checks

```matlab
% Visual: falsecolor overlay
midSlice = round(size(fixedData, 3) / 2);
imshowpair(fixedData(:,:,midSlice), registered(:,:,midSlice), "falsecolor");

% Quantitative: SSIM (structural similarity)
% IMPORTANT: use im2double (not double) — see quality-assessment.md for details
ssimBefore = ssim(im2double(movingData(:,:,midSlice)), im2double(fixedData(:,:,midSlice)));
ssimAfter = ssim(im2double(registered(:,:,midSlice)), im2double(fixedData(:,:,midSlice)));
fprintf("SSIM: %.4f (before) -> %.4f (after)\n", ssimBefore, ssimAfter);
```

### Interpreting the Recovered Transform

Use the transform object's properties — do not read `.A` columns directly:

```matlab
angle = tform.RotationAngle;       % Degrees (2-D rigid/similarity)
t     = tform.Translation;         % [tx ty] translation in world units
```

> **Origin vs. centre:** `.Translation` is the translation about the **origin** `(0,0)`, not the image centre. For a rotation about a point `c`, the effective translation at `c` is `t_c = t + R*c - c`. If you need the displacement at the image centre, compute it explicitly.

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Hallucinating `registerVolumes` | Does not exist | Use `imregtform`/`imregister` (IPT) or `imregmoment` (MIT) |
| Registering anisotropic data without spatial referencing | Assumes unit spacing, wrong when voxels are non-cubic or resolutions differ | Build `imref3d`/`imref2d` from voxel dimensions |
| `imref3d(size, rowSpacing, colSpacing, sliceSpacing)` | Constructor takes `(size, xSpacing, ySpacing, zSpacing)` — x=cols, y=rows | Swap: `imref3d(sz, colSpacing, rowSpacing, sliceSpacing)` |
| Using `"monomodal"` for CT-to-MRI | Mean squares metric fails across modalities | Use `"multimodal"` (mutual information) |
| `imregister` when transform is needed | Returns only the resampled image, not the transform | Use `imregtform` + `imwarp` |
| Per-slice `imregdemons` loop for motion correction | Over-registers, destroys anatomy | Use `imreggroupwise` (MIT) |
| Using `pcregistericp` for medical surfaces | Wrong toolbox, different interface | Use `extractIsosurface` + `imregicp` from MIT |
| No `OutputView` in `imwarp` | Output may be cropped or wrong size | Always: `imwarp(..., OutputView=fixedRef)` |
| Default `DistanceThreshold` for ICP on medical data | 0.1 is too small for mm-scale coordinates | Set to 10–50 for medical volumes |
| Rigid-then-deformable for small deformations | Unnecessary, wastes time | Use `imregdemons` or `imregdeform` directly |
| Using `estimateGeometricTransform2D` | Not recommended (deprecated) | Use `estgeotform2d` |
| Feature-based on textureless/multimodal images | No features to match | Use intensity-based `imregtform` instead |

----

Copyright 2026 The MathWorks, Inc.

----
