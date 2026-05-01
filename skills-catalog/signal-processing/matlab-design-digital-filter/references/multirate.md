# Multirate Filtering Guide

Complete guide for multirate filtering in MATLAB. Covers when to use each function, streaming vs offline workflows, and cost analysis.
---

## Table of Contents
- [Critical Decision: Which Function to Use?](#critical-decision-which-function-to-use)
- [When Not to Use designMultistageDecimator/Interpolator](#important-when-not-to-use-designmultistagedecimatorinterpolator)
- [Concept: Multirate Pipeline](#concept-multirate-pipeline)
- [Workflow 1: Streaming Multirate](#workflow-1-streaming-multirate-narrow-transition)
- [Workflow 2: Offline Zero-Phase](#workflow-2-offline-zero-phase-narrow-transition)
- [Workflow 3: Wideband Rate Conversion](#workflow-3-wideband-rate-conversion-large-m)
- [Workflow 4: Complex Specifications](#workflow-4-complex-specifications-fdesign)
- [Cost Analysis](#cost-analysis-how-to-compare-approaches)
- [Key Functions Reference](#key-functions-reference)
- [Gotchas](#gotchas)
- [API References](#api-references)
- [Visualization](#visualization)

## Critical Decision: Which Function to Use?

**The choice of multirate function depends on your use case.** Using the wrong function can result in 5× worse performance.

### Quick Decision Table

| Use Case | Recommended Approach | Why |
|----------|---------------------|-----|
| **Narrow transition + streaming** | `designMultirateFIR` + separate sharp filter | Relaxed anti-alias + efficient sharp filter at low rate |
| **Narrow transition + offline** | `resample()` + sharp filter + `filtfilt()` | Simplest, built-in anti-alias, zero-phase |
| **Wideband rate change (M≥8)** | `designMultistageDecimator/Interpolator` | Automatic cascade optimization |
| **Complex frequency specs** | `fdesign.decimator` + `design()` | Flexible specification object |
| **CIC or halfband filters** | `fdesign.decimator` with CIC response | Specialized filter types |

---

## IMPORTANT: When NOT to Use designMultistageDecimator/Interpolator

**These functions are NOT optimal for narrow-transition filtering!**

When you pass tight specs (narrow TW, high Astop), these functions try to achieve the sharp transition **within** the decimation/interpolation, requiring very long filters.

### Real Example (Fs=44.1kHz, Fpass=2.8kHz, Fstop=3.1kHz, 60dB)

| Approach | MPIS | Result |
|----------|------|--------|
| `designMultirateFIR` + sharp filter | **115.75** | BEST |
| Single-stage FIR | 407.00 | Baseline |
| `designMultistageDecimator` + `Interpolator` with tight specs | 531.25 | WORSE! |

**Lesson**: For narrow transitions, use `designMultirateFIR` (relaxed anti-alias) + **separate sharp filter at reduced rate**.

### When designMultistage* IS Optimal

For **wideband rate conversion** (just anti-alias, no specific filtering), `designMultistageDecimator/Interpolator` with **default specs** is very efficient:

| M | designMultirateFIR (MPIS) | designMultistage* (MPIS) | Winner |
|---|---------------------------|--------------------------|--------|
| 4 | 90.2 | **60.8** | Multistage |
| 8 | 189.1 | **81.9** | Multistage (2.3×) |
| 16 | 382.6 | **128.4** | Multistage (3.0×) |
| 32 | 767.3 | **190.7** | Multistage (4.0×) |

---

## Concept: Multirate Pipeline

```
Input (Fs) → Decimate (÷M) → Filter (Fs/M) → Interpolate (×M) → Output (Fs)
```

**Why it works**: A 400-tap filter at 44.1 kHz becomes a ~100-tap filter at 11 kHz (after 4× decimation), and processes 1/4 as many samples.

**Output rate = Input rate**: Decimation and interpolation cancel out.

---

## Workflow 1: Streaming Multirate (Narrow Transition)

**Use `designMultirateFIR` for anti-alias + separate sharp filter.**

```matlab
%% Streaming multirate with narrow transition band
Fs = 44100;
Fpass = 2800; Fstop = 3100;
Rp = 0.1; Rs = 60;
M = 4;  % Decimation/interpolation factor
Fs_dec = Fs / M;

%% Design filters
% Step 1: Decimator with RELAXED anti-alias (just prevent aliasing)
dec = designMultirateFIR(DecimationFactor=M, ...
    StopbandAttenuation=Rs, SystemObject=true);

% Step 2: Sharp lowpass at reduced rate
d_sharp = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs_dec, DesignMethod="equiripple");

% Step 3: Interpolator with anti-image
interp = designMultirateFIR(InterpolationFactor=M, ...
    StopbandAttenuation=Rs, SystemObject=true);

%% Process frames (streaming)
frameSize = 1024;  % Must be multiple of M
y = zeros(size(x));

for i = 1:frameSize:length(x)-frameSize+1
    frame = x(i:i+frameSize-1);

    % Pipeline: decimate → sharp filter → interpolate
    frame_dec = dec(frame);
    frame_filt = filter(d_sharp, frame_dec);  % Causal
    frame_out = interp(frame_filt);

    y(i:i+frameSize-1) = frame_out;
end
```

**Note**: Streaming is **causal only** — no `filtfilt()`. There will be group delay.

---

## Workflow 2: Offline Zero-Phase (Narrow Transition)

**Use `resample()` for simplicity — it has built-in anti-alias/anti-image filters.**

```matlab
%% Offline multirate with zero-phase sharp filter
Fs = 44100;
Fpass = 2800; Fstop = 3100;
Rp = 0.1; Rs = 60;
M = 4;
Fs_dec = Fs / M;

% Load signal
[x, ~] = audioread("noisy_signal.wav");

%% Stage 1: Decimate (resample handles anti-aliasing)
x_dec = resample(x, 1, M);

%% Stage 2: Sharp lowpass at reduced rate (zero-phase)
d_sharp = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs_dec, DesignMethod="equiripple");

x_filt = filtfilt(d_sharp, x_dec);  % Zero-phase at low rate

%% Stage 3: Interpolate back (resample handles anti-imaging)
y = resample(x_filt, M, 1);

% Output y is at original Fs, zero-phase filtered
```

**Advantages**:
- Simple 3-line pipeline
- `resample()` handles anti-alias/anti-image automatically
- `filtfilt()` gives zero-phase at reduced computational cost

---

## Workflow 3: Wideband Rate Conversion (Large M)

**Use `designMultistageDecimator/Interpolator` with DEFAULT specs for pure rate change.**

```matlab
%% Wideband rate conversion (M=16, no specific filtering)
M = 16;
Fs = 48000;

% Default specs - optimized for wideband anti-alias
dec = designMultistageDecimator(M);
interp = designMultistageInterpolator(M);

% View cascade structure
info(dec)
info(interp)

% Cost comparison
cost_dec = cost(dec);
cost_interp = cost(interp);
fprintf('Decimator: %.2f MPIS\n', cost_dec.MultiplicationsPerInputSample);
fprintf('Interpolator: %.2f MPIS\n', cost_interp.MultiplicationsPerInputSample);

% Apply (streaming)
y_dec = dec(x);
y_out = interp(y_dec);
```

**When to use**: Decimation factor M > 8, or when you want MATLAB to optimize the cascade automatically.

---

## Workflow 4: Complex Specifications (fdesign)

**Use `fdesign.decimator` when you need specific passband/stopband control.**

```matlab
%% fdesign.decimator with lowpass specification
M = 4;
Fs = 44100;
Fpass_norm = 2800 / Fs;  % Normalized to Fs
Fstop_norm = 3100 / Fs;
Rp = 0.1; Rs = 60;

% Create specification object
d = fdesign.decimator(M, 'lowpass', 'Fp,Fst,Ap,Ast', ...
    Fpass_norm, Fstop_norm, Rp, Rs);

% Available design methods
designmethods(d)

% Design with kaiserwin (handles tight specs)
hd = design(d, 'kaiserwin', SystemObject=true);
cost(hd)

% Design with multistage (deprecated - use designMultistageDecimator)
% hd_multi = design(d, 'multistage', SystemObject=true);
```

**Key points**:
- Frequencies are normalized to Fs (0 to 1)
- Use `'kaiserwin'` for tight specs where `'equiripple'` fails
- The `'multistage'` method is deprecated — use `designMultistageDecimator` instead

---

## Cost Analysis: How to Compare Approaches

### Using the cost() Function

```matlab
%% Measure MPIS for each component
M = 4;
Rs = 60;

% Decimator
dec = designMultirateFIR(DecimationFactor=M, ...
    StopbandAttenuation=Rs, SystemObject=true);
cost_dec = cost(dec);
fprintf('Decimator: %d taps, %.2f MPIS\n', ...
    length(dec.Numerator), cost_dec.MultiplicationsPerInputSample);

% Sharp filter at reduced rate
d_sharp = designfilt("lowpassfir", ...
    PassbandFrequency=2800, StopbandFrequency=3100, ...
    StopbandAttenuation=Rs, SampleRate=44100/M, ...
    DesignMethod="equiripple");
sharp_sys = dsp.FIRFilter(Numerator=d_sharp.Numerator);
cost_sharp = cost(sharp_sys);
fprintf('Sharp filter: %d taps, %.2f MPIS (at 1/%d rate = %.2f effective)\n', ...
    length(d_sharp.Numerator), cost_sharp.MultiplicationsPerInputSample, ...
    M, cost_sharp.MultiplicationsPerInputSample/M);

% Interpolator
interp = designMultirateFIR(InterpolationFactor=M, ...
    StopbandAttenuation=Rs, SystemObject=true);
cost_interp = cost(interp);
fprintf('Interpolator: %d taps, %.2f MPIS\n', ...
    length(interp.Numerator), cost_interp.MultiplicationsPerInputSample);

% Total pipeline cost
total_mpis = cost_dec.MultiplicationsPerInputSample + ...
             cost_sharp.MultiplicationsPerInputSample/M + ...
             cost_interp.MultiplicationsPerInputSample;
fprintf('TOTAL: %.2f MPIS\n', total_mpis);
```

### Comparing with resample() Pipeline

`resample()` has internal filters not exposed to `cost()`. Use `timeit()`:

```matlab
x = randn(44100*2, 1);  % 2 seconds at 44.1 kHz

f_pipeline = @() resample(filtfilt(d_sharp, resample(x, 1, M)), M, 1);
t_pipeline = timeit(f_pipeline);
fprintf('Offline pipeline: %.2f ms\n', t_pipeline * 1000);
```

---

## Key Functions Reference

| Function | Use Case | Returns |
|----------|----------|---------|
| `designMultirateFIR()` | Single-stage decimator/interpolator | Coefficients or System object |
| `designMultistageDecimator()` | Optimal cascaded decimator (large M, wideband) | `dsp.FilterCascade` |
| `designMultistageInterpolator()` | Optimal cascaded interpolator (large M, wideband) | `dsp.FilterCascade` |
| `resample(x, P, Q)` | Offline rate conversion with anti-alias | Resampled signal |
| `fdesign.decimator()` | Flexible decimator specification | Specification object |
| `fdesign.interpolator()` | Flexible interpolator specification | Specification object |
| `dsp.FIRDecimator` | Streaming decimation System object | System object |
| `dsp.FIRInterpolator` | Streaming interpolation System object | System object |

---

## Gotchas

### 1. Don't Use designMultistage* with Tight Specs for Narrow Transitions

```matlab
% Template
% WRONG: Trying to do sharp filtering within decimation
dec = designMultistageDecimator(M, Fs, TW, Rs);  % TW = narrow

% RIGHT: Relaxed decimator + separate sharp filter
dec = designMultirateFIR(DecimationFactor=M, ...);
d_sharp = designfilt("lowpassfir", ..., SampleRate=Fs/M);
```

### 2. Don't Use System Objects with filtfilt()

```matlab
% Anti-pattern
% WRONG: System objects have internal state
dec_sys = designMultirateFIR(DecimationFactor=M, SystemObject=true);
y = filtfilt(dec_sys, x);  % ERROR!

% RIGHT: Use resample() for offline zero-phase
x_dec = resample(x, 1, M);
```

### 3. Frame Size Must Be Multiple of M

```matlab
% For streaming decimation
frameSize = 1024;  % OK for M=4 (1024/4 = 256)
frameSize = 1000;  % ERROR for M=4 (not divisible)
```

### 4. resample() Has Hidden Filter Cost

Don't claim "100 taps at 11 kHz" — `resample()` adds its own anti-alias/anti-image filtering. Measure total pipeline cost with `timeit()`.

### 5. Fs Meaning Differs Between Functions

- `designMultistageDecimator(M, Fs, ...)`: Fs = **input** rate
- `designMultistageInterpolator(L, Fs, ...)`: Fs = **output** rate (R2024b+)

---

## API References

| Doc File | Content |
|----------|---------|

---

## Visualization

**All multirate filters work with Filter Analyzer** for response visualization and comparison.

### Visualizing Individual Multirate Filters

```matlab
% Compare decimator designs in Filter Analyzer
dec4 = designMultirateFIR(DecimationFactor=4, SystemObject=true);
decMulti = designMultistageDecimator(8);
filterAnalyzer(dec4, decMulti, SampleRates=Fs, ...
    FilterNames=["SingleStage", "Multistage"]);
```

### Visualizing Complete Multirate Pipelines

**IMPORTANT**: For comparing dec→filter→interp pipelines against single-stage filters, wrap the complete pipeline in `dsp.FilterCascade`:

```matlab
%% Create cascade from multirate pipeline for Filter Analyzer
Fs = 44100; M = 4;

% Build pipeline components
dec_sys = designMultirateFIR(DecimationFactor=M, StopbandAttenuation=60, SystemObject=true);
d_core = designfilt("lowpassfir", ...
    PassbandFrequency=2800, StopbandFrequency=3000, ...
    StopbandAttenuation=60, SampleRate=Fs/M, DesignMethod="equiripple");
core_sys = dsp.FIRFilter('Numerator', d_core.Numerator);  % Wrap digitalFilter!
interp_sys = designMultirateFIR(InterpolationFactor=M, StopbandAttenuation=60, SystemObject=true);

% Create cascade for visualization
multirate_cascade = dsp.FilterCascade(dec_sys, core_sys, interp_sys);

% Add to Filter Analyzer alongside other filter types
filterAnalyzer(multirate_cascade, SampleRates=Fs, FilterNames="Multirate_Pipeline");
```

**Key points:**
- Wrap `digitalFilter` in `dsp.FIRFilter` before adding to cascade
- `dsp.FilterCascade` shows the **overall** response of the pipeline
- Use same `SampleRates=Fs` as the input rate

See `filter-analyzer.md` → "Visualizing Multirate Pipelines" for complete comparison examples.

---

## See Also

- `efficient-filtering.md` — Decision guide for choosing approach
- `multistage-ifir.md` — IFIR (constant-rate alternative)
- `patterns.md` — Code templates
- `filter-analyzer.md` — Multirate filter visualization


----

Copyright 2026 The MathWorks, Inc.

----
