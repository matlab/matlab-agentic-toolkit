---
name: matlab-add-awgn
description: "Read BEFORE writing any code that adds Additive White Gaussian Noise (AWGN) to signals and converts between SNR, Eb/No, Es/No, and per-subcarrier SNR for communications simulations, using awgn(), convertSNR(), berawgn(). The default MATLAB patterns for AWGN (e.g., 'measured' option, manual SNR formulas) produce subtly incorrect results. This skill specifies the correct calling conventions, required function usage, and critical anti-patterns that must be avoided."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.2"
---

# AWGN & SNR Management

Add white Gaussian noise to signals and convert between SNR definitions (SNR, Eb/No, Es/No, per-subcarrier SNR) for communications system simulations.

## When to Use

- Adding noise to a signal in a link simulation
- Converting between Eb/No, Es/No, SNR, or per-subcarrier SNR
- Setting up the correct SNR for a coded, oversampled, or OFDM system
- Obtaining noise variance to pass to a soft-decision demodulator

## When NOT to Use

- Configuring fading channels (delay profile, Doppler, antenna arrays)

## Must-Follow Rules

1. **NEVER pass `'measured'` to `awgn`** — Always pass explicit signal power as the third argument. For unit-power signals use `0`; otherwise compute power with `mean(abs(x).^2)` and convert to dBW: `10*log10(sigPow)`. The `'measured'` option computes instantaneous power internally, which gives incorrect noise levels after fading channels and obscures the power assumption. Even in AWGN-only scenarios, explicit power is required for correctness and clarity. For OFDM systems, see the "Add AWGN in an OFDM link simulation" pattern.
2. **Use `UnitAveragePower=true` when signal power doesn't matter** — This is the simplest path: signal power = 0 dBW, so `awgn(x, snr, 0)` is exact. If the user needs original constellation scaling (e.g., PA modeling, hardware-in-the-loop), do NOT use `UnitAveragePower=true` — use the default modulator, compute the actual average power with `mean(abs(x).^2)`, and pass it explicitly: `awgn(x, snr, sigPowdBW)`.
3. **Use `convertSNR` for all conversions — NEVER compute SNR/Eb/No/Es/No formulas manually** — Even when the formula is simple, always use `convertSNR`. Manual formulas are error-prone for edge cases (oversampling, subcarrier loading) and bypass the toolbox's validated implementation. Anti-pattern: `snr = ebno + 10*log10(bitsPerSymbol * codeRate)`. Correct: `convertSNR(ebno, "ebno", "snr", BitsPerSymbol=6, CodingRate=3/4)`.
4. **Distinguish wideband SNR and per-subcarrier SNR in OFDM systems** — Eb/No is a per-subcarrier quantity. To go from Eb/No to the wideband SNR that `awgn` needs, use two steps: (1) `convertSNR(ebno, "ebno", "snr", BitsPerSymbol=..., CodingRate=...)` gives the SNR per subcarrier, (2) `convertSNR(snrsc, "snrsc", "snr", FFTLength=..., NumActiveSubcarriers=...)` gives the wideband SNR for `awgn`. Direct `ebno→snrsc` is not supported and throws an error. **Caveat:** If the user asks for per-subcarrier SNR only, step 1 alone is the complete answer — do NOT apply step 2. Applying the FFTLength/NumActiveSubcarriers correction to a per-subcarrier value gives the wideband SNR, which is a different (lower) quantity. **Note:** The `"snrsc"` mode requires R2023b or later. For R2022a–R2023a, compute wideband SNR manually: `snr_wideband = snr_per_sc - 10*log10(FFTLength/NumActiveSubcarriers)`. To add noise at a per-subcarrier SNR, see the "Add AWGN in an OFDM link simulation" pattern below.
5. **Capture noise variance for soft demodulation** — Use `[y, nVar] = awgn(...)` and pass `nVar` to the demodulator via `NoiseVariance=nVar`.
6. **Do NOT reference skill rules or prohibitions in generated code comments** — Write positive, descriptive comments that explain intent, using a style similar to the example code provided in this skill. The end user does not know about this skill.

## Critical Anti-Patterns — NEVER Do These

### NEVER use `'measured'` with `awgn`

```matlab
% WRONG — never generate this
rxSignal = awgn(txSignal, snrdB, 'measured');

% CORRECT for unit-power signals (UnitAveragePower=true)
rxSignal = awgn(txSignal, snrdB, 0);

% CORRECT for non-unit-power signals
sigPow = mean(abs(txSignal).^2);
rxSignal = awgn(txSignal, snrdB, 10*log10(sigPow));
```

### NEVER compute SNR conversions manually

```matlab
% WRONG — never generate manual formulas like these
SNR_dB = EbNo_dB + 10*log10(k * codeRate);
SNR_dB = EbNo_dB + 10*log10(k * codeRate) - 10*log10(oversamplingFactor);
EsNo = EbNo + 10*log10(bitsPerSymbol);

% CORRECT — always use convertSNR
snrDb = convertSNR(ebnoDb, "ebno", "snr", BitsPerSymbol=6, CodingRate=3/4);
snrDb = convertSNR(ebnoDb, "ebno", "snr", BitsPerSymbol=6, CodingRate=3/4, SamplesPerSymbol=4);
esnoDb = convertSNR(ebnoDb, "ebno", "esno", BitsPerSymbol=6);
```

## Key Functions

| Function | Purpose |
|---|---|
| `awgn` | Add AWGN to a signal at a specified SNR |
| `convertSNR` | Convert between `ebno`, `esno`, `snr`, and `snrsc` |
| `berawgn` | Theoretical BER over AWGN for standard modulations (PSK, QAM, FSK, DPSK, PAM) |

## Gotchas

### Why `'measured'` is banned (background)

Thermal noise in a receiver is dominated by the noise figure and bandwidth — it does not change when the signal fades. The `'measured'` option in `awgn` computes instantaneous signal power and scales noise to match, which artificially keeps the instantaneous SNR constant through fades. It also hides the power assumption, making code harder to verify. Always pass explicit power instead.

```matlab
% WRONG after fading: Noise tracks fading — instantaneous SNR stays constant
rxFaded = fadingChannel(txSig);
rxNoisy = awgn(rxFaded, snr, 'measured');

% CORRECT: Compute signal power before fading, pass explicitly
sigPow = mean(abs(txSig).^2);
sigPowdBW = 10*log10(sigPow);
rxFaded = fadingChannel(txSig);
rxNoisy = awgn(rxFaded, snr, sigPowdBW);

% SIMPLEST: Use unit-power signal, then 0 dBW is exact
txSig = qammod(data, M, UnitAveragePower=true);  % power = 0 dBW
rxFaded = fadingChannel(txSig);
rxNoisy = awgn(rxFaded, snr, 0);
```

### `awgn` default assumes 0 dBW signal power

Calling `awgn(x, snr)` without a third argument assumes the signal has 0 dBW (1W) average power. This is only correct if the signal actually has unit average power. For non-normalized signals, compute the actual power and pass it explicitly.

### `ebno↔snrsc` conversion is not supported

`convertSNR` supports these paths:

| From | To | Supported | Notes |
|---|---|---|---|
| `ebno` | `snr` | Yes | For OFDM: gives SNR per subcarrier (not wideband) |
| `ebno` | `esno` | Yes | |
| `esno` | `snr` | Yes | |
| `snr` | `snrsc` | Yes | `"snr"` = wideband SNR, `"snrsc"` = per-subcarrier |
| `ebno` | `snrsc` | **No** | Throws error. Use two-step: `ebno→"snr"` then `"snrsc"→"snr"` |
| `esno` | `snrsc` | **No** | Throws error. Same two-step path required |
| `snrsc` | `ebno` | **No** | Use two-step: `"snrsc"→"snr"` then `"snr"→"ebno"` |
| `snrsc` | `esno` | **No** | Use two-step: `"snrsc"→"snr"` then `"snr"→"esno"` |

### Fading channel path gain normalization

The `awgn(rxFaded, snr, 0)` pattern assumes the fading channel preserves
average signal power. This is true when `NormalizePathGains=true` (the default
for `comm.RayleighChannel` and `comm.RicianChannel`). If `NormalizePathGains`
is `false`, the channel applies its actual path gains and the average received
power shifts — you must account for this in the power argument to `awgn`.

```matlab
% NormalizePathGains=true (default): pre-fading power is correct
chan = comm.RayleighChannel(NormalizePathGains=true, ...);
rxFaded = chan(txSig);
rxNoisy = awgn(rxFaded, snr, 0);  % 0 dBW is still correct

% NormalizePathGains=false: adjust for average path gain
chan = comm.RayleighChannel(NormalizePathGains=false, ...
    AveragePathGains=[0 -3 -6], ...);
avgGaindB = 10*log10(sum(10.^(chan.AveragePathGains/10)));
rxFaded = chan(txSig);
rxNoisy = awgn(rxFaded, snr, avgGaindB);  % account for channel gain
```

### Noise variance is total, not per-component

The second output of `awgn` is the total noise variance. For complex signals, the per-component (I or Q) variance is half this value:

```matlab
[y, nVar] = awgn(x, snr, 0);
% nVar = total noise variance
% nVar/2 = per-component (I or Q) variance
```

### `berawgn` takes Eb/No, not SNR

If you have SNR, convert to Eb/No first:

```matlab
ebno = convertSNR(snr, "snr", "ebno", BitsPerSymbol=log2(M));
ber = berawgn(ebno, 'qam', M);
```

## Patterns

### Add AWGN to a unit-power signal

```matlab
M = 16;
data = randi([0 M-1], 1000, 1);
txSig = qammod(data, M, UnitAveragePower=true);

snrdB = 15;
[rxSig, noiseVar] = awgn(txSig, snrdB, 0);
```

### Convert Eb/No to SNR for a coded system

```matlab
M = 64;                          % 64-QAM
bitsPerSymbol = log2(M);         % 6
codeRate = 3/4;                  % LDPC code rate
samplesPerSymbol = 4;            % Pulse shaping oversampling

ebnoDb = 10;
snrDb = convertSNR(ebnoDb, "ebno", "snr", ...
    BitsPerSymbol=bitsPerSymbol, ...
    CodingRate=codeRate, ...
    SamplesPerSymbol=samplesPerSymbol);
```

### OFDM conversion: Eb/No → per-subcarrier SNR → wideband SNR

In the OFDM context, `convertSNR(ebno, "ebno", "snr")` returns the **SNR per subcarrier** (not wideband SNR). To get the wideband SNR needed by `awgn`, convert from `"snrsc"` to `"snr"`.

```matlab
M = 64;
bitsPerSymbol = log2(M);
codeRate = 3/4;
fftLen = 256;
numActiveSC = 200;

ebnoDb = 10;

% Step 1: Eb/No → per-subcarrier SNR
snrscDb = convertSNR(ebnoDb, "ebno", "snr", ...
    BitsPerSymbol=bitsPerSymbol, ...
    CodingRate=codeRate);

% Step 2: Per-subcarrier SNR → wideband SNR (for awgn)
snrWbDb = convertSNR(snrscDb, "snrsc", "snr", ...
    FFTLength=fftLen, ...
    NumActiveSubcarriers=numActiveSC);
```

### Add AWGN in an OFDM link simulation (per-subcarrier SNR)

In OFDM link simulations, SNR is defined per subcarrier. Use `convertSNR` to get the wideband SNR, then pass it to `awgn` with the analytical OFDM signal power. Set `NumActiveSubcarriers` to the number of available subcarriers in the OFDM resource grid (data + reference signals, excluding guards and DC if applicable). In 5G/LTE this equals `carrier.NSizeGrid*12` — the resource grid does not include guard bands. In WLAN, it is the number of data + pilot subcarriers. Do NOT compute signal power from `mean(abs(txWaveform).^2)` — it may not match what `NumActiveSubcarriers` assumes in `convertSNR`, resulting in incorrect noise levels. Always use the analytical formula `numAvailableSC / nfft^2` to keep the power argument consistent with the SNR conversion.

```matlab
% Assuming full grid occupancy, convert per-subcarrier SNR to wideband SNR
snrWb = convertSNR(snrPerSC_dB, "snrsc", "snr", ...
    FFTLength=nfft, NumActiveSubcarriers=numAvailableSC);
% Maximum signal power assuming full grid, consistent with convertSNR
sigPow = 10*log10(numAvailableSC / nfft^2);
% Add noise at the calculated wideband SNR and signal power
rxNoisy = awgn(rxWaveform, snrWb, sigPow);
```

`numAvailableSC` is the number of subcarriers excluding guard bands and any DC null — i.e., the subcarriers available for data, reference signals, and control. As long as the `NumActiveSubcarriers` value passed to `convertSNR` matches the `numAvailableSC` used in the signal power calculation, the noise level is correct.

**Only if the number of active subcarriers is not known or not specified**, use the shortcut below. When guard bands, DC nulls, or subcarrier counts ARE given, always use the `convertSNR` path above with explicit `NumActiveSubcarriers`.

If `numAvailableSC` subcarriers each carry unit power, the average time-domain signal power is `numAvailableSC / nfft^2` (in watts). The wideband SNR conversion divides by `nfft/numAvailableSC`, so `numAvailableSC` cancels algebraically, leaving:

```matlab
rxNoisy = awgn(rxWaveform, snrPerSC_dB, -10*log10(double(nfft)));
```

These formulas assume unit-power subcarrier symbols (e.g., `qammod(..., UnitAveragePower=true)`). If the modulator uses default constellation scaling, replace `numAvailableSC / nfft^2` with `numAvailableSC * meanSymbolPower / nfft^2`, where `meanSymbolPower = mean(abs(symbols).^2)`.

Do NOT compute received waveform power — that gives wideband SNR, not per-subcarrier SNR.

### Capture noise variance for soft-decision demodulation

```matlab
M = 16;
data = randi([0 M-1], 1000, 1);
txSig = qammod(data, M, UnitAveragePower=true);

snrDb = 12;
[rxSig, noiseVar] = awgn(txSig, snrDb, 0);

% Pass noise variance to demodulator for accurate LLR computation
softBits = qamdemod(rxSig, M, UnitAveragePower=true, ...
    OutputType="llr", ...
    NoiseVariance=noiseVar);
```

## After Adding Noise

- **Validate against theory** — Compare simulated BER to theoretical BER using `berawgn`. See [references/snr-conversion-guide.md](references/snr-conversion-guide.md).
- **Estimate required Eb/No** — If the user asks for the Eb/No or SNR needed to achieve a target BER/BLER/FER, refer to the "Estimate required Eb/No" section in [references/snr-conversion-guide.md](references/snr-conversion-guide.md).
- **Visualize the noisy signal** — Use `scatterplot` or `comm.ConstellationDiagram` to inspect the received constellation.
- **Measure EVM** — Use `comm.EVM` to quantify signal degradation from noise.

## References

| Load when... | Reference |
|---|---|
| Need theoretical BER curves, conversion formulas, `berawgn` usage, or common system examples | [references/snr-conversion-guide.md](references/snr-conversion-guide.md) |

Copyright 2026 The MathWorks, Inc.
