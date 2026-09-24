# RT60 Measurement

Guidance for selecting parameters, interpreting results, and guiding user workflows for `rt60`.

## Intake Questions

### 1. What is the purpose?

| Purpose | What RT60 tells them |
|---------|---------------------|
| Room design verification | Does the finished room meet the acoustic design target? |
| Speech intelligibility assessment | Is the room too reverberant for speech? (RT60 > 1.5s generally problematic) |
| Music venue evaluation | Is the reverberance appropriate for the genre? |
| Noise control / absorption planning | How much absorption is needed to reduce RT60 to target? |
| Compliance with building standards | Does the room meet standards like BB93, ANSI S12.60? |
| STI context | Explaining why STI is low — reverberance is the usual culprit |

### 2. Do they have an impulse response?

- **Yes:** Pass directly to `rt60(ir, fs)`
- **No, need to measure:** See the `matlab-play-record-audio` skill for the IR capture workflow (`sweeptone` generation, playback/recording through the room, and `impzest` deconvolution). This skill covers what to do *with* the IR once obtained.

**IR requirements:** The IR must include the noise floor — continue recording after the reverberation tail has fully decayed. The function assumes at least the last 10% of the IR duration corresponds to noise (used for noise floor estimation). For large reverberant spaces (churches, concert halls), use longer captures (3–5 s minimum).

### 3. What analysis bandwidth?

| Bandwidth | Output | When to use |
|-----------|--------|-------------|
| `"1 octave"` (default) | RT60 per octave band | Standard building acoustics, compliance checks, general room characterization |
| `"1/3 octave"` | RT60 per 1/3-octave band | Detailed analysis, research, when absorption varies significantly within octave bands |

### 4. Noise compensation method

| Method | Behavior | When to use |
|--------|----------|-------------|
| `"truncate-correct"` (default) | Lundby algorithm: estimates noise floor, truncates IR at noise intersection, compensates per ISO 3382-1 | Standard-compliant measurements; most situations |
| `"subtract-truncate-correct"` | Additionally subtracts noise floor before truncation | When the noise floor is relatively high; shown to introduce less systematic error in noisy conditions (non-ISO) |

Default is appropriate for most users. Only suggest `"subtract-truncate-correct"` when IRs have marginal SNR and the user does not require strict ISO 3382-1 compliance.

### 5. Measurement conditions (ISO 3382-2)

ISO 3382-2 defines three measurement levels (Table 1, section 4.3):

| Level | Source-mic combinations | Source positions | Mic positions | Accuracy (octave) |
|-------|------------------------|-----------------|---------------|-------------------|
| Survey | ≥2 | ≥1 | ≥2 | ~10% |
| Engineering | ≥6 | ≥2 | ≥2 | ~5% |
| Precision | ≥12 | ≥2 | ≥3 | ~2.5% |

**Position requirements (section 4.3.1):**
- Mic positions **shall** be at least half a wavelength apart (~2 m for typical frequency range)
- Distance from mic to nearest reflecting surface (including floor) **should preferably** be at least a quarter wavelength (~1 m)
- Minimum source-to-mic distance depends on room volume and expected RT60: d_min = 2×sqrt(V / (c×T))
- Symmetric positions **shall** be avoided

**Additional conditions:**
- **Room state:** Furnishings in place as intended for use (unfurnished rooms measure much longer RT60)
- **Background noise (section 5.2.1):** Source level **shall** be at least 35 dB above background noise for T20, or 45 dB for T30
- **Reliability (ISO 3382-1 section 7.3):** Results **shall** satisfy B×T > 16, where B is the filter bandwidth (Hz) and T is the measured reverberation time (s). Low-frequency bands with short RT60 may fail this criterion.

## Interpreting RT60 Results

### T20 vs T30 vs EDT

| Metric | Evaluation Range | What it represents |
|--------|-----------------|-------------------|
| EDT (Early Decay Time) | 0 to −10 dB | Perceived reverberance — what listeners experience (first part of decay dominates perception) |
| T20 | −5 to −25 dB | Reverberation time extrapolated from 20 dB range — more robust to noise than T30 |
| T30 | −5 to −35 dB | Reverberation time from 30 dB range — more accurate but requires higher IR SNR |

**Guidance:**
- **EDT** correlates best with subjective impression of reverberance — use when reporting "how reverberant the room feels"
- **T30** is the standard metric for compliance and design verification (ISO 3382 prefers T30 when SNR allows)
- **T20** is a fallback when background noise limits the usable decay range
- **Topt** uses the decay range yielding the best linear fit while remaining 10 dB above the detected noise floor — useful when neither T20 nor T30 gives a clean fit
- In a well-diffused room, EDT ≈ T20 ≈ T30. If they diverge significantly:
  - EDT << T20/T30: Strong early reflections followed by a long tail (common with localized absorption near source/receiver)
  - EDT >> T20/T30: Weak early field (unusual — check measurement)
- Metrics return **NaN** when the detected noise floor does not allow 10 dB of headroom over the evaluation range — this indicates insufficient IR SNR for that metric in that band

### Additional Output Metrics

The `rt60` output table includes metrics beyond reverberation time that are useful for room quality assessment:

| Metric | Standard | Definition | Application |
|--------|----------|-----------|-------------|
| C50 | ISO 3382-1 | Clarity (50 ms cutoff) — early-to-late energy ratio (dB) | Speech clarity: C50 > 0 dB is generally acceptable; higher is clearer |
| C80 | ISO 3382-1 | Clarity (80 ms cutoff) — early-to-late energy ratio (dB) | Music clarity: C80 between −2 and +2 dB is optimal for most genres |
| D50 | ISO 3382-1 | Definition (50 ms cutoff) — early-to-total energy ratio (0 to 1) | Speech: D50 > 0.5 generally indicates adequate articulation |
| TS | ISO 3382-1 | Center time — center of gravity of the squared IR (seconds) | Lower TS = more early energy; correlates with clarity perception |
| DegreeOfNonLinearity | ISO 3382-2 B.2 | 1000×(1−r²) for the linear fit of each decay range (N-by-4 matrix: EDT, T20, T30, Topt) | Values 0–5 typical; high values suggest non-exponential decay |
| Curvature | ISO 3382-2 B.3 | `100 × (T30/T20 − 1)` (signed) | Values −5 to 5 typical; magnitude indicates divergence between T20 and T30; sign indicates direction |

**When to report which metrics:**
- Room design compliance: T30 (or T20), Curvature
- Speech room assessment: T30, EDT, C50, D50
- Music venue assessment: T30, EDT, C80, TS
- Measurement quality check: DegreeOfNonLinearity, Curvature

### Target RT60 Values by Space Type

| Space | Target RT60 (s) | Standard/Reference |
|-------|----------------|-------------------|
| Recording studio / control room | 0.2–0.4 | — |
| Classroom (≤283 m³) | ≤ 0.6 | ANSI S12.60, BB93 (UK) |
| Classroom (>283 m³) | ≤ 0.7 | ANSI S12.60 |
| Conference room | 0.4–0.7 | — |
| Lecture hall | 0.7–1.0 | — |
| Open plan office | 0.5–0.8 | — |
| Concert hall (symphony) | 1.8–2.2 | — |
| Concert hall (chamber music) | 1.4–1.8 | — |
| Opera house | 1.2–1.6 | — |
| Church (liturgical music) | 2.0–4.0 | — |
| Worship (speech-primary) | 0.8–1.2 | — |
| Hospital patient room | 0.4–0.6 | — |

### RT60 vs Frequency

RT60 typically varies with frequency:
- **Low frequencies (125–250 Hz):** Often longer (less absorption from typical materials at LF)
- **Mid frequencies (500–1000 Hz):** Reference range — most targets are specified here
- **High frequencies (2000–8000 Hz):** Often shorter due to air absorption and porous absorber effectiveness

**Common patterns and implications:**
| Pattern | Cause | Action |
|---------|-------|--------|
| Flat across frequency | Well-treated room with broadband absorption | Ideal for speech and music |
| Rising at low frequency | Insufficient bass trapping | Add bass traps, panel absorbers, or membrane absorbers |
| Falling at high frequency | Excessive HF absorption or air absorption in large rooms | Normal for large volumes; add diffusion if HF liveness desired |
| Spike at one frequency | Room mode or resonance | Treat the specific mode with targeted absorption |

### Relationship to STI

RT60 and STI are directly related — reverberation is the primary degrader of speech intelligibility in quiet rooms. Approximate STI for purely diffuse exponential-decay rooms with no ambient noise (computed using `speechTransmissionIndex` on synthetic IRs with `AddOperationalAmbientNoise=false`):

| RT60 (s) | Approximate STI | IEC 60268-16 Category |
|-----------|----------------|----------------------|
| 0.5 | 0.74 | A |
| 1.0 | 0.60 | D |
| 1.5 | 0.50 | G |
| 2.0 | 0.44 | H–I |
| 3.0 | 0.36 | U |
| 5.0 | 0.27 | U |

Adding ambient noise can only reduce STI below these values.

If the user has STI concerns:
- Short RT60 but low STI → noise is the dominant factor, not reverberation
- Long RT60 and low STI → reduce RT60 with absorption (most effective intervention)
- Use `rt60` to diagnose, then `speechTransmissionIndex` to quantify the intelligibility impact

### Assessing Measurement Quality

Use `DegreeOfNonLinearity` and `Curvature` from the output table to assess whether results are trustworthy:

- **DegreeOfNonLinearity (ξ):** Defined as 1000×(1−r²), where r² is the correlation coefficient of the linear fit to the energy decay curve. ξ = 0 means a perfect linear fit (r² = 1). ISO 3382-2 B.2 states typical values are 0–5. To interpret as r²: r² = 1 − ξ/1000 (e.g., ξ = 5 → r² = 0.995).
- **Curvature:** Quantifies the divergence between T30 and T20. Values near 0 indicate consistent decay; |Curvature| > 5 suggests coupled volumes or non-diffuse conditions (ISO 3382-2 B.3).
- **NaN values:** If a metric returns NaN, the detected noise floor does not provide enough headroom for that evaluation range in that band — use a metric with a shorter evaluation range (T20 instead of T30) or re-record with a stronger source.

## Common Scenarios

### Scenario: Classroom Compliance Check

1. Obtain room IR (see `matlab-play-record-audio` for capture workflow; sine sweep method preferred for SNR)
2. Compute: `rtsummary = rt60(ir, fs, Bandwidth="1 octave")`
3. Read T30 (or T20 if insufficient SNR) at 500 Hz, 1000 Hz, 2000 Hz
4. Average these three mid-frequency bands → this is the compliance metric
5. Compare to target: ANSI S12.60 requires ≤ 0.6 s for rooms ≤ 283 m³

### Scenario: Diagnose Low STI

1. Measure STI: `speechTransmissionIndex(ir, fs, OperationalNoiseLevel="NC-35")`
2. If STI is low, measure RT60: `rtsummary = rt60(ir, fs)`
3. Examine frequency-dependent RT60 — which bands are too long?
4. Cross-reference with MTI output from STI: low MTI at specific bands + long RT60 at those bands = reverberation-driven problem
5. Recommend treatment: add absorption in the frequency bands where RT60 exceeds the target

### Scenario: Concert Hall Evaluation

1. Measure at multiple source-receiver positions (≥6 per ISO 3382-1)
2. Compute per-position RT60 and EDT
3. Report: mean T30 across positions (spatial average), EDT for perceived character
4. Compare T30 to genre target (1.8–2.2 s for symphony, 1.4–1.8 for chamber)
5. Check frequency balance: flat or gently rising at LF is preferred for warmth

## Troubleshooting

### Visual inspection of decay curves

The primary troubleshooting step is to call `rt60` with no output arguments to generate the convenience plot. The plot shows:
- **Top panel:** RT60 values (EDT, T20, T30, Topt) across octave bands — click a band to inspect it
- **Bottom panel:** The energy decay curve (EDC) for the selected band with linear fit lines overlaid

Inspect the fit lines against the EDC to identify:
- **Noise floor intersection** — where the EDC flattens, indicating the usable decay range
- **Double-slope decay (coupled rooms)** — a "hump" or change in slope in the tail, where energy from an adjacent coupled space arrives. This appears as a concave EDC that doesn't follow a single straight line.
- **Poor fit** — the linear regression doesn't track the actual decay

### Adjusting parameters for better fits

If the decay curves show poor fits, adjust `FilterOrder`, `FilterDirection`, and `NoiseCompensation` and monitor `DegreeOfNonLinearity` and `Curvature` to find the combination that best characterizes the decay:

| Parameter | Options | When to adjust |
|-----------|---------|----------------|
| `FilterOrder` | 2 (default), 4, 6, ... | Higher order gives sharper band separation — try when adjacent bands bleed energy |
| `FilterDirection` | `"forward"` (default), `"backward"` | Backward filtering eliminates filter ringing at the start of the decay — try when EDT looks unreliable |
| `NoiseCompensation` | `"truncate-correct"` (default), `"subtract-truncate-correct"` | Subtract mode reduces bias from high noise floors — try when T30 shows large DegreeOfNonLinearity |

### Common issues

| Observation | Likely Cause | Action |
|-------------|-------------|--------|
| T30 varies wildly between bands | Normal if room has frequency-dependent absorption | Expected behavior; focus on mid-frequency average for compliance |
| T30 > T20 by large margin | Noise floor contaminating the lower part of the decay | Trust T20; re-measure with higher source level if T30 needed |
| Large Curvature with concave EDC | Coupled room — energy returns from adjacent space | Report T20 (less affected); note coupled-room behavior in results |
| EDT much shorter than T30 | Strong early reflections near measurement position | Indicates non-diffuse field; measure at more positions and average |
| Very short RT60 (<0.1 s) | IR too short, or measurement captured direct sound only | Verify IR contains the full decay; use longer measurement window |
| RT60 result shows NaN or unreliable | Insufficient signal-to-noise ratio in that band | Check noise floor; use T20 instead of T30; re-record with stronger source |
| Different results from different positions | Normal room mode behavior — spatial variation is expected | Average across ≥3 positions per ISO 3382; report range |
| RT60 doesn't match subjective impression | EDT correlates better with perception than T30 | Report EDT alongside T30 for perceptual assessment |
| Measured RT60 seems implausible for the room | Measurement error, or unexpected room conditions | Use `predictRT60` with known room dimensions and materials as a sanity check against the measured value |

----

Copyright 2026 The MathWorks, Inc.

----
