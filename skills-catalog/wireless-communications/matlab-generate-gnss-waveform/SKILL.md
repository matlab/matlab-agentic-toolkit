---
name: matlab-generate-gnss-waveform
description: >
  Generate GNSS baseband waveforms (GPS, Galileo, NavIC) with physically
  realistic or user-specified channel impairments using the Satellite
  Communications Toolbox. Use when generating GPS L1 C/A, L1C, L2C, L5,
  Galileo E1, E1C, E5a, E5b, E5, or NavIC L5, S, L1 signals. Covers
  gpsWaveformGenerator, galileoWaveformGenerator, satelliteScenario,
  Doppler/delay from orbital dynamics or custom values, navigation data
  encoding with ephemeris, and RINEX integration.
  Triggers on: GPS waveform, Galileo waveform, NavIC waveform, GNSS signal,
  satellite scenario, GNSS simulation, receiver test signal, baseband GNSS,
  L-band satellite signal, navigation signal generation.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2026a"
metadata:
  author: MathWorks
  version: "1.0"
---

# Generate GNSS Waveform

Generate multi-satellite GNSS baseband waveforms with properly encoded
navigation data. Channel impairments (Doppler, delay, noise) can come from
a realistic satellite scenario OR from user-specified custom values.
Supports GPS, Galileo, and NavIC constellations. The waveform carries real
ephemeris so a receiver can decode it for position estimation.

## When to Use

- Generating GNSS baseband signals (GPS, Galileo, or NavIC) for receiver testing
- Simulating multi-satellite channels with Doppler and delay from orbital dynamics
- Testing with specific Doppler/delay/SNR values (custom channel mode)
- Building end-to-end GNSS receiver simulations that need decodable nav data

## When NOT to Use

- Signal acquisition, tracking loops, nav decoding, or position estimation
- BeiDou/GLONASS (not supported) or SDR hardware transmission

## Prerequisites: Helper Files

Copy helper files from MathWorks examples into your project folder.
See `references/helper-files.md` for the full list of source examples
and files to copy per constellation (GPS, Galileo, NavIC).

## Workflow

The pipeline has 6 steps (0-5). Step 0 determines signal type, channel
mode, and data source. The channel mode decides whether Steps 2-3 are needed.

```
Step 0: Determine signal type + channel mode + data source + nav data intent
Step 1: Configure waveform generator
         ├── Scenario mode → Step 2 (satellite scenario) + Step 3 (compute channel from physics)
         └── Custom mode   → Step 3c (user provides Doppler/delay/SNR directly)
Step 4: Encode navigation data (both modes)
Step 5: Generate waveform with channel (both modes)
```

### Step 0: Determine signal type, channel mode, and data source

**If the user's prompt does not clearly specify the signal type**, ask:

> What GNSS waveform would you like to generate?
>
> **GPS:** L1 C/A, L1C, L2C, L5
> **Galileo:** E1, E1C (pilot only), E5a, E5b, E5 (wideband)
> **NavIC:** L5, S, L1
>
> Also, how should channel impairments (Doppler shift, propagation delay,
> noise) be applied?
>
> **(a) Scenario-driven** — I compute realistic values from a satellite
> scenario. You provide a receiver location (lat/lon) and I handle the
> orbital dynamics.
>
> **(b) Custom values** — You provide Doppler (Hz), delay (s), and/or
> SNR (dB) per satellite. Useful for controlled testing or when you already
> have your own channel model.

**Detection heuristics:** Location/city/lat-lon → Scenario. Specific
Doppler/delay/SNR numbers → Custom. "Stress test" or "extreme" → Custom.
No cues → Ask. If signal type is clear but mode ambiguous, ask only
about mode.

#### Data source selection

**Available:** `gpsAlmanac.txt` (always on path), RINEX `.rnx` files
(Nav Toolbox). **Require setup:** `galileoAlmanac.xml` (copy from
example), fresh almanac (download from USCG NAVCEN).

**Decision rules:**
1. User provides RINEX → use for both scenario AND nav data.
2. No RINEX → use bundled almanac (`gpsAlmanac.txt` or `galileoAlmanac.xml`).
3. Current-epoch needed → offer fresh almanac download (requires internet).
4. RINEX requested but no Nav Toolbox → fall back to almanac or parse
   manually (see `references/rinex-integration.md`).

**All bundled files are from a fixed past epoch.** This is fine for receiver
algorithm testing (orbital geometry is still valid) but does not represent
today's actual sky. The agent MUST communicate which file and epoch is being
used.

#### Navigation data intent

Navigation data can be:
- **Real ephemeris** (from almanac/RINEX) — required for end-to-end receiver
  testing where position estimation must work
- **Random/dummy bits** — valid for signal-level testing (acquisition,
  tracking, modulation quality) where nav decode is not the goal

If user's intent is unclear, ask:
> Do you need the waveform to carry real navigation data (for position
> estimation), or are dummy bits fine (for signal-level testing)?

#### STOP — Present choices before generating

**Before writing or executing ANY code**, print a standalone configuration
summary stating: signal type, center frequency, sample rate, duration,
data source + epoch, start time, and nav data type. This MUST appear as
visible text BEFORE any code block — not buried in comments or post-run
summaries. In interactive mode, wait for user confirmation.

### Step 1: Configure waveform generator (constellation-specific)

**GPS:**
```matlab
sampleRate = 5e6;
wavegenobj = gpsWaveformGenerator(SampleRate=sampleRate);
wavegenobj.SignalType = "legacy";  % L1 C/A
navDataType = "LNAV";
centerFrequency = 1575.42e6;
stepTime = wavegenobj.BitDuration;
```
**Verify:** `stepTime` should be 0.02 (20 ms) for L1 C/A, 0.01 for L1C/L5.

**Galileo:**
```matlab
sampleRate = 25e6;  % Use 60e6 for E5 wideband
wavegenobj = galileoWaveformGenerator(SampleRate=sampleRate);
wavegenobj.SignalType = "E1";  % or "E1C","E5a","E5b","E5"
centerFrequency = 1575.42e6;  % E5 uses 1191.795e6
stepTime = wavegenobj.BitDuration;
```
**Verify:** `stepTime` should be 0.004 (4 ms) for E1/E1C/E5b, 0.02 for E5a/E5.

**E5 has critical pitfalls** — nav data must be a `{fnavbits, inavbits}`
cell array (not a matrix), and I/NAV needs 5× more rows than F/NAV.
See `references/galileo-pipeline.md` E5 section.

**NavIC (R2026a -- no system object yet):**
```matlab
sampleRate = 24e6;
centerFrequency = 1176.45e6;  % L5 (or 2492.028e6 for S, 1575.42e6 for L1)
stepTime = 0.02;  % 20 ms for L5/S, 10 ms for L1
```
NavIC L1 is completely different from L5/S (SBOC, IZ4 codes, support file download). See `references/navic-pipeline.md` §NavIC L1 SPS.

See `references/gps-pipeline.md`, `references/galileo-pipeline.md`, or `references/navic-pipeline.md` for full signal type tables.

### Step 2: Set up satellite scenario (SCENARIO MODE ONLY)

**Skip this step entirely in custom mode.**

Create the scenario, ground station, and timing (shared). Then add
satellites using the constellation-specific method.

```matlab
sc = satelliteScenario;
rx = groundStation(sc, lat, lon, Altitude=alt);
rx.MinElevationAngle = 10;

waveDuration = 10;  % seconds
sc.StartTime  = startTime;
sc.StopTime   = sc.StartTime + seconds(waveDuration - stepTime);
sc.SampleTime = stepTime;
```

Add satellites (constellation-specific). **Default to almanac** unless the
user explicitly has a RINEX file or asks for RINEX. The almanac path avoids
a Navigation Toolbox dependency (`rinexread`). The same source must feed
Step 4 (nav data encoding).

**GPS (almanac path — preferred):**
```matlab
sat = satellite(sc, "gpsAlmanac.txt", OrbitPropagator="gps");
```

**GPS (RINEX path):** Check `~isempty(ver('nav'))` first. If Navigation
Toolbox is unavailable, use almanac or parse RINEX manually
(see `references/rinex-integration.md`).
```matlab
rinexdata = rinexread(rinexFileName);
sat = satellite(sc, rinexdata, OrbitPropagator="gps");
```

**Galileo (almanac path — preferred)** -- `satellite()` does NOT accept
Galileo XML almanac files. Use the helper:
```matlab
sat = HelperAddGalileoSatellitesToScenario(sc, "galileoAlmanac.xml");
```

**Galileo (RINEX path):** Same toolbox check; fall back to almanac if unavailable.
```matlab
rinexdata = rinexread(rinexFileName);
sat = satellite(sc, rinexdata);
```

**NavIC** -- RINEX only (requires Navigation Toolbox).
Use `HelperAddSatellite(sc, selectedRows)` — see `references/navic-pipeline.md`.

**Critical:** Use the same `startTime` and data source (almanac OR RINEX)
for both orbit propagation (this step) and nav data encoding (Step 4).

**Verify:** After adding satellites, check `sat` is non-empty. For GPS
almanac, expect ~30 satellites total in the scenario.

### Step 3: Compute channel parameters from physics (SCENARIO MODE ONLY)

**Skip this step entirely in custom mode — go to Step 3c instead.**

```matlab
dopShifts = dopplershift(sat, rx, Frequency=centerFrequency).';
ltncy = latency(sat, rx).';
```

Compute SNR from free-space path loss:

```matlab
DtLin = db2pow(12);           % Transmit antenna directivity
DrLin = db2pow(4);            % Receive antenna directivity
k = physconst("boltzmann");
T = 300;                      % Temperature (K)
Pr = Pt*DtLin*DrLin ./ ((4*pi*(centerFrequency + dopShifts).*ltncy).^2);
snrs = 10*log10(Pr/(k*T*sampleRate)) + 3;
```

| Constellation | `Pt` (Transmit Power) |
|--------------|----------------------|
| GPS | 44.8 W |
| Galileo | 160 W |
| NavIC | 50 W |

Find visible satellites (non-NaN latency at first time step):

```matlab
satIndices = find(~isnan(ltncy(1,:)));
```

**Verify:** `numel(satIndices)` should be >= 4 (minimum for positioning).
If zero, the start time does not match the data source epoch (Gotcha #12).

### Step 3c: Set up custom channel parameters (CUSTOM MODE ONLY)

**Skip this step entirely in scenario mode.**

The user provides Doppler, delay, and/or SNR values directly.

```matlab
numSats = 4;
dopShifts = [2000, -1500, 800, 3200];      % Hz per satellite
ltncy = [0.072, 0.074, 0.069, 0.078];      % seconds per satellite
snrs = [-10, -12, -11, -9];                 % dB per satellite

% For time-varying custom values, use matrices (numsteps x numSats)
% dopShifts = [...];  % each row is one time step

waveDuration = 10;  % seconds
numsteps = round(waveDuration / stepTime);
satIndices = 1:numSats;
```

**Required from user:** number of satellites, Doppler (Hz), delay (s),
PRN/SVID list. **Optional (defaults):** SNR (-10 dB), duration (10 s),
time-varying (no, static).

**Expand static values for the generation loop:**
```matlab
if isvector(dopShifts) && size(dopShifts,1) == 1
    dopShifts = repmat(dopShifts, numsteps, 1);
    ltncy = repmat(ltncy, numsteps, 1);
    snrs = repmat(snrs, numsteps, 1);
end
```

**No physical constraint validation in custom mode.** The user may
intentionally provide extreme values. Do NOT assert against physical ranges.

### Step 4: Encode navigation data (BOTH MODES, constellation-specific)

Navigation data carries ephemeris the receiver needs for position estimation.

**If user needs real ephemeris (position estimation):**
- Use the same data source as the scenario (Step 2)
- If RINEX was used for the scenario, use RINEX for nav data too (preferred)
- Almanac supplements non-ephemeris fields only (health bits, almanac pages)
- **Start time for nav data encoding MUST match scenario start time** —
  mismatched times produce nav bits that don't correspond to satellite
  positions, causing silent position estimation errors

**If user only needs signal-level testing (acquisition/tracking):**
- Random bits are acceptable: `navdata = randi([0 1], numsteps, numSats);`
- No almanac or RINEX files needed at all
- Waveform will have correct modulation and channel but nav decode will fail

 **Critical:** When RINEX was used for orbit propagation in Step 2, you MUST
  use `HelperGPSRINEX2Config` (not `HelperGPSAlmanac2Config`) for nav data
  encoding. The same RINEX struct feeds both orbit and ephemeris. Falling back
  to almanac for nav data while using RINEX for the scenario violates the
  single-source principle and may produce inconsistent ephemeris.

**Scenario mode with real ephemeris:** `satIndices` comes from visible
satellite computation in Step 3.

**Custom mode with real ephemeris:** Use almanac as the data source (no
Navigation Toolbox needed). The user must specify which PRN/SVID values
to encode. Use the almanac path examples below.

**GPS (almanac path):**
```matlab
navcfg = HelperGPSAlmanac2Config(almFileName, navDataType, satIndices, startTime);
visiblePRN = [navcfg(:).PRNID];

% Encode nav data per satellite (HelperGPSNAVDataEncode accepts scalar config only)
tempnavdata = HelperGPSNAVDataEncode(navcfg(1));
navdata = zeros(length(tempnavdata), length(navcfg));
navdata(:,1) = tempnavdata;
for isat = 2:length(navcfg)
    navdata(:,isat) = HelperGPSNAVDataEncode(navcfg(isat));
end
```

**GPS (RINEX path)** -- see `references/gps-pipeline.md` for the full
`HelperGPSRINEX2Config` pattern.

**Galileo (almanac path):** Use the nav data signal type mapping from
`references/galileo-pipeline.md` (E1→E1B, E5a→E5a, E5b→E5b):
```matlab
galNavObj = HelperGalileoNavigationData(almFileName, true, SignalType="E1B");
visibleSVIDs = galNavObj.Ephemeris.SatelliteID(satIndices);
[~, inittow] = HelperGPSConvertTime(startTime);
navdata = navdata2bits(galNavObj, visibleSVIDs, inittow, numpages);
```

**Galileo (RINEX path)** -- see `references/galileo-pipeline.md`.

**NavIC** -- RINEX only. `HelperNavICRINEX2Config` takes the RINEX data
table directly (not a filename):
```matlab
navicCfg = HelperNavICRINEX2Config(selectedRows);
```

See the constellation-specific reference files for complete encoding patterns.

### Step 5: Generate waveform with channel (BOTH MODES)

This step is identical for both scenario and custom modes. By Step 5,
`dopShifts`, `ltncy`, and `snrs` are all `numsteps x numSats` matrices
regardless of how they were obtained.

**GPS and Galileo** use their system object in a stepped loop:

```matlab
wavegenobj.PRNID = visiblePRN;  % GPS uses PRNID
% wavegenobj.SVID = visibleSVID;  % Galileo uses SVID

gnsschannelobj = HelperGNSSChannel( ...
    FrequencyOffset=dopShifts(1,satIndices), ...
    SignalDelay=ltncy(1,satIndices), ...
    SignalToNoiseRatio=snrs(1,satIndices), ...
    SampleRate=sampleRate, ...
    RandomStream="mt19937ar with seed", Seed=73);

numsteps = round(waveDuration / stepTime);
samplesPerStep = sampleRate * stepTime;
waveform = zeros(numsteps * samplesPerStep, 1);

for istep = 1:numsteps
    idx = (istep-1)*samplesPerStep + (1:samplesPerStep);
    waveform(idx,:) = gnsschannelobj(wavegenobj(navdata(istep,:)));
    gnsschannelobj.SignalToNoiseRatio = snrs(istep, satIndices);
    gnsschannelobj.FrequencyOffset = dopShifts(istep, satIndices);
    gnsschannelobj.SignalDelay = ltncy(istep, satIndices);
end
```

**NavIC (R2026a)** uses `HelperNavICBBWaveform` or manual modulation
(no system object). The helper returns multi-column output (one per
satellite) -- pass directly to `HelperGNSSChannel`, do not sum first.
See `references/navic-pipeline.md` for the full pattern.

**Verify:** `length(waveform) == numsteps * samplesPerStep`. Waveform
should not be all-zero (would indicate channel SNR too low or nav data
mismatch).

## Signal Type Quick Reference

See `references/signal-type-mapping.md` for full tables of SignalType
strings, center frequencies, BitDuration, and nav data types per
constellation.

## Verification (Scenario Mode Only)

After generating a waveform in scenario mode, verify channel parameters are
physically realistic. See `references/physical-constraints.md` for the full
verification function and expected ranges per constellation. Key checks:
at least 4 visible satellites, Doppler within ±10 kHz (L1), delay 67-86 ms
(MEO) or 119-130 ms (GEO/GSO), distinct Doppler per satellite, and
time-varying Doppler.

**Do not run these checks in custom mode** — the user may intentionally
provide values outside physical ranges.

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `gpsWaveformGenerator` | Generate GPS baseband waveform | Satellite Communications |
| `galileoWaveformGenerator` | Generate Galileo baseband waveform | Satellite Communications |
| `satelliteScenario` | Create scenario (scenario mode) | Satellite Communications |
| `dopplershift` | Compute Doppler from orbital dynamics | Satellite Communications |
| `latency` | Compute propagation delay | Satellite Communications |
| `rinexread` | Read RINEX navigation files (RINEX path only) | Navigation (optional) |
| `physconst` | Physical constants (Boltzmann, light speed) | Core MATLAB |

## Gotchas

1. **Random nav bits only if user explicitly agrees.** `randi([0 1], ...)`
   is acceptable for signal-level testing (acquisition, tracking) but makes
   position estimation impossible. If user needs end-to-end receiver testing,
   use the constellation-specific nav data encoder for real ephemeris.
   Always confirm nav data intent in Step 0.

2. **In scenario mode, never hand-roll Doppler or delay.** Do not use
   `exp(1j*2*pi*f*t)` for Doppler or `circshift` for delay. Use
   `satelliteScenario` -> `dopplershift()` -> `latency()` ->
   `HelperGNSSChannel` for physics-based channel modeling. In custom mode,
   user-provided values are passed directly to `HelperGNSSChannel`.

3. **Nav data has more rows than numsteps.** Nav data encoders produce the
   full message (e.g., 37500 rows for GPS LNAV) because they encode the
   complete nav frame structure. Only the first `numsteps` rows are consumed
   in the generation loop. Do not resize or assert equality — excess rows
   are simply unused.

4. **RINEX: pass struct, not filename.** `satellite(sc, rinexData)` expects
   the struct from `rinexread()`, not the `.rnx` filename string. Passing
   the filename causes a confusing "invalid orbit data" error.

5. **Center frequency must match signal type.** L1/E1 = 1575.42 MHz,
   L2 = 1227.60 MHz, L5/E5a = 1176.45 MHz, E5b = 1207.14 MHz,
   E5 = 1191.795 MHz, S = 2492.028 MHz. Must match in `dopplershift()`.

6. **GPS uses `PRNID`, Galileo uses `SVID`.** Using the wrong property
   name silently creates a dynamic property on the system object — the
   waveform generator ignores it and generates with default satellite IDs,
   producing incorrect spreading codes.

7. **Galileo transmit power is 160 W, not GPS's 44.8 W.** Using GPS power
   for Galileo gives incorrect SNR. NavIC uses 50 W.

8. **NavIC has no system object in R2026a.** Calling `navicWaveformGenerator`
   will error. Use manual modulation (`interplexmod`, `bocmod`, `gnssCACode`)
   or the `HelperNavICBBWaveform` helper. Ships as a system object in R2026b.

9. **`satellite()` only accepts GPS SEM almanac natively.** Passing a
   Galileo XML or NavIC RINEX file directly to `satellite()` errors or
   produces wrong orbits. Use the constellation-specific helpers in Step 2.

10. **GPS L5 and L1C: not all satellites broadcast modernized signals.**
    Block IIF+ carry L5; Block III+ carry L1C. Expect ~4-6 visible vs ~8-12 for L1 C/A.

11. **Filter PRN/SVID against nav data availability.** Intersect visible
    satellites with the nav data object's available IDs before encoding.

12. **Time/epoch consistency is critical.** Three times must align:
    `sc.StartTime`, the nav data encoder's `startTime`, and the data source
    epoch. If `sc.StartTime` is far from the almanac/RINEX epoch,
    `latency()` returns all-NaN (zero visible satellites, no error). If nav
    data `startTime` differs from `sc.StartTime`, ephemeris won't match
    satellite positions — causing silent position errors. Bundled files are
    from a fixed past epoch; always communicate which file and epoch is used.

## Conventions

- `datetime` with `TimeZone="UTC"` for all GNSS time references
- Name-value syntax (`Name=Value`), not legacy `'Name', Value` pairs
- GPS time conversion: `HelperGPSConvertTime`; Galileo/NavIC: `HelperGNSSConvertTime`
- Always transpose `dopplershift`/`latency` output (`.';`) — they return
  column-per-timestep, but the generation loop indexes row-per-timestep
- Pre-allocate the waveform: `zeros(numsteps * samplesPerStep, 1)`
- Use `seconds()` for duration arithmetic (not bare numbers)
- Signal type strings are case-sensitive: `"legacy"` not `"Legacy"`, `"l5"` not `"L5"`
- Prefer `find(~isnan(ltncy(1,:)))` to detect visible satellites — simpler
  and more robust than elevation angle filtering

Copyright 2026 The MathWorks, Inc.
