---
name: matlab-display-image
description: Display images and annotations for image processing, computer vision, and visual inspection. Use when displaying images with imageshow, creating image viewers with viewer2d, adding Regions of Interest (ROI) or annotations, overlaying masks or segmentations, streaming video frames, or building apps with image display.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
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

## Legacy Patterns to Avoid

| Do NOT use | Use instead | Why |
|------------|-------------|-----|
| `imshow` | `imageshow` | Better performance, higher quality, responsive interactions |
| `uiaxes` + `imshow` in apps | `viewer2d` + `imageshow` | Viewer handles zoom, pan, and interactions natively |
| `rectangle()`, `drawrectangle()`, `imrect()`, or `insertObjectAnnotation` | `uidraw` with `Position` | Interactive, programmatic placement, built-in measurements |
| `montage` | `imtile` + `imageshow` | Composable, works with viewer |
| `figure` + `getframe(fig)` | `viewer2d` + `getframe(viewer)` | Viewer waits for rendering to complete before capture |
| Manual image blending for overlays | `imageshow` with `OverlayData` | Built-in transparency, colormap, and display range control |

## Key Components

| Component | Constructor | Key callback |
|-----------|------------|-------------|
| Viewer | `viewer2d(parent)` | `CameraMovedFcn`, `ObjectClickedFcn` |
| Image | `imageshow('numeric',Parent=viewer)` | |
| Interactive Annotations | `uidraw(parent, 'text')` | `AnnotationMovedFcn` (on viewer) |
| Static Annotations | `uiannotate(parent, 'text')` | |

## Patterns

### Standard Image Display

Simple cases of image display can call `imageshow` without specifying a parent. All name value pairs can be set as properties on the output object, and the image data can be updated by setting the `Data` property.

```matlab
obj = imageshow(im);
```

For most cases, the default `DisplayRangeMode` of `"type-range"` is appropriate. Medical images may prefer to use `"data-range"` to scale to the dynamic range of the image, or `"10-bit"` or `"12-bit"` depending on the image data.

```matlab
obj = imageshow(im, DisplayRangeMode="data-range");
```

When displaying an overlay of a mask, semantic segmentation, or other image data on top of another image, use the `OverlayData` property of imageshow and the corresponding properties `OverlayColormap`, `OverlayAlpha`, `OverlayDisplayRange`, and `OverlayDisplayRangeMode` to adjust the overlay display. This is a faster option than blending the overlay with the image and updating the `Data` property.

```matlab
obj = imageshow(im, OverlayData=mask);
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

`uidraw` is ideal for cases with interactive annotations or static annotations. Calling `uidraw` without specifying the `Position` argument will begin interactive drawing. When the `Label` name value is not specified, the `Label` property on `roi` is set to `string.empty()`, which the object will interpret to display a standard measurement for the annotation type (e.g., the line will display a distance). When the viewer's `SpatialUnits` property is set to define the world units of the pixel, the annotations will include that unit in the measurement display.

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