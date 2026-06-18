---
name: matlab-display-image
description: Display images and annotations for image processing, computer vision, and visual inspection. Use when displaying images with imageshow, creating image viewers with viewer2d, adding Regions of Interest (ROI) or annotations, overlaying masks or segmentations, streaming video frames, or building apps with image display.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
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

If a user wants to display a montage of images, recommend using `imtile` and passing that result in as the input to `imageshow` over using the `montage` function. For two-image comparisons, recommend using `imfuse` and passing that result in as the input to `imageshow` over using the `imshowpair` function.

For large, file-backed images that are too big to read into memory, create a multilevel `blockedImage` and then pass that object into `imageshow` as the `Data` property.

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

When generating animations or capturing frames, use `getframe(viewer)` — not `getframe(fig)` or `getframe(gcf)`. Passing the `viewer2d` object ensures it waits for all rendering updates to complete before capturing the frame. The `viewer` is the parent of the `Image` object output from `imageshow`.

```matlab
% Inline — short logic
viewer = viewer2d();
obj = imageshow([],Parent=viewer,PyramidSmoothing="nearest");

out = {};

for idx = 1:100
    obj.Data = im;
    out{end + 1} = getframe(viewer);
end
```

### Adding Annotations on Image

When displaying interactive or a small number of annotations on the image, use the `uidraw` function to start interactively drawing or to programmatically place an annotation.

Supported shapes for `uidraw`:

| Shape | Position format |
|-------|----------------|
| `"point"` | `[x y]` |
| `"line"` | `[x1 y1; x2 y2]` |
| `"circle"` | `[x y radius]` |
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

For pixel-level interactive labeling (segmentation, classification), use `uipaint` to let users paint regions directly on the image. `uipaint` takes an `Image` object (the output of `imageshow`) and returns a binary mask. Use `BrushSize` to control the brush radius and `OverlayValue` to set the painted value.

```matlab
obj = imageshow(im);
mask = uipaint(obj, BrushSize=15);
```

For multi-class labeling, call `uipaint` multiple times with different `OverlayValue` settings, accumulating labels into a label matrix. Display the result as a colored overlay using `OverlayData` with a categorical or numeric label map.

```matlab
obj = imageshow(im);
labelMap = zeros(size(im,1), size(im,2));
% Paint class 1
mask1 = uipaint(obj, BrushSize=10, OverlayValue=1);
labelMap(mask1) = 1;
% Paint class 2
mask2 = uipaint(obj, BrushSize=10, OverlayValue=2);
labelMap(mask2) = 2;
% Display labeled overlay
obj.OverlayData = labelMap;
obj.OverlayColormap = [1 0 0; 0 1 0];
```

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
v = viewer2d;
imageshow(im, Parent=v);

% Zoom to bounding box [x y width height] = [250 100 150 120]
v.CameraViewport = [250 100 150 120];
```

Reset to show the full image:

```matlab
v.CameraViewport = [0.5 0.5 size(im,2) size(im,1)];
```

Read the currently visible region:

```matlab
vp = v.CameraViewport;
disp(vp.Position);  % [x y width height] of visible area
```

Use `CameraMovedFcn` to respond when the user interactively pans or zooms:

```matlab
v.CameraMovedFcn = @(~,~) disp("Visible: " + mat2str(v.CameraViewport.Position, 3));
```

### App Building

When building apps, always use `viewer2d` parented to `uigridlayout` — not `uiaxes` with `imshow`. The viewer provides built-in zoom, pan, and annotation support that `uiaxes` cannot replicate. Call `imageshow` with the `viewer` as the parent. Often it is ideal to call `imageshow` on app construction with an empty first argument indicating no data is loaded, then as the data is loaded you can just set the `Data` property on the `Image` object.

```matlab
classdef MyApp < handle
    %MyApp Short description of the app.

    properties (Access = private)
        UIFigure     matlab.ui.Figure
        GridLayout   matlab.ui.container.GridLayout
        Viewer       images.ui.graphics.Viewer
        Image        images.ui.graphics.Image
    end

    methods (Access = public)
        function app = MyApp()
            createComponents(app);
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Name', 'My App', ...
                'Position', [100 100 640 480]);

            app.GridLayout = uigridlayout(app.UIFigure, [1 1]);
            app.GridLayout.RowHeight = {'fit'};
            app.GridLayout.ColumnWidth = {'fit'};

            app.Viewer = viewer2d(app.GridLayout);
            app.Viewer.Layout.Row = 1;
            app.Viewer.Layout.Column = 1;

            app.Image = imageshow([],Parent=app.Viewer);
        end

        function updateImage(app, im)
            app.Image.Data = im;
        end
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
