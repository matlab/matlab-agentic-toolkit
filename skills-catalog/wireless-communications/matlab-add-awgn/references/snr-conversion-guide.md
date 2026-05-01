# SNR Conversion Guide & Theoretical BER

## Conversion Formulas

All values in dB.

### Eb/No ↔ Es/No

```
Es/No = Eb/No + 10*log10(BitsPerSymbol)
```

- `BitsPerSymbol` = log2(M) where M is the modulation order
- Es/No is the energy per symbol relative to noise spectral density
- Eb/No is the energy per bit relative to noise spectral density

### Eb/No ↔ SNR

```
SNR = Eb/No + 10*log10(BitsPerSymbol * CodingRate / SamplesPerSymbol)
```

- `CodingRate` = information bits / coded bits (e.g., 3/4 for rate-3/4 LDPC)
- `SamplesPerSymbol` = oversampling factor from pulse shaping (1 for baseband)
- For uncoded systems, `CodingRate = 1`

### SNR ↔ Per-Subcarrier SNR (OFDM)

```
SNR_sc = SNR + 10*log10(FFTLength / NumActiveSubcarriers)
```

- `FFTLength` = total number of subcarriers (including guards and DC)
- `NumActiveSubcarriers` = number of data + pilot subcarriers
- SNR_sc > SNR because energy is concentrated on fewer subcarriers

## Valid `convertSNR` Conversions

| From → To | Supported | Required Name-Value Parameters |
|---|---|---|
| `ebno` → `esno` | Yes | `BitsPerSymbol` |
| `esno` → `ebno` | Yes | `BitsPerSymbol` |
| `ebno` → `snr` | Yes | `BitsPerSymbol`, `CodingRate`, `SamplesPerSymbol` |
| `snr` → `ebno` | Yes | `BitsPerSymbol`, `CodingRate`, `SamplesPerSymbol` |
| `esno` → `snr` | Yes | `CodingRate`, `SamplesPerSymbol` |
| `snr` → `esno` | Yes | `CodingRate`, `SamplesPerSymbol` |
| `snr` → `snrsc` | Yes | `FFTLength`, `NumActiveSubcarriers` |
| `snrsc` → `snr` | Yes | `FFTLength`, `NumActiveSubcarriers` |
| `ebno` → `snrsc` | **No** | Throws error. Use two-step: `ebno→"snr"` then `"snrsc"→"snr"` |
| `esno` → `snrsc` | **No** | Throws error. Same two-step path required |
| `snrsc` → `ebno` | **No** | Use two-step: `"snrsc"→"snr"` then `"snr"→"ebno"` |
| `snrsc` → `esno` | **No** | Use two-step: `"snrsc"→"snr"` then `"snr"→"esno"` |

> **Key insight for OFDM:** `convertSNR(ebno, "ebno", "snr")` returns the SNR per subcarrier (not wideband SNR). Do NOT pass this directly to `awgn()`. You must convert via `convertSNR(snrsc, "snrsc", "snr", ...)` to get wideband SNR, which subtracts `10*log10(nFFT/nActiveSC)`. Skipping this step gives ~0.90 dB too much SNR (for 64-FFT, 52 active), producing ~0.36x theoretical BER.

### `convertSNR` Name-Value Parameters

| Parameter | Default | When It Matters |
|---|---|---|
| `BitsPerSymbol` | 1 | Any conversion involving `ebno` or `esno` |
| `CodingRate` | 1 | Any conversion involving `snr` when FEC is used |
| `SamplesPerSymbol` | 1 | Any conversion involving `snr` when oversampling (pulse shaping) |
| `FFTLength` | 64 | Any conversion involving `snrsc` |
| `NumActiveSubcarriers` | 64 | Any conversion involving `snrsc` |

## Theoretical BER with `berawgn`

`berawgn` computes exact theoretical BER for standard modulations over AWGN. The input is always **Eb/No in dB**.

### Supported Modulations

```matlab
% PSK (phase shift keying)
ber = berawgn(ebno, 'psk', M, 'nondiff');   % M = 2, 4, 8, 16, ...
ber = berawgn(ebno, 'psk', M, 'diff');      % Differentially encoded

% QAM (quadrature amplitude modulation)
ber = berawgn(ebno, 'qam', M);              % M = 4, 8, 16, 32, 64, ...

% FSK (frequency shift keying)
ber = berawgn(ebno, 'fsk', M, 'coherent');
ber = berawgn(ebno, 'fsk', M, 'noncoherent');

% DPSK (differential phase shift keying)
ber = berawgn(ebno, 'dpsk', M);

% PAM (pulse amplitude modulation)
ber = berawgn(ebno, 'pam', M);
```

### Example: Plot Theoretical BER Curves

```matlab
ebnoVec = 0:0.5:20;
berBPSK = berawgn(ebnoVec, 'psk', 2, 'nondiff');
berQPSK = berawgn(ebnoVec, 'psk', 4, 'nondiff');
berQAM16 = berawgn(ebnoVec, 'qam', 16);
berQAM64 = berawgn(ebnoVec, 'qam', 64);
berQAM256 = berawgn(ebnoVec, 'qam', 256);

semilogy(ebnoVec, berBPSK, ebnoVec, berQPSK, ebnoVec, berQAM16, ...
    ebnoVec, berQAM64, ebnoVec, berQAM256);
grid on;
xlabel('Eb/No (dB)');
ylabel('BER');
legend('BPSK', 'QPSK', '16-QAM', '64-QAM', '256-QAM');
title('Theoretical BER over AWGN');
```

### Example: Compare Simulated vs Theoretical BER

```matlab
M = 16;
bitsPerSymbol = log2(M);
ebnoVec = 0:2:16;
numBits = 1e6;

berSim = zeros(size(ebnoVec));
for idx = 1:length(ebnoVec)
    snrDb = convertSNR(ebnoVec(idx), "ebno", "snr", ...
        BitsPerSymbol=bitsPerSymbol);
    txBits = randi([0 1], numBits, 1);
    txSig = qammod(txBits, M, InputType="bit", UnitAveragePower=true);
    rxSig = awgn(txSig, snrDb, 0);
    rxBits = qamdemod(rxSig, M, OutputType="bit", UnitAveragePower=true);
    [~, berSim(idx)] = biterr(txBits, rxBits);
end

berTheory = berawgn(ebnoVec, 'qam', M);

semilogy(ebnoVec, berTheory, '-', ebnoVec, berSim, 'o');
grid on;
xlabel('Eb/No (dB)');
ylabel('BER');
legend('Theoretical', 'Simulated');
title('16-QAM BER: Simulated vs Theoretical');
```

## Estimate Required Eb/No for a Target BER

Use `berawgn` over a fine Eb/No range and interpolate to estimate the crossing point. Works for any modulation `berawgn` supports (PSK, QAM, FSK, DPSK, PAM). The result is an **estimate** — accuracy depends on the Eb/No step size.

```matlab
% Estimate Eb/No needed for 16-QAM BER = 1e-5
targetBER = 1e-5;
M = 16;
ebnoVec = 0:0.1:25;
berVec = berawgn(ebnoVec, 'qam', M);
reqEbNoDb = interp1(log10(berVec), ebnoVec, log10(targetBER));
% Result: ~13.4 dB
```

This approach generalizes to any standard modulation — just change the `berawgn` call:

```matlab
% Estimate Eb/No for BPSK BER = 1e-6
berVec = berawgn(ebnoVec, 'psk', 2, 'nondiff');
reqEbNoDb = interp1(log10(berVec), ebnoVec, log10(1e-6));
% Result: ~10.5 dB

% Estimate Eb/No for 64-QAM BER = 1e-3
berVec = berawgn(ebnoVec, 'qam', 64);
reqEbNoDb = interp1(log10(berVec), ebnoVec, log10(1e-3));
% Result: ~14.8 dB
```

> **Note:** `interp1` works on `log10(berVec)` because BER curves are approximately linear on a log scale. Use a fine Eb/No step (0.1 dB) for sub-0.1 dB accuracy. Results are estimates, not exact analytical values.

## Common System Configurations

### QPSK, Rate-1/2, No Oversampling

```matlab
ebnoDb = 5;
snrDb = convertSNR(ebnoDb, "ebno", "snr", ...
    BitsPerSymbol=2, CodingRate=1/2);
% snrDb = 5 + 10*log10(2 * 0.5 / 1) = 5 + 0 = 5 dB
```

### 64-QAM, Rate-3/4, 4x Oversampling

```matlab
ebnoDb = 10;
snrDb = convertSNR(ebnoDb, "ebno", "snr", ...
    BitsPerSymbol=6, CodingRate=3/4, SamplesPerSymbol=4);
% snrDb = 10 + 10*log10(6 * 0.75 / 4) = 10 + 0.51 = 10.51 dB
```

### 256-QAM, Rate-5/6, OFDM (2048-FFT, 1200 Active)

```matlab
ebnoDb = 20;

% Step 1: Eb/No → per-subcarrier SNR
snrscDb = convertSNR(ebnoDb, "ebno", "snr", ...
    BitsPerSymbol=8, CodingRate=5/6);
% snrscDb = 20 + 10*log10(8 * 5/6) = 20 + 8.24 = 28.24 dB

% Step 2: Per-subcarrier SNR → wideband SNR (for awgn)
% Subtracts 10*log10(nFFT/nActiveSC)
snrWbDb = convertSNR(snrscDb, "snrsc", "snr", ...
    FFTLength=2048, NumActiveSubcarriers=1200);
% snrWbDb = 28.24 - 10*log10(2048/1200) = 28.24 - 2.32 = 25.92 dB
```

Copyright 2026 The MathWorks, Inc.
