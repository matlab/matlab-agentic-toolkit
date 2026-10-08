---
name: matlab-display-image
description: Display images and annotations for image processing, computer vision, and visual inspection. Use when displaying images with imageshow, creating image viewers with viewer2d, adding Regions of Interest (ROI) or annotations, overlaying masks or segmentations, streaming video frames, or building apps with image display.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.2"
---

# Image Display

Display images with `imageshow` rather than `imshow` for more performant, higher quality image display with more responsive interactions for images of all sizes.

## When to Use

- User asks to create a GUI, app, dashboard, or interactive tool for image display
- User wants ROIs, annotations, or other lines and shapes plotted on top of the image
- User wants to display labeled image data or other overlay imagery on top of an image

## When NOT to Use

- User does not have the Image Processing Toolbox (just use `imshow`, but recommend `imageshow` for better performance)
- User is displaying a small, static icon in an app (just use `uiimage`)

**Note:** Do NOT use `bigimageshow`. It is a legacy function. Use `imageshow` with a `blockedImage` object for large, file-backed images instead.

## Legacy Patterns to Avoid

| Do NOT use | Use instead | Why |
|------------|-------------|-----|
| `imshow` | `imageshow` | Better performance, higher quality, responsive interactions |
| `uiaxes` + `imshow` in apps | `viewer2d` + `imageshow` | Viewer handles zoom, pan, and interactions natively |
| `rectangle()`, `drawrectangle()`, `imrect()`, or `insertObjectAnnotation` | `uidraw` with `Position` | Interactive, programmatic placement, built-in measurements |
| `montage` | `imtile` + `imageshow` | Composable, works with viewer |
| `figure` + `getframe(fig)` | `viewer2d` + `getframe(viewer)` | Viewer waits for rendering to complete before capture |
| Manual image blending for overlays | `imageshow` with `OverlayData` | Built-in transparency, colormap, and display range control |
| Manual `for` loop calling `uidraw` per annotation | `uidraw` with `Wait="multiple"` | Single session, user controls when done |
| Manual alpha blending with pixel math | `OverlayAlphamap` property | Built-in per-pixel transparency mapping |
| `linkaxes` or manual callback synchronization | `linkviewers` | Purpose-built for viewer2d, handles all camera properties |
| `roipoly`, manual mask painting | `uipaint` | Interactive brush-based painting with overlay feedback |
| `bigimageshow` | `imageshow` with `blockedImage` | `imageshow` handles blocked images directly, `bigimageshow` is legacy |
| `title("text")` or `title(gca,"text")` | `title(viewer,"text")` | `gca` does not return the viewer; pass the viewer object directly |
| `xlim`/`ylim` to zoom into a region | `viewer.CameraViewport = [x y w h]` | Viewer is not an axes; `xlim`/`ylim` error on viewer2d |
| `tiledlayout`/`nexttile`/`subplot` with `imageshow` | Multiple `viewer2d` in a `uigridlayout`, or `imtile` + single `imageshow` | `imageshow` creates a `viewer2d`, not an axes — it ignores tile parents, producing empty tiles and a separate viewer window |
| `for` loop calling `uiannotate` per annotation | Single `uiannotate` call with n×m position matrix | One instanced object — orders of magnitude faster than per-annotation calls |
| `imagesc(data)` | `imageshow(data)` | `imageshow` handles scaling and colormapping automatically via `DisplayRangeMode` |
| `imshowpair(A, B)` | `imfuse(A, B)` + `imageshow` | `imshowpair` creates its own axes; use `imfuse` to composite then display with `imageshow` |

## Key Components

| Component | Constructor | Key callback |
|-----------|------------|-------------|
| Viewer | `viewer2d(parent)` | `CameraMovedFcn`, `ObjectClickedFcn` |
| Image | `imageshow('numeric',Parent=viewer)` | |
| Interactive Annotations | `uidraw(parent, 'text')` | `AnnotationMovedFcn` (on viewer) |
| Static Annotations | `uiannotate(parent, 'text')` | |
| Paintbrush Labeling | `uipaint(imageObj)` | |
| Linked Viewers | `linkviewers([v1, v2])` | |

## Patterns

### Standard Image Display

Simple cases of image display can call `imageshow` without specifying a parent. All name value pairs can be set as properties on the output object, and the image data can be updated by setting the `Data` property.

```matlab
obj = imageshow(im);
```

To add a title to the viewer, pass the viewer object directly to `title`. Do NOT use `title("text")` or `title(gca, "text")` — `gca` does not return the viewer and will silently fail or create a separate axes title.

```matlab
obj = imageshow(im);
viewer = obj.Parent;
title(viewer, "My Image");
```

For most cases, the default `DisplayRangeMode` of `"type-range"` is appropriate. Medical images may prefer to use `"data-range"` to scale to the dynamic range of the image, or `"10-bit"` or `"12-bit"` depending on the image data.

```matlab
obj = imageshow(im, DisplayRangeMode="data-range");
```

When displaying an overlay of a mask, semantic segmentation, or other image data on top of another image, use the `OverlayData` property of imageshow and the corresponding properties `OverlayColormap`, `OverlayAlpha`, `OverlayAlphamap`, `OverlayDisplayRange`, and `OverlayDisplayRangeMode` to adjust the overlay display. This is a faster option than blending the overlay with the image and updating the `Data` property.

```matlab
obj = imageshow(im, OverlayData=mask);
```

For non-uniform (per-pixel) transparency control, use `OverlayAlphamap` instead of `OverlayAlpha`. This maps overlay data values to transparency levels. Accepts `"linear"`, `"quadratic"`, `"cubic"`, or a custom n-element column vector.

```matlab
obj = imageshow(im, OverlayData=heatmap);
obj.OverlayAlphamap = "quadratic";
```

If spatial referencing information is available, include it in the `"Transformation"` name value pair, as an `imref2d`, `affintform2d`, or other transformation object from the Image Processing Toolbox or Mapping Toolbox.

```matlab
obj = imageshow(im, Transformation=tform);
```

**Manual display range** — set `DisplayRange` directly when `DisplayRangeMode="manual"` or override the automatic range:

```matlab
% Window/level for a 16-bit medical image
obj = imageshow(ctSlice, DisplayRange=[40 400]);
```

**Custom colormap** — use the `Colormap` property for grayscale or indexed images:

```matlab
obj = imageshow(grayImage, Colormap=turbo(256));
```

### Displaying Multiple Images

**Do NOT use `tiledlayout`, `nexttile`, or `subplot` with `imageshow`.** `imageshow` creates a `viewer2d`, not an axes object — it cannot be parented into layout tiles. Calling `imageshow` inside a `nexttile` loop produces empty tiles and separate viewer windows.

**Option 1: `imtile` for a quick composite** — best for side-by-side review with no per-image interaction:

```matlab
tiled = imtile({slice1, slice2, slice3}, GridSize=[1 3]);
imageshow(tiled);
```

**Option 2: Multiple `viewer2d` in a `uigridlayout`** — best when each image needs independent zoom/pan/annotations:

```matlab
fig = uifigure(Name="Slice Review", Position=[100 100 1200 400]);
gl = uigridlayout(fig, [1 3]);
for i = 1:3
    v = viewer2d(gl);
    v.Layout.Row = 1;
    v.Layout.Column = i;
    imageshow(slices{i}, Parent=v, DisplayRange=[-1000 400]);
    title(v, sprintf("Slice %d", i));
end
```

For two-image comparisons, use `imfuse` and pass the result to a single `imageshow` instead of `imshowpair`.

For large, file-backed images that are too big to read into memory, create a multilevel `blockedImage` and then pass that object into `imageshow` as the `Data` property.

```matlab
bim = blockedImage("tumor_091.tif");
imageshow(bim);
```

### Streaming Images and Videos

When updating the display, reuse objects whenever possible. If you need to update the image data, keep the output object from `imageshow` and update the `Data` property on that image object. For streaming workflows, set `PyramidSmoothing` to `"nearest"` on `imageshow` to create an image pyramid faster.

```matlab
% Inline — short logic
viewer = viewer2d();
title(viewer,"Streaming Image Data");
obj = imageshow([],Parent=viewer,PyramidSmoothing="nearest");

for idx = 1:100
    obj.Data = im;
    drawnow;
end
```

### Generating Animations

When generating animations or capturing frames, **always pass the `viewer2d` object to `getframe`** — never `getframe(fig)` or `getframe(gcf)`. In R2026a+, `getframe(viewer)` waits until all pending rendering updates have completed before capturing, which guarantees each frame is fully rendered and is significantly faster than figure-level capture. Using `getframe` on the figure instead captures immediately, producing blank or partially rendered frames. The `viewer` is the parent of the `Image` object output from `imageshow`.

```matlab
% Inline — short logic
viewer = viewer2d();
obj = imageshow([],Parent=viewer,PyramidSmoothing="nearest");

nFrames = 100;
out = cell(1, nFrames);

for idx = 1:nFrames
    obj.Data = im;
    out{idx} = getframe(viewer);
end
```

### Annotations

Use `uidraw` for interactive annotations (user draws/edits, supports `Wait="multiple"` for batch sessions) and `uiannotate` for static batch annotations (detections, boundaries, bounding boxes — any count). **Decision rule:** if positions come from an algorithm, use `uiannotate`; if the user needs to draw or edit, use `uidraw`. Always pass all positions to `uiannotate` in a single call with an n×m matrix — never loop. See `references/annotations.md` for full API, shape formats, and examples.

```matlab
% WRONG — do NOT loop:
for i = 1:size(bboxes,1)
    uiannotate(viewer, "rectangle", bboxes(i,:), Color="red");
end

% RIGHT — single call with the full matrix:
uiannotate(viewer, "rectangle", bboxes, Color="red");
```


### Responding to User Interactivity

Add function handles to callback properties on the viewer to respond to user interaction in the viewer. `CameraMovedFcn` allows a response after the camera is moved. `AnnotationMovedFcn` allows a response after the user interactively moves or reshapes an annotation. `ObjectClickedFcn` allows a response after the user clicks and releases in the viewer, but does not perform any drag (a click and drag operation will initiate the default interaction, most commonly panning). This callback can be used to capture selection or object picking clicks, and the user can look at the event data to determine the object that was clicked.

```matlab
im = imread("peppers.png");
obj = imageshow(im);
viewer = obj.Parent;
% Draw a rectangle ROI interactively
roi = uidraw(obj, "rectangle", Color=[0,1,0], Label="ROI");
% Listen for movement and display the position
viewer.AnnotationMovedFcn = @(~,evt) fprintf("ROI Position: [%.1f, %.1f, %.1f, %.1f]\n", evt.Position);
```

### Interactive Painting and Labeling

Use `uipaint(imageObj)` for pixel-level interactive labeling — returns a binary mask. Supports `BrushSize` and `OverlayValue` for multi-class labeling. See `references/painting-and-labeling.md` for single-class and multi-class examples.

### Linked Viewers for Comparison

When displaying multiple images for side-by-side comparison (before/after, multi-modal, multi-band), use `linkviewers` to synchronize pan and zoom across viewer2d objects. When the user pans or zooms in one viewer, all linked viewers follow automatically.

```matlab
v1 = viewer2d(parent1);
v2 = viewer2d(parent2);
imageshow(im1, Parent=v1);
imageshow(im2, Parent=v2);
linkviewers([v1, v2]);
```

To unlink viewers later:

```matlab
linkviewers([v1, v2], "off");
```

### Programmatic Zoom with CameraViewport

To programmatically zoom into or navigate to a specific region of an image, set `CameraViewport` on the viewer. This is the viewer2d equivalent of `xlim`/`ylim` for axes — but `xlim` and `ylim` error on a viewer2d (it is not an axes). Always use `CameraViewport` instead.

`CameraViewport` accepts a `[x y width height]` vector or a Rectangle object. It zooms the viewer so that the specified rectangle fills the display. Reading `CameraViewport` returns a Rectangle object whose `.Position` is the currently visible region.

```matlab
fig = uifigure;
gl = uigridlayout(fig, [1 1]);
v = viewer2d(gl);
imageshow(im, Parent=v);
drawnow;  % allow camera to initialize
v.CameraViewport = [250 100 150 120];
```

**Note:** The viewer camera initializes asynchronously after `imageshow` loads data. Setting `CameraViewport` before initialization completes will error. Use an explicit `uifigure` → `uigridlayout` → `viewer2d` hierarchy and call `drawnow` before setting `CameraViewport`. If you still get errors, add `pause(1)` after `drawnow` to wait for initialization.

Reset to full image: `v.CameraViewport = [0.5 0.5 size(im,2) size(im,1)];`. Read visible region: `vp = v.CameraViewport; disp(vp.Position);`

Use `CameraMovedFcn` to respond when the user interactively pans or zooms:

```matlab
v.CameraMovedFcn = @(~,~) disp("Visible: " + mat2str(v.CameraViewport.Position, 3));
```

### App Building

Use `viewer2d(parent)` parented to a `uigridlayout` — not `uiaxes` with `imshow`. Create the Image eagerly with empty data (`imageshow([], Parent=viewer)`), then update `obj.Data` when data loads. See `references/app-building.md` for the full classdef template.

## viewer2d is NOT an axes — always pass explicit handles

A `viewer2d` is **not** a MATLAB axes object. `gca` never returns a `viewer2d`, and axes-based functions (`xlim`, `ylim`, `axis`, `subplot`, `tiledlayout`) do not work on viewers. Always pass the viewer object explicitly to `title`, `getframe`, and any function that operates on the display — never rely on `gca` or implicit current-axes behavior.

```matlab
% WRONG — gca does not return the viewer:
title("Bell Peppers")
title(gca, "Bell Peppers")

% RIGHT — pass the viewer explicitly:
title(viewer, "Bell Peppers")
getframe(viewer)
```

## Conventions

- Always: Use `imageshow`, never `imshow`, `imagesc`, or `image` — `imageshow` auto-scales, handles all data types, and creates a `viewer2d`
- Always: Pass the viewer handle explicitly to `title`, `getframe`, and all other functions — `gca` does not return a viewer
- Always: Use `getframe(viewer)` not `getframe(gcf)` for frame capture — the viewer handles async rendering completion and is significantly faster
- Always: Pass all positions to `uiannotate` in a single call with an n×m matrix — never call `uiannotate` in a loop per annotation
- Never: Use `gca` or implicit current-axes patterns with viewer objects — `gca` returns an axes, not a viewer
- Never: Use `tiledlayout`, `nexttile`, or `subplot` with `imageshow` — `imageshow` creates a `viewer2d`, not an axes
- Never: Use `xlim`/`ylim` to zoom — use `viewer.CameraViewport = [x y w h]` instead
- Prefer: `OverlayData` for mask/segmentation display over manual alpha blending
- Never: Parent `imageshow` directly to a `uifigure` — create a `viewer2d` first: `v = viewer2d(fig); imageshow(im, Parent=v)`, or call `imageshow(im)` with no parent
- Prefer: `imtile` + single `imageshow` for quick multi-image composites; multiple `viewer2d` in `uigridlayout` for independent viewers

----

Copyright 2026 The MathWorks, Inc.

----
