# Geometric Transformations

Decision guidance and gotchas for resizing, rotating, cropping, warping, spatial referencing, and geometric transform objects.

> **Often loaded with:** `registration.md` (aligning images after computing transforms), `image-io.md` (loading source images).

## Legacy vs. Modern Transform Objects

**Always use the modern `tform` objects:**

| Legacy (avoid) | Modern (use) | DOF |
|---------------|-------------|-----|
| — | `transltform2d(tx, ty)` | 2 (translation) |
| — | `rigidtform2d(angle, [tx ty])` | 3 (rotation + translation) |
| — | `simtform2d(scale, angle, [tx ty])` | 4 (similarity) |
| `affine2d` | `affinetform2d(A)` | 6 (affine) |
| `projective2d` | `projtform2d(A)` | 8 (projective) |
| `affine3d` | `affinetform3d(A)` | 12 (3-D affine) |
| — | `rigidtform3d`, `simtform3d`, `transltform3d` | 3-D variants |

### Matrix Convention Change (R2022b)

Legacy and modern transform objects use a different convention to define the transformation matrix:

- **Legacy `affine2d`:** post-multiply — `[x y 1] = [u v 1] * T` → translation in **bottom row**, property name `.T`
- **Modern `affinetform2d`:** pre-multiply — `[x; y; 1] = A * [u; v; 1]` → translation in **right column**, property name `.A`

The two are related by transposition: `A = T'`. The modern objects, which use a pre-multiply convention, are consistent with most textbooks, Wikipedia, and online resources. When copying a matrix from a reference, use `affinetform2d(A)` directly — do NOT transpose it.

```matlab
% Legacy (translation in bottom row — AVOID):
%   T = [1 0 0; 0 1 0; tx ty 1]
%   tform = affine2d(T);     % uses tform.T

% Modern (translation in right column — USE):
%   A = [1 0 tx; 0 1 ty; 0 0 1]
%   tform = affinetform2d(A);  % uses tform.A
```

**Always use `.A`, not `.T`:** When accessing the matrix from a modern transform object, use the `.A` property. The `.T` property exists only on legacy `affine2d`/`affine3d` objects and uses the transposed convention.

### Constructing Transforms

```matlab
% Translation only
tform = transltform2d([10 20]);           % [tx ty]

% Rigid: rotation (degrees) + translation
tform = rigidtform2d(30, [10 20]);        % 30° rotation, then translate

% Similarity: scale + rotation + translation
tform = simtform2d(2, 30, [10 20]);       % 2× scale, 30° rotation, translate

% Affine from 3×3 matrix
A = [1.2 0.1 5; -0.1 1.1 10; 0 0 1];
tform = affinetform2d(A);

% From point correspondences (replaces legacy fitgeotrans)
tform = fitgeotform2d(movingPts, fixedPts, "similarity");
```

### Transform Operations

```matlab
pts_world = transformPointsForward(tform, pts);   % Apply transform
pts_orig = transformPointsInverse(tform, pts);    % Undo transform
tform_inv = invert(tform);                        % Get inverse transform
```

### Custom Non-Linear Transforms — `geometricTransform2d`

For arbitrary warps (barrel distortion, fisheye correction, custom mappings) that aren't affine or projective:

```matlab
% Define inverse mapping: given output coords, return where to sample in input
inverseFcn = @(xy) [xy(:,1) + 10*sin(xy(:,2)/20), xy(:,2)];  % sinusoidal warp
tform = geometricTransform2d(inverseFcn);

warped = imwarp(img, tform);
```

- `imwarp` requires at minimum the **inverse** function (output → input mapping)
- Optionally provide a forward function for `transformPointsForward`
- Function handle must be vectorized: takes N×2 `[x y]` matrix, returns N×2 `[xOut yOut]`

## `imtranslate` — Simple Image Shift

For translating an image by a pixel offset, use `imtranslate` — do NOT build a full transform object:

```matlab
shifted = imtranslate(img, [tx ty]);           % Shift by [tx ty] pixels (x=col, y=row)
shifted = imtranslate(img, [tx ty], "nearest"); % Specify interpolation
shifted = imtranslate(img, [tx ty], "OutputView", "same");  % Keep same size (default)
shifted = imtranslate(img, [tx ty], "OutputView", "full");  % Expand to fit shifted content
```

**Gotcha:** The translation vector is `[x, y]` (columns, rows) — not `[row, col]`.

**When NOT to use:** If you also need rotation/scale/shear, build a proper transform and use `imwarp`.

## `imrotate` — Rotate an Image About a Point

Default is `"loose"` — output is larger than input. Out-of-bounds pixels are set to 0.

```matlab
rotated = imrotate(img, 45);                   % "loose": bounding box grows
rotated = imrotate(img, 45, "bilinear", "crop");  % "crop": same size, corners clipped
```

### Rotation About an Arbitrary Point (R2026b)

By default, `imrotate` rotates about the center of the image. Use `RotationCenter` to specify a different pivot:

```matlab
rotated = imrotate(img, 30, RotationCenter=[100 50]);  % Rotate about (cx=100, cy=50)
```

- Coordinates are `[cx, cy]` in intrinsic image coordinates (x = column direction, y = row direction)
- Default center of an M×N image: `[(N+1)/2, (M+1)/2]`
- `"loose"` bbox is not supported with `RotationCenter` — defaults to `"crop"`
- Out-of-bounds centers are allowed (e.g., rotating a tile around a point in a larger mosaic)

## Composing Transforms — Do Not Chain `imtranslate` → `imrotate` → `imresize`

If you need a geometric transformation that is a chain of primitives (translation, rotation, scale), **do not** chain `imtranslate`, `imrotate`, and `imresize` calls. This is wasteful — each call makes a full pass through the image and creates an intermediate full-image variable, and each interpolation pass degrades quality.

Instead, compose a single geometric transformation by multiplying the primitive `.A` matrices, then apply once with `imwarp`:

```matlab
R = rigidtform2d(theta, [0 0]);       % Rotation only
S = simtform2d(s, 0, [0 0]);          % Scale only
T = transltform2d(tx, ty);            % Translation only
tform = affinetform2d(T.A * S.A * R.A);  % Compose: rotate → scale → translate
out = imwarp(img, tform);
```

> **Note on `imresize` vs. scale in `imwarp`:** `imresize` applies an antialiasing filter by default when downsampling; `imwarp` does not. A composed scale transform through `imwarp` is not equivalent to `imresize` unless you set `imresize(..., "Antialiasing", false)`.

## `imwarp` — The General-Purpose Warper

```matlab
warped = imwarp(img, tform);
```

### Key Gotcha: Output Size Changes

By default, `imwarp` computes a bounding box that contains the entire transformed image. **The output size will differ from input size.** To keep the same size, specify the `OutputView` name-value argument:

```matlab
Rout = imref2d(size(img));  % Same spatial extent as input
warped = imwarp(img, tform, OutputView=Rout);
```

For more control, use `affineOutputView`:

```matlab
% Full transformed content (matches imwarp default when no OutputView is specified)
Rout = affineOutputView(size(img), tform, BoundsStyle="FollowOutput");
warped = imwarp(img, tform, OutputView=Rout);

% Same size as input, centered — default BoundsStyle for affineOutputView
Rout = affineOutputView(size(img), tform, BoundsStyle="CenterOutput");
warped = imwarp(img, tform, OutputView=Rout);

% Same size as input, origin-aligned
Rout = affineOutputView(size(img), tform, BoundsStyle="SameAsInput");
warped = imwarp(img, tform, OutputView=Rout);
```

### Interpolation

Default is `"linear"` (not `"cubic"`). Use `"nearest"` for label maps or binary masks to avoid creating intermediate values.

```matlab
warped = imwarp(img, tform, "nearest");  % Preserves exact values — use for masks/labels
warped = imwarp(img, tform, "linear");   % Default for numeric images
warped = imwarp(img, tform, "cubic");    % Smoother, slightly slower
```

### FillValues

Specifies what value fills out-of-bounds pixels (default: 0).

```matlab
warped = imwarp(img, tform, FillValues=128);       % Scalar — all channels
warped = imwarp(rgb, tform, FillValues=[0 255 0]); % Per-channel vector
```

### SmoothEdges

Controls whether the interpolation kernel can sample beyond the original image extent.

- **`false` (default):** Out-of-bounds samples are excluded from interpolation. Edge pixels are interpolated only from actual image content → sharp cutoff at boundary. Good for stitching and mosaics to achieve a crisp seam between images.
- **`true`:** Input is padded with `FillValues` before interpolation. Edge pixels blend between image content and the fill value → gradual 1–2 pixel transition. Good for single-image display to avoid harsh staircase at diagonal boundaries.

```matlab
warped = imwarp(img, tform, SmoothEdges=true);   % Blended edges
warped = imwarp(img, tform, SmoothEdges=false);  % Sharp edges (default)
```

## `Warper` — Fast Repeated Transforms

Use `images.geotrans.Warper` when applying the same transform to many same-sized images. It precomputes the coordinate mapping once, then only performs interpolation per image.

### From a transform object

```matlab
tform = rigidtform2d(10, [5 3]);
warper = images.geotrans.Warper(tform, size(img));

% Apply to many frames
for i = 1:numFrames
    result = warp(warper, frames{i});
end
```

### From precomputed source coordinates

For custom non-linear mappings (lens undistortion, perspective rectification, etc.) where you compute the coordinate map from any source:

```matlab
% Precompute mapping (e.g., from camera intrinsics + a plane transform)
[X, Y] = meshgrid(1:width, 1:height);
sourceX = X + displacementX;  % Where each output pixel samples from
sourceY = Y + displacementY;

warper = images.geotrans.Warper(sourceX, sourceY);

% Fast per-frame warp
rectified = warp(warper, frame);
```

### When to use

| Scenario | Use |
|----------|-----|
| Single image, one-off transform | `imwarp` |
| Same transform applied to many same-sized images | `Warper` (initialize once, warp per frame) |

## `imresize` — Resize Images

Resizes an image by a scale factor or to a target `[rows cols]` size. Applies antialiasing by default when downsampling.

### Size Argument is [rows cols], Not [width height]

```matlab
img = imread("peppers.png");    % 384×512×3
resized = imresize(img, [200 300]);  % 200 rows × 300 cols (NOT 200w × 300h)
```

### Antialiasing

`imresize` enables antialiasing by default when **downsampling**. Disabling it is faster but may produce aliasing:

```matlab
small = imresize(img, 0.25);                        % Antialiased (default)
small = imresize(img, 0.25, "Antialiasing", false); % Faster, may alias
```

### Interpolation

Default is `"bicubic"`. Use `"nearest"` for label maps or masks to avoid creating intermediate values:

```matlab
mask_resized = imresize(mask, 0.5, "nearest");  % Preserves binary/label values
```

## `imcrop` — Coordinate Convention

**`imcrop` uses `[xmin ymin width height]`** — spatial (x,y) coordinates, NOT (row, col):

```matlab
% x = column direction, y = row direction
cropped = imcrop(img, [100 50 200 150]);  % x: 100–300, y: 50–200
% Equivalent indexing: img(50:200, 100:300, :)
```

**Output size is `(height+1) × (width+1)`** because both endpoints are included.

> **`imcrop` does not accept spatial referencing objects.** `imcrop(img, R, rect)` where `R` is an `imref2d` silently returns an empty result — `R` is misinterpreted as legacy `imcrop(xref, yref, ...)` arguments. To crop in world coordinates, convert world bounds to pixel indices with `worldToSubscript` or `worldToDiscrete` and use array indexing.

### Center and Random Crops

```matlab
win = centerCropWindow2d(size(img), [200 200]);  % Centered crop window
cropped = imcrop(img, win);

win = randomCropWindow2d(size(img), [100 100]);  % Random location
cropped = imcrop(img, win);
```

## Spatial Referencing — `imref2d` / `imref3d`

Associates pixel grid with world coordinates. Critical for `imwarp` OutputView and registration:

```matlab
% Default: pixel coordinates (pixel centers at 1, 2, 3, ...)
R = imref2d(size(img));

% Custom world extent: image covers [0,10] × [0,10] world units
R = imref2d(size(img), [0 10], [0 10]);  % [XWorldLimits], [YWorldLimits]

% Uniform pixel spacing (e.g., 0.5 mm pixels)
R = imref2d(size(img), 0.5, 0.5);  % PixelExtentInWorldX, PixelExtentInWorldY
```

**Key properties:** `XWorldLimits`, `YWorldLimits`, `PixelExtentInWorldX`, `PixelExtentInWorldY`, `ImageSize`

### Coordinate Conversion

Convert between voxel/pixel subscripts and world coordinates using methods on the spatial referencing object:

```matlab
% 2-D: pixel ↔ world
R = imref2d(size(img), pixelSpacingX, pixelSpacingY);
[xWorld, yWorld] = intrinsicToWorld(R, col, row);
[col, row] = worldToIntrinsic(R, xWorld, yWorld);
[row, col] = worldToSubscript(R, xWorld, yWorld);  % Rounded to nearest pixel

% 3-D: voxel ↔ world
R3 = imref3d(size(V), xSpacing, ySpacing, zSpacing);
[xW, yW, zW] = intrinsicToWorld(R3, col, row, slice);
[col, row, slice] = worldToIntrinsic(R3, xW, yW, zW);
[row, col, slice] = worldToSubscript(R3, xW, yW, zW);

% Check if a world point is inside the volume bounds
tf = contains(R3, xW, yW, zW);
```

**Argument order gotcha:** `intrinsicToWorld` and `worldToIntrinsic` use **(x, y, z)** order (col, row, slice), but `worldToSubscript` returns **(row, col, slice)** order for direct array indexing.

## Image Pyramids

```matlab
reduced = impyramid(img, "reduce");   % Gaussian smooth + downsample by 2
expanded = impyramid(img, "expand");  % Upsample by 2 + interpolate
```

Build a multi-level pyramid:
```matlab
pyramid = cell(1, 4);
pyramid{1} = img;
for i = 2:4
    pyramid{i} = impyramid(pyramid{i-1}, "reduce");
end
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Using `affine2d` / `projective2d` | Legacy, transposed matrix convention | Use `affinetform2d` / `projtform2d` |
| `imresize(img, [width height])` | Argument is [rows cols] not [w h] | `imresize(img, [rows cols])` |
| `imwarp` without `OutputView` | Output size changes unpredictably | Set `"OutputView", imref2d(size(img))` |
| `imcrop(img, [row col h w])` | `imcrop` takes `[x y w h]` not `[row col ...]` | Remember: x=col, y=row |
| `imresize(mask, 0.5)` for labels | Bicubic creates non-integer values | Use `"nearest"` for masks/labels |
| `imrotate` expecting same size | Default is `"loose"` (larger output) | Add `"crop"` for same-size output |
| Building transform matrix in legacy format | Row/column of translation differs | Use constructor: `rigidtform2d(angle, [tx ty])` |
| `fitgeotrans` | Legacy function | Use `fitgeotform2d` |
| Building `affinetform2d` just to translate | Overcomplicated for a shift | Use `imtranslate(img, [tx ty])` |

----

Copyright 2026 The MathWorks, Inc.

----
