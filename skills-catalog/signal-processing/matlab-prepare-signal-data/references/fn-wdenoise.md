# Function: `wdenoise`

> Used in: wf-denoise.md
> Toolbox: **Wavelet Toolbox** (separate license - NOT Signal Processing Toolbox)

Wavelet signal denoising. Decomposes the signal into wavelet coefficients,
thresholds the detail coefficients per scale, and reconstructs. Its value
over a moving-average smoother is that it can KILL broadband noise while
PRESERVING sharp transients - large coefficients survive the threshold,
small (noise) coefficients get shrunk.

## License gate - check before calling

`wdenoise` needs Wavelet Toolbox (absent from a plain Signal Processing or
base-MATLAB install). Guard the call with
`license("test","Wavelet_Toolbox") && ~isempty(which("wdenoise"))` and fall
back to `sgolayfilt` when it is unavailable. See wf-denoise.md for the fallback
rationale.

## Signature

```matlab
XDEN = wdenoise(X)
XDEN = wdenoise(X, LEVEL)
XDEN = wdenoise(___, Name=Value)
[XDEN, DENOISEDCFS]          = wdenoise(___)
[XDEN, DENOISEDCFS, ORIGCFS] = wdenoise(___)
```

- `X` - vector, matrix, or timetable. All values must be finite and
  nonsparse. A matrix is denoised **column-wise** (one signal per column).
  A vector needs at least 2 samples; a matrix/timetable at least 2 rows.
  `wdenoise` **assumes uniform sampling** - a timetable with non-linearly
  spaced timestamps triggers a warning (regularize it first,
  wf-uniform-rate.md).
- `LEVEL` - level of wavelet decomposition, positive integer
  `<= floor(log2 N)`. Default is `min(floor(log2 N), wmaxlev(N,"sym4"))`.
- `XDEN` - denoised signal, same type/shape as `X`. For timetable input it
  keeps the original variable names and timestamps.
- `DENOISEDCFS` / `ORIGCFS` - cell arrays of the denoised / original
  wavelet+scaling coefficients, decreasing resolution; the last element is
  the approximation (scaling) coefficients. Return these only if you need to
  inspect the coefficients.

## Name-value pairs (full surface)

| NV-pair | Default | Values / purpose |
|---|---|---|
| `Wavelet` | `"sym4"` | Orthogonal or biorthogonal wavelet name. Orthogonal families: `"db"`, `"sym"`, `"coif"`, `"haar"`, `"fk"`, `"bl"`, `"beyl"`, `"han"`, `"mb"`, `"vaid"`. Biorthogonal: `"bior"`, `"rbio"`. Must be orthogonal or biorthogonal (not a continuous-only wavelet). |
| `DenoisingMethod` | `"Bayes"` | `"Bayes"` (empirical Bayes, Cauchy prior), `"BlockJS"` (block James-Stein), `"FDR"` (false discovery rate; best for sparse data), `"Minimax"`, `"SURE"` (Stein's unbiased risk estimate), `"UniversalThreshold"` (sqrt(2 ln N)). |
| `ThresholdRule` | method-dependent | Shrink rule for detail coefficients. Valid options depend on `DenoisingMethod` (see table below). |
| `NoiseEstimate` | `"LevelIndependent"` | `"LevelIndependent"` estimates noise variance from the finest-scale coefficients; `"LevelDependent"` estimates it per resolution level (use for colored noise). No effect with `"BlockJS"` (always level-independent). |

### `ThresholdRule` valid options per method

| `DenoisingMethod` | Valid `ThresholdRule` | Default | Notes |
|---|---|---|---|
| `"Bayes"` | `"Median"`, `"Mean"`, `"Soft"`, `"Hard"` | `"Median"` | Posterior rule. |
| `"SURE"`, `"Minimax"`, `"UniversalThreshold"` | `"Soft"`, `"Hard"` | `"Soft"` | Classical shrinkage. |
| `"BlockJS"` | `"James-Stein"` only | - | No need to set; only option. |
| `"FDR"` | `"Hard"` only | - | No need to set; only option. |

`"Soft"` shrinks surviving coefficients toward zero (smoother output, may
blunt peaks). `"Hard"` keeps them unchanged (sharper, retains more noise).

### `"FDR"` Q-value (special form)

`"FDR"` takes an optional Q-value (proportion of false positives,
`0 < Q <= 1/2`, default `0.05`). Pass it as a cell array:

```matlab
xden = wdenoise(x, DenoisingMethod={"FDR", 0.01});
```

## Defaults in one call

`wdenoise(x)` = `sym4` wavelet, empirical `Bayes` method, posterior
`Median` threshold rule, `LevelIndependent` noise estimate, auto level. This
is the recommended first call; tune one knob at a time from there
(wf-denoise.md has the "when to change each knob" table).

## Gotchas

- **Wavelet Toolbox license required** - the single most common failure for
  code that reaches for `wdenoise`. Guard with `license("test",...)`.
- **Assumes uniform sampling.** Non-uniform timetable input only warns, it
  does not resample. Align onto a regular grid first.
- **Column-wise on matrices.** Each column is an independent signal. If your
  signals are in rows, transpose first.
- **`LEVEL` is capped** at `floor(log2 N)`. For `"BlockJS"` there must be
  `floor(log2 N)` coefficients at the coarsest level.
- **Bayes wants samples.** The empirical Bayes method estimates a mixture
  weight from the data, so it works better with more samples. On very short
  signals prefer `"UniversalThreshold"` or `"Minimax"`.
- **Code generation:** timetable input is not supported for C/C++ or GPU
  codegen, and `Wavelet` must be a `coder.Constant`.

## See also

- wf-denoise.md - when to reach for `wdenoise` vs. `smoothdata` /
  `sgolayfilt` / `lowpass`, plus the license fallback.
- `sgolayfilt`, `smoothdata` (Signal Processing Toolbox / base MATLAB) -
  the no-extra-license alternatives.
- `wdenoise2` (2-D), `wavedec`, `thselect` (Wavelet Toolbox).

## Version history

Introduced in Wavelet Toolbox in R2017b.

----

Copyright 2026 The MathWorks, Inc.

----
