# Workflow: align multi-rate / offset channels to a shared time base

> Functions used: `synchronize`, `retime`, `resample`, `finddelay`, `alignsignals`, `xcorr`

Several signals from different sources — different sample rates, different
start times, or an unknown lag between them — become one aligned, uniformly
sampled table.

> **Off-ramp.** If a single channel just has non-uniform / jittery timestamps
> (no second channel to align against), that is regularize, not align — see
> wf-uniform-rate.md.

## When to use this

Reach here when the inputs are **two or more** channels that need a common
time base:
- Different rates (100 Hz accelerometer + 50 Hz pressure).
- Different start times or offsets.
- An unknown lag to estimate and remove first.

The dominant mistake is **hand-orchestrating** the merge: retime channel B,
estimate the lag, shift B's row times, retime again, then build a timetable
by hand to concatenate.
That produces the correct result but in five steps.
`synchronize` does the bring-to-common-grid step in one call.

## Recipe

### Step 1 — Get each channel into a timetable

If the channels are numeric vectors with sample rates, wrap them:

```matlab
A = timetable(secondsA', chA, 'VariableNames', "accel");   % or SampleRate= form
B = timetable(secondsB', chB, 'VariableNames', "press");
```

Once they are timetables, the merge is one function — the rate difference is
handled by the adjust method, not by manual resampling per channel.

### Step 2 (only if there is an unknown lag) — estimate and remove it

If the channels are the *same* physical signal seen through different sensors
with an unknown delay, find the lag first.
Both `finddelay` and a normalized `xcorr` peak give it; they should agree.

```matlab
d = finddelay(a, b);              % integer-sample lag of b relative to a
b_aligned = alignsignals(a, b);   % or shift b's row times by d/fs
```

When you report the lag to the user, lead with the physical time in seconds — that is unambiguous across channels. `finddelay`/`xcorr` measure the lag in samples of the grid the two signals were compared on, so a raw sample count only means something once you say which rate it is at. Report the delay as seconds (`d/fsCommon`, where `fsCommon` is the shared/aligned rate), and if you also give a sample count, state the grid it refers to (e.g. "8 ms = 8 samples at the 1 kHz aligned rate"). Do not report a bare integer sample count for mismatched-rate channels — the same delay is a different count at each rate.

For sub-sample precision, refine the `xcorr` peak parabolically.
Skip this whole step when the channels are *different* signals sharing a
clock — there is no lag to estimate, only a rate/offset difference, which
step 3 handles directly.

### Step 3 — Merge onto a shared grid with `synchronize`

This is the one-shot primitive. Pick the common time basis and the adjust
method (full contract in fn-synchronize.md):

```matlab
% Put everything on A's row times, interpolate B linearly:
TT = synchronize(A, B, 'first', 'linear');

% Or a clean uniform output rate, regardless of either input's grid:
TT = synchronize(A, B, 'regular', 'linear', 'SampleRate', 100);

% Or keep only the overlapping span (drop non-overlapping tails):
TT = synchronize(A, B, 'commonrange', 'linear');
```

Choose the basis by intent:
- `'first'` / `'last'` — anchor to one channel's existing grid.
- `'regular'` + `SampleRate` — impose a clean uniform rate.
- `'commonrange'` — keep only where all channels have data.
- `'union'` (default) — keep every sample and NaN-fill the rest (see step 4).

**Anti-pattern.** Do not `retime` each channel separately and then build a
timetable by hand to stitch them. `synchronize` is exactly that operation,
done once, with the grid choice explicit.

```matlab
% Bad — hand-orchestrated merge:
Br = retime(B, A.Time, 'linear');
TT = timetable(A.Time, A.accel, Br.press);   % manual concat

% Good — one call:
TT = synchronize(A, B, 'first', 'linear');
```

### Step 4 — Handle the NaNs that alignment creates

At times where one channel has no sample and you used the default
(`'fillwithmissing'`, i.e. `synchronize(A,B)` with no method), or where
`'union'` introduced rows outside a channel's span, the output has `NaN`s.
Align typically **precedes fill**: decide whether those gaps are
interpolated, held, or left missing.
See wf-repair-missing.md for the fill step.

If you interpolated in step 3 (`'linear'` etc.), watch the endpoints:
`'linear'` extrapolates by default, so a channel that starts late gets
invented values before its first real sample. Pass `EndValues=NaN` to refuse
extrapolation, then fill deliberately.

Two mistakes are common at exactly this step, both on the `NaN`s alignment
just created:

- **Dropping the NaN rows** (`tt = tt(all(isfinite(tt{:,:}),2), :)`) to make
  the table finite. That silently truncates every channel to the *overlap*
  span and desynchronizes rows you meant to keep - it is not a fill, it is a
  crop. If you genuinely want only the overlap, ask `synchronize` for it up
  front with `'commonrange'`; do not post-hoc delete rows.
- **Treating the endpoint `NaN`s as ordinary interior gaps.** A late-starting
  channel's leading `NaN`s (and an early-ending channel's trailing `NaN`s) are
  *edge* gaps with data on one side only - the endpoint case in
  wf-repair-missing.md. Route them there; on an oscillatory channel the fill is
  `fillgaps`, not `fillmissing(..., EndValues=...)`.

## Aliasing guardrail — `resample` before `synchronize` when downsampling

`synchronize`/`retime` interpolation methods do **not** antialias, and they
alias **silently**. If a channel is being brought onto a grid **coarser** than
its own content bandwidth (any real downsampling), plain interpolation folds
high-frequency energy back into the band with no warning.

Rule: when the shared grid is coarser than a channel's native rate, `resample`
that channel to the target rate **first** (antialiased, `resample` applies the
FIR anti-alias filter), *then* `synchronize` onto the grid. Reserve bare
`synchronize`-linear for channels whose content is slow relative to the shared
rate — i.e. you are not reducing real bandwidth. See fn-resample.md and
wf-uniform-rate.md (the single-channel rate-change workflow).

## See also

- fn-synchronize.md — the merge primitive, basis and method contract.
- fn-retime.md — single-channel rate change (the piece `synchronize` generalizes).
- fn-resample.md — antialiased rate conversion.
- wf-repair-missing.md — fill the NaNs alignment creates.
- wf-uniform-rate.md — single-channel onto a uniform rate (regularize jitter or plain rate-change).

----

Copyright 2026 The MathWorks, Inc.

----
