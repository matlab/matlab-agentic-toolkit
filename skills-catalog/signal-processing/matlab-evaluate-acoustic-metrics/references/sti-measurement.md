# STI Measurement

## Intake Questions

### 1. What is the application?

Target STI values from IEC 60268-16 Table G.1 and application-specific standards:

| Application | Target STI | Standard/Regulation |
|-------------|-----------|---------------------|
| Voice alarm / emergency PA | >= 0.50 | IEC 60268-16 Table G.1 (Cat. G); EN 54-16, BS 5839-8 |
| Classroom / lecture hall | >= 0.62 | IEC 60268-16 Table G.1 (Cat. D); BB93 (UK), ANSI S12.60 |
| Courtroom / parliament | >= 0.70 | IEC 60268-16 Table G.1 (Cat. B) |
| Teleconferencing | >= 0.66 | IEC 60268-16 Table G.1 (Cat. C) |
| Recording studio / broadcast | > 0.76 | IEC 60268-16 Table G.1 (Cat. A+) |
| PA in difficult acoustic environments | >= 0.46 | IEC 60268-16 Table G.1 (Cat. H) |

### 2. What measurement method should they use?

| Scenario | Recommended Method | Rationale |
|----------|-------------------|-----------|
| Room acoustics simulation | IR (indirect) | Fastest; works directly with simulated or measured IRs |
| PA/VA system commissioning | Direct STIPA | IEC 60268-16 Annex B recommended; captures nonlinear behavior |
| System with AGC, compression, or limiting | Direct STIPA | IR method assumes linearity -- invalid for nonlinear systems |
| Lab reference measurement | Direct Full STI | Maximum precision (all 98 modulation frequencies) |
| Comparing rooms from IR databases | IR (indirect) | Quick what-if analysis; vary noise without re-measuring |
| Digital codec or telecom evaluation | Direct STIPA | Captures codec distortion the IR method cannot |
| Fluctuating industrial noise | Direct (with caution) | All methods have limited accuracy with time-varying noise |

**Limitations of indirect (IR) methods:** The IR method cannot capture the effect of ambient noise directly -- noise must be added mathematically to the MTF after measurement (see Post-Processing Adjustment Workflow below). Always measure in silence when using the IR method, then specify operational noise via `OperationalNoiseLevel`.

### 3. Do they have an impulse response or will they measure?

- **Have an IR:** Use the IR method -- simpler, no alignment needed, fastest
- **Will measure live:** Generate test signal with `stipaExcitation`, transmit through system, record, align, compute
- **Simulated room:** Use `acousticRoomResponse` to get an IR, then use the IR method

### 4. What are the operational conditions?

These significantly affect the result -- ask about:
- **Ambient noise level:** What NC rating (or octave-band levels) is expected during normal operation? Default is NC-35. Changing from NC-25 to NC-45 can reduce STI by 0.10-0.20.
- **Speech level:** Normal voice (60 dBA at 1 m) is the default. Raised voice changes the spectral shape and typically improves STI.
- **Auditory effects:** Should auditory masking be included? (Default: yes.) Disabling gives the "physical" STI without listener hearing model.

### 5. Measurement conditions (for direct method)

- **Sample rate:** >=16 kHz required; 48 kHz recommended
- **Signal duration:** >=15 s for STIPA (default 18 s provides margin)
- **Signal level:** STIPA test signal should be played at 3 dB above measured speech LAeq at the mic position (IEC 60268-16 clause 5.1 / Annex J)
- **Background noise:** Measure ambient noise with system off before the STI measurement
- **Multiple positions:** Measure at representative listener positions; report worst-case STI per zone
- **HVAC:** Ensure all building systems in normal operating state during measurement

## speechTransmissionIndex

Two syntaxes are available. All NV arguments work with both syntaxes.

### Method 1: IR-based

Compute STI directly from a room impulse response. No alignment needed. The IR must be at least 1.6 seconds long (the period of the lowest modulation frequency, 0.63 Hz).

```matlab
[ir, fs] = audioread("room_ir.wav");
sti = speechTransmissionIndex(ir, fs);
```

To obtain the impulse response: use `sweeptone` to generate a sine sweep, play it through the system, record the response, then extract the IR with `impzest`. See `matlab-play-record-audio` for the device I/O workflow.

### Method 2: Direct (test signal)

Transmit a test signal through the system and compute STI from the received signal. Two test signal types are available:

| Type | Signal Shape | Duration | Precision |
|------|-------------|----------|-----------|
| `"Direct STIPA"` | Column vector (N-by-1) | ~15 s minimum | 14 modulation frequencies (2 per band) |
| `"Direct Full STI"` | N-by-14-by-7 array | ~15 min total | All 98 modulation frequencies |

**STIPA (faster, most common):**

```matlab
fs = 48000;
reference = stipaExcitation(fs, Duration=15, Type="Direct STIPA");

% --- Transmit 'reference' through system, record 'processed' ---

% Align signals (required -- function does not align internally)
processed = alignsignals(processed, reference);

sti = speechTransmissionIndex(processed, reference, fs);
```

**Full STI (maximum precision):**

```matlab
fs = 48000;
reference = stipaExcitation(fs, Duration=15, Type="Direct Full STI");

% --- Transmit 'reference' through system, record 'processed' ---

processed = alignsignals(processed, reference);

sti = speechTransmissionIndex(processed, reference, fs);
```

For both types, the processed signal must have the same dimensions as the reference.

### Name-Value Arguments (both syntaxes)

| Argument | Default | Purpose |
|----------|---------|---------|
| `OperationalSignalLevel` | `60 + [-2.5 0.5 0 -6 -12 -18 -24]` | Expected speech level per octave band (dB) |
| `OperationalNoiseLevel` | `"NC-35"` | Ambient noise -- string (`"NC-xx"`, `"RNC-xx"`, or `"RC-xx"`) or 1-by-7 vector (dB). String input requires R2026b+; earlier releases require the vector form. |
| `AddOperationalAmbientNoise` | `true` | Add ambient noise to MTF computation |
| `AddOperationalAuditoryContributions` | `true` | Add auditory masking and threshold effects |
| `RawSignalLevel` | -- | Measured signal level per band (dB) |
| `RawNoiseLevel` | -- | Measured noise level per band (dB) |
| `RemoveRawAmbientNoise` | `false` | Remove ambient noise from raw measurement |
| `RemoveRawAuditoryContributions` | `false` | Remove auditory effects from raw measurement |

**Constraints:**
- `RawSignalLevel` and `RawNoiseLevel` must be specified together (both or neither)
- `RemoveRawAmbientNoise=true` requires both `RawSignalLevel` and `RawNoiseLevel` to be set
- `RemoveRawAuditoryContributions=true` requires both `RawSignalLevel` and `RawNoiseLevel` to be set

### Post-Processing Adjustment Workflow (IEC 60268-16 Annex M)

The NV arguments implement the post-processing steps from Table M.1 of the standard. The midpoint of the process is deriving an MTF free of ambient noise and auditory effects -- then adding back the desired operational conditions.

**Select the workflow based on measurement conditions:**

| Measurement Condition | What to Set | Why |
|---|---|---|
| **Measured in silence** (ideal) | `OperationalNoiseLevel`, `OperationalSignalLevel` | MTF is already free of noise -- just add operational conditions (Step 5) |
| **Measured with ambient noise present** | `RemoveRawAmbientNoise=true`, `RawSignalLevel`, `RawNoiseLevel`, then operational args | Remove measured noise (Step 4), then add operational conditions (Step 5) |
| **Measured with auditory model already applied** | `RemoveRawAuditoryContributions=true`, `RawSignalLevel`, `RawNoiseLevel`, then operational args | Remove old auditory effects (Step 3), optionally remove noise (Step 4), then add new conditions (Step 5) |
| **Simulating different operational conditions** | Change `OperationalNoiseLevel` and/or `OperationalSignalLevel` | Simulate operational conditions with alternative speech/noise levels without re-measuring |

**Recommended practice:** Measure the MTF in silence (test signal only, no ambient noise), then separately measure the operational noise level. This gives the cleanest starting point -- the function adds operational noise and auditory effects via `AddOperationalAmbientNoise` and `AddOperationalAuditoryContributions` (both default to `true`). If the MTF cannot be measured in silence, separately measure background noise levels per octave band so they can be removed.

**Ask the user about:**
- What is the expected operational noise level? (NC rating or octave-band levels)
- What speech level is expected? (default assumes normal speech at 1 m)
- Should auditory masking effects be included? (default: yes)
- Were the measurements taken in silence, or was ambient noise present during measurement?

### Outputs

```matlab
[sti, mti, mtf] = speechTransmissionIndex(ir, fs, ...
    OperationalNoiseLevel="NC-40");
```

- `sti` -- Speech transmission index (0 to 1)
- `mti` -- Modulation transmission index (table with per-band values)
- `mtf` -- Modulation transfer function (table)

## stipaExcitation

```matlab
% STIPA signal (default -- single merged signal)
reference = stipaExcitation(fs, Duration=15, Type="Direct STIPA");

% Full STI signal (all 98 modulation frequencies)
reference = stipaExcitation(fs, Duration=15, Type="Direct Full STI");
```

STIPA uses a subset of modulation frequencies for faster measurement (~15 seconds minimum). Full STI uses all 98 combinations (14 modulation frequencies x 7 octave bands) for maximum accuracy.

## Signal Alignment

`speechTransmissionIndex` does not perform internal alignment for the direct method.

**Impact of misalignment (empirically measured):**

| Delay | STI Error (15s STIPA) |
|-------|----------------------|
| <=50 ms | <0.001 (negligible) |
| 100 ms | 0.004 |
| 200 ms | 0.017 |
| 500 ms | 0.046 (10s signal) |

Always align for the direct method:

```matlab
processed = alignsignals(processed, reference);
```

The IR-based method avoids this issue entirely -- `impzest` deconvolution handles propagation delay during IR extraction.

## Complete Workflow: Measure STI in a Room

```matlab
fs = 48000;

% Generate test signal
reference = stipaExcitation(fs, Duration=15);

% Play through room and record (see matlab-play-record-audio for device I/O)
% processed = <recorded signal>

% Align
processed = alignsignals(processed, reference);

% Compute STI with operational conditions
[sti, mti] = speechTransmissionIndex(processed, reference, fs, ...
    OperationalNoiseLevel="NC-40", ...
    AddOperationalAuditoryContributions=true);

fprintf("STI = %.2f\n", sti);
```

## Interpreting Results

### Interpreting STI (IEC 60268-16 Table G.1)

For a native listener with no hearing impairment:

| Category | Nominal STI | Comment |
|----------|-------------|---------|
| A+ | > 0.76 | Excellent intelligibility |
| A | 0.74 | High intelligibility |
| B | 0.70 | High intelligibility |
| C | 0.66 | High intelligibility |
| D | 0.62 | Good intelligibility |
| E | 0.58 | High quality public address systems |
| F | 0.54 | Good quality public address systems |
| G | 0.50 | Target value for voice alarm systems |
| H | 0.46 | Lower limit for voice alarm systems |
| I | 0.42 | Limited intelligibility |
| J | 0.38 | Not suitable for public address systems |
| U | < 0.36 | Not suitable for public address systems |

### Using MTI for Diagnostics

The per-band Modulation Transfer Index reveals *where* intelligibility is being lost:

| Low MTI Location | Likely Cause | Remediation |
|------------------|-------------|-------------|
| Low frequencies (125-250 Hz) | Excessive low-frequency reverberation or rumble noise | Add low-frequency absorption; isolate HVAC vibration |
| Mid frequencies (500-2000 Hz) | General reverberance problem -- most critical for intelligibility | Add broadband absorption; reduce RT60 |
| High frequencies (4000-8000 Hz) | Air absorption, poor HF loudspeaker coverage, or HVAC hiss | Improve speaker positioning; treat HF noise sources |
| Uniform across all bands | High ambient noise floor overwhelming the signal | Reduce noise or increase signal level (loudspeaker power) |

### RT60-to-STI Rule of Thumb

Approximate STI for purely diffuse exponential-decay rooms with no ambient noise (computed using `speechTransmissionIndex` on synthetic IRs with `AddOperationalAmbientNoise=false`):

| RT60 (s) | Approximate STI |
|-----------|----------------|
| 0.5 | 0.74 |
| 1.0 | 0.60 |
| 1.5 | 0.50 |
| 2.0 | 0.44 |
| 3.0 | 0.36 |
| 5.0 | 0.27 |

Adding ambient noise can only reduce STI below these values.

### Effect of Noise Curve on STI

Changing the operational noise has a dramatic effect. The magnitude depends on the room — drier rooms (lower RT60) are more sensitive to noise because modulations are better preserved before noise is added. Computed using `speechTransmissionIndex` on synthetic diffuse-decay IRs:

| Noise Condition | STI Reduction (RT60=0.5s) | STI Reduction (RT60=1.0s) |
|-----------------|---------------------------|---------------------------|
| NC-25 | Reference | Reference |
| NC-35 | -0.06 | -0.04 |
| NC-45 | -0.22 | -0.16 |
| NC-55 | -0.47 | -0.37 |
| NC-65 | -0.68 | -0.55 |

## Troubleshooting

| Observation | Likely Cause | Action |
|-------------|-------------|--------|
| STI too high (> 0.9) for a reverberant room | Operational corrections not applied | Verify `AddOperationalAmbientNoise=true` and `AddOperationalAuditoryContributions=true` (both default to true) |
| STI too low for a quiet, dry room | Noisy IR (background noise in the recording) | Use direct STIPA method, or re-record IR with higher SNR (need >=20 dB) |
| STIPA and IR method disagree by > 0.05 | System is nonlinear (AGC, compression) | Trust STIPA for real-world condition; IR method is invalid for nonlinear systems |
| MTF values > 1.0 reported | Noise contamination during direct measurement | Values are clipped internally, but if many exceed 1.3, re-measure (impulsive noise likely) |
| STI varies significantly across positions | Normal for large rooms -- coverage is non-uniform | Report worst-case per position; investigate speaker aiming |
| IR method gives STI = 0 | IR is likely all zeros or wrong channel | Verify IR has energy: `max(abs(ir))` should be > 0 |
| Direct method gives very low STI with correct signal | Signals not aligned, or reference type mismatch | Verify alignment with `alignsignals`; ensure `stipaExcitation` Type matches |

----

Copyright 2026 The MathWorks, Inc.

----
