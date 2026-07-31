---
name: matlab-design-radar-waveform
description: >
  Design, select, and analyze waveforms for radar, sonar, and active sensing
  using the Phased Array System Toolbox. Covers LFM, NLFM, FMCW, phase-coded,
  CW, stepped FM, custom IQ, ambiguity functions, sidelobe reduction, and
  Doppler tolerance. Key objects: phased.LinearFMWaveform,
  phased.NonlinearFMWaveform, phased.CustomFMWaveform,
  phased.PhaseCodedWaveform, phased.FMCWWaveform, phased.SteppedFMWaveform,
  phased.MFSKWaveform, phased.RectangularWaveform, nlfmspec2freq,
  shapespectrum, ambgfun, pambgfun, sidelobelevel, legendreseq, mlseq,
  radarWaveformGenerator.
keywords:
  - waveform, signal, chirp, LFM, NLFM, FMCW, PMCW, pulse compression
  - transmit signal, sidelobe, Doppler, range resolution, matched filter
  - ambiguity, pulse, PRF, sweep, radar, sonar
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2024b"
metadata:
  author: MathWorks
  version: "1.0"
---

# Radar Waveform Design

Design and select radar waveforms using the Phased Array System Toolbox. Use
the decision tree to select the correct waveform object based on requirements,
follow correct function-to-object pairings, and avoid common mistakes.

## When to Use

**Primary keywords** (any of these alone can trigger the skill):
waveform, signal, chirp, LFM, NLFM, FMCW, PMCW, pulse compression, transmit signal

**Sensing-context words** (confirm sensing domain when paired with primary keywords):
target, jammer, jamming, pulse, pulses, spectrum, sidelobe, Doppler, range resolution, detection, clutter, matched filter, ambiguity, sweep, PRF, PRI

**Trigger logic:**
- Primary keyword + sensing-context word → use this skill directly
- Primary keyword alone → ask: sensing or communications? (communications → skill does not apply)
- Sensing-context words + vague language ("a signal that changes each time") → use this skill

**After triggering, clarify purpose and scope:**

1. **Purpose** — application-driven or exploration/learning?
   - Exploration/learning (student, paper reproduction, comparing properties): proceed with given parameters, suggest `radarWaveformGenerator`. Do not push for application context.
   - Application-driven → clarify dimensions below.

2. **Application dimensions** (ask what's unknown — applies to any sensing application):
   Range scale | Target motion and velocity | Resolution need | Environment (clutter, jamming, interference) | Hardware limits (ADC, duty cycle) | Primary metric (detection, resolution, accuracy, or ambiguity-free)

3. **Requirements** — Derive waveform parameters from the answers above (see table below)

## When NOT to Use

- Full radar system simulation (transmitter → channel → receiver chain)
- Beamforming or array design (use phased array skills)
- Target detection / CFAR processing
- Simulink waveform generation blocks
- Communications waveforms (OFDM, QAM, etc.)

### Escalation / Boundary Conditions

Do not answer as if waveform choice alone solves:

- Range/velocity ambiguity resolution strategy (staggered PRF scheduling, medium-PRF processing)
- Tracker-level Doppler/range association
- Detailed receiver chain design (noise figure, dynamic range budgets)
- Clutter suppression design (MTI, STAP)
- Antenna/array pattern issues
- CFAR or detector performance questions

Instead, explain that the issue is system-level and identify what waveform-related
part can still be addressed.

## Workflow

1. **Clarify requirements** — Gather what the user hasn't specified (see table below)
2. **Select waveform object** — Use the decision tree below
3. **Configure the waveform** — Set properties based on requirements
4. **Analyze** — Use appropriate analysis function (ambgfun, pambgfun, sidelobelevel)
5. **Suggest interactive exploration** — Recommend `radarWaveformGenerator` app

**Analysis approach:** Use `ambgfun` zero-Doppler cut to study the matched filter
response (mainlobe width, sidelobe structure). Measure PSL with `sidelobelevel`
on that cut. Only construct a `phased.MatchedFilter` object when the user
explicitly needs coefficients for downstream signal processing.

### Agent Reasoning Policy

- Follow the clarification flow above — do not skip to code without sufficient context.
- Performance requirements given → derive parameters before selecting objects.
- Waveform family given (e.g., "NLFM") → ask about the goal (sidelobes, spectral shaping, Doppler tolerance, hardware).
- Exploration/learning → help directly with given parameters; do not require application context.
- Application context only (no numeric requirements) → recommend the waveform family/object and explain why. If the domain has well-known defaults (e.g., automotive radar at 77 GHz), state assumptions and proceed. Otherwise ask the application dimensions. Do NOT silently invent parameters without stating them.
- Conflicting requirements → surface the conflict before proposing a waveform.
- "Best waveform" → explain it depends on resolution, ambiguity, sidelobes, Doppler, hardware, and processing.
- User states MATLAB release → check function availability; note `radarWaveformGenerator` requires R2026a.
- **No debugging loops.** If code errors or results don't match expectations, retry at most once with a targeted fix. If the second attempt fails, stop and report what went wrong, what you tried, and ask the user whether to adjust requirements, relax constraints, or provide additional information. Do not iterate beyond 2 attempts.

### Requirements to Clarify

Once the application dimensions are known, check for these specific gaps:

| If the user hasn't specified... | Ask about... | Impacts... |
|---|---|---|
| Modulation type | Pulsed vs CW; FM vs phase-coded | Object selection (decision tree) |
| Range resolution | Required resolution (m) | Bandwidth via `rangeres2bw` |
| Sidelobe requirement | Acceptable PSL (dB) | NLFM vs windowed matched filter vs phase code choice |
| Range and velocity together | Max unambiguous range AND velocity | PRF conflict check (see Parameter Derivation) |
| Doppler tolerance | Max target velocity during dwell | LFM (tolerant) vs phase-coded (sensitive) tradeoff |
| Hardware constraints | ADC bandwidth, instantaneous BW limit | Stretch processing or stepped FM instead of wideband LFM |

### Requirement-to-Recommendation Heuristics

- If the user prioritizes Doppler tolerance over perfectly decoupled range–Doppler, prefer LFM-style solutions.
- If the user prioritizes low sidelobes without receiver SNR loss, consider NLFM.
- If the user needs spectral notching (avoiding interference bands), use `shapespectrum` on an existing waveform. If they need a custom frequency profile for sidelobe control, use `nlfmspec2freq` + `CustomFMWaveform`.
- If the user's hardware cannot support large instantaneous bandwidth, consider stretch processing or stepped FM.
- If the user needs to bring external IQ data into toolbox processing, use the Custom IQ pattern (`PhaseCodedWaveform` with `Code='Custom'`).
- If the user needs periodic/CW-style analysis, direct them toward `pambgfun` rather than `ambgfun`.

### Waveform Family Summary

| Family | Strength | Tradeoff |
|---|---|---|
| LFM | Doppler tolerant | Range–Doppler coupled (ridge ambiguity) |
| NLFM | Low sidelobes, no SNR loss | Mainlobe broadens (amount depends on taper), less Doppler tolerant than LFM |
| Phase-coded | Thumbtack ambiguity | Doppler sensitive, code-dependent PSL |
| FMCW | Continuous, range+speed | Periodic analysis required (`pambgfun`) |
| Stepped FM | High resolution, low instantaneous BW | Requires coherent integration across steps |

## Waveform Selection Decision Tree

```
Is the waveform continuous (CW)?
├── Yes: Does the user need linear FM sweep?
│   ├── Yes: Multiple targets where ghost targets are a concern?
│   │   ├── Yes → phased.MFSKWaveform (resolves range+speed without ghosts)
│   │   └── No → phased.FMCWWaveform (triangle sweep for range+speed)
│   └── No: Does the user need multiple frequency steps?
│       ├── Yes → phased.MFSKWaveform
│       └── No: No dedicated CW object for desired modulation?
│           └── Use pulsed object with PRF = 1/PulseWidth (see CW Pattern below)
│               ├── Nonlinear FM → phased.NonlinearFMWaveform or phased.CustomFMWaveform
│               └── Phase-coded → phased.PhaseCodedWaveform
│
└── No (pulsed): What modulation?
    ├── None (simple pulse) → phased.RectangularWaveform
    ├── Linear FM → phased.LinearFMWaveform
    ├── Nonlinear FM (built-in type) → phased.NonlinearFMWaveform
    │   (4 types: Polynomial, Hyperbolic, Hybrid Linear-Tangent, Stepped Price)
    ├── Nonlinear FM (custom shape) → phased.CustomFMWaveform
    │   (use with nlfmspec2freq for stationary-phase design)
    ├── Phase-coded → phased.PhaseCodedWaveform
    └── Stepped frequency → phased.SteppedFMWaveform
```

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `rangeres2bw` | Convert range resolution (m) to bandwidth (Hz) | — |
| `speed2dop` | Convert speed to Doppler shift (**one-way only**; multiply by 2 for radar) | — |
| `freq2wavelen` | Convert carrier frequency to wavelength | — |
| `nlfmspec2freq` | Compute instantaneous frequency from desired spectrum shape | R2023a |
| `shapespectrum` | Generate waveform with desired spectrum shape (notching, masks) | R2024b |
| `sidelobelevel` | Measure peak and integrated sidelobe levels (**input must be in dB**) | R2024b |
| `legendreseq` | Generate Legendre sequences (perfect periodic autocorrelation) | R2024a |
| `mlseq` | Generate maximum-length sequences | R2024a |
| `apaseq` | Generate almost-perfect autocorrelation sequences; pass length N | R2024a |
| `pnkcode` | Generate polyphase P(n,k) code of length N: `pnkcode(N, n, k)` — best for deep PSL | R2024a |
| `bandwidth` | Return waveform bandwidth (Hz); available on all pulsed objects except SteppedFMWaveform | — |
| `ambgfun` | Compute ambiguity function (any waveform, including pulse trains) | — |
| `pambgfun` | Compute periodic ambiguity function (CW/periodic waveforms) | — |

## Patterns

### Parameter Derivation from Requirements

Derive all waveform parameters from system requirements — never hardcode.

```matlab
fc = 10e9;                              % carrier frequency
rangeRes = 20;                          % required range resolution (m)
maxRange = 80e3;                        % max unambiguous range (m)
maxVel = 300;                           % max target velocity (m/s)

lambda = freq2wavelen(fc);
bw = rangeres2bw(rangeRes);             % bandwidth from range resolution
c = physconst('LightSpeed');
prfMax = c / (2 * maxRange);            % max PRF from range ambiguity
fdMax = 2 * speed2dop(maxVel, lambda);  % TWO-WAY Doppler (speed2dop is one-way)
tbp = 50;                               % time-bandwidth product
pw = tbp / bw;                          % pulse width from TBP
```

**PRF conflict:** If `fdMax > prfMax`, the velocity requirement demands a higher
PRF than the range requirement allows — no single PRF satisfies both. **Do NOT
proceed with a single-PRF design.** Present the conflict, explain the trade-off
(range vs velocity), and recommend staggered PRF or medium-PRF with ambiguity
resolution. Ask which strategy the user prefers before generating any waveform code.
Waveform objects accept PRF as a vector for staggered operation, but the ambiguity
resolution strategy is a system-level concern — see Escalation / Boundary Conditions.

**Before generating code, verify:**
- `PulseWidth <= 1/PRF` (pulse fits within PRI)
- `SampleRate / PRF` is integer (integer samples per PRI)
- For phase-coded: `SampleRate * ChipWidth` is integer

**Choosing a valid sample rate:** `rangeres2bw` often returns a non-round value
(e.g., `c/(2*rangeRes)` ≈ 9.993 MHz). Naively multiplying by an oversampling
factor gives a sample rate that may not divide evenly by PRF. Fix:

```matlab
fs = ceil(8*bw / prf) * prf;  % round up to next PRF-compatible sample rate
```

This guarantees `fs/prf` is integer while meeting the oversampling requirement.

When using tapering (windowed matched filter or NLFM), mainlobe broadens. To
still meet the range resolution requirement, compensate the bandwidth using the
`'RangeBroadening'` parameter. The broadening factor depends on the taper shape
(e.g., Taylor ~1.3×, heavier tapers more):

```matlab
bwComp = rangeres2bw(rangeRes, 'RangeBroadening', broadeningFactor);
```

### NLFM Design via Stationary Phase

Use `nlfmspec2freq` to compute the frequency profile from a desired spectrum
shape, then feed it to `phased.CustomFMWaveform`. Do NOT use with
`phased.NonlinearFMWaveform` (which has fixed built-in types only).

```matlab
% Design NLFM waveform with low sidelobes
bw = 5e6;
nSamples = 500;
desiredSpectrum = taylorwin(nSamples, 4, -40);
freq = nlfmspec2freq(bw, desiredSpectrum);

wav = phased.CustomFMWaveform( ...
    'PulseWidth', 10e-6, ...
    'SampleRate', 10e6, ...
    'FrequencyModulation', freq);
```

**TBP-PSL trade-off:** The stationary-phase approximation introduces Fresnel
ripples that limit achievable PSL. The design spectrum (e.g., Taylor window)
sets an upper bound, but actual PSL is always worse than the design SLL —
the gap narrows as TBP increases. At low TBP (< 100), expect PSL significantly
above the design target; at high TBP (200+), PSL approaches the design SLL.

If the achieved PSL doesn't meet the target, do not iterate on window parameters
or design tweaks — the gap is a fundamental limitation of the stationary-phase
method at that TBP. Instead, present the trade-off options:
- Increase pulse width or bandwidth to raise TBP
- Switch to a windowed matched filter (achieves target PSL at any TBP, at the
  cost of SNR loss that grows with the target SLL)
- Accept the achieved PSL if it meets system needs

### CW from Pulsed Objects (100% Duty Cycle)

When no dedicated CW object exists for your modulation type, use a pulsed
waveform object with `PRF = 1/PulseWidth` so the pulse fills the entire PRI.

**Do NOT use `DutyCycle = 1`** — this errors on all pulsed waveform objects.
Instead, set PRF equal to the reciprocal of the pulse width.

```matlab
% Phase-coded CW using Legendre sequence
seq = legendreseq(127);
chipWidth = 1e-6;
prf = 1/(numel(seq) * chipWidth);  % 100% duty cycle
wav = phased.PhaseCodedWaveform( ...
    'Code', 'Custom', ...
    'CustomCode', seq, ...   % Do NOT set NumChips — inferred from vector length
    'ChipWidth', chipWidth, ...
    'PRF', prf, ...
    'SampleRate', 10e6);
```

**IMPORTANT:** Never set `NumChips` when `Code='Custom'`. The chip count is
inferred from the `CustomCode` vector length. Setting `NumChips` explicitly
produces a warning and may cause unexpected behavior.

**PMCW (Phase-Modulated Continuous Wave):** PMCW is phase-coded radar with 100%
duty cycle — the code fills the entire PRI with no dead time. Always configure
PMCW as `PRF = 1/PulseWidth` (i.e., `PRF = 1/(numel(code) * ChipWidth)` so the
pulse width equals the full code duration). If the user says "PMCW" or
"phase-modulated continuous wave", this means CW — do not create a low-duty-cycle
pulsed waveform. Even if the user also says "pulse repetition period" or "PRI",
the signal is still continuous; PRI in PMCW context refers to the code repetition
interval, not a pulsed transmission with dead time.

### Custom IQ as Waveform Object

Use `phased.PhaseCodedWaveform` with `Code='Custom'` to wrap arbitrary complex
IQ data into the toolbox ecosystem. Despite the name, `CustomCode` accepts any
complex-valued vector — not just phase values. Do not set `NumChips` when
using Custom code — it is inferred from the vector length.

```matlab
% Wrap hardware-captured IQ into toolbox
customIQ = loadIQFromHardware();  % complex vector, length N
wav = phased.PhaseCodedWaveform( ...
    'Code', 'Custom', ...
    'CustomCode', customIQ, ...
    'ChipWidth', 1/fs, ...
    'SampleRate', fs);

% Now use with matched filter
mfCoeffs = getMatchedFilter(wav);
mf = phased.MatchedFilter('Coefficients', mfCoeffs);
```

**When NOT to wrap:** If you only need ambiguity analysis on captured IQ, pass it
directly to `ambgfun(iq, fs, prf)` — no object needed. Use the wrapper only when
you need toolbox integration (matched filter, range processing, etc.).

### Sidelobe Reduction

Three approaches, depending on context:

**1. Windowed matched filter (simplest, works with any waveform):**

`SpectrumWindow` options that accept `SidelobeAttenuation`: `'Taylor'`, `'Chebyshev'`.
`'Hamming'` works but has no tunable attenuation. `'Kaiser'` ignores
`SidelobeAttenuation` (warning issued) — apply Kaiser manually if needed.

The windowed matched filter achieves the specified PSL at any TBP (unlike NLFM
which is TBP-limited), but costs SNR (loss increases with target SLL). Use
`SampleRate >= 8 * bandwidth` for accurate PSL measurement. If the measured PSL
doesn't match the window specification, verify: (1) input to `sidelobelevel` is
in dB, (2) sample rate is adequate — do not cycle through different windows.

```matlab
wav = phased.LinearFMWaveform('PulseWidth', 10e-6, 'SweepBandwidth', 5e6);
mf = phased.MatchedFilter( ...
    'Coefficients', getMatchedFilter(wav), ...
    'SpectrumWindow', 'Taylor', ...
    'SidelobeAttenuation', 40);
```

**2. NLFM (inherent low sidelobes, no SNR loss):**

Use the NLFM Design pattern above with `nlfmspec2freq` + `CustomFMWaveform`.
No SNR loss unlike windowed matched filter. Mainlobe broadens (amount depends
on the spectral taper shape). Requires sufficient TBP to approach target PSL.

**3. Phase codes with good autocorrelation:**

Use `pnkcode` for deep PSL (< -30 dB) at moderate lengths. `legendreseq` only
achieves ~-20 dB PSL. See `references/phase-code-reference.md` for selection.

### Ambiguity Function Analysis

**Ambiguity shape drives waveform choice:**

| Shape | Character | When to use |
|-------|-----------|-------------|
| Ridge (LFM) | Doppler tolerant — shift causes range offset, not SNR loss | Robustness to unknown Doppler; velocity resolved elsewhere |
| Thumbtack-like (some phase-coded, optimized codes) | Clean range–Doppler decoupling | Need unambiguous range AND Doppler from the same waveform |

Do not assume waveform class guarantees thumbtack — phase-coded can still be
Doppler sensitive; NLFM improves range sidelobes but may not decouple delay-Doppler.
Always validate with `ambgfun` 2D cut.

Choose the right function: `ambgfun` for single pulses and pulse trains;
`pambgfun` for CW/periodic waveforms (exploits periodicity for finer Doppler).

**Critical:** Pass the full PRI output to `ambgfun` (includes trailing zeros),
not just the pulse portion — pulse-only will error:

```matlab
sig = wf();          % full PRI — pass this to ambgfun
```

See `references/analysis-functions.md` for cut conventions, Doppler loss
measurement, and detailed usage examples.

### Stepped FM Processing

Processing stepped FM data requires coherent integration across frequency steps,
not a single matched filter. Apply matched filter per step, then combine returns
across steps (IFFT across the frequency dimension) to synthesize the full
bandwidth and achieve the fine range resolution. The effective bandwidth is
`NumSteps × FrequencyStep`. See `references/waveform-objects.md` for full code.

### Stretch Processing (Wideband LFM)

When approximate target range is known, use stretch processing instead of matched
filtering to avoid wideband ADC requirements. Only available for `LinearFMWaveform`.

```matlab
wav = phased.LinearFMWaveform('PulseWidth', 10e-6, 'SweepBandwidth', 100e6);
refRange = 5000;   % approximate target range (m)
rngSpan = 200;     % range window of interest (m)
strproc = getStretchProcessor(wav, refRange, rngSpan);
```

The returned `phased.StretchProcessor` object mixes the received signal with a
reference chirp. The beat frequency is narrowband → low-bandwidth ADC suffices.
Use `stretchfreq2rng` to convert detected beat frequencies back to range:

```matlab
slope = bw / pw;  % sweep slope (Hz/s), NOT bandwidth
rng = stretchfreq2rng(beatFreq, slope, refRange);
```

### Polynomial NLFM Coefficient Convention

`phased.NonlinearFMWaveform` with `Type='Polynomial'`: the polynomial defines
**instantaneous frequency**, not phase. LFM = linear frequency → coefficients
`[0, 1, 0]`. Do NOT use `[1, 0, 0]` — that gives quadratic frequency (not LFM).
See `references/waveform-objects.md` for coefficient examples.

## Troubleshooting Patterns

If the user reports:

- Unexpected warnings with Custom code → check that `NumChips` is not set (inferred from vector)
- Poor measured PSL → check `SampleRate >= 8 * bandwidth` and that `sidelobelevel` input is in dB
- Errors around PRF/sample rate → check that `SampleRate / PRF` is integer; use `fs = ceil(8*bw / prf) * prf`
- `ambgfun` "input X should contain at least Fs/PRF samples" → pass full PRI from `wf()`, not just the pulse portion
- Unexpected Doppler results → check one-way vs two-way Doppler (`2 * speed2dop`)
- Poor stepped-FM range resolution → verify coherent step processing, not a single matched filter
- Construction error on phase-coded waveform → check that `SampleRate * ChipWidth` is integer

For the full common mistakes catalog, see `references/common-mistakes.md`.

## Multi-Step Reasoning Examples

These show how to chain multiple skill sections for non-obvious design decisions:

- **"I need 5 m range resolution but my ADC only handles 20 MHz"** → `rangeres2bw` gives ~30 MHz (exceeds ADC) → cannot use standard matched filter → recommend stretch processing (if approximate range known) or stepped FM (if not). Both avoid wideband ADC.

- **"I want a CW waveform with low sidelobes"** → no dedicated NLFM-CW object → use `CustomFMWaveform` with `PRF = 1/PulseWidth` for 100% duty → design frequency profile via `nlfmspec2freq` + Taylor window → analyze with `pambgfun` (not `ambgfun`).

- **"I need deep PSL and good Doppler tolerance"** → phase-coded gives thumbtack but PSL limited by code type and length; NLFM achieves low PSL without SNR loss but is less Doppler tolerant than LFM and requires high TBP; LFM + windowed matched filter preserves Doppler tolerance while achieving target PSL (with some SNR loss) → recommend LFM with windowed MF when Doppler tolerance is the priority.

## Conventions

- Prefer toolbox System objects over manual signal construction
- Always recommend `radarWaveformGenerator` for interactive waveform exploration (requires R2026a)
- For phase-coded waveforms: clarify binary vs polyphase constraints before recommending a code (see `references/phase-code-reference.md`)

## References

- `references/waveform-objects.md` — All 8 waveform objects with properties and constraints
- `references/phase-code-reference.md` — Code types, binary vs polyphase, NumChips constraints
- `references/analysis-functions.md` — ambgfun, pambgfun, sidelobelevel usage details
- `references/common-mistakes.md` — Full catalog of common mistakes with corrections

----

Copyright 2026 The MathWorks, Inc.

----
