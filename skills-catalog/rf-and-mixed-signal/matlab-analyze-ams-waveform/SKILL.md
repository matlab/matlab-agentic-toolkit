---
name: matlab-analyze-ams-waveform
description: "Analyze AMS waveform data using Mixed-Signal Blockset utilities: phase noise measurement, clock jitter, anti-aliased resampling, timing measurements, lock time, INL/DNL, ADC/DAC calibration, HSpice import. Use when analyzing time-domain voltage from PLL/VCO/clock simulations, measuring phase noise from variable-step solver output, computing jitter, or resampling non-uniform data."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Analyze AMS Waveforms — Mixed-Signal Blockset Utilities

Analyze waveform data using `msblksutilities` functions from the
Mixed-Signal Blockset. Covers timing, phase noise, jitter, lock time,
resampling, INL/DNL, ADC/DAC calibration, and HSpice data import.

## When to Use

- Measuring phase noise from time-domain VCO/PLL simulation output
- Computing period jitter or cycle-to-cycle jitter from clock signals
- Resampling non-uniform (variable-step solver) data to a uniform grid
- Measuring rise/fall time, duty cycle from digital waveforms
- Computing INL/DNL for ADC/DAC characterization
- Importing HSpice simulation results (.tr0, .ac0, .sw0)
- Converting a phase noise profile to integrated RMS jitter

## When NOT to Use

- Spectral analysis with Signal Processing Toolbox (FFT, PSD, spectrogram) — use SPT directly
- Signal quality metrics (SNR, SINAD, THD, SFDR) — use SPT functions (`snr`, `thd`, `sfdr`, `sinad`) directly
- Filtering or envelope detection — use Signal Processing Toolbox directly
- Uniformly-sampled data that doesn't need anti-aliased resampling

---

## Workflow Directive: Phase Noise Parameter Gathering

When the user asks to measure phase noise from waveform data, **ask for frequency
offset points before proceeding**:

1. **Ask:** "At which frequency offsets would you like to measure phase noise?
   Default: `[10e3, 100e3, 1e6, 10e6]` Hz — press Enter to use these or specify
   your own."
2. Once offsets are confirmed, **propose RBW** based on the lowest offset:
   `RBW = min(offsets) / 2` (e.g., 5 kHz for 10 kHz lowest offset). State:
   "I'll use RBW = X Hz (lowest offset / 2). Let me know if you'd like a
   different value."
3. Proceed with measurement unless the user overrides.

This ensures the measurement matches the user's application without requiring
them to know the API signature upfront.

---

## Phase 1: Ingest Waveform Data

### 1.1 Determine Data Source

```matlab
% From workspace variables
x = t;  y = v;

% From .mat file
data = load('waveform.mat');
x = data.time;  y = data.voltage;

% From .csv
data = readmatrix('waveform.csv');
x = data(:,1);  y = data(:,2);

% From HSpice transient (.tr0)
tr0Reader('sim.tr0', 'output.mat');
data = load('output.mat');

% From HSpice AC (.ac0)
ac0Reader('sim.ac0', 'output.mat');

% From HSpice DC sweep (.sw0)
sw0Reader('sim.sw0', 'output.mat');

% From Simulink simulation output (timeseries in logsout)
sig = simOut.logsout.get('signalName').Values;
x = sig.Time(:);          % column vector
y = squeeze(sig.Data(:)); % column vector — squeeze removes trailing dims
```

### 1.2 Basic Waveform Summary

Always print a summary before analysis:

```matlab
fprintf('=== Waveform Summary ===\n');
fprintf('Points     : %d\n', numel(x));
fprintf('X range    : [%.6g, %.6g]\n', min(x), max(x));
fprintf('Y range    : [%.6g, %.6g]\n', min(y), max(y));
fprintf('Y mean     : %.6g\n', mean(y));
fprintf('Y RMS      : %.6g\n', rms(y));
if all(diff(x) > 0)
    dx = diff(x);
    if max(dx)/min(dx) < 1.01, uStr = 'yes'; else, uStr = 'no'; end
    fprintf('X step     : %.6g (uniform: %s)\n', median(dx), uStr);
    if median(dx) > 0
        fprintf('Sample rate: %.6g Hz\n', 1/median(dx));
    end
end
```

### 1.3 MSB Analysis Menu

```
Available MSB analyses for time-domain waveform:

  --- Timing Measurements ---
  [1]  Rise time — timeDomainSignal2RiseTime
  [2]  Fall time — timeDomainSignal2FallTime
  [3]  Duty cycle — timeDomainSignal2DutyCycle

  --- Clock / PLL Measurements ---
  [4]  Phase noise from frequency-domain data — phaseNoiseMeasure (default Type='Frequency')
  [5]  Phase noise from time-domain voltage — phaseNoiseMeasure (Type='Time')
  [6]  Period jitter & cycle-to-cycle jitter — clockJitterMeasure
  [7]  Phase noise to jitter conversion — phaseNoiseToJitter
  [8]  Lock time from control voltage — lockTimeMeasure

  --- Resampling ---
  [9]  Anti-aliased resampling — lowpassResample

  --- ADC/DAC Characterization ---
  [10] INL / DNL measurement — inldnl
  [11] ADC calibration — calibrateADC
  [12] DAC calibration — calibrateDAC

  --- Data Import ---
  [13] HSpice transient (.tr0) — tr0Reader
  [14] HSpice AC (.ac0) — ac0Reader
  [15] HSpice DC sweep (.sw0) — sw0Reader

  --- Frequency-Domain Utilities ---
  [16] Interpolate/extrapolate to new grid — interpExtrap
  [17] Laplace to biquad SOS — laplace2sos
```

---

## Phase 2: Execute Analysis

### 2.1 Timing Measurements

```matlab
% Rise time — 3rd arg is [low high] percent reference levels (required)
rt = timeDomainSignal2RiseTime(x, y, [10 90]);
fprintf('Rise time (10%%-90%%): mean = %.4g s (std = %.4g s, N=%d)\n', ...
    mean(rt), std(rt), numel(rt));

% Fall time — same 3-arg signature
ft = timeDomainSignal2FallTime(x, y, [10 90]);
fprintf('Fall time (90%%-10%%): mean = %.4g s (std = %.4g s, N=%d)\n', ...
    mean(ft), std(ft), numel(ft));

% Duty cycle — returns per-cycle values for multi-cycle waveforms
dc = timeDomainSignal2DutyCycle(x, y);
fprintf('Duty cycle: mean = %.4f%%, std = %.4f%%\n', mean(dc)*100, std(dc)*100);
```

### 2.2 Phase Noise Measurement

**Pre-check (mandatory):** Verify simulation duration before measuring.

```matlab
% Sim duration pre-check — STOP if insufficient
minDuration = 10 / min(FrOffset);   % need >= 10 cycles of lowest offset
simDuration = x(end) - x(1);
if simDuration < minDuration
    error('Simulation too short: %.4g s < %.4g s needed for %.0f Hz offset.\nIncrease sim stop time to >= %.4g s.', ...
        simDuration, minDuration, min(FrOffset), minDuration);
end
```

```matlab
% From time-domain voltage waveform (MSB variable-step simulation output)
% Type='Time' is REQUIRED — extracts phase via zero-crossings internally
Rbw = 1e3;                          % resolution bandwidth (Hz)
FrOffset = [10e3 100e3 1e6 10e6];   % offsets to measure
[PnAtOffsets, freqAxis, pnProfile] = phaseNoiseMeasure( ...
    x(:), y(:), Rbw, FrOffset, 'on', 'PN Measurement', ...
    -inf, ...                       % 7th arg: target PN level for plot overlay (-inf = no target line)
    Type='Time');
% Note: To reduce ripple in pnProfile, use smaller RBW (increases freq resolution)
% or increase simulation duration. SpectralAverages is a PLL Testbench block
% parameter, NOT a phaseNoiseMeasure argument.

% From frequency-domain data (e.g., imported spectrum analyzer measurement)
% Default Type='Frequency': Xin=freq offset vector, Yin=power in dBc/Hz
[PnAtOffsets, freqAxis, pnProfile] = phaseNoiseMeasure( ...
    freqOffsets, pnPower_dBcHz, Rbw, FrOffset, 'on', 'PN from Spectrum');

fprintf('Phase Noise Results:\n');
for k = 1:numel(FrOffset)
    fprintf('  @ %.0f kHz : %.1f dBc/Hz\n', FrOffset(k)/1e3, PnAtOffsets(k));
end

% Save figure for Claude to read
figPath = fullfile(tempdir, 'phase_noise_plot.png');
saveas(gcf, figPath);
fprintf('Phase noise figure saved to: %s\n', figPath);
```

### 2.3 Jitter Measurements

**Mandatory follow-up:** After any phase noise measurement (Section 2.2), ALWAYS
compute integrated RMS jitter using `phaseNoiseToJitter`. Report jitter in
picoseconds — this is the metric engineers compare against specs.

```matlab
% Clock jitter from time-domain waveform
% Returns 2 outputs: [periodJitter, c2cJitter] (RMS values)
% threshold MUST cross the signal — use midpoint or known logic level
% Inputs must be column vectors
threshold = (max(y) + min(y)) / 2;
clockFreq = 1e9;     % expected clock frequency (Hz)
[periodJitter, c2cJitter] = clockJitterMeasure(x(:), y(:), threshold, clockFreq);
fprintf('Period jitter (RMS): %.4f ps\n', periodJitter * 1e12);
fprintf('C2C jitter (RMS)   : %.4f ps\n', c2cJitter * 1e12);

% Convert phase noise profile to jitter
% Exclude DC bin (freqAxis==0) — integration from 0 Hz returns Inf
validIdx = freqAxis > 0;
[jitterRad, jitterDeg, jitterSec] = phaseNoiseToJitter( ...
    freqAxis(validIdx), pnProfile(validIdx), Frequency=carrierFreq);
fprintf('RMS jitter from PN : %.4f ps\n', jitterSec * 1e12);
```

### 2.4 Lock Time Measurement

```matlab
% x = time, y = control voltage (loop filter output)
% lockTimeMeasure takes (voltage, time, tolerance) — note: voltage FIRST
% Both must be column vectors
x_col = x(:);  y_col = y(:);
targetVoltage = y_col(end);   % assume final value is lock voltage
errorTol = 0.01;              % 1% tolerance
lockTime = lockTimeMeasure(y_col, x_col, errorTol);
fprintf('Lock time (%.0f%% tolerance): %.4g s\n', errorTol*100, lockTime);
```

**Preferred method:** If a PLL Testbench block is present, use its measured lock
time (`get_param(tbBlk, 'UserData').lockTime`) — frequency-error detection is
more accurate than voltage settling.

### 2.5 Resampling

```matlab
% Anti-aliased resampling to new sample time
Ts_new = 1e-9;
tq = (x(1) : Ts_new : x(end))';
cfg.OutputRiseFall = Ts_new;
cfg.NDelay = 1;
cfg.SampleMode = 'variable';
cfg.CausalMode = 'off';
y_resampled = lowpassResample(x, y, tq, cfg);
x_resampled = tq;
```

### 2.6 INL/DNL Measurement

```matlab
% ADC: uses transition-based fit (works on ANY input stimulus, not just ramps)
result = inldnl(Analog, Digital, Range, 'ADC', ...
    'INLMethod', 'All', 'DNLMethod', 'All', ...
    'OffsetErrorUnit', 'All', 'GainErrorUnit', 'All');

fprintf('Max |Endpoint INL|: %.4f LSB\n', max(abs(result.EndpointINL)));
fprintf('Max |Endpoint DNL|: %.4f LSB\n', max(abs(result.EndpointDNL)));
fprintf('Offset Error: %.4f LSB\n', result.OffsetErrorLSB);
fprintf('Gain Error: %.4f LSB\n', result.GainErrorLSB);

% DAC: uses center-based fit (FitMode='centers' is default for DAC)
result_dac = inldnl(Analog, Digital, Range, 'DAC', ...
    'INLMethod', 'All', 'DNLMethod', 'All');
```

**Critical:** Do NOT use histogram-based DNL (code bin counts). That method
requires a specific input stimulus (ramp or sine with known PDF). The `inldnl`
function uses transition-based analysis that works on arbitrary inputs.

**ADC vs DAC:** ADC uses `FitMode='transitions'` (default); DAC uses
`FitMode='centers'`. Using the wrong fit mode gives incorrect results.

### 2.7 ADC/DAC Calibration

```matlab
% Calibrate ADC: correct offset and gain errors
y_cal = calibrateADC(Digital, NBits, Polarity);
% Or infer errors from measured data:
y_cal = calibrateADC(Analog, Digital, Range, 'OffsetError', oe, 'GainError', ge);

% Calibrate DAC:
y_cal = calibrateDAC(Digital, NBits, Polarity);
% Or with reference/bias:
y_cal = calibrateDAC(Digital, Analog, Ref, Bias);
```

---

## Phase 3: Interpreting Phase Noise Plots

### 3.1 Slope Analysis

| Region | Slope | Physical Meaning |
|--------|-------|-----------------|
| Close-in (< loop BW) | -30 dB/dec | 1/f^3 -- flicker FM noise dominates |
| Mid-range | -20 dB/dec | 1/f^2 -- white FM / VCO thermal noise |
| Far-out (> loop BW) | -20 dB/dec then flat | VCO open-loop noise, then thermal floor |

### 3.2 Loop Bandwidth Hump

A hump or peak (3-10 dB) indicates the PLL closed-loop bandwidth.
If >10 dB, the loop may be under-damped (low phase margin).

### 3.3 Noise Floor

Far-out floor (beyond 1-10 MHz offset) is set by VCO thermal noise
and simulation numerical noise. Should match VCO open-loop spec.

### 3.4 Artifacts and Ripple

- **High-frequency ripple**: Insufficient spectral averaging
- **Spurious tones**: Expected at multiples of fPFD in frac-N PLLs
- **Flat/rising at low offsets**: Simulation too short (see W9)

### 3.5 Example Interpretation

```
Phase noise from a 1 GHz VCO (MSB sim, 100 us, zero-crossing):
  @ 10 kHz  : -51.8 dBc/Hz  <- marginal (sim too short)
  @ 100 kHz : -82.4 dBc/Hz  <- in 1/f^2 region, reasonable
  @ 1 MHz   : -98.4 dBc/Hz  <- approaching noise floor
  @ 10 MHz  : -127.6 dBc/Hz <- VCO open-loop thermal floor

Observations:
- -20 dB/dec slope from 10-80 kHz confirms white FM noise
- Hump at 100-300 kHz suggests loop BW artifact
- Floor at -128 dBc/Hz consistent with VCO open-loop spec
- 10 kHz result unreliable -- need >= 1 ms sim for clean data
```

---

## Phase 4: Reporting

### 4.1 Save Figure for Inspection

```matlab
figPath = fullfile(tempdir, 'analysis_plot.png');
saveas(gcf, figPath);
fprintf('Figure saved to: %s\n', figPath);
```

After MATLAB prints `figPath`, use the **Read** tool to open the PNG
and provide observations (slope, artifacts, noise floor per Phase 3).

### 4.2 Generate HTML Report

Always generate an HTML report with:
1. Header (data file, date, method, MATLAB version)
2. MATLAB console output in dark-themed `<pre>` block
3. Waveform summary table
4. Measurement config table
5. Numeric results table
6. Embedded figure via `file:///` URL
7. Observations from Phase 3
8. Recommendations
9. Footer: "Generated by Claude Code -- Waveform Analysis Skill -- {date}"

Naming: `report_{datafile_stem}.html` in the same directory as the data.

---

## Quick Reference: MSB Function Sources

| Function | Purpose |
|----------|---------|
| `phaseNoiseMeasure` | Phase noise measurement |
| `phaseNoiseToJitter` | Phase noise to jitter |
| `clockJitterMeasure` | Period & cycle-to-cycle jitter |
| `lockTimeMeasure` | PLL lock time |
| `timeDomainSignal2RiseTime` | Rise time |
| `timeDomainSignal2FallTime` | Fall time |
| `timeDomainSignal2DutyCycle` | Duty cycle |
| `inldnl` | INL/DNL measurement |
| `calibrateADC` | ADC error calibration |
| `calibrateDAC` | DAC error calibration |
| `lowpassResample` | Anti-aliased resampling |
| `interpExtrap` | Multi-signal interpolation |
| `laplace2sos` | Laplace to biquad SOS |
| `ac0Reader` | Import HSpice AC data |
| `tr0Reader` | Import HSpice transient data |
| `sw0Reader` | Import HSpice DC sweep data |

---

## Pitfalls (MSB-specific)

- **W1**: Always compute `Fs` from data (`1/median(diff(x))`) rather than assuming
- **W2**: For phase noise, RBW should be <= half the lowest offset frequency
- **W3**: For time-domain voltage data (MSB sim output), always pass `Type='Time'`. The only valid types are `'Frequency'` (default) and `'Time'`
- **W4**: For non-uniformly sampled data, resample to uniform grid first using `lowpassResample`
- **W5**: `clockJitterMeasure` needs the nominal clock frequency from design spec, not estimated from data
- **W6**: HSpice readers output .mat files -- load them after conversion
- **W7**: MSB uses variable-step discrete solver, producing non-uniform time data. Voltage-based FFT methods will fail — always use `phaseNoiseMeasure(..., Type='Time')` which extracts phase via zero-crossings internally
- **W8**: Zero-crossing `phaseNoiseMeasure` reports center frequency as f_carrier/2 -- this is a display convention, carrier is still correct
- **W9**: Simulation duration limits lowest measurable offset: need >= `10/f_offset_min` seconds. E.g., 10 kHz offset requires >= 1 ms sim time
- **W10**: PN profile ripple is reduced by using smaller RBW or longer simulation duration. `SpectralAverages` is a **PLL Testbench block** parameter (set via `set_param`), NOT a `phaseNoiseMeasure` argument
- **W11**: MSB variable-step data shows `max(dt)/min(dt) >> 1`. This is expected — use `Type='Time'` for PN, or `lowpassResample` to create a uniform grid for FFT
- **W12**: `clockJitterMeasure` returns NaN if threshold doesn't cross the signal. Use `(max(y)+min(y))/2` or the known logic threshold
- **W13**: `phaseNoiseToJitter` returns Inf if `freqAxis(1)==0`. Always exclude the DC bin before calling
- **W14**: NEVER use histogram-based DNL on MSB simulation data. MSB outputs are not uniform ramps — histogram method gives 1000x+ errors. Always use `inldnl(Analog, Digital, Range, Type)` which uses transition detection
- **W15**: For ADC use `FitMode='transitions'` (default). For DAC use `FitMode='centers'`. Using the wrong fit mode corrupts INL results
- **W16**: All MSB measurement functions (`lockTimeMeasure`, `clockJitterMeasure`, `phaseNoiseMeasure` Type='Time') expect **column vectors**. Use `x(:)` and `y(:)` to ensure correct shape. Row vectors produce silent wrong results or errors

----

Copyright 2026 The MathWorks, Inc.

----
