---
name: matlab-display-volume
description: Display 3-D image volumes, medical image volumes, surface meshes, and annotations for 3-D image processing. Use when displaying 3-D images or isosurfaces with volshow, creating volume viewers with viewer3d, adding Regions of Interest (ROI) or annotations, overlaying masks or segmentations, streaming volumetric data, or building apps with volume display.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Volume Display

Display volumes with `volshow` for performant, high quality volume display. Display isosurface meshes, triangulations, and surfaces using `images.ui.graphics.Surface` rather than `isosurface` for more performant, higher quality mesh display with more responsive interactions for meshes of all sizes.

## When to Use

- User asks to create a GUI, app, dashboard, or interactive tool for volume, isosurface, or surface mesh display
- User wants ROIs, annotations, or other lines and shapes plotted on top of the volume or surface mesh
- User wants to display labeled data or other overlay volumes on top of a volume

## When NOT to Use

- User does not have the Image Processing Toolbox — fall back to `isosurface` + `patch`, but recommend `volshow` for better performance.

## Medical Image Volumes

When the user has the Medical Imaging Toolbox, use `medicalVolume` to load DICOM/NIfTI/NRRD files, then call the `volshow` method on that object. This automatically sets the spatial `Transformation` and `SpatialUnits` from the file metadata. All other patterns in this skill (Viewer, overlays, annotations, streaming, app building) still apply — only the entry point differs.

```matlab
medVol = medicalVolume("brain.nii");
obj = volshow(medVol);
```

## Key Objects

| Object | Constructor | Key callback |
|--------|------------|-------------|
| `Viewer` | `viewer3d(parent)` | `CameraMovedFcn`, `ObjectClickedFcn` |
| `Volume` | `volshow(data, Parent=viewer)` | |
| `Surface` | `images.ui.graphics.Surface(viewer, Data=tri)` | |
| Interactive Annotations | `uidraw(parent, "shape")` | `AnnotationMovedFcn` (on Viewer) |

**Utilities:** `linkviewers(viewers)` synchronizes camera motion across multiple Viewers. `title(viewer, "text")` sets the Viewer title.

## Workflow

1. **Create Viewer** — call `viewer3d()` or `viewer3d(parent)` for app contexts
2. **Add Volume** — call `volshow(V, Parent=viewer)` to display volumetric data
3. *(Optional)* **Add surfaces** — call `images.ui.graphics.Surface(viewer, Data=tri)` for mesh display
4. *(Optional)* **Add annotations** — call `uidraw(volObj, "line")` for interactive ROIs
5. *(Optional)* **Configure callbacks** — set `CameraMovedFcn`, `AnnotationMovedFcn`, or `ObjectClickedFcn` on the Viewer
6. **Update data** — set `obj.Data = newV` to stream; use `waitfor(viewer,"Busy",false)` for synchronization

## Legacy Patterns to Avoid

| Do NOT use | Use instead | Why |
|------------|-------------|-----|
| `isosurface` + `patch` | `images.ui.graphics.Surface(viewer, Data=tri)` | Better rendering, interactive performance, depth peeling |
| `clear(viewer)` then re-add objects | Reuse objects, update `Data` property | Avoids reconstruction overhead |
| `drawnow` for volume streaming sync | `waitfor(viewer,"Busy",false)` | Volume data loads asynchronously; `drawnow` is still appropriate for Surface animation |
| Creating new `volshow` each frame | Keep reference, set `obj.Data = V` | Reuse avoids GPU reallocation |

## Patterns

### Standard Volume Display

Simple cases of volume display can call `volshow` without specifying a parent. All name-value arguments can be set as properties on the Volume object, and the volume data can be updated by setting the `Data` property.

```matlab
obj = volshow(V);
```

Choose `DisplayRangeMode` based on the data type and value range:

| Data characteristics | Recommended mode |
|---------------------|-----------------|
| Normalized `single`/`double` in [0, 1] | `"data-range"` (default) |
| `uint8` or `int8` | `"data-range"` (default) |
| `uint16` with values up to 1023 (e.g., 10-bit CT) | `"10-bit"` |
| `uint16` with values up to 4095 (e.g., 12-bit CT/MR) | `"12-bit"` |
| `uint16` full range or `int16` | `"16-bit"` |
| Custom window/level needed | `"manual"` with `DisplayRange=[low high]` |

```matlab
% 12-bit medical volume
obj = volshow(V, DisplayRangeMode="12-bit");

% Manual window/level
obj = volshow(V, DisplayRangeMode="manual", DisplayRange=[200 1200]);
```

Set `RenderingStyle` to control how voxel data is visualized. See the dedicated **Rendering Styles** section below for detailed guidance.

**Choosing a Colormap** — Select based on data content:

| Data content | Recommended colormap | Rationale |
|-------------|---------------------|-----------|
| CT / MR (anatomical) | `gray(256)` | Clinical convention; preserves radiologist familiarity |
| CT with window/level | `gray(256)` + `DisplayRange` | Narrow range highlights target tissue |
| Fluorescence / emission | `hot(256)` or `green(256)` | Hot emphasizes intensity peaks; green matches fluorophore |
| General scientific | `parula(256)` (default) | Perceptually uniform, accessible |
| Multi-structure / labeled | `turbo(256)` | Full-spectrum rainbow, perceptually ordered |
| Signed data (e.g., flow, strain) | Custom diverging (blue-white-red) | Distinguishes positive/negative around midpoint |

```matlab
obj = volshow(V, Colormap=gray(256));
```

**Choosing an Alphamap** — The alphamap is a 256×1 vector mapping normalized intensity [0, 1] to opacity [0, 1]. It controls which structures are visible vs. transparent. The default is a cubic ramp (`x.^3`), which suppresses low-intensity background while revealing bright structures.

| Goal | Alphamap shape | Construction |
|------|---------------|--------------|
| Show bright structures, hide background | Cubic ramp (default) | `linspace(0,1,256)'.^3` |
| Show all intensities equally | Linear ramp | `linspace(0,1,256)'` |
| Reveal only a specific intensity band | Gaussian peak | `exp(-((x-center).^2)/(2*width^2))` |
| Hard threshold (binary visibility) | Step function | `double((1:256)' > threshold)` |
| Hide bright, show dim (e.g., cavities) | Inverted ramp | `linspace(1,0,256)'` |
| Custom: show bone, hide soft tissue (CT) | Step at bone HU | `double(linspace(0,1,256)' > 0.3)` |

```matlab
% Gaussian alphamap centered at 60% intensity (width 10%)
x = linspace(0, 1, 256)';
alpha = exp(-((x - 0.6).^2) / (2*0.1^2));
obj = volshow(V, Alphamap=alpha, Colormap=gray(256));

% Hard threshold — only show voxels above 30% of the display range
alpha = double(linspace(0, 1, 256)' > 0.3);
obj = volshow(V, Alphamap=alpha);
```

For per-voxel opacity control (e.g., masking specific regions regardless of intensity), set the `AlphaData` property to a volume the same size as `Data` with values in [0, 1]:

```matlab
obj = volshow(V, AlphaData=double(regionMask));
```

When displaying an overlay of a mask, semantic segmentation, or other volume data on top of another volume, use the `OverlayData` property of the Volume object and the corresponding name-value arguments `OverlayColormap`, `OverlayAlpha`, `OverlayRenderingStyle`, `OverlayDisplayRange`, and `OverlayDisplayRangeMode` to adjust the overlay display. This is a faster option than blending the overlay with the volume and updating the `Data` property, or adding a second Volume object to the Viewer. The default properties for overlay display are tuned to support semantic labels, but can be adjusted to support continuous data for other purposes.

```matlab
obj = volshow(V, OverlayData=mask);
```

If spatial referencing information is available, include it in the `Transformation` name-value argument. Build an `imref3d` from voxel spacing and volume size, or use an `affinetform3d` for arbitrary affine transforms. When using `medicalVolume`, the `volshow` method sets the transformation automatically from file metadata.

```matlab
% From voxel spacing (e.g., [0.5 0.5 1.0] mm)
R = imref3d(size(V), 0.5, 0.5, 1.0);
obj = volshow(V, Transformation=R);

% From an affine matrix
tform = affinetform3d(A);
obj = volshow(V, Transformation=tform);
```

For large volumes that exceed GPU texture memory (typically > 2048³ voxels) or are too large to fit in RAM, create a multilevel `blockedImage` and pass it to `volshow`. The `makeMultiLevel3D` function creates a resolution pyramid for progressive rendering — the Viewer loads coarse levels first, then refines as the camera settles.

```matlab
bim = blockedImage(V, BlockSize=[512,512,512]);
mbim = makeMultiLevel3D(bim, Scales=[2 4 8]);
volshow(mbim);
```

Use `Scales` to control the downsampling factors. Each scale creates a level at 1/N resolution. For very large volumes (e.g., 4096³+), include more scales (e.g., `[2 4 8 16]`). Smaller volumes that just exceed the texture limit need fewer levels (e.g., `[2 4]`). The `BlockSize` should match or be a multiple of the GPU texture block size (512³ is a good default).

### Surface Mesh Display

Displaying surface meshes using `images.ui.graphics.Surface` offers better rendering and interactive performance over `isosurface` + `patch`. Pass a `triangulation` object as `Data` and an N×3 matrix of per-vertex RGB colors as `Color`.

```matlab
% tri = triangulation(...), cpoints = N-by-3 vertex colors
viewer = viewer3d(BackgroundGradient="off", BackgroundColor="white");
obj = images.ui.graphics.Surface(viewer, Data=tri, Color=cpoints);
```

When possible, displaying the mesh with the default `Alpha` of 1.0 is recommended for optimal performance. You can call images.ui.graphics.Surface multiple times to add multiple objects to the scene and the objects will be sorted and rendered spatially correct with depth peeling. When objects are transparent, more render passes are required and the performance will decrease.

Surface meshes can be displayed together with volumes in the same Viewer.

```matlab
viewer = viewer3d();
volObj = volshow(V, Parent=viewer);
surfObj = images.ui.graphics.Surface(viewer, Data=tri);
```

When updating the position or size of a Surface, it is much faster to update the `Transformation` property than to re-set `Data` with a new triangulation. Use `drawnow` to flush the graphics queue between frames (this is appropriate for Surface animation — only volume streaming requires `waitfor`).

```matlab
viewer = viewer3d(BackgroundGradient="off", BackgroundColor="white");
obj = images.ui.graphics.Surface(viewer, Data=tri, Color=cpoints);

% Disable auto camera position update
viewer.CameraPositionMode = "manual";

% Animate the surface moving in the z direction
for idx = 1:100
    tform = transltform3d(0, 0, idx);
    obj.Transformation = tform;
    drawnow;
end
```

### Rendering Styles

The `RenderingStyle` property on the Volume object controls how voxel data is visualized. Choose the style based on what structures need to be visible.

**Maximum Intensity Projection (MIP)** — Projects the brightest voxel along each viewing ray onto the screen. Ideal for vascular imaging (angiography), fluorescence microscopy, or any data where bright structures are the signal of interest.

```matlab
obj = volshow(V, RenderingStyle="MaximumIntensityProjection");
```

**Gradient Opacity** — Makes large homogeneous regions (low gradient) transparent while preserving regions with sharp intensity transitions (high gradient). This lets you see through bulk tissue to reveal boundaries and edges within the volume.

```matlab
obj = volshow(V, RenderingStyle="GradientOpacity");
```

**Cinematic Rendering** — State-of-the-art photorealistic rendering with global illumination, ambient occlusion, and soft shadows. Produces the highest quality visualization for solid structures like bone in CT scans. More computationally expensive but delivers publication-quality results.

```matlab
obj = volshow(V, RenderingStyle="CinematicRendering");
```

**Other styles:**

| RenderingStyle | Use when |
|---------------|----------|
| `"VolumeRendering"` | Default — semi-transparent volume with transfer function based on intensity |
| `"MinimumIntensityProjection"` | Showing darkest structures (e.g., airways, cavities) |
| `"Isosurface"` | Displaying a surface at a threshold (set `IsosurfaceValue`) |
| `"SlicePlanes"` | Viewing orthogonal slices through the volume |
| `"LightScattering"` | Simulated light scattering for soft tissue appearance |

```matlab
% Isosurface at a specific threshold (e.g., bone in CT)
obj = volshow(V, RenderingStyle="Isosurface", IsosurfaceValue=300);

% Orthogonal slice planes
obj = volshow(V, RenderingStyle="SlicePlanes");
```

### Streaming Volumes

When updating the display, reuse objects whenever possible. Avoid using the `clear` method on the Viewer when you are going to re-add the same types of objects — always reuse. Keep the Volume object returned by `volshow` and update its `Data` property. Volume data is loaded asynchronously, so `drawnow` may return before rendering completes. Use `waitfor` on the Viewer's `Busy` property to block until the data has finished loading.

```matlab
viewer = viewer3d();
obj = volshow([], Parent=viewer);

for idx = 1:10
    V = rand([512,512,512]);
    obj.Data = V;
    waitfor(viewer, "Busy", false);
end
```

### Generating Animations

When generating animations or capturing frames, use `getframe` and pass the Viewer (parent of the Volume object) as the first argument. The Viewer waits until all pending updates have processed before capturing, which guarantees each frame is fully rendered.

```matlab
viewer = viewer3d();
obj = volshow([], Parent=viewer);

frames = cell(1, 100);
for idx = 1:100
    V = rand([512,512,512]);
    obj.Data = V;
    frames{idx} = getframe(viewer);
end
```

### Adding Annotations on Volume

When displaying interactive or a small number of annotations on the volume, use the `uidraw` function to start interactively drawing or to programmatically place an annotation.

`uidraw` is ideal for fewer than 100 annotations. Omitting `Position` starts interactive drawing. When `Label` is not specified, the ROI displays a standard measurement (e.g., distance for lines). Set `SpatialUnits` on the Viewer to include units in the measurement display.

```matlab
obj = volshow(V);
viewer = obj.Parent;
viewer.SpatialUnits = "mm";

% Interactive drawing (user places the line)
roi = uidraw(obj, "line", Color=[1,0,0]);

% Programmatic placement (no interaction required)
roi2 = uidraw(obj, "point", Position=[20,20,50], Color=[0,0,1], Label="Point of Interest");

% Multi-point polyline from a position matrix (each row is a point)
pos = [20,20,50; 50,60,75; 50,80,100];
roi3 = uidraw(obj, "polyline", Position=pos, Color=[0,1,0]);

% Make an annotation static (disable further interaction)
set(roi3, "Interactions", "none");
```

### Responding to User Interactivity

Add function handles to callback properties on the Viewer to respond to user interaction. `CameraMovedFcn` fires after the camera is moved. `AnnotationMovedFcn` fires after the user interactively moves or reshapes an annotation. `ObjectClickedFcn` fires after the user clicks and releases in the Viewer without dragging (a click-and-drag initiates the default interaction, typically panning). Use the event data to determine which object was clicked.

```matlab
V = rand([100,100,100]);
obj = volshow(V);
viewer = obj.Parent;
% Draw a rectangle ROI interactively
roi = uidraw(obj, "point", Color=[0,1,0], Label="ROI");
% Listen for movement and display the position
viewer.AnnotationMovedFcn = @(~,evt) fprintf("ROI Position: [%.1f, %.1f, %.1f]\n", evt.Position);
```

### App Building

When building apps, call `viewer3d(parent)` to create a Viewer parented to a `uigridlayout`, then call `volshow` with that Viewer as the parent. Create the Volume object eagerly at construction time with empty data (`[]`) — this avoids conditional logic later and lets you simply update `obj.Data` when data becomes available. Only defer Volume creation if the app supports switching between fundamentally different display modes (e.g., volume vs. surface-only).

Use a standard app classdef (see `matlab-building-apps` skill) with the following in `createComponents`:

```matlab
% Inside createComponents(app) — viewer3d parented to grid layout
app.GridLayout = uigridlayout(app.UIFigure, [1 1]);
app.GridLayout.RowHeight = {"fit"};
app.GridLayout.ColumnWidth = {"fit"};

app.Viewer = viewer3d(app.GridLayout);
title(app.Viewer, "App Display");
app.Viewer.Layout.Row = 1;
app.Viewer.Layout.Column = 1;

% Create Volume eagerly with empty data
app.Volume = volshow([], Parent=app.Viewer);
```

Then update data later with `app.Volume.Data = im;`.

### Adding a Colorbar to a Volume App

Since the Viewer does not natively support a colorbar, place an invisible `uiaxes` with a colorbar in an adjacent grid column. Set `Colormap` and `CLim` on the axes to match the Volume object, then call `colorbar` on that axes.

```matlab
fig = uifigure(Name="Volume with Colorbar", Position=[100 100 800 500]);
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {"1x", 80};

% Volume viewer in left column
viewer = viewer3d(gl);
viewer.Layout.Row = 1;
viewer.Layout.Column = 1;
title(viewer, "Colorbar with Volshow");

V = rand([64 64 64]);
vol = volshow(V, Parent=viewer, Colormap=parula(256));

% Invisible axes with colorbar in right column
ax = uiaxes(gl, Visible="off", HitTest="off", PickableParts="none");
ax.Layout.Row = 1;
ax.Layout.Column = 2;
ax.Toolbar.Visible = "off";

% Match colormap and data range to the Volume object
ax.Colormap = vol.Colormap;
ax.CLim = [min(vol.Data, [], "all"), max(vol.Data, [], "all")];
cb = colorbar(ax, Units="normalized");
```

### Linking Multiple Viewers

Use `linkviewers` to synchronize camera motion across multiple Viewers. When the user rotates or zooms one Viewer, all linked Viewers update to match. Pass `"off"` to unlink.

```matlab
viewer1 = viewer3d();
viewer2 = viewer3d();
title(viewer1, "Original");
title(viewer2, "Segmentation");

volshow(V, Parent=viewer1);
volshow(V, Parent=viewer2, OverlayData=mask);

linkviewers([viewer1, viewer2]);
```

## Conventions

- Always: Pass the Viewer as the first positional argument to `images.ui.graphics.Surface(viewer, ...)` — do NOT use `Parent=viewer` as a name-value argument
- Always: Reuse Volume objects by updating `obj.Data` — never recreate the volume each frame
- Always: Use `waitfor(viewer, "Busy", false)` to synchronize after setting `Data` when timing matters (screenshots, frame capture)
- Always: Use `getframe(viewer)` not `getframe(gcf)` for screenshots — the Viewer handles async completion
- Always: When the user has Medical Imaging Toolbox, use `volshow(medVol)` on a `medicalVolume` object — this auto-sets `Transformation` and `SpatialUnits`
- Never: Call `clear(viewer)` to reset the scene — reuse existing objects instead
- Never: Use `isosurface` + `patch` for mesh display when Image Processing Toolbox is available
- Prefer: `OverlayData` property for masks/segmentations over blending into `Data` or adding a second volume
- Prefer: Updating `Transformation` over re-setting `Data` when only position/size changes

----

Copyright 2026 The MathWorks, Inc.

----
