# Equalization Tuning

## CTLE Configuration via poleZeroDefine

`serdes.utilities.poleZeroDefine` generates a GPZ (Gain-Pole-Zero) matrix from
DC Gain + AC Gain specifications, suitable for `serdes.CTLE` in `"GPZ Matrix"` mode.

```matlab
% Generate GPZ matrix from gain specifications
nyquistFreq = baudRate / 2;

gpzMatrix = serdes.utilities.poleZeroDefine( ...
    "PeakingFrequency", nyquistFreq, ...
    "DCGain", [0 -1 -2 -3 -4 -5 -6], ...
    "ACGain", 0);
% Returns Nx4 matrix: [Gain(dB) Pole1(Hz) Zero1(Hz) Pole2(Hz)]

ctle = serdes.CTLE("Specification", "GPZ Matrix", ...
    "GPZ", gpzMatrix, ...
    "Mode", 1, ...                       % REQUIRED for ConfigSelect to work
    "ConfigSelect", 3);                  % Select row 3 (0-indexed)
```

For fitting measured CTLE frequency response data (e.g., from CSV), use `ctlefit`
instead — see `reference/serdes-api-reference.md` for the `ctlefit` class API.

### CTLE Specification Modes

| Mode | Properties Set | When to Use |
|------|---------------|-------------|
| `"DC Gain and Peaking Gain"` | `DCGain`, `PeakingGain` | Quick exploration |
| `"DC Gain and AC Gain"` | `DCGain`, `ACGain` | Datasheet specs |
| `"AC Gain and Peaking Gain"` | `ACGain`, `PeakingGain` | Relative gain control |
| `"GPZ Matrix"` | `GPZ`, `Mode`, `ConfigSelect` | Multi-config sweeps, compliance |

**Key rule:** Set `Specification` BEFORE setting gain properties. Post-hoc changes to
`Specification` may silently ignore previously set values.

### ConfigSelect Requires Mode=1

`ConfigSelect` only works when `Mode = 1` (fixed configuration). With the default
`Mode = 0` (bypass/auto), row 0 is always used regardless of `ConfigSelect` value.
This is a silent failure — no error, no warning.

## FFE Optimization: MMSE vs ZF Tradeoff

Two conceptual strategies for FFE tap weight selection:

| Strategy | Objective | Pros | Cons |
|----------|-----------|------|------|
| **Zero-Forcing (ZF)** | Minimize ISI at sample points | Maximum ISI cancellation, best for high-SNR | Amplifies noise at low SNR, can over-equalize |
| **MMSE** | Minimize mean-squared error (ISI + noise) | Better noise performance, robust at low SNR | Slightly higher residual ISI |

**When to use which:**
- **ZF approach**: Low-loss channels (< 15 dB), NRZ, high SNR — maximize pre/post tap magnitude
- **MMSE approach**: High-loss channels (> 20 dB), PAM4, noisy links — keep main cursor higher
- At mid-loss (15-20 dB), MMSE-like taps typically yield 0.5-1.0 dB better COM than ZF

SerDes Toolbox `serdes.FFE` does not have a built-in ZF/MMSE mode selector. Instead,
implement the tradeoff through tap weight selection:

```matlab
% ZF-like taps: aggressive pre/post for maximum ISI cancellation
ffeZF = serdes.FFE("TapWeights", [-0.15 0.55 -0.30]);

% MMSE-like taps: conservative pre/post, preserves signal amplitude
ffeMMSE = serdes.FFE("TapWeights", [-0.08 0.77 -0.15]);
```

**Best practice:** Use GA optimization (see `reference/optimization.md`) to find
optimal taps for the specific channel and noise environment. GA naturally finds the
MMSE-optimal point by maximizing COM (which includes both ISI and noise effects).
This is preferred over manually choosing ZF vs MMSE tap weights.

## Multi-Lane Simulation

SerDes Toolbox simulates **one lane at a time**. For multi-lane links (e.g., PCIe x16,
100GBASE-CR4), loop over lanes individually:

```matlab
% Multi-lane simulation — one lane at a time
sParamFiles = {"lane1.s4p", "lane2.s4p", "lane3.s4p", "lane4.s4p"};
comResults = zeros(numel(sParamFiles), 1);

for lane = 1:numel(sParamFiles)
    spCh = SParameterChannel("FileName", sParamFiles{lane}, ...
        "SampleInterval", symbolTime / 16);
    channel = ChannelData("Impulse", spCh.ImpulseResponse, "dt", spCh.SampleInterval);
    sys = SerdesSystem('ChannelData', channel, ...
        'TxModel', Transmitter('Blocks', {ffe}), ...
        'RxModel', Receiver('Blocks', {ctle, dfecdr}), ...
        'SymbolTime', symbolTime, 'SamplesPerSymbol', 16, ...
        'Modulation', modulation);
    analysis(sys);
    comResults(lane) = sys.Metrics.summary.COMestimate;
end
fprintf("Worst-lane COM: %.2f dB\n", min(comResults));
```

Crosstalk between lanes is modeled via multi-port S-parameters on a per-victim basis,
not as a simultaneous multi-lane simulation. See `reference/channel-modeling.md`.

## FFE Tap Count and Weight Selection

### Tap Naming Convention

| Tap | Index | Role |
|-----|-------|------|
| Pre-cursor | 1 | Compensates pre-cursor ISI (negative weight) |
| Main cursor | 2 | Signal amplitude (positive, largest weight) |
| Post-cursor(s) | 3+ | Compensates post-cursor ISI (negative weights) |

A 3-tap FFE has [pre, main, post]. A 5-tap FFE has [pre2, pre1, main, post1, post2].

### Normalization Constraint

FFE taps must satisfy `sum(abs(taps)) = 1.0` (energy conservation). For a 3-tap FFE,
the main cursor is derived: `main = 1 - |pre| - |post|`.

### Practical Guidelines

- **3 taps** (1 pre + 1 post): Sufficient for most channels up to 25 dB loss
- **5 taps** (2 pre + 2 post): Needed for channels > 25 dB or with significant reflections
- **7+ taps**: Rarely needed; adds complexity without proportional benefit
- **Quantization**: Real hardware quantizes taps (e.g., 0.02 resolution). Include in optimization.
- **Main cursor floor**: Keep `main >= 0.4` to avoid excessive signal attenuation

### Tap Weight Starting Points by Loss

| Channel Loss | Pre | Main | Post | Notes |
|-------------|-----|------|------|-------|
| 5-10 dB | -0.05 | 0.90 | -0.05 | Minimal equalization needed |
| 10-20 dB | -0.10 | 0.70 | -0.20 | Moderate ISI compensation |
| 20-30 dB | -0.15 | 0.55 | -0.30 | Aggressive post-cursor emphasis |
| 30+ dB | -0.18 | 0.44 | -0.38 | Near main-cursor floor |

## DFE Tap Count Selection

DFE taps cancel post-cursor ISI that FFE cannot reach. More taps = longer ISI
cancellation, but diminishing returns after the channel impulse decays.

- **5 taps**: Standard for most links up to 25 dB
- **10-15 taps**: High-loss channels (25-30 dB) with long impulse tails
- **30-40 taps**: Extreme cases (PAM8, very high loss) — last resort
- **Adaptive mode** (`Mode = 2` on `serdes.DFECDR`): Let the DFE find its own taps

**Key finding:** For PAM8 and higher modulation orders, DFE with many taps and NO CTLE
(AC Gain = 0 dB) outperforms conventional CTLE + DFE. CTLE amplifies inter-level noise
that is critical for PAM8's tight eye levels.

## Tx/Rx Analog Parameter Guidance

Include `AnalogModel` on both Tx and Rx for realistic COM — omitting it inflates COM
by 1-2 dB. Analog parameters span three classes:

### Default Values and Sensitivities

| Parameter | Set On | Default | Sensitivity | Notes |
|-----------|--------|---------|-------------|-------|
| `RiseTime` | `Transmitter` | 9.6 ps | High | Optimal: 0.3-0.4 x SymbolTime. Too fast or too slow hurts. |
| `C` (Tx) | `AnalogModel` | 100 fF | High at > 500 fF | 1 pF → -2.5 dB COM, 2 pF → -7 dB |
| `C` (Rx) | `AnalogModel` | 200 fF | High at > 500 fF | 1 pF → -2.3 dB COM, 2 pF → -5.5 dB |
| `R` (Tx) | `AnalogModel` | 50 ohm | Low | +-0.5 dB over 25-100 ohm range |
| `R` (Rx) | `AnalogModel` | 50 ohm | Low | +-0.5 dB over 25-100 ohm range |
| `VoltageSwingIdeal` | `Transmitter` | 1.0 V | None (COM) | Scales EH linearly, COM is a ratio |

`AnalogModel` accepts only `R` (single-ended termination resistance) and `C` (single-ended
parasitic capacitance). `RiseTime` and `VoltageSwingIdeal` are `Transmitter` properties.

### Setting Analog Parameters in SerdesSystem

```matlab
sys = SerdesSystem("ChannelData", channel, ...
    'TxModel', Transmitter('Blocks', {ffe}, ...
        'AnalogModel', AnalogModel("R", 50, "C", 150e-15), ...
        'RiseTime', 12e-12, 'VoltageSwingIdeal', 1.0), ...
    'RxModel', Receiver('Blocks', {ctle, dfecdr}, ...
        'AnalogModel', AnalogModel("R", 50, "C", 200e-15)));
```

### Design Insight: CTLE Counterproductive for High-Order PAM

At PAM8 and above, CTLE high-frequency boost amplifies inter-level noise more than it
improves the eye. The optimal strategy is often AC Gain = 0 dB with many DFE taps.

56 Gbps PAM8 at 15 dB loss:
- CTLE AC=12 dB + 5-tap DFE: COM = 0.8 dB (closed eye)
- CTLE AC=0 dB + 40-tap DFE: COM = 4.9 dB (open eye)

This is the opposite of conventional NRZ/PAM4 wisdom where CTLE is essential.

## Industry Reference Designs

Starting-point configurations for common standards. Adjust based on channel
characteristics and margin requirements.

### 56 Gbps PAM4 (28 GBaud)

```matlab
symbolTime = 1 / 28e9;
ffe = serdes.FFE("TapWeights", [-0.1 0.7 -0.2]);
ctle = serdes.CTLE("Specification", "DC Gain and AC Gain", ...
    "DCGain", 0, "ACGain", 12, "PeakingFrequency", 14e9);
dfecdr = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 5), ...
    "SymbolTime", symbolTime, "Modulation", 4);
```

### 112 Gbps PAM4 (56 GBaud)

```matlab
symbolTime = 1 / 56e9;
ffe = serdes.FFE("TapWeights", [-0.15 0.55 -0.30]);
ctle = serdes.CTLE("Specification", "DC Gain and AC Gain", ...
    "DCGain", 0, "ACGain", 15, "PeakingFrequency", 28e9);
dfecdr = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 10), ...
    "SymbolTime", symbolTime, "Modulation", 4);
```

### 28 Gbps NRZ (28 GBaud)

```matlab
symbolTime = 1 / 28e9;
ffe = serdes.FFE("TapWeights", [-0.05 0.85 -0.10]);
ctle = serdes.CTLE("Specification", "DC Gain and AC Gain", ...
    "DCGain", 0, "ACGain", 8, "PeakingFrequency", 14e9);
dfecdr = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 5), ...
    "SymbolTime", symbolTime, "Modulation", 2);
```

## Fitting CTLE from Measured Data (ctlefit)

When you have measured CTLE frequency response data (e.g., from lab equipment or
vendor datasheets as CSV), use `ctlefit` to generate a GPZ matrix:

```matlab
% Import measured CTLE data from CSV
% CSV format: freq,real,imag,real,imag,... (one column pair per config)
[f, H] = ctlefit.readcsv("ctle_measured.csv");

% Fit pole-zero model — returns object with GPZ property
obj = ctlefit("f", f, "H", H, "SampleInterval", dt, "MaxNumberOfPoles", 2);
truncateAbove(obj, 2 * nyquistFreq);  % cut fitting noise above 2x Nyquist

% Extract GPZ matrix for SerDes CTLE
gpzMatrix = obj.GPZ;

% Use in SerdesSystem
ctle = serdes.CTLE("Specification", "GPZ Matrix", ...
    "GPZ", gpzMatrix, "Mode", 1, "ConfigSelect", 0);
```

`ctlefit` produces a GPZ matrix in the same `[Gain(dB) Pole1(Hz) Zero1(Hz) Pole2(Hz)]`
format as `serdes.utilities.poleZeroDefine`. Use `ctlefit` when fitting real measurements;
use `poleZeroDefine` when synthesizing from DC/AC gain specs. See
`reference/serdes-api-reference.md` for `ctlefit` properties and preprocessing methods.

## Extracting Combined Equalization Transfer Function

To visualize the combined equalization transfer function programmatically:

```matlab
% Get the combined equalization transfer function from a configured system
results = analysis(sys);
eqImpulse = results.impulse(:, 2);     % equalized impulse
unEqImpulse = results.impulse(:, 1);   % unequalized impulse

% Compute transfer function as ratio of FFTs
nfft = 2^nextpow2(numel(eqImpulse));
freq = (0:nfft/2-1) / (nfft * sys.dt);
H_eq = fft(eqImpulse, nfft);
H_uneq = fft(unEqImpulse, nfft);
H_combined = H_eq(1:nfft/2) ./ H_uneq(1:nfft/2);

figure;
plot(freq / 1e9, 20*log10(abs(H_combined)));
xlabel("Frequency (GHz)"); ylabel("Gain (dB)");
title("Effective Equalization Transfer Function");
xlim([0 freq(end)/2e9]);
```

Note: This shows the combined equalization response (FFE + CTLE + DFE), not the
CTLE alone. To isolate the CTLE, run two systems — one with CTLE enabled and one
with CTLE bypassed (Mode=0) — and compare their impulse responses.

----

Copyright 2026 The MathWorks, Inc.
----
