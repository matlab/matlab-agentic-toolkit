# LDPC Coding for OFDM — Reference

## Must-Follow Rules

1. **Use the modern function API** — `ldpcEncode`/`ldpcDecode` with config objects. The System objects `comm.LDPCEncoder` and `comm.LDPCDecoder` are **removed** and error immediately.
2. **Pass `NoiseVariance` to the demodulator** — `qamdemod`/`pskdemod` need `NoiseVariance` to produce correctly scaled LLR. Without it, decoding degrades severely.
3. **Include `CodingRate` in `convertSNR`** — omitting it inflates SNR (3 dB too high for rate-1/2). Always pass the actual code rate.
4. **Feed LLR (soft bits) to the decoder** — `ldpcDecode` takes log-likelihood ratios. Convention: positive LLR = bit 0, negative LLR = bit 1.
5. **`ldpcEncoderConfig` and `ldpcDecoderConfig` each take exactly one argument: a parity check matrix** — there is no scalar, Name-Value, or two-argument shortcut. Always create the PCM first, then pass it:

```matlab
% CORRECT — two-step: create PCM, then config
H = ldpcPCM(648, 324);           % parity check matrix (sparse logical)
encCfg = ldpcEncoderConfig(H);   % encoder config
decCfg = ldpcDecoderConfig(H);   % decoder config

% WRONG — all of these error immediately:
ldpcEncoderConfig(648, 1/2)                  % scalar args
ldpcEncoderConfig(648)                       % scalar block length
ldpcDecoderConfig(BlockLength=648, CodeRate=1/2)  % Name-Value pairs
```

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `ldpcPCM(N, K)` | Create rate-1/2 parity check matrix | R2025a |
| `ldpcQuasiCyclicMatrix(Z, P)` | Create any-rate PCM from prototype | R2021b |
| `ldpcEncoderConfig(H)` | Create encoder config | R2021b |
| `ldpcDecoderConfig(H)` | Create decoder config | R2021b |
| `ldpcEncode(msg, encCfg)` | Encode information bits | R2021b |
| `ldpcDecode(llr, decCfg, maxIter)` | Decode from LLR | R2021b |

**Removed — do NOT use:**
- `comm.LDPCEncoder` / `comm.LDPCDecoder` — removed, error immediately
- `dvbs2ldpc` — deprecated, warns. Use `ldpcPCM` or `ldpcQuasiCyclicMatrix`

## Which Approach to Use

| MATLAB Version | How to Create the Parity Check Matrix |
|----------------|--------------------------------------|
| **R2025a+** | `H = ldpcPCM(N, K)` — generic, any block length and rate. Preferred. |
| **R2021b–R2024b** | `H = ldpcQuasiCyclicMatrix(blockSize, P)` — pass a subblock size and prototype matrix `P`. See the `ldpcQuasiCyclicMatrix` doc examples for IEEE 802.11 prototype matrices at various rates. |

Once you have `H`, the workflow is identical on all versions:
```matlab
encCfg = ldpcEncoderConfig(H);
decCfg = ldpcDecoderConfig(H);
coded  = ldpcEncode(msg, encCfg);
decoded = ldpcDecode(llr, decCfg, maxIter);
```

**Example (R2021b+, rate 3/4, block 648, from `ldpcQuasiCyclicMatrix` doc):**
```matlab
P = [16 17 22 24  9  3 14 -1  4  2  7 -1 26 -1  2 -1 21 -1  1  0 -1 -1 -1 -1
     25 12 12  3  3 26  6 21 -1 15 22 -1 15 -1  4 -1 -1 16 -1  0  0 -1 -1 -1
     25 18 26 16 22 23  9 -1  0 -1  4 -1  4 -1  8 23 11 -1 -1 -1  0  0 -1 -1
      9  7  0  1 17 -1 -1  7  3 -1  3 23 -1 16 -1 -1 21 -1  0 -1 -1  0  0 -1
     24  5 26  7  1 -1 -1 15 24 15 -1  8 -1 13 -1 13 -1 11 -1 -1 -1 -1  0  0
      2  2 19 14 24  1 15 19 -1 21 -1  2 -1 24 -1  3 -1  2  1 -1 -1 -1 -1  0];
H = ldpcQuasiCyclicMatrix(27, P);  % rate 3/4, block 648
encCfg = ldpcEncoderConfig(H);
```

## Basic OFDM + LDPC Workflow

```matlab
%% Parameters
nFFT = 64; cpLen = 16;
nullIdx = [1:6, 33, 60:64].';
nActiveSC = nFFT - length(nullIdx);  % 52
M = 16; k = log2(M);
snr_sc = 12;  % dB

%% Create LDPC code (rate-1/2)
H = ldpcPCM(648, 324);
encCfg = ldpcEncoderConfig(H);
decCfg = ldpcDecoderConfig(H);
codeRate = decCfg.CodeRate;  % 0.5
K = encCfg.NumInformationBits;  % 324
N = encCfg.BlockLength;  % 648

%% Encode
msg = randi([0 1], K, 1);
encoded = ldpcEncode(msg, encCfg);

%% Map to OFDM symbols
nSymbolsPerCW = ceil(N / (nActiveSC * k));  % QAM symbols needed
% Pad to fill complete OFDM grid
nBitsNeeded = nActiveSC * nSymbolsPerCW * k;
txBits = [encoded; zeros(nBitsNeeded - N, 1)];

%% Modulate (QAM + OFDM)
txQAM = qammod(txBits, M, InputType="bit", UnitAveragePower=true);
txGrid = reshape(txQAM, nActiveSC, nSymbolsPerCW);
txSig = ofdmmod(txGrid, nFFT, cpLen, nullIdx);

%% Add noise
sigPow = 10*log10(nActiveSC / nFFT^2);
snr_wb = convertSNR(snr_sc, "snrsc", "snr", ...
    FFTLength=nFFT, NumActiveSubcarriers=nActiveSC);
[rxSig, nVar] = awgn(txSig, snr_wb, sigPow);

%% Demodulate (OFDM + QAM with LLR)
rxGrid = ofdmdemod(rxSig, nFFT, cpLen, cpLen, nullIdx);
nVar_sc = nVar * nFFT;  % frequency-domain noise variance
rxLLR = qamdemod(rxGrid(:), M, OutputType="approxllr", ...
    UnitAveragePower=true, NoiseVariance=nVar_sc);

%% Decode (take only N bits worth of LLR)
[decoded, numIter, parityChecks] = ldpcDecode(rxLLR(1:N), decCfg, 50);
numErrors = sum(msg ~= decoded);
fprintf("Errors: %d, Iterations: %d\n", numErrors, numIter);
```

## CodingRate in convertSNR

Omitting `CodingRate` inflates SNR:

```matlab
% WRONG — 3 dB too much SNR for rate-1/2
snr = convertSNR(5, "ebno", "snr", BitsPerSymbol=2);  % 8.01 dB

% RIGHT — accounts for code rate
snr = convertSNR(5, "ebno", "snr", BitsPerSymbol=2, CodingRate=1/2);  % 5.00 dB
```

| Code rate | SNR penalty if CodingRate omitted |
|-----------|-----------------------------------|
| 1/2 | 3.01 dB |
| 2/3 | 1.76 dB |
| 3/4 | 1.25 dB |
| 5/6 | 0.79 dB |

## NoiseVariance for LLR

For OFDM, noise variance after `ofdmdemod` scales by nFFT:

```matlab
% Capture from awgn
[rxSig, nVar] = awgn(txSig, snr_wb, sigPow);

% Scale to frequency domain
nVar_sc = nVar * nFFT;

% Pass to demodulator
rxLLR = qamdemod(rxData, M, OutputType="approxllr", ...
    UnitAveragePower=true, NoiseVariance=nVar_sc);
```

**Without NoiseVariance:** LLR magnitudes are unscaled, decoder needs more iterations or fails.

## Decoder Algorithms

| Algorithm | Description | When to use |
|-----------|-------------|-------------|
| `"bp"` | Belief propagation (sum-product) | Default. Best accuracy |
| `"layered-bp"` | Layered belief propagation | Faster convergence for QC-LDPC |
| `"norm-min-sum"` | Normalized min-sum | Lower complexity, hardware models |
| `"offset-min-sum"` | Offset min-sum | Lower complexity, hardware models |

```matlab
decCfg = ldpcDecoderConfig(H);
decCfg.Algorithm = "layered-bp";  % faster convergence for QC-LDPC (BP=20 ≈ layered=10)
```

## Iteration Control and Failure Detection

```matlab
maxIter = 50;
[decoded, numIter, parityChecks] = ldpcDecode(rxLLR, decCfg, maxIter);

if all(parityChecks == 0)
    fprintf("Converged after %d iterations\n", numIter);
else
    fprintf("FAILED to converge after %d iterations\n", numIter);
    % Check: NoiseVariance correct? LLR sign convention? SNR too low?
end
```

**Note:** `ldpcDecode` returns `int8`. Use `double(decoded)` if comparing against `double` arrays.

## LLR OutputType

Always use `OutputType="approxllr"` — negligible accuracy loss vs exact `"llr"`, significantly faster for higher-order QAM.

## Multi-Codeword OFDM Frames

When a frame contains multiple LDPC codewords:

```matlab
numCW = 4;
K = encCfg.NumInformationBits;
N = encCfg.BlockLength;

% Encode all codewords
txBits = zeros(N * numCW, 1);
msgAll = zeros(K * numCW, 1);
for ii = 1:numCW
    msg = randi([0 1], K, 1);
    msgAll((ii-1)*K+1 : ii*K) = msg;
    txBits((ii-1)*N+1 : ii*N) = ldpcEncode(msg, encCfg);
end

% ... modulate, OFDM, channel, demodulate ...

% Decode each codeword — split LLR by codeword length N (not symbols)
for ii = 1:numCW
    cwLLR = rxLLR((ii-1)*N+1 : ii*N);
    decoded = ldpcDecode(cwLLR, decCfg, 50);
end
```

**Key:** Split received LLR by codeword length `N`, not by QAM symbols.

## Supported Code Sizes (ldpcPCM)

| N | K | Rate | Expansion factor Z |
|---|---|------|--------------------|
| 648 | 324 | 1/2 | 27 |
| 1296 | 648 | 1/2 | 54 |
| 1944 | 972 | 1/2 | 81 |

For other rates (2/3, 3/4, 5/6), use `ldpcQuasiCyclicMatrix(Z, P)` with the prototype matrix from the relevant standard (IEEE 802.11, 3GPP TS 38.212).

Copyright 2026 The MathWorks, Inc.
