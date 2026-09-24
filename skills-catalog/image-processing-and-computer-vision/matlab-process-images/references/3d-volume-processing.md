# 3-D Volume Processing

Decision guidance for processing 3-D volumetric data: filtering, morphology, segmentation, measurement, geometric transforms, and the key differences from 2-D workflows.

> **Often loaded with:** `segmentation-automated.md` (3-D segmentation methods), `segmentation-interactive.md` (interactive masks and region growth), `analysis-measurement.md` (`regionprops3` measurement), `geometric-transforms.md` (2-D transform basics that carry over to 3-D), `registration.md` (3-D volume alignment and deformable registration), `image-io.md` (loading multi-page TIFFs into 3-D arrays).

## Critical: What Works Differently in 3-D

Many 2-D IPT functions extend to 3-D, but some don't. Key incompatibilities:

| Function | 3-D support | 3-D alternative |
|----------|-------------|-----------------|
| `imadjust` | No | `imadjustn` |
| `adapthisteq` (CLAHE) | No (2-D grayscale only) | Apply per-slice or use `imadjustn` |
| `imhistmatch` | 2-D only | `imhistmatchn` (N-D) |
| `edge` | No (2-D only) | `edge3` (methods: `"approxcanny"`, `"Sobel"`) or `imgradient3` |
| `imgradient` | 2-D only | `imgradient3` |
| `imgradientxy` | 2-D only | `imgradientxyz` |
| `bwareafilt` / `bwpropfilt` | No (2-D only) | `bwvolumefilt` / `bwpropfilt3` (R2026b+), or `regionprops3` + `ismember` |
| `bwlabel` | 2-D only | `bwlabeln` |
| `bwselect` | 2-D only | `bwselect3` |
| `bwboundaries` | 2-D only | No direct 3-D equivalent — use `isosurface` or `bwperim` + surface extraction |
| `bwmorph` | 2-D only | `bwmorph3` |
| `superpixels` | 2-D only | `superpixels3` |
| `imsegkmeans` | 2-D spatial only (treats 3rd dim as channels, output is M×N not M×N×P) | `imsegkmeans3` |
| `imresize` | Runs but in-plane only (no Z resize) | `imresize3` for true 3-D |
| `imrotate` | Runs but in-plane only (no Z rotation) | `imrotate3` for true 3-D |
| `imcrop` | 2-D only | `imcrop3` |
| `medfilt2` | No — errors on 3-D | `medfilt3` |
| `imgaussfilt` | Runs on 3-D but per-slice (no Z smoothing) | `imgaussfilt3` for true 3-D |
| `imboxfilt` | Runs on 3-D but per-slice (no Z smoothing) | `imboxfilt3` for true 3-D |
| `integralImage` / `integralBoxFilter` | Run on 3-D but per-slice | `integralImage3` / `integralBoxFilter3` for true 3-D |
| `fspecial` | 2-D only | `fspecial3` (types: `"average"`, `"ellipsoid"`, `"gaussian"`, `"laplacian"`, `"log"`, `"prewitt"`, `"sobel"`) |
| `imsharpen` | No (2-D grayscale/RGB only) | `imfilter` with `fspecial3("laplacian")` for unsharp masking |
| `imflatfield` | No (2-D grayscale/RGB only) | Apply per-slice, or `imgaussfilt3` + division for background correction |
| `label2rgb` | No (2-D only) | `volshow(V, OverlayData=L)` for 3-D label visualization |
| `regionprops` | Accepts 3-D but limited subset (Area, Centroid, BoundingBox, PixelIdxList, PixelList, Image, SubarrayIdx, FilledImage, FilledArea, and intensity properties) — shape/moment properties are 2-D only | `regionprops3` for full 3-D property set |

Functions that **do** work on N-D arrays without change: `imbinarize`, `imerode`, `imdilate`, `imopen`, `imclose`, `imtophat`, `imbothat`, `imfill`, `imclearborder`, `bwareaopen`, `bwconncomp`, `bwdist`, `bwskel` (prefer for 3-D; for 2-D use `bwmorph` `"skel"`), `bwperim` (with 6/18/26 conn), `watershed`, `imhmin`, `imhmax`, `imregionalmax`, `imregionalmin`, `imextendedmax`, `imextendedmin`, `imreconstruct`, `imimposemin`, `imfilter`, `adaptthresh` (accepts 2-D matrix or 3-D array), `graythresh`, `imadjustn`, `imhistmatchn`, `imwarp` (with 3-D transform), `bwlabeln`.

## 3-D Structuring Elements

```matlab
se = strel("sphere", 3);       % Sphere of radius 3
se = strel("cube", 5);         % 5×5×5 cube
se = strel("cuboid", [3 3 7]); % Anisotropic cuboid
```

**Do not use `strel("disk", …)` or `strel("square", …)` for volumetric morphology** — those are 2-D SEs. `imerode`/`imdilate` will accept them on a 3-D input without erroring, but silently apply the SE per-slice (no Z coupling), giving 2-D behavior instead of true 3-D morphology.

**Anisotropic data (e.g., CT with 0.5×0.5×2.5 mm spacing):** Use `strel("cuboid", …)` scaled to approximate isotropy in physical space:

```matlab
voxelSize = [0.5 0.5 2.5];  % [row col slice] in mm
targetRadius = 2;  % mm
seSize = round(2*targetRadius ./ voxelSize);
seSize = seSize + (1 - mod(seSize, 2));  % Ensure odd
se = strel("cuboid", seSize);
```

## Connectivity in 3-D

| Connectivity | Neighbors | Meaning | Use when |
|-------------|-----------|---------|----------|
| 6 | Adjacent faces only | Strictest | Objects should connect only through faces |
| 18 | Face + edge | Moderate | Good default for most segmentation |
| 26 | Face + edge + vertex | Most permissive | Default for `bwconncomp` in 3-D |

**Gotcha:** Default connectivity for `bwconncomp`, `bwvolumefilt`, and `bwpropfilt3` on 3-D is 26 (most permissive). For segmentation tasks where you want to separate nearby objects, explicitly use 6:

```matlab
cc = bwconncomp(bw3d, 6);           % Stricter separation
bw = bwvolumefilt(bw3d, 5, 6);      % 5 largest by volume, 6-connectivity
```

## Filtering

Use `imgaussfilt3` / `imboxfilt3` to apply true 3-D filtering to volumetric data. `imgaussfilt` and `imboxfilt` accept 3-D arrays without error or warning but filter per-slice only (no Z-axis smoothing).

```matlab
% Gaussian smoothing
smoothed = imgaussfilt3(V, sigma);            % Isotropic sigma
smoothed = imgaussfilt3(V, [sx sy sz]);       % Anisotropic sigma

% Median filtering
denoised = medfilt3(V);                       % Default 3×3×3
denoised = medfilt3(V, [3 3 5]);              % Anisotropic kernel

% Box filtering (fast mean)
mean3 = imboxfilt3(V, [3 3 3]);

% Custom 3-D kernel via imfilter 
h = fspecial3("gaussian", [7 7 7], 1.5);      
filtered = imfilter(V, h, "replicate");

% Anisotropic diffusion (edge-preserving)
% imdiffusefilt accepts 3-D grayscale volumes directly
denoised = imdiffusefilt(V);

% Mode filter for label/categorical volumes (preserves discrete values)
labelSmoothed = modefilt(labelVol, [3 3 3]);
```

**Choosing a 3-D denoiser:**

| Filter | Speed | Preserves edges | Notes |
|--------|-------|----------------|-------|
| `imgaussfilt3` | Fast | No | Standard smoothing |
| `imboxfilt3` | Very fast | No | Uses 3-D integral image internally |
| `medfilt3` | Medium | Yes | Best for salt-and-pepper on volumes |
| `modefilt` | Fast | N/A (categorical) | Smooths label/categorical volumes — preserves discrete class values |
| `imdiffusefilt` (on volume) | Slow (iterative) | Yes | Best when strong noise + edge detail matters |

`imnlmfilt`, `imbilatfilt`, `imguidedfilter`, `locallapfilt`, and `localcontrast` are **2-D only**. Apply per-slice if you need them on a volume. See `filtering.md` for parameter guidance and type restrictions on these 2-D filters.

## Edge Detection — `edge3` and `imgradient3`

```matlab
% edge3 — threshold is REQUIRED (unlike 2-D edge which auto-computes)
BW = edge3(V, "approxcanny", 0.5);              % Scalar threshold
BW = edge3(V, "approxcanny", [0.2 0.5]);        % [low high] thresholds
BW = edge3(V, "approxcanny", [0.2 0.5], 1.5);   % With sigma

BW = edge3(V, "Sobel", 0.3);                    % Sobel method

% imgradient3 — gradient magnitude and direction (not binary edges)
[Gmag, Gazimuth, Gelevation] = imgradient3(V);
```

**`edge3` only supports `"approxcanny"` and `"Sobel"`** — not `"Canny"`, `"Prewitt"`, `"Roberts"`, or `"log"`.

## Contrast Adjustment

```matlab
% imadjustn — N-D equivalent of imadjust
Vadj = imadjustn(V);                          % Auto stretch to [0 1] output
Vadj = imadjustn(V, stretchlim(V(:)));        % Percentile-based limits

% N-D histogram matching (align intensities to a reference volume)
Vmatched = imhistmatchn(V, Vref);
Vmatched = imhistmatchn(V, Vref, 128);        % Custom bin count

% Per-slice CLAHE (adapthisteq is 2-D only)
Vclahe = zeros(size(V), "like", V);
for k = 1:size(V, 3)
    Vclahe(:,:,k) = adapthisteq(V(:,:,k));
end
```

**`histeq` works on 3-D** (flattens histogram across entire volume), but `imadjustn` is generally preferred for volumetric contrast — it provides percentile-based stretching without redistributing the histogram.

**When to prefer `imhistmatchn` over `imadjustn`:** matching two volumes acquired under different conditions (different scanners, sessions, or exposures) before registration or comparison.

## Thresholding

```matlab
BW = imbinarize(V);                                % Otsu on 3-D grayscale
BW = imbinarize(V, "adaptive", Sensitivity=0.5);   % Adaptive on 3-D volume

% Or via adaptthresh (equivalent — build threshold volume explicitly)
T = adaptthresh(V, 0.5);
BW = imbinarize(V, T);
```

## Morphological Cleanup (3-D)

```matlab
se = strel("sphere", 2);
bw = imbinarize(V);                  % Otsu on volume
bw = imopen(bw, se);                 % Remove small protrusions
bw = imclose(bw, se);                % Fill small gaps
bw = imfill(bw, "holes");            % Fill fully-enclosed 3-D holes
bw = imclearborder(bw);              % Remove objects touching any volume face
bw = bwareaopen(bw, minVoxelCount);  % Remove small objects by voxel count
```

**3-D-specific `bwmorph3` operations** — only these six: `"branchpoints"`, `"clean"`, `"endpoints"`, `"fill"`, `"majority"`, `"remove"`. It does **not** support `"thin"`, `"skel"`, `"spur"`, `"bridge"` — use `bwskel` for 3-D skeletonization.

## Filtering Objects by Properties — 3-D

### R2026b+: `bwvolumefilt` and `bwpropfilt3`

Starting in R2026b, use these dedicated 3-D object filtering functions — they mirror the 2-D `bwareafilt`/`bwpropfilt` functions:

```matlab
% Filter by volume (3-D equivalent of bwareafilt)
bwFiltered = bwvolumefilt(bw, [minVol maxVol]);           % Keep objects in volume range
bwFiltered = bwvolumefilt(bw, n);                          % Keep n largest objects (default)
bwFiltered = bwvolumefilt(bw, n, "smallest");              % Keep n smallest
bwFiltered = bwvolumefilt(bw, n, 6);                       % With explicit connectivity

% Filter by any regionprops3 property (3-D equivalent of bwpropfilt)
bwFiltered = bwpropfilt3(bw, "SurfaceArea", [100 Inf]);
bwFiltered = bwpropfilt3(bw, "Solidity", 3, "largest");
bwFiltered = bwpropfilt3(bw, I, "MeanIntensity", [50 200]);   % Needs grayscale I

% Both accept a connected component structure (from bwconncomp) as input:
cc = bwconncomp(bw, 6);
ccFiltered = bwpropfilt3(cc, "Volume", [1000 Inf]);
```

### Pre-R2026b: `regionprops3` + `ismember` fallback

In R2026a and earlier, `bwareafilt` and `bwpropfilt` are **2-D only**. Use `regionprops3` and `ismember` to manually filter by 3-D properties:

```matlab
cc = bwconncomp(bw, 26);
props = regionprops3(cc, "Volume", "Centroid");

keep = props.Volume > minVolume;
L = labelmatrix(cc);
bwFiltered = ismember(L, find(keep));

% Multiple properties
keep = props.Volume > 100 & props.Volume < 10000;
bwFiltered = ismember(L, find(keep));
```

**Note:** `bwareaopen(bw, minVoxels)` works on 3-D for simple size thresholding (remove objects below a minimum), but cannot filter by range or by non-volume properties.

## `regionprops3` — 3-D Measurement

```matlab
props = regionprops3(cc, "Volume", "Centroid", "PrincipalAxisLength", "SurfaceArea");
```

**Key 3-D properties:**

| Property | Description |
|----------|-------------|
| `Volume` | Voxel count (equivalent to 2-D `Area`) |
| `Centroid` | Center of mass `[x, y, z]` — x=col, y=row, z=slice. To index the volume: `V(round(c(2)), round(c(1)), round(c(3)))` |
| `SurfaceArea` | Surface area (Crofton formula, assumes unit voxel spacing) |
| `PrincipalAxisLength` | `[major, middle, minor]` axis lengths |
| `Orientation` | Euler angles `[roll, pitch, yaw]` in degrees (rotation about x-, y-, z-axes) |
| `BoundingBox` | `[x y z width height depth]` |
| `EquivDiameter` | Diameter of sphere with same volume |
| `Solidity` | Ratio of Volume to ConvexVolume |
| `ConvexVolume` | Volume of convex hull |
| `ConvexHull` / `ConvexImage` | Convex hull vertices / binary convex hull image |
| `Extent` | Ratio of Volume to BoundingBox volume |
| `EigenValues` / `EigenVectors` | Principal moments and directions |
| `VoxelIdxList` | Linear indices of all voxels in region |
| `VoxelList` | `[x y z]` subscript coordinates of all voxels |
| `SubarrayIdx` | Cell of subscript ranges for bounding box |

**Converting to physical units:** `Volume` and `SurfaceArea` are in voxels/voxel² by default. Multiply manually: `physicalVolume = props.Volume * prod(voxelSpacing)`. Note that `SurfaceArea` assumes isotropic voxels and cannot be corrected by a simple scalar for anisotropic spacing.

**Intensity measurements** (require grayscale volume):
```matlab
props = regionprops3(cc, V, "MeanIntensity", "MaxIntensity", "MinIntensity", "VoxelValues", "WeightedCentroid");
```

## 3-D Segmentation

Beyond thresholding (`imbinarize`, `adaptthresh`) and k-means (`imsegkmeans3`, `superpixels3`), these methods handle more complex 3-D segmentation tasks:

### Watershed — Separating Touching Objects

```matlab
% Distance-transform based (for separating touching convex objects)
D = bwdist(~bw);
D = -D;
D = imhmin(D, 2);      % Suppress shallow minima to reduce over-segmentation
L = watershed(D);
bwSeparated = bw & (L > 0);  % Watershed lines are L==0
```

`imhmin` accepts an N-D connectivity argument — pass 6 or 18 to influence how minima are grouped in 3-D:

```matlab
D = imhmin(D, 2, 6);   % Stricter minima connectivity in 3-D
```

### Active Contours — `activecontour`

Level-set segmentation, works on 3-D volumes:

```matlab
% Initial mask (rough estimate of region)
mask = false(size(V));
mask(r1:r2, c1:c2, s1:s2) = true;

% Chan-Vese (region-based, no edge needed) — default method
result = activecontour(V, mask, numIterations, "Chan-Vese");

% Edge-based
result = activecontour(V, mask, numIterations, "edge");
```

### Seed-Based Region Growing — `imsegfmm`

Fast marching segmentation from seed points, works on 3-D:

```matlab
W = graydiffweight(V, seedCol, seedRow, seedSlice);       % Intensity-difference weights
BW = imsegfmm(W, seedCol, seedRow, seedSlice, 0.01);     % Geodesic threshold

W = gradientweight(V);                                    % Gradient-based weights
BW = imsegfmm(W, seedCol, seedRow, seedSlice, 0.05);
```

## 3-D Geometric Transforms

### Resizing — `imresize3`

```matlab
Vs = imresize3(V, 0.5);                          % Uniform scale
Vs = imresize3(V, [200 200 100]);                % Explicit output size
Vs = imresize3(V, [200 200 100], "nearest");     % Preserve labels/masks
```

**Interpolation methods:** `"nearest"`, `"linear"`, `"cubic"` (default), `"box"`, `"triangle"`, `"lanczos2"`, `"lanczos3"`.

**Categorical / label volumes:** `imresize3` accepts categorical arrays directly — use `"nearest"` to avoid invalid intermediate labels.

### Rotation — `imrotate3`

Rotates about an arbitrary axis (unlike 2-D `imrotate` which always rotates about the image center in-plane):

```matlab
Vr = imrotate3(V, 30, [0 0 1]);                          % 30° about Z
Vr = imrotate3(V, 45, [1 1 0], "linear", "crop");        % 45° about [1 1 0], cropped to input size
Vr = imrotate3(V, 15, [1 0 0], FillValues=NaN);          % NaN fill (FillValues must be numeric)
```

**Accepts categorical arrays** (labels/masks) — use `"nearest"` interpolation. Default bounding box is `"loose"` (output grows to contain the entire rotated volume). Use `"crop"` to keep the same size as the input, clipping regions that rotate outside the original bounds.

### Cropping — `imcrop3`

```matlab
Vc = imcrop3(V, [xmin ymin zmin width height depth]);
```

### Oblique Slicing — `obliqueslice`

Extract a 2-D slice at an arbitrary angle from a volume (multiplanar reformation):

```matlab
[B, x, y, z] = obliqueslice(V, [cx cy cz], [nx ny nz]);  % Center point + normal vector
B = obliqueslice(V, center, normal, Method="nearest");     % For label volumes
```

To reslice a full volume along an arbitrary plane, call `obliqueslice` in a loop with varying center points along the desired axis.

### General warping — `imwarp` with 3-D transforms

```matlab
% 3-D affine transform (12 DOF)
A = [1 0 0 tx; 0 1 0 ty; 0 0 1 tz; 0 0 0 1];   % Translation example
tform = affinetform3d(A);

% Rigid: Euler angles + translation
tform = rigidtform3d(eulerAngles, [tx ty tz]);

% Warp with spatial referencing (critical for anisotropic voxels)
Rin  = imref3d(size(V), voxSpacing(2), voxSpacing(1), voxSpacing(3));  % x,y,z
Vw   = imwarp(V, Rin, tform, OutputView=Rin);
Vw   = imwarp(V, Rin, tform, "nearest");  % For label/mask volumes
```

**`imref3d` argument order gotcha:** the constructor is `imref3d(imageSize, xSpacing, ySpacing, zSpacing)` where **x=cols, y=rows, z=slices**. Passing row/col spacing in the natural array order swaps X and Y and silently produces geometrically wrong results.

**`OutputView` controls the output grid.** Pass `OutputView=Rin` to keep the output in the same coordinate system as the input. To resample onto a different grid (e.g., matching a reference volume), create an `imref3d` for the target size and spacing and pass it as `OutputView`.

`imwarp` accepts categorical arrays — use `"nearest"` interpolation for labels.

## Resampling to Isotropic Spacing

Many algorithms assume isotropic voxels. Resample anisotropic data first:

```matlab
voxelSize = [0.5 0.5 2.5];        % [row col slice] mm
targetSpacing = min(voxelSize);   % Resample to finest dimension
scale = voxelSize / targetSpacing;
newSize = round(size(V) .* scale);
Viso = imresize3(V, newSize, "linear");
```

For label/mask volumes, use `"nearest"` interpolation to avoid creating invalid labels:

```matlab
maskIso = imresize3(uint8(mask), newSize, "nearest") > 0;
% Or, for a categorical label volume:
labelsIso = imresize3(labelsCategorical, newSize, "nearest");
```

## Visualization

```matlab
% Volume rendering
volshow(V);

% With label overlay
volshow(V, OverlayData=labelVol);

% Orthogonal slice planes through the volume
volshow(V, RenderingStyle="SlicePlanes");

% Isosurface extraction + display (modern: viewer3d + Surface)
viewer = viewer3d;
[faces, verts] = isosurface(V, isovalue);
tri = triangulation(faces, verts);
images.ui.graphics.Surface(viewer, Data=tri);

% Slice browsing
sliceViewer(V);              % Single-direction slice browser with slider
orthosliceViewer(V);         % Three orthogonal views with linked crosshairs

% All slices as tiled gallery
montage(V);
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `bwareafilt(bw3d, [min Inf])` | 2-D only — errors on 3-D | `bwvolumefilt` (R2026b+) or `regionprops3` + `ismember` |
| `imadjust(V)` on volume | Doesn't accept 3-D | `imadjustn(V)` |
| `adapthisteq(V)` on volume | 2-D grayscale only | Per-slice loop or `imadjustn`/`imhistmatchn` |
| `edge(V, "Canny")` on volume | 2-D only, and `edge3` doesn't offer "Canny" | `edge3(V, "approxcanny", …)` or `imgradient3` |
| `imgaussfilt(V, sigma)` | Runs but filters per-slice only — no Z smoothing, no warning | `imgaussfilt3(V, sigma)` |
| `strel("disk", r)` for 3-D morphology | Creates 2-D SE — `imerode`/`imdilate` silently apply it per-slice (no Z coupling) | `strel("sphere", r)` |
| Ignoring anisotropic voxel spacing | SE is wrong physical size per axis | Use `strel("cuboid", …)` scaled by voxel size, or resample to isotropic first |
| Default 26-connectivity merging objects | Over-connects in dense volumes | Explicitly use 6-connectivity |
| `imresize3(mask, newSize)` for labels | Default `"cubic"` creates non-binary/invalid values | `imresize3(mask, newSize, "nearest")` |
| `imref3d(sz, rowSpacing, colSpacing, sliceSpacing)` | Constructor is `(sz, xSpacing, ySpacing, zSpacing)` — x=cols, y=rows | `imref3d(sz, colSpacing, rowSpacing, sliceSpacing)` |
| `fspecial3("box", …)` | No such type — use `"average"` | `fspecial3("average", hsize)` |
| Passing `Centroid` `[x y z]` straight to `V(…)` | Array indexing is `[row col slice]` = `[y x z]` | `V(round(c(2)), round(c(1)), round(c(3)))` |
| `regionprops(cc3d, "Solidity")` on 3-D | Shape/moment properties (Solidity, Eccentricity, Orientation, etc.) warn and return empty on 3-D | Use `regionprops3` for full 3-D property set |
| `edge3(V, "approxcanny")` without threshold | Threshold is required (unlike 2-D `edge` which auto-computes) | `edge3(V, "approxcanny", thresh)` |
| `imsegkmeans(V, K)` on a volume | Treats 3rd dim as channels — output is M×N, not M×N×P | `imsegkmeans3(V, K)` |

----

Copyright 2026 The MathWorks, Inc.

----
