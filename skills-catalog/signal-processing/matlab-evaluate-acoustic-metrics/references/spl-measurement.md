# SPL Measurement

Guidance for selecting parameters, interpreting results, and guiding user workflows for `splMeter`.

## Intake Questions

### 1. What is the measurement purpose?

| Purpose | Frequency Weighting | Time Weighting | Key Output |
|---------|-------------------|----------------|------------|
| Occupational noise exposure (hearing protection) | A-weighting | Slow | Leq (8-hour TWA) |
| Environmental noise monitoring | A-weighting | Fast | Leq, Lmax |
| Peak assessment (impulse hazard) | C-weighting | — | Lpeak |
| Product noise testing (to spec sheet) | A-weighting | — | Leq |
| Machinery noise for NC/RC compliance | Z-weighting | Fast | Octave-band Leq |
| Regulatory environmental limit | Depends on regulation | Depends on regulation | Varies |
| Building acoustics (background noise) | Z-weighting | Fast | Octave-band Leq → pass to `noiseCriteria` |
| General "how loud is it?" | A-weighting | Fast | Leq |

### 2. Frequency weighting selection

| Weighting | What it does | When to use |
|-----------|-------------|-------------|
| A-weighting | Approximates human hearing sensitivity at moderate levels; attenuates low frequencies | Most general-purpose measurements, occupational noise, environmental noise, product noise specs |
| C-weighting | Flatter response; mild LF roll-off below 31.5 Hz | Peak measurements (Cpeak), high-level noise (>100 dB), assessing low-frequency content, some regulatory requirements |
| Z-weighting | Flat (no filtering) — raw acoustic pressure level | Octave-band analysis for NC/RC/RNC, feeding into compliance functions, when you need unweighted per-band levels, research |

**Guidance:**
- If the user says "dB" without qualification, they likely mean dB(A) — confirm
- If they need octave-band levels for noise compliance, use Z-weighting (the compliance functions apply their own corrections)
- C-weighting for peak is standard in occupational noise (IEC 61672 specifies C-peak for impulse hazard)
- A-weighting underestimates the perceived loudness of low-frequency noise — if the user complains about "rumble" but A-weighted levels seem low, suggest octave-band analysis or C-weighting

### 3. Time weighting selection

| Time Weighting | Time Constant | Behavior | When to use |
|----------------|---------------|----------|-------------|
| Fast | 125 ms attack/release | Tracks fluctuations; standard for most measurements | General purpose, environmental monitoring, product testing |
| Slow | 1000 ms attack/release | Smoothed; averages short-term fluctuation | Occupational noise exposure, stable environments, when fast readings fluctuate too much to read |
| Custom | User-defined | For specialized standards | Rarely needed; specific regulatory or research requirements |

**Guidance:**
- Default to Fast unless the user has a specific reason for Slow
- If levels fluctuate rapidly and the user wants a single characterization, Leq (equivalent continuous level) is more meaningful than any single time-weighted reading
- For impulsive noise (hammering, gunfire), neither Fast nor Slow captures the peak — use Lpeak output

### 4. Bandwidth selection

| Bandwidth | Output columns | When to use |
|-----------|---------------|-------------|
| `"Full band"` | 1 (overall level) | Quick overall SPL, occupational noise, simple monitoring |
| `"1 octave"` | 1 per octave band | NC/RC/RNC input, spectral diagnosis of noise sources, building acoustics |
| `"1/3 octave"` | 1 per 1/3-octave band | Detailed spectral analysis, product noise standards, transmission loss |
| `"2/3 octave"` | 1 per 2/3-octave band | Rarely used; specific legacy standards |

**Guidance:**
- If the goal is noise compliance (NC/RC/RNC), use `"1 octave"` with Z-weighting — the compliance functions expect octave-band Leq
- If the goal is a single number (occupational, environmental), use `"Full band"`
- If the user wants to "see what frequencies are loud," use `"1 octave"` or `"1/3 octave"`

### 5. Calibration

Ask about the full signal chain:
- **Recording device:** What mic/interface was used? What is the sensitivity?
- **Calibration method:** Did they use a pistonphone or physical SPL meter for system calibration?
- **CalibrationFactor:** Do they already have one? If not, see the Calibration section in SKILL.md

If calibration is unknown and absolute levels are needed, the measurement is unreliable. Recommend:
1. Re-record with a calibration reference, OR
2. Use `calibrateMicrophone` with a known-SPL reference tone recording

For *relative* comparisons (before/after, product A vs B), calibration matters less as long as the same setup is used for both recordings.

### 6. Multichannel input

`splMeter` accepts matrix input where each column is an independent channel. For multichannel:
- `CalibrationFactor` can be a vector (one value per channel)
- Outputs become 3D arrays when using octave/fractional-octave bandwidth: L-by-B-by-C (samples × bands × channels)
- Each channel is metered independently

## splMeter vs poctave

Both `splMeter` and `poctave` compute octave-band levels. They produce identical results when filter orders match:

```matlab
% These are equivalent:
spl = splMeter(SampleRate=fs, Bandwidth="1 octave", FrequencyWeighting="Z-weighting", ...
    OctaveFilterOrder=2, CalibrationFactor=1, TimeInterval=duration);
[~, Leq] = spl(x);
levels_splMeter = Leq(end,:);

[p, cf] = poctave(x, fs, "power", BandsPerOctave=1, FilterOrder=2);
levels_poctave = 10*log10(p' / (2e-5)^2);
```

The default filter orders differ — `splMeter` uses `OctaveFilterOrder=2`, `poctave` uses `FilterOrder=6`. This causes ~1–2 dB differences if not matched.

### TimeInterval and Leq accumulation

`splMeter` resets its Leq accumulation at each `TimeInterval` boundary. If the signal length is not an integer multiple of `TimeInterval`, the last interval is shorter. To compute overall Leq from per-interval values, duration-weight the energy sum:

```matlab
% Wrong: treats partial last interval as a full interval
Leq_wrong = 10*log10(mean(10.^(Leq_intervals/10)));

% Correct: weight by actual interval duration
Leq_correct = 10*log10((1/T_total) * sum(t_i .* 10.^(L_i/10)));
```

To avoid this issue entirely, set `TimeInterval` to the full signal duration — then `Leq(end,:)` is the overall Leq directly.

## Interpreting SPL Results

### Overall Sound Pressure Levels

| dB(A) | Environment / Source | Subjective Impression |
|-------|---------------------|----------------------|
| 20–30 | Quiet bedroom, recording studio | Very quiet; barely audible |
| 30–40 | Quiet library, rural ambient | Quiet; comfortable |
| 40–50 | Quiet office, residential area at night | Moderate; noticeable |
| 50–60 | Normal conversation at 1 m, office | Clearly audible; may interfere with concentration |
| 60–70 | Busy restaurant, TV audio | Loud; raised voice needed for speech |
| 70–80 | Vacuum cleaner, busy traffic | Very loud; prolonged exposure fatiguing |
| 80–85 | Power tools, loud music | Hearing protection threshold (occupational) |
| 85–90 | Heavy machinery, motorcycle | OSHA action level; hearing damage begins |
| 90–100 | Lawn mower, band rehearsal | Painful without protection |
| 100–120 | Chainsaw, rock concert, jet takeoff at distance | Immediate hearing damage risk |
| >120 | Threshold of pain, close to explosion | Physical pain; acoustic trauma |

### Occupational Noise Exposure Limits

| Standard | Permissible Exposure Limit (8h TWA) | Action Level |
|----------|-------------------------------------|--------------|
| OSHA PEL (USA) | 90 dB(A) | 85 dB(A) |
| NIOSH REL (USA) | 85 dB(A) | — |
| EU Directive 2003/10/EC | 87 dB(A) | 80 dB(A) (lower) / 85 dB(A) (upper) |
| ISO 1999:2013 | 85 dB(A) (recommended) | — |

**Halving/doubling rule:** For every 3 dB increase (NIOSH/EU) or 5 dB increase (OSHA), permissible exposure time halves:
- NIOSH: 85 dB → 8h, 88 dB → 4h, 91 dB → 2h, 94 dB → 1h
- OSHA: 90 dB → 8h, 95 dB → 4h, 100 dB → 2h, 105 dB → 1h

### Environmental Noise Limits (Typical)

These vary by jurisdiction. Common residential limits:

| Time Period | Typical Limit | Standard/Regulation |
|------------|---------------|---------------------|
| Daytime (7am–10pm) | 55 dB(A) Leq | WHO guidelines, many local codes |
| Nighttime (10pm–7am) | 45 dB(A) Leq | WHO guidelines |
| Lmax nighttime | 60 dB(A) | WHO sleep disturbance threshold |

Always ask the user which specific regulation they're working to — limits vary significantly by location and zone (residential, commercial, industrial).

### Peak Level Interpretation

| Lpeak dB(C) | Risk |
|-------------|------|
| < 135 | Generally safe for single events |
| 135–140 | EU upper exposure action value — hearing protection mandatory |
| > 140 | Immediate acoustic trauma risk |

### Output Metric Selection

| User's Question | Which Output to Report |
|-----------------|----------------------|
| "What's the noise level?" | Leq (time-averaged level — single representative value) |
| "How loud does it get?" | Lmax (maximum level during measurement) |
| "Is there an impulse hazard?" | Lpeak (true peak pressure, unweighted by time constant) |
| "What does the level look like over time?" | Lt (time-weighted instantaneous level — use downsampled intervals) |
| "8-hour exposure?" | Leq over measurement period, then compute TWA |

## Common Scenarios

### Scenario: Background Noise Survey for NC Rating

1. Record ≥15 s of steady-state background noise (HVAC on, room unoccupied)
2. Compute A-weighted Leq as a quick sanity check:
   ```
   splMeter: Bandwidth="Full band", FrequencyWeighting="A-weighting"
   ```
   Compare to the A-weighted target for the space type (see `references/noise-compliance.md`)
3. Compute octave-band Leq for spectral diagnosis:
   ```
   splMeter: Bandwidth="1 octave", FrequencyWeighting="Z-weighting", FrequencyRange=[15 8000]
   ```
4. For formal NC/RNC/RC compliance, pass the recording to `noiseCriteria(audioIn, fs, CalibrationFactor=cf)` — it computes octave-band Leq and assigns the rating internally

### Scenario: Product Noise Measurement

1. Set up mic at specified distance (typically 1 m, per product standard)
2. Record product in specified operating conditions
3. Compute A-weighted Leq: `splMeter` with `Bandwidth="Full band"`, `FrequencyWeighting="A-weighting"`
4. Report `Leq(end)` as the product noise level in dB(A)
5. If spec requires octave-band data, also compute with `Bandwidth="1 octave"`, `FrequencyWeighting="Z-weighting"`

### Scenario: Occupational Noise Assessment

1. Record representative work period (or use duration-weighted samples)
2. Compute A-weighted Leq with Slow time weighting:
   ```
   splMeter: Bandwidth="Full band", FrequencyWeighting="A-weighting", TimeWeighting="slow"
   ```
3. Report Leq(end) and compare to exposure limit
4. If peak hazard is a concern, also report Lpeak with C-weighting:
   ```
   splMeter: FrequencyWeighting="C-weighting"
   ```

## Troubleshooting

### Handling splMeter output size

`splMeter` outputs one row per input sample, but `Leq` is only updated at `TimeInterval` boundaries — between boundaries the value is held from the previous interval, and it is `-Inf` before the first boundary. Choose `TimeInterval` based on what you need:

| Goal | TimeInterval | How to read Leq |
|------|-------------|-----------------|
| Single overall level | Set to signal duration | `Leq(end)` |
| Time history (e.g., 1-second snapshots) | `1` | `Leq(fs:fs:end,:)` (value at each 1-second boundary) |

**Notes:**
- If `TimeInterval` > signal duration, `Leq` is never reported (all `-Inf`)
- `Leq` resets at each `TimeInterval` boundary — it is NOT a cumulative running total across the full signal (see "TimeInterval and Leq accumulation" above)

### Common issues

| Observation | Likely Cause | Action |
|-------------|-------------|--------|
| SPL seems 20–40 dB too low or too high | Missing or incorrect calibration factor | Verify CalibrationFactor; if unknown, levels are relative only |
| Leq is all -Inf | TimeInterval > signal duration | Set TimeInterval ≤ signal duration |
| Octave-band output missing expected bands | FrequencyRange excludes some true center frequencies | Use `[15 8000]` for 16 Hz–8 kHz; see SKILL.md gotchas |
| All octave bands show same level | FrequencyWeighting is applied — Z-weighting for flat bands | Use Z-weighting if you want unweighted per-band levels |
| Levels don't match physical meter | Different weighting, time constant, or calibration | Match all settings: same weighting, same time constant, verify cal |
| Lpeak is much higher than Leq | Normal for impulsive or highly variable noise | Report both; Lpeak represents instantaneous peak exposure |

----

Copyright 2026 The MathWorks, Inc.

----
