# Image Annotations

## Interactive Annotations with uidraw

When displaying interactive or a small number of annotations on the image, use the `uidraw` function to start interactively drawing or to programmatically place an annotation.

Supported shapes for `uidraw`:

| Shape | Position format |
|-------|----------------|
| `"point"` | `[x y]` |
| `"line"` | `[x1 y1; x2 y2]` |
| `"circle"` | `[x y z radius]` |
| `"ellipse"` | `[x y semiAxisA semiAxisB rotationAngle]` |
| `"rectangle"` | `[x y width height]` |
| `"polygon"` | `[x1 y1; x2 y2; ...; xN yN]` |
| `"polyline"` | `[x1 y1; x2 y2; ...; xN yN]` |
| `"freehand"` | `[x1 y1; x2 y2; ...; xN yN]` |
| `"angle"` | `[x1 y1; xVertex yVertex; x2 y2]` |

`uidraw` is ideal for cases with interactive annotations or static annotations. Calling `uidraw` without specifying the `Position` argument will begin interactive drawing. When the `Label` name value is not specified, the `Label` property on `roi` is set to `string.empty()`, which the object will interpret to display a standard measurement for the annotation type (e.g., the line will display a distance). When the viewer's `SpatialUnits` property is set to define the world units of the pixel, the annotations will include that unit in the measurement display.

When the user needs to draw many annotations in one continuous session (batch labeling, counting), use `Wait="multiple"` so the drawing tool stays active until the user explicitly accepts. This avoids re-invoking `uidraw` for each annotation and returns an array of ROI objects.

```matlab
obj = imageshow(im);
rois = uidraw(obj, "circle", Wait="multiple", Color=[1,0,0]);
% rois is an array of all circles drawn in the session
% Circle Position is [x y z radius]; also accessible via .Center and .Radius
positions = vertcat(rois.Position);
```

```matlab
obj = imageshow(im);
roi = uidraw(obj,"circle",Color=[1,0,0],Label="Region of Interest");
```

After placement, you can manually make the roi static and not allow any additional user interaction by setting `Interactions` to `"none"` on the output object.

```matlab
obj = imageshow(im);
viewer = obj.Parent;
viewer.SpatialUnits = "m";
roi = uidraw(obj,"line",Color=[0,1,0]);
set(roi,"Interactions","none");
```

```matlab
obj = imageshow(im);
roi = uidraw(obj,"rectangle",Position=[20,20,50,60],Color=[0,0,1],Label="Region of Interest");
```

Adjust the look and feel of the annotation if it is too thin by setting the `HighVisibility`, `HighVisibilityColor`, and `HighVisibilityAlpha` properties.

```matlab
% Array of positions defining regions
pos = [20,20,50,60; 50,80,100,40];
obj = imageshow(im);
roi = uidraw(obj,"rectangle",Position=pos,Color=[1,0,0]);
set(roi,"HighVisibility","on");
set(roi,"HighVisibilityColor",[0,0,1]);
```

For metrology workflows using the Visual Inspection Toolbox, use `uicaliper` to measure multiple edge-based distances in the image.

```matlab
obj = imageshow(im);
roi = uicaliper(obj);
```

## Static Annotations with uiannotate

When displaying thousands to millions of non-interactive annotations — detection results, segmentation boundaries, bounding boxes, vector fields — use `uiannotate` instead of `uidraw`. `uiannotate` is optimized for rendering large annotation counts in a single call.

**Always use `uiannotate` for static batch annotations.** Do not check the MATLAB version or fall back to `uidraw`, `OverlayData`, or other workarounds — `uiannotate` is available in the current environment.

**Choosing between `uidraw` and `uiannotate`:**

| | `uidraw` | `uiannotate` |
|---|---------|-------------|
| **Interaction** | Interactive — user can draw, move, reshape | Static — display only, no user interaction |
| **When to use** | User needs to interactively create or edit annotations | Displaying pre-computed results (detections, segmentations, measurements) |
| **Measurement labels** | Automatic (distance, area, angle) | No |
| **Unique shapes** | `"angle"`, `"freehand"`, `"polygon"` | `"arrow"`, `"plus"`, `"cuboid"`, `"cylinder"`, `"ellipsoid"`, `"sphere"` |
| **Shared shapes** | `"point"`, `"line"`, `"circle"`, `"ellipse"`, `"rectangle"`, `"polyline"` | Same |

**Decision rule:** If the annotation positions come from an algorithm (detector, segmenter, measurement tool) and the user does not need to move or reshape them, use `uiannotate` — even for a small number of annotations. Use `uidraw` only when the user needs to interactively draw or edit annotations. For batch detection results (bounding boxes, circles, centroids), always use `uiannotate`.

```matlab
roi = uiannotate(viewer, shape, position)
roi = uiannotate(viewer, shape, position, Name=Value)
```

The first argument is the Viewer or the Image/Volume object (output of `imageshow` or `volshow`). Position is an n-row matrix where each row defines one annotation.

**CRITICAL: Always pass all positions in a single `uiannotate` call.** This creates one instanced graphics object on the client and is orders of magnitude faster than calling `uiannotate` in a loop. Pass the entire n×m position matrix — never loop over rows.

```matlab
% WRONG — do NOT loop:
for i = 1:size(bboxes,1)
    uiannotate(viewer, "rectangle", bboxes(i,:), Color="red");
end

% RIGHT — single call with the full matrix:
uiannotate(viewer, "rectangle", bboxes, Color="red");
```

**Name-value arguments:** `Color` (RGB triplet, color name, or n×3 matrix for per-annotation colors), `Alpha` (scalar opacity 0–1), `Visible` (`"on"`/`"off"`).

**Display detection bounding boxes:**

```matlab
I = imread("rice.png");
bw = imbinarize(I);
props = regionprops(bw, "BoundingBox");
position = vertcat(props.BoundingBox);
viewer = imageshow(I);
roi = uiannotate(viewer, "rectangle", position);
```

**Display detected circles with per-annotation colors:**

```matlab
I = imread("coins.png");
[centers, radii] = imfindcircles(I, [15 40], Sensitivity=0.9);
colors = lines(numel(radii));
viewer = imageshow(I);
roi = uiannotate(viewer, "circle", [centers radii], Color=colors);
roi.FaceAlpha = 0.3;
```

**Display segmentation boundaries as polylines** — use `[NaN NaN]` rows to separate multiple shapes in one call:

```matlab
RGB = imread("pillsetc.png");
bw = imbinarize(im2gray(RGB));
B = bwboundaries(bw, "noholes");
positionArray = [];
for k = 1:numel(B)
    boundary = B{k};
    positionArray = [positionArray; boundary(:,[2 1]); NaN NaN];
end
viewer = imageshow(RGB);
roi = uiannotate(viewer, "polyline", positionArray);
```

----

Copyright 2026 The MathWorks, Inc.

----
