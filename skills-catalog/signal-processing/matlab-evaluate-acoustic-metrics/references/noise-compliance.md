# Noise Compliance Function Family

## Intake Questions

Before writing code, ask the user about these topics to select the right function and parameters:

### 1. What is the noise source?

| Source | Implication |
|--------|-------------|
| HVAC (fans, ducts, diffusers) | Use `roomCriteria` for spectral quality; `noiseCriteria` for compliance |
| Variable-speed drives or cycling equipment | Use `roomNoiseCriteria` — fluctuation penalty likely applies |
| General background (multiple sources) | Use `noiseCriteria` for a standard NC rating |
| Unknown / complaint investigation | Run all three methods and compare |

### 2. What is the space type?

Needed for selecting a design target. Common targets (from ANSI/ASA S12.2-2019 Tables C.1/C.2/C.3/D.2):

| Occupancy | NC/RNC Target | RC Target | A-weighted Target (dBA) |
|-----------|---------------|-----------|-------------------------|
| Concert hall / recording studio | 15–20 | RC 15–20 (N) | — |
| Courtroom / lecture hall | 25–30 | RC 25–30 (N) | 39–44 |
| Private office / conference room | 25–35 | RC 25–35 (N) | 44–48 |
| Classroom | 25–30 | RC 25–30 (N) | 35 |
| Open plan office | 35–45 | RC 35–45 (N) | 44–48 |
| Hospital patient room | 25–35 | RC 25–35 (N) | 35–39 |
| Restaurant / cafeteria | 40–45 | RC 40–45 (N) | 48–52 |

NC and RNC share the same recommendation targets — use RNC in place of NC when temporal variation is a concern. RC targets are from a separate table with different occupancy categories.

Use `noiseCriteriaRecommendations("NC")`, `noiseCriteriaRecommendations("RC")`, or `noiseCriteriaRecommendations("A-weighted")` for the full table with all occupancy types.

### 3. Is the noise steady or fluctuating?

- **Steady:** NC or RC is sufficient
- **Fluctuating (surging, throbbing, cycling):** Use `roomNoiseCriteria` — it penalizes temporal variation that NC misses. RNC ≥ NC always (RNC is stricter). If RNC significantly exceeds NC, the fluctuation is the problem.
- **Unsure:** Record ≥15 s and run both `noiseCriteria` and `roomNoiseCriteria`; compare the ratings

### 4. What is the goal?

| Goal | Approach |
|------|----------|
| Simple compliance check against spec | `noiseCriteria` → compare to target |
| Diagnose spectral problems in HVAC | `roomCriteria` → read QAI and classification |
| Investigate occupant complaints | Run all three; compare NC vs RNC for fluctuation penalty |
| Set design targets for new construction | `noiseCriteriaRecommendations` → specify in contract |
| Determine if noise affects speech | `speechInterferenceLevel` or SIL output from `noiseCriteria` |

### 5. Measurement conditions

Confirm with the user:
- **Calibration:** Do they have a calibration factor? (See main skill for conversion from dB sensitivity)
- **Recording duration:** ≥15 s recommended for `roomNoiseCriteria`. The function will error on shorter recordings if surging or large random fluctuations are detected (the correction algorithm requires 150 Lt samples at 100 ms intervals, per clause 5.3.4). Shorter recordings pass if neither condition is detected. `noiseCriteria` and `roomCriteria` have no minimum duration requirement.
- **Room conditions:** HVAC systems should be operating at normal design conditions, room unoccupied but furnished, doors/windows closed
- **Microphone position:** Ear height of typical occupant (seated ~1.2 m, standing ~1.5 m). Either measure at a specific position to be characterized, or sweep slowly throughout the space while remaining at least 0.6 m from any one surface, 1.2 m from the intersection of two surfaces, and 2.4 m from the intersection of three surfaces.

Note: these measurement conditions are for strict compliance with the standard. The functions accept any calibrated recording — the conditions affect the validity of the result, not the ability of the function to compute it.

## Function Selection

| Function | Standard | Best For | Key Outputs |
|----------|----------|----------|-------------|
| `noiseCriteria` | ANSI/ASA S12.2-2019 (NC) | General background noise assessment | NC level, SIL, spectrum imbalance, rattle risk |
| `roomNoiseCriteria` | ANSI/ASA S12.2-2019 (RNC) | Noise with audible temporal variation | RNC level, rattle risk |
| `roomCriteria` | ANSI/ASA S12.2-2019 (RC Mark II) | HVAC system noise evaluation | RC level, LMF, QAI, rattle risk |
| `speechInterferenceLevel` | ANSI/ASA S12.65-2006 | Quick speech interference check | SIL value (dB) |
| `noiseCriteriaCurves` | ANSI/ASA S12.2-2019 | Look up NC curve SPL values | SPL values at octave bands for given NC level |
| `noiseCriteriaRecommendations` | ANSI/ASA S12.2-2019 | Find target NC/RC/dBA for room type | Recommended range for specified room use |

**Plotting:** All noise compliance functions (`noiseCriteria`, `roomCriteria`, `roomNoiseCriteria`, `noiseCriteriaCurves`) produce a plot when called with no output arguments. Use this to visualize the measurement against reference curves. Encourage users to plot results for visual inspection.

## Syntax and Outputs

### noiseCriteria

Default choice for background noise assessment. Returns four outputs:

```matlab
[NC, SIL, spectrumImbalance, rattleRisk] = noiseCriteria(audioIn, fs, ...
    CalibrationFactor=calFactor);
```

- `NC` — NC level as string (e.g., `"NC-35"`)
- `SIL` — Speech interference level (average of 500/1k/2k/4k Hz bands)
- `spectrumImbalance` — Structure with `Summary` (string) and `Details` (table showing deviation from reference NC curve per band)
- `rattleRisk` — Structure with `Summary` (string) and `Details` (table showing measured levels vs. perceptibility thresholds)

Name-value arguments:
- `CalibrationFactor` — Microphone calibration factor (default: 1)
- `PressureReference` — Reference pressure in Pa (default: 20e-6)
- `ScreenSurging` — Auto-detect surging in signal (default: true). **Non-standard heuristic** — per clause 5.3.2.1, surging should be detected by the user by listening or watching a meter for oscillations in low frequencies. Use this screening as a convenience, but inform users it is not a replacement for subjective assessment.
- `ScreenLargeRandomFluctuations` — Auto-detect fluctuations (default: true). Uses the algorithmic method from the standard — users can have confidence in this screening.

Can also accept pre-computed octave-band Leq values: `noiseCriteria(Leq)` where Leq is a 1-by-10 row vector (octave bands 16 Hz to 8 kHz).

### roomCriteria

Preferred for HVAC noise specifically. The RC Mark II method adds a Quality Assessment Index (QAI) that characterizes the noise spectrum as neutral, rumbly, hissy, or vibratory:

```matlab
[RC, LMF, QAI, rattleRisk] = roomCriteria(audioIn, fs, ...
    CalibrationFactor=calFactor);
```

- `RC` — RC level as string (e.g., `"RC-32(N)"` — the letter indicates spectrum quality)
- `LMF` — Mid-frequency average (arithmetic mean of 500/1k/2k Hz octave bands)
- `QAI` — Quality Assessment Index (lower is better; 0 = ideal neutral spectrum)
- `rattleRisk` — Structure with rattle risk assessment

The spectrum quality descriptor appended to RC:
- `(N)` — Neutral: balanced spectrum, no corrections needed
- `(R)` — Rumble: excessive low-frequency energy
- `(H)` — Hiss: excessive high-frequency energy
- `(RV)` — Rumble with vibration risk

### roomNoiseCriteria

Use when the noise has audible temporal variation (surging, random fluctuations). RNC is a stricter criterion than NC — it penalizes unsteady noise. Returns 2 outputs (not 4 like `noiseCriteria`):

```matlab
[RNC, rattleRisk] = roomNoiseCriteria(audioIn, fs, ...
    CalibrationFactor=calFactor);
```

**Minimum duration:** ≥15 s recommended. The function errors on shorter recordings if surging or large random fluctuations are detected (the correction requires 150 Lt samples at 100 ms). Shorter recordings pass if neither condition is present.

Name-value arguments:
- `IsSurging` — `"auto-detect"` (default), `true`, or `false`. The surging detection algorithm is a **non-standard heuristic**. Per clause 5.3.2.1, surging should be identified by the user by listening or watching a meter for oscillations in low frequencies.
- `IsFluctuating` — `"auto-detect"` (default), `true`, or `false`. This uses the algorithmic method from the standard.

Can also accept pre-computed measurements: `roomNoiseCriteria(Leq, Lt)` where Lt is an N-by-10 matrix of fast time-weighted SPL measurements (100 ms intervals, one row per time step). Lt must use fast time-weighting.

### speechInterferenceLevel

Simplest metric for speech interference — returns just the SIL value:

```matlab
SIL = speechInterferenceLevel(audioIn, fs, CalibrationFactor=calFactor);
```

Supports time-varying output via `TimeInterval`:

```matlab
SIL = speechInterferenceLevel(audioIn, fs, ...
    CalibrationFactor=calFactor, TimeInterval=1);
```

### noiseCriteriaCurves

Look up SPL values for NC, RNC, or RC curves at standard octave-band center frequencies:

```matlab
spl = noiseCriteriaCurves("NC", CurveID=35);
spl = noiseCriteriaCurves("RNC", CurveID=[25 30 35 40]);
```

First argument is the criteria name: `"NC"`, `"RNC"`, or `"RC"` (required). `CurveID` selects specific curve levels.

The function can return values outside the published standard range (e.g., below NC-15 or above NC-70) for flexibility and implementation robustness. The standard only defines curves within its published range.

Calling with no output arguments plots the curve family. Set the `Parent` argument to place the plot axes in a desired `Axes`, `UIAxes`, or `Panel` — useful as a building block in larger visual metering displays and applications.

### noiseCriteriaRecommendations

Look up recommended noise criteria levels by occupancy/room type:

```matlab
rec = noiseCriteriaRecommendations("NC");
rec = noiseCriteriaRecommendations("RC", Occupancy="Private offices");
rec = noiseCriteriaRecommendations("A-weighted");
```

First argument is the criteria name: `"NC"`, `"RNC"`, `"RC"`, or `"A-weighted"` (required). Do NOT call with zero arguments or with a room-type string as the first argument.

## Output Types

All noise compliance functions return strings and structs — not plain numerics for the rating outputs:

| Output | Type | Example |
|--------|------|---------|
| `NC` | string | `"NC-35"` or `"NC-56 (1000 Hz)"` (band shown if one exceeds) |
| `RC` | string | `"RC-32(N)"`, `"RC-47 (H)"` (letter = spectrum quality: N/R/H/RV) |
| `RNC` | string | `"RNC-38"` |
| `SIL`, `LMF`, `QAI` | double | Scalar values in dB |
| `specImbalance` | struct or char | `.Summary` (string) and `.Details` (table) — see note below |
| `rattleRisk` | struct | `.Summary` (string) and `.Details` (table) |

To display struct outputs, access the `.Summary` field: `fprintf("Rattle: %s\n", rattleRisk.Summary)`. Do NOT pass the struct directly to `string()` or `fprintf %s`.

**Edge case:** `specImbalance` degrades to a plain `char` string (not a struct) when NC exceeds the curve range (e.g., "Above NC-70") or falls below NC-15 — spectrum imbalance is undefined in both cases. Always guard before dot-indexing:

```matlab
if isstruct(specImbalance)
    fprintf("Imbalance: %s\n", specImbalance.Summary);
else
    fprintf("Imbalance: %s\n", specImbalance);
end
```

## Input Flexibility

All noise compliance functions accept either:
- Raw audio + sample rate: `func(audioIn, fs, CalibrationFactor=cf)` — computes octave-band Leq internally
- Pre-computed octave-band Leq: `func(Leq)` — a 1-by-10 vector (16 Hz to 8 kHz octave bands)

The raw-audio method is simpler and handles all filtering/integration internally. Use the Leq method when you have measurements from a physical SPL meter or from `splMeter`.

**When providing pre-computed measurements:** The SPL meter must use Z frequency-weighting (unweighted). This applies to all noise compliance functions (NC, RNC, RC) — octave-band filtering provides the frequency selectivity, so no additional weighting should be applied. For `roomNoiseCriteria` Lt input, also use fast time-weighting.

## Interpreting Results

### NC Rating Interpretation

The NC algorithm: compute SIL (average of 500/1k/2k/4k Hz bands) → select the NC curve corresponding to that SIL value → check if any measured bands exceed that curve → if so, apply the tangency method and append the tangent frequency.

Output formats:
- `"NC-35"` — SIL-based rating; no band exceeds the SIL-selected curve
- `"NC-42 (1000 Hz)"` — Tangency method drove the rating; the noted band exceeds the SIL-selected NC curve. This indicates spectral imbalance at that frequency.
- `"Below NC-15"` or `"Above NC-70"` — Outside the published curve range

The output is always an integer NC value. When the tangency-based NC exceeds the SIL-based NC by more than 3 dB, the spectrum has an imbalance. Check `specImbalance.Details` to see which bands deviate from the reference curve.

### RC Mark II Classification — Engineering Actions

| Classification | Meaning | Typical Remediation |
|----------------|---------|---------------------|
| `(N)` — Neutral | Balanced spectrum; ~5 dB/octave slope | Acceptable. No action needed. |
| `(H)` — Hissy | Excessive high-frequency energy | Check diffuser throw velocities, duct lining condition, valve noise |
| `(R)` — Rumbly | Excessive low-frequency energy | Check fan isolation mounts, duct breakout, flexible connectors |
| `(RV)` — Rumbly-Vibratory | Severe low-frequency excess with vibration risk | Serious concern — address structure-borne transmission paths, verify inertia base isolation |

**QAI (Quality Assessment Index):**
- QAI ≤ 5 dB: Acceptable spectral balance
- QAI > 5 dB: Poor balance. The classification letter tells you which region dominates.
- QAI = 0: Perfect match to the ideal RC contour (rare in practice)

### RNC vs NC — Diagnosing Fluctuation

When RNC significantly exceeds NC for the same recording, the noise has temporal variation causing additional annoyance. The larger the difference, the more the temporal variation contributes to the overall noise problem.

Common causes of fluctuation: variable-frequency drives on fans, cycling compressors, duct resonances at low frequency, interaction between multiple HVAC units.

### Speech Interference Level (SIL) Interpretation

SIL is the arithmetic average of octave-band Leq at 500, 1000, 2000, and 4000 Hz. Higher SIL values indicate greater difficulty communicating by speech. Compare against project specifications or use the STI/SII metrics for a more detailed speech intelligibility assessment.

### Rattle Risk Interpretation

The `rattleRisk` output assesses whether low-frequency levels could excite lightweight building elements (ceiling tiles, light fixtures, ductwork panels):

- **No rattle risk:** Levels are below perceptibility thresholds at 16 and 31.5 Hz
- **Moderate risk (Region B):** Vibration moderately perceptible — may cause intermittent rattles
- **High risk (Region A):** Vibration clearly perceptible — rattling of lightweight structures likely

Check `rattleRisk.Details` for the specific assessment per frequency band.

## Troubleshooting

| Observation | Likely Cause | Action |
|-------------|-------------|--------|
| NC seems fine but occupants complain | Noise fluctuates — NC averages away the annoyance | Run `roomNoiseCriteria` to quantify fluctuation penalty |
| NC exceeds target by 1–2 dB | One band drives tangency while SIL is within target | Check `specImbalance.Details` — treatment may be needed in one band only |
| RC shows "(RV)" | Severe low-frequency excess at 16 or 31.5 Hz | Do not attempt to mask with absorption — isolate the vibration source |
| RNC errors on short recording | Surging or fluctuation detected but recording under 15 s (correction needs 150 samples) | Re-record ≥15 s, or set `IsSurging=false, IsFluctuating=false` to bypass correction (result will not account for temporal variation) |
| NC/RC ratings differ significantly | They use different band ranges (NC: 63–8kHz, RC: 16–4kHz) and methods | Normal; RC captures low-frequency problems NC misses |
| Measurements vary widely by position | Room modes and proximity to sources | Report worst-case; measure at multiple positions or sweep per measurement conditions above |
| Bands below 63 Hz needed but instrument can't measure them | Type 2 meters often roll off below 63 Hz | Use Type 1 meter for RC/RNC (which include 16 and 31.5 Hz bands) |
| Background noise contaminates measurement | Source noise isn't >10 dB above ambient in all bands | Measure with source off, verify ≥10 dB separation. Apply background correction if 3–10 dB difference. |

----

Copyright 2026 The MathWorks, Inc.

----
