# Color Processing

Decision guidance and gotchas for color space conversions, white balance, perceptual color difference, and color-based segmentation.

**Prerequisite:** Input must be RGB truecolor (M×N×3). For indexed images, convert first with `ind2rgb(X, map)`. For grayscale images, color operations do not apply.

> **Often loaded with:** `filtering.md` (per-channel processing), `preprocessing.md` (contrast/normalization), `segmentation-automated.md` (color-based object extraction).

## Choosing a Color Space

| Space | Function pair | When to use |
|-------|--------------|-------------|
| L\*a\*b\* | `rgb2lab` / `lab2rgb` | Perceptual operations: color difference, segmentation by color, contrast on L channel only |
| HSV | `rgb2hsv` / `hsv2rgb` | Hue-based segmentation, color selection by "what color is it" |
| YCbCr | `rgb2ycbcr` / `ycbcr2rgb` | Video processing, skin detection |
| XYZ | `rgb2xyz` / `xyz2rgb` | Intermediate for white point adaptation |
| Linear RGB | `rgb2lin` / `lin2rgb` | Physical light operations (blending, compositing, lighting math) |

**Rule:** Default to converting out of RGB for any operation that interprets color or brightness. RGB is adequate only for per-pixel arithmetic (scaling, masking with a known binary mask) and I/O. For contrast enhancement, segmentation, thresholding, color comparison, blending, or any task where "how it looks" matters — convert to the appropriate space first.

## L\*a\*b\* Gotchas

### `rgb2lab` Output Type Matches Float Input

`rgb2lab` returns floating-point output — `double` for integer or double input, `single` for single input:

```matlab
lab = rgb2lab(uint8Image);    % Output is double
lab = rgb2lab(doubleImage);   % Output is double
lab = rgb2lab(singleImage);   % Output is single
```

L channel range: [0, 100]. a and b channels: approximately [-128, 128] in theory; narrower for sRGB inputs (roughly -110 to +100).

### `lab2rgb` Can Produce Out-of-Gamut Values

**Critical:** `lab2rgb` can return values outside [0, 1] for saturated colors:

```matlab
rgb = lab2rgb(labImage);
% WRONG: assume [0,1] and save directly
% CORRECT: clip before saving
rgb = max(0, min(1, lab2rgb(labImage)));
```

This happens when L\*a\*b\* values represent colors outside the sRGB gamut.

### Non-sRGB Input

For Adobe RGB or ProPhoto RGB images, specify the input color space: `rgb2lab(img, ColorSpace="adobe-rgb-1998")`. Use `WhitePoint` to override the default D65 reference white.

### `rgb2lab` Input Type Trap

`rgb2lab` interprets `double` input as [0, 1] range. If your double image has 0–255 values, the result is silently wrong:

```matlab
% WRONG: double image with 0-255 range — rgb2lab assumes [0,1]
lab = rgb2lab(doubleImage255);

% CORRECT: ensure proper range
lab = rgb2lab(im2uint8(doubleImage255));  % or
lab = rgb2lab(doubleImage255 / 255);
```

## HSV — Hue Wraps Around

**Gotcha:** Red straddles H=0 and H=1. A simple range check `H > 0.9` misses half the reds:

```matlab
hsv = rgb2hsv(img);
H = hsv(:,:,1);
S = hsv(:,:,2);
V = hsv(:,:,3);

% Red: must check BOTH ends of hue circle
red_mask = (H < 0.05 | H > 0.95) & S > 0.4 & V > 0.3;

% Green: continuous range, no wrapping issue
green_mask = (H > 0.2 & H < 0.45) & S > 0.3 & V > 0.2;
```

**Always include saturation and value thresholds** — low-saturation pixels have unstable hue.

## White Balance

### Workflow: Estimate Illuminant → Adapt

```matlab
img = im2single(imread("photo.png"));

% Step 1: Estimate scene illuminant (choose one method)
illum = illumwhite(img);   % White patch assumption (brightest pixel is white)
illum = illumgray(img);    % Gray world assumption (average is gray)
illum = illumpca(img);     % PCA-based (most robust for complex scenes)

% Step 2: Apply chromatic adaptation (default "srgb" handles gamma correctly)
balanced = chromadapt(img, illum);
```

### `chromadapt` Parameters

```matlab
balanced = chromadapt(img, illuminant, ...
    "ColorSpace", "linear-rgb", ...  % "srgb" (default), "linear-rgb", "adobe-rgb-1998", "prophoto-rgb"
    "Method", "bradford");            % "bradford" (default), "vonkries", "simple"
```

The `illuminant` argument is the estimated scene illuminant (3-element RGB vector). The function adapts from this illuminant to D65 (standard daylight).

**Gotcha:** `chromadapt` output can exceed [0, 1] — clip if saving to file.

## Perceptual Color Difference

### `deltaE` — CIE76 (Simple Euclidean in L\*a\*b\*)

```matlab
dE = deltaE(img1, img2);                    % RGB input (converts internally)
dE = deltaE(lab1, lab2, isInputLab=true);   % L*a*b* input (skips conversion)
```

Returns a 2-D map of per-pixel color differences.

### `imcolordiff` — CIE94 / CIEDE2000 (More Perceptually Uniform)

```matlab
dE = imcolordiff(img1, img2);                              % CIE94 (default)
dE = imcolordiff(img1, img2, Standard="CIEDE2000");        % CIEDE2000 (best)
dE = imcolordiff(lab1, lab2, isInputLab=true);             % L*a*b* input
```

**Which to use:**
- `deltaE` (CIE76): simple, fast, adequate for large differences
- `imcolordiff` with CIE94: better perceptual uniformity
- `imcolordiff` with CIEDE2000: best perceptual accuracy, use for quality assessment

**Interpretation (CIE76 scale):** ΔE < 1 = imperceptible; 1–2 = barely perceptible; 2–10 = noticeable; > 10 = very different. For CIEDE2000, thresholds are lower (ΔE > 5 is already very different).

## Color-Based Segmentation

Use HSV when the user names a color category (e.g., "red", "blue"). Use L\*a\*b\* distance when they provide a specific RGB value or sample pixel.

### L\*a\*b\* Distance (Best for Specific Target Color)

```matlab
lab = rgb2lab(img);
target_lab = rgb2lab(reshape(uint8([200 50 50]), [1 1 3]));  % Target color

% Distance in a*b* plane (ignore luminance for illumination robustness)
a_diff = lab(:,:,2) - target_lab(1,1,2);
b_diff = lab(:,:,3) - target_lab(1,1,3);
color_dist = sqrt(a_diff.^2 + b_diff.^2);
mask = color_dist < 30;  % Threshold in perceptual units
```

### HSV Hue Segmentation (Best for "What Color" Questions)

See HSV section above. Good when you want "all red objects" regardless of shade.

## CLAHE on Color Images

Apply contrast enhancement to luminance only — never to color channels. **Shortcut:** `rgb2lightness(img)` extracts the L\* channel directly without a full L\*a\*b\* conversion.

```matlab
lab = rgb2lab(img);
L = lab(:,:,1);
L_enhanced = adapthisteq(L / 100) * 100;  % Normalize to [0,1] for adapthisteq, scale back
lab(:,:,1) = L_enhanced;
result = lab2rgb(lab);
result = max(0, min(1, result));  % Clip out-of-gamut
```

## Gamma and Linearization

Operations that model physical light (blending, compositing, lighting) must be done in **linear RGB**, not sRGB:

```matlab
linear = rgb2lin(srgbImage);     % Remove gamma curve
% ... physical operations (blending, alpha compositing) ...
srgb = lin2rgb(linearResult);    % Re-apply gamma for display
```

**Gotcha:** Averaging two sRGB images directly (without linearization) produces incorrect mid-tones. Linearize first for physically correct blending.

## Decorrelation Stretching

Enhances color differences for visualization (useful for multispectral or low-contrast color images):

```matlab
enhanced = decorrstretch(img);              % Basic stretch
enhanced = decorrstretch(img, "Tol", 0.01); % Clip 1% tails to reduce outlier influence
```

## ICC Profiles — When to Use

For standard sRGB work, use direct conversion functions (`rgb2lab`, `rgb2xyz`, etc.). ICC profiles are needed only for:
- Non-sRGB color spaces (Adobe RGB, ProPhoto RGB)
- Printer/display profiling
- Color management workflows

```matlab
profile = iccread("custom_profile.icc");
% makecform/applycform is the correct API for ICC profile transforms.
% Do NOT use makecform/applycform for standard sRGB conversions — use
% rgb2lab, rgb2hsv, etc. directly (simpler, no profile needed).
cform = makecform("icc", profile, profile2);  % Between two profiles
result = applycform(img, cform);
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Color math in RGB | RGB distances aren't perceptual | Convert to L\*a\*b\* for perceptual operations |
| `lab2rgb` without clipping | Can produce values < 0 or > 1 | `max(0, min(1, lab2rgb(...)))` |
| HSV red check: `H > 0.9` only | Red wraps around: H≈0 and H≈1 | `(H < 0.05 \| H > 0.95)` |
| CLAHE on RGB channels separately | Distorts color | Apply to L channel in L\*a\*b\* only |
| Blending/compositing in sRGB | Non-linear gamma causes dark halos | Linearize first with `rgb2lin` |
| `chromadapt` output saved without clipping | Can exceed [0,1] | Clip before `imwrite` |
| Using `makecform`/`applycform` for standard sRGB conversions | Unnecessary when both ends are sRGB — `makecform`/`applycform` are correct for ICC profile workflows (see above) | Use `rgb2lab`, `rgb2hsv`, etc. directly for sRGB |
| `rgb2lab` on double image with 0–255 range | `rgb2lab` assumes double input is [0, 1] — values >1 produce wrong L\*a\*b\* | Convert to uint8 first, or divide by 255 |

----

Copyright 2026 The MathWorks, Inc.

----
