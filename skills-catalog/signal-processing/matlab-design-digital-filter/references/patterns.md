# Filter Design Patterns

Quick design templates and application patterns for MATLAB digital filter design. Consult this file when you need ready-to-use code patterns.

---
## Table of Contents
- [Quick Design Patterns](#quick-design-patterns)
  - [High-Level One-Liners](#high-level-one-liners)
  - [Order Estimation](#order-estimation)
  - [Minimum-Phase FIR (Reduced Latency)](#minimum-phase-fir-reduced-latency)
  - [IFIR (Interpolated FIR) for Narrow Transitions](#ifir-interpolated-fir-for-narrow-transitions)
- [Multirate Design Patterns](#multirate-design-patterns)
  - [Streaming Multirate](#streaming-multirate-modern-syntax-r2024a)
  - [Offline Zero-Phase Multirate](#offline-zero-phase-multirate)
  - [Wideband Rate Conversion](#wideband-rate-conversion-large-m)
- [Application Patterns](#application-patterns)
  - [Extract Coefficients](#extract-coefficients-from-digitalfilter-object)
  - [Offline Validation](#offline-validation-zero-phase)
  - [Streaming CTF](#streaming-ctf-path-r2024b)
  - [Streaming SOS System Object](#streaming-sos-system-object-all-versions)
  - [Advanced Filter Analyzer Usage](#advanced-filter-analyzer-usage)
- [Complete Examples](#complete-examples)
- [Quick Lookup](#quick-lookup)

**Note**: For basic `designfilt()` syntax (response types, parameters, gotchas), see `quick-ref/designfilt.md`.


## Quick Design Patterns

### High-Level One-Liners

These functions auto-design minimum-order filters and return `[y, d]`:

```matlab
% Lowpass / Highpass
[y, d] = lowpass(x, Fpass, Fs, StopbandAttenuation=Rs, ImpulseResponse="iir");
[y, d] = highpass(x, Fpass, Fs, StopbandAttenuation=Rs, ImpulseResponse="iir");

% Bandpass / Bandstop (passband as [f1 f2])
[y, d] = bandpass(x, [f1 f2], Fs, StopbandAttenuation=Rs, ImpulseResponse="iir");
[y, d] = bandstop(x, [f1 f2], Fs, StopbandAttenuation=Rs, ImpulseResponse="iir");
```

**Note**: Set `ImpulseResponse="fir"` for linear phase. Use `Steepness` parameter (0-1) to control transition width.

---

### Order Estimation

Use MATLAB-native estimators to sanity-check how big a single-stage FIR might be **before** committing to multirate/IFIR.

```matlab
% Convert dB specs to linear deviations
dev_p = (10^(Rp_dB/20)-1) / (10^(Rp_dB/20)+1);
dev_s = 10^(-Rs_dB/20);

% LOWPASS example (Hz). Adapt f/a for highpass/bandpass/bandstop.
f = [Fpass Fstop];
a = [1 0];
dev = [dev_p dev_s];

% Kaiser window estimate
[N_kaiser, Wn, beta, ftype] = kaiserord(f, a, dev, Fs);

% Equiripple estimate (Parks–McClellan)
[N_pm, fo, ao, w] = firpmord(f, a, dev, Fs);

fprintf("Estimated order: Kaiser=%d, Equiripple=%d\n", N_kaiser, N_pm);
```


### Minimum-Phase FIR (Reduced Latency)

Use `PhaseConstraint="minimum"` with designfilt (**NOT** `MinimumPhase=true`):

```matlab
% Minimum-phase FIR (lower delay than linear phase, same order)
d = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="equiripple", ...
    PhaseConstraint="minimum");  % CORRECT syntax

% Alternative: firgr with 'minphase' flag (advanced)
b = firgr(filtord(d), [0 Fp/Fn Fst/Fn 1], [1 1 0 0], [1 w], 'minphase');
```

**Trade-offs**:
- Lower group delay than linear-phase (roughly half)
- Non-linear phase (not suitable for phase-sensitive applications)
- Cannot use `filtfilt()` (already minimum phase, would create mixed-phase result)
- Use `filter()` for causal application

---

### IFIR (Interpolated FIR) for Narrow Transitions

For narrow transition bands (trans_pct < 2%; see `quick-ref/efficient-filtering.md`), IFIR reduces total multipliers by using sparse filter + image suppressor at constant sample rate.

**Method 1: fdesign + ifir with SystemObject (Recommended for Filter Analyzer)**

```matlab
% Design IFIR lowpass with fdesign (returns dsp.FilterCascade)
Fpass = 2800; Fstop = 3200; Fs = 44100;

Hf = fdesign.lowpass(Fpass/(Fs/2), Fstop/(Fs/2));

% Two equivalent ways to get dsp.FilterCascade:
d_ifir = ifir(Hf, SystemObject=true);           % Option 1
% d_ifir = design(Hf, 'ifir', SystemObject=true);  % Option 2

% Works directly with Filter Analyzer
filterAnalyzer(d_ifir, FilterNames="IFIR_Lowpass", SampleRates=Fs);

% Apply filter (streaming)
y = d_ifir(x);

% For offline zero-phase, use Method 2 (raw coefficients with filtfilt)
```

**Method 2: Raw ifir() function (For coefficient access and filtfilt)**

```matlab
% Raw IFIR design returns coefficient arrays
Fn = Fs/2;
dev_pass = (10^(Rp/20) - 1) / (10^(Rp/20) + 1);
dev_stop = 10^(-Rs/20);

[b_ifir, b_model, b_image] = ifir(L, "low", [Fpass Fstop]/Fn, [dev_pass dev_stop]);

% Apply with filtfilt (works with raw coefficients)
y = filtfilt(b_ifir, 1, x);

% WARNING: Raw coefficients don't work directly with filterAnalyzer()
% Use Method 1 for Filter Analyzer compatibility
```

**When to use IFIR**:
- Narrow transition bands (trans_pct < 2%; see `quick-ref/efficient-filtering.md`)
- Constant sample rate required (can't use multirate)
- Need fewer multipliers than single-stage FIR

**Trade-offs vs Multirate**:
- IFIR: Constant rate, simpler pipeline, works with Filter Analyzer (Method 1)
- Multirate: May be faster for very narrow bands, but internal rate change

---

## Multirate Design Patterns

### Streaming Multirate (Modern Syntax, R2024a+)

For real-time/streaming applications with polyphase efficiency:

```matlab
% Example: Multistage lowpass (STREAMING/REAL-TIME)
M = 4;  % Decimation factor
Fs_dec = Fs / M;  % Decimated sample rate

% Stage 1: Anti-alias + decimate (modern syntax with SystemObject=true)
dec_filt = designMultirateFIR(DecimationFactor=M, ...
    StopbandAttenuation=Rs, SystemObject=true);

% Stage 2: Sharp lowpass at reduced rate
d_sharp = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs_dec, DesignMethod="equiripple");

% Stage 3: Interpolate + image rejection (modern syntax)
interp_filt = designMultirateFIR(InterpolationFactor=M, ...
    StopbandAttenuation=Rs, SystemObject=true);

% Apply cascade (STREAMING - causal, has group delay)
x_dec = dec_filt(x);             % Decimate
x_filt = filter(d_sharp, x_dec); % Sharp filter at low rate (causal)
y = interp_filt(x_filt);         % Interpolate back to original Fs
```

### Offline Zero-Phase Multirate

For offline batch processing where zero-phase filtering is needed:

```matlab
% Example: Multistage lowpass (OFFLINE - zero-phase)
M = 4;
Fs_dec = Fs / M;

% Stage 1: Decimate with built-in anti-alias (use resample, NOT System objects)
x_dec = resample(x, 1, M);

% Stage 2: Sharp lowpass at reduced rate (zero-phase)
d_sharp = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs_dec, DesignMethod="equiripple");

x_filt = filtfilt(d_sharp, x_dec);  % Zero-phase filtering

% Stage 3: Interpolate back (use resample for proper alignment)
y = resample(x_filt, M, 1);
```

**WARNING**: Do NOT use `dsp.FIRDecimator`/`FIRInterpolator` with `filtfilt()`. See `quick-ref/multirate-offline.md` for details.

### Wideband Rate Conversion (Large M)

For pure rate conversion with large factors (M≥8), use `designMultistageDecimator/Interpolator`:

```matlab
% Wideband rate conversion - multistage automatically optimizes cascade
M = 16;  % Large decimation factor

% Multistage decimator (default wideband TW)
dec = designMultistageDecimator(M);

% Multistage interpolator (default wideband TW)
interp = designMultistageInterpolator(M);

% View cascade structure and cost
info(dec)
cost(dec)

% Apply (streaming)
y_dec = dec(x);
y_out = interp(y_dec);
```

**Note**: These functions automatically factor composite M into stages for minimum MPIS. Benefits increase with M. Default TW is wideband; for narrow-transition filtering, use the streaming/offline patterns above instead.

---

## Application Patterns

### Extract Coefficients from digitalFilter Object

```matlab
% Template
% After designing with designfilt()
d = designfilt("lowpassiir", ...);

% Get CTF form (per-section rows)
B = d.Numerator;      % Lx3 [b0 b1 b2] for each section
A = d.Denominator;    % Lx3 [a0 a1 a2] for each section
L = size(B, 1);       % number of biquad sections

% Convert to SOS matrix (Lx6) if needed
sos = [B A];          % [b0 b1 b2 a0 a1 a2] per row

% DEPRECATED: Don't use d.Coefficients (removed in recent versions)
```

### Offline Validation (Zero-Phase)

```matlab
% Zero-phase reference (doubles effective filter order)
y0 = filtfilt(d, x);

% Frequency response (Hz-aware)
figure;
freqz(d, [], Fs);
grid on;
title('Magnitude & Phase Response');

% Group delay
figure;
grpdelay(d, [], Fs);
grid on;
title('Group Delay vs Frequency');

% Measure achieved specs
[h, f] = freqz(d, 2048, Fs);
mag_dB = 20*log10(abs(h));

% Find -3dB cutoff
idx_3dB = find(mag_dB < -3, 1);
fprintf('-3dB Cutoff: %.2f Hz\n', f(idx_3dB));

% Measure stopband attenuation
stopband_idx = f > Fstop;
min_atten = -max(mag_dB(stopband_idx));
fprintf('Stopband Attenuation: %.1f dB\n', min_atten);
```

### Streaming: CTF Path (R2024b+)

```matlab
% Extract CTF coefficients
B = d.Numerator;
A = d.Denominator;

% ONE-SHOT: Process entire signal (no frame management)
y_all = ctffilt(B, A, x);

% FRAME-BY-FRAME: Real-time with state carryover
frameLen = 1024;
state_ctf = [];  % initialize empty (zeros internally)
N = numel(x);
y_frames = zeros(N, 1);
p = 1;

while p <= N
    q = min(p + frameLen - 1, N);
    [y_frames(p:q), state_ctf] = ctffilt(B, A, x(p:q), state_ctf);
    p = q + 1;
end

% Verify: y_all ≈ y_frames (within numerical precision)
max_error = max(abs(y_all - y_frames));
fprintf('Max streaming error: %.2e\n', max_error);
```

### Streaming: SOS System Object (All Versions)

**PREFERRED METHOD**: Use `SystemObject=true` in `designfilt()`:

```matlab
% Get dsp.SOSFilter directly (no manual coefficient extraction)
sosFilter = designfilt("lowpassiir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="ellip", ...
    SystemObject=true);  % Returns dsp.SOSFilter with ScaleValues

% Access properties if needed
if sosFilter.HasScaleValues
    G = sosFilter.ScaleValues;  % Section scale values
end

% ONE-SHOT
y_all = sosFilter(x);

% FRAME-BY-FRAME (state preserved automatically)
reset(sosFilter);  % ensure known start
frameLen = 1024;
p = 1;
y_frames = zeros(numel(x), 1);

while p <= numel(x)
    q = min(p + frameLen - 1, numel(x));
    y_frames(p:q) = sosFilter(x(p:q));  % state handled internally
    p = q + 1;
end

% Works for codegen, Simulink, and HDL workflows
```

**ALTERNATIVE**: Manual creation from existing `digitalFilter`:

```matlab
% If you already have an IIR digitalFilter object 'd'
d = designfilt("lowpassiir", PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, SampleRate=Fs, DesignMethod="ellip");
B = d.Numerator;
A = d.Denominator;
sosFilt = dsp.SOSFilter('Numerator', B, 'Denominator', A);
y = sosFilt(x);
```

### Advanced Filter Analyzer Usage

```matlab
Fs = 44100;

% Design two filters for comparison
hpIIR = designfilt("highpassiir", ...
    StopbandFrequency=200, PassbandFrequency=300, ...
    StopbandAttenuation=60, PassbandRipple=1, ...
    SampleRate=Fs, DesignMethod="ellip");

hpFIR = designfilt("highpassfir", ...
    StopbandFrequency=200, PassbandFrequency=300, ...
    StopbandAttenuation=70, PassbandRipple=0.5, ...
    SampleRate=Fs, DesignMethod="equiripple");

% Configure frequency-domain display
optsMag = filterAnalysisOptions("magnitude", "phase", ...
    FrequencyNormalizationMode="unnormalized", ...
    ReferenceSampleRateMode="specify", ...
    ReferenceSampleRate=Fs, ...
    FrequencyRange="onesided", ...
    FrequencyScale="log", ...
    NFFT=4096, ...
    NormalizeMagnitude=true);

% IMPORTANT: FilterNames must be valid MATLAB identifiers
filterNames = ["HP_IIR_ellip", "HP_FIR_equiripple"];

[fa, disp1] = filterAnalyzer(hpIIR, hpFIR, ...
    FilterNames=filterNames, ...
    SampleRates=[Fs Fs], ...
    AnalysisOptions=optsMag);

% Add time-domain displays (impulse + step)
optsTD = filterAnalysisOptions("impulse", "step", ...
    ResponseLengthMode="specify", ...
    ResponseLength=512);
disp2 = addDisplays(fa, ...
    AnalysisOptions=optsTD, ...
    FilterNames=filterNames);
```

---

## Complete Examples

### Example 1: Minimal Lowpass (Auto Min-Order, Offline Zero-Phase)

**User Request**: "Design a lowpass filter at 48 kHz, pass 8 kHz, stop 10 kHz, 80 dB attenuation, zero-phase offline"

```matlab
Fs = 48e3;

% High-level one-liner (auto designs minimum order IIR)
[y, d] = lowpass(x, 8e3, Fs, ...
    StopbandAttenuation=80, ...
    ImpulseResponse="iir", ...
    Steepness=0.85);

% Zero-phase reference (offline processing)
y0 = filtfilt(d, x);

% Validate response (Hz-aware)
figure; freqz(d, [], Fs); grid on;
title('Lowpass IIR: |H(f)| & Phase');

figure; grpdelay(d, [], Fs); grid on;
title('Lowpass IIR: Group Delay');

% Report specs
fprintf('Filter Order: %d\n', filtord(d));
[h, f] = freqz(d, 512, Fs);
fprintf('-3dB Cutoff: %.1f Hz\n', f(find(abs(h) < 1/sqrt(2), 1)));
```

### Example 2: Speech Bandpass (IIR with Streaming)

**User Request**: "Bandpass filter for speech (300-3400 Hz) at 44.1 kHz, 1 dB passband ripple, 60 dB stopband, real-time causal"

```matlab
Fs = 44100;

% Design IIR bandpass (IMPORTANT: use scalar edge properties with 1/2 suffixes!)
d = designfilt("bandpassiir", ...
    StopbandFrequency1=200,  PassbandFrequency1=300, ...
    PassbandFrequency2=3400, StopbandFrequency2=3900, ...
    PassbandRipple=1, ...
    StopbandAttenuation1=60, StopbandAttenuation2=60, ...
    SampleRate=Fs, DesignMethod="ellip");

% Streaming: dsp.SOSFilter via SystemObject flag (PREFERRED)
sosFilter = designfilt("bandpassiir", ...
    StopbandFrequency1=200,  PassbandFrequency1=300, ...
    PassbandFrequency2=3400, StopbandFrequency2=3900, ...
    PassbandRipple=1, ...
    StopbandAttenuation1=60, StopbandAttenuation2=60, ...
    SampleRate=Fs, DesignMethod="ellip", ...
    SystemObject=true);  % Returns dsp.SOSFilter directly

y_sos = sosFilter(x);  % Use directly

% Offline zero-phase validation
y0 = filtfilt(d, x);
figure; freqz(d, [], Fs); grid on;

fprintf('Filter Order: %d sections\n', size(d.Numerator, 1));
```

### Example 3: Linear-Phase FIR with Filter Analyzer Overlay

**User Request**: "Linear-phase FIR lowpass at 10 kHz, pass 1 kHz, stop 1.2 kHz, 70 dB attenuation. Compare with IIR."

```matlab
Fs = 1e4;

% FIR design (linear phase, equiripple)
d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=1e3, StopbandFrequency=1.2e3, ...
    PassbandRipple=0.2, StopbandAttenuation=70, ...
    SampleRate=Fs, DesignMethod="equiripple");

% IIR comparator (elliptic, minimum order)
d_iir = designfilt("lowpassiir", ...
    PassbandFrequency=1e3, StopbandFrequency=1.2e3, ...
    PassbandRipple=0.2, StopbandAttenuation=70, ...
    SampleRate=Fs, DesignMethod="ellip");

% Apply FIR with zero-phase
y0 = filtfilt(d_fir, x);

% Overlay comparison in Filter Analyzer
% IMPORTANT: FilterNames must be valid MATLAB identifiers!
fa = filterAnalyzer(d_fir, d_iir, ...
    FilterNames=["FIR_equiripple", "IIR_ellip"], ...
    Analysis="magnitude", ...
    OverlayAnalysis="phase", ...
    SampleRates=[Fs Fs]);

% Report
fprintf('FIR Length: %d taps\n', length(d_fir.Numerator));
fprintf('IIR Order: %d sections\n', size(d_iir.Numerator, 1));
fprintf('FIR Group Delay: %.2f samples\n', mean(grpdelay(d_fir, 1)));
```

**Trade-offs**:
- FIR: Linear phase, ~120 taps
- IIR: Minimum order (4-6 sections), non-linear phase
- FIR suitable for offline; IIR better for real-time

---

## Quick Lookup

| Pattern | Section | Use Case |
|---------|---------|----------|
| High-level one-liners | Quick Design | Rapid prototyping |
| FIR designfilt | Quick Design | Linear phase filters |
| IIR designfilt | Quick Design | Sharp cutoff, minimum order |
| Minimum-phase FIR | Quick Design | Reduced latency |
| Streaming multirate | Multirate | Real-time polyphase |
| Offline multirate | Multirate | Zero-phase with `resample()` |
| Coefficient extraction | Application | Manual coefficient access |
| CTF streaming | Application | R2024b+ real-time |
| SOS streaming | Application | All versions real-time |
| Filter Analyzer | Application | Visual comparison |



----

Copyright 2026 The MathWorks, Inc.

----
