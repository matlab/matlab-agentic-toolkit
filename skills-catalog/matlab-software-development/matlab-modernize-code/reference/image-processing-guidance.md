
# Image Processing Modernization

## Quick Reference: Function Mappings

| Deprecated Function | Recommended Replacement | Since | Status |
|---------------------|------------------------|-------|--------|
| impoly | drawpolygon / images.roi.Polygon | R2018b | Not recommended |
| imellipse | drawellipse / images.roi.Ellipse | R2018b | Not recommended |
| imfreehand | drawfreehand / images.roi.Freehand | R2018b | Not recommended |
| imrect | drawrectangle / images.roi.Rectangle | R2018b | Not recommended |
| impoint | drawpoint / images.roi.Point | R2018b | Not recommended |
| imline | drawline / images.roi.Line | R2018b | Not recommended |
| roifill | regionfill | R2019a | Not recommended |

## ROI (Region of Interest) Tools

### Overview of ROI Modernization

Starting in **R2018b**, a new set of ROI objects replaced the existing ROI functions. The new objects provide:
- Face color transparency
- Event-based callbacks for ROI changes
- More consistent API across ROI types
- Better performance

**Although there are no plans to remove the old ROI objects at this time, switch to the new ROIs to take advantage of the additional capabilities.**

---

### impoly → drawpolygon

**Status:** Not recommended. Use `drawpolygon` or `images.roi.Polygon`.

**Old Pattern (Not Recommended):**
```matlab
% Legacy interactive polygon
imshow(img);
h = impoly(gca);
mask = createMask(h);
pos = getPosition(h);
```

**Modern Pattern (Use This):**
```matlab
% Modern interactive polygon
imshow(img);
roi = drawpolygon;
mask = createMask(roi);
pos = roi.Position;

% Programmatic creation
roi = images.roi.Polygon(gca, 'Position', [x1 y1; x2 y2; x3 y3]);

% With customization
roi = drawpolygon('Color', 'red', 'LineWidth', 2, 'FaceAlpha', 0.3);
```

**Event Handling (New Feature):**
```matlab
roi = drawpolygon;
addlistener(roi, 'MovingROI', @(src,evt) disp('Moving!'));
addlistener(roi, 'ROIMoved', @(src,evt) updateAnalysis(src));
```

---

### imellipse → drawellipse

**Status:** Not recommended. Use `drawellipse` or `images.roi.Ellipse`.

**Old Pattern (Not Recommended):**
```matlab
% Legacy ellipse
imshow(img);
h = imellipse(gca, [x y width height]);
mask = createMask(h);
```

**Modern Pattern (Use This):**
```matlab
% Modern interactive ellipse
imshow(img);
roi = drawellipse;
mask = createMask(roi);

% Programmatic creation
roi = images.roi.Ellipse(gca, 'Center', [100 100], 'SemiAxes', [50 30]);

% With rotation
roi = drawellipse('Center', [100 100], 'SemiAxes', [50 30], 'RotationAngle', 45);
```

**For Circular ROIs:**
```matlab
% Use Circle ROI instead of Ellipse for circles
roi = drawcircle('Center', [100 100], 'Radius', 50);
roi = images.roi.Circle(gca, 'Center', [100 100], 'Radius', 50);
```

---

### imfreehand → drawfreehand

**Status:** Not recommended. Use `drawfreehand` or `images.roi.Freehand`.

**Old Pattern (Not Recommended):**
```matlab
% Legacy freehand
imshow(img);
h = imfreehand(gca);
mask = createMask(h);
```

**Modern Pattern (Use This):**
```matlab
% Modern freehand drawing
imshow(img);
roi = drawfreehand;
mask = createMask(roi);

% With smoothing
roi = drawfreehand('Smoothing', 1);  % 0-1 smoothing factor

% Assisted freehand (follows edges)
roi = drawassisted;  % Snaps to image edges
```

---

### imrect → drawrectangle

**Status:** Not recommended. Use `drawrectangle` or `images.roi.Rectangle`.

**Old Pattern (Not Recommended):**
```matlab
% Legacy rectangle
imshow(img);
h = imrect(gca, [x y width height]);
pos = getPosition(h);
```

**Modern Pattern (Use This):**
```matlab
% Modern interactive rectangle
imshow(img);
roi = drawrectangle;
pos = roi.Position;  % [x y width height]

% Programmatic creation
roi = images.roi.Rectangle(gca, 'Position', [50 50 100 80]);

% With aspect ratio constraint
roi = drawrectangle('FixedAspectRatio', true, 'AspectRatio', 16/9);
```

---

### impoint → drawpoint

**Status:** Not recommended. Use `drawpoint` or `images.roi.Point`.

**Old Pattern (Not Recommended):**
```matlab
% Legacy point
imshow(img);
h = impoint(gca, x, y);
pos = getPosition(h);
```

**Modern Pattern (Use This):**
```matlab
% Modern interactive point
imshow(img);
roi = drawpoint;
pos = roi.Position;  % [x y]

% Programmatic creation
roi = images.roi.Point(gca, 'Position', [100 100]);

% Multiple points
for i = 1:5
    roi(i) = drawpoint;
end
positions = vertcat(roi.Position);
```

---

### imline → drawline

**Status:** Not recommended. Use `drawline` or `images.roi.Line`.

**Old Pattern (Not Recommended):**
```matlab
% Legacy line
imshow(img);
h = imline(gca, [x1 x2], [y1 y2]);
pos = getPosition(h);
```

**Modern Pattern (Use This):**
```matlab
% Modern interactive line
imshow(img);
roi = drawline;
pos = roi.Position;  % [x1 y1; x2 y2]

% Programmatic creation
roi = images.roi.Line(gca, 'Position', [10 10; 100 100]);

% Polyline (multiple segments)
roi = drawpolyline;
```

---

### roifill → regionfill

**Status:** Not recommended. Use `regionfill`.

**Old Pattern (Not Recommended):**
```matlab
% Legacy ROI fill
mask = roipoly(img);  % Interactive polygon selection
filled = roifill(img, mask);
```

**Modern Pattern (Use This):**
```matlab
% Modern region fill with drawpolygon
imshow(img);
roi = drawpolygon;
mask = createMask(roi);
filled = regionfill(img, mask);

% Or programmatically
mask = poly2mask(x, y, size(img,1), size(img,2));
filled = regionfill(img, mask);
```

---

## Complete ROI Migration Table

| Old Function | New Object | Convenience Function |
|--------------|------------|---------------------|
| impoly | images.roi.Polygon | drawpolygon |
| imellipse | images.roi.Ellipse | drawellipse |
| imfreehand | images.roi.Freehand | drawfreehand |
| imrect | images.roi.Rectangle | drawrectangle |
| impoint | images.roi.Point | drawpoint |
| imline | images.roi.Line | drawline |
| - | images.roi.Circle | drawcircle |
| - | images.roi.Polyline | drawpolyline |
| - | images.roi.AssistedFreehand | drawassisted |
| - | images.roi.Cuboid | drawcuboid |
| - | images.roi.Crosshair | drawcrosshair |

---

## Property Name Changes

| Old Method | New Property |
|------------|--------------|
| getPosition | Position |
| setPosition | Position |
| getColor | Color |
| setColor | Color |
| getVertices | (use Position) |
| addNewPositionCallback | MovingROI event |

---

## Working with Multiple ROIs

**Modern Pattern:**
```matlab
% Draw multiple ROIs
imshow(img);
rois = [];
for i = 1:3
    rois = [rois, drawrectangle];
end

% Get all masks
combinedMask = false(size(img, 1), size(img, 2));
for i = 1:length(rois)
    combinedMask = combinedMask | createMask(rois(i));
end

% Delete all ROIs
delete(rois);
```

---

## ROI Events (New Feature)

**The new ROI objects support events:**

```matlab
roi = drawrectangle;

% Listen for movement
addlistener(roi, 'MovingROI', @(src,evt) disp('Moving...'));
addlistener(roi, 'ROIMoved', @(src,evt) disp('Done moving'));

% Listen for clicks
addlistener(roi, 'ROIClicked', @handleClick);

function handleClick(src, evt)
    if strcmp(evt.SelectionType, 'double')
        disp('Double-clicked!');
    end
end
```

---

## Version Compatibility Notes

- **R2018b:** New ROI objects introduced (drawpolygon, drawellipse, etc.)
- **R2019a:** regionfill introduced as replacement for roifill
- **R2019b:** Additional ROI types (Cuboid, Crosshair) added

---

## Summary: Functions to Avoid

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `impoly` | `drawpolygon` | Not recommended since R2018b |
| `imellipse` | `drawellipse` | Not recommended since R2018b |
| `imfreehand` | `drawfreehand` | Not recommended since R2018b |
| `imrect` | `drawrectangle` | Not recommended since R2018b |
| `impoint` | `drawpoint` | Not recommended since R2018b |
| `imline` | `drawline` | Not recommended since R2018b |
| `roifill` | `regionfill` | Not recommended since R2019a |


----

Copyright 2026 The MathWorks, Inc.

----

