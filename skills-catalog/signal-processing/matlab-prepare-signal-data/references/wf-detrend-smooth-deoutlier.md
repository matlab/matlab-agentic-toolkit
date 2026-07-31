# Workflow: detrend + smooth + de-outlier a single channel

> Functions used: `filloutliers`, `hampel`, `medfilt1`, `detrend`, `smoothdata`, `sgolayfilt`

Condition one noisy channel before analysis: remove spikes, remove drift,
then smooth what remains. Three steps, and the **order matters** - do them in
the wrong order and each step corrupts the next.

> **Off-ramp.** If the "noise" you want gone has a frequency story you can name
> in Hz (60 Hz hum, a noise floor above 100 Hz), this is a filter job, not a
> data-cleaning job - use `highpass` / `lowpass` / `bandpass` directly. This
> workflow is for the case where the input has a **stationary character**
> (sparse spikes, smooth polynomial drift, broadband wiggle) and no clean
> cutoff frequency.

## When to use this

Reach for this recipe when the channel shows some combination of:

- **Sparse spikes / dropouts** - a few samples far off the local level.
- **Slow baseline drift** - a smooth wander over the record (thermal,
  sensor drift, gravitational).
- **Residual high-frequency wiggle** - broadband noise on top of the signal.

The core lesson: when the input looks like this, **data-cleaning
primitives beat DSP filters**. `detrend(x, n)` removes polynomial drift exactly
with unity passband gain; `filloutliers` fixes spikes without touching clean
samples. Filters have transition bands that touch the signal of interest.
Reach for the primitives first; reach for a filter only when you can name a
frequency.

## Why the order is outliers -> detrend -> smooth

Each step assumes the previous one ran:

- **Outliers first.** A single spike wrecks a polynomial fit - `detrend`
  minimizes squared error, so one outlier tilts the whole trend line.
  Remove spikes before you fit anything.
- **Detrend second.** Smoothing a signal that still has drift just produces a
  smooth version of the drift. Get the baseline flat before you smooth.
- **Smooth last.** Once spikes and drift are gone, whatever wiggle remains is
  the broadband noise you actually want to reduce.

Do not smooth first: smoothing spreads a spike across its whole window
(turning one bad sample into `win` mildly-bad samples) and bakes the drift
into the result.

## Recipe

### Step 1 - Remove outliers

Pick the outlier tool by spike density and whether you need an audit trail:

| Situation | Reach for | Detail |
|---|---|---|
| Sparse spikes; want a smooth fill across the spike | `filloutliers(x, "linear" \| "pchip", "movmedian", win)` | fn-filloutliers.md |
| Sparse spikes; do not care about the fill rule | `filloutliers(x, "clip", "movmedian", win)` | fn-filloutliers.md |
| Sparse spikes; want to know which samples were flagged | `hampel(x, k, nsigma)` (returns mask + local median + local sigma) | fn-hampel.md |
| Baseline drifts, so a global threshold misleads | `filloutliers(x, fill, "movmedian", win)` (or `hampel`) | fn-filloutliers.md |
| Dense impulse noise (>10% of samples corrupted) | `medfilt1(x, n)` | fn-medfilt1.md |

**Anti-pattern.** Do not use `medfilt1` for sparse spikes. It is a denoiser
that replaces *every* sample with a local median, distorting clean samples
too. It earns its place only when the burst is so dense that windowed
detection has no "normal" majority to compare against.

```matlab
% Sparse spikes, drifting baseline -> movmedian detection, smooth fill:
xc = filloutliers(x, "pchip", "movmedian", 25);
```

### Step 2 - Remove the trend

Pick the detrend tool by whether you can describe the drift's shape:

| Situation | Reach for | Detail |
|---|---|---|
| Drift is smooth and slow, looks polynomial | `detrend(x, n)` for `n` in {1, 2, 3} | fn-detrend.md |
| Drift jumps at known points (sensor reset, calibration) | `detrend(x, n, bp, Continuous=false)` | fn-detrend.md |
| Drift is oscillatory or non-stationary; no polynomial fits | `x - smoothdata(x, "lowess"\|"loess", win)` | lowess = local linear (steadier vs noise), loess = local quadratic (follows curvier trends); fn-smoothdata.md |
| Drift band is well below signal band, shape unknown | `highpass(x, fc, fs)` | base SPT filter; pick `fc` below signal band |
| Remove only the mean | `detrend(x, 0)` | fn-detrend.md |

**Escalate the polynomial degree before switching to a filter.** If a linear
`detrend` leaves a smooth low-frequency bend, escalate `n` (2, then 3) before
reaching for `highpass` - a smooth drift is often a low-order polynomial that
`detrend` removes exactly with unity passband gain. Switch to `highpass` or
`smoothdata("lowess")` only when the drift is genuinely oscillatory or
non-stationary. Full rationale, the escalation example, and when the polynomial
is genuinely wrong: fn-detrend.md.

### Step 3 - Smooth the residual noise

`smoothdata` is the dispatcher and the default first reach. `sgolayfilt` is
the escape hatch for the two cases `smoothdata` cannot cover cleanly.

| Situation | Reach for | Detail |
|---|---|---|
| General smoothing, no special story | `smoothdata(xd)` (default `"movmean"`) or `smoothdata(xd, "gaussian")` | fn-smoothdata.md |
| Outliers might remain (belt-and-braces) | `smoothdata(xd, "movmedian", win)` | fn-smoothdata.md |
| Peak shapes / derivatives matter (spectra, chromatograms, transients), degree 2 fine | `smoothdata(xd, "sgolay", fl)` | fn-smoothdata.md |
| Peak shapes matter and you need degree 3-4, or the FIR/weighted form | `sgolayfilt(xd, m, fl)` | fn-sgolayfilt.md |
| Named cutoff frequency in Hz | `lowpass(xd, fc, fs)` | base SPT filter; use when a Hz cutoff separates noise from signal |
| Non-stationary, multi-scale noise a tuned `sgolayfilt` cannot remove without blurring features | `wdenoise(xd, ...)` (Wavelet Toolbox) | escalation only; wf-denoise.md |

**`sgolayfilt` has no defaults** - both `m` (order) and `fl` (odd frame
length, `>= 2*m+1`) are required. If you find yourself wanting the defaults,
you want `smoothdata`.

```matlab
y = smoothdata(xd, "gaussian");        % default first reach
% peaks matter and degree 2 is not enough:
y = sgolayfilt(xd, 3, 11);             % order 3 over an 11-sample frame
```

## Worked end-to-end example

```matlab
% Sparse spikes + smooth cubic drift + broadband wiggle, no named cutoff.
xc = filloutliers(x, "pchip", "movmedian", 25);   % 1. spikes gone, clean fill
xd = detrend(xc, 3);                              % 2. cubic drift removed exactly
y  = smoothdata(xd, "gaussian");                  % 3. residual noise smoothed
```

## Next in the chain

- **Fill NaN gaps** left after outlier removal, before detrending, if any
  step introduced or exposed missing samples -> fn-fillmissing.md /
  fn-fillgaps.md.
- **Hand-off to `trainnet` / `dlarray`** once the channel is conditioned ->
  wf-handoff-to-dl.md.

----

Copyright 2026 The MathWorks, Inc.

----
