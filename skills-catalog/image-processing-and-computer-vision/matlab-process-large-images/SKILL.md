---
name: matlab-process-large-images
description: "Patterns for using blockedImage to process large images, harness parallel compute for image processing, and write custom adapters. Use when writing code that creates, processes, or visualizes blockedImage objects, when implementing images.blocked.Adapter subclasses, or when a user needs help with large image data. Always use this skill when working with TIFF,GeoTIFF, .svs, .ndpi, .czi or other WSI, satellite imagery or microscopy volume image formats."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

## When to Use
- Writing code that creates, processes, or visualizes `blockedImage` objects
- Implementing `images.blocked.Adapter` subclasses for custom file formats
- User needs help with large image data that doesn't fit in memory
- User wants to leverage parallel computing for image processing tasks
- Working with whole-slide images, geospatial rasters, 3D microscopy volumes, or tiled mosaics
- **Any time a user is working with a TIFF file** — load this skill and check the file first with `imfinfo`. Use `blockedImage` if the file is large (dimensions > 10,000 pixels in any axis), has multiple channels beyond RGB, or contains multiple IFDs (could be pyramid levels, time series, or Z-stack slices)

## When NOT to Use
- Image fits comfortably in memory and no parallel processing is needed — use standard `imread`/`imwrite` workflows
- General image display without `blockedImage` — use the `matlab-display-image` skill instead
- Deep learning model architecture or training loop design — this skill covers data preparation with `blockedImageDatastore`, not network design

# Large Image Processing with blockedImage

**Reference files** (read on demand when the topic comes up):
- `references/visualization.md` — imageshow, overlays, synced views, overview+detail, annotations
- `references/training-and-labeling.md` — Image Labeler, labeled blockedImages, training datastores, DL inference
- `references/3d-volumes.md` — 3D blocked images, 3D inference, 3D training data
- `references/geospatial.md` — GeoTIFF, shapefiles, coordinate systems, spatial referencing
- `references/data-discovery.md` — 7-step data discovery workflow, custom adapters, format conversion adapter selection, virtual composite adapters, adapter performance tips
- `references/specialized-workflows.md` — writing block-by-block, coordinate systems, mask-based block selection, ExtraImages for pixel-level masking, in-place resume
- `references/whole-slide-images.md` — importing WSI files via OpenSlide/Bio-Formats, choosing between libraries, display, downstream processing (segmentation, classification)

## When to use blockedImage
blockedImage is not only for data that exceeds RAM. Even when the data fits in memory, wrapping it as a blockedImage lets you harness a parallel cluster: each worker can independently read and write different blocks, enabling parallel partial reads and parallel writes into separate file blocks.

**Always ask the user what their intent with the data is.** Ask about visualization, processing, DL training, archival, and whether they want to leverage parallel compute — even if the data fits in RAM.

## When the user points you at a directory or multi-file dataset
**ALWAYS read `references/data-discovery.md` and follow its 7-step workflow** before writing any code. The workflow covers: inspecting file layout, parsing naming conventions, understanding user intent, choosing between single blockedImage vs. collection, assessing random access capabilities, checking for gaps/overlaps, and recommending an approach (built-in adapter, format conversion, or custom adapter).

## Construction
```matlab
% Read-only (auto-selects adapter; reads only metadata, fast)
bim = blockedImage("large_image.tif");

% Multiple images at once
[bim1, bim2] = blockedImage(["img1.tif", "img2.tif"]);

% Writable
bim = blockedImage(dest, imageSize, blockSize, initVal, Mode="w");

% Override adapter
bim = blockedImage(source, Adapter=myAdapter);
```

## BlockSize
- Defaults to a factor of `IOBlockSize` (adapter's native read unit), targeting ~1024 or the minimum dimension size.
- The object's `BlockSize` is the default for all downstream processing and visualization.
- Override per-operation via the `BlockSize` name-value argument (e.g., when a DL network requires a fixed input size).
- For best performance, keep `BlockSize` as a multiple of `IOBlockSize` and as large as practical.

## Reading Data
- `getBlock(bim, blocksub)` — read one block by block subscript. Returns `[data, blockinfo]`.
- `getRegion(bim, pixelStart, pixelEnd)` — read an arbitrary pixel region.
- `gather(bim)` — load entire image into memory (only if it fits in RAM). Use `Level` to select resolution.

## Processing with `apply()`
`apply(bim, @fcn)` calls `fcn` on each block one at a time. Scales to arbitrarily large data. Supports `UseParallel=true` for cluster execution.

Key name-value arguments: `BlockSize`, `BorderSize`, `Level`, `ExtraImages`, `PadPartialBlocks`, `PadMethod`, `OutputLocation`, `BatchSize`, `Resume`, `BlockLocationSet`, `DisplayWaitbar`.

### Block struct (`bs`) fields
The user function receives a block struct `bs` with:
- `bs.Data` — pixel data for this block (includes border if `BorderSize` > 0)
- `bs.Start` — 1-by-N pixel subscript of the block's top-left corner (excluding border)
- `bs.End` — 1-by-N pixel subscript of the block's bottom-right corner (excluding border)
- `bs.BorderSize` — 1-by-N border size used
- `bs.Level` — resolution level
- `bs.BlockSub` — block subscript (index into `SizeInBlocks`)
- `bs.ImageNumber` — index of the source image (when processing an array)

### Struct / non-image output
When the output per block is not image data (e.g., detection results, counts), use `images.blocked.MATBlocks` adapter to store structs:
```matlab
bResults = apply(bim, @countNuclei, ...
    BlockLocationSet=bls, BorderSize=[r r], ...
    Adapter=images.blocked.MATBlocks, OutputLocation="results_dir");
allResults = gather(bResults);  % load all structs into memory
```

### Limit work to real data
- **Crop first.** `crop(bim, cstart, cend)` is virtual — no data copy, executes instantly. Use to restrict to a spatial ROI or single channel before processing.
- **Use masks with `selectBlockLocations`.** Build a mask from a coarse level, then process only blocks overlapping the ROI. See `references/specialized-workflows.md` for the full pattern including `InclusionThreshold` and block-size tuning.

### Key patterns
- **Single pass.** Perform all pre/post-processing inside `fcn` to go through data only once.
- **World coordinates.** `fcn` receives block metadata. Use `sub2world()` to convert block-local positions to world coordinates before returning detection results.
- **BorderSize for overlap.** Set `BorderSize` when the processing function needs context from neighboring blocks (e.g., DL network with wider input than output field of view).
- **Unique detections via centroids.** Set `BorderSize` >= half the max object diameter. In the user function, discard detections whose centroid falls in the border region, then convert remaining centroids to global coordinates using `bs.Start`:
  ```matlab
  onBorder = centroids(:,1) < bs.BorderSize(1) ...
           | centroids(:,1) > size(bs.Data,1) - 2*bs.BorderSize(1) ...
           | centroids(:,2) < bs.BorderSize(2) ...
           | centroids(:,2) > size(bs.Data,2) - 2*bs.BorderSize(2);
  centroids(onBorder,:) = [];
  centroids = centroids + bs.Start(1:2);  % local -> global
  ```
  For inconsistent detectors, add a second `apply()` pass with `BorderSize=BlockSize` to deduplicate by bounding-box overlap in global coordinates.
- **Multi-resolution output.** Use `makeMultiLevel2D(bResult, Scales=[1 0.5 0.3 0.1])` to generate a pyramid from a single-level result. Use `"nearest"` interpolation for label/mask data. Or return multiple levels from `fcn` and combine with `concatenateLevels`.
- **Small block output.** When per-block output is tiny (e.g., a count), use `gather()` to load all results into memory, or `write()` to rewrite with a larger block size.
- **Resume.** Set `Resume=true` to continue a previously interrupted `apply()` from where it left off. For in-place resume with overwrite, see `references/specialized-workflows.md`.
- **Multi-output apply.** When the processing function returns N outputs, `apply` returns N separate blockedImages. Use this to split channels in a single pass:
  ```matlab
  [o1, o2, o3, o4] = apply(bim, @(bs) splitChannels(bs), ...
      BlockSize=[10 2048 2048 4], UseParallel=true, OutputLocation=outDir);
  ```
- **ExtraImages for pixel-level masking.** Pass a second blockedImage via `ExtraImages` to access it in the block function alongside the primary image. See `references/specialized-workflows.md` for the full pattern including resolution mismatch handling.
- **Pyramidal TIFF in one pass.** Generate multi-resolution levels and write as a single pyramidal TIFF using `LevelImages`:
  ```matlab
  [b1,b2,b3,b4] = apply(bim, @resizeBlocks);
  write(bim, "pyramid.tif", LevelImages=[b1 b2 b3 b4], BlockSize=[2048 2048]);
  function [b1,b2,b3,b4] = resizeBlocks(bs)
      b1 = imresize(bs.Data, 0.5, 'nearest');
      b2 = imresize(b1, 0.5, 'nearest');
      b3 = imresize(b2, 0.5, 'nearest');
      b4 = imresize(b3, 0.5, 'nearest');
  end
  ```
- **BatchSize.** Process multiple blocks at once by setting `BatchSize=N`. The block function receives `bs.Data` with an extra trailing dimension of size N and `bs.BatchSize` indicating the count. Useful when per-block overhead is high.

### Iterative development workflow
Processing full-resolution blocked images is slow. Shorten the feedback cycle by prototyping on smaller data first:

1. **Prototype on a coarse level.** Use `gather(bim, Level=bim.NumLevels)` to load the coarsest level into memory. Develop and tune parameters on this small image, then apply to the full image:
   ```matlab
   imCoarse = gather(bim, Level=bim.NumLevels);
   thresh = graythresh(im2gray(imCoarse));
   bResult = apply(bim, @(bs) ~imbinarize(im2gray(bs.Data), thresh));
   ```
2. **Prototype on an ROI.** Extract a small region with representative features using `getRegion`, tune parameters, then apply:
   ```matlab
   roi = getRegion(bim, [900 2400], [1700 3300], Level=1);
   thresh = graythresh(im2gray(roi));
   bResult = apply(bim, @(bs) ~imbinarize(im2gray(bs.Data), thresh));
   ```

### Parallel processing
When writing results to disk, check for Parallel Computing Toolbox and use it if available:
```matlab
outDir = tempname;
usepar = ~isempty(ver("parallel"));
bResult = apply(bim, @fcn, UseParallel=usepar, OutputLocation=outDir);
```
Always include `UseParallel` when specifying `OutputLocation` — set it based on toolbox availability.

## Visualization
**Choose 2D vs 3D based on the data, not convenience:**
- **3D volumes (Z-stacks, CT, MRI, microscopy stacks):** Default to `volshow` + `viewer3d`. Use `OverlayData` for multi-channel overlay, `SlicePlanes` for interactive browsing, and `linkviewers` for overview+detail. Read `references/3d-volumes.md` for full patterns. Do NOT flatten 3D data into 2D slice-by-slice viewers — that discards spatial context and ignores the 3D tooling.
- **2D images (whole-slide, satellite, mosaics):** Use `imageshow` + `viewer2d`. Read `references/visualization.md` for overlays, synced views, overview+detail, and annotations.

If the data has a Z/depth/slice dimension, it is 3D — use the 3D path even if each slice is a separate file.

## Format Conversion
Use `write(bim, destination)` to convert between formats or re-chunk data:
```matlab
write(bim, "output.tif", BlockSize=[512 512 3]);
```
For adapter selection guidance when converting (JPEG vs PNG vs H5Blocks), see "Adapter Preference for Format Conversion" in `references/data-discovery.md`.

----

Copyright 2026 The MathWorks, Inc.
