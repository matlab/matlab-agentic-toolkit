# Interactive Painting and Labeling

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

----

Copyright 2026 The MathWorks, Inc.

----
