# Fading Channel for OFDM — Reference

## Must-Follow Rules

1. **Always set `SampleRate`** — default is 1 Hz. With realistic Doppler (e.g., 100 Hz), the constraint `MaximumDopplerShift <= SampleRate/10` will fail. Set `SampleRate = nFFT * subcarrierSpacing`.
2. **Enable `PathGainsOutputPort=true`** — required for `ofdmChannelResponse`. Use this for perfect channel estimation and equalization as a simulation baseline.
3. **Use `ofdmChannelResponse` for per-subcarrier H** — do NOT manually compute `H = fft(h, nFFT)`. `ofdmmod` uses `ifftshift` internally, so manual FFT gives wrong subcarrier mapping (silent error, degraded BER).
4. **Use explicit signal power in `awgn` after fading, NEVER `'measured'`** — fading changes instantaneous power, but thermal noise floor is fixed. `'measured'` artificially adjusts noise to track fading — physically wrong.

## Channel Object Configuration

### comm.RayleighChannel (all NLOS paths)

```matlab
channel = comm.RayleighChannel( ...
    SampleRate=1e6, ...
    PathDelays=[0 1e-6 2e-6], ...      % seconds
    AveragePathGains=[0 -3 -6], ...     % dB
    MaximumDopplerShift=50, ...
    PathGainsOutputPort=true);           % CRITICAL for equalization

[fadedSig, pathGains] = channel(txSig);
pathFilters = info(channel).ChannelFilterCoefficients;
```

### comm.RicianChannel (LOS + scattered)

```matlab
channel = comm.RicianChannel( ...
    SampleRate=1e6, ...
    PathDelays=[0 1e-6], ...
    AveragePathGains=[0 -5], ...
    KFactor=10, ...                     % LOS/scattered ratio (linear, NOT dB)
    DirectPathDopplerShift=0, ...
    DirectPathInitialPhase=0, ...
    MaximumDopplerShift=50, ...
    PathGainsOutputPort=true);
```

**KFactor gotchas:**
- Applies to first path only (scalar) or per-path (vector matching PathDelays)
- `KFactor=0` is NOT allowed — use `comm.RayleighChannel` instead
- When vector, `DirectPathDopplerShift` and `DirectPathInitialPhase` must also be vectors

### When to use Rician vs Rayleigh

- **Rayleigh** — no line-of-sight: urban NLOS, indoor obstructed, rich scattering
- **Rician** — line-of-sight exists: rural, rooftop-to-rooftop, satellite, short-range LOS

## Key Properties

| Property | Default | Description |
|----------|---------|-------------|
| `SampleRate` | 1 | Input signal sample rate (Hz). **Always set.** |
| `PathDelays` | 0 | Row vector of path delays in seconds |
| `AveragePathGains` | 0 | Path gains in dB (scalar when single path, vector matching length of PathDelays) |
| `MaximumDopplerShift` | 0.001 | Max Doppler (Hz). Must be <= SampleRate/10 |
| `PathGainsOutputPort` | false | Set `true` for equalization |
| `NormalizePathGains` | true | Normalize so linear sum = 1 (preserves power) |
| `DopplerSpectrum` | `doppler('Jakes')` | Jakes, Flat, Bell, Gaussian, etc. |
| `RandomStream` | `'Global stream'` | `'mt19937ar with seed'` for reproducibility |
| `Seed` | 73 | Seed when using mt19937ar |

### Key methods

| Method | Description |
|--------|-------------|
| `[y, pg] = ch(x)` | Filter signal, get path gains |
| `info(ch)` | Returns ChannelFilterCoefficients, ChannelFilterDelay |
| `reset(ch)` | New realization (global stream) or restore initial state (seeded stream) |

## Computing Doppler from Velocity

```matlab
c = physconst("LightSpeed");  % 299792458 m/s
fc = 2.4e9;                    % carrier frequency (Hz)
v_kmh = 120;                   % velocity (km/h)
fd = (v_kmh / 3.6) * fc / c;  % max Doppler shift (Hz)
% 120 km/h at 2.4 GHz → fd ≈ 267 Hz
```

| Carrier | 30 km/h | 60 km/h | 120 km/h |
|---------|---------|---------|----------|
| 900 MHz | 25 Hz | 50 Hz | 100 Hz |
| 2.4 GHz | 67 Hz | 133 Hz | 267 Hz |
| 3.5 GHz | 97 Hz | 195 Hz | 389 Hz |
| 28 GHz | 778 Hz | 1557 Hz | 3113 Hz |

## Path Delay Constraint for OFDM

Maximum path delay must be less than CP duration, otherwise ISI corrupts the signal:

```matlab
maxDelay = max(pathDelays);          % seconds
cpDuration = cpLen / sampleRate;     % seconds
assert(maxDelay < cpDuration, 'Max path delay exceeds CP — ISI will occur')
```

## ofdmChannelResponse

```matlab
H = ofdmChannelResponse(pathGains, pathFilters, nFFT, cpLen, activeIdx)
H = ofdmChannelResponse(pathGains, pathFilters, nFFT, cpLen, activeIdx, timingOffset)
```

- `pathGains` — from channel second output `[Nsamp x Npaths]` (SISO)
- `pathFilters` — from `info(channel).ChannelFilterCoefficients` `[Npaths x Ncoeff]`
- `activeIdx` — `setdiff((1:nFFT).', nullIdx)` — column vector of active subcarrier indices
- `timingOffset` — from `channelDelay(pathGains, pathFilters)` (default 0)
- **Returns** — `[nActiveSC x nOFDMSym]` (SISO)

Introduced R2023a.

## ofdmEqualize

```matlab
[eqSym, csi] = ofdmEqualize(rxSym, H, nVar)
[eqSym, csi] = ofdmEqualize(rxSym, H, nVar, Algorithm="mmse")
```

- `H` dimension rules (DataFormat="3-D", default):
  - `[nSC x Ns x Nr]` — static (same H for all symbols)
  - `[(nSC*nSym) x Ns x Nr]` — time-varying (use `reshape(H, [], Ns, Nr)`)
  - **NEVER pass `[nSC x nSym]`** — dim 2 is interpreted as Tx streams, giving `[nSC x nSym x nSym]` output (silent wrong result)
- `nVar` — noise variance per subcarrier (linear)
- `csi` — channel state information (reliability weights for soft decoding)

Introduced R2022b.

## 3GPP Delay Profiles

| Profile | Paths | Max Delay | Use Case |
|---------|-------|-----------|----------|
| EPA | 7 | 410 ns | Low delay spread (indoor, small cell) |
| EVA | 9 | 2.51 μs | Medium delay spread (urban) |
| ETU | 9 | 5.0 μs | High delay spread (large cell) |

```matlab
% EPA (Extended Pedestrian A)
epa.delays = [0 30 70 90 110 190 410] * 1e-9;
epa.gains  = [0 -1 -2 -3 -8 -17.2 -20.8];

% EVA (Extended Vehicular A)
eva.delays = [0 30 150 310 370 710 1090 1730 2510] * 1e-9;
eva.gains  = [0 -1.5 -1.4 -3.6 -0.6 -9.1 -7.0 -12.0 -16.9];

% ETU (Extended Typical Urban)
etu.delays = [0 50 120 200 230 500 1600 2300 5000] * 1e-9;
etu.gains  = [-1 -1 -1 0 0 0 -3 -5 -7];
```

For 5G NR channel models (TDL, CDL), use `nrTDLChannel`/`nrCDLChannel` from 5G Toolbox.

## Quasi-Static Fading (Block Fading)

Set `MaximumDopplerShift=0` for a channel that stays constant within one call (one frame):

```matlab
channel = comm.RayleighChannel(SampleRate=1e6, ...
    PathDelays=[0 1e-6], AveragePathGains=[0 -3], ...
    MaximumDopplerShift=0, PathGainsOutputPort=true, ...
    RandomStream="mt19937ar with seed", Seed=42);
```

With `MaximumDopplerShift=0`, the channel is constant (quasi-static) — repeated calls to `channel(x)` return the **same** fading realization. Calling `reset(channel)` draws a **new** random realization (with the global stream) or restores the **original** realization (with a seeded stream).

**To simulate multiple independent frames with quasi-static fading (fastest approach):**

```matlab
% Use global stream (NOT seeded) so reset() gives a new realization each time
channel = comm.RayleighChannel(SampleRate=1e6, ...
    PathDelays=[0 1e-6], AveragePathGains=[0 -3], ...
    MaximumDopplerShift=0, PathGainsOutputPort=true);

for frame = 1:numFrames
    reset(channel);  % New independent realization (fast)
    [fadedSig, pathGains] = channel(txSig);
    % ... process frame ...
end
```

Do NOT use `release(channel)` + seed change inside the loop — `release` rebuilds internal state and is significantly slower. Use seeded streams only if the user specifically asks for reproducibility. Even then, warn the user that `release`/set-seed inside the loop is slow. Default to the global stream for maximum run speed.

## Reproducibility

```matlab
channel = comm.RayleighChannel(SampleRate=1e6, ...
    PathDelays=[0 1e-6], AveragePathGains=[0 -3], ...
    MaximumDopplerShift=50, PathGainsOutputPort=true, ...
    RandomStream="mt19937ar with seed", Seed=42);

[y1, ~] = channel(txSig);
reset(channel);
[y2, ~] = channel(txSig);
% y1 and y2 are identical
```

## Theoretical BER over Fading (Per Subcarrier)

```matlab
EbNo = 0:2:30;
berRay = berfading(EbNo, "psk", 4, 1);        % Rayleigh, no diversity
berRic = berfading(EbNo, "psk", 4, 1, 5);     % Rician K=5
berAWGN = berawgn(EbNo, "psk", 4, "nondiff");  % AWGN reference

semilogy(EbNo, berAWGN, EbNo, berRic, EbNo, berRay);
legend("AWGN", "Rician K=5", "Rayleigh");
xlabel("Eb/No (dB)"); ylabel("BER"); grid on;
```

`berfading` takes Eb/No (not SNR), modulation type, modulation order, diversity order, and optionally K-factor (linear). In OFDM, each subcarrier experiences flat fading — these curves give the per-subcarrier BER. Convert SNR_sc to Eb/No via `convertSNR` before comparing.

Copyright 2026 The MathWorks, Inc.
