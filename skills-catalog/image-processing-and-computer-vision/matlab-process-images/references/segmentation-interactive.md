# Interactive Segmentation

Decision guidance for segmentation methods that use user input — point/box prompts, scribbles, ROIs, seed points, or initial masks. When a user can provide any form of guidance, **prompted SAM is the recommended first choice** for its accuracy, flexibility, and zero-shot capability.

> **Often loaded with:** `morphological-ops.md` (cleaning up masks), `analysis-measurement.md` (measuring segmented regions), `segmentation-automated.md` (when no user input is available).

## Method Selection

| Task | User input | Algorithm |
|------|-----------|-----------|
| Segment specific object (best quality) | Point or bounding box | `segmentAnythingModel` (prompted SAM) **(CVT+DLT)** |
| Foreground/background separation | ROI rectangle | `grabcut` (requires superpixels) |
| Foreground/background from strokes | Scribbles | `lazysnapping` (requires superpixels) |
| 2–3 regions from strokes | Scribbles | `imseggeodesic` |
| Flood-fill from seed | Seed point + tolerance | `grayconnected` |
| Region growing from seeds | Seed points | `imsegfmm` |
| Evolving boundary to edges | Initial mask | `activecontour` |
| Medical organ/tumor (interactive box) | Bounding box | `medicalSegmentAnythingModel` **(MIT)** |
| Cell/nucleus instances | Automatic or prompted | `cellpose` → `segmentCells2D` / `segmentCells3D` **(MIT)** |

**Default recommendation:** Use prompted SAM when available — it handles the widest range of scenarios with minimal user input and no training data.

**Coordinate order varies by function:** SAM functions (`ForegroundPoints`, `BoundingBox`) use **(x, y)** order. Seed-based functions (`grayconnected`, `graydiffweight`, `imsegfmm`) use **(C, R)** order (column first, then row). Active contour and masks use standard **(row, col)** array indexing.

## Prompted SAM — First Choice (R2024b+)

Requires IPT Model for Segment Anything Model support package and Computer Vision Toolbox + Deep Learning Toolbox.

```matlab
try
    sam = segmentAnythingModel;  % Verifies support package AND Python environment
    hasSAM = true;
catch
    hasSAM = false;  % Help the user install the support package or fix the Python environment
end
```

> **Do not use `which` alone** — `~isempty(which("segmentAnythingModel"))` returns true even when the Python environment is missing or broken. Always attempt construction to confirm usability.

### Setup

```matlab
sam = segmentAnythingModel("sam2-large");
embeddings = extractEmbeddings(sam, I);  % Expensive — do ONCE per image
```

### Point Prompts

```matlab
% Single foreground point — [x, y] coordinates on the object
masks = segmentObjectsFromEmbeddings(sam, embeddings, size(I), ...
    ForegroundPoints=[200 150]);

% Refine with background points
masks = segmentObjectsFromEmbeddings(sam, embeddings, size(I), ...
    ForegroundPoints=[200 150], BackgroundPoints=[50 50; 350 350]);
```

### Bounding Box Prompt

```matlab
% [x, y, width, height]
masks = segmentObjectsFromEmbeddings(sam, embeddings, size(I), ...
    BoundingBox=[50 80 200 180]);
```

### Multiple Objects from Same Image

```matlab
% Extract embeddings once, segment multiple times
embeddings = extractEmbeddings(sam, I);

mask1 = segmentObjectsFromEmbeddings(sam, embeddings, size(I), ...
    ForegroundPoints=[100 200]);
mask2 = segmentObjectsFromEmbeddings(sam, embeddings, size(I), ...
    BoundingBox=[300 100 150 200]);
```

**Key rules:**
- `segmentObjectsFromEmbeddings` returns an **H×W logical mask** (single best mask by default). Use `ReturnMultiMask=true` to get H×W×3 with three ranked candidates.
- Extract embeddings once per image, segment multiple objects from same embeddings
- `size(I)` (third argument) is required — maps embeddings back to image coordinates
- `ForegroundPoints` and `BoundingBox` use **(x, y)** order, not (row, col)
- Combine foreground + background points for difficult cases

**Fallback** when SAM unavailable: `grabcut` for foreground/background, `activecontour` for boundary refinement, or `imsegfmm` for region growing.

## GrabCut — Foreground/Background from ROI

**Gotcha:** `grabcut` requires a superpixel label matrix in addition to the image. Always compute superpixels first:

```matlab
[L, N] = superpixels(I, 500);    % REQUIRED before grabcut
ROI = false(size(I,1), size(I,2));
ROI(50:300, 100:350) = true;
BW = grabcut(I, L, ROI);
```

Works on 3-D volumes too (with `superpixels3`).

## Lazy Snapping — Foreground/Background from Scribbles

Requires scribble masks indicating foreground and background regions. `fgScribble` and `bgScribble` are **logical masks** (same size as image) where `true` marks user-drawn strokes:

```matlab
[L, N] = superpixels(I, 500);    % REQUIRED before lazysnapping
BW = lazysnapping(I, L, fgScribble, bgScribble);
```

## Geodesic Segmentation — 2–3 Regions from Scribbles

For partitioning an image into a small number of regions based on user-drawn scribbles. **Requires RGB input** — does not work on grayscale. Returns a label matrix (not a binary mask):

```matlab
L = imseggeodesic(RGB, scribble1, scribble2);           % 2 regions
L = imseggeodesic(RGB, scribble1, scribble2, scribble3); % 3 regions
```

## Gray Connected — Flood-Fill from Seed

Simple region growing based on intensity similarity to a seed pixel:

```matlab
BW = grayconnected(I, row, col, 20);  % tolerance is positional (not a Name-Value pair)
```

## Active Contours — Evolving Boundary

Evolves an initial mask toward object boundaries. Users struggle most with creating the initial mask. Options:

```matlab
% From rough threshold + dilate (most common)
mask = imbinarize(I);
mask = imdilate(mask, strel("disk", 10));
BW = activecontour(I, mask, 200, "Chan-Vese");

% From bounding rectangle
mask = false(size(I));
mask(r1:r2, c1:c2) = true;
BW = activecontour(I, mask, 200, "edge");
```

| Method | Use when |
|--------|----------|
| `"Chan-Vese"` | Region-based, objects without strong edges |
| `"edge"` | Objects with clear boundary edges |

Works on 3-D volumes with same syntax.

## Fast Marching — `imsegfmm`

Region growing from seeds using a weight array:

```matlab
% Weight from intensity difference to seed
% graydiffweight and imsegfmm take (C, R) order — column first, then row
W = graydiffweight(I, col, row, GrayDifferenceCutoff=25);
BW = imsegfmm(W, col, row, 0.01);  % threshold on travel time

% Weight from gradient magnitude
W = gradientweight(I);
BW = imsegfmm(W, seedMask, 0.01);
```

## Medical Segmentation (Medical Imaging Toolbox)

For medical images with MIT available:

| Task | Function |
|------|----------|
| 2-D organ/tumor (interactive box) | `medicalSegmentAnythingModel` |
| 3-D automatic (organs) | `medicalImageLabeler` with MONAI Label |
| Cell/nucleus segmentation | `cellpose` → `segmentCells2D` / `segmentCells3D` |
| Radiomic features from ROI | `radiomics` |

For full medical segmentation workflows (MedSAM, Cellpose, radiomics), see Medical Imaging Toolbox documentation.

## Building Interactive Segmentation Apps

Use App Designer to build custom interactive segmentation tools with SAM. The pattern combines a `Viewer` for display, annotation-based prompts, and real-time mask preview.

### Architecture Pattern

Build a custom UI component inheriting from `matlab.ui.componentcontainer.ComponentContainer`:

```matlab
classdef SAMSegmenter < matlab.ui.componentcontainer.ComponentContainer
    properties
        Image
        Mask
        SavedMask
        SegmentationAlpha = 0.5
    end
    properties (Access = private)
        Model           % segmentAnythingModel object
        Embeddings      % Extracted once per image
        Viewer          % images.ui.graphics.Viewer
        ImageObject     % Image displayed in viewer
        Bbox            % Current bounding box
        SegmentRequired % Flag to trigger update
        CurrentLabelID = 1
        IsForegroundMode = true
    end
    methods (Access = protected)
        function setup(comp)
            comp.Viewer = viewer2d(comp);
            comp.ImageObject = imageshow([], Parent=comp.Viewer);
            comp.Viewer.AnnotationAddedFcn = @(~,evt) annotationAdded(comp, evt);
        end
    end
end
```

### Key Workflow: Load → Embed → Annotate → Preview → Commit

```matlab
% 1. Load image and extract embeddings ONCE
function loadImage(comp, imageData)
    comp.Image = imageData;
    comp.Model = segmentAnythingModel("sam2-large");
    comp.Embeddings = extractEmbeddings(comp.Model, imageData);
    comp.ImageObject.Data = imageData;
    comp.SavedMask = zeros(size(imageData, [1 2]), "uint8");
end
```

### Annotation-Driven Segmentation (update method)

The `update` method fires whenever annotations change, providing real-time preview:

```matlab
function update(comp)
    if ~comp.SegmentRequired, return; end
    comp.SegmentRequired = false;

    imageSize = size(comp.ImageObject.Data);
    annotations = comp.Viewer.Annotations;

    % Collect foreground/background points from annotations
    foreground = [];
    background = [];
    for idx = 1:numel(annotations)
        if isa(annotations(idx), "images.ui.graphics.roi.Point") && isvalid(annotations(idx))
            if annotations(idx).UserData  % true = foreground
                foreground(end+1,:) = annotations(idx).Position(1:2);
            else
                background(end+1,:) = annotations(idx).Position(1:2);
            end
        end
    end

    if isempty(foreground) && isempty(comp.Bbox), return; end

    % Segment using current prompts
    mask = segmentObjectsFromEmbeddings(comp.Model, comp.Embeddings, imageSize, ...
        ForegroundPoints=foreground, BoundingBox=comp.Bbox, BackgroundPoints=background);

    % Preview: overlay new mask on saved mask
    priorMask = comp.SavedMask;
    priorMask(mask) = uint8(comp.CurrentLabelID);
    comp.ImageObject.OverlayData = priorMask;
end
```

### Handling Annotations via Viewer Events

Use the `AnnotationAdded` event from `Viewer` to process user interactions:

```matlab
function annotationAdded(comp, event)
    event.Annotation.Interactions = "click";

    if isa(event.Annotation, "images.ui.graphics.roi.Rectangle")
        % Bounding box drawn — save position, switch to point mode
        comp.Bbox = event.Annotation.Position;
        comp.Viewer.Mode.Annotate.Style = "point";
        comp.Viewer.Mode.Annotate.ContinueAnnotating = true;
        comp.Viewer.Mode.CurrentMode = "annotate";
    else
        % Point — validate it's inside bounding box
        if ~isempty(comp.Bbox)
            pos = event.Annotation.Position;
            if pos(1) < comp.Bbox(1) || pos(2) < comp.Bbox(2) || ...
                    pos(1) > (comp.Bbox(1)+comp.Bbox(3)) || pos(2) > (comp.Bbox(2)+comp.Bbox(4))
                delete(event.Annotation);
                return;
            end
        end
        event.Annotation.UserData = comp.IsForegroundMode;
    end
    comp.SegmentRequired = true;
end
```

### Commit / Revert Pattern

```matlab
% Commit current preview to saved mask
function saveMask(comp)
    comp.SavedMask = comp.ImageObject.OverlayData;
    comp.Mask = comp.SavedMask;
    comp.Viewer.Annotations = [];
    comp.Bbox = [];
end

% Revert to last saved state
function clearAll(comp)
    comp.Viewer.Annotations = [];
    comp.ImageObject.OverlayData = comp.SavedMask;
    comp.Bbox = [];
end
```

### App-Level Integration

Wrap the component in an App Designer app with toolstrip controls:

```matlab
function startupFcn(app)
    app.SamSegmenter = SAMSegmenter(app.WorkingAreaGrid);
end

function loadImageFromFile(app)
    [file, location] = uigetfile("*.*", "Select an image");
    if ~isequal(file, 0)
        d = uiprogressdlg(app.UIFigure, Title="Please Wait", ...
            Message="Generating SAM embeddings...", Indeterminate="on");
        imageData = imread(fullfile(location, file));
        loadImage(app.SamSegmenter, imageData);
        close(d);
    end
end

function exportMask(app)
    mask = app.SamSegmenter.Mask;
    assignin("base", "SegmentedImage", mask);
end
```

### Design Guidelines

- **Extract embeddings once** per image — show a progress dialog since it's expensive
- **Use `Viewer` with `OverlayData`** for real-time mask overlay (not `labeloverlay` + redraw)
- **Validate point positions** — discard points outside the active bounding box
- **Commit/revert pattern** — let users build up multi-label masks incrementally
- **`ComponentContainer` inheritance** — isolates segmentation logic from app layout for reusability
- Use `Viewer.Mode.Annotate` to control annotation style (point vs rectangle) and continuation

This pattern extends beyond SAM — replace the `segmentObjectsFromEmbeddings` call with any interactive segmentation method (`grabcut`, `activecontour`, `imsegfmm`, etc.) to build custom annotation apps for any interactive segmentation workflow.

## Displaying Segmentation Results

```matlab
% Direct overlay display (preferred — one step, interactive)
imageshow(I, OverlayData=BW);

% For generating an RGB array (e.g., saving to file or further processing)
rgb = labeloverlay(I, BW, Transparency=0.5);
```

## Conventions

- Always compute `superpixels` before `grabcut` or `lazysnapping`
- For prompted SAM, extract embeddings once per image — never per query
- Use `bwareafilt` or `imfill` to clean up after interactive segmentation (see `morphological-ops.md`)
- Prefer prompted SAM over grabcut/activecontour when CVT+DLT are available

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `grabcut(I, [], ROI)` without superpixels | Requires label matrix input | `[L,N] = superpixels(I,500)` then `grabcut(I,L,ROI)` |
| `extractEmbeddings` per bounding box | Embeddings are expensive | Extract once, call `segmentObjectsFromEmbeddings` multiple times |
| `activecontour` without initial mask | Requires a mask to evolve from | Threshold + dilate, or bounding rectangle |
| `regiongrowing(I, seed)` | Does not exist in IPT | Use `activecontour`, `imsegfmm`, or `grayconnected` |
| SAM coordinates in (row, col) | SAM uses (x, y) order | `ForegroundPoints=[x y]`, not `[row col]` |
| `graydiffweight(I, row, col)` or `imsegfmm(W, row, col, t)` | These take **(C, R)** order — column first, then row | `graydiffweight(I, col, row)`, `imsegfmm(W, col, row, t)` |
| `grayconnected(I, r, c, Tolerance=20)` | Tolerance is positional, not a Name-Value pair | `grayconnected(I, r, c, 20)` |
| `imseggeodesic(grayImg, ...)` | Requires RGB input; returns label matrix, not binary | `L = imseggeodesic(RGB, scribble1, scribble2)` |
| `imshow(I, OverlayData=BW)` | `imshow` does not support `OverlayData` | `imageshow(I, OverlayData=BW)` (R2024b+) |

----

Copyright 2026 The MathWorks, Inc.

----
