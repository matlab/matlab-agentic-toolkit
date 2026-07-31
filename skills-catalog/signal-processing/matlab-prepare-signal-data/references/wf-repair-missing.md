# Workflow: repair missing samples (fill NaN gaps)

> Functions used: `fillmissing`, `fillgaps`, `isoutlier`, `filloutliers`

A single channel has NaN gaps (dropouts, corrupted transmission, sensor
outages). Fill them so downstream analysis runs, without fabricating content
that the downstream will mistake for signal. The whole decision is one
question: interpolate (`fillmissing`) or model-and-extrapolate (`fillgaps`).

> **Off-ramp.** If the "gaps" are actually spikes/outliers (finite bad values,
> not NaN), that is deoutliering, not gap-filling. See
> wf-detrend-smooth-deoutlier.md and fn-filloutliers.md. If you need to
> resample onto a *different* time grid rather than fill at known indices, use
> `interp1` (or `retime` for a timetable).

## When to use

Use this workflow when the signal has `NaN` at known sample indices and you
want values back on the same grid. The failure mode this exists to prevent:
cold agents do not know `fillgaps` exists and invent function names
(`regularizeNaNs`, `inpaintn` are not real), or they reach for `fillmissing`
interpolation on a long gap in an oscillatory signal and silently corrupt the
spectrum.

## Recipe

### Step 1 — Characterize the gaps and the downstream

Two facts decide everything: how wide is the widest gap, and what does the
downstream analysis measure.

```matlab
gapWidths = diff(find(~isnan(x)));      % run lengths between valid samples
maxGap = max(gapWidths) - 1;            % widest NaN run
```

- **Downstream is spectral** (FFT, PSD, spectrogram, tone detection)? The fill
  rule matters a lot; a bad fill shows up as spurious frequency content.
- **Downstream is time-domain** (statistics, plotting, thresholding)? Almost
  any smooth fill is fine.

### Step 2 — Pick the filler

**"Short" vs "long" is relative to the signal's frequency, not an absolute
sample count.** What matters is the gap width in *cycles* of the frequency you
care about: `gapSamples * f / fs` (equivalently `gapSeconds * f`). A 200-sample
gap is trivial for a 10 kHz tone at fs=1 MHz but spans many cycles of an 8 Hz
tone at fs=160 Hz. Convert the gap to cycles before deciding.

| Situation | Reach for | Detail |
|---|---|---|
| Gap spans << 1 cycle of your highest frequency of interest, generic downstream | `fillmissing(x, "pchip")` | fn-fillmissing.md |
| Same, time-domain downstream | `fillmissing(x, "linear")` | fn-fillmissing.md |
| Gap spans >= ~1/2 cycle of the lowest frequency, oscillatory signal, spectral downstream | `fillgaps(x, maxlen, order)` | fn-fillgaps.md |
| Wide gap, non-stationary, no AR model applies | `fillmissing(x, "spline", MaxGap=N)` + disclose | fn-fillmissing.md |

Leading/trailing (edge) gaps are not a separate category - apply the same gates below.

**Rule of thumb — two gates, both must hold for `fillgaps`.** (1) *Spectral +
wide:* downstream is FFT/PSD/spectrogram AND a gap is wider than ~half a cycle
of the lowest frequency you care about (`maxGap > fs/(2*fLow)`). (2)
*AR-suitable:* the signal is **oscillatory / quasi-stationary** — a dominant
tone, resonance, or periodicity an AR model can continue through the gap. If
gate 2 fails — the signal is noise-like, a monotonic trend, or a one-off
transient with no periodic structure — AR extrapolation has nothing to lock
onto, so use `fillmissing` even when the gap is wide. **Quick check:** look at a
clean window just before the gap — clear repeating cycles / a peaky spectrum ⇒
`fillgaps` will track it; looks like noise or a ramp ⇒ `fillmissing`. When
unsure, fill both ways and overlay: `fillgaps` should continue the oscillation,
not flatten it.

**AR fitting also needs enough surrounding samples.** Separately from the
gap-width question: `fillgaps` fits an AR model from the non-missing samples, so
it needs a healthy run of good data around each gap (short signals or sparse
data starve the fit - cap `maxlen` and drop to a low fixed `order`). See
fn-fillgaps.md.

**Edge (leading/trailing) gaps are the same oscillatory-vs-not split, not a
separate rule.** An endpoint gap has valid data on only *one* side, so
interpolation cannot bracket it: `fillmissing(..., EndValues="nearest"/"linear")`
holds the last value or extrapolates a straight ramp, which flattens an
oscillation into spurious low-frequency content. `fillgaps` fits a **one-sided**
AR model (forward AR for a trailing gap, reverse AR for a leading gap) and
continues the tone through the endpoint. So for an oscillatory signal, prefer
bare `fillgaps(x)` on edge gaps too; reserve the `EndValues=` forms for
non-oscillatory signals where a hold/ramp is honest.

**Anti-pattern.** Do not invent a filler. `regularizeNaNs`, `inpaintn`, and
similar names are not MATLAB functions. The two real choices are `fillmissing`
(base MATLAB, interpolation) and `fillgaps` (SPT, AR model).

### Step 3 — The `fillmissing` (interp) vs `fillgaps` (AR) decision

The two are indistinguishable on **short** gaps. They diverge on **long** gaps
in oscillatory signals: `fillmissing` interpolates a smooth ramp that flattens
the oscillation (spurious low-frequency content in a spectrum), while `fillgaps`
continues the tone through the gap and preserves the spectrum.

- **Spectral downstream** (FFT/PSD/spectrogram) with a gap wider than ~half a
  cycle of the lowest frequency of interest -> `fillgaps`. See fn-fillgaps.md
  for the AR mechanism and the worked spectrum comparison.
- **Time-domain downstream**, or short gaps -> `fillmissing` is simpler and fine.

### Step 4 — Fill, verify, disclose

Take the mask output so you can confirm what was filled:

```matlab
[xFilled, filledMask] = fillmissing(x, "pchip");
nnz(filledMask)                          % how many samples were fabricated
```

If any gap was too wide to fill honestly, gate it with `MaxGap` so it stays
NaN rather than becoming a fabricated ramp, and tell the downstream consumer:

```matlab
xFilled = fillmissing(x, "spline", MaxGap=50);   % gaps wider than 50 stay NaN
```

Disclose any gap you did fill in a long-gap or non-stationary case. A filled
gap is synthesized data, not measurement.

## Worked end-to-end example

```matlab
% Oscillatory signal with a long dropout, spectral downstream.
fs = 160;
maxGap = max(diff(find(~isnan(x)))) - 1;

if maxGap > fs/(2*lowestFreqOfInterest)      % gap wider than ~half a cycle
    xFilled = fillgaps(x, 4*maxGap, "aic");  % AR model preserves the spectrum
else
    xFilled = fillmissing(x, "pchip");        % short gap: interpolation is fine
end

P = pspectrum(xFilled, fs);                   % spectrum is not corrupted by the fill
```

## Next in the chain

- **Outliers rather than NaN** (finite bad values, spikes) ->
  wf-detrend-smooth-deoutlier.md, fn-filloutliers.md.
- **Resample onto a new grid** instead of filling at known indices -> `interp1`
  / `retime`.

----

Copyright 2026 The MathWorks, Inc.

----
