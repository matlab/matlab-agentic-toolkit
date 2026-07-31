# Function: `sgolayfilt`

> Used in: wf-detrend-smooth-deoutlier.md
> Toolbox: Signal Processing Toolbox

Savitzky-Golay FIR smoothing filter. It fits a polynomial of order `m` over a
sliding odd-length frame `fl` and takes the center value. Unlike a moving
average, it preserves higher-order moments - peak height, peak width,
derivatives - which is why it is the tool for spectra, chromatograms, and
transient detection.

This is the **escape hatch**, not the default. `smoothdata`
(fn-smoothdata.md) is the dispatcher you reach for first. Come here only when
you need a polynomial order other than 2 (`smoothdata(x, "sgolay")` fixes
degree 2 unless you set `Degree`) or when you want direct access to the FIR
formulation. `sgolayfilt` has **no defaults** - both `m` and `fl` are
required.

## Signature

```matlab
y = sgolayfilt(x, m, fl)              % order m, frame length fl (both required)
y = sgolayfilt(x, m, fl, w)           % w = weighting vector, length fl
y = sgolayfilt(x, m, fl, w, dim)
```

## Arguments

| Argument | Default | Purpose |
|---|---|---|
| `m` (polynomial order) | **none - required** | Nonnegative integer, must be `< fl`. Order 2-4 is typical. Higher order preserves more signal detail but rejects less noise. |
| `fl` (frame length) | **none - required** | Positive **odd** integer. Must satisfy `fl >= 2*m + 1`. Larger `fl` = more smoothing. |
| `w` (weighting) | `ones(fl,1)` | Real positive vector of length `fl` for the least-squares fit. Use a `kaiser(fl, beta)` window to taper the fit. |
| `dim` | first non-singleton | Dimension to filter along. Default is the first dimension whose size is `> 1`. |

## No defaults - you must pick both `m` and `fl`

There is no `sgolayfilt(x)` form. Sensible starting values:

```matlab
m  = 2;                 % quadratic; go 3-4 for sharper peaks
fl = 11;                % odd, and >= 2*m + 1
y  = sgolayfilt(x, m, fl);
```

- `m` in `{2, 3, 4}` covers almost all uses. Order 2 is the `smoothdata`
  default; pick `sgolayfilt` when you want 3 or 4.
- `fl` odd, `fl >= 2*m + 1`. Larger frame = smoother output.

## Gotchas

- **Both `m` and `fl` are required; no defaults exist.** A caller who expects
  `sgolayfilt(x)` to work is thinking of `smoothdata`.
- **`fl` must be odd.** An even frame length errors.
- **`m` must be `< fl`. If `m = fl - 1` the filter does nothing** - the doc
  states a polynomial of order `fl-1` fits the frame exactly, so the output
  equals the input (no smoothing).
- **Preserves peaks but rejects less noise** than a plain moving average. That
  is the deliberate tradeoff: it is more effective at keeping high-frequency
  signal components and less successful at rejecting high-frequency noise.
- **Operates column-wise on matrices** unless you pass `dim`.

## Choosing between this and the smoothing dispatcher

`sgolayfilt` is the escape hatch (see the intro): reach for it when you need a
polynomial order other than 2, a weighted (`w`) least-squares fit, or the direct
FIR form. Picking a smoother for the job at all - `smoothdata` default vs.
`smoothdata(x,"sgolay")` vs. this vs. `lowpass` - is the workflow decision:
see wf-detrend-smooth-deoutlier.md (Step 3).

## See also

- fn-smoothdata.md — the dispatcher; `smoothdata(x, "sgolay")` is degree 2.
- `lowpass` — use when a cutoff frequency in Hz separates noise from signal.
- `sgolay` — returns the filter matrix if you need the transient-region rows.
- wf-detrend-smooth-deoutlier.md — where smoothing sits in the recipe.

----

Copyright 2026 The MathWorks, Inc.

----
