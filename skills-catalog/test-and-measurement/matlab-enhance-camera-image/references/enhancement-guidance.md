# Enhancement Guidance — IPT Functions, Parameters, and Pipelines

## Pipeline Ordering Rules

Apply post-processing in this order. Violating the order degrades results:

1. **Brighten** — lift shadows and correct exposure
2. **Contrast** — enhance local/global contrast
3. **Sharpen** — enhance edges (last, because it amplifies noise)
4. **Denoise** — only if noise is still problematic after other steps; apply before sharpening if noise is severe

Why this order matters:
- Sharpening amplifies whatever is in the image — apply after denoising
- Contrast enhancement on a dark image exaggerates noise in shadows — brighten first
- Denoising after sharpening blurs the edges you just enhanced

## Function Reference

### Brightening / Exposure Correction

#### `imlocalbrighten`
```matlab
out = imlocalbrighten(img);
out = imlocalbrighten(img, amount);
```
- **amount**: 0–1 (default 1.0). Use 0.5–0.9 for moderate to strong brightening
- Only lifts dark regions; preserves already-bright areas
- Preferred for backlit scenes over global brightness increase
- Input: uint8/uint16/single RGB or grayscale
- Does not require conversion

#### Gamma Correction (manual)
```matlab
out = imadjust(img, [], [], gamma);
```
- **gamma < 1**: brightens (e.g., 0.6–0.8 for moderate brightening)
- **gamma > 1**: darkens
- Alternative: `img .^ gamma` on double/single images

#### `imadjust`
```matlab
out = imadjust(img);                          % Auto stretch to [0, 1]
out = imadjust(img, [low_in high_in], [low_out high_out]);
```
- Stretches intensity range linearly
- For overexposed images: `imadjust(img, [], [0 0.8])` compresses output range
- Operates per-channel on RGB (may shift color balance)

#### Inverted `imreducehaze` (shadow lifting)
```matlab
out = imreducehaze(imcomplement(img));
out = imcomplement(out);
```
- Treating shadows as "haze in the inverted image" lifts dark regions
- Useful when `imlocalbrighten` is too aggressive

### Contrast Enhancement

#### `locallapfilt` (Local Laplacian Filter)
```matlab
out = locallapfilt(img, sigma, alpha);
```
- **sigma**: edge threshold (0.1–0.5). Lower = only enhance fine details
- **alpha**: enhancement amount. >1 enhances, <1 smooths
- Recommended: sigma=0.2–0.4, alpha=1.2–2.0 for moderate enhancement
- Input: uint8/uint16/single/double
- Excellent for natural-looking local contrast without halos

#### `adapthisteq` (CLAHE)
```matlab
out = adapthisteq(grayImg);
out = adapthisteq(grayImg, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
```
- **CRITICAL**: Operates on single-channel images only
- For RGB: convert to Lab, apply to L channel, convert back:
  ```matlab
  lab = rgb2lab(img);
  lab(:,:,1) = adapthisteq(uint8(lab(:,:,1) * 255 / 100)) * 100 / 255;
  out = lab2rgb(lab, 'OutputType', 'uint8');
  ```
- **ClipLimit**: 0.01–0.05 (lower = less enhancement, fewer artifacts)
- **NumTiles**: [8 8] default; larger tiles = more global effect

#### `localtonemap`
```matlab
out = localtonemap(imgSingle);
```
- **CRITICAL**: Requires `single` input — always convert with `im2single()` first
- Designed for HDR images but works on standard images for extreme contrast recovery
- May produce unnatural results on well-exposed images

### Sharpening

#### `imsharpen`
```matlab
out = imsharpen(img);
out = imsharpen(img, 'Radius', R, 'Amount', A);
```
- **Radius**: 1–3 (size of blur kernel; larger = coarser sharpening)
- **Amount**: 0.5–2.0 (strength; >2 risks halos)
- **Threshold**: 0–1 (skip sharpening for low-contrast edges to avoid noise amplification)
- Recommended starting point: Radius=1.5, Amount=1.0, Threshold=0.1
- Limited help for out-of-focus images — cannot recover lost information

#### `deconvwnr` / `deconvlucy` (deconvolution)
```matlab
out = deconvwnr(img, psf, nsr);
out = deconvlucy(img, psf, numIterations);
```
- Requires estimating the PSF (point spread function)
- For motion blur: `psf = fspecial('motion', len, angle)`
- For defocus: `psf = fspecial('disk', radius)`
- Aggressive — can introduce ringing artifacts. Use conservatively.

### Noise Reduction

#### `imgaussfilt`
```matlab
out = imgaussfilt(img, sigma);
```
- **sigma**: 0.5–2.0 (higher = more smoothing, more detail loss)
- Fast and simple; good for light noise
- Blurs edges — prefer `imnlmfilt` for better edge preservation

#### `imnlmfilt` (Non-Local Means)
```matlab
out = imnlmfilt(img);
out = imnlmfilt(img, 'DegreeOfSmoothing', dos);
```
- **DegreeOfSmoothing**: auto-estimated if omitted; override for control
- Preserves edges better than Gaussian; slower
- Good default for moderate noise

#### `wiener2`
```matlab
out = wiener2(grayImg, [m n]);
```
- **[m n]**: neighborhood size (default [3 3]; try [5 5] for stronger denoising)
- Grayscale only — apply per-channel for RGB
- Adaptive — adjusts based on local variance

### Color Correction

#### Manual White Point Correction
```matlab
imgDouble = im2double(img);
rScale = targetGray / mean(imgDouble(:,:,1), "all");
gScale = targetGray / mean(imgDouble(:,:,2), "all");
bScale = targetGray / mean(imgDouble(:,:,3), "all");
out = imgDouble .* cat(3, rScale, gScale, bScale);
out = im2uint8(min(out, 1.0));
```
- `targetGray`: typically 0.5 or the mean of the green channel
- Simple but effective for uniform color casts

## Input Type Requirements Summary

| Function | Required Input Type | Conversion |
|----------|-------------------|-----------|
| `localtonemap` | single | `im2single(img)` |
| `adapthisteq` | uint8 single-channel | Extract L or V channel |
| `imlocalbrighten` | uint8/uint16/single | Usually no conversion needed |
| `locallapfilt` | uint8/uint16/single/double | Usually no conversion needed |
| `imsharpen` | uint8/uint16/single/double | Usually no conversion needed |
| `wiener2` | double grayscale | `im2double(grayImg)` |
| `imnlmfilt` | uint8/uint16/single | Usually no conversion needed |

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Expected input to be single` | `localtonemap` received uint8 | `im2single(img)` before calling |
| `Expected 2-D input` | `adapthisteq` received RGB | Extract luminance channel first |
| `Output contains values > 1` | Operations on double without clamping | `min(max(out, 0), 1)` or `im2uint8` |
| Halos around edges after sharpening | `imsharpen` Amount too high | Reduce Amount to 0.8–1.2 |
| Color shift after `imadjust` on RGB | Per-channel stretch changes ratios | Convert to Lab, adjust L only |
| Noise amplified after sharpening | Sharpened before denoising | Reorder: denoise first, then sharpen |

## Generating Reusable Functions

After the diagnosis and tuning workflow, generate a `.m` function file the user can call repeatedly without the agent.

### What to include

Only include enhancement steps that **measurably improved** at least one metric during the session. If a step was tried and reverted (no improvement), omit it.

### Hardcoded vs parameterized values

- **Hardcode** camera-specific settings that won't change between captures (adaptor name, device ID, format, ReturnedColorSpace, tuned property values)
- **Parameterize** values the user may want to adjust per-capture. Use an `arguments` block:

```matlab
function img = acquireEnhancedImage(options)
    arguments
        options.BrightenAmount (1,1) double = 0.8
        options.DenoiseSigma (1,1) double = 0.8
    end
    % ... acquisition code ...
    img = imlocalbrighten(img, options.BrightenAmount);
    img = imgaussfilt(img, options.DenoiseSigma);
end
```

Use parameterization when the user expressed interest in adjusting strength, or when the optimal value depends on scene conditions that may vary.

### Optional image input (skip acquisition)

If the user wants to reuse only the enhancement pipeline on pre-captured images, add an optional input:

```matlab
function img = acquireEnhancedImage(options)
    arguments
        options.InputImage (:,:,:) uint8 = uint8.empty
        options.BrightenAmount (1,1) double = 0.8
    end
    if isempty(options.InputImage)
        % ... full acquisition code ...
    else
        img = options.InputImage;
    end
    % ... enhancement pipeline ...
end
```

### videoinput type validation

`videoinput` is not a standard MATLAB class. It cannot be used as a class validator in `arguments` blocks:

```matlab
% THIS FAILS at runtime:
function stopCapture(vid)
    arguments
        vid (1,1) videoinput   % Error: 'videoinput' is not recognized as a class
    end
end
```

Use an `isa` guard in the function body instead:

```matlab
function stopCapture(vid)
    if ~isa(vid, "videoinput") || ~isvalid(vid)
        error("Expected a valid videoinput object.");
    end
    % ... rest of function ...
end
```

### Naming conventions

- Function name: lowerCamelCase, verb-phrase (e.g., `acquireEnhancedImage`, `captureCleanFrame`)
- File name must match function name: `acquireEnhancedImage.m`
- One-line H1 help comment describing what it does
- Keep the function under 50 lines where possible

----

Copyright 2026 The MathWorks, Inc.

----
