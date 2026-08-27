# poctave API Reference

Fractional-octave spectrum analysis. Introduced R2018a.

## Calling Syntaxes

```matlab
% From time-domain signal
[p,cf] = poctave(x,Fs)
[p,cf] = poctave(x,Fs,'power')            % explicit type (default)
[p,cf,t] = poctave(x,Fs,'spectrogram')    % octave spectrogram

% From pre-computed PSD
[pxx,f] = pwelch(x,[],[],[],Fs);
[p,cf] = poctave(pxx,Fs,f)

% From timetable
[p,cf] = poctave(timetable_input)

% Plot mode (no output)
poctave(x,Fs)
```

## Name-Value Parameters

| Parameter | Values | Default | Notes |
|-----------|--------|---------|-------|
| `BandsPerOctave` | 1, 3/2, 2, 3, 6, 12, 24, 48, 96 | 1 | Use this instead of string like '1/3 octave' |
| `FrequencyLimits` | [fLow fHigh] | [max(3,3*Fs/48e3) Fs/2] | Band range |
| `FilterOrder` | positive even integer | 6 | Order of bandpass filters |
| `Weighting` | "none", "A", "C", vector, digitalFilter | "none" | Frequency weighting |
| `MinThreshold` | real scalar | -Inf | Lower bound for nonzero values |
| `WindowLength` | nonneg integer | — | For spectrogram mode |
| `OverlapPercent` | [0, 100) | — | For spectrogram mode |

## Common Mistakes

- **`poctave(x,Fs,'1/3 octave')`** — WRONG. Use `poctave(x,Fs,'BandsPerOctave',3)`
- **`poctave(x,Fs,'psd')`** — WRONG. Output is always power. Only valid types: `'power'`, `'spectrogram'`
- **`'ReferenceFrequency'`** — Does NOT exist as a parameter

## Typical Usage Patterns

```matlab
% 1/3-octave spectrum (acoustic standards)
[p,cf] = poctave(x,Fs,'BandsPerOctave',3);

% A-weighted 1/3-octave (environmental noise)
[p,cf] = poctave(x,Fs,'BandsPerOctave',3,'Weighting','A');

% Limited frequency range
[p,cf] = poctave(x,Fs,'BandsPerOctave',3,'FrequencyLimits',[20 20000]);

% From existing PSD (avoids recomputing)
[pxx,f] = pwelch(x,[],[],[],Fs);
[p,cf] = poctave(pxx,Fs,f,'BandsPerOctave',3);

% Octave spectrogram (time-varying)
[p,cf,t] = poctave(x,Fs,'spectrogram','BandsPerOctave',3);
```

## Octave Smoothing

Use `poctave(pxx,Fs,f)` to smooth a noisy high-resolution PSD into clean octave bands. This integrates the PSD across each band's bandwidth on a log-frequency scale. Fewer `BandsPerOctave` = smoother result. White noise rises ~3 dB/octave because wider bands integrate more power.

```matlab
% Octave smoothing of a high-res PSD
[pxx,f] = pwelch(x,[],[],[],Fs);

% Smooth into 1/3-octave bands
[p_smooth,cf] = poctave(pxx,Fs,f,'BandsPerOctave',3);

% Overlay raw PSD and smoothed version
figure
plot(f,pow2db(pxx),'Color',[0.7 0.7 0.7])
hold on
stairs(cf,pow2db(p_smooth),'b','LineWidth',1.5)
hold off
set(gca,'XScale','log')
xlabel("Frequency (Hz)")
ylabel("Power (dB)")
legend("PSD (high-res)","1/3-octave smoothed")
grid on
```

## BandsPerOctave Mapping

| Standard Name | BandsPerOctave Value |
|---------------|---------------------|
| Full octave | 1 |
| 1/3 octave | 3 |
| 1/6 octave | 6 |
| 1/12 octave | 12 |
| 1/24 octave | 24 |

----

Copyright 2026 The MathWorks, Inc.

----
