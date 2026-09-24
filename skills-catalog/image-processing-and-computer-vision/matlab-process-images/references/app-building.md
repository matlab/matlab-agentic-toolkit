# Image Processing Apps

Decision guidance for building interactive image processing applications using `viewer2d`, `imageshow`, ROI tools, and UI components.

**Boundary with `matlab-build-app`:** This reference covers image-specific UI: `viewer2d`/`viewer3d`, `imageshow`/`volshow`, `uidraw`/`uipaint`/`uiannotate`, ROI tools, and viewer callbacks. For general app infrastructure — `uifigure`, `uigridlayout`, standard UI components (`uislider`, `uibutton`, `uidropdown`, `uitree`, etc.), callbacks, and app packaging — see the **`matlab-build-app`** skill.

> **Often loaded with:** whichever processing references the app needs (e.g., `filtering.md`, `preprocessing.md`, `segmentation-automated.md`).

## Architecture: Modern Image App Stack (R2024b+)

```
uifigure
└── uigridlayout
    ├── viewer2d          ← image container (left/main pane)
    │   └── imageshow
    └── uipanel           ← controls (right/side pane)
        └── uislider, uibutton, uidropdown, ...
```

**Key principle:** Use the Viewer object created by `viewer2d` (for images) and `viewer3d` (for volumes) as the image container in apps — not axes + `imshow`. The viewer provides built-in pan, zoom, and pixel inspection, and is the parent for `uidraw` and `uipaint`.

## Basic App Pattern

```matlab
fig = uifigure(Name="Image Processor");
gl = uigridlayout(fig, [1 2], ColumnWidth={"1x", 200});

% Image viewer (left)
v = viewer2d(gl);
im = imageshow(img, Parent=v);

% Controls panel (right)
pnl = uipanel(gl, Title="Controls");
pgl = uigridlayout(pnl, [4 1], RowHeight={30, 30, 30, "1x"});

% Add controls
sld = uislider(pgl, Limits=[0 1], Value=0.5);
sld.ValueChangedFcn = @(src, ~) updateThreshold(im, img, src.Value);
```

### Updating the Display

Update the displayed image by setting properties on the Image object — do NOT recreate `imageshow`:

```matlab
function updateThreshold(im, img, thresh)
    bw = imbinarize(img, thresh);
    im.Data = bw;          % Replace the displayed image
    % or
    im.OverlayData = bw;   % Show mask as overlay on original
end
```

**Key Image object properties for reactive updates:**

| Property | Purpose |
|----------|---------|
| `im.Data` | Replace displayed image data |
| `im.OverlayData` | Add/update label or mask overlay |
| `im.DisplayRange` | Change window/level |
| `im.DisplayRangeMode` | `"data-range"`, `"type-range"`, `"manual"` |
| `im.Colormap` | Change colormap |
| `im.AlphaData` | Transparency mask |

## ROI Drawing — `uidraw` (R2026a)

`uidraw` creates interactive ROIs in `viewer2d`/`viewer3d` contexts.

```matlab
% Interactive drawing (blocks until user finishes)
roi = uidraw(v, "polygon");            % Wait="drawing" (default)
roi = uidraw(v, "rectangle", Wait="accept");  % Blocks until Enter or accept icon — lets user adjust shape before returning

% Programmatic placement (non-interactive)
roi = uidraw(v, "rectangle", Position=[50 50 100 80], Wait="none");
```

### Available Shapes

`"point"`, `"line"`, `"rectangle"`, `"circle"`, `"ellipse"`, `"polygon"`, `"polyline"`, `"freehand"`, `"angle"` (all R2026a)

### Position Format

Position formats vary by shape. Compact shapes use a fixed-length vector; vertex-based shapes use an Nx2 or Nx3 matrix. An optional z coordinate defaults to 1 when omitted — and `roi.Position` always includes z when read back.

```matlab
% Rectangle: [xmin ymin width height]
roi = uidraw(v, "rectangle", Position=[50 50 100 80], Wait="none");

% Circle: [x y radius] or [x y z radius]
% Ellipse: [x y semix semiy] or [x y semix semiy theta]
% Angle: similar — optional z in center coordinate

% Polygon/polyline/freehand: Nx2 or Nx3
roi = uidraw(v, "polygon", ...
    Position=[50 50; 150 50; 150 150; 50 150], Wait="none");

% Point: [x y] or [x y z]
roi = uidraw(v, "point", Position=[100 100], Wait="none");
```

### Getting a Mask from ROI

```matlab
roi = uidraw(v, "polygon");
mask = createMask(roi);  % Binary mask matching displayed image size
```

### Multiple ROIs

```matlab
% Interactive: draw multiple, press Enter or accept icon when done
rois = uidraw(v, "polygon", Wait="multiple");

% Programmatic: pass multiple positions as rows of a matrix
rois = uidraw(v, "rectangle", Position=[50 50 100 80; 200 200 60 60]);
```

## Viewer Callbacks

Set callbacks on the viewer to respond to user interaction:

```matlab
% All viewer callbacks were introduced in R2026b

% Click on viewer content — image, volume, or surface
v.ObjectClickedFcn = @(~,evt) onObjectClicked(evt);

% Camera callbacks — after camera settles vs. during movement
v.CameraMovedFcn  = @(~,~) updateStatusBar(v.CameraZoom);
v.CameraMovingFcn = @(~,~) showMovingIndicator();   % fires continuously while moving

% Annotation lifecycle callbacks
v.AnnotationAddedFcn   = @(~,evt) onAnnotationAdded(evt);
v.AnnotationMovedFcn   = @(~,evt) onAnnotationMoved(evt);
v.AnnotationRemovedFcn = @(~,evt) onAnnotationRemoved(evt);
```

**Note:** `AnnotationMovedFcn` fires after the move is complete — not continuously during dragging. Use legacy `draw*` tools if you need per-ROI real-time movement events (`MovingROI`).

## Accessing and Managing Annotations Programmatically

All annotations in a viewer are stored in the `Annotations` property. Annotations can come from interactive drawing (`uidraw`, see above), static overlays (`uiannotate`, see below), or direct constructor calls. You can iterate and modify them:

```matlab
% Iterate all annotations
for roi = v.Annotations'
    roi.Color = [1 0 0];
end

% Index directly
v.Annotations(1).Label = "Region A";

% Count
n = numel(v.Annotations);
```

**Note:** Annotations may be different types (rectangles, polygons, points, etc.) with different properties, so filtering by property values like `{v.Annotations.Label}` only works when all annotations share that property. Use `isprop` or iterate with type checks when mixing annotation types.

**`SpatialUnits` affects display only:** Setting `v.SpatialUnits = "mm"` changes the units shown in measurement labels on the viewer. It does NOT convert ROI position coordinates or measurement properties — `roi.Position` and distance properties always return values in pixel/voxel units. Apply your own scale factor when converting to world units.

```matlab
v.SpatialUnits = "mm";        % display labels show "mm"
roi.Position                  % still in pixel coordinates
roi.Position * pixelSpacing   % convert yourself
```

## Static Annotations — `uiannotate` (R2026b)

`uiannotate` places static (non-interactive) annotations. Unlike `uidraw`, each call accepts all positions at once as a matrix — this makes it the right choice for displaying large numbers of overlays from detection or segmentation results.

```matlab
% Pass all positions in one call
rects  = uiannotate(v, "rectangle", positions);  % N-by-4: [x y w h] per row
circs  = uiannotate(v, "circle",    positions);  % N-by-3: [x y r] per row
pts    = uiannotate(v, "point",     positions);  % N-by-2: [x y] per row
arrows = uiannotate(v, "arrow",     positions);  % N-by-4: [x1 y1 x2 y2] (endpoints) or N-by-5: [x y u v mag] (direction+magnitude) per row
```

**Available shapes:** `"rectangle"`, `"circle"`, `"ellipse"`, `"line"`, `"polyline"`, `"point"`, `"arrow"`, `"plus"`, `"cuboid"`, `"sphere"`, `"ellipsoid"`, `"cylinder"`

The returned annotation object has these properties: `Color` (N-by-3 matrix for per-annotation colors), `Alpha`, `FaceAlpha`, `Visible`, `Tag`, `UserData`.

## Rendering Updates and Performance

The viewer renders changes efficiently when MATLAB drives the update cycle naturally. Avoid calling `drawnow` inside loops that update annotation properties — this interrupts the normal update cycle and forces a full display refresh after each individual change, which is significantly slower when working with many annotations.

```matlab
% Avoid — forces a render after every single property change
for i = 1:numel(rois)
    rois(i).Color = newColors(i,:);
    drawnow  % do not do this in a loop
end

% Prefer — let the viewer process all changes together
for i = 1:numel(rois)
    rois(i).Color = newColors(i,:);
end
```

Use `drawnow` only when you explicitly need the display to update at a specific point — for example, when capturing frames for an animation or showing incremental progress between long operations. In normal app code driven by callbacks, MATLAB handles rendering automatically.

**Performance note:** Above ~500 annotations, `uidraw` issues a warning and performance degrades. Use `uiannotate` for large overlay sets — it is optimized for displaying hundreds to thousands of static annotations.

## Paintbrush Annotation — `uipaint` (R2026a)

For freeform mask painting:

```matlab
v = viewer2d;
im = imageshow(img, Parent=v);
mask = uipaint(im, BrushSize=15);  % Blocks until user finishes
```

Multi-label painting:

```matlab
im = imageshow(img);
mask1 = uipaint(im, BrushSize=10, OverlayValue=1);
mask2 = uipaint(im, BrushSize=10, OverlayValue=2);
```

## Viewer Camera Controls

All camera properties are on the shared `Viewer` object used by both `viewer2d` and `viewer3d`.

| Property | Purpose | Since |
|----------|---------|-------|
| `CameraZoom` | Zoom level (1 = default fit) | — |
| `CameraPosition` | Camera location `[x y z]` | — |
| `CameraTarget` | Point camera looks at `[x y z]` | — |
| `CameraUpVector` | Up direction (`[0 0 1]` default for both `viewer2d` and `viewer3d`) | — |
| `CameraProjection` | `"orthographic"` (default) or `"perspective"` | R2026a |
| `CameraViewAngle` | Field of view in degrees (default 45, range 0–180); only meaningful with `"perspective"` projection | R2026a |
| `CameraViewport` | Visible region as `[x y width height]` in world coordinates | R2026a |
| `CameraInteractionStyle` | Style of rotate, zoom, and pan — see table below | R2026a |

```matlab
% Programmatic zoom reset button
btn = uibutton(pgl, Text="Reset View");
btn.ButtonPushedFcn = @(~,~) set(v, CameraZoom=1);

% Focus viewer on a specific image region (R2026a)
v.CameraViewport = [x y width height];

% Set view to a standard angle on a 3-D viewer (R2026a)
viewangle(v3d, 45, 30);  % azimuth, elevation
```

### CameraInteractionStyle Values (R2026a)

Default is `"planar"` for `viewer2d` and `"scene-orbit"` for `viewer3d`.

| Value | Rotate around | Notes |
|-------|--------------|-------|
| `"scene-orbit"` | Scene center | Default for `viewer3d` |
| `"click-orbit"` | Clicked location | Common for point clouds |
| `"target-orbit"` | `CameraTarget` | Useful when focusing on a specific object |
| `"focus-orbit"` | Most recent zoom location | Useful when zooming in then rotating around a feature |
| `"planar"` | Scene center (roll only) | Default for `viewer2d` — image plane stays constant |
| `"dolly"` | — | First-person perspective; requires `CameraProjection="perspective"` |
| `"walk"` | — | First-person flyover, z stays constant; requires `CameraProjection="perspective"` |

```matlab
% Make viewer display-only (disable all user interaction)
v.Interactions = "none";

% Hide or auto-hide toolbar for cleaner app UI
v.Toolbar = "off";     % always hidden
v.Toolbar = "hover";   % appears on mouse-over only
```

## Linked Viewers (R2026a)

Synchronize pan/zoom across multiple viewers:

```matlab
gl = uigridlayout(fig, [1 2]);
v1 = viewer2d(gl);
v2 = viewer2d(gl);
imageshow(original, Parent=v1);
imageshow(processed, Parent=v2);

linkviewers([v1 v2]);  % Synchronized pan/zoom
```

## Cropping the Viewer

`CropRegion` clips the displayed scene to a region — useful for focusing a volume app on a structure of interest after detection. The underlying data is not modified; only the visualization is affected.

```matlab
% Crop to a rectangular box around a detected region (R2023b)
v.CropRegion = [xmin ymin zmin; xmax ymax zmax];

% Clear the crop
v.CropRegion = [];
```

For 2-D viewers, use `CameraViewport` instead — `CropRegion` is primarily for 3-D/volume scenes.

| Property | Purpose |
|----------|---------|
| `CropRegion` | `2-by-3 matrix` (rectangular), `[x y z r]` (spherical, R2024b), `5-element vector` (cylindrical, R2024b) |
| `CropMode` | `"inclusive"` (show inside, default) or `"exclusive"` (hide inside) |
| `CropInteractions` | `"all"` (user can drag crop box, default) or `"none"` (programmatic only) |

```matlab
% Programmatic-only crop with no user interaction
v.CropRegion = [xmin ymin zmin; xmax ymax zmax];
v.CropInteractions = "none";

% Inverted crop — hide the interior, show the surroundings
v.CropMode = "exclusive";
```

## Legacy ROI Tools (R2018b+, axes-based)

For apps using traditional axes (not `viewer2d`):

```matlab
ax = uiaxes(gl);
imshow(img, Parent=ax);  % Legacy: axes-based display

roi = drawpolygon(ax);       % Interactive polygon
roi = drawrectangle(ax, Position=[50 50 100 80]);  % Programmatic
mask = createMask(roi);
```

**Legacy ROI events** (richer than `uidraw`):

```matlab
addlistener(roi, "ROIMoved", @(src, ~) onROIMoved(src));
addlistener(roi, "MovingROI", @(src, evt) onMoving(evt));
```

Available events: `MovingROI`, `ROIMoved`, `ROIClicked`, `DeletingROI`, `DrawingStarted`, `DrawingFinished`

### When to Use Legacy vs Modern

| Use case | Approach |
|----------|----------|
| New app (R2024b+) | `viewer2d` + `imageshow` (add `uidraw` from R2026a) |
| Need ROI event callbacks | Legacy `draw*` in axes (richer events) |
| Volume display in app | `viewer3d` + `volshow` |
| Existing app with `uiaxes` | Legacy `draw*` functions |

## Visual Inspection Metrology Tools (requires Visual Inspection Toolbox)

These tools add precision measurement overlays to an image displayed with `imageshow`. All take the `imageshow` Image object as input — not the viewer.

```matlab
im = imageshow(img);  % Image object, not the viewer
```

| Function | Purpose | Key output property | Since |
|----------|---------|---------------------|-------|
| `uicaliper(im)` | Edge-pair distance along a scan line | `IntraEdgeDistance`, `InterEdgeDistance` | R2025a |
| `uitsquare(im)` | Point-to-line perpendicular distance (T-square) | `Distance` | R2026b |
| `uifitcircle(im)` | Circle fitting — center, radius, area | `Center`, `Radius`, `Area` | R2026b |
| `uifitangle(im)` | Angle between two lines | `Theta` | R2026b |

```matlab
% Caliper: measure edge-pair distances interactively
cal = uicaliper(im, EdgeTransition="rising");
d   = cal.IntraEdgeDistance;   % distance within each edge pair

% T-square: point-to-line perpendicular distance
tsq = uitsquare(im);
d   = tsq.Distance;            % N-by-1 perpendicular distances

% Circle fit: fit circle to circular feature
circ = uifitcircle(im, Snap=true);
r    = circ.Radius;
c    = circ.Center;

% Angle: measure angle between two edges
ang   = uifitangle(im);
theta = ang.Theta;
```

`uitsquare`, `uifitcircle`, and `uifitangle` have a `snap()` method that automatically aligns the tool to detected edges:

```matlab
tsq  = uitsquare(im, LineSnapMethod="closest", EdgeMap="canny");
snap(tsq);   % aligns tool to detected edges
```

## Complete App Example

```matlab
function imageThresholdApp(img)
    fig = uifigure(Name="Threshold App");
    gl = uigridlayout(fig, [2 2], ...
        RowHeight={"1x", 40}, ColumnWidth={"1x", "1x"});

    % Original and result viewers
    v1 = viewer2d(gl); v1.Layout.Row = 1; v1.Layout.Column = 1;
    v2 = viewer2d(gl); v2.Layout.Row = 1; v2.Layout.Column = 2;
    linkviewers([v1 v2]);

    gray = im2gray(img);
    im1 = imageshow(img, Parent=v1);
    im2 = imageshow(imbinarize(gray), Parent=v2);

    % Threshold slider
    sld = uislider(gl, Limits=[0 1], Value=graythresh(gray));
    sld.Layout.Row = 2; sld.Layout.Column = [1 2];
    sld.ValueChangedFcn = @(src, ~) updateResult(im2, img, src.Value);
end

function updateResult(im, img, thresh)
    im.Data = imbinarize(img, thresh);
end
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `figure` instead of `uifigure` | `figure` includes toolstrips and behaviors not suitable for apps | Use `uifigure` for apps |
| `imtool` for interactive viewing | Legacy, will be removed | Use `viewer2d` + `imageshow` |
| `imshow` in `uifigure` app | Creates axes, no viewer features | Use `viewer2d` + `imageshow` |
| Recreating `imageshow` on each update | Slow, flickers, loses zoom state | Set `im.Data = newImg` instead |
| `drawpolygon` in `viewer2d` | Legacy ROIs need axes parent | Use `uidraw(v, "polygon")` |
| Reading `uidraw` Position and expecting no z column | All shapes store z (defaults to 1) — Position always includes z when read back | Expect z in `roi.Position` |
| `uipaint(v)` passing viewer | Takes Image object, not viewer | `uipaint(im)` where `im = imageshow(...)` |
| Building ROI callbacks with `uidraw` | New ROIs lack `MovingROI` events | Use legacy `draw*` if real-time events needed |
| Calling `drawnow` after each annotation change in a loop | Forces one render per change — prevents efficient batching | Update all properties first, let MATLAB handle rendering |
| Expecting `roi.Position` in world units after setting `SpatialUnits` | `SpatialUnits` only changes display labels — positions stay in pixels | Apply `pixelSpacing` scale factor yourself |

----

Copyright 2026 The MathWorks, Inc.

----
