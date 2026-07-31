---
name: matlab-normalize-image
description: >
  Normalize images to [0,1] using im2double with proper validation and edge-case
  detection. Use when reading images with imread and converting to double for
  processing, displaying images with imshow, normalizing for ML training,
  brightening/adjusting pixel values, or any imread→process→imwrite workflow.
  Triggers on: im2double, normalize image, convert to double, imshow displays
  white, image appears all white, image appears all black, read and process images,
  batch normalize, brighten image, pixel value scaling.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
matlab-release: ">=R2021a"
metadata:
  author: MathWorks
  version: "1.0"
---

# Image Normalization and Type Conversion

Detect and prevent unexpected normalization results when converting images to [0,1]
using base MATLAB image I/O functions.

## When to Use

- Reading images with `imread` and converting to double for processing
- Normalizing images to [0,1] for ML training or batch processing
- Displaying images with `imshow` (especially if result is all-white)
- Any `imread` → process → `imwrite` workflow involving type conversion
- Brightening, scaling, or adjusting pixel values arithmetically

## When NOT to Use

- Pure format conversion (e.g., TIFF to PNG without processing) — no normalization needed
- Deep learning `imageDatastore` with `ReadFcn` — handles normalization internally
- Simulink image processing blocks — different pipeline
- Color space conversion (RGB↔HSV↔Lab) — separate domain
- Image Processing Toolbox algorithm workflows (filtering, segmentation, morphology)

## Workflow

Follow this pipeline for every image normalization task:

### Step 1: Inspect metadata with `imfinfo`

Before reading, check what you're dealing with:

```matlab
info = imfinfo(filePath);
fprintf('ColorType: %s, BitDepth: %d, Class will be: ', info.ColorType, info.BitDepth);
```

**What to look for:**

| `info.ColorType` | Action |
|-----------------|--------|
| `'indexed'` | Use `[X, cmap] = imread(f)` then `ind2rgb(X, cmap)` (core MATLAB) — single-output `imread` returns indices, not pixel colors |
| `'truecolor'` | Standard RGB — proceed normally |
| `'grayscale'` | Single channel — proceed normally |

| `info.BitDepth` per channel | Action |
|----------------------------|--------|
| 8 | Standard uint8, `im2double` divides by 255 |
| 16 | Standard uint16, `im2double` divides by 65535 |
| 12, 10, 14 | Bit-depth mismatch — data stored in uint16 container. `im2double` divides by 65535 but actual max is 2^BitDepth-1. Correct with `double(img) / (2^BitDepth - 1)`. |
| 32, 64 | Likely float-class — `im2double` will be a no-op. Use `rescale` after reading. |

### Step 2: Read and normalize

```matlab
img = imread(filePath);
imgNorm = im2double(img);
```

### Step 3: Validate and correct

**Always check the result immediately after `im2double` — if correction is needed, apply it and explain to the user why:**

```matlab
maxVal = max(imgNorm(:));
minVal = min(imgNorm(:));

if maxVal > 1.0
    imgNorm = rescale(imgNorm, 0, 1);
end

if maxVal < 0.1
    info = imfinfo(filePath);
    bitsPerChannel = info.BitDepth / size(imgNorm, 3);
    if bitsPerChannel < 16
        imgNorm = double(img) / (2^bitsPerChannel - 1);
    end
end
```

**This single validation step catches the majority of failures.** If `im2double` produced values outside [0,1] (float-class no-op) or in a narrow sub-range (bit-depth mismatch), apply the correct normalization and report to the user which alternative path was taken and why.

### Step 4: Process (if applicable)

For relative operations (brighten, contrast), work in [0,1] domain:

```matlab
processed = imgNorm * factor;
processed = min(max(processed, 0), 1);  % Explicit clamp
```

For absolute operations (subtract background count), stay in native domain:

```matlab
img = imread(filePath);
result = double(img) - backgroundValue;
result = max(result, 0);  % Prevent underflow
```

**Domain choice rule:**
- Relative adjustment (%, ratio) → normalized [0,1]
- Absolute value (raw counts, dark frame subtraction) → native domain

### Step 5: Display correctly

```matlab
if isfloat(imgNorm) && max(imgNorm(:)) > 1.0
    imshow(rescale(imgNorm, 0, 1));  % Normalize for display (RGB and grayscale)
else
    imshow(imgNorm);                 % Standard display for data in [0,1]
end
```

`imshow` expects double images in [0,1]. Values > 1.0 clip to white — the entire image appears white. Note: `imshow(img, [])` only auto-scales **grayscale** images; for RGB float data it is silently ignored. Use `rescale` before display instead.

### Step 6: Convert and write

For writing to integer formats (JPEG requires uint8, TIFF supports uint16):

```matlab
if max(imgNorm(:)) > 1.0
    imgNorm = rescale(imgNorm, 0, 1);  % Ensure [0,1] before conversion
end
% With IPT: output = im2uint8(imgNorm);
% Without IPT: output = uint8(round(imgNorm * 255));
imwrite(imgNorm, outputPath);  % Some formats accept double [0,1] directly (PNG, TIFF)
```

## Key Functions

| Function | Purpose | Source | Behavior on float input |
|----------|---------|--------|------------------------|
| `im2double` | Convert to double [0,1] | Core MATLAB | **No-op on double/single** — passes values through unchanged |
| `imfinfo` | Read image metadata | Core MATLAB | Returns BitDepth, ColorType, size |
| `imread` | Read image data | Core MATLAB | Returns uint8, uint16, or double depending on file |
| `imwrite` | Write image data | Core MATLAB | Format-specific class requirements |
| `imshow` | Display image | Core MATLAB | Expects double in [0,1]; clips values > 1 to white. `[]` auto-range works only for grayscale, not RGB. |

## Common Mistakes

| Mistake | Why It's Wrong | What To Do |
|---------|---------------|------------|
| `im2double(img)` on float-class image without validation | `im2double` is a no-op on double/single inputs — values pass through unchanged (e.g., [0, 946] stays [0, 946]) | Check `max(result(:)) <= 1.0` after calling. If violated, apply `rescale(img, 0, 1)`. |
| Bare `imshow(img)` on float data with values > 1 | `imshow` clips double values > 1.0 to white — entire image appears white | Use `imshow(rescale(img, 0, 1))` for correct display. Note: `imshow(img, [])` only works for grayscale — it is silently ignored for RGB. |
| Hardcoded `double(img) / 255` | Only works for uint8. Breaks silently on uint16 (divides by 255 instead of 65535) | Use `im2double(img)` — it handles class dispatch automatically |
| Reporting mean=240.9 as "normalized" | If mean exceeds 1.0, the data is NOT normalized — `im2double` was a no-op | Always validate range before reporting or using results |
| Normalizing AFTER processing | `img * 1.2` then `/ max(img(:))` undoes the scaling — brighten has no visible effect | Normalize FIRST, then process, then validate |
| `double(img) / double(intmax(class(img)))` | Reinvents `im2double` but breaks on float input — `intmax('double')` = 1.8e308 | Use `im2double` for integer classes. It exists for this purpose. |
| Not checking `imfinfo` before `imread` | Indexed images return colormap indices, not pixel values. Alpha channels are silently lost with single-output `imread`. | Call `imfinfo` first. Check `ColorType` and `BitDepth`. |
| 12-bit image appears near-black after `im2double` | `im2double` divides uint16 by 65535 (container max), but 12-bit data only reaches 4095. Result max = 0.0625. | Detect via `imfinfo` BitDepth. Apply `double(img) / (2^bitsPerChannel - 1)` for full-range normalization. |

## Patterns

### Float-class detection and correction

When `im2double` produces values > 1.0, apply correct normalization and inform the user:

```matlab
img = imread(filePath);
imgNorm = im2double(img);

if max(imgNorm(:)) > 1.0
    % im2double is a no-op on float-class inputs — apply rescale instead
    imgNorm = rescale(imgNorm, 0, 1);
end
```

Alternative normalization approaches:
- `rescale(img, 0, 1)` — core MATLAB (R2017b+, no toolbox needed)
- `mat2gray(img)` — requires Image Processing Toolbox
- `img / max(img(:))` — manual scaling to [0,1]

### Bit-depth mismatch detection and correction

When 12-bit data in a 16-bit container produces near-black normalized results, correct and inform the user:

```matlab
info = imfinfo(filePath);
img = imread(filePath);
imgNorm = im2double(img);
bitsPerChannel = info.BitDepth / size(img, 3);

if bitsPerChannel < 16 && isa(img, 'uint16')
    % im2double divided by 65535 but actual range is 2^bitsPerChannel - 1
    imgNorm = double(img) / (2^bitsPerChannel - 1);
end
```

### Correct display for any image class

```matlab
img = imread(filePath);
if isfloat(img) && max(img(:)) > 1.0
    imshow(rescale(img, 0, 1));
    title(sprintf('%s — rescaled [%.0f, %.0f]', fileName, min(img(:)), max(img(:))));
else
    imgDisp = im2double(img);
    imshow(imgDisp);
    title(fileName);
end
```

## Conventions

- **Always validate after `im2double`** — check `max(result(:)) <= 1.0` and if violated, correct and explain to the user why an alternative path was taken
- **Always call `imfinfo` first** when processing unknown or mixed-format images
- **Never use bare `double(img)`** for normalization — it preserves raw values without scaling
- **Use `imshow(rescale(img, 0, 1))` for float data** with values outside [0,1] — `imshow(img, [])` only works for grayscale, not RGB
- **Normalize BEFORE processing** — never scale to [0,1] after arithmetic (it undoes the operation)
- **Detect, correct, and report** — when normalization fails, apply the right fix (rescale, bit-depth correction, ind2rgb) and explain to the user what was detected and which correction was applied
- **Domain choice matters** — relative operations (brighten by %) use normalized [0,1]; absolute operations (subtract 100 counts) stay in native domain

## Troubleshooting

| Step | Error | Recovery |
|------|-------|----------|
| `imfinfo` | `"Unable to determine file format from filename."` — file has wrong or missing extension | Retry with explicit format argument: `imfinfo(f, 'tif')`. If still fails, report to the user: "The file format could not be determined. Verify the file extension matches the actual format, or run `imformats` to see the list of supported formats. The file cannot be processed." Skip the file. |
| `imfinfo` / `imread` | `"Could not read IFD ... the file may be corrupt."` or `"Unable to open file"` | File is corrupt or inaccessible. Report to the user: "The file appears corrupt or incomplete — pixel data cannot be recovered. Verify file integrity (check file size, re-download if from a remote source, or inspect with a hex editor)." Skip file, log path, continue batch processing. |
| `imfinfo` / `imread` | `"Can't read URL ... Location must have read access and be opened through a working network connection."` | Remote URL is unreachable or access is denied. Download the file locally first using `websave(localPath, url)`, then pass the local path to `imfinfo`/`imread`. |
| `imread` | Warning: `"Corrupt JPEG data: bad Huffman code"` — `imread` succeeds but data may be partially invalid | Check `lastwarn` after `imread`. Report the warning to the user: the image was read but may contain visual artifacts from corrupt regions. Proceed with normalization but flag the result as potentially unreliable. |
| `imfinfo` | `ColorType` returns unexpected value (e.g., `-1`) due to missing TIFF tags | Metadata is incomplete. Do not use the ColorType lookup table. Fall back to class-based normalization: use `class(img)` and `max(img(:))` to infer correct scaling. Report to the user that the file has missing metadata tags and caveat the result as potentially unreliable — MATLAB may have guessed the pixel interpretation incorrectly without the required tag. |
| `imread` | Returns valid array but `imfinfo` BitDepth or ColorType fields are missing | Metadata is incomplete. Fall back to class-based normalization: use `class(img)` and `max(img(:))` to infer correct scaling instead of relying on BitDepth. |
| `im2double` → validate | `max == min` (constant-value image) — `rescale` produces all zeros | Normalization is undefined for constant data — `(x - min) / (max - min)` divides by zero. Report to the user: `"Warning: Image has uniform intensity (all pixels = <value>). Normalization to [0,1] is undefined for constant data. The result will be all zeros."` Explain that a meaningful [0,1] range requires at least two distinct pixel values. |
| `im2double` → validate | Bit-depth correction still produces values outside [0,1] | `imfinfo` BitDepth does not match actual data range (metadata mismatch). Fall back to `rescale(img, 0, 1)` which uses observed min/max regardless of metadata. |

## References

See `references/normalization-decision-tree.md` for the complete decision tree covering all edge cases — consult when handling mixed-format batches, indexed images, or images with alpha channels.

----

Copyright 2026 The MathWorks, Inc.

----
