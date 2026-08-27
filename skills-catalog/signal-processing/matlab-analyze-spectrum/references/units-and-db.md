# Units, dB Conversion, and Reference Levels

How to convert spectral quantities to dB, choose the correct reference level for your domain, and report results with proper units.

## dB Conversion Rules

| Quantity Type | Formula | MATLAB |
|:------------:|---------|--------|
| Power (PSD, power spectrum, bandpower) | 10·log₁₀(value/ref) | `pow2db(value/ref)` |
| Amplitude (voltage, pressure, acceleration) | 20·log₁₀(value/ref) | `mag2db(value/ref)` |

**Key rule:** Use `pow2db` for power quantities, `mag2db` for amplitude quantities. If unsure, check the units: if it's squared (W, V², Pa²/Hz), use `pow2db`.

**Never use raw `10*log10(...)` or `20*log10(...)`** — always use `pow2db`/`mag2db`/`db2pow`/`db2mag`. These handle edge cases (zero, negative) gracefully and make intent explicit.

## Why Negative dB Is Normal

Negative dB simply means the value is below the reference level. This is completely normal and expected:
- A signal with power 0.5 W relative to 1 W reference = -3 dB
- An FFT bin with amplitude 0.1 V relative to 1 V reference = -20 dB

**Do not panic at negative dB values.** They only indicate "less than the reference."

## Domain-Specific Reference Levels

| Domain | Quantity | Reference | dB Unit | MATLAB |
|--------|----------|-----------|---------|--------|
| Acoustics | Sound pressure | 20 µPa (air), 1 µPa (water) | dB SPL | `mag2db(p / 20e-6)` |
| Acoustics | Sound power | 1 pW (10⁻¹² W) | dB SWL | `pow2db(P / 1e-12)` |
| Vibration | Acceleration PSD | (m/s²)²/Hz | dB re (m/s²)²/Hz | `pow2db(pxx)` (no ref standard) |
| Vibration | Velocity | 1 nm/s or 10⁻⁹ m/s | dB re 1 nm/s | `mag2db(v / 1e-9)` |
| Electrical | Voltage | 1 V (dBV) or 0.775 V (dBu) | dBV or dBu | `mag2db(v / 1)` or `mag2db(v / 0.775)` |
| Electrical | Power | 1 mW (into 600 Ω) | dBm | `pow2db(P / 1e-3)` |
| RF/Comms | Power density | 1 W/Hz | dB/Hz | `pow2db(pxx)` |
| General | Relative | Signal's own total power | dB (relative) | `pow2db(band / total)` |

## Converting PSD to dB SPL (Acoustics)

Common task: convert PSD (Pa²/Hz) to sound pressure level in each band.

```matlab
Fs = 48000;
pref = 20e-6;  % 20 µPa reference for air

% PSD in Pa²/Hz
[pxx,f] = pwelch(pressure_signal,hann(4096),[],[],Fs);

% PSD in dB/Hz relative to pref²
pxxDB = pow2db(pxx / pref^2);

% Overall SPL from band power
bp = bandpower(pressure_signal,Fs,[20 20000]);
SPL = pow2db(bp / pref^2);

figure
plot(f,pxxDB)
xlabel("Frequency (Hz)")
ylabel("PSD (dB re 20\muPa^2/Hz)")
title(sprintf("Overall SPL = %.1f dB",SPL))
```

## Octave-Band Analysis (Acoustics / Vibration Standards)

For standards-compliant measurements (ANSI S1.11, IEC 61260):

```matlab
% 1/3-octave spectrum
[p,cf] = poctave(x,Fs);

% Convert to dB SPL
pref = 20e-6;
pDB = pow2db(p / pref^2);

figure
bar(pDB)
set(gca,XTickLabel=compose("%.0f",cf))
xlabel("Center Frequency (Hz)")
ylabel("Band Level (dB SPL)")
title("1/3-Octave Band Spectrum")
```

## Comparing Signals of Different Lengths

PSD (power/Hz) is length-independent — the correct quantity for fair comparison:

```matlab
% Signal 1: 2 seconds
[pxx1,f1] = pwelch(x1,hann(512),[],[],Fs);
bp1 = bandpower(pxx1,f1,[fLow fHigh],'psd');

% Signal 2: 10 seconds
[pxx2,f2] = pwelch(x2,hann(512),[],[],Fs);
bp2 = bandpower(pxx2,f2,[fLow fHigh],'psd');

% Compare in dB
diffDB = pow2db(bp2/bp1);
fprintf("Signal 2 has %.2f dB more power in %.0f-%.0f Hz band than Signal 1\n",...
    diffDB,fLow,fHigh);
```

**Note:** The shorter signal's PSD will have higher variance (fewer Welch segments). Mention this when reporting: "Signal 1 PSD estimated from 7 segments (higher uncertainty) vs Signal 2 from 39 segments."

## Reporting Results

Always include:
1. **The quantity and units**: "Band power in 100-500 Hz = 0.23 V²"
2. **The dB value with reference stated**: "-6.4 dB re 1 V²" or "85.2 dB SPL"
3. **For comparisons**: "Signal B has 3.2 dB more power in the 1-4 kHz band than Signal A"

Example reportable conclusion:
```matlab
fprintf("Band power (100-500 Hz):\n");
fprintf("  Signal A: %.2e W  (%.1f dB re 1W)\n",bp1,pow2db(bp1));
fprintf("  Signal B: %.2e W  (%.1f dB re 1W)\n",bp2,pow2db(bp2));
fprintf("  Difference: %.1f dB (B is %.1f%% stronger)\n",...
    pow2db(bp2/bp1),100*(bp2/bp1 - 1));
```

## Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Using `mag2db` on PSD values | Off by factor of 2 in dB | PSD is power → use `pow2db` |
| Using raw `10*log10(...)` | Inconsistent with skill convention, no edge-case handling | Use `pow2db` / `mag2db` |
| No reference level stated | Results are ambiguous | Always state "dB re ..." |
| `pow2db(0)` → -Inf | Crashes or misleading plot | Guard with `max(pxx,eps)` if zeros possible |
| Comparing power spectra of different-length signals | Longer signal has more total power | Use PSD (power/Hz) which is length-independent |
| `bandpower` result "doesn't match" PSD plot | bandpower returns linear power, plot shows dB | `pow2db(bandpower_result)` to compare with dB plot |

----

Copyright 2026 The MathWorks, Inc.

----
