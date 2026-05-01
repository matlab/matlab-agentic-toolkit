# General IIR/FIR Best Practices Card

Open this card when working with high-order IIR, long FIR, `freqz`/`grpdelay` plots, or `filtfilt`.

---

## High-Order IIR: Use SOS Form

The `[b, a]` transfer function form is **numerically unstable** for high-order IIR filters (order > 8).

**Risky**:
```matlab
[b, a] = butter(12, 0.3);  % High-order [b,a] form
y = filter(b, a, x);       % May produce Inf/NaN
```

**Better**:
```matlab
% Option 1: zpk → sos conversion
[z, p, k] = butter(12, 0.3);
sos = zp2sos(z, p, k);
y = sosfilt(sos, x);

% Option 2: designfilt (recommended - handles SOS internally)
d = designfilt("lowpassiir", ...
    FilterOrder=12, HalfPowerFrequency=0.3, ...
    DesignMethod="butter");
y = filter(d, x);  % Uses stable SOS form internally
```

---

## Long FIR: Use fftfilt

Direct convolution (`filter(b, 1, x)`) is slow for FIR filters > ~100 taps.

```matlab
b = d.Numerator;

if length(b) > 100
    y = fftfilt(b, x);  % FFT-based overlap-add (much faster)
else
    y = filter(b, 1, x);  % Direct form OK for short FIR
end
```

**Rule of thumb**: For FIR length N and signal length L:
- `filter()` is O(N*L)
- `fftfilt()` is O(L*log(L)) — wins for large N

---

## freqz/grpdelay: Always Pass Fs

Without `Fs`, plots show normalized frequency (0 to pi) — confusing!

**Confusing**:
```matlab
freqz(d);  % Plots 0 to π normalized
```

**Clear**:
```matlab
freqz(d, [], Fs);     % Plots in Hz
grpdelay(d, [], Fs);  % Group delay axis in Hz
```

Also applies to `phasez`, `zerophase`, etc.

---

## filtfilt: Offline Only!

`filtfilt()` requires the **entire signal** (forward-backward filtering). It is **not** compatible with streaming/real-time.

**Wrong** (real-time loop):
```matlab
% Anti-pattern
for frame = 1:numFrames
    y = filtfilt(d, x_frame);  % ERROR: filtfilt needs entire signal
end
```

**Correct** (streaming):
```matlab
% Use a System object with state management
sosFilt = dsp.SOSFilter('Numerator', B, 'Denominator', A);
for frame = 1:numFrames
    y_frame = sosFilt(x_frame);  % Causal, state preserved
end
```

**Correct** (offline zero-phase):
```matlab
y_offline = filtfilt(d, entire_signal);
```

### filtfilt doubles attenuation (exact)

`filtfilt` applies the filter twice (forward + backward), so effective magnitude = |H(f)|². In dB this is **exact** doubling:
- Effective stopband attenuation = 2 × single-pass Rs
- Effective passband ripple = 2 × single-pass Rp

**Design recipe for target effective specs (Rp_eff, Rs_eff):**
1. Design at halved specs: `PassbandRipple=Rp_eff/2, StopbandAttenuation=Rs_eff/2`
2. Apply: `y = filtfilt(d, x);`
3. Verify effective response: `H_eff_dB = 2 * 20*log10(abs(H));`

---

## Quick Checklist

| Situation | Action |
|-----------|--------|
| IIR order > 8 | Use `designfilt` or `zp2sos` + `sosfilt` |
| FIR length > 100 | Use `fftfilt()` |
| Plotting frequency response | Pass `Fs` to `freqz`, `grpdelay` |
| Real-time filtering | Use `dsp.SOSFilter` or `dsp.FIRFilter` |
| Zero-phase offline | Use `filtfilt()` on entire signal |


----

Copyright 2026 The MathWorks, Inc.

----
