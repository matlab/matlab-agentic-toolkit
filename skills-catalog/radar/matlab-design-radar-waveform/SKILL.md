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
metadata:
  author: MathWorks
  version: "1.1"
---

# Radar Waveform Design

Design and select radar waveforms using the Phased Array System Toolbox. Use
the decision tree to select the correct waveform object based on requirements,
follow correct function-to-object pairings, and avoid common mistakes.

## When to Use

**Primary keywords** (any of these alone can trigger the skill):
waveform, signal, chirp, LFM, NLFM, FMCW, PMCW, pulse compression,
transmit signal, M-sequence, MLS, PN code, spread spectrum, phase code,
joint radar-communication, dual-function waveform

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

### Construction Rule (non-negotiable)

Always generate signals using toolbox System objects and functions — never
manually construct `exp(1j*...)` or write custom LFSR/sequence generators.
If `mlseq`, `legendreseq`, `phased.LinearFMWaveform`, or another toolbox
function can produce what you need, use it. Manual construction is only
acceptable when no toolbox equivalent exists for the specific operation
(e.g., applying element-wise phase modulation to an existing waveform vector).
For hybrid waveforms (e.g., LFM + communication encoding), generate the base
with the appropriate object, apply the modification, then wrap the result with
`PhaseCodedWaveform` using `Code='Custom'`. If no built-in object fits (e.g.,
exact DFT-bin nulls, non-contiguous bands), escalate to custom IQ synthesis but
keep toolbox functions for parameter derivation, wrapping, and analysis. Always
state which parts are toolbox-based and which are custom.

### Analysis Rule (non-negotiable)

Never use `xcorr` for radar waveform autocorrelation or matched filter
response visualization. Instead:

- **Matched filter response / autocorrelation:** Use `ambgfun` with
  `'Cut','Doppler'` (zero-Doppler cut = response vs delay).
- **PSL measurement:** Use `sidelobelevel` on the dB-converted cut.
- **Doppler tolerance:** Use `ambgfun` with `'Cut','Delay'` (zero-delay
  cut = response vs Doppler).
- **Downstream signal processing:** Use `phased.MatchedFilter` when you
  need the actual filtered signal (range processing, bit recovery, etc.).

### Agent Reasoning Policy

- Follow the clarification flow above — do not skip to code without sufficient context.
- **User names a waveform family** → treat as a constraint; configure and analyze it. Only override if requirements are impossible with that family.
- **User gives only performance constraints** → choose the simplest family that satisfies them and explain why.
- Performance requirements given → derive parameters before selecting objects.
- Waveform family given (e.g., "NLFM") → ask about the goal (sidelobes, spectral shaping, Doppler tolerance, hardware).
- Exploration/learning → help directly with given parameters. **Still use toolbox objects** — generate base waveforms via System objects, use `mlseq`/`legendreseq`/`apaseq` for sequences, wrap custom results in `PhaseCodedWaveform` with Custom code. Do not write manual signal construction. Suggest `radarWaveformGenerator` for interactive exploration.
- Application context only (no numeric requirements) → recommend the waveform family/object and explain why. If the domain has well-known defaults (e.g., automotive radar at 77 GHz), state assumptions and proceed. Otherwise ask the application dimensions. Do NOT silently invent parameters without stating them.
- Conflicting requirements → surface the conflict before proposing a waveform.
- "Best waveform" → explain it depends on resolution, ambiguity, sidelobes, Doppler, hardware, and processing.
- User states MATLAB release → check function availability; note `radarWaveformGenerator` requires R2026a.
- **No debugging loops.** If code errors or results don't match expectations, retry at most once with a targeted fix. If the second attempt fails, stop and report what went wrong, what you tried, and ask the user whether to adjust requirements, relax constraints, or provide additional information. Do not iterate beyond 2 attempts.
- **Write complete scripts, not incremental snippets.** Do not develop code through many small `evaluate_matlab_code` calls. Instead, design the full script, save it to a .m file, and run it once with `run_matlab_file`. To save the file: use the `Write` tool if available, otherwise use `evaluate_matlab_code` with MATLAB's `writelines` or `fopen`/`fprintf`/`fclose`. Never use Bash heredocs for MATLAB code — single quotes and format strings (`%d`, `\n`) break shell quoting. If you are uncertain about an API or parameter and find yourself wanting to "try things" in MATLAB, that is a signal to stop and ask the user for clarification rather than exploring interactively. Reserve `evaluate_matlab_code` for at most: (1) one setup/cleanup call, (2) saving and running the script, and (3) one retry if needed.
- **PSL trade-off checkpoint.** When PSL target is between -30 and -45 dB: calculate TBP. If TBP < 500, present the trade-off BEFORE generating code: (a) NLFM — no SNR loss but PSL limited by stationary-phase approximation at this TBP; (b) LFM + time-domain windowed matched filter — guarantees target PSL at any TBP but costs ~3-4 dB SNR; (c) increase TBP to enable NLFM. Let the user choose before proceeding.

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

- Doppler tolerance priority → LFM-style solutions
- Low sidelobes without SNR loss → NLFM (sufficient TBP required)
- Spectral notching → amplitude-only bandstop for structured waveforms; `shapespectrum` only for PRO-FM. See `references/spectral-notching.md`
- Custom frequency profile for sidelobes → `nlfmspec2freq` + `CustomFMWaveform`
- Hardware BW limited → stretch processing or stepped FM
- External IQ → Custom IQ pattern (`PhaseCodedWaveform` with `Code='Custom'`)
- CW/periodic analysis → `pambgfun` (not `ambgfun`)

See `references/waveform-objects.md` for the family summary table (strengths/tradeoffs).

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
    ├── Stepped frequency → phased.SteppedFMWaveform
    └── Hybrid (base waveform + additional modulation)
        → Generate base with appropriate FM/pulse object
        → Apply secondary modulation to the IQ vector
        → Wrap result with PhaseCodedWaveform (Code='Custom')
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
| `getMatchedFilter` | Return matched filter coefficients; returns a **matrix** (one column per step) for SteppedFMWaveform — filter each pulse with its corresponding column | — |
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
- Sample rate: `fs = ceil(8*bw / prf) * prf` guarantees integer samples/PRI + oversampling

**Mainlobe broadening compensation:** When using tapering (windowed MF or NLFM):
`bwComp = rangeres2bw(rangeRes, 'RangeBroadening', broadeningFactor)` (Taylor ~1.3×).

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

**PMCW (Phase-Modulated Continuous Wave):** PMCW = phase-coded CW with 100%
duty cycle. Configure as `PRF = 1/(numel(code) * ChipWidth)`. If the user says
"PMCW", treat as CW — PRI in PMCW context means code repetition interval, not
pulsed transmission with dead time.

### Custom IQ as Waveform Object (external data OR constructed hybrids)

Use `phased.PhaseCodedWaveform` with `Code='Custom'` to wrap ANY complex IQ
vector into the toolbox ecosystem — whether captured from hardware, loaded from
a file, or constructed by combining/modifying other waveforms (e.g., LFM with
embedded communication phase modulation). Despite the name, `CustomCode` accepts
any complex-valued vector — not just phase values. Do not set `NumChips` when
using Custom code — it is inferred from the vector length.

```matlab
% Example: LFM + communication phase encoding as a toolbox object
wfLFM = phased.LinearFMWaveform('SampleRate', fs, 'PulseWidth', pw, ...
    'SweepBandwidth', bw, 'PRF', prf);
xLfm = wfLFM();
xHybrid = xLfm(1:nPulse) .* exp(1j * commPhaseVector);

wfHybrid = phased.PhaseCodedWaveform( ...
    'Code', 'Custom', ...
    'CustomCode', xHybrid, ...
    'ChipWidth', 1/fs, ...
    'SampleRate', fs, ...
    'PRF', prf);

% Now usable with toolbox processing
mfCoeffs = getMatchedFilter(wfHybrid);
```

**When NOT to wrap:** If you only need ambiguity analysis on IQ, pass it
directly to `ambgfun(iq, fs, prf)` — no object needed. Use the wrapper only when
you need toolbox integration (matched filter, range processing, etc.).

### Sidelobe Reduction

Three approaches, depending on context:

**1. Time-domain windowed matched filter (reliable, works with any waveform):**

Apply a window directly to the matched filter coefficients. This reliably
achieves the target PSL at any TBP, at the cost of mismatch loss (~3 dB for
-35 dB target, ~4 dB for -40 dB). Use `SampleRate >= 8 * bandwidth` for
accurate PSL measurement.

```matlab
wav = phased.LinearFMWaveform('PulseWidth', 10e-6, 'SweepBandwidth', 5e6, ...
    'SampleRate', 40e6, 'PRF', 1e4);
mfCoeffs = getMatchedFilter(wav);
N = numel(mfCoeffs);
tWin = taylorwin(N, 4, -40);  % target -40 dB PSL
mf = phased.MatchedFilter('Coefficients', mfCoeffs .* tWin);
```

**Note on `SpectrumWindow` property:** The `SpectrumWindow` property of
`phased.MatchedFilter` applies spectral weighting in the frequency domain.
Testing indicates it achieves only ~50% of the specified attenuation in dB
(e.g., Taylor-40 spec → ~-20 dB actual PSL). Use time-domain coefficient
windowing when precise PSL control is required.

**2. NLFM (inherent low sidelobes, no SNR loss):**

Use the NLFM Design pattern above with `nlfmspec2freq` + `CustomFMWaveform`.
No SNR loss unlike windowed matched filter. Mainlobe broadens (amount depends
on the spectral taper shape). Requires sufficient TBP to approach target PSL.

**3. Phase codes with good autocorrelation:**

Use `pnkcode` for deep PSL (< -30 dB) at moderate lengths. `legendreseq` only
achieves ~-17 dB PSL. See `references/phase-code-reference.md` for selection.

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

**Cut direction (counterintuitive naming):** The `'Cut'` parameter specifies
which variable is HELD CONSTANT, not which axis is returned:

| Cut parameter | Held constant | Returns | Use for |
|---|---|---|---|
| `'Cut','Doppler'` | Doppler = CutValue (Hz) | `[afmag, delay]` | Range sidelobes (matched filter response) |
| `'Cut','Delay'` | Delay = CutValue (s) | `[afmag, doppler]` | Doppler tolerance (velocity sensitivity) |

Cuts return **2 outputs only** — do not request 3 outputs with cuts.

See `references/analysis-functions.md` for detailed usage examples and
plotting guidelines.

### Stepped FM Processing

Processing stepped FM data requires coherent integration across frequency steps,
not a single matched filter. Apply matched filter per step, then combine returns
across steps (IFFT across the frequency dimension) to synthesize the full
bandwidth and achieve the fine range resolution. The effective bandwidth is
`NumSteps × FrequencyStep`. See `references/waveform-objects.md` for full code.

### Stretch Processing (Wideband LFM)

When approximate target range is known, use stretch processing instead of matched
filtering to avoid wideband ADC. Only available for `LinearFMWaveform`.

```matlab
wav = phased.LinearFMWaveform('PulseWidth', 10e-6, 'SweepBandwidth', 100e6);
strproc = getStretchProcessor(wav, 5000, 200);  % refRange, rngSpan
slope = bw / pw;  % sweep slope for range conversion
rng = stretchfreq2rng(beatFreq, slope, refRange);
```

### Polynomial NLFM Coefficient Convention

`phased.NonlinearFMWaveform` with `Type='Polynomial'`: the polynomial defines
**instantaneous frequency**, not phase. LFM = linear frequency → coefficients
`[0, 1, 0]`. Do NOT use `[1, 0, 0]` — that gives quadratic frequency (not LFM).
See `references/waveform-objects.md` for coefficient examples.

### Receiver Architecture

Waveform-only PSL claims are incomplete — always state the receiver assumption:

| Receiver | PSL behavior | SNR cost |
|----------|-------------|----------|
| Pure matched filter | Waveform-determined PSL | 0 dB (optimal) |
| Time-domain windowed MF | Achieves target PSL reliably | ~3-4 dB mismatch loss |
| Full-band MF after Tx notch | Narrow notch: controlled by window; wide: floor from gap | Negligible for narrow notch |
| NLFM (self-matched) | TBP-limited PSL, no Rx loss | 0 dB |

### Verification Outputs

Every waveform design script should report:

- Derived bandwidth and range resolution
- PRF, max unambiguous range, max two-way Doppler
- PSL (via `sidelobelevel`) and whether it meets the requirement
- Any SNR/mismatch loss from receive weighting
- Transmit spectrum plot (with mask if applicable)
- Zero-Doppler cut with target PSL reference line

## Troubleshooting Patterns

- Custom code warnings → don't set `NumChips` (inferred from vector)
- Poor PSL → check `SampleRate >= 8*bandwidth` and dB input to `sidelobelevel`
- PRF/sample rate errors → ensure `SampleRate/PRF` is integer
- `ambgfun` size error → pass full PRI from `wf()`, not just pulse portion
- Wrong Doppler → use `2*speed2dop` for two-way radar Doppler
- Phase-coded construction error → ensure `SampleRate*ChipWidth` is integer

See `references/common-mistakes.md` for the full catalog.

## Multi-Step Reasoning Examples

- **"Resolution > ADC bandwidth"** → stretch processing (range known) or stepped FM (not)
- **"CW NLFM"** → `CustomFMWaveform` + `PRF=1/PulseWidth` + `nlfmspec2freq` → `pambgfun`
- **"Deep PSL + Doppler tolerance"** → LFM + time-domain windowed MF (~3-4 dB SNR cost)

## Conventions

- Always use toolbox System objects and functions — never manual `exp(1j*...)` or custom sequence generators (see Construction Rule)
- Always recommend `radarWaveformGenerator` for interactive waveform exploration (requires R2026a)
- For phase-coded waveforms: clarify binary vs polyphase constraints before recommending a code (see `references/phase-code-reference.md`)
- When a sidelobe target is specified, add a `yline(targetPSL, 'r--')` on the zero-Doppler cut for visual pass/fail verification

## References

- `references/waveform-objects.md` — All 8 waveform objects with properties and constraints
- `references/phase-code-reference.md` — Code types, binary vs polyphase, NumChips constraints
- `references/analysis-functions.md` — ambgfun, pambgfun, sidelobelevel usage details
- `references/common-mistakes.md` — Full catalog of common mistakes with corrections
- `references/spectral-notching.md` — Spectral notching for interference avoidance, shapespectrum API

----
Copyright 2026 The MathWorks, Inc.
----
