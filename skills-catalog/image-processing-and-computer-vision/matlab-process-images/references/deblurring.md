# Image Deblurring & Restoration

Decision guidance for choosing and using deconvolution methods, PSF estimation, and artifact suppression.

> **Often loaded with:** `image-io.md` (loading blurred image), `quality-assessment.md` (measuring restoration quality).

## Choosing a Deconvolution Method

| Method | PSF known? | Noise level | Quality | Speed | Use when |
|--------|-----------|-------------|---------|-------|----------|
| `deconvwnr` | Yes | Known or estimated | Good | Fast | PSF and noise estimate both available |
| `deconvlucy` | Yes | Any (iterative) | Best | Slow | Best quality needed, can afford iterations |
| `deconvreg` | Yes | Known | Good | Fast | Want regularization without tuning iterations |
| `deconvblind` | No (estimated) | Any | Variable | Slowest | PSF unknown — must estimate from image |

**Default recommendation:** Use `deconvlucy` with `edgetaper` — it handles noise well and doesn't require a noise estimate.

## Critical: Always Use `edgetaper`

All deconvolution methods produce **severe ringing artifacts at image borders** unless you pre-process with `edgetaper`:

```matlab
% WRONG — ringing at edges
restored = deconvwnr(blurred, PSF, NSR);

% CORRECT — suppress edge artifacts first
tapered = edgetaper(blurred, PSF);
restored = deconvwnr(tapered, PSF, NSR);
```

`edgetaper` produces a weighted sum of the original image and a blurred version near the borders, reducing the discontinuity that causes Gibbs ringing. **Use it before every deconvolution call.**

## PSF Construction

| Blur type | PSF function | Parameters |
|-----------|-------------|------------|
| Gaussian (out-of-focus-like) | `fspecial("gaussian", size, sigma)` | `size`: kernel width, `sigma`: blur radius |
| Motion (linear camera shake) | `fspecial("motion", len, theta)` | `len`: motion length (pixels), `theta`: angle (degrees) |
| Disk (defocus/bokeh) | `fspecial("disk", radius)` | `radius`: blur disk radius |

All PSFs sum to 1.0 by construction.

**Estimating PSF size:** If you don't know the blur parameters, examine the degraded image — motion streaks suggest length/angle; star points or edge spread indicate radius.

## `deconvwnr` — Wiener Deconvolution

Fastest. Requires PSF and noise-to-signal ratio (NSR):

```matlab
tapered = edgetaper(blurred, PSF);
restored = deconvwnr(tapered, PSF, NSR);
```

### Estimating NSR

```matlab
% If noise variance is known:
NSR = noiseVariance / var(blurred(:));

% If unknown, try small values and inspect:
restored = deconvwnr(tapered, PSF, 0.01);  % Start here, increase if noisy
```

**Gotcha:** Without NSR (or NSR=0), Wiener filter amplifies noise catastrophically. Always provide a non-zero NSR.

> **`deconvwnr` requires `double` inputs.** If your image is `single`, use `im2double` before deconvolution. This overrides the general "prefer `im2single`" convention — the deconvolution functions require `double`.

**Output can exceed [0,1]** — clip after deconvolution if needed for display/saving.

## `deconvlucy` — Lucy-Richardson

Iterative, non-negativity constrained, handles Poisson noise well:

```matlab
tapered = edgetaper(blurred, PSF);
restored = deconvlucy(tapered, PSF, numIterations);
```

### Choosing Iterations

- Default: 10. Often too few for strong blur.
- More iterations = sharper but noisier (noise amplification)
- **Sweet spot:** 20–50 iterations for moderate blur. Inspect visually.

### Damping Parameter (Prevent Noise Amplification)

```matlab
dampar = sqrt(noiseVariance);  % Suppress changes smaller than noise level
restored = deconvlucy(tapered, PSF, 30, dampar);
```

Pixels where the residual is below `dampar` are not updated — prevents noise amplification in smooth regions.

### Iteration Strategy

Too few iterations: still blurry. Too many: noise artifacts (ringing at edges, speckle in flat regions).

```matlab
% Inspect at multiple iteration counts
for nIter = [10 20 30 50]
    result = deconvlucy(tapered, PSF, nIter);
    fprintf("Iter %d: range=[%.3f, %.3f]\n", nIter, min(result(:)), max(result(:)));
end
```

## `deconvreg` — Regularized Deconvolution

Constrained least-squares approach — minimizes `||y - H*x||² + λ||L*x||²` balancing fit vs smoothness, where `λ` is the Lagrange multiplier (`lagra` in the docs).

### Calling Forms

```matlab
tapered = edgetaper(blurred, PSF);

% Form 1: Automatic lagra from noise power (NP)
NP = numel(blurred) * noiseVariance;  % Total noise power
restored = deconvreg(tapered, PSF, NP);

% Form 2: Explicit Lagrange multiplier (4th arg = scalar lrange → used as lagra)
restored = deconvreg(tapered, PSF, 0, lagra);
% lagra ≈ 0.001 → sharper, noisier
% lagra ≈ 0.01  → balanced (good default)
% lagra ≈ 0.1   → smoother, less noise

% Form 3: Custom regularization operator
restored = deconvreg(tapered, PSF, 0, lagra, regop);
```

### Regularization Operator

The default operator is the discrete Laplacian (penalizes high frequencies, promotes smoothness). You can pass a custom operator, but in practice results are insensitive to the choice — even `regop = 1` (identity) works nearly as well.

## `deconvblind` — Blind Deconvolution

When the PSF is unknown — estimates both the restored image and the PSF simultaneously:

```matlab
PSF_init = ones(psfSize) / psfSize^2;  % Initial guess: uniform square
[restored, PSF_estimated] = deconvblind(edgetaper(blurred, PSF_init), PSF_init, numIterations);
```

### Key Considerations

- **Can degrade the image.** Always compare the output against the input (PSNR, SSIM) — if the restored image scores worse, blind deconvolution has failed. Prefer `deconvlucy`/`deconvwnr` with an estimated PSF when possible.
- **PSF initial size matters:** Must be large enough to contain the true PSF. Too large = slow and noisy.
- **Converges slowly:** Often needs 50+ iterations.
- **Sensitive to noise:** Works best with low-noise images.
- **Output PSF sums to 1** and represents the estimated blur kernel.

**Practical tip:** If you have *any* knowledge of the PSF type (Gaussian? motion?), use that as the initial guess rather than a uniform square.

## Color Image Deblurring

Deconvolution functions (`deconvlucy`, `deconvwnr`, `deconvreg`, `deconvblind`) accept RGB images directly — no per-channel loop needed:

```matlab
tapered = edgetaper(blurred, PSF);
restored = deconvlucy(tapered, PSF, 30);
```

**Do not** convert to grayscale and deconvolve — this discards color information permanently.

## Post-Processing Deconvolution Output

Deconvolution outputs often contain values outside valid range:

```matlab
% Clip to valid range
restored = max(0, min(1, restored));  % For double [0,1]

% Or for display/saving
imwrite(im2uint8(max(0, min(1, restored))), "restored.png");
```

## Decision Flowchart

```
Is the PSF known?
├── YES: Is the noise level known?
│   ├── YES → deconvwnr (fast, good quality)
│   └── NO → deconvlucy (iterative, robust to unknown noise)
└── NO → deconvblind (slow, less reliable)

In all cases: always apply edgetaper first!
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Skipping `edgetaper` | Severe ringing at image borders | Always: `edgetaper(img, PSF)` before deconvolution |
| `deconvwnr` without NSR | Noise amplification (output range explodes) | Always provide NSR > 0 |
| Too many Lucy-Richardson iterations | Noise amplification, ringing | Start at 20, increase cautiously; use `dampar` |
| `deconvblind` PSF init too small | Can't capture the true blur extent | Make init size ≥ expected PSF extent |
| Expecting output in [0,1] | Deconvolution can exceed valid range | Clip: `max(0, min(1, result))` |
| Using PSF that doesn't sum to 1 | Brightness shift in output | Use `fspecial` (auto-normalized) or normalize manually |

----

Copyright 2026 The MathWorks, Inc.

----
