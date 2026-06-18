---
name: matlab-design-ofdm-system
description: "Read BEFORE writing any code that builds or simulates OFDM systems. The default MATLAB patterns for OFDM (e.g., direct ifft/fft, awgn with 0 dBW power, missing symOffset) produce subtly incorrect results — always use ofdmmod/ofdmdemod instead of direct IFFT/FFT. This skill specifies the correct calling conventions for ofdmmod, ofdmdemod, ofdmChannelResponse, ofdmEqualize, and critical anti-patterns that must be avoided. Use when building OFDM transmitters or receivers, allocating subcarriers and guard bands, inserting pilots, computing SNR for OFDM, configuring fading channels (Rayleigh/Rician), estimating and equalizing channels, implementing timing and frequency synchronization, adding LDPC coding, designing resource grids, or setting up OFDM link simulations."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# OFDM System Design

## When To Use

Use this skill when the user wants to build a custom (non-standard) OFDM transmitter/receiver, configure subcarrier allocation, add noise to OFDM signals, equalize OFDM through fading channels, implement synchronization, or add LDPC coding.

## When Not To Use

Do NOT use this skill for standards-specific OFDM (use 5G Toolbox for 5G NR, WLAN Toolbox for Wi-Fi, LTE Toolbox for 4G/LTE, Bluetooth Toolbox for Bluetooth, Satellite Communications Toolbox for satellite links).

## GATE — Ask Before Coding

If the user's request does not specify or unambiguously imply ALL of the following, STOP and ask before generating any code. Present unclear items as a numbered list and ask whether the user wants to: (a) specify values, (b) have you derive them from other constraints (e.g., CP from delay spread, SCS from Doppler), or (c) use typical defaults. Do not assume defaults. Do not proceed until the user responds.

1. **OFDM parameters** — FFT size, CP length, subcarrier spacing, subcarrier allocation
2. **Channel model** — AWGN only, fading with perfect CSI, or fading with pilot-based estimation
3. **Pilots** — needed for channel estimation or phase tracking?
4. **Coding** — uncoded, or coded with a specific rate?
5. **Synchronization** — perfect sync, or include timing/CFO estimation?

## Must-Follow Rules

1. **ALWAYS use `ofdmmod`/`ofdmdemod` — NEVER implement OFDM by directly calling `ifft`/`fft`** — The functions handle CP insertion/removal, `ifftshift`/`fftshift` for centered-frequency ordering, and pilot/null subcarrier management. Direct IFFT/FFT gets subcarrier mapping wrong (silent error). Input is `[nDataSC × nSym]` for SISO. Output is a time-domain column vector. **Note:** sync preambles (e.g., Schmidl-Cox) that require DFT-order subcarrier mapping may use `ifft` directly, since `ofdmmod` applies `ifftshift` which changes the even/odd bin assignment. **Windowing:** `ofdmmod` does not support windowing. For raised cosine windowing, use `comm.OFDMModulator` for the transmitter only (always use `ofdmdemod` function for demodulation). See `references/ofdm-system-guide.md` for capability comparison.

2. **Always use a `symOffset` variable in `ofdmdemod`** — when passing `nullidx` (5th arg), `symOffset` must be explicitly provided as the 4th arg. The default `symOffset` value is `cpLen` (skip entire CP). Note: `cpLen/2` is more robust when timing synchronization is imperfect.

3. **Use explicit signal power in `awgn`, NEVER `'measured'` or `0`** — `ofdmmod` output power is NOT 1W. It equals `nActiveSC / nFFT^2` due to MATLAB's 1/N IFFT normalization. Using `awgn(x, snr, 0)` adds far too much noise. Compute `sigPow = 10*log10(nActiveSC / nFFT^2)` once before any loop — it is a constant determined by OFDM parameters.

4. **Use `ofdmChannelResponse` for frequency-domain channel response** — do NOT compute `H = fft(h, nFFT)` directly. `ofdmmod` uses `ifftshift` internally, so direct FFT-based channel responses have wrong subcarrier mapping. Pass the result to `ofdmEqualize` for equalization.

5. **When deriving OFDM parameters from physical specs, show the computation with comments** — do not just state the values. Show how you calculate subcarrier spacing, FFT size, CP length, sample rate, guard subcarriers, etc. from bandwidth, delay spread, and Doppler spread. Add comments explaining each derivation step.

6. **Check MATLAB version before using version-gated APIs** — Functions like `ofdmChannelEstimate`, `ofdmPilotConfig` (R2026a), and `ldpcPCM` (R2025a) are not available on older releases. Unless the user specifically asks for code compatible with a previous version, call `version('-release')` to get the current MATLAB release, then choose the appropriate API path.

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `ofdmmod` | OFDM modulation (IFFT + CP insertion) | R2018a |
| `ofdmdemod` | OFDM demodulation (CP removal + FFT) | R2018a |
| `ofdmChannelResponse` | Per-subcarrier channel response from path gains | R2023a |
| `ofdmEqualize` | ZF/MMSE frequency-domain equalization | R2022b |
| `ofdmPilotConfig` | Pilot location and symbol configuration | R2026a |
| `ofdmChannelEstimate` | Pilot-based channel estimation (LS + denoising) | R2026a |
| `convertSNR` | SNR conversion (snrsc, snr, ebno) | R2022a |
| `awgn` | Add white Gaussian noise with explicit signal power | — |

## Subcarrier Allocation

Subcarrier indices use **centered-frequency ordering**: index 1 = most negative frequency, index `nFFT/2 + 1` = DC, index nFFT = most positive frequency.

Rules for subcarrier indices:
- `nullIdx` and `pilotIdx` must be **vectors** of 1-based integers in `[1, nFFT]`
- They must not overlap
- DC subcarrier = `nFFT/2 + 1` (always null it)
- `ofdmmod` input X has size `[nDataSC x nSym]` — null and pilot subcarriers are excluded
- `ofdmdemod` output has size `[nDataSC x nSym]` — nulls stripped, pilots returned separately

Example (WiFi-like 64-FFT):
```matlab
nullIdx = [1:6, 33, 60:64].';  % 12 nulls (6 lower guard + DC + 5 upper guard)
pilotIdx = [12; 26; 40; 54];   % 4 pilots
nActiveSC = nFFT - length(nullIdx);                    % 52 (data + pilots)
nDataSC   = nFFT - length(nullIdx) - length(pilotIdx); % 48
```

## Basic OFDM Tx/Rx (AWGN)

```matlab
% Parameters
nFFT = 64;  cpLen = 16;
nullIdx = [1:6, 33, 60:64].';  % 12 nulls
nActiveSC = nFFT - length(nullIdx);  % 52
nDataSC = nActiveSC;  % no pilots
M = 4;  % QPSK
nSym = 100;
snr_sc = 10;  % dB, per-subcarrier SNR

% Transmit
data = randi([0 M-1], nDataSC, nSym);
modData = pskmod(data, M, InputType="integer");
txSig = ofdmmod(modData, nFFT, cpLen, nullIdx);

% SNR conversion and noise
sigPow = 10*log10(nActiveSC / nFFT^2);  % OFDM signal power (dBW)
snr_wb = convertSNR(snr_sc, "snrsc", "snr", ...
    FFTLength=nFFT, NumActiveSubcarriers=nActiveSC);
rxSig = awgn(txSig, snr_wb, sigPow);

% Receive
symOffset = cpLen;
rxData = ofdmdemod(rxSig, nFFT, cpLen, symOffset, nullIdx);
demodData = pskdemod(rxData, M, OutputType="integer");
[numErr, ber] = biterr(data(:), demodData(:));
```

## SNR Handling for OFDM

**SNR per subcarrier (SNR_sc) is the standard noise reference for OFDM simulations.** If you need other noise metrics — Eb/No for theoretical BER comparison, or wideband SNR for `awgn` — use `convertSNR` to derive them from SNR_sc. See `matlab-add-awgn` for full `convertSNR` patterns and `awgn` usage.

**For theoretical BER:** convert SNR_sc to Eb/No via `convertSNR(snr_sc, "snr", "ebno", BitsPerSymbol=log2(M))`, then call `berawgn(ebno, 'qam', M)`. Do NOT pass SNR_sc directly to `berawgn` or use it as Eb/No in `erfc`/`qfunc` closed-form expressions — SNR_sc ≠ Eb/No.

OFDM-specific points (beyond what the AWGN skill covers):
- **Signal power** = `10*log10(nActiveSC / nFFT^2)` dBW — due to MATLAB's 1/N IFFT normalization
- **`nActiveSC`** includes data AND pilot subcarriers
- **Always capture noise variance from `awgn`'s second output:** `[rxSig, nVar] = awgn(...)`. Do NOT compute noise variance manually from SNR formula — use the value `awgn` returns to stay in sync with its internal rounding.
- **Noise variance after `ofdmdemod`** scales by nFFT: `nVar_sc = nVar * nFFT` (FFT sums N terms)
- **`convertSNR` "snr" type** = per-subcarrier SNR when converting from Eb/No or Es/No (each OFDM subcarrier carries one symbol). To convert per-subcarrier SNR to wideband SNR (for `awgn`), use `convertSNR(snr_sc, "snrsc", "snr", FFTLength=nFFT, NumActiveSubcarriers=nActiveSC)`.

## Critical Gotchas

### `awgn(x, snr, 0)` is WRONG for OFDM

OFDM signal power depends on nActiveSC and nFFT, not 1W.

```matlab
% WRONG — assumes unit power (adds ~19 dB too much noise for 64-FFT)
rxSig = awgn(txSig, snr_wb, 0);

% CORRECT — explicit power, capture noise variance
sigPow = 10*log10(nActiveSC / nFFT^2);
[rxSig, nVar] = awgn(txSig, snr_wb, sigPow);
```

### `symOffset` is required in `ofdmdemod`

```matlab
symOffset = cpLen;  % skip entire CP (or cpLen/2 for imperfect timing)
rxData = ofdmdemod(rxSig, nFFT, cpLen, symOffset, nullIdx);
```

### Modulator/demodulator input must be a column vector for single-stream

All Communications Toolbox modulators (`qammod`, `pskmod`, etc.) process **by columns** — each column is an independent channel/stream. For single-stream OFDM, always pass bits or integers as a column vector:

```matlab
% WRONG — [nSym x k] matrix: each column is treated as a separate stream
txData = reshape(txBits, nBitsPerSym, []).';
txSymbols = qammod(txData, M, InputType="bit", UnitAveragePower=true);

% CORRECT — column vector in, then reshape output to OFDM grid
txSymbols = qammod(txBits, M, InputType="bit", UnitAveragePower=true);
txSymbols = reshape(txSymbols, nActiveSC, nSym);
```

Use multiple columns only when modulating independent MIMO streams or parallel codewords simultaneously.

### DC subcarrier index

DC = `nFFT/2 + 1`. For nFFT=64, DC is index 33. Always include it in `nullIdx`.

### `ofdmEqualize` hEst dimensions

With default `DataFormat="3-D"`, `hEst` dimensions are:

- `[nSC × NS × NR]` — **static**: same estimate applied to all OFDM symbols
- `[(nSC*nSym) × NS × NR]` — **time-varying**: per-symbol estimates collapsed into first dimension

Passing `[nSC × nSym]` directly is wrong — dim 2 is read as NS, not nSym:

```matlab
% WRONG — hEst [nSC x nSym] misinterpreted as [nSC x NS=nSym]
eqData = ofdmEqualize(rxData, hEst_per_sym, nVar);

% CORRECT — collapse first dim to (nSC*nSym), keep stream/antenna dims
eqData = ofdmEqualize(rxData, reshape(hEst_per_sym, [], Ns, Nr), nVar);
```

## OFDM with Pilots

To insert pilots, pass `pilotIdx` and pilot symbols as additional arguments to `ofdmmod`/`ofdmdemod`. Signal power is based on `nActiveSC` (data + pilots), not `nDataSC` alone.

See `references/ofdm-pilots-and-estimation.md` for the full pilot insertion example.

## Pilot-Based Channel Estimation (R2026a)

Use `ofdmPilotConfig` + `ofdmChannelEstimate` for pilot-based channel estimation without perfect CSI. If you have not already checked, get the current MATLAB version before deciding between the R2026a workflow and the pre-R2026a manual LS approach.

The `ofdmChannelEstimate` workflow differs from the legacy `pilotIdx` approach:

- **`nullIdx` contains only guard bands (NOT DC)** — DC becomes an active-grid position that you zero out manually.
- **No `pilotIdx` argument** to `ofdmmod`/`ofdmdemod` — build a full `[nActiveSC x nSym]` grid with data, pilots, and DC=0, then pass it directly.
- **Pilot locations come from `ofdmPilotConfig`**, not from function arguments.
- **`rxSym` is 3-D**: `[nActiveSC x nSym x nRx]` — add the receive-antenna dimension even for SISO.

See `references/ofdm-pilots-and-estimation.md` for complete code examples.

## OFDM over Fading Channels

Two approaches for channel equalization:

1. **Perfect CSI** (R2023a) — use `ofdmChannelResponse` with path gains from `comm.RayleighChannel` (requires `PathGainsOutputPort=true`). Get `pathFilters` from `info(channel).ChannelFilterCoefficients`. Pass `H(:)` to `ofdmEqualize` for time-varying SISO.

2. **Pilot-based estimation** (R2026a) — use `ofdmPilotConfig` + `ofdmChannelEstimate`.

Both approaches use `ofdmEqualize` with `Algorithm="mmse"` for final equalization. Always use explicit signal power in `awgn` (not `'measured'`) — fading changes the instantaneous power.

See `references/ofdm-fading-channel.md` for channel configuration (Rayleigh/Rician, Doppler, 3GPP profiles, `ofdmEqualize` dimensions).

## Fading Channel Setup

Configure `comm.RayleighChannel` or `comm.RicianChannel` with `PathGainsOutputPort=true`. Key rules:
- Always set `SampleRate` (default is 1 Hz)
- Maximum path delay must be < CP duration: `max(PathDelays) < cpLen/SampleRate`
- Compute Doppler from velocity: `fd = (velocity * carrierFreq) / physconst('LightSpeed')`

See `references/ofdm-fading-channel.md` for full setup, 3GPP profiles, and quasi-static fading.

## Synchronization

Pipeline: **Coarse timing → CFO estimation → CFO correction → Fine timing → OFDM demod → Phase tracking**

Key rules:
- Use `frequencyOffset` for CFO application/correction (not manual `exp(-1j*2*pi*...)`)
- Use `timingEstimate` for cross-correlation timing detection
- Always `unwrap` pilot phase estimates before applying correction across symbols

See `references/ofdm-synchronization.md` for Schmidl-Cox, CP-based timing, Zadoff-Chu preambles, and complete Rx example.

## LDPC Coding

Key rules:
- Use `ldpcEncode`/`ldpcDecode` with config objects (NOT removed `comm.LDPCEncoder`/`comm.LDPCDecoder`)
- **Create config from parity check matrix only:** `H = ldpcPCM(648, 324); encCfg = ldpcEncoderConfig(H); decCfg = ldpcDecoderConfig(H)`. Do NOT pass scalars or Name-Value pairs — `ldpcEncoderConfig(648)`, `ldpcEncoderConfig(648, 1/2)`, and `ldpcDecoderConfig(BlockLength=648)` all error. If you have not already checked, get the current MATLAB version to decide between `ldpcPCM` (R2025a+) and `ldpcQuasiCyclicMatrix` (R2021b+).
- Include `CodingRate` in `convertSNR` when computing Eb/No for coded systems
- Pass `NoiseVariance` to demodulators, such as `qamdemod`, for proper LLR scaling; scale to frequency domain: `nVar_sc = nVar * nFFT`
- Use `OutputType="approxllr"` for LLR computation

See `references/ofdm-ldpc-coding.md` for OFDM+LDPC workflow and multi-codeword framing.

## Advanced Features

See `references/ofdm-system-guide.md` for:
- **Variable CP length** — per-symbol CP via row vector `cpLens`
- **Common OFDM configurations** — WiFi-like, LTE-like, 5G-like parameter sets
- **SNR conversion** — see `matlab-add-awgn` skill for all `convertSNR` patterns
- **Noise variance for soft demodulation** — scaling after `ofdmdemod`

## Cross-References

- **`matlab-add-awgn`** — when you need to add noise and calculate SNR conversions, use this skill. It covers all `convertSNR` patterns, `awgn` usage, and noise variance capture.

## Reference Loading

Load `references/ofdm-pilots-and-estimation.md` when the user asks about pilot insertion, pilot-based channel estimation (R2026a `ofdmChannelEstimate`), or pre-R2026a LS estimation.

Load `references/ofdm-fading-channel.md` when the user asks about fading channel configuration, Rayleigh/Rician setup, Doppler calculation, 3GPP delay profiles, or `ofdmEqualize` dimension handling.

Load `references/ofdm-synchronization.md` when the user asks about timing synchronization, CFO estimation/correction, Schmidl-Cox, preamble design, or pilot-based phase tracking.

Load `references/ofdm-ldpc-coding.md` when the user asks about LDPC coding, forward error correction, `ldpcEncode`/`ldpcDecode`, `NoiseVariance` for soft decoding, or coded BER simulations.

Load `references/ofdm-system-guide.md` when the user asks about SNR conversion details, common OFDM configurations, noise variance for soft demodulation, or variable CP length.

Copyright 2026 The MathWorks, Inc.
