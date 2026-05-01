# Filter Design Best Practices

Guidelines for robust filter design, validation workflows, and professional interactions. Consult this file when you need guidance on methodology and approach.

## Table of Contents
- [Core Principles](#core-principles)
- [Provide Complete Solutions](#provide-complete-solutions)
- [Documentation Usage Strategy](#documentation-usage-strategy)
- [Common Tasks Reference](#common-tasks-reference)
- [Example Interaction Pattern](#example-interaction-pattern)
- [Validation Workflow](#validation-workflow)
- [Architecture Decision Workflow](#architecture-decision-workflow)
- [Streaming vs Offline](#streaming-vs-offline)
- [Performance Optimization](#performance-optimization)
- [Quick Lookup](#quick-lookup)

---

## Core Principles

### Always Consider

1. **Sample Rate Implications**
   - Frequency specifications are relative to Fs/2 (Nyquist)
   - Narrow transition bands (< 2% of Fs) require special handling
   - Plot in Hz for clarity: `freqz(d, [], Fs)`

2. **Filter Order vs Performance Trade-offs**
   - Higher order = sharper cutoff but more computation
   - IIR = fewer coefficients but non-linear phase
   - FIR = linear phase but longer filters

3. **Computational Efficiency for Real-Time**
   - Prefer IIR for streaming with sharp cutoff
   - Use multistage for narrow transition bands
   - Consider `fftfilt()` for long FIR (> 100 taps)

4. **Numerical Stability for IIR**
   - Always use SOS or CTF form (not `[b,a]`)
   - Use `designfilt()` which handles stability internally
   - For high-order IIR (> 8), verify pole locations

---

## Provide Complete Solutions

Every filter design response should include:

### 1. Design Code
```matlab
d = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="equiripple");
```

### 2. Visualization Code
```matlab
figure;
freqz(d, [], Fs);
grid on;
title('Filter Response');
```

### 3. Parameter Explanation
- Why this filter type was chosen
- Trade-offs considered
- Key specifications achieved

### 4. Validation Steps
- How to verify the design meets specs
- Test signal suggestions
- Performance metrics to check

---

## Documentation Usage Strategy

### Start Broad, Drill Down

1. **First**: Check references/INDEX.md for file summaries
2. **Overview**: Read `signal_filter-design.md` for concepts
3. **Details**: Drill into `ref_designfilt.md` for exact syntax
4. **Examples**: Check `examples/` for complete workflows

### Reference During Design

- **Verify syntax** against official docs before executing
- **Check examples** in documentation for similar problems
- **Confirm parameters** for edge cases (bandpass, notch, etc.)

---

## Common Tasks Reference

### Task: Design Lowpass Filter

1. **Check quick-reference.md** for parameter templates
2. **Read relevant section** from `ref_designfilt.md`
3. **Generate MATLAB code** using `designfilt()`
4. **Test if MCP available** by running code
5. **Provide visualization** code for frequency response

### Task: Choose Design Method

**Consult** `signal_filter-design.md` for:
- Design method comparison
- When to use each approach
- Trade-offs between methods

**Reference** `ref_designfilt.md` for:
- Available methods per filter type
- Method-specific parameters
- Examples using each method

### Task: Analyze Existing Filter

1. **Guide user** to use Filter Analyzer app
2. **Reference** `ref_filteranalyzer-app.md` for:
   - How to import filters
   - Available analysis types
   - Interpretation of results

### Task: Apply Filter to Data

1. **Determine requirements**:
   - Need zero phase? → Use `filtfilt()`
   - Long FIR filter? → Consider `fftfilt()`
   - Streaming/real-time? → Use `dsp.SOSFilter`
   - Standard application? → Use `filter()`

2. **Reference appropriate documentation**:
   - `ref_filtfilt.md` for zero-phase requirements
   - `ref_fftfilt.md` for performance optimization
   - `ref_filter.md` for state management

---

## Example Interaction Pattern

**User Request**: "I need a bandpass filter for 50-100 Hz signal at 1000 Hz sampling rate"

**Your Response Pattern**:

### Step 1: Clarify Requirements
Ask about:
- FIR or IIR preference?
- Phase requirements (linear, zero, minimum)?
- Stopband attenuation needed?

### Step 2: Read Documentation
Check `ref_designfilt.md` for bandpass filter syntax

### Step 3: Recommend Approach
Suggest FIR equiripple (linear phase) or IIR Butterworth (minimum order)

### Step 4: Generate Code
Provide complete `designfilt()` code with all parameters

### Step 5: Test (if MCP available)
Execute and show frequency response

### Step 6: Guide Application
Explain how to apply with `filter()` or `filtfilt()`

---

## Validation Workflow

### Pre-Application Checks

```matlab
% 1) Order (MATLAB's actual order)
fprintf("Filter order: %d\n", filtord(d));

% 2) Frequency response (Hz-aware)
Nfft = 8192;
[h, f] = freqz(d, Nfft, Fs);
mag_dB = 20*log10(abs(h) + eps);

% 3) If the final application is filtfilt(d,x), verify the *effective* response
use_filtfilt = false;  % set true if you will apply filtfilt()
if use_filtfilt
    mag_dB = 2*mag_dB;  % |H|^2 -> dB doubles
end

% 4) Build pass/stop masks by RESPONSE TYPE
responseType = "lowpass";  % "highpass" | "bandpass" | "bandstop"

switch responseType
    case "lowpass"
        pass = f <= Fpass;
        stop = f >= Fstop;
    case "highpass"
        pass = f >= Fpass;
        stop = f <= Fstop;
    case "bandpass"
        pass = (f >= Fpass1) & (f <= Fpass2);
        stop = (f <= Fstop1) | (f >= Fstop2);
    case "bandstop"
        pass = (f <= Fpass1) | (f >= Fpass2);
        stop = (f >= Fstop1) & (f <= Fstop2);
end

% 5) Measured specs (worst-case)
Rp_meas_dB = max(mag_dB(pass)) - min(mag_dB(pass));
Rs_meas_dB = -max(mag_dB(stop));

fprintf("Measured ripple: %.3f dB (spec %.3f dB)\n", Rp_meas_dB, Rp);
fprintf("Measured stopband attenuation: %.1f dB (spec %.1f dB)\n", Rs_meas_dB, Rs);

% 6) Plot (optional but recommended)
figure; plot(f, mag_dB); grid on;
xlabel("Frequency (Hz)"); ylabel("Magnitude (dB)");
title("Magnitude Response (verified in Hz)");
```

### Post-Filtering Checks

```matlab
% 1. Visual comparison
figure;
plot(t, x, 'b', t, y, 'r');
legend('Original', 'Filtered');

% 2. Spectrum comparison
figure;
pwelch(x, [], [], [], Fs); hold on;
pwelch(y, [], [], [], Fs);
legend('Original', 'Filtered');

% 3. SNR improvement (if ground truth available)
snr_before = 10*log10(sum(clean.^2) / sum((noisy - clean).^2));
snr_after = 10*log10(sum(clean.^2) / sum((filtered - clean).^2));
fprintf('SNR Improvement: %.1f dB\n', snr_after - snr_before);
```

---

## Architecture Decision Workflow

### Pre-Design Check (MANDATORY)

For EVERY filter design, calculate:

```matlab
% Template
% Transition width (Δf) should match the RESPONSE TYPE.
% Use the *constraining* transition (smallest transition band) in Hz.
%
% lowpass:   Δf = Fstop - Fpass
% highpass:  Δf = Fpass - Fstop
% bandpass:  Δf = min(Fpass1 - Fstop1, Fstop2 - Fpass2)
% bandstop:  Δf = min(Fstop1 - Fpass1, Fpass2 - Fstop2)

delta_f = ...;                         % fill based on response type (Hz)
trans_pct = 100 * (delta_f / Fs);      % Transition width as % of sample rate

% FIR length heuristic (sanity check only; not a guarantee)
N_est = (Rs * Fs) / (22 * delta_f);

% Max decimation factor is straightforward for LOWPASS cases:
% M_max ≈ floor(Fs / (2 * Fstop))
% For highpass/band* cases, safe decimation depends on spectral placement and is not a single formula.
M_max = floor(Fs / (2 * Fstop));
```


        ### Prefer MATLAB-Native FIR Order Estimators (recommended)

        The heuristic `N_est = (Rs * Fs)/(22 * Δf)` is **sanity-check only**. For a more standard, MATLAB-native estimate:

        - **Kaiser window estimate**: `kaiserord` (good quick order estimate for windowed FIR)
        - **Equiripple estimate**: `firpmord` (order estimate for Parks–McClellan FIR)

        ```matlab
        % Convert dB specs to linear deviations
        dev_p = (10^(Rp/20)-1) / (10^(Rp/20)+1);
        dev_s = 10^(-Rs/20);

        % LOWPASS example (adapt f/a for other responses):
        f = [Fpass Fstop];     % Hz
        a = [1 0];             % desired amplitudes in each band
        dev = [dev_p dev_s];   % linear deviations

        [N_kaiser, Wn, beta, ftype] = kaiserord(f, a, dev, Fs);
        [N_pm, fo, ao, w] = firpmord(f, a, dev, Fs);

        fprintf("Order estimates: Kaiser=%d, Equiripple=%d\n", N_kaiser, N_pm);
        ```

        **Workflow recommendation**:
        1) Use `kaiserord`/`firpmord` to estimate if a single-stage FIR is plausible.
        2) Design the real filter (e.g., `designfilt(..., DesignMethod="equiripple")`).
        3) Verify with `freqz` + measured `Rp_meas_dB` / `Rs_meas_dB`.


### Decision Matrix

| trans_pct | Action |
|-----------|--------|
| > 5% | Single-stage OK |
| 2-5% | Mention multistage option |
| < 2% | **Present tradeoff to user** (see `quick-ref/efficient-filtering.md`) |

### Response Template

> "Architecture check: Transition BW = X% of Fs, estimated ~Y taps. [Single-stage recommended / Multistage recommended - asking user preference]."

---

## Streaming vs Offline

### Offline Processing

- Use `filtfilt()` for zero-phase
- Use `resample()` for multirate
- Process entire signal at once
- No state management needed

### Streaming/Real-Time

- Use `dsp.SOSFilter` with `SystemObject=true`
- Or use `ctffilt()` (R2024b+) with state management
- Process frame-by-frame
- Reset state when needed

### Key Rule

**Offline zero-phase** → `resample()` + `filtfilt()`
**Streaming causal** → System objects + `filter()`

Never mix: System objects with `filtfilt()` = catastrophic failure 

---

## Performance Optimization

### Long FIR Filters

```matlab
if length(b) > 100
    y = fftfilt(b, x);  % FFT-based, faster
else
    y = filter(b, 1, x);  % Direct form OK
end
```

### Narrow Transition Bands

- Consider multistage approach
- Calculate efficiency gain: `(N_single) / (N_dec + N_sharp/M + N_interp)`
- For trans_pct < 2%, multistage often 5-10x more efficient (see `quick-ref/efficient-filtering.md`)

### IIR Numerical Stability

- Always use SOS form via `designfilt()` or `zp2sos()`
- Avoid `[b,a]` form for order > 8
- Check pole locations if stability concerns arise

---

## Quick Lookup

| Topic | Consult |
|-------|---------|
| Code templates | `patterns.md` |
| API details | references/INDEX.md |
| Architecture decision | Pre-Design Check above |
| Offline vs streaming | Streaming vs Offline section |
| Validation | Validation Workflow section |



----

Copyright 2026 The MathWorks, Inc.

----
