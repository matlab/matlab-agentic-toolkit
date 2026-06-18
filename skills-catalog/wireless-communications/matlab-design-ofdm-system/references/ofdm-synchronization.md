# OFDM Synchronization — Reference

## Synchronization Pipeline

```
Rx signal → Coarse Timing → Fractional CFO → Integer CFO → Fine Timing → ofdmdemod → Phase Tracking → Equalize
```

Not all steps are needed in every system. For AWGN-only or small CFO, skip integer CFO. For short frames, skip phase tracking.

## Must-Follow Rules

1. **Use `timingEstimate` for preamble-based timing** — not manual cross-correlation. Handles threshold detection, returns 0-based sample offset, works with multipath and CFO.
2. **Use `frequencyOffset` for CFO correction** — not manual `exp(-1j*2*pi*...)`. Handles sample-rate conversion, supports matrix input (multi-antenna).
3. **Normalize Schmidl-Cox metric correctly** — use `M(d) = |P(d)|² / (R1(d) * R2(d))`. Using only one energy window gives unbounded metric. Correct metric is bounded [0, 1].
4. **Use `unwrap` for pilot-based phase tracking** — residual CFO causes linearly increasing phase. Without `unwrap`, `angle()` wraps at ±π, corrupting correction.
5. **Use `findpeaks` for CP-based timing** — not `max()`. CP correlation peaks at every symbol boundary; `max()` picks an arbitrary one.

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `timingEstimate(rx, ref)` | Cross-correlation timing offset | R2024a |
| `frequencyOffset(x, Fs, offset)` | Apply/correct frequency offset | R2022a |
| `comm.PreambleDetector` | Correlate with known preamble | R2016b |

## Schmidl-Cox Synchronization

Joint timing + fractional CFO estimation using a preamble with repeated half-symbol.

**Always encapsulate** preamble generation and sync estimation as local functions (e.g., `generateSchmidlCoxPreamble`, `estimateTimingAndCFO`). The Tx generates the preamble and the Rx needs the same reference — a shared function avoids duplication and bugs.

**Always embed the preamble in a longer frame** — append at least one OFDM symbol (or `nFFT` zeros) after the preamble. A bare preamble (only `cpLen + nFFT` samples) leaves no margin for the timing search window. Noise shifts the timing metric peak by 1–2 samples, causing index-out-of-bounds when extracting the corrected signal. Example: `txFrame = [preamWithCP; dataSymbols]` or `txFrame = [preamWithCP; zeros(nFFT, 1)]`.

### Preamble Design

For half-symbol repetition in time domain, populate every other subcarrier in **DFT order** (not centered-frequency order):

```matlab
nFFT = 64; cpLen = 16;

% Even DFT-order subcarriers (0-based: 0,2,4,...) → MATLAB 1-based: 1,3,5,...
evenDFT = (1:2:nFFT).';
% Remove DC (index 1) and Nyquist (index nFFT/2+1)
usableSC = setdiff(evenDFT, [1; nFFT/2+1]);

% Populate with QPSK
rng(0);
preamDFT = zeros(nFFT, 1);
preamDFT(usableSC) = qammod(randi([0 3], length(usableSC), 1), 4, ...
    UnitAveragePower=true);

% IFFT → time domain (repeated half-symbol)
preamTD = ifft(preamDFT) * sqrt(nFFT);
preamWithCP = [preamTD(end-cpLen+1:end); preamTD];

% Verify: first half equals second half
halfN = nFFT/2;
assert(norm(preamTD(1:halfN) - preamTD(halfN+1:end)) < 1e-10);
```

**Why DFT order, not centered-frequency?** `ofdmmod` applies `ifftshift` internally. For manual preamble generation with `ifft`, use DFT-order indices directly.

### Alternative: Zadoff-Chu Preamble

Zadoff-Chu (ZC) sequences have constant amplitude and ideal autocorrelation, making them robust for timing detection in multipath:

```matlab
nFFT = 64; cpLen = 16;

% Generate ZC sequence (length must be prime for constant amplitude)
zcLen = 63; zcRoot = 25;
zcSeq = zadoffChuSeq(zcRoot, zcLen);

% Map to even DFT-order subcarriers for half-symbol repetition
evenDFT = (1:2:nFFT).';
usableSC = setdiff(evenDFT, [1; nFFT/2+1]);
preamDFT = zeros(nFFT, 1);
preamDFT(usableSC) = zcSeq(1:length(usableSC));

% IFFT → time domain
preamTD = ifft(preamDFT) * sqrt(nFFT);
preamWithCP = [preamTD(end-cpLen+1:end); preamTD];
```

For a full-spectrum preamble (used with `timingEstimate` for timing detection without half-symbol structure):

```matlab
% Full-spectrum ZC preamble — all active subcarriers populated
zcLen = 53; zcRoot = 25;  % prime length close to nActiveSC
zcSeq = zadoffChuSeq(zcRoot, zcLen);
nullIdx = [1:6, 33, 60:64].';
nActiveSC = nFFT - length(nullIdx);  % 52
preamSym = zcSeq(1:nActiveSC);
preamTD = ofdmmod(preamSym, nFFT, cpLen, nullIdx);
```

### Metric Computation

```matlab
halfN = nFFT/2;
nSamples = length(rxSig);
P  = zeros(nSamples, 1);
R1 = zeros(nSamples, 1);
R2 = zeros(nSamples, 1);

for d = 1:nSamples - 2*halfN + 1
    for k = 0:halfN-1
        P(d)  = P(d)  + conj(rxSig(d+k)) * rxSig(d+k+halfN);
        R1(d) = R1(d) + abs(rxSig(d+k))^2;
        R2(d) = R2(d) + abs(rxSig(d+k+halfN))^2;
    end
end

% Bounded metric [0, 1]
M = abs(P).^2 ./ (R1 .* R2 + eps);
```

### Timing and CFO Extraction

```matlab
% Timing: peak of metric
[~, peakIdx] = max(M);

% Fractional CFO (normalized to subcarrier spacing)
cfoFrac = angle(P(peakIdx)) / pi;

% Convert to Hz and correct
scs = sampleRate / nFFT;
cfoFrac_Hz = cfoFrac * scs;
rxCorrected = frequencyOffset(rxSig, sampleRate, -cfoFrac_Hz);
```

Schmidl-Cox CFO range: (−1, +1) subcarrier spacings.

## CP-Based Coarse Timing

Exploits the cyclic prefix — no preamble needed.

```matlab
L = cpLen; N = nFFT;
nSamples = length(rxSig);
P = zeros(nSamples, 1);
R = zeros(nSamples, 1);

for d = 1:nSamples - N - L + 1
    for k = 0:L-1
        P(d) = P(d) + conj(rxSig(d+k)) * rxSig(d+k+N);
        R(d) = R(d) + abs(rxSig(d+k))^2 + abs(rxSig(d+k+N))^2;
    end
end
M = 2*abs(P) ./ (R + eps);

% Find first symbol boundary (NOT max — picks arbitrary symbol)
[~, locs] = findpeaks(M, MinPeakHeight=0.5, MinPeakDistance=N);
firstSymbolStart = locs(1);

% CP-based fractional CFO estimate (single symbol)
cfoFrac = angle(P(firstSymbolStart)) / (2*pi);

% Improved: average across all detected symbol boundaries for robustness
cfoFrac = mean(angle(P(locs))) / (2*pi);
```

**Averaging over multiple symbols** reduces CFO estimation noise. The single-peak estimate suffices at high SNR; averaging helps at low SNR or with short CP.

**CP-based CFO range:** (−0.5, +0.5) subcarrier spacings (narrower than Schmidl-Cox).

**CP vs Schmidl-Cox:** CP peaks at every symbol boundary (repeating). Schmidl-Cox peaks only at the preamble (unique). Use CP when no preamble is available.

## Integer CFO Estimation

After correcting fractional CFO, residual integer offset shifts all subcarriers by N positions. Use a separate **full-spectrum** preamble (all active subcarriers populated):

```matlab
% After fractional CFO correction and timing alignment
rxPreamble = rxCorrected(timingOffset + (1:nFFT+cpLen));
rxPreamFFT = fft(rxPreamble(cpLen+1:end));
refFFT = fft(refPreamTD);  % known full-spectrum preamble (no CP)

% Cross-correlate in frequency domain
searchRange = -5:5;
corrMag = zeros(length(searchRange), 1);
for i = 1:length(searchRange)
    shift = searchRange(i);
    corrMag(i) = abs(sum(rxPreamFFT .* conj(circshift(refFFT, shift))));
end

[~, bestIdx] = max(corrMag);
integerCFO = searchRange(bestIdx);

% Total CFO = fractional + integer
totalCFO_Hz = (cfoFrac + integerCFO) * scs;
rxFullCorr = frequencyOffset(rxSig, sampleRate, -totalCFO_Hz);
```

For small CFO (< 1 subcarrier spacing), integer CFO estimation is not needed.

## Pilot-Based Phase Tracking

After OFDM demod, residual CFO causes linearly increasing phase across symbols.

**When is CPE tracking needed?**
- **Perfect CSI** (`ofdmChannelResponse`) — always needed. The channel response captures only the physical channel, not oscillator offset.
- **Sparse pilot estimation** (pilots on some symbols, interpolated between) — needed on non-pilot symbols where interpolation cannot track fast phase changes.
- **Dense pilot estimation** (pilots on every symbol) — not needed. The per-symbol channel estimate already captures the phase rotation; equalization corrects it implicitly.

```matlab
% After ofdmdemod with pilots
[rxData, rxPilots] = ofdmdemod(rxSig, nFFT, cpLen, cpLen, nullIdx, pilotIdx);

% Known transmitted pilots
txPilots = ones(length(pilotIdx), nSym);

% Common Phase Error (CPE) per symbol
pilotPhaseErr = angle(rxPilots ./ txPilots);   % [nPilots x nSym]
cpe = mean(pilotPhaseErr, 1);                   % [1 x nSym]

% CRITICAL: unwrap to handle phase wrapping
cpe = unwrap(cpe);

% Correct data subcarriers
rxCorrected = rxData .* exp(-1j * cpe);
```

**Why `unwrap`?** Residual CFO of 0.02 SCS accumulates ~15.5 rad over 100 symbols. Without `unwrap`, `angle()` wraps at ±π, creating discontinuities. With `unwrap`, BER drops from ~0.50 to ~0.01.

## `symOffset` and Timing Errors

The `symOffset` parameter in `ofdmdemod` controls where the FFT window starts within the CP+symbol:

- `symOffset = cpLen` — skip entire CP (optimal with perfect timing)
- `symOffset = cpLen/2` — center the FFT window (robust to timing errors up to ±cpLen/2 samples)
- Timing error within CP range → only phase rotation per subcarrier (correctable by equalization)
- Timing error beyond CP → ISI (not correctable)

## `timingEstimate` Usage

```matlab
% Basic: returns 0-based sample offset
offset = timingEstimate(rxSig, preamWithCP);

% With threshold (returns empty if not detected)
offset = timingEstimate(rxSig, preamWithCP, Threshold=0.5);

% Second output: normalized correlation (for debugging)
[offset, normcorr] = timingEstimate(rxSig, preamWithCP);
```

Robust to CFO and multipath. Works at SNR as low as 0 dB. Returns `[]` when threshold not met.

Introduced R2024a.

## `frequencyOffset` Usage

```matlab
% Apply CFO (impairment simulation)
rxWithCFO = frequencyOffset(txSig, sampleRate, cfo_Hz);

% Correct CFO (negate the estimate)
rxCorrected = frequencyOffset(rxWithCFO, sampleRate, -cfoEst_Hz);
```

**Convert normalized CFO to Hz:** `cfo_Hz = cfo_normalized * (sampleRate / nFFT)`

Introduced R2022a.

## Complete OFDM Rx with Synchronization

```matlab
nFFT = 64; cpLen = 16;
nullIdx = [1:6, 33, 60:64].';
pilotIdx = [12; 26; 40; 54];
nDataSC = nFFT - length(nullIdx) - length(pilotIdx);
nActiveSC = nFFT - length(nullIdx);
sampleRate = 1e6; scs = sampleRate / nFFT;
M = 4;  nSym = 50;

% --- Tx: Preamble + Data ---
preamDFT = zeros(nFFT, 1);
usableSC = setdiff((1:2:nFFT).', [1; nFFT/2+1]);
preamDFT(usableSC) = qammod(randi([0 3], length(usableSC), 1), 4, ...
    UnitAveragePower=true);
preamTD = ifft(preamDFT) * sqrt(nFFT);
preamWithCP = [preamTD(end-cpLen+1:end); preamTD];

data = randi([0 M-1], nDataSC, nSym);
modData = pskmod(data, M, InputType="integer");
pilots = ones(length(pilotIdx), nSym);
dataTD = ofdmmod(modData, nFFT, cpLen, nullIdx, pilotIdx, pilots);

txSig = [zeros(100, 1); preamWithCP; dataTD];

% --- Channel: multipath + CFO + noise ---
h = [1; 0; 0.3*exp(1j*0.5)];
fadedSig = filter(h, 1, txSig);
trueCFO_Hz = 0.15 * scs;
rxWithCFO = frequencyOffset(fadedSig, sampleRate, trueCFO_Hz);
sigPow = 10*log10(nActiveSC / nFFT^2);
snr_sc = 20;
snr_wb = convertSNR(snr_sc, "snrsc", "snr", ...
    FFTLength=nFFT, NumActiveSubcarriers=nActiveSC);
rxSig = awgn(rxWithCFO, snr_wb, sigPow);

% --- Step 1: Coarse timing via preamble ---
offset = timingEstimate(rxSig, preamWithCP);

% --- Step 2: Schmidl-Cox fractional CFO ---
halfN = nFFT/2;
preamRx = rxSig(offset + (1:nFFT+cpLen));
P = sum(conj(preamRx(cpLen + (1:halfN))) .* preamRx(cpLen + halfN + (1:halfN)));
cfoFrac = angle(P) / pi;
cfoFrac_Hz = cfoFrac * scs;

% --- Step 3: Correct CFO ---
rxCorrected = frequencyOffset(rxSig, sampleRate, -cfoFrac_Hz);

% --- Step 4: OFDM demod (skip preamble) ---
dataStart = offset + length(preamWithCP);
rxDataTD = rxCorrected(dataStart + (1:nSym*(nFFT+cpLen)));
[rxData, rxPilots] = ofdmdemod(rxDataTD, nFFT, cpLen, cpLen, nullIdx, pilotIdx);

% --- Step 5: Pilot-based phase tracking ---
cpe = unwrap(mean(angle(rxPilots ./ pilots), 1));
rxTracked = rxData .* exp(-1j * cpe);

% --- Demod and BER ---
demodData = pskdemod(rxTracked, M, OutputType="integer");
[~, ber] = biterr(data(:), demodData(:));
fprintf('BER: %.4f\n', ber);
```

Copyright 2026 The MathWorks, Inc.
