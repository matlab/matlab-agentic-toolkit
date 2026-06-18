# OFDM Pilots and Channel Estimation — Reference

For fading channel configuration details (Rayleigh/Rician setup, Doppler, path delays), see `ofdm-fading-channel.md`.

## Which Approach to Use

- **R2026a+**: Prefer `ofdmPilotConfig` + `ofdmChannelEstimate` — flexible time-frequency pilot placement, no wasted subcarriers on non-pilot symbols, built-in LS estimation with denoising/interpolation.
- **R2023a–R2025b**: Use `pilotIdx` argument to `ofdmmod`/`ofdmdemod` — simpler setup, pilots on fixed subcarrier positions across all symbols.

## Pilot Insertion with ofdmmod/ofdmdemod (pilotIdx Workflow)

**Note:** The `pilotIdx` approach reserves pilot subcarrier positions for **all** symbols. To insert pilots only on specific symbols (e.g., symbols 2 and 8 out of 14), set the pilot values to zero on non-pilot symbols:

```matlab
pilots = zeros(length(pilotIdx), nSym);
pilots(:, [2 8]) = pskmod(zeros(length(pilotIdx), 2), 4, InputType="integer");
```

Those subcarrier positions still carry zero energy on non-pilot symbols (no data there). To place **data on pilot positions in non-pilot symbols**, use the R2026a `ofdmPilotConfig` workflow (full grid approach) described below.

```matlab
nFFT = 64;  cpLen = 16;
nullIdx = [1:6, 33, 60:64].';
pilotIdx = [12; 26; 40; 54];
nDataSC = nFFT - length(nullIdx) - length(pilotIdx);  % 48
nActiveSC = nFFT - length(nullIdx);  % 52 (data + pilots)
M = 16;  nSym = 100;  snr_sc = 15;  % dB

% Modulate data
data = randi([0 M-1], nDataSC, nSym);
modData = qammod(data, M, UnitAveragePower=true, InputType="integer");

% QPSK pilots (same for all symbols)
pilots = pskmod(zeros(length(pilotIdx), nSym), 4, InputType="integer");

% OFDM modulate (6 arguments: data, nFFT, cpLen, nullIdx, pilotIdx, pilots)
txSig = ofdmmod(modData, nFFT, cpLen, nullIdx, pilotIdx, pilots);

% Add noise (power based on nActiveSC, which includes pilots)
sigPow = 10*log10(nActiveSC / nFFT^2);
snr_wb = convertSNR(snr_sc, "snrsc", "snr", ...
    FFTLength=nFFT, NumActiveSubcarriers=nActiveSC);
rxSig = awgn(txSig, snr_wb, sigPow);

% Demodulate (returns data and pilots separately)
symOffset = cpLen;
[rxData, rxPilots] = ofdmdemod(rxSig, nFFT, cpLen, symOffset, nullIdx, pilotIdx);

% Demod
demodData = qamdemod(rxData, M, UnitAveragePower=true, OutputType="integer");
[~, ber] = biterr(data(:), demodData(:));
```

## Perfect CSI Equalization (with Pilots for Phase Tracking)

When path gains are known (simulation), use `ofdmChannelResponse` for equalization and pilots for residual phase tracking:

```matlab
nFFT = 64;  cpLen = 16;
nullIdx = [1:6, 33, 60:64].';
pilotIdx = [12; 26; 40; 54];
nDataSC = nFFT - length(nullIdx) - length(pilotIdx);
nActiveSC = nFFT - length(nullIdx);
activeIdx = setdiff((1:nFFT).', nullIdx);  % for ofdmChannelResponse
M = 4;  nSym = 100;  snr_sc = 15;

% Transmit with pilots
data = randi([0 M-1], nDataSC, nSym);
modData = pskmod(data, M, InputType="integer");
pilots = pskmod(zeros(length(pilotIdx), nSym), 4, InputType="integer");
txSig = ofdmmod(modData, nFFT, cpLen, nullIdx, pilotIdx, pilots);

% Fading channel (see ofdm-fading-channel.md for configuration details)
channel = comm.RayleighChannel(SampleRate=1e6, ...
    PathDelays=[0 1e-6 2e-6], AveragePathGains=[0 -3 -6], ...
    MaximumDopplerShift=50, PathGainsOutputPort=true);
[fadedSig, pathGains] = channel(txSig);

% Add noise
sigPow = 10*log10(nActiveSC / nFFT^2);
snr_wb = convertSNR(snr_sc, "snrsc", "snr", ...
    FFTLength=nFFT, NumActiveSubcarriers=nActiveSC);
rxSig = awgn(fadedSig, snr_wb, sigPow);

% Demodulate
symOffset = cpLen;
[rxData, rxPilots] = ofdmdemod(rxSig, nFFT, cpLen, symOffset, nullIdx, pilotIdx);

% Channel response via ofdmChannelResponse
pathFilters = info(channel).ChannelFilterCoefficients;
H = ofdmChannelResponse(pathGains, pathFilters, nFFT, cpLen, activeIdx);
% H is [nActiveSC x nSym] — extract data subcarrier rows for equalization

% Data subcarrier indices within the active grid
dataRowIdx = setdiff(1:nActiveSC, find(ismember(activeIdx, pilotIdx)));
H_data = H(dataRowIdx, :);

% Equalize (reshape for time-varying channel, works for SISO and MIMO)
nVar_sc = 10^(-snr_sc/10);
[eqData, csi] = ofdmEqualize(rxData, reshape(H_data, [], Ns, Nr), nVar_sc, Algorithm="mmse");

% Demodulate
demodData = pskdemod(eqData, M, OutputType="integer");
[~, ber] = biterr(data(:), demodData(:));
```

## Pilot-Based Channel Estimation (R2026a)

For practical systems without perfect CSI, use `ofdmPilotConfig` + `ofdmChannelEstimate`. This workflow uses a different grid structure — `nullIdx` contains only guard bands (not DC), and you build a full `[nActiveSC x nSym]` grid manually.

```matlab
nFFT = 64;  cpLen = 16;  nSym = 50;  M = 4;  snr_sc = 15;

% Guard-band-only nullIdx (DC is NOT included — it's an active grid position)
guardBands = [6; 5];
nullIdx = [1:guardBands(1), nFFT-guardBands(2)+1:nFFT].';
nActiveSC = nFFT - length(nullIdx);  % 53

% Pilot configuration
pcfg = ofdmPilotConfig;
pcfg.FFTLength = nFFT;
pcfg.NumGuardBandCarriers = guardBands;
pcfg.NumSymbols = nSym;
validate(pcfg);

% Identify data positions (exclude pilots and DC)
[pSym, pLinIdx] = pilotSignal(pcfg);
[pRow, ~] = ind2sub([nActiveSC, nSym], pLinIdx);
pilotSCpos = unique(pRow);
dcActiveIdx = nFFT/2 + 1 - guardBands(1);  % DC in active grid
dataSCpos = setdiff(setdiff((1:nActiveSC).', pilotSCpos), dcActiveIdx);
nDataSC = length(dataSCpos);

% Build transmit grid [nActiveSC x nSym]
data = randi([0 M-1], nDataSC, nSym);
modData = pskmod(data, M, InputType="integer");
txGrid = zeros(nActiveSC, nSym);
txGrid(dataSCpos, :) = modData;
txGrid(pLinIdx) = pSym;  % insert pilots; DC stays zero

% OFDM modulate (no pilotIdx argument — full grid passed directly)
txSig = ofdmmod(txGrid, nFFT, cpLen, nullIdx);

% Fading channel (see ofdm-fading-channel.md for configuration details)
channel = comm.RayleighChannel(SampleRate=1e6, ...
    PathDelays=[0 1e-6 2e-6], AveragePathGains=[0 -3 -6], ...
    MaximumDopplerShift=50);
fadedSig = channel(txSig);

% Add noise
sigPow = 10*log10(nActiveSC / nFFT^2);
snr_wb = convertSNR(snr_sc, "snrsc", "snr", ...
    FFTLength=nFFT, NumActiveSubcarriers=nActiveSC);
rxSig = awgn(fadedSig, snr_wb, sigPow);

% OFDM demodulate (no pilotIdx — returns full active grid)
symOffset = cpLen;
rxGrid = ofdmdemod(rxSig, nFFT, cpLen, symOffset, nullIdx);

% Channel estimation (rxSym must be 3-D: [nActiveSC x nSym x nRx])
[hEst, nVarEst] = ofdmChannelEstimate(reshape(rxGrid, nActiveSC, nSym, 1), pcfg, cpLen);

% Equalize data subcarriers
rxData = rxGrid(dataSCpos, :);
hData = hEst(dataSCpos, :);
[eqData, csi] = ofdmEqualize(rxData, hData(:), nVarEst, Algorithm="mmse");

% Demodulate
demodData = pskdemod(eqData, M, OutputType="integer");
[~, ber] = biterr(data(:), demodData(:));
```

## Pre-R2026a Pilot-Based Estimation (LS + Interpolation)

When `ofdmChannelEstimate` is not available, estimate the channel from received pilots using LS estimation and interpolate to **all active subcarrier positions** (not just data). This makes the estimate compatible with `ofdmEqualize`.

```matlab
% Extract received pilots
symOffset = cpLen;
[rxData, rxPilots] = ofdmdemod(rxSig, nFFT, cpLen, symOffset, nullIdx, pilotIdx);

% Known pilots
txPilots = pskmod(zeros(length(pilotIdx), nSym), 4, InputType="integer");

% LS estimate at pilot positions
H_pilots = rxPilots ./ txPilots;  % [nPilots x nSym]

% Interpolate to ALL active subcarrier positions (data + pilots)
activeIdx = setdiff((1:nFFT).', nullIdx);
pilotPos = find(ismember(activeIdx, pilotIdx));
allPos = (1:length(activeIdx)).';  % all active SC positions

H_all = zeros(length(activeIdx), nSym);
for sym = 1:nSym
    H_all(:, sym) = interp1(pilotPos, H_pilots(:, sym), allPos, 'linear', 'extrap');
end

% Equalize data subcarriers using ofdmEqualize
dataPos = find(~ismember(activeIdx, pilotIdx));
H_data = H_all(dataPos, :);
nVar_sc = nVar_td * nFFT;  % per-subcarrier noise variance
[eqData, ~] = ofdmEqualize(rxData, H_data(:), nVar_sc, Algorithm="mmse");
```

**Key points:** Interpolate on complex H values (not magnitude/phase separately). Always interpolate to all active positions first, then extract the data rows for `ofdmEqualize`.

Copyright 2026 The MathWorks, Inc.
