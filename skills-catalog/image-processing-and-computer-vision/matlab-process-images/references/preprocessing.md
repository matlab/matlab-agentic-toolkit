# Preprocessing

Diagnostic decision guide for preparing images before processing: data type interpretation, conversion, normalization, contrast enhancement, illumination correction, and arithmetic. Start from the problem (dark image, uneven lighting, wrong range), not the function name.

> **Often loaded with:** `filtering.md` (smoothing/denoising), `image-io.md` (loading data), `deep-learning-imaging.md` (per-channel normalization for networks).
>
> **Routes to other references:** color space conversion → `color-processing.md`; morphological illumination correction (top-hat, bottom-hat) → `morphological-ops.md`; indexed image semantics → `image-io.md`; volumetric preprocessing → `3d-volume-processing.md`; display viewers → skill `matlab-display-image`.

## Characterize Before Transforming

Before any preprocessing step, establish these properties (for full characterization workflows, see `image-understanding.md`):

| Property | How to check | Why it matters for preprocessing |
|----------|-------------|----------------------------------|
| **Storage class** | `class(img)` | Controls arithmetic behavior, saturation, and function compatibility |
| **Actual data range** | `[min(img(:)) max(img(:))]` | May differ from the type's valid range — e.g., 12-bit sensor data in uint16 uses only [0, 4095] |
| **Display range** | What the viewer assumes | A dark display does not mean dark data — determines whether you need data modification or just a viewer adjustment |

**Key insight:** conversion is not normalization. `im2single` does type-aware scaling (uint8 255 → 1.0); `rescale` remaps actual min/max. `double(img)` does neither — it just changes the type without scaling, producing values like 128.0 that IPT functions interpret as out-of-range.

## Problem-Oriented Preprocessing Workflow

1. **Diagnose** — What is wrong? (dark, low contrast, uneven illumination, wrong type for downstream task)
2. **Choose one transformation** — Pick the minimal operation that addresses the problem
3. **Inspect the result** — Verify the fix didn't introduce new issues
4. **Evaluate** — Does it improve the downstream task? (see `quality-assessment.md`)
5. **Only then** add another stage — stacked operations obscure which step caused a failure

### Typical Preprocessing Order

When multiple preprocessing steps are needed, this order avoids common pitfalls:

1. **Illumination correction** (`imflatfield`, `imtophat`) — before contrast enhancement, which would amplify the illumination gradient
2. **Denoising** (`imgaussfilt`, `medfilt2`, `imnlmfilt`) — before contrast enhancement, which would amplify noise
3. **Contrast enhancement** (`imadjust`, `adapthisteq`) — after illumination and noise are addressed
4. **Type conversion** (`im2single`, `im2uint8`) — at the boundary where downstream functions require a specific type

Illumination correction, contrast enhancement, and histogram equalization are covered in the sections that follow this order. Denoising is covered in `filtering.md`. The remaining sections — image arithmetic, linear combinations, and image blending — cover operations typically applied at or after the type-conversion boundary.

## Display vs Data — Know the Difference

Adjusting the viewer's display range changes **presentation only**. Calling `imadjust` or `rescale` changes **the actual pixel data**. Before modifying data, ask: does the output need to be saved or only inspected? For scientific/medical data, prefer display-range adjustment over data modification when the goal is visualization.

```matlab
% Display-only: adjust viewer window/level — data is untouched
imageshow(img, DisplayRange=[500 2000]);

% Data modification: pixels are permanently changed
adjusted = imadjust(img, [500/65535 2000/65535], []);
```

## Illumination Correction

| Goal | Function | Route |
|------|----------|-------|
| Correct smooth, gradual falloff (vignetting, microscopy) | `imflatfield(img, sigma)` | This reference |
| Estimate and subtract background | Background estimation + subtraction | This reference |
| Extract small bright objects on dark background | `imtophat` (morphological) | `morphological-ops.md` |
| Extract small dark objects on bright background | `imbothat` (morphological) | `morphological-ops.md` |
| Clean up documents for OCR | Morphological binarization pipeline | `morphological-ops.md` |

### `imflatfield`

```matlab
corrected = imflatfield(img, sigma);
```

- `sigma` should be larger than the largest foreground object (typical: 30–100)
- Supports a `Mask` argument to limit where the correction is applied — pixels where the mask is false retain their original values
- Processes RGB images through the HSV value channel automatically
- Simpler than morphological alternatives for smooth illumination gradients

## Contrast Enhancement — Choosing a Method

| Goal | Function | What it does |
|------|----------|-------------|
| Remap endpoints to known desired range | `imadjust(img, [low high], [])` | Linear mapping with explicit limits |
| Remap endpoints to automatically calculated range | `imadjust(img)` (grayscale only) | Clips bottom/top 1% via `stretchlim` — robust to outliers |
| Remap RGB image to automatically calculated range | `imadjust(rgb, stretchlim(rgb), [])` | **Must provide explicit limits** — `imadjust(rgb)` without args errors |
| Redistribute intensities for uniform histogram | `histeq(img)` | Maximizes global contrast; can look unnatural and amplify noise in flat regions |
| Apply locally varying contrast enhancement | `adapthisteq(img)` (CLAHE) | Tile-based — reveals detail in varying-brightness images |
| Gamma correction | `imadjust(img, [], [], gamma)` | gamma < 1 brightens; gamma > 1 darkens |
| Brighten dark regions selectively | `imlocalbrighten(img)` | Brightens dim areas while preserving already bright regions; `AlphaBlend=true` protects highlights |
| Remove atmospheric haze | `imreducehaze(img)` | Uses approximate dark channel prior method; returns dehazed image, transmission map, and atmospheric light estimate |

### Histogram Equalization

| Function | Effect | Risk |
|----------|--------|------|
| `histeq` | Global histogram equalization | Can look unnatural; amplifies noise in flat regions |
| `adapthisteq` | Local (tile-based) CLAHE | More stable; `ClipLimit` controls noise amplification |

**Color images:** Never apply `histeq` or `adapthisteq` directly to RGB — per-channel equalization distorts color. Convert to L\*a\*b\* or HSV and equalize only the luminance/value channel.

### `imadjust` Details

```matlab
adj = imadjust(gray);                           % Auto 1% saturation
adj = imadjust(rgb, stretchlim(rgb), []);        % RGB — required form
adj = imadjust(img, [0.2 0.8], [0 1]);           % Explicit input range
adj = imadjust(img, [], [], 0.5);                 % Gamma correction
```

- Single `[low high]` applies to all channels; a 2-by-3 matrix allows per-channel limits

### CLAHE — `adapthisteq`

```matlab
enhanced = adapthisteq(img, ClipLimit=0.02, NumTiles=[8 8]);
```

- `ClipLimit` (0–1): higher = more contrast; lower = prevents noise amplification. Start with 0.02
- `NumTiles`: more tiles = more local; can expose tile-boundary artifacts at high values
- `NBins`: trades speed for dynamic-range fidelity (default 256)
- **Grayscale only** — for color images, apply to luminance channel only (convert to L\*a\*b\*, enhance L, convert back, clip out-of-gamut). See `color-processing.md` for the full pattern

### Histogram Matching — `imhistmatch` / `imhistmatchn`

Transform an image so its histogram approximates a reference image's histogram. Use for batch normalization, cross-session consistency, or matching imaging conditions:

```matlab
matched = imhistmatch(img, referenceImg);           % 2-D grayscale or RGB
matched = imhistmatchn(vol, referenceVol);           % N-D grayscale
```

- `imhistmatch` accepts grayscale or RGB (per-channel matching for RGB)
- `imhistmatchn` is grayscale only, works on N-D data (volumes)
- Both accept uint8, uint16, int16, single, double

## Conversion and Normalization Decision Tree

| Goal | Function | What it does |
|------|----------|-------------|
| Convert to float for arithmetic with type-aware range scaling | `im2single(img)` | uint8 /255, uint16 /65535 → [0, 1] single; preserves relative intensities |
| Convert to double precision with type-aware range scaling | `im2double(img)` | Same scaling as `im2single` but double; rarely needed — prefer `im2single` |
| Remap actual data extrema to a target range | `rescale(img)` or `rescale(img, 0, 255)` | Linear map of actual min/max; can target any range |
| Remap from a known sensor range | `rescale(img, 0, 1, InputMin=0, InputMax=4095)` | Useful for 12-bit, 14-bit sensor data in wider containers |
| Make a non-image matrix displayable | `mat2gray(img)` | Actual min/max → double [0, 1]; always outputs double |
| Robust contrast stretch (clip outliers) | `imadjust(img)` / `stretchlim` | Saturates bottom/top 1% by default |
| Prepare float data for `imwrite` | `im2uint8(img)` | Float [0,1] → uint8 [0,255] |

**Do NOT use `double(img)`** for image conversion — it changes the type without scaling, leaving values like 128.0 that IPT treats as out-of-range.

**Quantization warning:** converting from higher to lower bit depth (e.g., uint16 → uint8) permanently discards precision. Do this only at the end of a pipeline.

**Batch warning:** `rescale` and `imadjust` with default arguments normalize each image to its own min/max. In a dataset where intensity comparisons across images matter (time series, dose response, multi-well plates), compute normalization limits once from the entire dataset and apply them uniformly — otherwise inter-image relationships are destroyed.

**Prefer `im2single` over `im2double`:**
- Halves memory (4 bytes/pixel vs 8)
- Many IPT functions have optimized code paths for `single`
- 24-bit mantissa covers uint16 range exactly

Most IPT functions accept integer images directly — **do not convert to floating-point as a default habit**. If an IPT function rejects your data type, check its documentation with `matlab-read-documentation` — the issue may be a specific type restriction (e.g., int16 not supported), not a blanket float requirement.

**When float IS needed:** custom arithmetic operations (matrix math, weighted sums — integer clips silently), deep learning network input (see `deep-learning-imaging.md` for per-channel normalization with ImageNet statistics and dataset mean/std).

## Image Arithmetic and Precision

Integer arithmetic clips silently. Nested operations compound rounding error:

| Function | `uint8` behavior | `double` behavior |
|----------|-----------------|-------------------|
| `imadd(A, B)` | Saturates at 255 | Can exceed 1.0 |
| `imsubtract(A, B)` | Saturates at 0 | Can go negative |
| `imabsdiff(A, B)` | Absolute difference | Always non-negative |
| `imcomplement(A)` | `255 - A` | `1 - A` |

**Precision rule:** If a computation involves subtraction, weighting, or multiple steps, convert to `single` once at the start, compute, then cast to the output type once at the end:

```matlab
% WRONG — integer clips at each step
result = imadd(imsubtract(uint8(A), uint8(B)), uint8(C));  % Lost negatives, compounded rounding

% RIGHT — compute in float, cast once
A = im2single(A); B = im2single(B); C = im2single(C);
result = im2uint8(A - B + C);
```

### `imlincomb` — Linear Combinations Without Intermediate Clipping

For weighted sums, `imlincomb` computes the entire expression in double precision and rounds only at the end. Use `imlincomb` when you need precise weighted arithmetic on integer images and the result should remain integer. For visual compositing and blending effects, use `imblend` instead.

```matlab
% Weighted blend — no intermediate clipping
result = imlincomb(0.7, img1, 0.3, img2);           % Returns same class as img1
result = imlincomb(0.5, A, 0.5, B, "single");       % Force output class
result = imlincomb(1, img1, -1, img2, 128);          % Difference with offset
```

Prefer `imlincomb` over manual `a*im2single(A) + b*im2single(B)` when the output should remain integer.

## Image Blending — `imblend`

Blend two images using various modes (R2024b). Do NOT manually implement alpha blending:

```matlab
blended = imblend(foreground, background);                        % Alpha blend (default)
blended = imblend(fg, bg, mask, Mode="Poisson");                  % Seamless Poisson blend
blended = imblend(fg, bg, mask, Mode="PoissonMixGradients");      % Mix gradients at boundary
blended = imblend(fg, bg, mask, Location=[100 50]);               % Place fg at offset in bg
```

| Mode | Effect | Use case |
|------|--------|----------|
| `"Alpha"` | Opacity-weighted blend | General compositing |
| `"Poisson"` | Seamless gradient-domain blend | Object insertion without visible seams |
| `"PoissonMixGradients"` | Mix fg+bg gradients | Texture transfer, transparent object insertion |
| `"Guided"` | Edge-preserving blend | Smooth transitions preserving structure |
| `"Min"` / `"Max"` / `"Average"` / `"Overlay"` | Pixel-wise operations | Special effects |

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `double(img)` instead of `im2single(img)` | No scaling — 128.0 is out of [0,1] range | Use `im2single` or `im2double` for image conversion |
| Converting to float "just in case" | Wastes memory, no benefit for built-in functions | Most IPT functions accept integer directly |
| `imadjust(rgbImage)` without args | Errors — no auto mode for RGB | `imadjust(rgb, stretchlim(rgb), [])` |
| `adapthisteq` on RGB directly | Per-channel equalization distorts color | Apply to L channel in L\*a\*b\* space |
| Manual `(x-min)/(max-min)` | Reinventing the wheel, no output-range control | `rescale(x)` or `rescale(x, 0, 255)` |
| Integer arithmetic with subtraction | Negatives clip to 0 silently | Convert to float first, or use `imlincomb` |
| Stacking multiple adjustments blindly | Can't tell which step caused a problem | Apply one transformation, inspect, then proceed |
| `adapthisteq` on float data outside [0,1] | Silently clips output to [0,1] — no error or warning | Ensure float input is in [0,1] before calling; use `rescale` if needed |
| Modifying scientific data when only display needed | Permanent data loss | Adjust viewer `DisplayRange` instead |
| uint16 → uint8 early in pipeline | Discards 8 bits of precision | Convert to lower bit depth only at the final output step |

----

Copyright 2026 The MathWorks, Inc.

----
