# Automated Image Segmentation

Decision guidance for segmentation methods that require no user interaction — thresholding, clustering, watershed, automatic SAM, and deep learning pipelines.

> **Often loaded with:** `morphological-ops.md` (cleaning up masks), `analysis-measurement.md` (measuring segmented regions), `segmentation-interactive.md` (when automatic methods fail and user input is available).

## Method Selection

| Image type | Task | Constraints | Algorithm |
|-----------|------|-------------|-----------|
| 2-D gray | Binary, high contrast | Automatic | `imbinarize` (global) |
| 2-D gray | Binary, uneven lighting | Automatic | `imbinarize("adaptive")` |
| 2-D gray/color | Multi-level threshold | Automatic | `multithresh` + `imquantize` |
| 2-D gray/color | Multi-region, known K | Automatic | `imsegkmeans` |
| 2-D gray/color | Multi-region, unknown K | Automatic | `imsegisodata` (R2024b+) |
| 2-D/3-D | Splitting touching convex objects (cells, particles) | Have binary mask | Marker-controlled watershed |
| 2-D | Complex scene, zero-shot | No training data | `imsegsam` **(CVT+DLT)** (R2024b+) |
| 2-D/3-D | Pixel-level classes | Have labeled data | `semanticseg` pipeline **(CVT+DLT)** |
| 2-D | Instance (per-object masks) | Have labeled data | `maskrcnn` **(CVT+DLT)** |
| 3-D volume | Multi-region | Automatic | `imsegkmeans3` |

**When uncertain:** prefer simpler method first; escalate if it fails.

## Thresholding

### Global

```matlab
BW = imbinarize(I);           % Otsu's method (default)
BW = imbinarize(I, 0.45);    % Manual threshold
```

### Adaptive (Uneven Illumination)

```matlab
BW = imbinarize(I, "adaptive", Sensitivity=0.4);
```

### Multi-Level

```matlab
thresh = multithresh(I, 3);       % 3 thresholds → 4 regions
L = imquantize(I, thresh);
```

## Marker-Controlled Watershed — Critical Pattern

**When to use:** Splitting touching/overlapping convex objects where you already have a clean binary mask (cells, particles, grains). This is the one scenario where watershed excels over modern alternatives.

**When NOT to use:** For general scene segmentation, use SAM (`imsegsam`) or clustering. Superpixels over-segment uniformly (don't solve the "split touching blobs" problem).

**Never apply `watershed` directly to a gradient.** Raw watershed produces thousands of regions. Always use marker-controlled approach:

```matlab
% 1. Create binary mask
BW = imbinarize(I);
BW = imfill(BW, "holes");

% 2. Distance transform (peaks at object centers)
D = -bwdist(~BW);

% 3. Suppress shallow minima (CRITICAL — prevents over-segmentation)
D = imhmin(D, 2);  % h=2: higher → fewer regions

% 4. Watershed
L = watershed(D);
L(~BW) = 0;  % Remove background label
```

**Tuning `h` in `imhmin`:** too small = over-segmented, too large = objects merged. Start at 2, increase until object count looks right.

### Alternative: Gradient-Based with `imimposemin`

When you don't have a clean binary mask:

```matlab
gmag = imgradient(im2double(I));
markers = imextendedmin(imcomplement(im2double(I)), 0.1);
gmag2 = imimposemin(gmag, markers);
L = watershed(gmag2);
L(L == 0) = 1;  % Merge watershed ridge lines into nearest region
```

## Clustering — `imsegkmeans` vs `imsegisodata`

```matlab
% Known number of regions (grayscale uint8 input works directly)
L = imsegkmeans(I, 4);

% Multichannel input — double must be converted to single; uint8/uint16/int16 work directly
L = imsegkmeans(single(I), 4);  % Use when I is double or single

% Unknown number of regions (auto-determines K)
[L, centers] = imsegisodata(I);  % R2024b+
```

**Color images:** For color-based segmentation, convert to L\*a\*b\* before clustering — do not cluster in RGB:

```matlab
lab = rgb2lab(I);
L = imsegkmeans(single(lab), 4);
```

**With texture features** (Gabor filter bank):

```matlab
gBank = gabor(2.^(2:5), 0:45:135);
features = cat(3, single(I), single(imgaborfilt(im2gray(I), gBank)));
L = imsegkmeans(features, 5);
```

## SAM — Automatic Zero-Shot Segmentation (R2024b+)

Requires IPT Model for Segment Anything Model support package. Check availability:

```matlab
try
    sam = segmentAnythingModel;  % Verifies support package AND Python environment
    hasSAM = true;
catch
    hasSAM = false;  % Help the user install the support package or fix the Python environment
end
```

> **Do not use `which` alone** — it returns true even when the Python environment is broken. Attempt construction to confirm usability.

```matlab
[cc, scores] = imsegsam(I, MinObjectArea=500, ScoreThreshold=0.7);
% cc is a connected component struct (like bwconncomp output)
% cc.NumObjects, cc.PixelIdxList — use labelmatrix(cc) for a label map
```

**Fallback** when SAM unavailable: `imsegisodata` for multi-region or `imsegkmeans` if K is known.

`imsegsam` is automatic only (no prompts). For point/box-prompted segmentation, see `segmentAnythingModel` in `segmentation-interactive.md`.

## Deep Learning Segmentation

For pixel-level classification with labeled training data, see `deep-learning-imaging.md` for the full pipeline. Quick inference pattern:

```matlab
result = semanticseg(testImage, net);  % Returns categorical label map
```

## Preprocessing for Segmentation

| Problem | Fix | Function |
|---------|-----|----------|
| Noise | Smooth first | `imgaussfilt`, `medfilt2` |
| Low contrast | Enhance | `imadjust`, `adapthisteq` |
| Uneven illumination | Flatten background | `imtophat` or `imflatfield` |
| Color → cluster | Convert to L\*a\*b\* | `rgb2lab` then `imsegkmeans` on Lab channels |

### Adaptive Thresholding with Masked Regions

`imbinarize(I, "adaptive")` calls `adaptthresh` internally. When you need to modify the threshold map before binarizing, compute it explicitly with `adaptthresh` + `imbinarize(A, T)` instead.

When parts of the image are zeroed out (e.g., background outside a brain, removed ROI), `adaptthresh` uses those zeros in local neighborhood calculations, corrupting thresholds near the mask boundary. Setting masked pixels to NaN also fails (produces black blocks).

**Fix: post-process the threshold map** — let `adaptthresh` run, then interpolate over the affected region:

```matlab
T = adaptthresh(A, "NeighborhoodSize", M);
B2 = imdilate(mask, ones(M, M));  % Expand mask by neighborhood size
T2 = regionfill(T, B2);           % Interpolate threshold values from surroundings
BW = imbinarize(A, T2);
```

This works because `regionfill` smoothly fills in threshold values from the unaffected boundary — the actual image zeros never influence the final threshold in the masked region.

## Displaying Segmentation Results

```matlab
% Direct overlay display (preferred — one step, interactive)
imageshow(gray, OverlayData=L);

% For generating an RGB array (e.g., saving to file or further processing)
rgb = labeloverlay(gray, L, Transparency=0.5);
```

`imageshow` with `OverlayData` is the modern approach — it renders the overlay interactively and supports clicking to inspect label values. Use `labeloverlay` only when you need an RGB array (e.g., for `imwrite` or compositing).

## Conventions

- Always use `imbinarize` — never `im2bw` (not recommended) or manual `graythresh` + threshold
- For watershed, always suppress minima — never `watershed(imgradient(I))` directly
- For color segmentation, convert to L\*a\*b\* before clustering
- Prefer `imsegisodata` over manual ISODATA when cluster count is unknown
- Use `bwareafilt` or `imfill(BW, "holes")` to clean up after thresholding (see `morphological-ops.md`) — `imfill(BW)` without `"holes"` is interactive (opens a figure for seed point selection), not automatic

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `watershed(imgradient(I))` | Severe over-segmentation (thousands of regions) | Marker-controlled: `imhmin` or `imimposemin` first |
| `im2bw(I, level)` | Not recommended since R2016a | `imbinarize(I)` or `imbinarize(I, level)` |
| Clustering in RGB space | RGB not perceptually uniform | Convert to L\*a\*b\*: `imsegkmeans(single(rgb2lab(I)), K)` |
| `segnet` or `fcnLayers` | Do not exist in current releases | Use `deeplabv3plus` or `unet` (see `deep-learning-imaging.md`) |
| `imshow(I, OverlayData=L)` | `imshow` does not support `OverlayData` | `imageshow(I, OverlayData=L)` (R2024b+) |

----

Copyright 2026 The MathWorks, Inc.

----
