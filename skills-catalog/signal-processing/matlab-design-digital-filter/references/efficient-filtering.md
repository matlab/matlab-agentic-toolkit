# Efficient Filtering for Narrow Transitions

When transition bands are narrow (trans_pct < 2%; see `quick-ref/efficient-filtering.md`), single-stage FIR filters require hundreds of taps. This guide helps you choose an efficient alternative.

## Table of Contents
- [When You Need This](#when-you-need-this)
- [Four Approaches Compared](#four-approaches-compared)
- [Quantify Single-Stage FIR Cost](#quantify-single-stage-fir-cost)
- [Multirate Design](#multirate-design-function-selection)
- [IFIR Quick Syntax](#ifir-quick-syntax)
- [Decision Flowchart](#decision-flowchart)
- [MPIS Cost Comparison](#mpis-cost-comparison-real-example)
- [Why MPIS is the Right Metric](#why-mpis-is-the-right-metric)
- [Visualizing All Approaches in Filter Analyzer](#visualizing-all-approaches-in-filter-analyzer)
- [Quick Selection Guide](#quick-selection-guide)
- [Cross-References](#cross-references)

---

## When You Need This

Calculate your transition percentage:

```
Compute constraining transition width Δf (Hz):
- lowpass:   Δf = Fstop - Fpass
- highpass:  Δf = Fpass - Fstop
- bandpass:  Δf = min(Fpass1 - Fstop1, Fstop2 - Fpass2)
- bandstop:  Δf = min(Fstop1 - Fpass1, Fpass2 - Fstop2)

Then:
trans_pct = 100 * (Δf / Fs)
```

| trans_pct | Recommendation |
|-----------|----------------|
| > 5% | Single-stage filter is fine |
| 2-5% | Consider efficient alternatives |
| **< 2%** | **Efficient approach strongly recommended** (see `quick-ref/efficient-filtering.md`) |

---

## Four Approaches Compared

| Approach | Sample Rate | Structure | Best When |
|----------|-------------|-----------|-----------|
| **Single-stage IIR** | Constant | SOS (biquads) | Offline zero-phase OK, minimum coefficients |
| **Multirate** | Changes internally | Decimate→filter→interpolate | Large M possible, prefer linear phase |
| **IFIR** | Constant | Sparse + image suppressor | Rate change problematic, constant rate required |
| **Single-stage FIR** | Constant | One filter | trans_pct > 5%, or simplicity matters |

**Key insight**: For offline processing, **IIR + `filtfilt()`** is often the most efficient because `filtfilt()` cancels phase distortion, allowing minimum-order IIR designs.

**Note**: Because `filtfilt()` applies the filter forward and backward, the effective magnitude response is the squared magnitude of the original filter (amplitude specs should be checked on the combined response).
---

## Quantify Single-Stage FIR Cost

Before you jump to multirate/IFIR, **quantify how bad a single-stage FIR really is** using MATLAB-native estimators.

```matlab
% Convert dB specs to linear deviations
dev_p = (10^(Rp_dB/20)-1) / (10^(Rp_dB/20)+1);
dev_s = 10^(-Rs_dB/20);

% LOWPASS example (Hz). Adapt f/a for other responses:
f = [Fpass Fstop];
a = [1 0];
dev = [dev_p dev_s];

% Order estimates
[N_kaiser, Wn, beta, ftype] = kaiserord(f, a, dev, Fs);
[N_pm, fo, ao, w] = firpmord(f, a, dev, Fs);

fprintf("Estimated FIR order: Kaiser=%d, Equiripple=%d\n", N_kaiser, N_pm);
```

**Interpretation**:
- If the estimate is already in the **hundreds of taps**, a single-stage linear-phase FIR is likely expensive in streaming.
- If the estimate is modest, you may not need multirate/IFIR at all — keep it simple and verify.


---

## Multirate Design: Function Selection

For multirate approaches, select functions based on your goal:

| Goal | Recommended Approach |
|------|---------------------|
| **Pure rate conversion** (wideband anti-alias) | `designMultistageDecimator/Interpolator` with default TW |
| **Narrow-transition filtering** at reduced rate | `designMultirateFIR` (anti-alias) + separate sharp filter |
| **Offline FIR-based rate conversion** (delay-compensated) | `resample()` |

### When Multistage Excels

`designMultistageDecimator/Interpolator` automatically factor the overall rate-change (when the factor is composite) into stages and select a stage sequence that minimizes MPIS.

**Example** (from MathWorks docs): For M=48 decimation, multistage reduces MPIS from ~15.7 to ~7.3 — roughly 2× savings.

**Note**: Actual savings depend heavily on TW, Astop, and factorization. Use `cost()` to compare specific designs.

These functions are optimized for **wideband anti-aliasing**. Default transition width depends on the function and MATLAB release:
- `designMultistageDecimator`: default TW = 0.2×Fs/M
- `designMultistageInterpolator`: default TW = 0.2×Fs (R2024b+; was 0.2×Fs/L previously)

### Narrow-Transition Strategy

For narrow transition bands, the sharp filtering is more efficient at reduced sample rate:

1. **Decimate** with relaxed anti-alias (`designMultirateFIR`)
2. **Sharp filter** at reduced rate (`designfilt` with tight specs)
3. **Interpolate** with anti-image (`designMultirateFIR`)

This separates the anti-aliasing (wideband) from the sharp filtering (narrowband), allowing each to be optimized independently.



        ### Multirate Candidate Selection Recipe (repeatable)

        For lowpass-style “keep baseband” problems, start with:

        ```matlab
        % Max decimation factor that keeps stopband below new Nyquist (lowpass heuristic)
        M_max = floor(Fs / (2*Fstop));
        M_try = [2 3 4 5 6 8];
        M_try = M_try(M_try <= M_max);
        ```

        Then evaluate each `M` by **total MPIS** (multiplications per input sample):

        ```matlab
        best = struct(M=1, mpis=Inf);

        for M = M_try
            Fs_dec = Fs / M;

            % Anti-alias / anti-image (relaxed) at full rate
            dec = designMultirateFIR(DecimationFactor=M, StopbandAttenuation=Rs_dB, SystemObject=true);
            interp = designMultirateFIR(InterpolationFactor=M, StopbandAttenuation=Rs_dB, SystemObject=true);

            % Sharp filter at reduced rate (digitalFilter -> wrap for cost())
            d_sharp = designfilt("lowpassfir", ...
                PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
                PassbandRipple=Rp_dB, StopbandAttenuation=Rs_dB, ...
                SampleRate=Fs_dec, DesignMethod="equiripple");
            sharp = dsp.FIRFilter(Numerator=d_sharp.Numerator);

            mpis_total = cost(dec).MultiplicationsPerInputSample + ...
                         cost(sharp).MultiplicationsPerInputSample / M + ...
                         cost(interp).MultiplicationsPerInputSample;

            if mpis_total < best.mpis
                best.M = M; best.mpis = mpis_total;
            end
        end

        fprintf("Best multirate candidate: M=%d (%.2f MPIS)\n", best.M, best.mpis);
        ```

        **Why this is “standard”**: it turns “multirate might help” into a repeatable cost-based selection, instead of a vibe-based guess.

        **Caveat**: `M_max` above is a *lowpass heuristic*. For highpass/bandpass/bandstop, safe rate-change needs spectrum-aware reasoning.

→ See `multirate.md` for complete workflows and cost analysis examples.

---

## IFIR Quick Syntax

**Method 1: Direct ifir() with linear deviations**
```matlab
% WARNING: ifir() uses LINEAR deviations and NORMALIZED frequencies (0-1)!
delta_p = 10^(Rp_dB/20) - 1;  % passband deviation
delta_s = 10^(-Rs_dB/20);      % stopband deviation
[h, g] = ifir(L, 'low', [Fpass Fstop]/(Fs/2), [delta_p delta_s]);
y = filter(g, 1, filter(h, 1, x));  % cascade application

% For Filter Analyzer: wrap in System objects
H = dsp.FIRFilter(Numerator=h);
G = dsp.FIRFilter(Numerator=g);
filterAnalyzer(cascade(H,G), FilterNames="IFIR_Cascade");
```

**Method 2: fdesign + ifir (Recommended for Filter Analyzer)**
```matlab
% Returns dsp.FilterCascade directly - works with filterAnalyzer
Hf = fdesign.lowpass(Fpass/(Fs/2), Fstop/(Fs/2));
Hd = ifir(Hf, SystemObject=true);
filterAnalyzer(Hd, FilterNames="IFIR_Lowpass");
```

---

## Decision Flowchart

```
Narrow transition band (trans_pct < 2%)?
│
├── No  → Single-stage filter is fine
│         - FIR for linear phase (streaming)
│         - IIR for efficiency
│
└── Yes → Is this offline or streaming?
    │
    ├── OFFLINE → Do you need linear phase (constant group delay)?
    │   │
    │   ├── No  → **IIR + filtfilt()** (BEST: 23 MPIS)
    │   │         Zero-phase, far fewer coefficients
    │   │
    │   └── Yes → Choose efficient FIR approach:
    │             ├── Can you tolerate internal rate change?
    │             │   ├── Yes → **Multirate** (decimate→filter→interpolate)
    │             │   └── No  → **IFIR** (constant rate)
    │             └── Or just accept ~400 taps if simplicity matters
    │
    └── STREAMING → Do you need linear phase?
        │
        ├── No  → **IIR** (minimum order, sharp cutoff)
        │
        └── Yes → Choose efficient FIR approach:
                  ├── Can you tolerate internal rate change?
                  │   ├── Yes → **Multirate** (System objects)
                  │   └── No  → **IFIR** (constant rate)
                  └── Or accept latency of ~400-tap FIR
```

---

## MPIS Cost Comparison (Real Example)

**Specifications**: Fs=44.1kHz, Fpass=2.8kHz, Fstop=3.1kHz, 60dB stopband (trans_pct = 0.68%)

```matlab
%% Measure MPIS with cost() function
Fs = 44100; Fpass = 2800; Fstop = 3100; Rs = 60;

% FIR Equiripple
d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    StopbandAttenuation=Rs, SampleRate=Fs, DesignMethod="equiripple");
fir_sys = dsp.FIRFilter('Numerator', d_fir.Numerator);
cost_fir = cost(fir_sys);

% IIR Elliptic
d_iir = designfilt("lowpassiir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    StopbandAttenuation=Rs, SampleRate=Fs, DesignMethod="ellip");
iir_sys = dsp.SOSFilter('Numerator', d_iir.Numerator, 'Denominator', d_iir.Denominator);
cost_iir = cost(iir_sys);

fprintf('FIR Equiripple: %d taps, %.0f MPIS\n', length(d_fir.Numerator), cost_fir.MultiplicationsPerInputSample);
fprintf('IIR Elliptic:   %d sections, %.0f MPIS\n', size(d_iir.Numerator,1), cost_iir.MultiplicationsPerInputSample);
```

**Results**:

| Filter | Taps/Sections | MPIS | Relative Cost |
|--------|---------------|------|---------------|
| FIR Equiripple | 407 taps | **407** | 1.00× (baseline) |
| IIR Elliptic | 5 sections | **23** | 0.06× (**17× more efficient**) |
| FIR Decimator (M=4) | 96 taps | 18.25 | (per input sample) |
| FIR Interpolator (L=4) | 96 taps | 72 | (per output sample) |

---

## Why MPIS is the Right Metric

| Metric | Problem |
|--------|---------|
| **Tap count** | Ignores polyphase efficiency, IIR structure, rate changes |
| **`timeit()`** | Hardware-dependent, JIT-variable, not reproducible |
| **MPIS via `cost()`** | Deterministic, structure-aware, MathWorks standard |

Use the `cost()` function on DSP System objects to get accurate MPIS values.

---

## Visualizing All Approaches in Filter Analyzer

**All filter types can be visualized together** in Filter Analyzer, including:
- Single-stage FIR/IIR (`digitalFilter`, `dsp.FIRFilter`, `dsp.SOSFilter`)
- IFIR cascades (`dsp.FilterCascade` from `ifir()`)
- Multirate pipelines (`dsp.FilterCascade` wrapping dec→filter→interp)
- Individual multirate filters (`dsp.FIRDecimator`, `dsp.FIRInterpolator`)

### Complete Comparison Example (FIR vs IFIR vs Multirate Pipeline)

**IMPORTANT**: For multirate pipelines, wrap the complete dec→filter→interp chain in `dsp.FilterCascade` so it appears as a single filter for comparison.

```matlab
%% Complete comparison: FIR vs IFIR vs Multirate Pipeline
Fs = 44100; M = 4;
Fpass = 2800; Fstop = 3000; Rp = 0.1; Rs = 60;

% Approach 1: Single-stage FIR (baseline)
d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="equiripple");
fir_sys = dsp.FIRFilter('Numerator', d_fir.Numerator);

% Approach 2: IFIR cascade
Hf = fdesign.lowpass(Fpass/(Fs/2), Fstop/(Fs/2), Rp, Rs);
ifir_sys = ifir(Hf, 'SystemObject', true);

% Approach 3: Multirate pipeline (dec → filter → interp)
dec_sys = designMultirateFIR(DecimationFactor=M, StopbandAttenuation=Rs, SystemObject=true);
d_core = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs/M, DesignMethod="equiripple");
core_sys = dsp.FIRFilter('Numerator', d_core.Numerator);  % Wrap for cascade!
interp_sys = designMultirateFIR(InterpolationFactor=M, StopbandAttenuation=Rs, SystemObject=true);
multirate_cascade = dsp.FilterCascade(dec_sys, core_sys, interp_sys);

% Open Filter Analyzer with ALL THREE
fa = filterAnalyzer(fir_sys, ifir_sys, multirate_cascade, ...
    FilterNames=["FIR_SingleStage", "IFIR_Cascade", "Multirate_Pipeline"], ...
    SampleRates=Fs, Analysis="magnitude");

% Add group delay and impulse response
addDisplays(fa, Analysis="groupdelay");
addDisplays(fa, Analysis="impulse");
showFilters(fa, true);

% Compare MPIS
fprintf('MPIS: FIR=%.0f, IFIR=%.0f, Multirate=%.0f\n', ...
    cost(fir_sys).MultiplicationsPerInputSample, ...
    cost(ifir_sys).MultiplicationsPerInputSample, ...
    cost(multirate_cascade).MultiplicationsPerInputSample);
```

**Key points:**
- Wrap `digitalFilter` in `dsp.FIRFilter` before adding to `dsp.FilterCascade`
- **Use `dsp.FilterCascade(dec, filter, interp)`** to create a single object for comparison
- Filter Analyzer shows the **overall** frequency response of the cascade
- Use same `SampleRates=Fs` for all (multirate rates are handled internally)
- IFIR cascades automatically expand to show individual stages

→ See `filter-analyzer.md` § "Visualizing Multirate Pipelines" for more details.

---

## Quick Selection Guide

| Your Situation | Recommended Approach | Details |
|----------------|---------------------|---------|
| Offline, zero-phase OK | **IIR + `filtfilt()`** | Simplest, most efficient |
| Offline, linear phase needed, rate change OK | **Multirate** | `resample()` + sharp filter |
| Offline, linear phase needed, constant rate | **IFIR** | `ifir()` function |
| Streaming, no phase requirement | **IIR** | `dsp.SOSFilter` |
| Streaming, linear phase, rate change OK | **Multirate** | System objects pipeline |
| Streaming, linear phase, constant rate | **IFIR** | `ifir(..., SystemObject=true)` |

---

## Cross-References

**Detailed Guides**:
- **Multirate workflows** → `multirate.md`
- **IFIR/Multistage workflows** → `multistage-ifir.md`

**API Documentation**:

**Other Knowledge**:
- `filter-analyzer.md` — Visualizing and comparing filters
- `patterns.md` — Code templates for all approaches


----

Copyright 2026 The MathWorks, Inc.

----
