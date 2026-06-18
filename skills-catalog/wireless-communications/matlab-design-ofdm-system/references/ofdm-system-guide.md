# OFDM System Design — SNR, Parameters, and Configurations

## SNR and Noise for OFDM

For general `convertSNR` and `awgn` patterns, see `matlab-add-awgn`.

### Signal Power

OFDM time-domain signal power with unit-power modulation symbols:

```
sigPow = nActiveSC / nFFT^2    (linear)
sigPow_dBW = 10*log10(nActiveSC) - 20*log10(nFFT)    (dB)
```

This is due to MATLAB's `ifft` using 1/N normalization. `nActiveSC` includes both data and pilot subcarriers.

### Converting Between SNR Domains

| From | To | Formula |
|------|----|---------|
| SNR_sc | SNR_wb | `convertSNR(snr_sc, "snrsc", "snr", FFTLength=nFFT, NumActiveSubcarriers=nActiveSC)` |
| SNR_wb | SNR_sc | `convertSNR(snr_wb, "snr", "snrsc", FFTLength=nFFT, NumActiveSubcarriers=nActiveSC)` |
| SNR_sc | Eb/No | `convertSNR(snr_sc, "snr", "ebno", BitsPerSymbol=bps)` |
| SNR_sc | Eb/No (coded) | `convertSNR(snr_sc, "snr", "ebno", BitsPerSymbol=bps, CodingRate=R)` |
| Eb/No | SNR_sc | `convertSNR(ebno, "ebno", "snr", BitsPerSymbol=bps, CodingRate=R)` |

**Note:** `convertSNR` does NOT handle CP overhead. CP samples carry the same signal power as OFDM symbol samples, so the overhead is accounted for by using explicit signal power in `awgn`.

### Complete Noise Addition Recipe

```matlab
% 1. Signal power (deterministic from OFDM parameters)
nActiveSC = nFFT - length(nullIdx);
sigPow = 10*log10(nActiveSC / nFFT^2);

% 2. Convert per-subcarrier SNR to wideband SNR
snr_wb = convertSNR(snr_sc, "snrsc", "snr", ...
    FFTLength=nFFT, NumActiveSubcarriers=nActiveSC);

% 3. Add noise with explicit power
[rxSig, nVar] = awgn(txSig, snr_wb, sigPow);

% 4. After ofdmdemod: frequency-domain noise variance
nVar_sc = nVar * nFFT;
```

### Converting to Eb/No (for `berawgn` comparison)

`berawgn` requires Eb/No — do NOT pass SNR_sc directly. Always convert SNR_sc to Eb/No first using `convertSNR`, then call `berawgn`. The same applies if using `erfc` or `qfunc` closed-form expressions: the argument must be derived from Eb/No, not SNR_sc.

```matlab
% Per-subcarrier SNR -> Eb/No (uncoded)
ebno = convertSNR(snr_sc, "snr", "ebno", BitsPerSymbol=log2(M));
ber_theory = berawgn(ebno, 'psk', M, 'nondiff');

% Per-subcarrier SNR -> Eb/No (coded, e.g., rate-1/2 LDPC)
ebno_coded = convertSNR(snr_sc, "snr", "ebno", ...
    BitsPerSymbol=log2(M), CodingRate=0.5);
```

### Noise Variance for Soft Demodulation

```matlab
% Capture noise variance from awgn
[rxSig, nVar] = awgn(txSig, snr_wb, sigPow);

% After ofdmdemod (FFT sums nFFT terms), noise variance scales by nFFT
nVar_sc = nVar * nFFT;

% Pass to soft demodulator
llr = qamdemod(rxData, M, UnitAveragePower=true, ...
    OutputType="approxllr", NoiseVariance=nVar_sc);
```

## Variable CP Length

`ofdmmod`/`ofdmdemod` support per-symbol CP length via a row vector:

```matlab
% 7 symbols: first has longer CP (like LTE slot structure)
cpLens = [20, 16, 16, 16, 16, 16, 16];  % row vector, length = nSym
nSym = length(cpLens);
data = complex(randn(nDataSC, nSym), randn(nDataSC, nSym));

txSig = ofdmmod(data, nFFT, cpLens, nullIdx);
symOffset = cpLens;  % default: skip entire CP
rxData = ofdmdemod(txSig, nFFT, cpLens, symOffset, nullIdx);
```

## Common OFDM Configurations

| Config | nFFT | CP | SCS | BW | Active SCs | Nulls |
|--------|------|----|-----|-----|-----------|-------|
| WiFi-like (20 MHz) | 64 | 16 | 312.5 kHz | 20 MHz | 52 | 12 |
| LTE-like (10 MHz) | 1024 | 72 | 15 kHz | 10 MHz | 600 | 424 |
| 5G-like (100 MHz) | 4096 | 288 | 30 kHz | 100 MHz | 3276 | 820 |

### WiFi-like (64-FFT) Subcarrier Allocation

```matlab
nFFT = 64; cpLen = 16;
nullIdx = [1:6, 33, 60:64].';       % 12 nulls: 6 lower + DC + 5 upper
pilotIdx = [12; 26; 40; 54];         % 4 pilots
nDataSC = 48;                         % 52 active - 4 pilots
```

## `ofdmmod` vs `comm.OFDMModulator` — When to Use Which

`ofdmmod` is the default for this skill. Use `comm.OFDMModulator` **only** when windowing is required (transmitter side only — always use `ofdmdemod` function for demodulation).

| Feature | `ofdmmod` function | `comm.OFDMModulator` SO |
|---------|-------------------|------------------------|
| Raised cosine windowing | No | **Yes** (`Windowing`, `WindowLength`) |
| Arbitrary null subcarrier indices | **Yes** (any index vector) | No (contiguous guard bands + DC only) |
| Per-symbol varying pilot locations | No (fixed across symbols) | **Yes** |
| Variable CP per symbol | Yes (vector, R2024a+) | Yes |
| MIMO / multi-stream | Yes (3rd dim) | Yes (`NumTransmitAntennas`) |
| Oversampling | Yes | Yes |
| dlarray / deep learning | **Yes** | No |
| GPU arrays | **Yes** | No |
| C/C++ code generation | **Yes** (R2025a+) | Yes |
| Batch dimension (4-D input) | **Yes** | No |
| `symOffset` (demod side) | **Yes** (`ofdmdemod`) | No (`comm.OFDMDemodulator` has no equivalent) |
| Resource mapping visualization | No | **Yes** (`showResourceMapping`) |

**Important:** Do NOT use `comm.OFDMDemodulator` — it lacks `symOffset` control and offers no advantage over `ofdmdemod`. If you use `comm.OFDMModulator` for TX windowing, pair it with `ofdmdemod` (function) for RX.

```matlab
% Example: TX with windowing, RX with ofdmdemod function
ofdmMod = comm.OFDMModulator( ...
    FFTLength=nFFT, ...
    CyclicPrefixLength=cpLen, ...
    NumGuardBandCarriers=[nGuardLow; nGuardHigh], ...
    InsertDCNull=true, ...
    Windowing=true, ...
    WindowLength=cpLen/2);

txSig = ofdmMod(dataGrid);
% ... channel + noise ...
symOffset = cpLen;
rxData = ofdmdemod(rxSig, nFFT, cpLen, symOffset, nullIdx);
```

Copyright 2026 The MathWorks, Inc.
