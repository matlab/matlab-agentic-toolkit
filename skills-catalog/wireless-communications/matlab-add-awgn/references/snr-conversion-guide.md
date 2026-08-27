# SNR Conversion Guide & Theoretical BER

## Manual Fallback: SNR ↔ Per-Subcarrier SNR (pre-R2023b)

The `"snrsc"` mode in `convertSNR` requires R2023b or later. For R2022a–R2023a, use this formula:

```
SNR_sc = SNR + 10*log10(FFTLength / NumActiveSubcarriers)
```

- `FFTLength` = total number of subcarriers (including guards and DC)
- `NumActiveSubcarriers` = number of data + pilot subcarriers
- SNR_sc > SNR because energy is concentrated on fewer subcarriers

All other conversions (Eb/No↔Es/No, Eb/No↔SNR, Es/No↔SNR) are handled by `convertSNR` (available since R2022a). Always use `convertSNR` — never compute these manually. For details, refer to the [`convertSNR` documentation](https://www.mathworks.com/help/comm/ref/convertsnr.html).

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

> **Key insight for OFDM:** `convertSNR(ebno, "ebno", "snr")` returns the SNR per subcarrier (not wideband SNR). Do NOT pass this directly to `awgn()`. You must convert via `convertSNR(snrsc, "snrsc", "snr", ...)` to get wideband SNR, which subtracts `10*log10(nFFT/nActiveSC)`. Skipping this step overestimates SNR — for example, ~0.90 dB too much for 64-FFT with 52 active subcarriers, producing ~0.36x theoretical BER.

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

Use the two-step conversion from Eb/No to wideband SNR:

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

## Estimate required Eb/No

Use this section when the user asks for the Eb/No or SNR needed to achieve a target BER, BLER, or FER.

### Decision tree

1. **Modulation supported by `berawgn` or `berfading`?**
   - Yes → Use the analytical function with `fzero` or `interp1` to find the Eb/No crossing point.
   - No → Run Monte Carlo simulations sweeping Eb/No.

2. **Channel type:**
   - **AWGN:** Use `berawgn(ebnoRange, modType, M)` directly.
   - **Flat or frequency-selective fading (single-carrier):** Use `berfading(ebnoRange, modType, M, ...)` if supported.
   - **OFDM:** Assume flat fading per subcarrier. If the modulation is supported by `berawgn` or `berfading`, use the analytical approach per subcarrier; otherwise, simulate.

3. **Converting result to wideband SNR:**
   - Convert per-subcarrier Eb/No to wideband SNR using the two-step process (see "256-QAM, Rate-5/6, OFDM" example above) to set the noise level for `awgn`.

### Example: Find Eb/No for target BER using fzero

```matlab
% Find Eb/No for BER = 1e-5 with 16-QAM over AWGN
targetBER = 1e-5;
M = 16;
f = @(ebnoDb) berawgn(ebnoDb, 'qam', M) - targetBER;
requiredEbNo = fzero(f, [0 20]);
% requiredEbNo ≈ 13.4 dB
```

### Example: Find Eb/No for target BER using interp1

```matlab
% Sweep Eb/No and interpolate
ebnoRange = 0:0.1:20;
ber = berawgn(ebnoRange, 'qam', 16);
targetBER = 1e-5;
requiredEbNo = interp1(ber, ebnoRange, targetBER);
% requiredEbNo ≈ 13.4 dB (accuracy depends on step size)
```

### When to simulate

If the scenario is not supported analytically (e.g., custom modulation, non-standard channel model, or coded systems where `berfading` doesn't apply), run Monte Carlo simulations sweeping Eb/No and use `interp1` on the simulated BER curve.

Copyright 2026 The MathWorks, Inc.
