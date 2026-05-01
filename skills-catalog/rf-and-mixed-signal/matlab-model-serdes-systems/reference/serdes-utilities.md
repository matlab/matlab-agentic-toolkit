# SerDes Utility Functions

Utility functions in the `serdes.utilities` namespace for signal quality
metrics, signal manipulation, CTLE pole/zero generation, and formatting.
All functions are called as `serdes.utilities.<FunctionName>(...)`.

## Signal Quality Metrics

### SER (Symbol Error Rate)

Class that calculates symbol error rate from stimulus and equalized waveforms.

```matlab
ser = serdes.utilities.SER;
ser.SymbolTime = symbolTime;
ser.SampleInterval = dt;
ser.Modulation = modulation;       % 2 = NRZ, 4 = PAM4, etc.
ser.IgnoreSymbols = 100;           % skip CDR convergence period

% Inputs: stimulus (1 sample/symbol), equalized wave, clock, thresholds
calculateSER(ser, stimulusSymbols, equalizedWave, clock, thresholds);

% Read results
fprintf("SER = %g\n", ser.SymbolErrorRate);
plotComparison(ser);  % overlay stimulus vs latched symbols
```

**Properties:**

| Property | Description |
|----------|-------------|
| `SymbolTime` | Symbol period (seconds) |
| `SampleInterval` | Sample interval (seconds) |
| `Modulation` | Number of symbol levels (2, 3, 4, ...) |
| `IgnoreSymbols` | Symbols to skip before counting errors |
| `SymbolErrorRate` | Read-only. Computed SER after `calculateSER` |

**Critical:** The `clock` input must come from `pulseRecoverClock` or a CDR
object — do not use arbitrary sample indices. The clock waveform has
rising/falling edges that signal the latch point.

### SNR (Signal-to-Noise Ratio)

Computes SNR from a pulse response. Returns a **ratio, not dB**.

```matlab
m = serdes.utilities.SNR(pulse, samplesPerSymbol);
fprintf("SNR = %g (%.1f dB)\n", m, 10*log10(m));
```

The algorithm finds the energy under the cursor portion of the pulse and
divides by the energy of the remainder (ISI). Uses `pulseRecoverClock`
internally to find the cursor location.

**Input:** `pulse` — column vector pulse response, `samplesPerSymbol` — integer.

**Output:** `m` — SNR as a linear ratio. Apply `10*log10(m)` for dB.

### WaveEyeHeight

Finds the maximum eye height of a symbol-rate waveform by folding.

```matlab
maxEH = serdes.utilities.WaveEyeHeight(waveIn, samplesPerSymbol);
[maxEH, upperBound, lowerBound] = serdes.utilities.WaveEyeHeight(waveIn, samplesPerSymbol);
```

**Inputs:**
- `waveIn` — time-domain waveform (column vector)
- `samplesPerSymbol` — integer SPS

**Outputs:**
- `maxEH` — maximum eye height (volts). Returns `NaN` if waveform too short
- `upperBound` — upper eye boundary voltage
- `lowerBound` — lower eye boundary voltage

The function folds the waveform at symbol boundaries and measures the
vertical opening at each sample phase. The output is a **vector** (one
value per sample phase within a symbol) — use `max(maxEH)` for the best
phase. For jitter-aware eye height, use `eyeDiagramSI` instead
(see `reference/visualization-and-metrics.md`).

### icn (Integrated Crosstalk Noise)

Computes integrated crosstalk noise per OIF-CEI-04.0 Section 12.2.1.2.
Returns **volts RMS** (consistent with `ChannelData.FEXTICN`/`NEXTICN`).

```matlab
% Basic: frequency vector, crosstalk S-parameter matrix, baud rate
Y = serdes.utilities.icn(f, Sxt, fb);

% Full: with aggressor amplitude (Vpp), rise time (s), start frequency (Hz)
Y = serdes.utilities.icn(f, Sxt, fb, A, Tr, fStart);

% Multi-output: MDXT = multi-disturber crosstalk, W = weighting function
[Y, MDXT, W] = serdes.utilities.icn(f, Sxt, fb);
```

**Inputs:**

| Parameter | Description |
|-----------|-------------|
| `f` | Frequency vector (Hz), same length as `Sxt` |
| `Sxt` | Crosstalk S-parameter column matrix `[Xt1, Xt2, ...]` |
| `fb` | Baud frequency (Hz). For NRZ: `1 / (2 * SymbolTime)` |
| `A` | (Optional) Aggressor Vpp differential amplitude (V) |
| `Tr` | (Optional) Aggressor 20-80% rise time (s) |
| `fStart` | (Optional) Integration start frequency (Hz) |

Multiple crosstalk waveforms are power-summed to yield multi-disturber
crosstalk, then windowed by the weighting function.

## CTLE Pole/Zero Generation

### poleZeroDefine

Generates CTLE poles and zeros from peaking specifications. Three calling
conventions (any two of DCGain, ACGain, PeakingGain plus PeakingFrequency):

```matlab
% Convention 1: DCGain + PeakingGain
[G, P, Z] = serdes.utilities.poleZeroDefine(...
    'PeakingFrequency', 7e9, 'DCGain', -6, 'PeakingGain', 6);

% Convention 2: DCGain + ACGain (PeakingGain = ACGain - DCGain)
[G, P, Z] = serdes.utilities.poleZeroDefine(...
    'PeakingFrequency', 7e9, 'DCGain', -6, 'ACGain', 0);

% Convention 3: ACGain + PeakingGain (DCGain = ACGain - PeakingGain)
[G, P, Z] = serdes.utilities.poleZeroDefine(...
    'PeakingFrequency', 7e9, 'PeakingGain', 6, 'ACGain', 0);
```

**Output forms:**

| Syntax | Output |
|--------|--------|
| `[G, P, Z] = poleZeroDefine(...)` | Separate: gain (dB), poles (Hz), zeros (Hz) |
| `GPZ = poleZeroDefine(...)` | Single output: `[G P1 Z1 P2; ...]` matrix for `serdes.CTLE` |
| `poleZeroDefine(...)` | No output: plots magnitude and phase |

**Vector inputs:** `PeakingFrequency`, `DCGain`, `PeakingGain`, `ACGain` can
be vectors (same length or scalar) to generate multiple CTLE configurations
at once. The single-output `GPZ` matrix then has one row per configuration.

**Usage with CTLE:**
```matlab
GPZ = serdes.utilities.poleZeroDefine(...
    'PeakingFrequency', 7e9, 'DCGain', [-8 -6 -4 -2 0], 'ACGain', 0);
ctle = serdes.CTLE('Specification', "GPZ Matrix", 'GPZ', GPZ);
```

## Signal Manipulation

### resampleImpulse

Resamples an impulse response to a new sample interval.

```matlab
Y = serdes.utilities.resampleImpulse(X, dtIn, dtOut, normalize);
```

- All four arguments are required (including `normalize`)
- Upsampling: spline interpolation
- Downsampling: raised-cosine anti-aliasing filter first, then decimation
- `normalize` — set to `0` to skip normalization, `1` to normalize
- `X` must be a **column matrix** (each column is an impulse response)

**Warning:** Assumes samples before and after `X` are zero. Large deviations
from zero at endpoints can cause inaccuracies at boundaries.

### shiftPulse

Circular-shifts a pulse response so the cursor aligns to the center of a
folded eye diagram.

```matlab
[pulse, cursorNdx, shift1] = serdes.utilities.shiftPulse(pulse, N);
[pulse, cursorNdx, shift1] = serdes.utilities.shiftPulse(pulse, N, ClockIndex);
```

- `N` — samples per symbol
- `ClockIndex` — (optional) directly specify cursor position instead of
  using the hula-hoop algorithm
- `cursorNdx` — recovered clock location in symbol units
- `shift1` — number of samples shifted

### SoftClipper

Creates a cubic soft-clipper voltage transfer curve for `serdes.SaturatingAmplifier`.

```matlab
VinVout = serdes.utilities.SoftClipper(linearGain, limit);
VinVout = serdes.utilities.SoftClipper(linearGain, limit, npts);
VinVout = serdes.utilities.SoftClipper(linearGain, limit, x);
```

- `linearGain` — small-signal gain (V/V)
- `limit` — clipping voltage (V)
- `npts` — number of points (default: 63)
- `x` — custom Vin vector (overrides npts)
- Output: `[Nx2]` matrix `[Vin, Vout]`

**Usage with SaturatingAmplifier:**
```matlab
VinVout = serdes.utilities.SoftClipper(2, 0.8);
amp = serdes.SaturatingAmplifier('Specification', "VinVout", ...
    'VinVout', VinVout);
```

### floatingTaps

Applies floating tap group constraints to DFE tap vectors.

```matlab
taps = serdes.utilities.floatingTaps(optimizedTaps, fixedTaps, groups, groupSize);
```

Searches left-to-right for the position where each floating tap group has
the largest sum. Fixed leading taps (pre-taps + main) are excluded from
the search.

- `optimizedTaps` — vector of tap weights before constraints
- `fixedTaps` — number of leading taps to skip
- `groups` — number of floating tap groups
- `groupSize` — size of each group

## IBIS Rise Time Conversion

### dt2Trf / trf2dt

Convert between IBIS ramp `dV/dt` rise time and LTI 20-80% rise time.

```matlab
Trf = serdes.utilities.dt2Trf(dt, R, C, rLoad);
dt  = serdes.utilities.trf2dt(Trf, R, C, rLoad);
```

- `dt` — IBIS ramp rise time (from `dV/dt_r` record)
- `Trf` — 20-80% LTI rise time
- `R` — driver impedance (ohms)
- `C` — parasitic capacitance (F)
- `rLoad` — load impedance (ohms)

Based on M. Steinberger's IBISRiseTime derivation.

## Formatting and Conversion

### db

Converts linear magnitude to decibels: `20*log10(abs(x))`. Code-generation
compatible.

```matlab
y = serdes.utilities.db(x);
% Equivalent to: y = 20*log10(abs(x))
```

### num2prefix

Converts a numeric value to a string with SI prefix.

```matlab
str = serdes.utilities.num2prefix(100e-12);           % "100 ps"
str = serdes.utilities.num2prefix(14.125e9, "Hz");    % "14.125 GHz"
[str, prefixStr, Y] = serdes.utilities.num2prefix(X, UNIT);
```

**Outputs:**
- `str` — formatted string with value and prefix+unit
- `prefixStr` — prefix and unit string only (e.g., `"ps"`, `"GHz"`)
- `Y` — scale factor used (e.g., `1e12` for pico)

**Prefix range:** yocto (`y`, 10^-24) through Tera (`T`, 10^12).

### SignalIntegrityColorMap

Standard colormap for statistical eye diagrams (not a utility function but
in the `serdes.utilities` namespace):

```matlab
cmap = serdes.utilities.SignalIntegrityColorMap;
colormap(cmap);
```

## Common Mistakes

### 1. SNR Returns Ratio, Not dB

```matlab
% WRONG — treating SNR output as dB
m = serdes.utilities.SNR(pulse, 16);
fprintf("SNR = %.1f dB\n", m);  % Incorrect — m is a linear ratio

% CORRECT — convert to dB manually
fprintf("SNR = %.1f dB\n", 10*log10(m));
```

### 2. icn Returns Volts RMS, Not dB

```matlab
% WRONG — treating icn output as dB
icnVal = serdes.utilities.icn(f, Sxt, fb);
fprintf("ICN = %.1f dB\n", icnVal);  % Incorrect — icnVal is in V RMS

% CORRECT — display in mV RMS (consistent with ChannelData.FEXTICN)
fprintf("ICN = %.2f mV RMS\n", icnVal * 1e3);
```

### 3. resampleImpulse Requires Column Matrix and normalize Argument

```matlab
% WRONG — row vector input and missing normalize argument
impulse = zeros(1, 128);
Y = serdes.utilities.resampleImpulse(impulse, 1e-12, 6.25e-12);  % Error

% CORRECT — column vector with normalize argument
impulse = zeros(128, 1);
Y = serdes.utilities.resampleImpulse(impulse, 1e-12, 6.25e-12, 0);
```

### 4. SER Needs Clock from pulseRecoverClock

```matlab
% WRONG — using arbitrary sample indices as clock
clock = (0:N-1) * dt;  % Not a valid clock waveform

% CORRECT — use pulseRecoverClock or CDR output
clockIdx = pulseRecoverClock(pulse, samplesPerSymbol);
% Or use serdes.CDR to generate clock waveform with rising edges
```

----

Copyright 2026 The MathWorks, Inc.
----
