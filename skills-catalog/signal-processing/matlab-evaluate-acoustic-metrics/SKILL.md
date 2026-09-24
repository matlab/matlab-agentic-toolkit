---
name: matlab-evaluate-acoustic-metrics
description: >
  Select and use Audio Toolbox acoustic, psychoacoustic, and speech quality
  metrics. Use when computing loudness, sharpness, roughness, fluctuation
  strength, noise criteria (NC/RNC/RC), speech transmission index (STI),
  speech intelligibility index (SII), speech quality (ViSQOL, STOI), SPL,
  reverberation time (RT60), tone-to-noise ratio, or prominence ratio.
  Also use when asked about PESQ, POLQA, calibration factor, EBU R 128,
  LUFS, HVAC noise, background noise evaluation, or how to measure audio
  quality or noise compliance. Covers calibration, standard selection, signal
  alignment, and the complete function inventory including what does NOT exist.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Evaluate Acoustic Metrics

Select the correct Audio Toolbox function for acoustic measurement, apply proper calibration, and choose appropriate standards — instead of reimplementing algorithms or calling nonexistent functions.

## When to Use

- Computing psychoacoustic metrics (loudness, sharpness, roughness, fluctuation)
- Evaluating speech quality or intelligibility (ViSQOL, STOI, STI, SII)
- Assessing noise compliance (NC rating, RC rating, RNC, SIL)
- Measuring SPL from recordings (offline, calibrated)
- Computing broadcast loudness (EBU R 128 / LUFS)
- Measuring reverberation time (RT60) from impulse responses
- Detecting tonal content (tone-to-noise ratio, prominence ratio)
- Converting microphone sensitivity to CalibrationFactor
- User mentions PESQ or POLQA (redirect to correct alternatives)

## When NOT to Use

- Real-time streaming audio processing loops — use `matlab-process-streaming-audio`
- Audio device I/O, recording, or live `calibrateMicrophone` — use `matlab-play-record-audio`
- Audio plugin authoring (VST/AU) — use `matlab-write-audio-plugin`
- General filter design unrelated to measurement — use `matlab-design-digital-filter`
- Spatial audio / HRTF / SOFA processing

## Workflow

Follow this decision tree to route the user's goal to the right function:

### 1. Identify the measurement goal

| Goal | Category | Go to |
|------|----------|-------|
| "How loud is it?" (perceived) | Psychoacoustic | → Psychoacoustic Metrics |
| "Does it comply with broadcast loudness?" | Broadcast | → Broadcast Loudness |
| "Is the noise level acceptable for this space?" | Noise compliance | → Noise Compliance |
| "Can people understand speech in this room?" | Speech intelligibility | → STI/SII Measurement |
| "How good does processed speech sound?" | Speech quality | → Speech Quality |
| "What's the SPL?" | Level measurement | → SPL Measurement |
| "What's the reverberation time?" | Room acoustics | → RT60 |
| "Is there a tonal component?" | Tonality | → Tonality |

### 2. Ask before computing

Before writing code, confirm these with the user:

- **Calibration:** Do they have a CalibrationFactor? Did they calibrate with `calibrateMicrophone`? (See Calibration section)
- **Standard:** Which standard or method applies? (ISO 532-1 vs 532-2, NC vs RC vs RNC)
- **Sound field:** Free field or diffuse field recording?
- **Application context:** What space type? What's the concern? (Drives NC vs RC vs RNC selection)

### 3. Select function and apply

Use the Key Functions table and the category-specific patterns below.

## Functions That Do NOT Exist

| Function | Status | Use Instead |
|----------|--------|-------------|
| `pesq` | Does NOT exist (proprietary ITU-T P.862 license) | `visqol(degraded, reference, fs, Mode="speech")` |
| `polqa` | Does NOT exist (proprietary ITU-T P.863 license) | `visqol(degraded, reference, fs)` |

Never suggest `pesq` or `polqa`. They are not in Audio Toolbox and cannot be added due to licensing.

## Key Functions

| Function | Purpose | Standard | Available From |
|----------|---------|----------|----------------|
| `acousticLoudness` | Perceived loudness (sones) | ISO 532-1/2 | R2020a |
| `acousticSharpness` | Perceived sharpness (acum) | DIN 45692 | R2020a |
| `acousticRoughness` | Perceived roughness (asper) | — | R2021a |
| `acousticFluctuation` | Fluctuation strength (vacil) | — | R2020b |
| `integratedLoudness` | Broadcast loudness (LUFS) | EBU R 128 / ITU-R BS.1770 | R2016b |
| `loudnessMeter` | Streaming broadcast loudness meter | EBU R 128 / ITU-R BS.1770 | R2018a |
| `visqol` | Full-reference audio quality (MOS) | — | R2024a |
| `stoi` | Short-time objective intelligibility | — | R2024a |
| `mnru` | Modulated noise reference unit | ITU-T P.810 | R2024a |
| `dBov` | Power level relative to overload (dB) | ITU-T G.100.1 | R2024a |
| `speechTransmissionIndex` | STI from IR or test signals | IEC 60268-16 | R2026a |
| `speechIntelligibilityIndex` | SII from IR, test signals, or levels | ANSI/ASA S3.5-1997 | R2026b |
| `stipaExcitation` | Generate STI/STIPA test signals | IEC 60268-16 | R2026a |
| `siiExcitation` | Generate SII test signals | ANSI/ASA S3.5-1997 | R2026b |
| `noiseCriteria` | NC rating + SIL + spectrum imbalance + rattle risk | ANSI/ASA S12.2 | R2026b |
| `roomNoiseCriteria` | RNC rating (detects surging/fluctuations) | ANSI/ASA S12.2 | R2026b |
| `roomCriteria` | RC Mark II rating (HVAC systems) | ANSI/ASA S12.2 | R2026b |
| `noiseCriteriaCurves` | Look up NC curve values | ANSI/ASA S12.2 | R2026b |
| `noiseCriteriaRecommendations` | Recommended NC levels by room type | ANSI/ASA S12.2 | R2026b |
| `speechInterferenceLevel` | SIL from recording | ANSI/ASA S12.2 | R2026b |
| `rt60` | Reverberation time from impulse response | ISO 3382-1/2 | R2025a |
| `acousticToneToNoiseRatio` | Detect/quantify tones | ECMA-418-1 | R2023b |
| `acousticProminenceRatio` | Tonality via critical band comparison | ECMA-418-1 | R2023b |
| `splMeter` | SPL measurement (time-weighted, per-band) | IEC 61672 | R2018a |
| `calibrateMicrophone` | Compute calibration factor from known tone | — | R2018b |
| `weightingFilter` | A/C/Z/K frequency weighting | IEC 61672-1 | R2016b |
| `octaveFilter` | Single octave-band filter | ANSI S1.11-2004 | R2017b |
| `octaveFilterBank` | Multi-band octave filtering | ANSI S1.11-2004 | R2019a |

See `references/function-arguments.md` for complete argument lists, defaults, and valid values for each function — consult when constructing calls with non-default parameters.

## Calibration

### CalibrationFactor from microphone sensitivity

Convert dB sensitivity (dBV/Pa) to the linear CalibrationFactor:

```matlab
sensitivity_dBV = -26;  % Example: -26 dBV/Pa microphone
calibrationFactor = 1 / 10^(sensitivity_dBV/20);
```

The CalibrationFactor is the 3rd positional argument for `acousticLoudness`, `acousticSharpness`, `acousticRoughness`, and `acousticFluctuation` (default: `sqrt(8)`). For noise compliance functions, pass it as a name-value: `CalibrationFactor=value`.

### System-level calibration advice

Always ask the user about their signal chain. If the recording path includes a preamp, audio interface, or ADC with unknown gain, the mic sensitivity spec alone is insufficient. Recommend:

1. Play a 1 kHz tone through the system and record it through the full signal chain (mic → preamp → ADC → WAV). Use a pistonphone for a known 94 dB reference, or place a physical SPL meter next to the microphone to get an SPL reading.
2. Compute the system calibration factor: `calibrationFactor = calibrateMicrophone(calRecording, fs, SPLreading, FrequencyWeighting="Z-weighting")`
3. Pass that factor to the measurement function

`calibrateMicrophone` expects a 1 kHz tone recording as input. The `SPLreading` argument is the known SPL in dB (e.g., 94 from a pistonphone, or the value shown on a physical SPL meter).

Cross-reference: for the physical recording workflow with `calibrateMicrophone`, see the `matlab-play-record-audio` skill.

## Patterns

### Psychoacoustic Metrics

```matlab
[audioIn, fs] = audioread("recording.wav");
calFactor = 1 / 10^(-26/20);

loudness = acousticLoudness(audioIn, fs, calFactor, ...
    Method="ISO 532-1", SoundField="diffuse", TimeVarying=true);

sharpness = acousticSharpness(audioIn, fs, calFactor, ...
    SoundField="diffuse", TimeVarying=true);

roughness = acousticRoughness(audioIn, fs, calFactor, SoundField="diffuse");

fluctuation = acousticFluctuation(audioIn, fs, calFactor, SoundField="diffuse");
```

**Return types:** `acousticLoudness` returns a scalar (sones) for stationary analysis. With `TimeVarying=true`, it returns a column vector (time-varying loudness in sones). The second output (`specificLoudness`) is a matrix (time x critical bands). It does NOT return a struct or timetable.

**Ask the user:**
- ISO 532-1 (Zwicker, stationary/time-varying) or ISO 532-2 (Moore-Glasberg)?
- Free-field or diffuse-field recording?
- Time-varying analysis needed?

See `references/psychoacoustic-metrics.md` for method selection guidance (ISO 532-1 vs 532-2), interpretation tables (sone values, sharpness/roughness/fluctuation scales), tonality metric selection, and combined sound quality assessment workflows.

### Unit Conversions

Use built-in functions — do NOT reimplement conversion formulas manually:

| Conversion | Function | Method selection |
|------------|----------|-----------------|
| phon → sone | `phon2sone(phon, standard)` | `"ISO 532-1"` (default), `"ISO 532-2"` |
| sone → phon | `sone2phon(sone, standard)` | `"ISO 532-1"` (default), `"ISO 532-2"` |
| Hz → ERB | `hz2erb(freq)` | Single formula (no variants) |
| ERB → Hz | `erb2hz(erb)` | Single formula (no variants) |
| Hz → bark | `hz2bark(freq)` | Single formula (no variants) |
| bark → Hz | `bark2hz(bark)` | Single formula (no variants) |
| Hz → mel | `hz2mel(freq, MelStyle=s)` | `"oshaughnessy"` (default), `"slaney"` |
| mel → Hz | `mel2hz(mel, MelStyle=s)` | `"oshaughnessy"` (default), `"slaney"` |

When the user specifies a standard (e.g., "ISO 532-2"), pass it as the second positional argument for `phon2sone`/`sone2phon`. For `hz2mel`/`mel2hz`, use the `MelStyle` name-value pair.

### Noise Compliance

Choose the function based on the application:

| Situation | Function | Why |
|-----------|----------|-----|
| General background noise rating | `noiseCriteria` | Standard NC curves (ANSI/ASA S12.2) |
| HVAC system noise specifically | `roomCriteria` | RC Mark II designed for HVAC evaluation |
| Noise with audible surging/fluctuation | `roomNoiseCriteria` | RNC penalizes time-varying noise (requires ≥15 s recording) |
| Quick speech interference check | `speechInterferenceLevel` | Direct SIL value |
| Need recommended levels for room type | `noiseCriteriaRecommendations` | Lookup table by room use |

```matlab
[audioIn, fs] = audioread("office_noise.wav");

[NC, SIL, specImbalance, rattleRisk] = noiseCriteria(audioIn, fs, ...
    CalibrationFactor=2.3);

[RC, LMF, QAI, rattleRisk] = roomCriteria(audioIn, fs, ...
    CalibrationFactor=2.3);

SIL = speechInterferenceLevel(audioIn, fs, CalibrationFactor=2.3);

rec = noiseCriteriaRecommendations("NC", Occupancy="all");
```

**Return types:**
- `NC` is a string (e.g., `"NC-35"` or `"NC-56 (1000 Hz)"` if a band exceeds)
- `RC` is a string (e.g., `"RC-32(N)"` — the letter indicates spectrum quality: N/R/H/RV)
- `SIL` and `LMF` are double scalars (dB)
- `QAI` is a double scalar (dB; 0 = ideal neutral)
- `specImbalance` and `rattleRisk` are structs with `.Summary` (string) and `.Details` (table) — access `.Summary` for display. **Exception:** `specImbalance` degrades to a `char` scalar (not a struct) when NC exceeds the curve range (e.g., "Above NC-70") or falls below NC-15. Guard with `isstruct(specImbalance)` before dot-indexing.
- `noiseCriteriaRecommendations` requires a criteria name argument: `"NC"`, `"RNC"`, or `"RC"`

**Ask the user:**
- What type of space? (office, classroom, hospital, concert hall)
- Is the noise source HVAC? → prefer `roomCriteria`
- Is the noise steady or fluctuating? → if fluctuating, use `roomNoiseCriteria`

See `references/noise-compliance.md` for detailed output interpretation and selection guidance.

### Speech Quality

```matlab
[degraded, fs] = audioread("processed_speech.wav");
[reference, ~] = audioread("reference_speech.wav");

mosScore = visqol(degraded, reference, fs, Mode="speech");

intelligibility = stoi(degraded, reference, fs);
```

**Critical:** `stoi` and `visqol` argument order is `(processed, reference, fs)` — processed/degraded signal FIRST.

`visqol` modes: `"speech"` for narrowband/wideband speech (outputs 1-5 MOS), `"audio"` (default) for general audio.

### STI/SII Measurement

Two methods are available for both `speechTransmissionIndex` and `speechIntelligibilityIndex`:

**IR-based method** (simpler — no alignment needed):

```matlab
[ir, fs] = audioread("room_impulse_response.wav");
sti = speechTransmissionIndex(ir, fs);
sii = speechIntelligibilityIndex(ir, fs);
```

**Direct method** (from test signals transmitted through the system):

```matlab
fs = 48000;
reference = stipaExcitation(fs, Duration=15);
% Transmit reference through system, record as 'processed'
[processed, ~] = audioread("received_stipa.wav");

% IMPORTANT: Align signals before computing (see Signal Alignment)
processed = alignsignals(processed, reference);

sti = speechTransmissionIndex(processed, reference, fs);
```

**Ask the user:**
- Do they have an impulse response? → use IR method (simpler, no alignment needed)
- Measuring live? → generate test signal, transmit, record, align, compute
- STI or SII? STI for room/PA systems (IEC 60268-16); SII for hearing/communication (ANSI S3.5)

See `references/sti-measurement.md` for STI NV arguments, post-processing adjustment workflow (Annex M), test signal generation, and result interpretation. See `references/sii-measurement.md` for SII standard clause selection (5.1-5.3), BandImportanceFunction guidance, measurement positioning, and result interpretation.

### SPL Measurement (Offline)

```matlab
[audioIn, fs] = audioread("recording.wav");

spl = splMeter(SampleRate=fs, ...
    Bandwidth="Full band", ...
    FrequencyWeighting="A-weighting", ...
    TimeWeighting="fast", ...
    CalibrationFactor=2.3);

[Lt, Leq, Lpeak, Lmax] = spl(audioIn);

% For a single overall value, read the final row
fprintf("Leq: %.1f dB(A)\n", Leq(end));
```

Valid `Bandwidth` values: `"Full band"` (overall level), `"1 octave"`, `"2/3 octave"`, `"1/3 octave"`. There is no `"broadband"` option — use `"Full band"` for a single overall SPL value.

**Output arity:** All outputs (`Lt`, `Leq`, `Lpeak`, `Lmax`) have one row per input sample. For a 12-second file at 44.1 kHz, that is 539,648 rows. Never `fprintf` or `disp` the full output — it will hang. Instead:
- **Single overall value:** read `Leq(end)` (the final accumulated value)
- **Time-interval readings:** downsample to interval boundaries: `Leq(round(fs*T):round(fs*T):end, :)` where `T` is the desired interval in seconds

`TimeInterval` controls the integration window for `Leq` computation but does NOT reduce the number of output rows.

Do not manually compute `20*log10(rms(audioIn)/20e-6)` — `splMeter` handles calibration, weighting, and time integration correctly per IEC 61672.

**Multi-band (octave-band) SPL:** Use `splMeter` with `Bandwidth="1 octave"` — do NOT use `octaveFilterBank` + manual dB conversion. Key properties for octave-band SPL:

```matlab
[audioIn, fs] = audioread("recording.wav");

spl = splMeter(SampleRate=fs, ...
    Bandwidth="1 octave", ...
    FrequencyWeighting="Z-weighting", ...
    TimeWeighting="fast", ...
    FrequencyRange=[15 8000], ...
    OctaveFilterOrder=8, ...
    CalibrationFactor=2.3);

[Lt, Leq, Lpeak, Lmax] = spl(audioIn);
cf = getCenterFrequencies(spl);
```

**Critical gotchas for octave-band `splMeter`:**

- **Property name is `OctaveFilterOrder`** (not `FilterOrder`). `FilterOrder` does not exist on `splMeter`.
- **`FrequencyRange` compares against true center frequencies** (`fc = 1000 × 10^(3b/10)` per IEC 61260), not nominal values. A band is included only if its true center falls within `[lower, upper]`. Bands below 1 kHz have true centers slightly above nominal (e.g., "63 Hz" = 63.10); bands above 1 kHz have true centers below nominal (e.g., "2 kHz" = 1995.26, "8 kHz" = 7943.28). Use `floor(true_center)` for lower bounds and `ceil(true_center)` for upper bounds. Common case "16 Hz to 8 kHz": use `[15 8000]` — the 16 Hz true center is 15.85 (so 15 ≤ 15.85 includes it) and 8 kHz true center is 7943 (so 8000 ≥ 7943 includes it). Do NOT use `[16 8000]` — this drops the 16 Hz band.
- **Output is per-sample** (see Output arity note above). Never print the full output. For time-interval readings, downsample: `Lt100ms = Lt(round(fs*0.1):round(fs*0.1):end, :);`

See `references/spl-measurement.md` for weighting selection guidance (A/C/Z and fast/slow), SPL interpretation tables, occupational exposure limits, splMeter vs poctave equivalency, and common measurement scenarios.

### Broadcast Loudness (EBU R 128)

```matlab
[audioIn, fs] = audioread("broadcast_content.wav");
[loudness, loudnessRange] = integratedLoudness(audioIn, fs);

% Check compliance: target is -23 LUFS +/- 1 LU
isCompliant = abs(loudness - (-23)) <= 1;
```

Use `integratedLoudness` for offline compliance checks. Use `loudnessMeter` for streaming/real-time monitoring (see `matlab-process-streaming-audio`).

### RT60

```matlab
[ir, fs] = audioread("room_ir.wav");
rtsummary = rt60(ir, fs, Bandwidth="1 octave");
```

**Ask the user:**
- What is the room type? (drives the target RT60)
- Do they have an IR, or do they need to measure one?
- T30 (standard) vs T20 (when noise floor limits dynamic range)?

See `references/rt60-measurement.md` for target RT60 values by space type, T20/T30/EDT interpretation, frequency-dependent analysis, and relationship to STI.

### Tonality

```matlab
[audioIn, fs] = audioread("machine_noise.wav");

[tnr, tnrFreq, isProminent] = acousticToneToNoiseRatio(audioIn, fs);

[pr, prFreq, isProminent] = acousticProminenceRatio(audioIn, fs);
```

All outputs are empty (0×1) when no tonal components are detected. Check `isempty(tnr)` before indexing.

### Standards-Compliant Filters (Custom Preprocessing)

The metric functions above perform standards-compliant filtering internally. Use standalone filter objects only for custom measurement workflows where no single metric function applies AND you do not need SPL output:

```matlab
% A-weighting filter
wf = weightingFilter("A-weighting", fs);
weightedSignal = wf(audioIn);

% Octave-band filter bank (for waveform-level band decomposition only)
ofb = octaveFilterBank("1 octave", fs, ...
    FrequencyRange=[31.5 16000], FilterOrder=8);
bandSignals = ofb(audioIn);
```

**If you need octave-band SPL levels**, use `splMeter` with `Bandwidth="1 octave"` instead of `octaveFilterBank` + manual dB conversion. See the Multi-band SPL section above.

## Signal Alignment

| Function | Internal alignment? | Action |
|----------|-------------------|--------|
| `visqol` | Yes | No action needed |
| `stoi` | No | Align before calling |
| `speechTransmissionIndex` | No | Align for direct method; IR method avoids issue |
| `speechIntelligibilityIndex` | No | Align for direct method; IR method avoids issue |

For the direct `(processed, reference, fs)` method, always align signals:

```matlab
processed = alignsignals(processed, reference);
```

SII is more sensitive to misalignment than STI. At 50 ms delay: SII error ~0.016, STI negligible. At 200 ms: SII ~0.036, STI ~0.017. The IR-based `(ir, fs)` method avoids alignment issues entirely.

## Common Mistakes

| Mistake | Why it fails | Correct approach |
|---------|-------------|-----------------|
| Call `pesq(reference, degraded, fs)` | Function does not exist | `visqol(degraded, reference, fs, Mode="speech")` |
| `stoi(reference, processed, fs)` | Wrong argument order | `stoi(processed, reference, fs)` — processed FIRST |
| `acousticFluctuationStrength(...)` | Wrong function name | `acousticFluctuation(audioIn, fs, calFactor)` |
| Implement NC from scratch with hardcoded curves | Misses SIL, spectrum imbalance, rattle risk | `noiseCriteria(audioIn, fs, CalibrationFactor=cf)` |
| `20*log10(rms(x)/20e-6)` for SPL | No weighting, no time integration, no calibration | `splMeter` with appropriate settings |
| Implement STI algorithm manually | ~100 lines, error-prone, misses NV options | `speechTransmissionIndex(ir, fs)` |
| Divide signal by calibration factor manually | Incorrect; factor is a multiplier, not a divisor | Pass as positional arg or `CalibrationFactor=value` |
| Skip alignment for direct STI/SII | Silent accuracy degradation | `alignsignals(processed, reference)` before calling |
| Use `acousticLoudness` for broadcast loudness | Wrong standard (ISO 532 = sones, not LUFS) | `integratedLoudness` for EBU R 128 compliance |
| `string(rattleRisk)` or `fprintf("%s", specImbalance)` | These are structs, not strings | Access `.Summary` field: `rattleRisk.Summary` |
| `specImbalance.Summary` when NC is out of curve range | `specImbalance` degrades to `char` (not struct) when "Above NC-70" or below NC-15 | Guard: `if isstruct(specImbalance), disp(specImbalance.Summary); end` |
| `roomNoiseCriteria` on recordings shorter than 15 s | ANSI/ASA S12.2-2019 requires ≥150 Lt samples at 100 ms intervals | Ensure recording is at least 15 seconds; use `noiseCriteria` for shorter clips |
| `round(NC)` or arithmetic on NC/RC output | NC and RC are strings, not numbers | Use directly: `fprintf("%s\n", NC)` |
| `noiseCriteriaRecommendations()` with no args | First argument (criteria name) is required | `noiseCriteriaRecommendations("NC")` |
| `loudness.OverallLoudness` after `acousticLoudness` | Returns a scalar or vector, not a struct | Use directly: `fprintf("%.1f sones\n", loudness)` |
| `splMeter(..., FilterOrder=8)` | Property does not exist on `splMeter` | Use `OctaveFilterOrder=8` |
| `splMeter(..., FrequencyRange=[16 8000])` for 16 Hz–8 kHz | Drops 16 Hz band (true center is 15.85 Hz, which is below 16) | Use `FrequencyRange=[15 8000]` — use `floor(true_center)` for lower bound |
| `octaveFilterBank` + `20*log10(rms(band)/pRef)` for SPL | Manual, no time weighting, no calibration integration | Use `splMeter` with `Bandwidth="1 octave"` |
| Treating `splMeter` output as a single value | All outputs have one row per input sample (e.g., 539k rows for 12s at 44.1 kHz) | Use `Leq(end)` for a single value, or downsample to interval boundaries |

## Conventions

- Always ask about the user's measurement goal before selecting a function
- Always ask about calibration — recommend `calibrateMicrophone` for system-level accuracy
- Default to `SoundField="free"` for anechoic/outdoor, `"diffuse"` for reverberant rooms
- Default to `Method="ISO 532-1"` for loudness (Zwicker method, most common)
- Use IR-based methods for STI/SII when an impulse response is available (avoids alignment)
- Pass `CalibrationFactor` explicitly rather than pre-scaling the signal
- For noise compliance, prefer `roomCriteria` for HVAC and `noiseCriteria` for general background noise

----

Copyright 2026 The MathWorks, Inc.

----
