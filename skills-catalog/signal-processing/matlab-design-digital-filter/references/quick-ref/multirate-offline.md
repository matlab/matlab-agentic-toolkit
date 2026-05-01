# Multirate OFFLINE Card (rate change + zero‑phase)

Use this card when the user wants:
- output returned to the **original sample rate**, but
- is OK with an **internal rate change**, and
- wants **offline / batch** processing (zero‑phase is on the table).

## Critical Gotcha: System Objects + filtfilt = Catastrophic

**Never** combine multirate System objects with `filtfilt()`:

```matlab
% Anti-pattern
% WRONG - causes severe signal degradation (e.g., -27 dB SNR)
decimator = dsp.FIRDecimator(M, b_dec);
interpolator = dsp.FIRInterpolator(M, b_interp);

x_dec = decimator(x);              % System object has internal state
x_filt = filtfilt(d, x_dec);       % filtfilt assumes no state - MISALIGNED!
y = interpolator(x_filt);          % Output is garbage
```

**Why**: System objects maintain internal state and group delays. `filtfilt()` processes forward/backward assuming clean start states, causing catastrophic misalignment.

**Solution**: Use `resample()` for offline zero-phase multirate:

```matlab
x_dec = resample(x, 1, M);         % Built-in anti-alias, proper alignment
x_filt = filtfilt(d_sharp, x_dec); % Zero-phase at reduced rate
y = resample(x_filt, M, 1);        % Interpolate back properly
```

## Canonical offline pipeline

```matlab
Fs = 44100;
M  = 4;
Fs_dec = Fs/M;

% 1) Downsample with built-in anti-aliasing
x_dec = resample(x, 1, M);

% 2) Design the sharp filter at the reduced rate
d_sharp = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs_dec, DesignMethod="equiripple");

% 3) Zero-phase filtering at low rate
y_dec = filtfilt(d_sharp, x_dec);

% 4) Upsample back (built-in anti-imaging)
y = resample(y_dec, M, 1);
```

## Notes that avoid “confident nonsense”

- `resample()` has hidden filter cost (not exposed via `cost()`).
  - Use `timeit()` if you need wall-clock timing.
- If you use `filtfilt(d_sharp, ...)`, the effective magnitude response is **squared**.
  - Expect stopband attenuation in dB to roughly **double**.
- For architecture choice (narrow transitions), compare against:
  - single-stage FIR (high MPIS),
  - constant-rate multistage FIR (IFIR), if rate change is not acceptable.


----

Copyright 2026 The MathWorks, Inc.

----
