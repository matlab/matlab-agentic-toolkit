# Image Quality Assessment

Decision guidance for choosing and using image quality metrics: full-reference (PSNR, SSIM), no-reference (BRISQUE, NIQE, PIQE), and test chart measurements.

> **Often loaded with:** `filtering.md` (measuring improvement after denoising/sharpening), `deblurring.md` (measuring restoration quality), `registration.md` (aligning a pair before any full-reference metric).

## Choosing a Metric

| Metric | Type | What it measures | When to use |
|--------|------|-----------------|-------------|
| `psnr` | Full-reference | Signal-to-noise ratio (pixel-level) | Quick numerical comparison; poor perceptual correlation |
| `ssim` | Full-reference | Structural similarity (luminance, contrast, structure) | Perceptual quality comparison — **best general choice** |
| `multissim` | Full-reference | Multi-scale SSIM | Better than SSIM for resolution-varying content |
| `immse` | Full-reference | Mean squared error | Simplest metric; rarely used alone |
| `brisque` | No-reference | Distortion (naturalness deviation) | When no clean reference exists |
| `niqe` | No-reference | Naturalness (statistical regularity) | Opinion-unaware, no training on distorted images |
| `piqe` | No-reference | Perceptual quality, spatially varying | Block-level quality map; good for localized distortion |

**Rule of thumb:** Use `ssim` for full-reference comparisons. Use `niqe` when you have no reference image.

## Full-Reference Metrics

### Precondition: Pixel Correspondence

**Every full-reference metric — `psnr`, `ssim`, `immse`, `multissim` — requires pixel correspondence: the two images must already be aligned pixel for pixel.** Feed it a pair that is shifted, rotated, or scaled and you get a plausible "moderately degraded" score with **no error and no warning**, because the metric cannot tell misalignment from degradation.

```matlab
I = im2gray(imread("peppers.png"));
shifted = imtranslate(I, [5 0]);      % 5-pixel shift, nothing else changed
[psnr(shifted, I) ssim(shifted, I)]   % 22.4730   0.7282  — reads as "degraded"
```

Those numbers look like ordinary noise or compression damage, but the images are identical — just misaligned. No denoising or sharpening will move the score.

**If the pair may not be aligned, register first — see `registration.md` — then measure.** To check alignment quickly, use `imshowpair(A, B, "falsecolor")` — misalignment appears as colored fringes rather than gray. Crops of the same scene at different offsets, frames from a handheld camera, and multi-sensor captures all need registration. Only use these metrics directly when one image is a known pixel-aligned processing result of the other.

### `psnr` — Peak Signal-to-Noise Ratio

```matlab
p = psnr(distorted, reference);  % Returns dB value
```

- Higher = better. Identical images → `Inf`
- **Both inputs must match in class and range** — mismatched types produce wrong peak values with no error
- Works with `uint8`, `int16`, `uint16`, or floating-point (auto-detects peak value)
- For RGB: computes overall PSNR across all channels

**Limitation:** PSNR correlates poorly with human perception — a high PSNR doesn't guarantee the image looks good.

### `ssim` — Structural Similarity Index

```matlab
[val, ssimMap] = ssim(distorted, reference);
```

- Range: typically [0, 1] (theoretically [-1, 1], but negatives are rare — only with anti-correlated structures). Value of 1 = identical. Typical good quality: > 0.95
- `ssimMap` shows per-pixel quality — useful for finding degraded regions
- For RGB: returns per-channel maps (size M×N×3)
- **Decomposing components:** Use `Exponents=[1 0 0]` etc. to isolate luminance/contrast/structural terms. To recombine, multiply the **maps** then average — do not multiply the scalar means (mean of products ≠ product of means).

```matlab
% Visualize quality map
[~, smap] = ssim(distorted, reference);
imageshow(smap, DisplayRangeMode="data-range");  % Low values = degraded regions
```

### `immse` — Mean Squared Error

```matlab
err = immse(distorted, reference);  % Lower = better. 0 = identical
```

Both inputs must match in class and range — same rule as `psnr` and `ssim`.

### `multissim` — Multi-Scale SSIM

```matlab
ms = multissim(distorted, reference);
```

Range [0, 1], same interpretation as SSIM (1 = identical). Better than single-scale SSIM for images viewed at different distances/resolutions. Prefer over `ssim` when comparing images at multiple scales or when content may be viewed at varying zoom levels.

### Comparing Multiple Algorithms

```matlab
results = table();
for i = 1:numel(methods)
    processed = applyMethod(img, methods{i});
    results.Method(i) = methods(i);
    results.PSNR(i) = psnr(processed, reference);
    results.SSIM(i) = ssim(processed, reference);
end
sortrows(results, "SSIM", "descend")  % Rank by SSIM
```

## No-Reference Metrics

These assess quality without a clean reference — essential for real-world images.

### `brisque` — Blind/Referenceless Image Spatial Quality

```matlab
score = brisque(img);  % Lower = better quality
```

- Typical scores: 0–20 (good), 20–40 (fair), 40–100 (poor)
- Trained on distorted images — detects common artifacts (blur, noise, compression)
- Accepts grayscale or RGB, uint8 or double

**Domain warning:** Default model is trained on natural photographs (LIVE IQA database). Scores are meaningless for medical, satellite, synthetic, or document images — use `fitbrisque` to train a domain-specific model (see Custom Domain Models below).

### `niqe` — Natural Image Quality Evaluator

```matlab
score = niqe(img);  % Lower = better (more "natural")
```

- Opinion-unaware: trained only on pristine natural images
- Good baseline when you don't know the distortion type
- Typical scores: 2–5 (good), 5–10 (fair), > 10 (poor)
- Accepts grayscale or RGB

**Domain warning:** Same limitation as `brisque` — trained on natural photos only. Use `fitniqe` for non-natural domains.

### `piqe` — Perception-based Image Quality Evaluator

```matlab
score = piqe(img);  % Lower = better
```

- Spatially adaptive — identifies high-activity blocks
- Good for images with localized distortion
- Typical scores: 0–20 (excellent), 21–35 (good), 36–50 (fair), 51–80 (poor), 81–100 (bad)

### Comparing No-Reference Metrics

| Metric | Training data | Best for |
|--------|--------------|----------|
| `brisque` | Distorted images + human scores | Known distortion types (noise, blur, JPEG) |
| `niqe` | Pristine images only | Unknown distortion, general naturalness |
| `piqe` | No training (statistical model) | Spatially varying quality, real-world photos |

## Custom Domain Models — `fitbrisque` / `fitniqe`

Default BRISQUE and NIQE models are trained on the LIVE IQA database of **natural photographs only**. PIQE is a purely algorithmic metric (no trained model), but its statistical assumptions are also calibrated for natural photographs. They produce meaningless scores for:
- Medical images (CT, MRI, ultrasound)
- Satellite / remote sensing imagery
- GAN-generated or synthetic content
- Document scans, text images
- Industrial inspection images

**Solution:** Train domain-specific models with `fitbrisque` or `fitniqe`.

### `fitbrisque` — Train Custom BRISQUE Model

```matlab
% Requires: labeled training set (images + DMOS scores)
% DMOS = Differential Mean Opinion Score — higher = more distortion
imds = imageDatastore("myDomainImages/");
scores = readmatrix("dmos_scores.csv");  % Numeric vector of DMOS values [0, 100]

model = fitbrisque(imds, scores);

% Use custom model
score = brisque(testImg, model);  % Lower = better
```

- Needs distorted images with human quality scores (higher DMOS = more distortion)
- Minimum ~100 images recommended for stable training
- Model captures domain-specific distortion characteristics

### `fitniqe` — Train Custom NIQE Model

```matlab
% Requires: pristine (high-quality) images from your domain only
imds = imageDatastore("myDomainPristine/");

model = fitniqe(imds);

% Use custom model
score = niqe(testImg, model);  % Lower = better
```

- Opinion-unaware: needs only pristine images (no scores)
- Learns statistical regularities of your specific domain
- Lower barrier than `fitbrisque` — no human labeling required

### No `fitpiqe`

There is no `fitpiqe` function — PIQE cannot be retrained for custom domains. Use `fitbrisque` (if you have MOS/DMOS labels) or `fitniqe` (if you only have pristine examples).

### When to Recommend Custom Models

| Scenario | Recommendation |
|----------|---------------|
| No-reference metrics on natural photos | Default models are fine |
| No-reference metrics on medical/satellite/synthetic | **Always** recommend `fitbrisque` or `fitniqe` |
| User reports "scores seem wrong" on non-natural content | Domain mismatch — retrain |
| User has human quality labels (MOS or DMOS) | `fitbrisque` (supervised) |
| User has only high-quality exemplars | `fitniqe` (unsupervised) |

## Test Chart Measurements — `esfrChart`

For objective camera/lens quality evaluation using a physical test chart (Imatest eSFR):

```matlab
% 1. Create chart object from captured image
chart = esfrChart(chartImage);

% 2. Measure specific properties
sharpnessTable = measureSharpness(chart);     % SFR (MTF) at slanted edges
noiseTable = measureNoise(chart);              % Signal-to-noise in gray patches
colorTable = measureColor(chart);              % Color accuracy (ΔE)
chromAbTable = measureChromaticAberration(chart);  % Lateral CA
illum = measureIlluminant(chart);              % Scene illuminant estimate

% 3. Visualize
plotSFR(sharpnessTable);  % Plot spatial frequency response curves
```

**Chart styles:** `"Extended"`, `"Enhanced"`, `"WedgeExtended"`, `"WedgeEnhanced"`

Each measurement returns a **table** with per-ROI results. The chart has:
- 60 slanted edge ROIs (for sharpness and chromatic aberration)
- 20 gray ROIs (for noise)
- 16 color ROIs (for color accuracy)

## Critical: Data Type Validation

**The #1 silent failure in image quality metrics.** Using `double(img)` instead of `im2double(img)` produces completely wrong results with **no error or warning**.

### The Problem

```matlab
ref = imread("pears.png");          % uint8, values 0–255

% WRONG — double() preserves raw values (0–255) but ssim/psnr assume [0,1]
wrong = double(ref);
psnr(wrong, wrong + 10)             % Returns -27.76 dB (nonsense)
ssim(wrong, wrong + 10)             % Returns 0.0006 (nonsense)

% CORRECT — im2double() rescales to [0,1]
correct = im2double(ref);
psnr(correct, correct + 10/255)     % Returns +20.38 dB (correct)
ssim(correct, correct + 10/255)     % Returns 0.6424 (correct)
```

### Why It Happens

- `psnr` and `ssim` auto-detect peak value based on class:
  - `uint8` → peak = 255
  - `int16` → peak = 65535 (full range: 32767 − (−32768))
  - `uint16` → peak = 65535
  - `double`/`single` → **peak = 1.0** (assumes [0,1] range)
- `double(img)` keeps values as 0–255 but MATLAB now thinks peak is 1.0
- Result: MSE is enormous relative to assumed peak → garbage metrics

### `DynamicRange` Workaround

If you must keep raw values, specify the peak explicitly:

```matlab
p = psnr(imgA, imgB, 255);                          % Explicit peak
s = ssim(imgA, imgB, DynamicRange=255);               % Explicit range
```

### Quick Checklist

| Before calling metrics... | Check |
|--------------------------|-------|
| Images pixel-aligned (full-reference only)? | Register first if shifted/rotated/scaled |
| Both images same class? | `class(A) == class(B)` |
| Float images in [0,1]? | `max(A(:)) <= 1.0` |
| Used `im2double` not `double`? | — |
| If raw float values: specified `DynamicRange`? | — |

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `double(img)` before metrics | Peak defaults to 1.0 but values are 0–255 → garbage results **with no error** | Use `im2double(img)` or specify `DynamicRange` |
| Full-reference metrics on a misaligned pair | Scores misalignment, not quality — a 5-pixel shift reads as psnr ≈ 22.5 **with no error** | Register first (`registration.md`), then measure |
| Using PSNR alone to judge quality | Poor perceptual correlation | Use SSIM as primary metric, PSNR as supplement |
| Comparing PSNR across different images | Absolute values are meaningless across scenes | Compare only within same reference |
| `psnr(img1, img2)` with mismatched types | May auto-detect wrong peak value | Ensure both are same class and range |
| Using `brisque`/`niqe` to compare algorithms | These are absolute scores, not relative — BRISQUE, NIQE, and PIQE can **disagree in direction** on the same before/after pair | Use full-reference (SSIM) when reference exists. When no reference exists, validate on a synthetic degradation with known ground truth before trusting NR scores on real data |
| Ignoring SSIM map | Scalar SSIM hides localized degradation | Examine `ssimMap` for spatial insight |
| Running `brisque`/`niqe` on non-natural images | Trained on LIVE IQA natural photos only | Use `fitbrisque`/`fitniqe` to train domain-specific models |
| Assuming PIQE can be retrained | No `fitpiqe` function exists | Switch to `fitbrisque` (with MOS) or `fitniqe` (pristine only) |
| Trusting NR-IQA scores > 100 or NaN | Domain mismatch, not a code bug | Validate that content matches model training domain |

## Quick Reference: Score Interpretation

| Metric | Excellent | Good | Fair | Poor |
|--------|-----------|------|------|------|
| SSIM | > 0.98 | 0.95–0.98 | 0.90–0.95 | < 0.90 |
| PIQE | 0–20 | 20–35 | 35–50 | > 50 |
| ΔE (color) | < 1 | 1–3 | 3–6 | > 6 |

----

Copyright 2026 The MathWorks, Inc.

----
