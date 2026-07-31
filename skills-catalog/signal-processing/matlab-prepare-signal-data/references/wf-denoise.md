# Workflow: wavelet denoising (the escalation beyond `smoothdata`/`sgolayfilt`)

> Functions used: `wdenoise` (Wavelet Toolbox), fallback `sgolayfilt` / `smoothdata`

Smoothing and denoising are one family - MATLAB groups `smoothdata`,
`sgolayfilt`, `medfilt1`, and friends under "Smoothing and Denoising". For a
broadband-noisy signal, do the smoothing there: the Step 3 matrix in
wf-detrend-smooth-deoutlier.md picks between `lowpass` (named cutoff),
`sgolayfilt` / `smoothdata("sgolay")` (features must survive), and
`smoothdata` (general).

This page is only the **wavelet escalation**: `wdenoise` sits outside that base
family (it needs Wavelet Toolbox) and is the reach-for when a tuned
`sgolayfilt` still cannot remove multi-scale noise without blurring features.

## When `wdenoise` earns the dependency

Reach for it only when ALL of these hold:
- The signal is genuinely non-stationary - features at very different scales,
  bursts, changing character over time.
- A frame-length-tuned `sgolayfilt` still leaves noise you cannot remove
  without blurring the features you care about.
- You can invest in choosing the wavelet and level (the defaults are not a
  free win - see below).

Otherwise stay in the smoothing family (wf-detrend-smooth-deoutlier.md, Step 3).

`wdenoise` thresholds coefficients per scale, so it can keep a high-amplitude
transient while shrinking low-amplitude broadband noise. But with defaults
(`sym4`, Bayes) it often widens narrow pulses MORE than a well-chosen
`sgolayfilt`; the per-scale advantage shows up only when the wavelet and level
match the feature scale.

## Toolbox gate

`wdenoise` needs **Wavelet Toolbox** (a separate license, not SPT or base
MATLAB). Guard the call and fall back to `sgolayfilt` / `smoothdata` when the
license is absent; note the substitution in a script comment. Call
`wdenoise(x)` first (sensible defaults), then tune one knob at a time.
Signature and the full knob table: fn-wdenoise.md.

## Recipe

1. Confirm you are actually past what the smoothing family can do
   (wf-detrend-smooth-deoutlier.md Step 3) - `wdenoise` is the escalation, not
   the first reach.
2. Guard on the Wavelet Toolbox license; fall back to `sgolayfilt` if absent.
3. `wdenoise(x)` first, then tune wavelet / level / method one at a time
   against a measured SNR or a visual overlay (fn-wdenoise.md).
4. Verify features survived; emit one runnable `.m` script with the guard.

## Related

- The smoothing/denoising family (the common path): wf-detrend-smooth-deoutlier.md, Step 3.
- `wdenoise` signature + knobs: fn-wdenoise.md.

----

Copyright 2026 The MathWorks, Inc.

----
