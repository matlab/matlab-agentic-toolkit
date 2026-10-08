
# Blob Analysis and Region Properties

Measure geometric properties of segmented binary objects: area, perimeter,
centroid, bounding box, orientation, eccentricity, and more. Measurements can
be in pixels or in physical world units when camera calibration is available.

## When to Use

- Measuring area, perimeter, diameter of segmented objects
- Extracting shape features (circularity, eccentricity, solidity)
- Computing centroids and bounding boxes of connected components
- Reporting measurements in physical units (mm², mm)
- Filtering objects by size or shape properties

## When NOT to Use

- Need to detect or segment objects first — segment first, then use this skill
- Edge-based dimensional measurement (widths, gaps) — see `references/measure-gauging.md`
- Object detection with bounding boxes from raw images — see `references/detect-objects.md`
- Counting without measurement — see `references/count-objects.md`

## Getting Measurements in World Units

| Imaging Setup | Approach | Accuracy |
|---------------|----------|----------|
| Low distortion, top-down view, uniform pixel size | Simple scale factor: multiply by mm/pixel | Good for moderate tolerances |
| Calibrated camera, perspective or lens distortion present | Rectify with `imageToWorldPlane` first, then `regionprops` directly | High — handles non-uniform pixel-to-world mapping |

### Why Rectify First?

Manual scaling (`Area * pixelSize^2`) assumes every pixel subtends the same
world distance. This is only true for telecentric or near-top-down views with
low-distortion lenses. With perspective or barrel/pincushion distortion, pixel
size varies across the image. Rectifying to a world-coordinate image with
`imageToWorldPlane` makes every pixel homogeneous in world units, so
`regionprops` measurements are directly in world units without post-hoc
scaling.

## Patterns

### Basic regionprops (Pixel Units)

```matlab
bw = imbinarize(im2gray(img));
bw = bwareaopen(bw, 50);
props = regionprops(bw, "Area", "Perimeter", "Centroid", "BoundingBox");
```

### Simple Scale Factor (Uniform Pixel Size)

When the pixel-to-world ratio is constant across the image:

```matlab
mmPerPixel = 0.05;
props = regionprops(bw, "Area", "Perimeter", "MajorAxisLength");
areaMM2 = [props.Area] * mmPerPixel^2;
perimeterMM = [props.Perimeter] * mmPerPixel;
diameterMM = [props.MajorAxisLength] * mmPerPixel;
```

Area scales quadratically, linear measurements scale linearly.

### Calibrated World-Unit Measurement (Rectify First)

When camera calibration is available, rectify the image so each pixel is a
known world size, then run `regionprops` directly:

```matlab
D = imageToWorldPlaneMapping(intrinsics, camExtrinsics);
rectified = imwarp(img, D);
bw = imbinarize(im2gray(rectified));
bw = bwareaopen(bw, 50);
props = regionprops(bw, "Area", "Perimeter", "Centroid", "MajorAxisLength");
```

In this workflow, `props.Area` is already in world units² (e.g., mm²) and
`props.Perimeter` is in world units (mm) because the rectified image has
uniform world-unit pixels.

For a one-off measurement (not repeated):

```matlab
[rectified, Rout] = imageToWorldPlane(img, intrinsics, camExtrinsics);
```

### High-Performance Rectification for Deployment

For maximum throughput in deployment (MATLAB Compiler, production loops), use
`images.geotrans.Warper` with the displacement field from
`imageToWorldPlaneMapping`. Convert the displacement field to source
coordinates by adding destination intrinsic coordinates:

```matlab
D = imageToWorldPlaneMapping(intrinsics, camExtrinsics);
[X, Y] = meshgrid(1:size(D, 2), 1:size(D, 1));
sourceX = X + D(:,:,1);
sourceY = Y + D(:,:,2);
warper = images.geotrans.Warper(sourceX, sourceY);
rectified = warp(warper, img);
```

The `Warper` object precomputes interpolation weights once and applies them
efficiently to each subsequent frame via `warp(w, img)`.

### Filtering Objects by Properties

```matlab
props = regionprops(bw, "Area", "Circularity", "Centroid");
areas = [props.Area];
circularity = [props.Circularity];
validIdx = areas > 100 & circularity > 0.8;
validProps = props(validIdx);
```

### Labeling and Visualizing Results

```matlab
props = regionprops(bw, "Centroid", "Area");
imshow(img)
hold on
for k = 1:numel(props)
    text(props(k).Centroid(1), props(k).Centroid(2), ...
        sprintf("%.1f", props(k).Area), Color="yellow", FontSize=10)
end
hold off
```

### Common regionprops Properties

| Property | Measures | Units (after rectification) |
|----------|----------|-----------------------------|
| `Area` | Number of pixels in region | world units² |
| `Perimeter` | Boundary length | world units |
| `MajorAxisLength` | Length of major axis of fitted ellipse | world units |
| `MinorAxisLength` | Length of minor axis | world units |
| `Centroid` | Center of mass [x, y] | world units (position) |
| `BoundingBox` | Smallest enclosing rectangle | world units |
| `Circularity` | 4π·Area/Perimeter² (1 = perfect circle) | dimensionless |
| `Eccentricity` | Ratio of foci distance to major axis (0–1) | dimensionless |
| `Solidity` | Area / ConvexArea (how convex the shape is) | dimensionless |
| `Orientation` | Angle of major axis from horizontal | degrees |

## Decision Framework

| Question | Answer |
|----------|--------|
| Do I need world units? | No → `regionprops` directly in pixel units |
| Is pixel size uniform? | Yes (top-down, low distortion) → simple scale factor |
| Is there perspective or distortion? | Yes → rectify with `imageToWorldPlane` first |
| Fixed camera, many frames? | Precompute `imageToWorldPlaneMapping` |
| Maximum throughput in deployment? | `images.geotrans.Warper` with precomputed source coords |

## Conventions

- **Always:** use `bwareaopen` to remove noise before `regionprops`
- **Always:** rectify before `regionprops` when pixel-to-world mapping is non-uniform
- **Always:** precompute mapping for production (fixed camera, repeated frames)
- **Never:** manually scale area/perimeter measurements when perspective distortion is present
- **Prefer:** requesting specific properties (e.g., `"Area","Perimeter"`) over `"all"` for performance
- **Prefer:** `images.geotrans.Warper` over `imwarp` in deployed production loops for speed

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Scaling area by pixelSize instead of pixelSize² | Area scales quadratically | `area_mm2 = area_px * mmPerPixel^2` |
| Manual scaling with perspective distortion | Pixel size varies across image | Rectify with `imageToWorldPlane` first |
| Using `regionprops("all")` unnecessarily | Slow — computes properties you don't need | Request only needed properties |
| Not removing small noise regions | Spurious blobs affect measurements | `bwareaopen(bw, minArea)` before `regionprops` |
| Recomputing `imageToWorldPlane` per frame | Slow for repeated use | `imageToWorldPlaneMapping` once, `imwarp` per frame |
| Using `imwarp` in tight deployment loop | Slower than precomputed `Warper` | `images.geotrans.Warper` + `warp` |


----

Copyright 2026 The MathWorks, Inc.

----
