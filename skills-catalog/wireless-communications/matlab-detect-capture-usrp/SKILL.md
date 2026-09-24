---
name: matlab-detect-capture-usrp
description: Smart triggered RF capture on NI USRP radios with Wireless Testbench — record only when a signal of interest appears, not continuously (triggered spectrum sensing). Use energy detection to capture when signal power rises above the noise floor, or preamble detection to cross-correlate against a known sequence (WLAN L-LTF, 5G NR PSS/SSS, LTE PSS, Zadoff-Chu, custom protocols) and capture only when that protocol's preamble is detected. Use when implementing triggered (wake-on-signal) capture or spectrum sensing, capturing protocol-based signals via cross-correlation, calibrating detection thresholds (plotDetectionSignals / plotThreshold), scanning frequency bands for activity, or building transmit-then-detect workflows.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Detect and Capture RF Signals on NI USRP Radios

## Reference Loading
- **Code patterns (required at Step 4):** for the seven copy-ready capture patterns (A–G) and the loopback table, `Read references/patterns.md` before generating any capture code.
- For API signatures, property ranges, and threshold constraints: `Read references/api.md`
- For conceptual architecture and detector behavior: `Read references/overview.md`
- For the threshold calibration sub-workflow (`plotDetectionSignals` / `plotThreshold` step-by-step): `Read references/threshold-calibration.md`
- Load the api / overview / calibration references only when generating code that requires specific parameter values, constraints, or tuning.

## Sub-Workflows

This skill exposes one sub-workflow that is loaded on demand from `references/`:

| Sub-workflow | What it provides |
|--------------|------------------|
| **Threshold Calibration** (`references/threshold-calibration.md`) | Step-by-step plot -> diagnose -> tune procedure for both `energyDetector` and `preambleDetector`, plus combined symptom -> cause -> fix table |

### Trigger: when to route into Threshold Calibration

Route into `references/threshold-calibration.md` whenever **any** of these conditions hold:

1. **No detection** — generated Pattern returned `status == 0` (capture timed out, no data captured) and the user expected a signal to fire it. This is the primary trigger.
2. **Wrong detection** — Pattern returned `status >= 1` but the captured data is wrong: noise instead of signal, baseline instead of preamble, saturated waveform (`max(abs(data))` near `1.414`), or sanity ratio fails (`r < 50` for energyDetector, `r < 100` for preambleDetector).
3. **Unstable detection** — Pattern fires inconsistently across consecutive runs (sometimes `status=0`, sometimes `status=1`); thresholds are sitting on a jittery boundary.
4. **User explicitly asks** to "calibrate", "tune thresholds", "tune detection", "fix detection", "why didn't it detect", "diagnose", or names `plotDetectionSignals` / `plotThreshold`.

Do **not** route into the sub-workflow for first-time code generation — generate the Pattern from this SKILL.md, run it, and only route into calibration on a failure outcome. The sub-workflow assumes a detector object is already configured and a TX or external signal is present.

If the failure mode is RF-path (no peaks at all on the figure, wrong frequency, broken cable, wrong antenna name), the sub-workflow exits early back to this skill — calibration cannot fix RF problems.

Generate working MATLAB code to detect and capture RF signals using energy detection or preamble detection triggers on NI USRP radios with Wireless Testbench.

## Prerequisites

Before this skill applies, the user must have:
- MATLAB R2022a+ (preambleDetector) or R2023b+ (energyDetector)
- Wireless Testbench toolbox installed
- Wireless Testbench Support Package for NI USRP Radios installed
- Radio previously configured using the Radio Setup wizard
- Physical NI USRP radio connected and validated

## When to Use

Trigger this skill when the user wants smart/triggered capture — record only when something interesting appears on the air, not continuously:

- Capture only when signal energy rises above the noise floor (`energyDetector`, Patterns A/B/E/F) — wake-on-signal recording, opportunistic capture, transmit-then-detect verification
- Capture only when a known protocol preamble is cross-correlated and matched (`preambleDetector`, Patterns C/D/G) — WLAN L-LTF, 5G NR PSS/SSS, LTE PSS, Zadoff-Chu, custom sync sequences
- Calibrate detection thresholds (`plotDetectionSignals` for energyDetector, `plotThreshold` for preambleDetector)
- Scan multiple frequencies / channels for activity (e.g., WLAN channel scan across 2.4 GHz band)
- Transmit a test waveform from the same radio and capture it back upon detection (loopback verification)
- Capture multiple consecutive triggered signals with sample-clock timestamps

## When NOT to Use

Route to another skill if the user's goal is:
- **Untriggered capture** (immediate IQ capture without detection) -> `matlab-transmit-capture-usrp`
- **Continuous streaming** (System objects, real-time processing loops) -> use the `matlab-read-documentation` skill for "Live Data I/O" (Wireless Testbench)
- **Radio setup or troubleshooting** -> `matlab-set-up-usrp-radio`
- **Clock/time synchronization** -> use the `matlab-read-documentation` skill for "Radio Management" (Wireless Testbench)
- **FPGA targeting** -> use the `matlab-read-documentation` skill for "Target NI USRP Radios" (Wireless Testbench)

## Decision Tree

```
User request
|
|-- Mentions "untriggered capture", "immediate capture", "basebandReceiver"
|     -> REDIRECT to matlab-transmit-capture-usrp
|
|-- Mentions "System object", "streaming loop", "real-time processing"
|     -> REDIRECT: use matlab-read-documentation for "Live Data I/O" (Wireless Testbench streaming)
|
|-- Wants triggered capture (detection-based)
|     |
|     |-- Knows signal structure (preamble sequence available)
|     |     |-- Adaptive threshold -> Pattern C
|     |     |-- Fixed threshold -> Pattern D
|     |     |-- Wants to calibrate threshold -> Pattern D + plotThreshold
|     |     |-- Frequency scanning loop -> Pattern G
|     |
|     |-- Explicit energy/power cue (energy rise, power increase), no preamble
|     |     |-- Adaptive threshold (energy delta + minimum) -> Pattern A
|     |     |-- Fixed threshold -> Pattern B
|     |     |-- Wants to calibrate threshold -> Pattern A/B + plotDetectionSignals
|     |     |-- Multiple captures with timestamps -> Pattern E
|     |     |-- Transmit-then-detect workflow -> Pattern F
|     |
|     |-- Ambiguous: no energy/power cue, no preamble, no parameters given
|           -> ASK FIRST (do not assume energy): "Do you have a known preamble
|              sequence to correlate against, or do you want to trigger on any
|              signal energy increase? Also, what threshold values or detection
|              parameters would you like to use?"
```

## Code Generation Steps

### Key Functions

| Function | Purpose | Toolbox | Available From |
|----------|---------|---------|----------------|
| `energyDetector` | Arm radio; trigger capture when energy rises above the noise floor | Wireless Testbench | R2023b |
| `preambleDetector` | Arm radio; trigger capture on correlation with a known preamble | Wireless Testbench | R2022a |
| `capture` | Blocking triggered IQ capture (returns on detection or timeout) | Wireless Testbench | with detector object |
| `capture(..., "NumCaptures", N)` | Capture N consecutive triggered signals (Pattern E) | Wireless Testbench | R2024a |
| `plotDetectionSignals` | Calibrate energy threshold — energyDetector only | Wireless Testbench | R2023b |
| `plotThreshold` | Calibrate preamble threshold — preambleDetector only | Wireless Testbench | R2022a |
| `transmit` / `stopTransmission` | Send / stop a test waveform on the detector object (Pattern F) | Wireless Testbench | with detector object |
| `zadoffChuSeq` | Generate a Zadoff-Chu preamble sequence (Patterns C/D) | Communications Toolbox | R2012b |
| `wlanLLTF` / `wlanNonHTConfig` | Build the WLAN L-LTF preamble (Pattern G) | WLAN Toolbox | R2015b |
| `chirp` | Generate a test chirp waveform (Pattern F) | Signal Processing Toolbox | before R2006a |

### Step 1: Determine Detector Type

Select on an **explicit cue**, not on the mere absence of a preamble.

| Signal | User says | Detector |
|--------|-----------|----------|
| Energy-based | explicit energy/power cue: "energy", "power increase/rise", "amplitude above the noise floor" | `energyDetector` |
| Preamble-based | "preamble", "Zadoff-Chu", "L-LTF", "PSS/SSS", "correlation", a known sequence | `preambleDetector` |
| Ambiguous | only "detect a signal" / "capture when it appears" — no energy/power cue, no preamble, no threshold parameters | **Ask first** (Guardrails -> Ask First); do not default to energy |

### Step 2: Gather Required Inputs

| Parameter | Required | Ask if missing |
|-----------|----------|----------------|
| Radio name | Yes | Always |
| Center frequency | Yes | Yes |
| Sample rate | Yes | Yes |
| Threshold method | Yes | Yes (adaptive/fixed) |
| Threshold values | Yes | Yes |
| Capture duration | Yes | Yes |
| Timeout | Yes | Default seconds(1) if not specified |
| Preamble sequence | Only for preambleDetector | Yes |

### Step 3: Validate Constraints

Check parameter values against valid ranges before generating code. See `references/api.md` for complete constraint tables (WindowLength, FixedThreshold, Preamble length, TriggerOffset, AdaptiveThresholdGain, AdaptiveThresholdOffset).

If a value violates these constraints, inform the user and suggest the valid range. Do NOT generate code with invalid values.

### Step 4: Generate Code

The seven copy-ready patterns (A–G) live in `references/patterns.md`. **`Read references/patterns.md` now**, then use the pattern the Decision Tree selected. Each pattern ships with concrete default values — replace the values marked `% <- set` with the user's radio and signal parameters, and validate them against the `references/api.md` ranges (Step 3) before running. For loopback bring-up (transmit-then-detect), follow the Local Hardware Testing table in that file.

| Pattern | Detector | Threshold | Use case |
|---------|----------|-----------|----------|
| A | `energyDetector` | adaptive | Wake-on-signal capture on an energy rise |
| B | `energyDetector` | fixed | Capture above a fixed power level |
| C | `preambleDetector` | adaptive | Capture on correlation with a known preamble |
| D | `preambleDetector` | fixed | Preamble capture / `plotThreshold` calibration |
| E | `energyDetector` | adaptive | Multiple consecutive captures with timestamps |
| F | `energyDetector` | adaptive | Transmit-then-detect (loopback) |
| G | `preambleDetector` | adaptive | Frequency-scanning loop (WLAN channel scan) |

If a generated pattern fires unreliably (timeout despite a real signal, false positives, or captures of noise/baseline), route into the threshold calibration sub-workflow — see the per-pattern calibration notes in `references/patterns.md` and the procedure in `references/threshold-calibration.md`.

## Guardrails

Organized by when they apply: **Always** rules fire on every generation, **Ask First** rules pause for the user, **Never** rules trigger a refusal and redirect.

### Always
- **Use a `radioName` variable from user input** — never hardcode radio names.
- **Begin every pattern with `clear ed pd`** — releases any prior radio lease regardless of detector class. The same physical radio can be held by either an `energyDetector` or a `preambleDetector` object; clearing only one variable name does not release a lease held by the other, which causes `validateLeaseOwner` errors when patterns are pasted sequentially into the same MATLAB session.
- **Validate threshold ranges before generating code** — see `references/api.md` for exact valid ranges per parameter (key: energyDetector `FixedThreshold` [0, 8191], preambleDetector `FixedThreshold` [0, 4095]). If a value is out of range, state the valid range and do not emit the code.
- **End every generated code block with a `%% Verify` section** that reports the outcome. Do NOT hard-`assert` on `status`: a timeout (`status == 0`) is an expected result to handle (warn + route to calibration), not a crash — a hard assert makes a no-signal bench run throw.
- **Stop after the first successful capture — do not re-run to "confirm."** Once a capture returns `status == 1` and the `%% Verify` sanity check passes (or, for a wideband chirp/OFDM signal, the matched-filter check confirms it), the task is done. Do NOT execute the full deliverable again end-to-end or re-open `plotDetectionSignals` / `plotThreshold` to double-check — each extra radio round-trip costs real seconds and risks a timeout.
- **Use `transmit()` / `stopTransmission()` on the detector object** for transmit-then-detect — do NOT create a separate `basebandTransmitter`.
- **Set `ThresholdMethod` before calling `transmit()`** — you cannot switch fixed↔adaptive during a continuous transmission (it errors: "stop the ongoing transmission first"). `MinimumEnergy`, `EnergyDeltaThreshold`, and `FixedThreshold` *can* be tuned live, so sweep those without stopping.
- **Match the calibration plot to the detector class** — `plotDetectionSignals` is energyDetector-only; `plotThreshold` is preambleDetector-only. Never cross them.
- **Normalize any custom or random preamble into [-1, 1] before assigning `pd.Preamble`.** `Preamble` elements must lie in [-1, 1] (`references/api.md`). Zadoff-Chu via `seq / norm(seq, 2)` already satisfies this; for a random or protocol-derived sequence, scale it with `preamble = preamble / max(abs(preamble))` — raw `randn`/sample values overflow [-1, 1] and error at assignment.

### Ask First
- **When the detection method is unstated, ask before generating — do not default to energy detection.** The absence of a preamble in the request is *not* evidence for energy detection. If the request names no explicit energy/power cue, no preamble/correlation sequence, and no threshold parameters, ask **one** question covering both the method (energy vs. preamble) and its parameters, then proceed. If the method is clear and only parameters are missing, ask once for those.

### Never
- **Never generate untriggered capture** — if the user wants immediate capture without detection, redirect to `matlab-transmit-capture-usrp`.
- **Never generate streaming code** — if the user wants continuous real-time processing, redirect to the streaming workflow (use the `matlab-read-documentation` skill for "Live Data I/O", Wireless Testbench).

----

Copyright 2026 The MathWorks, Inc.

----
