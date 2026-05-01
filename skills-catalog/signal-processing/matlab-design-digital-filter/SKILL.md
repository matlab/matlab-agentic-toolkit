---
name: matlab-design-digital-filter
description: >
  Design and validate digital filters in MATLAB. Use when cleaning up noisy signals,
  removing interference, filtering signals, designing FIR/IIR filters
  (lowpass/highpass/bandpass/bandstop/notch), or comparing filters in Filter Analyzer.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# Design Digital Filters in MATLAB

Design, implement, and validate digital filters using Signal Processing Toolbox and DSP System Toolbox. Choose the right architecture (single-stage vs efficient alternatives), generate correct code, and verify the result with plots and numbers.

## When to Use

- Designing lowpass, highpass, bandpass, bandstop, or notch filters
- Cleaning up noisy signals or removing interference
- Choosing between FIR and IIR filter architectures
- Comparing filter designs in Filter Analyzer
- Building streaming (real-time) or offline (batch) filtering pipelines
- Handling narrow transition bands with multirate or IFIR approaches

## When NOT to Use

- Adaptive filtering (LMS, RLS) -- use Signal Processing Toolbox docs directly
- Audio-specific processing (equalization, room correction) -- use Audio Toolbox
- Image filtering (2D convolution, morphological ops) -- use Image Processing Toolbox
- General spectral analysis without filtering intent -- FFT/periodogram docs suffice

## Key Rules

- **Read references/INDEX.md** before writing any filter design code.
- **Always write to .m files.** Never put multi-line MATLAB code directly in `evaluate_matlab_code`. Write to a `.m` file, run with `run_matlab_file`, edit on error.
- **Preflight before ANY MATLAB call.** Before calling any function listed in INDEX.md, read the required quick-ref first. State `Preflight: [files]` at the top of the response.
- **Do not guess key requirements.** If Mode (streaming vs offline) or Phase requirement is not stated, ask.
- **No Hz designs without Fs.** If `Fs` is unknown, stop and ask (unless the user explicitly wants normalized frequency).
- **Always pin the sample rate.** Use `designfilt(..., SampleRate=Fs)` and `freqz(d, [], Fs)`.
- **IIR stability:** Prefer SOS/CTF forms (avoid high-order `[b,a]` polynomials).

### Preflight Procedure

1. List MATLAB functions to call
2. Check `references/INDEX.md` for each (function-level + task-level tables)
3. Read required quick-ref files
4. State at response top: `Preflight: quick-ref/filter-analyzer.md, quick-ref/designfilt.md` (or `Preflight: none required`)

## Workflow

### Phase 1: Signal Analysis

- Analyze input data via MCP (spectrum, signal length, interference location)
- Compute `trans_pct` and identify interference characteristics

### Phase 2: Clarify Intent

After signal analysis, ask Mode + Phase if not stated:
- **Mode**: streaming (causal) | offline (batch)
- **Phase**: zero-phase | linear-phase | don't-care

Wait for answer before showing any approach comparison or overview.

### Phase 3: Architecture Selection

- Open `references/efficient-filtering.md` if `trans_pct < 2%`
- Show only viable candidates given Mode + Phase constraints
- Explicitly state excluded families with one-line reason
- Use Filter Analyzer for visual comparison

## Design Intake Checklist

### Required signal + frequency spec (cannot proceed without)

- `Fs` (Hz)
- Response type: lowpass / highpass / bandpass / bandstop / notch
- Edge frequencies in Hz

If any item is missing, ask.

### Required intent for architecture choice (ask if unknown)

- **Mode**: streaming (causal) | offline (batch)
- **Phase**: zero-phase | linear-phase | don't-care
- **Magnitude constraints**: `Rp_dB` passband ripple (default 1 dB), `Rs_dB` stopband attenuation (default 60 dB)

If Mode or Phase is unknown, ask 1-2 clarifying questions and stop.

## Architecture Checkpoint

Compute and state before finalizing an approach:

- `trans_bw = Fstop - Fpass`
- `trans_pct = 100 * trans_bw / Fs`
- `M_max = floor(Fs/(2*Fstop))` (only meaningful for lowpass-based multirate)

**Decision rule:**
- `trans_pct > 5%` -- single-stage FIR or IIR is usually fine
- `2% <= trans_pct <= 5%` -- single-stage possible; mention efficient alternatives if cost/latency matters
- `trans_pct < 2%` -- stop and do a narrow-transition comparison (see `references/quick-ref/efficient-filtering.md`)

## Design + Verify

1. **Feasibility check** -- Let `designfilt` choose minimum order, then query `filtord(d)`. Optionally use `kaiserord`/`firpmord` for FIR length estimates.
2. **Design candidates** -- Prefer `designfilt()` with explicit `Rp/Rs` and `SampleRate=Fs`. Streaming IIR: use `SystemObject=true`. Offline zero-phase: `filtfilt()` is allowed but state that it squares the magnitude response.
3. **Compare visually** -- Use `filterAnalyzer()` for comparing 2+ designs. Read `references/quick-ref/filter-analyzer.md` first. Minimum displays: magnitude + group delay.
4. **Verify with numbers** -- Worst-case passband ripple and stopband attenuation vs spec. For `filtfilt()`, verify the effective response (magnitude squared).
5. **Deliver the output** -- Specs recap, derived metrics, chosen architecture + why, MATLAB code, verification snippet + results, implementation form.

## Key Functions

| Function | Purpose |
|----------|---------|
| `designfilt()` | Primary filter design (FIR and IIR, all response types) |
| `filterAnalyzer()` | Visual comparison of 2+ filter designs |
| `freqz()`, `grpdelay()` | Frequency response and group delay analysis |
| `filtfilt()` | Zero-phase offline filtering |
| `dsp.SOSFilter` | Streaming IIR via `SystemObject=true` |
| `designMultirateFIR()` | Multirate decimator/interpolator design |
| `ifir()` | Interpolated FIR for narrow transitions at constant rate |
| `kaiserord()`, `firpmord()` | FIR order estimation |

## Conventions

- Always specify `SampleRate=Fs` in `designfilt()` and plot in Hz with `freqz(d, [], Fs)`
- Use `filterAnalyzer()` for multi-filter comparison, not custom `freqz`/`grpdelay` plots
- Use SOS form for IIR (avoid `[b,a]` for order > 8)
- Use `tiledlayout`/`nexttile` for multi-panel figures (not `subplot`)

----

Copyright 2026 The MathWorks, Inc.

----
