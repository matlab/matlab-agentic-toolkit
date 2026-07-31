# Workflow: extract a signal's envelope

> Functions used: `envelope`

Extract the amplitude outline of a signal - the smooth curve that rides the
peaks (and troughs) rather than the signal itself. This mirrors the
**Envelope** pane in Signal Analyzer's preprocessing.

> **Off-ramp - do you actually want the envelope, or a cleaner signal?**
> `envelope` is NOT a denoiser. It returns the AMPLITUDE OUTLINE, discarding
> the carrier. If you want a cleaned version of the signal itself, you're in
> the denoise family - see wf-denoise.md, not here.

## When to reach for it (distinct from smoothing)

Reach for `envelope` when the *amplitude trend* is the quantity of interest,
not the signal:

- **AM demodulation** - recover the modulating envelope of an
  amplitude-modulated carrier.
- **Amplitude / energy tracking** - how loud is this over time (audio RMS
  loudness, vibration amplitude, burst energy).
- **Peak-hull tracking** - the upper/lower bound curve that hugs an
  oscillation (decaying sinusoid outline, fault-signature amplitude).
- **Feature for ML** - the envelope is often a more stable input than the
  raw carrier for classifying amplitude-varying signals.

How this differs from smoothing (wf-denoise.md): a smoother returns a signal
that still oscillates, just with less noise. `envelope` returns a curve that
does NOT oscillate at the carrier frequency - it traces the peaks. If your
answer still has the carrier in it, you wanted smoothing; if it's the outline
above/below the carrier, you wanted envelope.

## Choosing the method

`envelope` has three methods; the method is the third positional argument.

| Method | Call | Use when |
|---|---|---|
| **analytic** (default) | `envelope(x)` or `envelope(x, fl, "analytic")` | Narrowband / AM-style signals. Uses the Hilbert transform of an FIR-filtered version; `fl` is the Hilbert filter length. The smooth analytic envelope. Default when you call `envelope(x)` or `envelope(x, fl)`. |
| **rms** | `envelope(x, wl, "rms")` | Energy / loudness tracking. Moving-RMS over a window of `wl` samples. Good for audio level and vibration amplitude. |
| **peak** | `envelope(x, np, "peak")` | Peak-hull / spline-through-peaks. Fits a spline over local maxima (and minima) separated by at least `np` samples. Good for tracing a decay envelope or a jagged peak outline. |

Both an upper and a lower envelope come back:
`[yupper, ylower] = envelope(...)`.

## Choosing the length parameter

The second positional argument means something different per method:

- **analytic**: `fl` = Hilbert FIR filter length. Larger `fl` = smoother,
  more selective envelope but more edge transient. Start modest (tens of
  samples) and increase if the envelope is too jagged.
- **rms**: `wl` = window length in samples. Set it to roughly one period of
  the slowest amplitude variation you want to follow. Too short tracks the
  carrier; too long over-smooths the amplitude trend.
- **peak**: `np` = minimum peak separation in samples. Set it near the
  carrier period so the spline hits one peak per cycle, not the noise
  wiggles between peaks.

## Recipe

```matlab
% Analytic (default) - AM demod / narrowband amplitude
[yup, ylo] = envelope(x, fl, "analytic");

% RMS - loudness / energy over a wl-sample window
[yup, ylo] = envelope(x, wl, "rms");

% Peak - spline hull over peaks at least np samples apart
[yup, ylo] = envelope(x, np, "peak");
```

1. Confirm you want the amplitude outline, not a cleaned signal
   (if you want the signal cleaned, see wf-denoise.md).
2. Pick the method from the table (AM/narrowband -> analytic; energy -> rms;
   peak hull -> peak).
3. Set the length parameter relative to the carrier period as above.
4. Overlay `yupper` (and `ylower`) on the original to confirm it hugs the
   peaks without tracking the carrier or over-smoothing.
5. Emit a runnable `.m` script.

## Gotchas

- **`envelope` needs the Signal Processing Toolbox** (not a separate license
  like `wdenoise`, but not base MATLAB either).
- **It discards the carrier by design** - do not use it expecting a denoised
  signal.
- **Column-wise on matrices** - each column is an independent channel.
- **Edge transients** on the analytic method grow with `fl`; the first/last
  `~fl/2` samples of the envelope are less reliable.

## Signatures & mechanism (folded from the function detail)

```matlab
[yupper, ylower] = envelope(x)                 % analytic via DFT hilbert (exact, full-length)
[yupper, ylower] = envelope(x, fl, "analytic") % analytic via length-fl Hilbert FIR
[yupper, ylower] = envelope(x, wl, "rms")      % moving RMS over wl-sample window
[yupper, ylower] = envelope(x, np, "peak")     % spline through peaks >= np samples apart
envelope(___)                                  % no output args -> plots signal + envelopes
```

- `envelope(x)` (DFT `hilbert`) and `envelope(x, fl, "analytic")` (FIR) are
  **distinct algorithms**, not one call with a default — passing a length
  switches from the DFT `hilbert` to the FIR Hilbert filter (which is where the
  edge transients come from; the first/last ~`fl/2` samples are less reliable).
- `x` is processed **column-wise** on a matrix (one channel per column).
- Primitives behind the three methods: `hilbert`, `findpeaks`, `movmean` /
  `movmax` / `movmin`, `rms`. Signal Processing Toolbox; introduced R2015b.

## Related

- If you actually wanted to clean the signal: wf-denoise.md.

----

Copyright 2026 The MathWorks, Inc.

----
