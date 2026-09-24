# Filtering

Diagnostic decision guide for choosing and applying image filters: smoothing, denoising, sharpening, and edge-preserving operations. Start from the noise model or artifact, not the function name.

> **Often loaded with:** `preprocessing.md` (contrast/normalization/type conversion), `quality-assessment.md` (measuring improvement), `morphological-ops.md` (post-filtering cleanup).
>
> **Routes to other references:** color-aware filtering → `color-processing.md`; volumetric data → `3d-volume-processing.md`; motion-blur restoration / deconvolution → `deblurring.md`; texture characterization → `texture-transforms.md`.

## Diagnose Before Filtering

Before selecting a filter, characterize the input:

1. **Storage class and range** — integer inputs clip negative/overflow results silently (see [Output Class and Clipping](#output-class-and-clipping))
2. **Noise/artifact type** — drives filter selection (see table below)
3. **Downstream task** — segmentation needs edge-preserving; display needs visual smoothing; measurement needs bias-free

## Noise/Artifact → Filter Selection

| Observed artifact | Likely noise model | Recommended filter | Why not the alternatives |
|-------------------|-------------------|-------------------|------------------------|
| Uniform grain in flat regions | Additive Gaussian | `imgaussfilt` or `imboxfilt` | Median filtering is primarily intended for impulse noise and may unnecessarily alter non-impulsive detail |
| Constant-power additive white noise | Additive white Gaussian | `wiener2` | Local adaptive filter; Gaussian blur ignores local variance |
| Bright/dark outlier pixels | Impulse (salt & pepper) | `medfilt2` | Gaussian blur spreads outliers; Wiener assumes smooth spectrum |
| Grain over fine texture | Additive Gaussian over texture | `imnlmfilt` (inspect result — may smooth texture) | Better edge preservation than Gaussian/bilateral, but can still reduce fine detail |
| Noise with strong edges to preserve | Mixed, edge-sensitive task | `imbilatfilt`, `imguidedfilter`, `imdiffusefilt` | Gaussian blurs edges; median can round corners |
| Detail enhancement or smoothing | Not noise — want to separate scales | `locallapfilt` | Multi-scale decomposition; bilateral only operates at one scale |

## Choosing a Smoothing Method

| Goal | Function | Key detail |
|------|----------|-----------|
| General Gaussian blur | `imgaussfilt(img, sigma)` | **Preferred over `fspecial`+`imfilter`** — auto filter size, replicate padding by default |
| Box/mean filter | `imboxfilt(img, filterSize)` | Internally chooses convolution or integral-image filtering; simpler API than `imfilter` with average kernel |
| Remove salt & pepper noise | `medfilt2(img, [m n])` | Grayscale only; nonlinear — preserves edges, removes impulse noise only |
| Local adaptive denoising | `wiener2(img, [m n])` | Grayscale only; adapts to local variance. Best for constant-power additive white noise; optional scalar noise-power argument |
| Edge-preserving smoothing | `imbilatfilt(img, degreeOfSmoothing, spatialSigma)` | Smooths flat regions, preserves edges. **Default `degreeOfSmoothing` is class-dependent:** 650.25 for uint8, 0.01 for double [0,1] — always specify explicitly when the input class may vary |
| Anisotropic diffusion | `imdiffusefilt(img)` | Grayscale only; iterative — use `imdiffuseest` to estimate `GradientThreshold` and `NumberOfIterations` |
| Guided filtering | `imguidedfilter(img)` | Edge-aware, can use separate guidance image |
| Detail/scale manipulation | `locallapfilt(img, sigma, alpha)` | **Does NOT accept `double`** — use `single` or integer |
| Local contrast | `localcontrast(img, edgeThreshold, amount)` | **Does NOT accept `double`** — use `single` or integer |

### Grayscale-Only Functions on RGB Images

`medfilt2` and `wiener2` error on RGB input. `imdiffusefilt` does not error but **warns and treats the RGB image as a 3-D volume**, diffusing across color channels — this is a different operation that produces plausible but incorrect results. Convert to a luminance-chrominance color space, filter the luminance channel only, and convert back — this avoids the color shifts that per-channel RGB filtering can introduce:

```matlab
lab = rgb2lab(img);
lab(:,:,1) = medfilt2(lab(:,:,1), [5 5]);
img_filtered = lab2rgb(lab, OutputType="uint8");
```

See `color-processing.md` for color space conversion details.

## Non-Local Means Denoising — `imnlmfilt`

Exploits self-similarity to denoise — preserves strong edges but **can smooth textured regions and reduce fine detail**. Best when the image has repeated structure that the algorithm can match across patches:

```matlab
[denoised, estimatedDoS] = imnlmfilt(img);                          % Auto parameters; returns estimated DegreeOfSmoothing

% Tune relative to the auto estimate — avoids hardcoding a class-dependent value
lighter = imnlmfilt(img, DegreeOfSmoothing=0.75*estimatedDoS);      % Less smoothing
stronger = imnlmfilt(img, DegreeOfSmoothing=1.25*estimatedDoS);     % More smoothing
```

**Key parameters:**
- `DegreeOfSmoothing` — auto value is based on estimated noise standard deviation, not a universally optimal setting. The appropriate value depends on the input class and data range — do not hardcode a single number across different images. Increase for stronger denoising; decrease to preserve more detail
- `SearchWindowSize` — runtime scales linearly with search-window size. Default 21 is a good balance; reduce for speed on large images

**When to prefer over other denoisers:**
- Over `medfilt2`: when noise is not impulse (salt & pepper)
- Over `imgaussfilt`: when strong edges must be preserved
- Over `imbilatfilt`: when image has repeated structure the algorithm can exploit for patch matching

**Limitations:** preserves strong edges but **smooths texture** — MathWorks examples show grass texture and fine detail being visibly reduced. Runtime scales linearly with search-window area; has a minimum image size requirement. Always inspect results on a representative region before committing, consider `imgaussfilt` or `imbilatfilt` as alternatives.

## Boundary Padding — Choose Before Filtering

Different functions have different padding defaults. Always decide intentionally:

| Function | Default padding |
|----------|----------------|
| `imfilter` | **Zero** |
| `medfilt2` | **Zero** |
| `ordfilt2` | **Zero** |
| `imgaussfilt` | **Replicate** |
| `medfilt3` | **Symmetric** |
| `modefilt` | **Symmetric** |

Zero padding is not always wrong — the effect depends on the kernel (sign, sum), data values near the border, and output class. For smoothing kernels on typical images, zeros pull border values down, producing a visible dark band. For zero-sum kernels (derivatives) or data where zero is a plausible continuation, zero padding may be appropriate.

**Padding options for `imfilter`:**

| Option | Behavior | When to use |
|--------|----------|-------------|
| `"replicate"` | Extends border pixels | Common choice for natural images |
| `"symmetric"` | Mirrors image at borders | Smooth natural images, avoids discontinuities |
| `"circular"` | Wraps around | Periodic signals (Fourier-consistent data) |
| Numeric value | Pads with that constant | When a specific background value is known (e.g., zero for masks) |

```matlab
h = fspecial("gaussian", 11, 2);
filtered = imfilter(img, h);              % Zero padding — may cause dark borders with smoothing kernels
filtered = imfilter(img, h, "replicate"); % Replicate padding — avoids border pull-down
```

**`imgaussfilt` uses replicate padding by default**, which is one reason it is preferred over `fspecial`+`imfilter` for Gaussian smoothing.

### Explicit Padding — `padarray`

For custom convolution, DL preprocessing, or frequency-domain filtering, pad explicitly:

```matlab
padded = padarray(img, [m n], "replicate");   % Replicate m rows, n cols on each side
padded = padarray(img, [m n], "symmetric");    % Mirror at borders
padded = padarray(img, [m n], "circular");     % Wrap around (periodic)
padded = padarray(img, [m n], 0);              % Zero-pad (any numeric scalar)
padded = padarray(img, [m n], "replicate", "pre");  % Pad only top/left
```

Default direction is `"both"` (pad before and after). Also accepts `"pre"` (top/left only) or `"post"` (bottom/right only). The `padsize` argument is `[rows cols]`.

## Output Class and Clipping

`imfilter` returns the same class as the input and performs double-precision accumulation internally before rounding and clipping to the output range. This matters for derivative and high-pass kernels:

```matlab
% Sobel edge kernel — response is signed
h = fspecial("sobel");
edges_clipped = imfilter(uint8(img), h);            % WRONG — negatives clip to 0
edges = imfilter(im2single(img), h, "replicate");   % RIGHT — preserves sign
edges_display = uint8(edges * 128 + 128);            % Offset only for visualization
```

**Rules:**
- Derivative/high-pass kernels produce negative values — filter in floating point, then offset only for display
- Integer output rounds fractions and clips to [0, intmax] — decide whether clipping is wanted
- When combining filter responses (e.g., gradient magnitude), compute in float first, then convert at the end

## Correlation vs Convolution

`imfilter` uses **correlation** by default, not convolution. For symmetric kernels this makes no difference. For asymmetric kernels (directional derivatives, motion blur):

```matlab
% Correlation (default) — kernel applied as-is
result = imfilter(img, h);

% Convolution — kernel flipped before applying
result = imfilter(img, h, "conv");
```

- Most `fspecial` kernels are symmetric (correlation = convolution); the `"motion"` kernel is asymmetric — use `"conv"` if convolution semantics are needed
- Custom asymmetric kernels: decide whether you want correlation or convolution and specify explicitly
- Even-sized kernels have an anchor at `floor((size(h)+1)/2)` — for a 4-by-4 kernel this is (2,2)

## Prefer Dedicated Functions Over `fspecial` + `imfilter`

| Old pattern | Modern replacement | Why |
|-------------|-------------------|-----|
| `fspecial('gaussian',n,s)` + `imfilter` | `imgaussfilt(img, sigma)` | Auto padding, auto filter size |
| `fspecial('average',n)` + `imfilter` | `imboxfilt(img, n)` | Simpler API, correct padding |
| Manual unsharp: `img + alpha*(img - blur)` | `imsharpen(img, Radius=r, Amount=a)` | Handles clipping, threshold option |
| `fspecial('sobel')` + `imfilter` for gradients | `imgradient(img)` / `imgradientxy(img)` | Returns magnitude+direction or Gx+Gy directly; supports Sobel, Prewitt, Roberts, central, intermediate methods |

`fspecial` is still useful for motion blur PSFs (`"motion"`), Laplacian (`"laplacian"`), and LoG (`"log"`) kernels where no dedicated function exists.

## Sharpening

```matlab
sharpened = imsharpen(img, "Radius", 2, "Amount", 1.5, "Threshold", 0.1);
```

- `Radius`: size of blur for unsharp mask (default 1)
- `Amount`: strength of sharpening (default 0.8)
- `Threshold`: minimum contrast to sharpen — **set this on noisy images** to prevent noise amplification

## Edge-Preserving Filters — When to Use Which

| Method | Tuning | Best for |
|--------|--------|----------|
| `imbilatfilt` | `degreeOfSmoothing`, `spatialSigma` | General edge-preserving smoothing. For RGB, convert to L\*a\*b\* first for perceptually uniform color smoothing |
| `imguidedfilter` | `DegreeOfSmoothing`, `NeighborhoodSize` | Edge-aware smoothing; guide can be the input itself, a separate image, or a different modality (see channel rules below) |
| `imdiffusefilt` | `NumberOfIterations`, `GradientThreshold` | Iterative — more iterations = stronger smoothing; strong noise, need fine control |
| `locallapfilt` | `sigma`, `alpha`, `NumIntensityLevels` | Multi-scale detail enhancement/smoothing |

Benchmark on representative data and hardware before choosing between these — relative performance depends on image size, parameter values, and platform.

### `imdiffuseest` — Parameter Estimation for Anisotropic Diffusion

Use `imdiffuseest` to estimate parameters rather than guessing:

```matlab
[gradThresh, numIter] = imdiffuseest(img);
filtered = imdiffusefilt(img, GradientThreshold=gradThresh, NumberOfIterations=numIter);
```

### `imguidedfilter` — Guidance Image Channel Rules

`DegreeOfSmoothing` is a variance threshold: neighborhoods with variance well below it get smoothed; those well above it are left mostly unchanged.

The guidance image `G` can differ from input `A` in number of channels:

| Input `A` | Guidance `G` | Behavior |
|-----------|-------------|----------|
| RGB | RGB | Each channel of `A` filtered using the corresponding channel of `G` |
| RGB | Grayscale | Each channel of `A` filtered using the same `G` |
| Grayscale | RGB | `A` filtered using combined color statistics of all three channels of `G` |

### `locallapfilt` — Parameters and Type Restriction

`locallapfilt` and `localcontrast` do **NOT** accept `double`. Convert first:

```matlab
% WRONG — errors on double input
result = locallapfilt(im2double(img), 0.4, 0.5);

% CORRECT — use single
result = locallapfilt(im2single(img), 0.4, 0.5);
```

**Parameters:**
- `sigma` — amplitude threshold separating "edges" from "details" (larger = more treated as detail)
- `alpha` — **< 1 enhances details, > 1 smooths details** (1 = no change). This is the opposite of what you might expect
- `beta` — dynamic range compression/expansion (< 1 compresses, > 1 expands; default 1)
- `NumIntensityLevels` — speed/quality tradeoff; lower = faster but coarser approximation
- `ColorMode` — `"luminance"` (default) processes only brightness; `"separate"` processes each channel

## Frequency-Domain Filtering

Use frequency-domain approaches when the requirement is naturally spectral (e.g., remove a periodic pattern) or when the spatial kernel is very large:

**When frequency-domain makes sense:**
- Removing periodic noise (banding, moiré) — design a notch filter in the frequency domain
- Very large filter kernels — FFT-based filtering can be faster than spatial convolution
- Custom frequency-selective operations not available as built-in spatial filters

**Pitfalls:**
- Sharp ideal cutoffs (brick-wall filters) cause ringing — use smooth transitions or windowed designs
- Direct FFT multiplication is circular convolution — pad the image to avoid wraparound artifacts
- Preserve phase unless you specifically want phase modification
- Frequency-sampling design can produce ripple; larger kernels reduce spatial extent but not height

For most denoising and smoothing tasks, spatial-domain filters are simpler and sufficient.

### Designing 2-D FIR Filters

Three approaches, all producing a spatial-domain kernel for use with `imfilter`:

**1. Frequency sampling (`fsamp2`)** — specify the desired frequency response on a grid, get a kernel whose response passes through those points:

```matlab
% Define desired response on an 11x11 frequency grid
Hd = zeros(11, 11);
Hd(4:8, 4:8) = 1;                        % Ideal low-pass in frequency domain
[f1, f2] = freqspace(11, "meshgrid");     % Normalized frequency grid [-1, 1]

% Design filter and inspect
h = fsamp2(Hd);
freqz2(h, [32 32]);                       % Visualize actual frequency response

% Apply
filtered = imfilter(img, h, "replicate");
```

Sharp transitions in `Hd` produce ripple in the spatial kernel. Increasing the grid size reduces the spatial extent of ripple but not its amplitude.

**2. Windowed design (`fwind1`)** — applies a 1-D window to reduce ripple from frequency sampling:

```matlab
h = fwind1(Hd, hamming(11));              % Circularly symmetric window via Huang's method
h = fwind1(Hd, win1, win2);              % Separable window from two 1-D windows
```

**3. Frequency transformation (`ftrans2`)** — transforms a 1-D FIR filter into a 2-D filter using the McClellan transform. **Requires `firpm` from Signal Processing Toolbox** for optimal 1-D design:

```matlab
b = firpm(10, [0 0.4 0.6 1], [1 1 0 0]);  % 1-D equiripple lowpass (Signal Processing Toolbox)
h = ftrans2(b);                             % 2-D filter via McClellan transform
filtered = imfilter(img, h, "replicate");
```

### Inspecting Filter Frequency Response

Use `freqz2` to visualize the actual frequency response of any 2-D FIR kernel:

```matlab
freqz2(h, [64 64]);                        % Mesh plot of magnitude response
[H, fx, fy] = freqz2(h, [64 64]);          % Return response for custom analysis
```

## Interpreting Filter Outputs — Not All Outputs Are Images

Some filtering operations produce **feature representations**, not enhanced images. The output is a measurement of local image structure, not a visually improved version of the input:

| Filter type | Output meaning | Typical use |
|-------------|---------------|-------------|
| Gabor filter bank (`imgaborfilt`) | Returns magnitude (one output) or `[mag, phase]` (two outputs) — magnitude indicates match strength at that orientation/frequency | Texture classification, feature engineering |
| Steerable filters | Orientation-selective responses | Edge/ridge detection, orientation estimation |
| Hessian-based vesselness (`fibermetric`) | Tubular structure likelihood | Vessel/fiber segmentation — preprocessing step, not a segmentor |
| LoG / Laplacian | Second-derivative response (signed) | Blob detection, zero-crossing edges |
| Filter-bank texture features | Multi-channel feature vectors per pixel | Segmentation, ML classification |

For Gabor filter response interpretation (magnitude, phase, normalization, real vs complex formulations), see the Gabor section in `texture-transforms.md`.

## Choosing an Implementation

Prefer the simplest approach that covers the operation. Benchmark on representative data and hardware before making performance claims:

1. **Dedicated function** — `imgaussfilt`, `medfilt2`, `imboxfilt`, `imsharpen`, etc. (fewest gotchas, internally optimized)
2. **`imfilter` with a designed kernel** — for custom linear filters (specify padding explicitly)
3. **`ordfilt2`** — for order-statistic / rank filters (generalized median)
4. **Vectorized / `blockproc`** — for non-overlapping tiled operations
5. **`nlfilter`** — arbitrary sliding-window function (per-pixel function call overhead — use only when no better option exists)

## Neighborhood Processing

For custom sliding-window operations not covered by built-in filters:

```matlab
% ordfilt2 — order-statistic filter (fast generalized median)
result = ordfilt2(img, 5, ones(3,3));  % 5th smallest in 3x3 = median

% blockproc — non-overlapping blocks (faster, for tiled operations)
fun = @(block_struct) std2(block_struct.data) * ones(size(block_struct.data));
result = blockproc(img, [32 32], fun);

% roifilt2 — filter only within a mask, leave the rest unchanged (grayscale)
% vertices of the mask polygon.
c = [222 272 300 270 221 194];
r = [21 21 75 121 121 75];
mask = roipoly(img,c,r);
h = fspecial("gaussian", 7, 2);
result = roifilt2(h, img, mask);              % Linear filter inside mask
result = roifilt2(img, mask, @(x) medfilt2(x));  % Custom function inside mask

% integralImage + integralBoxFilter — constant-time subregion summation
intImg = integralImage(img);               % Zero-padded on top and left
smoothed = integralBoxFilter(intImg, 11);  % Box filter via integral image

% nlfilter — arbitrary function on sliding neighborhood (slow, last resort)
result = nlfilter(img, [3 3], @(x) max(x(:)));
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Choosing filter by name, not noise model | Wrong filter for the artifact | Diagnose the noise type first, then select |
| `imfilter` without considering padding | Zero default can cause border artifacts with smoothing kernels | Choose padding intentionally — `"replicate"`, `"symmetric"`, `"circular"`, or zero if appropriate |
| `locallapfilt` alpha > 1 to enhance detail | Alpha > 1 **smooths** details | Use alpha < 1 to enhance details |
| `locallapfilt` on double | Type error — only single/integer | `locallapfilt(im2single(img), ...)` |
| High-pass kernel on uint8 input | Negatives clip to 0 | Use floating-point input for derivative kernels |
| Assuming `imfilter` does convolution | Default is correlation | Pass `"conv"` if convolution is needed |
| `fspecial('gaussian')` + `imfilter` | Slower, wrong default padding | Use `imgaussfilt(img, sigma)` |
| Sharpening noisy images | Amplifies noise | Set `"Threshold"` in `imsharpen` |
| `imgaussfilt` on data with Inf/NaN | Undefined behavior in frequency domain (the default `"auto"` mode may choose it) | Set `FilterDomain="spatial"` to contain Inf/NaN propagation |
| Expecting `imnlmfilt` to preserve all texture | Can smooth textured regions | Verify on a representative patch; tune `DegreeOfSmoothing` |
| `nlfilter` for everything custom | Extremely slow | Try `ordfilt2`, `blockproc`, or vectorized code first |
| Displaying feature-map output as an enhanced image | Feature responses are measurements, not improved images | Use for classification/segmentation; see `texture-transforms.md` for Gabor specifics |

----

Copyright 2026 The MathWorks, Inc.

----
