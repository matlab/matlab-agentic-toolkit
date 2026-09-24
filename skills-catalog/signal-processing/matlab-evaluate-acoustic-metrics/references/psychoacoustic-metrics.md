# Psychoacoustic Metrics

Guidance for selecting and interpreting `acousticLoudness`, `acousticSharpness`, `acousticRoughness`, `acousticFluctuation`, `acousticToneToNoiseRatio`, and `acousticProminenceRatio`.

## When to Use Psychoacoustic Metrics

Psychoacoustic metrics quantify *perceived* sound characteristics that dB SPL alone cannot capture. Two sounds at the same dB level can differ dramatically in perceived loudness, annoyance, and character depending on their spectral and temporal content.

| Metric | Measures | Unit | Typical Application |
|--------|----------|------|---------------------|
| `acousticLoudness` | Perceived loudness | sone | Product sound quality, noise annoyance, automotive NVH, appliance noise |
| `acousticSharpness` | High-frequency dominance / "harshness" | acum | Alert/alarm design, product sound quality, hearing aid tuning |
| `acousticRoughness` | Rapid amplitude modulation (15–300 Hz) | asper | Engine/motor sound quality, bearing fault detection, "harshness" |
| `acousticFluctuation` | Slow amplitude modulation (up to ~20 Hz) | vacil | HVAC surging detection, engine idle quality, periodic variation |
| `acousticToneToNoiseRatio` | Tonal prominence above broadband noise | dB | Product noise regulation (ECMA-418-1), transformer hum, fan tonal noise |
| `acousticProminenceRatio` | Tonal prominence via critical band comparison | dB | IT equipment noise (ECMA-418-1), regulatory compliance |

## Intake Questions

### 1. What is the user's concern or goal?

| User Says | Metric(s) to Use |
|-----------|------------------|
| "How loud does this sound?" / "Is it too loud?" | `acousticLoudness` |
| "It sounds harsh / shrill / piercing" | `acousticSharpness` |
| "It sounds rough / buzzy / grating" | `acousticRoughness` |
| "It throbs / surges / pulsates" | `acousticFluctuation` |
| "There's a whine / hum / tone" | `acousticToneToNoiseRatio` or `acousticProminenceRatio` |
| "Overall sound quality assessment" | All four (loudness + sharpness + roughness + fluctuation) |
| "Compare two products" | Run same metrics on both; compare values |
| "Does this meet noise regulations?" | Check which standard applies — may need tonality metrics for penalty assessment |

### 2. Calibration

All psychoacoustic metrics require calibrated input for absolute values. Ask:
- Do they have a CalibrationFactor? (3rd positional argument, default `sqrt(8)`)
- If they only need *relative* comparison between sounds (not absolute sones/acum), calibration is less critical — but the same factor must be used for both

### 3. Sound field

- **Free field** (`"free"`): Outdoor, anechoic chamber, or close-mic recordings without room reflections
- **Diffuse field** (`"diffuse"`): Reverberant rooms, typical indoor recordings
- **Earphones** (`"earphones"`): Headphone playback — requires `EarphoneResponse` for `acousticLoudness`
- **Eardrum** (`"eardrum"`): Signal already represents the pressure at the eardrum (e.g., from a probe mic)

Default is `"free"`. Using the wrong sound field introduces ~2–5 phon error in loudness.

### 4. Time-varying analysis?

- **Stationary sounds** (fans, HVAC steady-state, continuous tones): Single-value output is appropriate
- **Transient or varying sounds** (engine run-up, door slam, tool operation): Time-varying analysis reveals how perception changes over time

Only `acousticLoudness` with `Method="ISO 532-1"` supports `TimeVarying=true`. ISO 532-2 is stationary only. `acousticSharpness` also supports `TimeVarying=true`.

## acousticLoudness — Method Selection

### ISO 532-1 (Zwicker) vs ISO 532-2 (Moore-Glasberg)

| Aspect | ISO 532-1 | ISO 532-2 |
|--------|-----------|-----------|
| Basis | Critical-band rate (Bark scale) | Auditory filter shapes (ERB scale) |
| Time-varying | Yes (`TimeVarying=true`) | No (stationary only) |
| Low-frequency precision | Less precise below ~200 Hz | Improved low-frequency model |
| Low-level accuracy (< 40 phon) | Good | Better |
| Tonal / line-spectral sounds | Adequate | More accurate (sharper auditory filters) |
| Binaural (different signal at each ear) | Not supported | Supported |
| Industry adoption | Most widely used; default for most standards | Growing adoption; required by some automotive OEMs |
| Established since | 1975 (revised 2017) | 2017 |

### When to Use Each

| Scenario | Recommended Method |
|----------|-------------------|
| Time-varying analysis (engine run-up, transients) | ISO 532-1 (only option) |
| General product sound quality | ISO 532-1 (industry standard, most comparable to existing data) |
| Automotive NVH (unless OEM specifies otherwise) | ISO 532-1 |
| Accurate loudness at low levels (< 40 phon) | ISO 532-2 |
| Tonal sounds where spectral detail matters | ISO 532-2 |
| Regulatory compliance that specifies ISO 532-2 | ISO 532-2 |
| Comparing to legacy measurements | ISO 532-1 (historical data uses Zwicker) |
| Unsure / no specific requirement | ISO 532-1 (default, more widely understood) |

### Key Differences in Practice

- At moderate-to-high levels (> 40 phon), both methods give similar results (within ~5%)
- Below 40 phon, ISO 532-2 gives more accurate results because its auditory filter model better represents low-level hearing
- For narrowband/tonal sounds, ISO 532-2 can give different (typically more accurate) specific loudness patterns because ERB filters have better frequency resolution than Bark bands
- Time-varying loudness (ISO 532-1 only) uses a 2 ms temporal resolution with attack/decay modeling — essential for impulsive or transient sounds

### Interpreting Loudness Values

| Loudness (sone) | Subjective Impression | Example |
|-----------------|----------------------|---------|
| 1 | Reference (40 phon = 1 sone) | Quiet library |
| 2 | Twice as loud as 1 sone | Quiet office |
| 4 | Twice as loud as 2 sone | Normal conversation at 1 m |
| 8 | Twice as loud as 4 sone | Busy restaurant |
| 16 | Twice as loud as 8 sone | Vacuum cleaner at 1 m |
| 32+ | Very loud | Power tools, loud music |

**Key property:** Doubling of sone value = doubling of perceived loudness. This is the primary advantage over dB: a +10 dB increase roughly doubles loudness, but this depends on frequency and level. Sones capture the actual perceptual doubling.

### Specific Loudness

The second output of `acousticLoudness` is specific loudness — loudness distributed across critical bands. Use it to identify *which frequencies contribute most* to the overall loudness:

- Peaks in specific loudness → dominant frequency regions of the sound
- Comparing specific loudness patterns between products shows where one sounds louder
- Feed specific loudness into `acousticSharpness`, `acousticFluctuation`, or `acousticRoughness` for consistent analysis (avoids recomputation). This is only valid when loudness uses ISO 532-1 (the default) — sharpness, fluctuation, and roughness are defined on the Bark-band specific loudness of ISO 532-1, not the ERB-band output of ISO 532-2.

## acousticSharpness — Guidance

### What Sharpness Measures

Sharpness quantifies the proportion of high-frequency energy in the specific loudness pattern. A sound with more energy above ~3 kHz relative to lower frequencies will have higher sharpness.

| Sharpness (acum) | Subjective Impression | Example |
|------------------|----------------------|---------|
| 0.5–1.0 | Dull, warm | Low-frequency fan hum |
| 1.0–1.5 | Neutral | Broadband noise |
| 1.5–2.5 | Sharp, bright | High-speed drill, alarm |
| > 2.5 | Very sharp, piercing | Metal-on-metal, high-pitch alert |

### Weighting Methods

- **DIN 45692** (default): Standard method, most common
- **Aures**: Accounts for loudness level — sharpness decreases at low levels (more perceptually accurate)
- **von Bismarck**: Original empirical method, legacy use

Use DIN 45692 unless the user has a specific reason for another method.

### When Sharpness Matters

- **Alert/alarm design:** Sharpness > 1.5 acum helps signals cut through background noise, but > 3.0 can be painful
- **Product sound quality:** Lower sharpness is generally preferred (sounds "warmer" and less fatiguing)
- **Hearing aid fitting:** Excessive sharpness indicates too much HF gain
- **Vehicle interior:** Sharpness contributes to perceived quality — premium vehicles target low sharpness

## acousticRoughness — Guidance

### What Roughness Measures

Roughness quantifies perception of rapid amplitude modulation in the 15–300 Hz range (with peak sensitivity around 70 Hz). It corresponds to a "buzzing" or "grating" quality.

| Roughness (asper) | Subjective Impression | Example |
|-------------------|----------------------|---------|
| < 0.2 | Smooth | Pure tone, steady broadband noise |
| 0.2–0.5 | Slightly rough | Some electric motors |
| 0.5–1.0 | Moderately rough | Diesel engine idle, small power tools |
| > 1.0 | Very rough | Unbalanced machinery, bearing defects |

### When Roughness Matters

- **Engine/motor sound quality:** Roughness is a primary contributor to "harshness" perception in automotive NVH
- **Bearing fault detection:** Developing faults create amplitude modulation at characteristic frequencies → increased roughness
- **Electric vehicle noise:** Without engine masking, EV motor roughness becomes audible and annoying
- **Product quality comparison:** Lower roughness generally correlates with higher perceived quality

### Modulation Frequency Output

The third output `fMod` reports the detected modulation frequency. This is diagnostically valuable:
- fMod near rotational frequencies → imbalance or eccentricity
- fMod at gear mesh frequencies → gear noise
- fMod at blade-pass frequency → fan/compressor

## acousticFluctuation — Guidance

### What Fluctuation Strength Measures

Fluctuation strength quantifies perception of slow amplitude modulation below ~20 Hz (peak sensitivity at 4 Hz). It corresponds to a "throbbing" or "wah-wah" quality.

| Fluctuation (vacil) | Subjective Impression | Example |
|---------------------|----------------------|---------|
| < 0.1 | Steady | Constant fan noise |
| 0.1–0.3 | Slight pulsation | Some HVAC systems |
| 0.3–0.5 | Noticeable throbbing | Engine idle, rotating equipment |
| > 0.5 | Strong pulsation | Helicopter rotor, severe HVAC surging |

### Relationship to RNC

Fluctuation strength and Room Noise Criteria (RNC) address similar phenomena from different perspectives:
- `acousticFluctuation` gives a psychoacoustic metric (vacil) for any sound
- `roomNoiseCriteria` gives a noise compliance rating that penalizes fluctuation in the context of background noise

If `acousticFluctuation` is elevated AND the noise is background HVAC, suggest also running `roomNoiseCriteria` for a compliance-oriented assessment.

### When Fluctuation Matters

- **HVAC complaints:** "The noise seems to come and go" → measure fluctuation strength. If > 0.1 vacil, fluctuation is likely the annoyance driver (even if overall level is low).
- **Engine idle quality:** Low fluctuation is a target for premium vehicles
- **Periodic noise sources:** Anything with a repetition rate of 0.5–20 Hz will register as fluctuation

## Tonality Metrics — Guidance

### acousticToneToNoiseRatio vs acousticProminenceRatio

| Aspect | Tone-to-Noise Ratio (TNR) | Prominence Ratio (PR) |
|--------|---------------------------|----------------------|
| Standard | ECMA-418-1 | ECMA-418-1 |
| Method | Compares tone power to noise in critical bandwidth | Compares critical band power to adjacent bands |
| Best for | Detecting discrete tones in broadband noise | Detecting tonal prominence in shaped spectra |
| Regulation | Common in EU product noise directives | Common for IT equipment |
| Penalty threshold | TNR > 6 dB → tone is prominent | PR > 9 dB → tone is prominent |

### When to Use Tonality Metrics

- **Product noise certification:** Many regulations (EU Machinery Directive, outdoor equipment) apply a tonal penalty (+5 dB or K-factor) when prominent tones are detected
- **Transformer/power supply hum:** Detect and quantify 50/60 Hz or harmonic tones
- **Fan noise:** Blade-pass frequency tones often trigger tonality penalties
- **Quality control:** Detect emerging tonal defects in manufacturing (new bearings shouldn't have tones)

### Interpreting Results

Both functions return empty arrays when no tonal components are detected — always check `isempty(tnr)` before indexing.

The `isProminent` output directly answers the regulatory question: does this tone exceed the prominence threshold?

- **TNR > 6 dB:** Prominent per ECMA-418-1 — tonal penalty applies
- **PR > 9 dB:** Prominent per ECMA-418-1 — tonal penalty applies
- **Multiple tones detected:** Each is reported separately; the most prominent drives the penalty

### Frequency Information

The `tnrFreq` / `prFreq` outputs identify where each detected tone sits. Use this to:
- Trace the tone back to a physical source (e.g., 120 Hz = 2× mains frequency → power supply)
- Target mitigation (notch filter, vibration isolation at that frequency)
- Monitor whether a tone shifts frequency under load (indicates speed-dependent source)

## Sound Quality Assessment — Combined Metrics

For comprehensive product sound quality evaluation, compute all four metrics and interpret together:

| Metric | Target Direction | Rationale |
|--------|-----------------|-----------|
| Loudness | Lower | Quieter products preferred (unless loudness signals power/performance) |
| Sharpness | Lower | Less fatiguing, perceived as higher quality |
| Roughness | Lower | Smoother operation, fewer vibration issues |
| Fluctuation | Lower | Steadier, more predictable |

**Exception:** Some products intentionally target specific psychoacoustic signatures (e.g., sports car exhaust aims for moderate roughness to convey "power"). In these cases, the target is a specific *profile*, not simply "minimize all."

### Psychoacoustic Annoyance (PA)

Zwicker's psychoacoustic annoyance combines loudness, sharpness, fluctuation, and roughness into a single scalar [1]:

```
PA = N5 * (1 + sqrt(wS^2 + wFR^2))
```

where:
- `N5` — percentile loudness in sones (level exceeded 5% of the time)
- `wS = (S - 1.75) * 0.25 * log10(N5 + 10)` for S > 1.75 acum; otherwise `wS = 0`
- `wFR = (2.18 / N5^0.4) * (0.4*F + 0.6*R)` where F is fluctuation (vacil), R is roughness (asper)

**Extracting N5:** Call `acousticLoudness` with `TimeVarying=true`. The third output (`perc`) contains percentile loudness; with default `Percentiles=[0,5]`, `perc(2)` is N5.

```matlab
% Stationary loudness for sharpness
[~, specStationary] = acousticLoudness(x, fs, calib);
S = acousticSharpness(specStationary);

% Time-varying loudness for N5, fluctuation, roughness
[~, specHD, perc] = acousticLoudness(x, fs, calib, TimeVarying=true, TimeResolution="high");
spec = specHD(1:4:end,:,:); % standard resolution for fluctuation
N5 = perc(2);
vacil = acousticFluctuation(spec);
asper = acousticRoughness(specHD); % roughness needs high resolution

F = mean(vacil(:,1));
R = mean(asper(:,1));

wS = 0;
if S > 1.75
    wS = (S - 1.75) * 0.25 * log10(N5 + 10);
end
wFR = (2.18 / N5^0.4) * (0.4*F + 0.6*R);
PA = N5 * (1 + sqrt(wS^2 + wFR^2));
```

**PAT (annoyance with tonality):** For tonal noise (engines, transformers), More [2] extended the formula to include tonality:

```
PAT = N5 * (1 + sqrt(γ0 + γ1*wS^2 + γ2*wFR^2 + γ3*wT^2))
```

where `wT^2 = (1 - exp(γ4*N5))^2 * (1 - exp(γ5*K5))^2`, `K5` is the 5th percentile prominence ratio, and constants are γ0 = −0.16, γ1 = 11.48, γ2 = 0.84, γ3 = 1.25, γ4 = 0.29, γ5 = 5.49. If no prominent tone is detected, use PA (without tonality).

**References:**
1. Zwicker, E. and Fastl, H. *Psychoacoustics: Facts and Models*. Springer, 2013.
2. More, S. R. *Aircraft noise characteristics and metrics* (thesis), 2010, pp. 201–204.

### Typical Workflow

1. Record the product under standardized operating conditions
2. Compute all four metrics (same CalibrationFactor and SoundField for consistency)
3. Compute psychoacoustic annoyance (PA or PAT) as a single-number summary
4. Compare to competitor products or previous product generations
5. Identify which metric is the primary differentiator
6. Use specific loudness / modulation frequency to trace the physical source

----

Copyright 2026 The MathWorks, Inc.

----
