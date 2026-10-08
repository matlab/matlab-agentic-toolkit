# Threshold Calibration — Sub-Workflow

Calibration sub-procedure for `energyDetector` (`plotDetectionSignals`) and `preambleDetector` (`plotThreshold`). Load this file when the parent skill (`matlab-detect-capture-usrp`) routes a calibration request, or when a generated Pattern fires unreliably (timeouts despite a real signal, false positives on noise, captures of pure baseline, or `status=1` with garbage data).

## When to Apply This Sub-Workflow

Route in when **any** of these failure modes are observed:

| Failure mode | Symptom | Sub-workflow handles |
|--------------|---------|---------------------|
| **No detection** | `status == 0` (capture timed out, no data) when a signal was expected | Step 1: read `plotDetectionSignals` or `plotThreshold` figure to check whether thresholds are above peaks (false negative) or whether the RF path is dead |
| **Wrong detection** | `status >= 1` but captured data is noise, baseline, saturated (`max(abs(data))` near `1.414`), or sanity ratio fails (ED: `r < 50`; PD: `r < 100`) | Step 4: post-capture sanity check; falls back to Step 3 false-positive recovery |
| **Unstable detection** | Same Pattern fires inconsistently across 5 consecutive runs (sometimes `status=0`, sometimes `status=1`) | Step 3: add ≥6 dB margin to whichever threshold is on the boundary |
| **Explicit calibration request** | User says "calibrate", "tune thresholds", "tune detection", "fix detection", "why didn't it detect", "diagnose", or names `plotDetectionSignals` / `plotThreshold` | Whichever step matches the symptom they describe |

Do NOT apply when:
- The RF path itself is unverified (no cable / wrong antenna / wrong frequency / wrong gain). Calibration cannot fix RF problems — exit and fix the path first. (Step 1 will detect this when neither curve has any peaks.)
- The user is only generating new code and has not yet run it. Generate the Pattern, run it, then route in here only on a failure outcome.

## Pre-Conditions

| Required | Why |
|----------|-----|
| Detector object already created and configured | Calibration reads back live curves from the radio |
| TX is running (or a known external signal present) | Both `plotDetectionSignals` and `plotThreshold` need a signal to plot against |
| RF path proven (Pattern B fixed-threshold caught at least one signal previously) | Distinguishes "threshold problem" from "RF problem" |

## Sub-Workflow A: energyDetector Calibration (Patterns A / B / E / F)

`energyDetector` has two thresholds (`MinimumEnergy` absolute floor + `EnergyDeltaThreshold` relative dB ratio). Both must clear, so calibration tunes whichever knob the figure shows is blocking.

### Step 0 — Measure the real energy scale first

Absolute energy is radio-, gain-, and signal-specific. On an N310 SMA loopback the integrated energy (window 300) measured **≈ 6e-5 at RadioGain 30, ≈ 3e-4 at 45, ≈ 0.01 at 60, ≈ 0.1 at 70** — orders of magnitude below the OTA example values, and it never reaches ~4. `RadioGain` scales signal and noise together, so it does not improve SNR; `TransmitGain` does.

So do not hardcode `MinimumEnergy` / `FixedThreshold`. Read the real level once, then set from it:

Set `ThresholdMethod` **before** transmission starts — switching fixed<->adaptive during a
continuous transmission errors ("stop the ongoing transmission first"). If TX is already running,
call `stopTransmission(ed)` first, set the method, then transmit again.

```matlab
% 1. Set the method BEFORE transmitting (see the SKILL.md Always rule).
ed.ThresholdMethod = "fixed";
ed.FixedThreshold = 1e-9;                          % tiny -> triggers immediately

% 2. Start TX now (Pattern F), or confirm the external signal is on the air.

% 3. Grab one reference capture. Guard it: a timeout returns empty data.
[x, ~, ~, status] = capture(ed, milliseconds(3), seconds(2));
if status >= 1 && ~isempty(x)
    if iscell(x)                                   % NumCaptures > 1 returns a cell array
        x = x{1};
    end
    peakEnergy = max(movsum(abs(double(x)).^2, ed.WindowLength));  % same units as the thresholds
    ed.FixedThreshold = 0.3 * peakEnergy;          % fixed: ~1/4-1/2 of the measured peak
else
    warning("Reference capture timed out - no energy to measure. Check the RF path (Step 1) first.");
end
```

Adaptive alternative — also set it before transmitting: `ed.ThresholdMethod = "adaptive"` with
`ed.MinimumEnergy = 0`, and let `EnergyDeltaThreshold` (dB rise) trigger. That is scale-invariant,
so it needs no reference capture at all.

Prefer adaptive over loopback: the dB-rise trigger fires whatever the absolute scale, so you avoid chasing a moving absolute threshold.

### Step 1 — Always: Read the curves

With signal present (or TX running for transmit-then-detect):

```matlab
plotDetectionSignals(ed, milliseconds(2));
```

Read off the figure:

| Observation | Interpretation |
|-------------|----------------|
| `Integrated Signal Energy` curve does not touch `Minimum Energy Threshold` line | MinE too high -> false negative |
| `Energy Delta` curve never crosses `Energy Delta Threshold`, but shows clear **positive** peaks | Delta too high -> false negative (real signal, threshold sits above it) |
| `Energy Delta` swings roughly **symmetrically about 0** (e.g. ±1.4 dB) with flat `Integrated Signal Energy` | **Noise jitter, not a weak signal.** Do NOT lower the threshold — you will fire on noise. On a loopback with no transmitter the cable is passive (nothing arrives): switch to transmit-then-detect (Pattern F). |
| Neither curve has any peaks | RF path issue (cable / antenna / gain / frequency, **not** threshold) — exit this sub-workflow |

### Step 2 — False-negative recovery

First rule out noise jitter (Step 1: a symmetric Delta swing about 0 is noise, not a weak signal — do not chase it down; over a passive loopback go straight to transmit-then-detect). Then halve whichever knob the figure shows is blocking.

- **`MinimumEnergy`**: set to **0** and let `EnergyDeltaThreshold` trigger (the absolute energy is tiny and gain-dependent — see Step 0). If a floor is needed to reject noise jitter, measure the signal energy first and set the floor below it — do not hardcode a decade value
- **`EnergyDeltaThreshold`** in dB progression: `3 -> 1.5 -> 0.5` dB until the Delta curve crosses threshold

### Step 3 — False-positive recovery

- Raise `EnergyDeltaThreshold` x2: `3 -> 6 -> 12` dB until threshold sits well above the noise band's natural jitter
- Raise `MinimumEnergy` one decade if noise leaks through: `1e-6 -> 1e-4 -> 1e-2`
- Leave **at least 6 dB of Delta margin** between observed signal Delta and chosen threshold — the boundary is jittery

### Step 4 — Post-capture sanity

After a successful capture:

```matlab
if iscell(data)          % NumCaptures > 1 returns a cell array - score one capture
    data = data{1};
end
r = max(abs(data).^2) / median(abs(data).^2);
```

| Ratio | Verdict |
|-------|---------|
| `r >= 50` | Real signal — calibration is good |
| `r < 50` | Likely false positive (caught noise, not signal) — raise Delta or MinE and re-run **— unless the signal is wideband, see below** |

> **Wideband / chirp exception.** A wideband, low-duty-cycle signal (e.g. a `chirp`) spreads its energy over time, so the raw `max/median` ratio under-reports — `r ≈ 15–20` is normal for a *real* chirp and is **not** a false positive. For such signals the authoritative check is a matched filter against one period of the known transmit template:
>
> ```matlab
> template = knownPeriod / norm(knownPeriod);   % one period of the TX waveform (e.g. the chirp)
> mf = abs(filter(conj(flipud(template)), 1, data));
> mfRatio = max(mf).^2 / median(mf).^2;         % real wideband signal: >> 100 (noise: ~1)
> ```
>
> Trust the matched-filter ratio for chirps/wideband; do **not** re-tune the threshold on a low raw `r` alone, and do **not** launch a multi-run investigation — one confirming capture plus this matched-filter check is enough.

## Sub-Workflow B: preambleDetector Calibration (Patterns C / D / G)

`preambleDetector` triggers when correlator output power exceeds `AdaptiveThresholdGain * avgPower + AdaptiveThresholdOffset` (adaptive) or `FixedThreshold` (fixed).

### Step 1 — Always: Read the threshold curve

With TX running (or external signal present):

```matlab
plotThreshold(pd, milliseconds(1));
```

Read off the figure:

| Observation | Interpretation |
|-------------|----------------|
| Correlation peaks visible AND threshold curve sits above peaks | Gain too high -> false negative |
| Correlation peaks visible AND threshold curve sits below noise band | Gain too low -> false positive |
| No correlation peaks at all | RF path issue — exit this sub-workflow |

### Step 2 — False-negative recovery

Halve `AdaptiveThresholdGain` until the threshold curve drops below the correlation peaks but stays above the noise band:

```
8 -> 4 -> 2 -> 1 -> 0.5
```

### Step 3 — False-positive recovery

- Raise `AdaptiveThresholdGain` x2 progression until the threshold curve clears the noise band
- If margin remains tight, add a small `AdaptiveThresholdOffset` (start `0.1`)

### Step 4 — Post-capture sanity

After a successful capture:

```matlab
if iscell(data)          % NumCaptures > 1 returns a cell array - score one capture
    data = data{1};
end
matched = filter(conj(flipud(pd.Preamble)), 1, data);
peak = max(abs(matched).^2);
base = median(abs(matched).^2);   % median is base MATLAB - no extra toolbox needed
r = peak / base;
```

| Ratio | Verdict |
|-------|---------|
| `r > 100` | Real preamble fire |
| `50 <= r <= 100` | Marginal — real fire but tight; consider raising Gain |
| `r < 50` | Likely false positive (caught noise, not preamble) — raise Gain or add Offset and re-run |

Diagnostic rule of thumb: real preamble fires sit `peak/baseline > 100`; false positives cluster around 17.

## Symptom -> Cause -> Fix (combined ED + PD)

| Symptom | Likely cause | First diagnostic | Fix |
|---------|--------------|------------------|-----|
| `status=0` always (timeout, PD) | Threshold above peak (Gain too high) or RF path dead | `plotThreshold` | Correlation peaks visible but no trigger markers -> halve Gain (`8 -> 4 -> 2 -> 1 -> 0.5`). No peaks at all -> check antennas, gains, frequency, cable. |
| `status=1` but data is noise (PD) | Gain too low, fired on baseline | Offline `peak/baseline` ratio after capture | Ratio `< 50` -> raise Gain x2 or add small Offset (start `0.1`). |
| `status=1` but `max\|data\|` ~= 1.414 | RX saturated (RadioGain too high or TX too strong) | `max(abs(data))` check | Reduce RadioGain by 10-20 dB. Loopback ceiling is `RadioGain=60` dB at `TxGain=50` dB. |
| Adaptive `Gain=8` always times out over loopback | Quiet baseline -> `8 * ~0` collapses to Offset; peaks are also small | Loopback sweep evidence | Use `Gain=0.5, Offset=0` for loopback (working window `0.1-0.9`, sharp boundary at `1.0`). |
| OTA `Gain=0.5` constant false positives | Real noise floor lifts moving avg; `0.5 * avg` sits below peaks | `plotThreshold` shows triggers in non-signal regions | Raise Gain to `4-16` OTA range; add Offset `0.1-0.5` if margin tight. |
| ED `status=0` always (Pattern A/E/F) | MinE > integrated energy OR Delta > observed peak ratio OR RF path dead | `plotDetectionSignals(ed, milliseconds(2))` | Energy curve doesn't touch MinE line -> halve MinE (decade). Delta curve never crosses Delta threshold -> halve Delta (`3 -> 1.5 -> 0.5` dB). Neither curve has peaks -> RF path issue. |
| ED `status=1` but data is noise | Delta too low + tiny MinE -> baseline jitter cleared | Offline `r = max(abs(data).^2) / median(abs(data).^2)` | If `r < 50`, raise Delta x2 (`3 -> 6 -> 12` dB) or raise MinE one decade. |
| ED weak-signal jittery boundary | Living on FN edge of `EnergyDeltaThreshold` | Run capture 5x and count fires; if non-deterministic | Add `6+` dB Delta margin: if observed Delta is 22 dB, set threshold to `12-15` dB. |

## Tool Restrictions (from parent skill guardrails)

- `plotDetectionSignals` is for `energyDetector` ONLY — never call on a `preambleDetector`
- `plotThreshold` is for `preambleDetector` ONLY — never call on an `energyDetector`

## Exit Criteria

**Calibrate in a single pass, then STOP.** Do not re-run the full sweep chasing a perfect score, and do not re-execute the deliverable to "double-check" — over a quiet loopback the trigger boundary is naturally jittery, and every extra radio round-trip costs real seconds. Chasing a flawless run is the main cause of calibration timeouts.

Calibration is COMPLETE — return to the parent skill with the calibrated values — as soon as, in one pass:

- The relevant figure shows the threshold curve sitting between the noise band and the signal peaks, AND
- **One** test capture returns `status == 1` and the post-capture check passes: the sanity ratio `r` clears the threshold (`>= 50` for ED, `> 100` for PD), **or** — for a wideband chirp/OFDM signal — the matched-filter ratio confirms the signal (Step 4). That single confirming capture is enough evidence.

Then STOP. Once that confirming capture has fired:

- Do **not** re-run the full deliverable end-to-end again "to confirm" — the calibration capture already proved it fires. The deliverable is the calibrated parameter values, not one more live run.
- Do **not** re-open `plotDetectionSignals` / `plotThreshold` after success.
- A determinism check (repeating the capture 3-5 times) is **optional** — run it only if you actually saw inconsistent firing. If you do, a single boundary miss (e.g. 4/5) over a marginal loopback is acceptable: accept it, or apply **one** margin step (ED: raise `EnergyDeltaThreshold` by 6 dB; PD: set `AdaptiveThresholdOffset = 0.1`) and stop. Do NOT keep re-sweeping toward a perfect 5/5. For a wideband signal the matched-filter check already confirms a real detection — do not also run a determinism sweep.

Return to the parent skill (`matlab-detect-capture-usrp`) Pattern code with the calibrated parameter values.

----

Copyright 2026 The MathWorks, Inc.

----
