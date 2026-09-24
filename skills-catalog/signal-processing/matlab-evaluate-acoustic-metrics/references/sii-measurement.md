# SII Measurement

## Intake Questions

### 1. What is the application?

SII measures whether speech is audible and intelligible under given noise and hearing conditions. Common use cases:

| Application | Typical Approach |
|-------------|-----------------|
| Room/system evaluation with a recording | IR-based or Direct method (like STI) |
| Hearing aid evaluation | Level-only method with `InsertionGain` and `HearingThresholdLevel` |
| Telecom or communication system design | Direct method through the system |
| Noise environment assessment (no audio) | Level-only method with estimated noise and speech levels |
| Classroom design for hearing-impaired students | Level-only method with `HearingThresholdLevel` and room noise |

### 2. Do they have audio, or just level specifications?

- **Have IR or audio:** Use IR-based or Direct method (same as STI)
- **Only have noise levels and speech specs:** Use the Level-only method -- no audio signal needed. Provide noise level, vocal effort, and distance.

### 3. Listener characteristics

Ask about:
- **Hearing loss:** Does the listener have elevated hearing thresholds? -> `HearingThresholdLevel` (dB HL per band)
- **Conductive hearing loss:** -> `ConductiveHearingLossLevel` (must be <= `HearingThresholdLevel`)
- **Hearing device:** Is an amplification device being evaluated? -> `InsertionGain` (gain curve per band)
- **Binaural advantage:** Is the listener using both ears? -> `IsBinaural=true` (adds ~1 dB effective SNR benefit)

### 4. Communication conditions (Level-only method)

- **Vocal effort:** Normal, raised, loud, or shout? (Changes spectral shape, not just level)
- **Distance:** Talker-to-listener distance in meters (inverse-square-law attenuation applied)
- **Noise level:** Measured or estimated background noise (scalar dB OASPL or per-band vector)
- **Measurement location:** Free-field or at eardrum? (Affects the transfer function applied)

### 5. Band procedure

SII can use different frequency resolution:
- `"critical band"` -- 21 bands (default for IR/Direct methods)
- `"1/3 octave band"` -- 18 bands
- `"equally-contributing critical band"` -- 17 bands
- `"octave band"` -- 6 bands (least precise, fastest)

The choice affects precision slightly; `"1/3 octave band"` is common for practical measurements.

## Standard Clauses & Workflow Selection

The ANSI/ASA S3.5-1997 standard defines three calculation methods (clauses 5.1-5.3) in increasing order of generality. The standard also allows workflows outside these clauses.

### When to Use Each Clause

| Clause | Conditions Required | Typical Scenario |
|--------|-------------------|------------------|
| 5.1 (Levels only) | Low reverberation; listener faces source directly (or omnidirectional); speech and noise are independent; system is linear | Office noise assessment, outdoor environments, simple room predictions |
| 5.2 (Measurements at listener position) | Well-mixed sound field OR direct facing/omnidirectional; linear system; identical conditions in both ears | Room acoustics with measurement mic at head center, PA system evaluation |
| 5.3 (Measurements at eardrum) | Linear system; identical conditions in both ears; measurements taken at eardrum (HATS or probe mic) | Hearing device evaluation, eardrum-level assessment, binaural research |

### Practical Scenario Mapping

| Scenario | Recommended Approach | Rationale |
|----------|---------------------|-----------|
| "Will speech be intelligible in this room design?" (no measurements) | Clause 5.1 -- level-only method with estimated noise and standard speech | Fastest; no equipment needed; sufficient for design-stage predictions |
| "Evaluate speech intelligibility of installed PA system" | Clause 5.2 -- IR or direct method with mic at listener head position | Captures room acoustics and system response; standard positioning |
| "Assess hearing aid benefit for a patient" | Clause 5.3 -- with InsertionGain, HearingThresholdLevel, eardrum measurement location | Models device insertion gain and listener-specific hearing loss |
| "Compare noise environments for regulatory compliance" | Clause 5.1 -- with measured noise levels per band | Standard-compliant with measured noise; speech levels from standard |
| "Evaluate classroom acoustics with measured IR" | Clause 5.2 -- IR method with measured ambient noise | Realistic room assessment; compare to ANSI S12.60 targets |
| "Assess telecom system speech quality" | Clause 5.2 -- direct method with siiExcitation through the codec | Captures codec distortion and frequency shaping |

### Measurement Positioning by Clause

**Clause 5.1 (free-field, no audio):**
- No physical microphone measurement required for the SII computation itself
- If measuring noise levels: place mic at center of listener's head position, without listener present
- Speech levels typically come from the standard (selected via VocalEffort) or custom measurements at 1 m from talker

**Clause 5.2 (free-field, at listener position):**
- Microphone at center of listener's head, mid-point between ears
- Listener must NOT be present during measurement
- Transmit excitation signal from the talker/source position
- Set `SpeechMeasurementLocation="free-field"` and `NoiseMeasurementLocation="free-field"`

**Clause 5.3 (eardrum):**
- Use a Head and Torso Simulator (HATS) designed for eardrum measurements, OR
- Probe tube microphone within 5 mm of eardrum on >=8 otologically normal subjects (age 18-30)
- Set `SpeechMeasurementLocation="eardrum"` and `NoiseMeasurementLocation="eardrum"`
- Must specify `SpeechAndNoiseLevel` when using IR or direct method with eardrum location

### Workflows Beyond the Standard

The three standard clauses do not cover every valid use case. Common non-standard workflows:

| Workflow | Approach | Key Differences from Standard Clauses |
|----------|----------|---------------------------------------|
| Hearing device evaluation (no room measurement) | Level-only method + InsertionGain + HearingThresholdLevel | Uses clause 5.1 inputs but adds device/listener parameters |
| Binaural advantage assessment | Any clause + `IsBinaural=true` | Reduces equivalent hearing threshold by 1.7 dB |
| Custom speech material weighting | Any clause + custom `BandImportanceFunction` vector | Weights bands differently than standard speech |
| Noise environment comparison (parametric) | Level-only method, vary NoiseLevel | Quick what-if analysis without re-measuring |
| In-ear monitor evaluation | Direct method + eardrum location + InsertionGain | Combines clause 5.3 positioning with device modeling |
| Classroom design for hearing-impaired | Level-only method + HearingThresholdLevel + room noise | Clause 5.1 with listener-specific hearing model |

### BandImportanceFunction Selection

The BIF weights frequency bands by their relative importance to intelligibility. Choice depends on the speech material being evaluated:

| BIF Value | Speech Material | When to Use |
|-----------|----------------|-------------|
| `"standard"` | Average English sentences | Default for most assessments -- general-purpose |
| `"NNS"` | Nonsense syllables (CVC) | When testing pure audibility without linguistic context |
| `"CID-22"` | CID Everyday Sentences | Clinical audiometry with sentence-level material |
| `"NU6"` | Northwestern University Auditory Test No. 6 | Monosyllabic word recognition testing |
| `"DRT"` | Diagnostic Rhyme Test | Military/tactical communication systems assessment |
| `"Short Passages"` | Connected discourse (paragraphs) | Lecture/presentation intelligibility; high redundancy |
| `"SPIN"` | Speech Perception in Noise sentences | Assessment in noisy environments; high-context and low-context |
| Custom vector | User-defined | Specialized material, non-English languages, music intelligibility |

**Guidance:**
- Use `"standard"` unless the assessment targets a specific test protocol
- For hearing aid fitting/evaluation, match the BIF to the clinical test material used
- For communication system certification, match the BIF to the test protocol (e.g., DRT for military standards)
- Custom vectors must have one value per band (B values) and contain at least one nonzero element -- the function normalizes so they sum to 1

### SpeechAndNoiseLevel for Standard Compliance

For IR-based and direct methods, the standard recommends specifying `SpeechAndNoiseLevel`. This corresponds to the Combined Speech and Noise Spectrum Level (CSNSL) in ANSI/ASA S3.5-1997 clauses 5.2/5.3 -- the unmodulated spectrum level of the received signal (speech + noise together) measured at the listener position or eardrum.

- Measure with a calibrated SPL meter at the listener position during normal operational conditions (speech + noise simultaneously present)
- Report as a per-band vector in dB SPL for standard compliance (scalar OASPL is accepted but may be non-compliant)
- If you cannot measure combined levels, specify `NoiseLevel` separately (the function derives E' and N' differently)

**When using the IR method with separately measured noise:** The IR captures the room's effect on speech but does not contain ambient noise. If background noise is present during operation, specify `NoiseLevel` as a per-band vector measured at the listener position with the speech source off. The function adds this noise contribution to the SII calculation. Without it, the function assumes negligible noise (-50 dB/Hz per band).

## speechIntelligibilityIndex

Three syntaxes are available. **NV arguments are syntax-specific** -- using the wrong argument for a syntax causes an error.

### Method 1: IR-based

```matlab
[ir, fs] = audioread("room_ir.wav");
sii = speechIntelligibilityIndex(ir, fs);
```

### Method 2: Direct (test signal)

```matlab
fs = 48000;
[reference, speechRef] = siiExcitation(fs, Duration=16);

% --- Transmit 'reference' through system, record 'processed' ---

% Align signals (required -- SII is more sensitive to misalignment than STI)
% alignsignals requires vector input; use finddelay on one column instead
delay = finddelay(reference(:,1), processed(:,1));
if delay > 0
    processed = processed(delay+1:end, :);
    reference = reference(1:size(processed,1), :);
elseif delay < 0
    reference = reference(-delay+1:end, :);
    processed = processed(1:size(reference,1), :);
end

sii = speechIntelligibilityIndex(processed, reference, fs);
```

### Method 3: From levels only (no audio signal)

SII can be computed from speech and noise level specifications alone:

```matlab
sii = speechIntelligibilityIndex();

sii = speechIntelligibilityIndex(Method="1/3 octave band", ...
    NoiseLevel=40, VocalEffort="raised", Distance=2);
```

### Name-Value Arguments by Syntax

**Valid for IR-based and Direct methods only:**

| Argument | Default | Purpose |
|----------|---------|---------|
| `SpeechAndNoiseLevel` | -- | Combined speech+noise level per band (dB SPL vector). Recommended for standard compliance. |
| `NoiseLevel` | -50 dB/Hz per band | Noise level -- numeric vector (dB SPL) or scalar (dB OASPL) |

**Note:** For standard-compliant SII results with the IR or Direct method, specify `SpeechAndNoiseLevel` as a per-band vector. Without it, the function uses default levels and emits a warning.

**Valid for Level-only method only:**

| Argument | Default | Purpose |
|----------|---------|---------|
| `SpeechLevel` | `"standard"` | `"standard"`, `"idealized"`, or numeric vector (dB SPL) |
| `NoiseLevel` | -50 dB/Hz per band | Noise level -- numeric vector (dB SPL) or scalar (dB OASPL) |
| `Distance` | 1 m | Talker-to-listener distance |
| `VocalEffort` | `"normal"` | `"normal"`, `"raised"`, `"loud"`, `"shout"` |

**Valid for all syntaxes:**

| Argument | Default | Purpose |
|----------|---------|---------|
| `Method` | -- | Band procedure: `"critical band"`, `"1/3 octave band"`, `"equally-contributing critical band"`, `"octave band"` |
| `InsertionGain` | 0 dB | Hearing device gain (scalar or 1-by-B vector) |
| `HearingThresholdLevel` | 0 dB HL | Listener hearing threshold (scalar or 1-by-B vector) |
| `ConductiveHearingLossLevel` | 0 dB HL | Conductive hearing loss (must be <= HearingThresholdLevel) |
| `BandImportanceFunction` | `"standard"` | `"standard"`, `"NNS"`, `"CID-22"`, `"NU6"`, `"DRT"`, `"Short Passages"`, `"SPIN"` |
| `SpeechMeasurementLocation` | `"free-field"` | `"free-field"` or `"eardrum"` |
| `NoiseMeasurementLocation` | `"free-field"` | `"free-field"` or `"eardrum"` |
| `IsBinaural` | `false` | Binaural listening advantage |

**Critical constraints:**
- `VocalEffort`, `Distance`, and `SpeechLevel` are INVALID for IR-based and Direct methods -- they cause an error
- `SpeechAndNoiseLevel` is INVALID for the Level-only method -- use `SpeechLevel` and `NoiseLevel` separately instead
- `ConductiveHearingLossLevel` must be <= `HearingThresholdLevel` in all bands

**Ask the user about:**
- What is the talker-to-listener distance? (level-only method)
- What vocal effort level? (level-only method)
- Does the listener have hearing loss? (affects HearingThresholdLevel)
- Is a hearing device being evaluated? (InsertionGain)
- What noise level is present? (measured or estimated)

### Outputs

```matlab
[sii, baf, mtf] = speechIntelligibilityIndex(ir, fs, ...
    NoiseLevel=40);
```

- `sii` -- Speech intelligibility index (0 to 1)
- `baf` -- Band audibility function (table)
- `mtf` -- Modulation transfer function (table)

## siiExcitation

```matlab
[mtfExcitation, speechExcitation, expLevels] = siiExcitation(fs, Duration=16);

mtfExcitation = siiExcitation(fs, Duration=20, ...
    VocalEffort="raised", Method="1/3 octave band");
```

The `expLevels` output provides expected speech spectrum levels for system calibration.

## Signal Alignment

`speechIntelligibilityIndex` does not perform internal alignment for the direct method. SII is more sensitive to misalignment than STI.

**Impact of misalignment (empirically measured):**

| Delay | SII Error (20s signal) |
|-------|----------------------|
| <=50 ms | 0.016 (significant) |
| 100 ms | 0.029 |
| 200 ms | 0.036 |

Always align for the direct method. Because `siiExcitation` returns an N-by-9 matrix (not a vector), use `finddelay` on one column:

```matlab
delay = finddelay(reference(:,1), processed(:,1));
if delay > 0
    processed = processed(delay+1:end, :);
    reference = reference(1:size(processed,1), :);
elseif delay < 0
    reference = reference(-delay+1:end, :);
    processed = processed(1:size(reference,1), :);
end
```

The IR-based method avoids this issue entirely -- `impzest` deconvolution handles propagation delay during IR extraction.

## Complete Workflow: Evaluate SII for Hearing Device

```matlab
sii = speechIntelligibilityIndex( ...
    Method="1/3 octave band", ...
    NoiseLevel=50, ...
    VocalEffort="normal", ...
    Distance=1, ...
    InsertionGain=gainCurve, ...
    HearingThresholdLevel=audiogram);
```

## Interpreting Results

### SII Scale

| SII Range | Interpretation |
|-----------|---------------|
| 0.75-1.00 | Speech highly intelligible; nearly all speech cues audible |
| 0.45-0.75 | Moderate intelligibility; context helps significantly |
| 0.20-0.45 | Poor intelligibility; only familiar phrases understood |
| < 0.20 | Speech essentially inaudible above the noise |

### Key Differences from STI

- SII measures **audibility** of speech given noise and hearing -- can the listener detect speech cues?
- STI measures **transmission fidelity** -- does the channel preserve modulations?
- SII can be computed without any audio (level-only method) -- just noise spectrum + speech level + hearing threshold
- SII accounts for listener hearing loss; STI does not
- SII is more appropriate for hearing device evaluation; STI is more appropriate for room/PA evaluation

### Band Audibility Function (BAF) Diagnostics

The BAF output shows the proportion of speech information audible in each frequency band (0 = completely masked, 1 = fully audible):

- **Low BAF at low frequencies:** Low-frequency noise masks speech fundamentals -- less critical for intelligibility
- **Low BAF at 1-4 kHz:** Critical concern -- these bands carry the most speech information (consonant cues)
- **Low BAF at high frequencies with normal hearing:** HF noise or air absorption
- **Low BAF at high frequencies with hearing loss:** Expected sensorineural pattern -- evaluate hearing device InsertionGain in these bands

## Troubleshooting

| Observation | Likely Cause | Action |
|-------------|-------------|--------|
| Error about invalid NV argument | Wrong argument for the syntax -- VocalEffort/Distance only valid for Level-only method | Check which syntax is being used; see constraints table above |
| SII = 1.0 (perfect) | Speech far above noise in all bands | Expected for close-range, quiet conditions with normal hearing |
| SII near 0 with moderate noise | HearingThresholdLevel too high, or noise level wrong | Verify units -- noise should be dB SPL, hearing in dB HL |
| SII doesn't change with InsertionGain | Gain doesn't overcome the hearing threshold deficit | Check that InsertionGain + SpeechLevel - NoiseLevel > HearingThresholdLevel in critical bands |
| Warning about default levels | SpeechAndNoiseLevel not specified for IR/Direct method | Provide measured per-band levels for standard-compliant results |

----

Copyright 2026 The MathWorks, Inc.

----
