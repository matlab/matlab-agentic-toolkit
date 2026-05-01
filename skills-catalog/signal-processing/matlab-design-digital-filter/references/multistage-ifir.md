# IFIR and Multistage Filtering Guide

Complete guide for **Interpolated FIR (IFIR)** filters — a multistage approach that operates at **constant sample rate** (no decimation/interpolation).
---

## Table of Contents
- [Concept](#concept)
- [When to Use IFIR](#when-to-use-ifir)
- [Key Functions](#key-functions)
- [Workflow 1: SystemObject Method](#workflow-1-systemobject-method-filter-analyzer-compatible)
- [Workflow 2: Raw Coefficients Method](#workflow-2-raw-coefficients-method-for-filtfilt)
- [Understanding IFIR Structure](#understanding-ifir-structure)
- [Cost Analysis](#cost-analysis)
- [Comparison: IFIR vs Multirate](#comparison-ifir-vs-multirate)
- [Choosing Interpolation Factor L](#choosing-interpolation-factor-l)
- [Gotchas](#gotchas)
- [API References](#api-references)
- [See Also](#see-also)

## Concept

IFIR uses two filters in cascade:

```
Input → Model Filter h(z^L) → Image Suppressor g(z) → Output
        (sparse)              (removes images)
```

- **Model filter `h(z^L)`**: Sparse filter with zeros inserted between taps (stretched by factor L)
- **Image suppressor `g(z)`**: Removes spectral images created by the sparse filter
- **Combined response**: Achieves the target narrowband response with fewer total multipliers

**Key advantage**: Sample rate stays constant throughout — no decimation or interpolation needed.

---

## When to Use IFIR

| Criterion | IFIR | Alternative |
|-----------|------|-------------|
| trans_pct < 2% | ✓ Good choice | Single-stage OK if > 5% |
| Rate change problematic | ✓ **Best choice** | Multirate changes rate internally |
| Need linear phase | ✓ Maintains linear phase | IIR loses linear phase |
| Filter Analyzer visualization | ✓ Works with SystemObject=true | Multirate pipelines can't be visualized end-to-end |

---

## Key Functions

| Function | Returns | Filter Analyzer? | filtfilt()? |
|----------|---------|------------------|-------------|
| `ifir(Hf, SystemObject=true)` | `dsp.FilterCascade` | ✓ Yes | ✗ Use object directly |
| `ifir(L, 'low', freqs, devs)` | Raw coefficients `[b_ifir]` | ✗ No | ✓ Yes |
| `design(Hf, 'ifir', SystemObject=true)` | `dsp.FilterCascade` | ✓ Yes | ✗ Use object directly |

---

## Workflow 1: SystemObject Method (Filter Analyzer Compatible)

Use this when you want to visualize in Filter Analyzer or use streaming.

```matlab
%% IFIR with SystemObject (Filter Analyzer compatible)
Fs = 44100;
Fpass = 2800; Fstop = 3200;
Rp = 0.1; Rs = 60;

% Create filter specification (normalized frequencies)
Fn = Fs / 2;
Hf = fdesign.lowpass(Fpass/Fn, Fstop/Fn, Rp, Rs);

% Design IFIR filter (returns dsp.FilterCascade)
d_ifir = ifir(Hf, SystemObject=true);
% Alternative: d_ifir = design(Hf, 'ifir', SystemObject=true);

% View structure
info(d_ifir)

% Visualize in Filter Analyzer
filterAnalyzer(d_ifir, FilterNames="IFIR_Lowpass", SampleRates=Fs, ...
    Analysis="magnitude", OverlayAnalysis="phase");

% Apply filter (streaming - causal)
y = d_ifir(x);

% For batch processing, reset between uses
reset(d_ifir);
```

**Note**: `dsp.FilterCascade` objects work directly with Filter Analyzer but **cannot** be used with `filtfilt()`.

---

## Workflow 2: Raw Coefficients Method (For filtfilt)

Use this when you need zero-phase filtering with `filtfilt()`.

```matlab
%% IFIR with raw coefficients (for filtfilt)
Fs = 44100;
Fpass = 2800; Fstop = 3200;
Rp = 0.1; Rs = 60;
Fn = Fs / 2;

% Calculate deviations from ripple specs
dev_pass = (10^(Rp/20) - 1) / (10^(Rp/20) + 1);
dev_stop = 10^(-Rs/20);

% Choose interpolation factor L (typically 2-8)
L = 4;  % Higher L = more sparse model filter

% Design IFIR (returns coefficient vectors)
[b_ifir, b_model, b_image] = ifir(L, 'low', [Fpass Fstop]/Fn, [dev_pass dev_stop]);

% Apply with filtfilt (zero-phase)
y = filtfilt(b_ifir, 1, x);

% Report filter lengths
fprintf('Combined IFIR: %d taps\n', length(b_ifir));
fprintf('Model filter:  %d taps (sparse)\n', length(b_model));
fprintf('Image suppressor: %d taps\n', length(b_image));
```

**Note**: Raw coefficients work with `filtfilt()` but cannot be added directly to Filter Analyzer.

---

## Understanding IFIR Structure

### Model Filter h(z^L)

The model filter is "stretched" by inserting L-1 zeros between each coefficient:

```
Original:  h = [h0, h1, h2, h3]
Stretched: h(z^4) = [h0, 0, 0, 0, h1, 0, 0, 0, h2, 0, 0, 0, h3]
```

This creates a narrower transition band but introduces spectral images.

### Image Suppressor g(z)

A short lowpass filter that removes the images created by the sparse model filter.

### Why It's Efficient

| Component | Taps | Non-zero Multiplies |
|-----------|------|---------------------|
| Model filter h(z^L) | ~400 (sparse) | ~100 (only every L-th) |
| Image suppressor g(z) | ~30 | ~30 |
| **Total** | ~430 | **~130** |

Compare to single-stage FIR: 400 taps = 400 multiplies.

---

## Cost Analysis

### Measuring MPIS for IFIR

```matlab
%% Get MPIS for IFIR SystemObject
Fs = 44100;
Fpass = 2800; Fstop = 3200;
Rp = 0.1; Rs = 60;
Fn = Fs / 2;

Hf = fdesign.lowpass(Fpass/Fn, Fstop/Fn, Rp, Rs);
d_ifir = ifir(Hf, SystemObject=true);

% Get cost
c = cost(d_ifir);
fprintf('IFIR MPIS: %.2f\n', c.MultiplicationsPerInputSample);
fprintf('Coefficients: %d\n', c.NumCoefficients);
```

### Comparison with Alternatives

```matlab
%% Compare IFIR vs single-stage vs IIR
% Single-stage FIR
d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    StopbandAttenuation=Rs, SampleRate=Fs, DesignMethod="equiripple");
fir_sys = dsp.FIRFilter('Numerator', d_fir.Numerator);

% IIR Elliptic
d_iir = designfilt("lowpassiir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    StopbandAttenuation=Rs, SampleRate=Fs, DesignMethod="ellip");
iir_sys = dsp.SOSFilter('Numerator', d_iir.Numerator, 'Denominator', d_iir.Denominator);

% Compare
fprintf('Single-stage FIR: %.0f MPIS\n', cost(fir_sys).MultiplicationsPerInputSample);
fprintf('IFIR:             %.0f MPIS\n', cost(d_ifir).MultiplicationsPerInputSample);
fprintf('IIR Elliptic:     %.0f MPIS\n', cost(iir_sys).MultiplicationsPerInputSample);
```

---

## Comparison: IFIR vs Multirate

| Aspect | IFIR | Multirate |
|--------|------|-----------|
| **Sample rate** | Constant throughout | Changes internally |
| **Structure** | Two filters in cascade | Decimate→filter→interpolate pipeline |
| **Filter Analyzer** | ✓ Works directly | ✗ Can't show end-to-end |
| **Zero-phase offline** | Raw coefficients + filtfilt | resample + filtfilt |
| **Complexity** | Simpler (one cascade) | More stages |
| **Best for** | Rate change problematic | Large decimation possible |

---

## Choosing Interpolation Factor L

The interpolation factor L controls the trade-off between model filter sparsity and image suppressor length:

| L | Model Filter | Image Suppressor | Total Efficiency |
|---|--------------|------------------|------------------|
| 2 | Less sparse | Shorter | Moderate |
| 4 | More sparse | Medium | Good |
| 8 | Very sparse | Longer | Diminishing returns |

**Rule of thumb**: Start with L=4, adjust based on cost() measurements.

```matlab
% Compare different L values
for L_try = [2 4 6]
    [b_ifir, ~, ~] = ifir(L_try, 'low', [Fpass Fstop]/Fn, [dev_pass dev_stop]);
    fprintf('L=%d: %d total taps\n', L_try, length(b_ifir));
end
```

---

## Gotchas

### 1. SystemObject vs Raw Coefficients

```matlab
% Anti-pattern
% SystemObject: Can't use with filtfilt
d_ifir = ifir(Hf, SystemObject=true);
y = filtfilt(d_ifir, x);  % ERROR!

% Raw coefficients: Can't use with Filter Analyzer
[b_ifir, ~, ~] = ifir(L, 'low', freqs, devs);
filterAnalyzer(b_ifir, ...);  % Won't show IFIR structure properly
```

### 2. Normalized Frequencies for fdesign

```matlab
% fdesign uses normalized frequencies (0 to 1, where 1 = Fs/2)
Fn = Fs / 2;
Hf = fdesign.lowpass(Fpass/Fn, Fstop/Fn, Rp, Rs);  % Normalized!

% NOT: fdesign.lowpass(Fpass, Fstop, ...)  % Wrong!
```

### 3. Deviations vs dB for Raw ifir()

```matlab
% Raw ifir() uses linear deviations, not dB
Rp_dB = 0.1;  % Passband ripple in dB
Rs_dB = 60;   % Stopband attenuation in dB

dev_pass = (10^(Rp_dB/20) - 1) / (10^(Rp_dB/20) + 1);  % Convert to deviation
dev_stop = 10^(-Rs_dB/20);  % Convert to deviation

[b_ifir, ~, ~] = ifir(L, 'low', freqs, [dev_pass dev_stop]);
```

---

## API References

| Doc File | Content |
|----------|---------|

---

## See Also

- `efficient-filtering.md` — Decision guide for choosing approach
- `multirate.md` — Multirate (rate-changing) alternative
- `patterns.md` — Code templates
- `filter-analyzer.md` — Visualizing IFIR filters


----

Copyright 2026 The MathWorks, Inc.

----
