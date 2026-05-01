# Direct Equalization on Waveforms

Process time-domain waveforms through SerDes datapath blocks directly in MATLAB,
outside of `SerdesSystem.analysis()`. Enables custom equalization chains, A/B
comparisons, and waveform-level debugging.

For eye diagram analysis, jitter decomposition, and metrics extraction, see
`reference/visualization-and-metrics.md`.

## WaveType Modes

| WaveType | Input | Processing | Use For |
|----------|-------|------------|---------|
| `"Impulse"` | Impulse response vector | LTI convolution (Init path) | Design exploration, pulse metrics |
| `"Sample"` | Time-domain waveform | Sample-by-sample (GetWave path) | Realistic waveform equalization |

## Block Input Requirements

| Block | Impulse Mode | Sample Mode |
|-------|-------------|-------------|
| `serdes.FFE` | Full vector | Full vector |
| `serdes.CTLE` | Full vector | Full vector |
| `serdes.DFECDR` | Full vector | **Scalar only** (sample-by-sample loop) |
| `serdes.DFE` | Full vector | **Scalar only** (sample-by-sample loop) |
| `serdes.AGC` | Full vector | Full vector |
| `serdes.VGA` | Full vector | Full vector |
| Custom blocks | Full vector | Depends on implementation |

**Critical:** DFECDR and DFE in Sample mode require a `for` loop processing
one sample at a time. Passing a full vector errors with
`"Expected waveIn to be a scalar"`.

## Required Properties

Every block needs these properties set before calling:

```matlab
block.SymbolTime = symbolTime;
block.SampleInterval = sampleInterval;
block.WaveType = "Impulse";  % or "Sample"
```

## Impulse Mode Chain

```matlab
% Channel impulse -> FFE -> CTLE -> pulse -> metrics
ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
ffe.SymbolTime = 100e-12;  ffe.SampleInterval = dt;  ffe.WaveType = "Impulse";

ctle = serdes.CTLE('Specification', "DC Gain and AC Gain", 'DCGain', 0, 'ACGain', 8);
ctle.SymbolTime = 100e-12;  ctle.SampleInterval = dt;  ctle.WaveType = "Impulse";

eqImpulse = ctle(ffe(channelImpulse));
eqPulse = impulse2pulse(eqImpulse, samplesPerSymbol, dt);
metrics = optPulseMetric(eqPulse, samplesPerSymbol, dt, 1e-6);
```

## Channel Convolution Scaling

Channel impulse responses from `analysis()` and `serdes.ChannelLoss.impulse` are in
V/s (continuous-time units). When using `filter()` for FIR convolution, multiply by
`dt` to convert to unitless discrete-time coefficients:

```matlab
% WRONG — impulse is V/s, output blows up by ~10^11
chWave = filter(channelImpulse, 1, stimWave);

% CORRECT — multiply by dt for proper scaling
chWave = filter(channelImpulse * dt, 1, stimWave);
% Verify: sum(channelImpulse * dt) ≈ 1.0 (DC gain)
```

## Sample Mode Chain with DFECDR

**Mode matters:** Mode=0 is passthrough (no DFE). Mode=1 applies fixed taps + CDR.
Mode=2 applies taps + CDR + adaptation. Always use Mode>=1 for DFE to function.

**Adapted taps are the second output** — `[y, taps, phase] = dfecdr(x)`. The
`TapWeights` property always retains its initial value.

**Convergence:** Default `EqualizationGain` (9.6e-05) needs 80K+ symbols. Either
increase to 9.6e-04 (10x) for 20K-symbol convergence, or pre-load adapted taps
from `results.outparams` for instant convergence (recommended for NRZ).

**PAM4 time-domain caveat:** Pre-loaded taps from `analysis()` work well for NRZ
but often fail for PAM4 — the statistical path uses different signal normalization.
For PAM4 waveform processing, use adaptive DFE (Mode=2) with `EqualizationGain`
>= 5e-3, and measure the eye on the **converged portion** only (skip initial
transient). Also: at low loss (<=15 dB), CTLE over-boosts PAM4 — use DFE-only
(ACGain=0) for better COM in time-domain.

```matlab
% Waveform -> FFE -> CTLE -> DFECDR (sample loop) -> eyeDiagramSI
modulation = 4;  % PAM4 (set to 2 for NRZ)

ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
ffe.SymbolTime = 100e-12;  ffe.SampleInterval = dt;  ffe.WaveType = "Sample";

ctle = serdes.CTLE('Specification', "DC Gain and AC Gain", 'DCGain', 0, 'ACGain', 8);
ctle.SymbolTime = 100e-12;  ctle.SampleInterval = dt;  ctle.WaveType = "Sample";

% Option A: Pre-load adapted taps from analysis() (recommended — instant convergence)
adaptedTaps = results.outparams{end}.DFECDR.TapWeights;
dfecdr = serdes.DFECDR('TapWeights', adaptedTaps, 'Mode', 1);
% Option B: Adaptive with 10x gain (needs 20K+ symbols to converge)
% dfecdr = serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2);
% dfecdr.EqualizationGain = 9.6e-04;  % 10x default for faster convergence
dfecdr.SymbolTime = 100e-12;  dfecdr.SampleInterval = dt;  dfecdr.WaveType = "Sample";
dfecdr.Modulation = modulation;  % Required for PAM-N — defaults to NRZ (2)

w1 = ffe(wave);
w2 = ctle(w1);
w3 = zeros(size(w2));
for k = 1:numel(w2)
    [w3(k), adaptedTaps] = dfecdr(w2(k));  % capture adapted taps as 2nd output
end

eyeObj = eyeDiagramSI;
eyeObj.SampleInterval = dt;  eyeObj.SymbolTime = 100e-12;  eyeObj.Modulation = modulation;
eyeObj(w3);
fprintf("Eye Height: %.1f mV\n", eyeHeight(eyeObj) * 1e3);
```

## Lifecycle: release() Between Reconfiguration

Call `release(block)` before changing `WaveType` or structural properties
on a locked System object:

```matlab
ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
ffe.SymbolTime = 100e-12;  ffe.SampleInterval = dt;
ffe.WaveType = "Impulse";
yImpulse = ffe(impulse);       % first use locks the object

release(ffe);                   % unlock before changing WaveType
ffe.WaveType = "Sample";
ySample = ffe(waveform);        % now processes as time-domain samples
```

## Common Mistakes

### 1. Full Vector to DFECDR in Sample Mode

```matlab
% WRONG — DFECDR expects scalar in Sample mode
dfecdr.WaveType = "Sample";
y = dfecdr(waveform);          % ERROR: Expected waveIn to be a scalar

% CORRECT — loop sample by sample
y = zeros(size(waveform));
for k = 1:numel(waveform)
    y(k) = dfecdr(waveform(k));
end
```

### 2. Forgetting WaveType or Timing Properties

```matlab
% WRONG — defaults to SampleInterval=1, SymbolTime=8 (unitless)
ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
y = ffe(waveform);  % runs but produces wrong results

% CORRECT — always set timing and WaveType
ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
ffe.SymbolTime = symbolTime;
ffe.SampleInterval = dt;
ffe.WaveType = "Sample";
y = ffe(waveform);
```

## Pattern: Direct Equalization of a Captured Waveform

```matlab
% waveIn = column vector of voltage samples (oscilloscope or imported data)
symbolTime = 100e-12;  dt = 6.25e-12;  modulation = 4;  % PAM4
samplesPerSymbol = round(symbolTime / dt);

% Equalization chain — all blocks need timing + WaveType = "Sample"
ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
ffe.SymbolTime = symbolTime;  ffe.SampleInterval = dt;  ffe.WaveType = "Sample";
ctle = serdes.CTLE('Specification', "DC Gain and AC Gain", 'DCGain', 0, 'ACGain', 8);
ctle.SymbolTime = symbolTime;  ctle.SampleInterval = dt;  ctle.WaveType = "Sample";

% DFECDR: pre-load adapted taps from analysis() — Mode>=1 required (Mode=0 is passthrough)
adaptedTaps = results.outparams{end}.DFECDR.TapWeights;
dfecdr = serdes.DFECDR('TapWeights', adaptedTaps, 'Mode', 1);
dfecdr.SymbolTime = symbolTime;  dfecdr.SampleInterval = dt;  dfecdr.WaveType = "Sample";
dfecdr.Modulation = modulation;  % Required for PAM-N — defaults to NRZ

% FFE/CTLE accept vectors; DFECDR needs sample-by-sample. Taps are 2nd output.
w1 = ffe(waveIn);  w2 = ctle(w1);
w3 = zeros(size(w2));
for k = 1:numel(w2)
    [w3(k), adaptedTaps] = dfecdr(w2(k));
end

% Analyze equalized waveform
eyeObj = eyeDiagramSI;
eyeObj.SampleInterval = dt;  eyeObj.SymbolTime = symbolTime;  eyeObj.Modulation = modulation;
eyeObj(w3);
fprintf("EH: %.1f mV, COM: %.2f dB\n", eyeHeight(eyeObj)*1e3, com(eyeObj));
J = jitter(w3, SampleInterval=dt, SymbolTime=symbolTime, Plot=false);
fprintf("TJ: %.2f ps, RJ: %.2f ps, DDJ: %.2f ps\n", ...
    J.TJpkpk*1e12, J.RJrms*1e12, J.DDJpkpk*1e12);
```

----

Copyright 2026 The MathWorks, Inc.
----
