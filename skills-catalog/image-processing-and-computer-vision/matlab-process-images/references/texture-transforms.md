# Texture Analysis & Image Transforms

Decision guidance for texture descriptors (GLCM, LBP, Gabor), local texture filters, and frequency-domain transforms (FFT, DCT, Radon).

> **Often loaded with:** `filtering.md` (preprocessing before texture extraction), `segmentation-automated.md` (texture-based segmentation).

## Choosing a Texture Method

| Method | Output | Best for |
|--------|--------|----------|
| GLCM (`graycomatrix` + `graycoprops`) | Statistical features per region | Texture classification, material recognition |
| Local filters (`entropyfilt`, `rangefilt`, `stdfilt`) | Texture map (same size as image) | Segmentation by texture, finding textured regions |
| Gabor (`imgaborfilt`) | Oriented frequency response | Detecting patterns at specific orientations/scales |
| LBP (`extractLBPFeatures`) | Histogram feature vector | Fast texture classification, face recognition (**requires Computer Vision Toolbox**) |

## GLCM — Gray-Level Co-occurrence Matrix

### Computing GLCM

```matlab
% Basic (single offset [0 1] = horizontal neighbor)
glcm = graycomatrix(img);

% Multiple offsets (4 directions) — recommended for rotation invariance
offsets = [0 1; -1 1; -1 0; -1 -1];  % 0°, 45°, 90°, 135°
glcm = graycomatrix(img, "Offset", offsets, "NumLevels", 8, "Symmetric", true);
% Returns 8×8×4 (one GLCM per offset)
```

### Extracting Properties

```matlab
stats = graycoprops(glcm, "all");
% Returns struct with: Contrast, Correlation, Energy, Homogeneity
% Each field is 1×numOffsets vector
```

**Available properties:**

| Property | Measures | High value means |
|----------|----------|-----------------|
| `Contrast` | Local intensity variation | Coarse/rough texture |
| `Correlation` | Linear dependency of neighbors | Structured/predictable pattern |
| `Energy` | Sum of squared elements | Uniform/homogeneous texture |
| `Homogeneity` | Closeness to diagonal | Smooth transitions |

**Gotcha:** `graycoprops` accepts a single char vector (`'Contrast'`), a cell array of char vectors (`{'Contrast','Energy'}`), or `"all"` — but NOT a string array (`["Contrast","Energy"]` will error).

### GLCM Parameters That Matter

- **`NumLevels`** (default 8): Quantization levels. Lower = faster, less sensitive to noise. Higher = more detail but sparser matrix.
- **`GrayLimits`** (default `[min(img(:)) max(img(:))]`): Maps this intensity range to [1, NumLevels]. For float images or when comparing across images, set explicitly (e.g., `"GrayLimits", [0 1]`) to ensure consistent quantization.
- **`Symmetric`** (default false): Set `true` to treat pixel pair (a,b) same as (b,a) — recommended for undirected textures.
- **`Offset`**: Direction and distance. Multiple offsets capture texture at different orientations.

## Local Texture Filters

These produce a texture map the same size as the input — useful for texture-based segmentation:

```matlab
E = entropyfilt(img);          % Local entropy (higher = more complex texture)
R = rangefilt(img);            % Local range (max - min in neighborhood)
S = stdfilt(img);              % Local standard deviation
```

Default neighborhood is 9×9 for `entropyfilt`, 3×3 for `rangefilt`/`stdfilt`.

Custom neighborhood:
```matlab
E = entropyfilt(img, true(15));   % 15×15 neighborhood
S = stdfilt(img, ones(7));         % 7×7 neighborhood
```

**Use case:** Segment by texture using these as features for thresholding or clustering:
```matlab
textureMap = entropyfilt(img);
textureMask = textureMap > threshold;  % Separate textured from smooth regions
```

## Gabor Filtering

For detecting texture at specific orientations and spatial frequencies:

```matlab
% Create filter bank
wavelengths = [4 8 16 32];          % Spatial frequency (pixels per cycle)
orientations = [0 45 90 135];        % Degrees
gBank = gabor(wavelengths, orientations);  % 16 filters (4×4)

% Apply single filter
[mag, phase] = imgaborfilt(img, 8, 45);  % wavelength=8, orientation=45°

% Apply entire bank at once (returns H×W×numFilters stack)
[magBank, phaseBank] = imgaborfilt(img, gBank);
```

**Critical:** `imgaborfilt` requires a 2-D input. RGB images will error ("Expected A to be two-dimensional"). Convert first:

```matlab
gray = im2gray(img);           % Convert RGB to grayscale
[mag, phase] = imgaborfilt(gray, gBank);
```

**When to use Gabor over GLCM:** Gabor captures orientation-specific texture at specific scales. Better for detecting striped/periodic patterns, fingerprints, or textures with dominant orientation.

### Interpreting Gabor Responses

Gabor magnitude is a **relative response**, not a normalized measurement. A large value means local image content strongly matches the filter's orientation and wavelength — it is not a score on [0, 1]:

- **Interpret relative to context** — compare magnitudes across nearby pixels or across filters in a bank, not as absolute quantities
- **MATLAB does not normalize** — intentionally, because the right normalization depends on the application (per-filter-plane, across a feature vector, or application-specific scaling)
- **Phase is secondary** — `imgaborfilt` returns separate real-valued magnitude and phase arrays (`[mag, phase]`); one-output syntax returns magnitude only. Most texture workflows use only magnitude
- **Real-valued Gabor filters in literature** — many publications use only the real or imaginary component as an approximation. MATLAB's complex formulation preserves the complete response and produces magnitude that is less sensitive to phase shifts

## LBP — Local Binary Patterns (Computer Vision Toolbox)

**Requires Computer Vision Toolbox.** Not available with Image Processing Toolbox alone.

Fast histogram-based texture descriptor:

```matlab
features = extractLBPFeatures(img);                     % Whole-image histogram (1×59)
features = extractLBPFeatures(img, "CellSize", [32 32]); % Per-cell histograms (larger vector)
features = extractLBPFeatures(img, "NumNeighbors", 8, "Radius", 1);  % Standard LBP
```

**Use case:** Texture classification — compute LBP features for each sample, train a classifier.

**IPT alternative if Computer Vision Toolbox is unavailable:** Use `entropyfilt` + `stdfilt` or Gabor filter bank features for texture classification.

## Wavelet-Based Texture

For wavelet-based texture analysis or multi-resolution decomposition, use `dwt2`/`wavedec2` (requires Wavelet Toolbox).

## Fourier Transform — `fft2`

### Standard Pattern

```matlab
F = fft2(img);                      % Compute 2-D FFT
F_shifted = fftshift(F);            % Center DC component
magnitude = log(1 + abs(F_shifted)); % Log magnitude for visualization
```

### Frequency Domain Filtering

```matlab
[M, N] = size(img);
F = fftshift(fft2(img));

% Create frequency-domain filter (e.g., ideal low-pass)
[U, V] = meshgrid(1:N, 1:M);
D = sqrt((U - N/2).^2 + (V - M/2).^2);
H = double(D < cutoffRadius);       % Binary low-pass mask (ideal filter)

% Apply and reconstruct
filtered = real(ifft2(ifftshift(F .* H)));
% Note: Ideal (binary) filters cause ringing (Gibbs phenomenon).
% For smoother results, use a Gaussian or Butterworth filter:
% H = exp(-(D.^2) / (2*cutoffRadius^2));  % Gaussian — no ringing
```

### Key FFT Gotchas

| Mistake | Why it's wrong | Fix |
|---------|---------------|-----|
| Forgetting `fftshift` | DC component at corners, not center | Always `fftshift` before visualization/filtering |
| Forgetting `ifftshift` before `ifft2` | Misaligned spectrum for reconstruction | `ifft2(ifftshift(filtered_spectrum))` |
| Not taking `real()` of `ifft2` | Tiny imaginary parts from rounding | Wrap with `real()` |
| Visualizing `abs(F)` directly | Dynamic range too large | Use `log(1 + abs(F_shifted))` |

## DCT — Discrete Cosine Transform

```matlab
D = dct2(img);                      % Forward DCT
reconstructed = idct2(D);           % Inverse DCT
```

**Compression pattern** (zero out small coefficients):
```matlab
D = dct2(img);
D(abs(D) < threshold) = 0;         % Remove insignificant frequencies
compressed = idct2(D);
```

DCT is real-valued (unlike FFT which is complex) — simpler for compression and energy compaction.

## Radon Transform

For line detection and CT reconstruction:

```matlab
theta = 0:179;                      % Projection angles
[R, xp] = radon(img, theta);       % Sinogram: size [numRadialPositions × numAngles]

% Inverse (filtered back-projection)
reconstructed = iradon(R, theta, [], [], [], size(img, 1));  % Output size is 6th arg
```

**Gotcha — output size:** `iradon` without the output size argument produces a slightly larger image than the original. Specify it as the 6th positional argument: `iradon(R, theta, [], [], [], N)`. The 3rd–5th arguments (interpolation, filter, frequency scaling) use defaults when passed as `[]`.

**Gotcha — theta must be equally spaced:** `iradon` assumes equal angular spacing between projections. It does not warn or error on unequal spacing, but results degrade with irregular sampling (artifacts, streaks). If your projections have unequal angles, interpolate the sinogram to a regular angular grid first using `scatteredInterpolant` or `interp1` before calling `iradon`.

### Fan-Beam Transform

```matlab
[F, sensorPos, rotAngles] = fanbeam(img, D);  % D = source-to-center distance
reconstructed = ifanbeam(F, D);
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `graycoprops(glcm, ["Contrast","Energy"])` | String arrays not supported | Use cell array `{'Contrast','Energy'}` or `"all"` |
| GLCM without `"Symmetric", true` | Directional bias in features | Set `true` for undirected textures |
| FFT without `fftshift` | DC at corners, misleading spectrum | Always shift for visualization/filtering |
| `iradon(R, theta)` expecting original size | Output is slightly larger | Pass output size: `iradon(R, theta, N)` |
| `iradon` with unequally-spaced theta | No error, but artifacts from irregular sampling | Interpolate sinogram to regular angular grid first |
| Gabor on RGB image | Errors — `imgaborfilt` requires 2-D input | Convert with `im2gray` first |
| Treating Gabor magnitude as a normalized [0,1] score | Values are relative, not normalized | Normalize per application; interpret relative to filter bank |
| Comparing raw Gabor magnitudes across unrelated filter banks | Different filters produce different response scales | Normalize within each bank or feature vector |
| Very high `NumLevels` in GLCM | Sparse matrix, noise-sensitive | Use 8–32 levels for most applications |

----

Copyright 2026 The MathWorks, Inc.

----
