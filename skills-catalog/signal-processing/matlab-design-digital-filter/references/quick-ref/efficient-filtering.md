# Efficient Filtering Card (`trans_pct < 2%`)

Use this card when the transition band is **narrow** or you need to compare **compute cost** across architectures.

```matlab
trans_pct = 100 * (Fstop - Fpass) / Fs;
```

If `trans_pct < 2%`, a single-stage FIR may be hundreds of taps. **Stop and compare architectures** instead of committing early.

## Step 0 — compute the planning metrics

```matlab
trans_bw  = Fstop - Fpass;
trans_pct = 100 * trans_bw / Fs;
M_max     = floor(Fs/(2*Fstop));   % upper bound for lowpass-safe decimation
```

## Step 1 — do not guess: confirm the intent

You must know:
- Mode: **streaming** (causal) vs **offline** (batch)
- Phase: **zero-phase**, **linear-phase**, or **don't-care**
- Whether internal **rate change** is acceptable (multirate pipelines)

If any is unknown: ask, then stop.

## Step 2 — pick the viable candidate families (don't force all four)

For `trans_pct < 2%`, present **2–4 viable candidates**, not a fixed set.

### Quick lookup: Mode × Phase → Viable families

| Mode | Phase | Single-stage IIR | Single-stage FIR | Multirate | IFIR |
|------|-------|------------------|------------------|-----------|------|
| **Streaming** | linear-phase | ❌ | ✅ | ✅ polyphase | ✅ |
| **Streaming** | don't-care | ✅ | ✅ | ✅ polyphase | ✅ |
| **Offline** | zero-phase | ✅ `filtfilt()` | ✅ `filtfilt()` | ✅ `resample()+filtfilt()` | ✅ `filtfilt()` |
| **Offline** | linear-phase | ❌ | ✅ | ✅ polyphase | ✅ |
| **Offline** | don't-care | ✅ | ✅ | ✅ either | ✅ |

**Key insight**: Polyphase multirate (FIR decimator/interpolator) gives **linear-phase** — it's NOT limited to offline zero-phase workflows.

### Family details

| Family | Viable when | Quick notes |
|---|---|---|
| Single-stage **IIR** | phase ≠ "linear-phase" | Offline can use `filtfilt()` for zero-phase. Streaming IIR is efficient but non-linear phase. |
| Single-stage **FIR** | always viable | Linear phase possible, but may be long / high latency / high MPIS. |
| **Multirate pipeline** (dec→filter→interp) | rate change OK | **Streaming**: polyphase System objects (linear-phase). **Offline zero-phase**: `resample()` + `filtfilt()`. Never mix `filtfilt` with System objects. |
| **Constant-rate multistage FIR** (IFIR method) | rate change NOT OK | FIR-like behavior at constant rate with fewer multipliers than single-stage FIR in many narrow-band cases. |

If a family is excluded, say so explicitly (one line), e.g.:
- "Excluded IIR: user requires linear phase in streaming."
- "Excluded multirate: user cannot change internal sample rate."

### Choosing between IFIR and Notch+LP

When the spectrum shows a **dominant tonal interferer** near the transition band, consider a **Notch + relaxed LP** hybrid:

| Approach | Best when |
|----------|-----------|
| **Notch + relaxed LP** | Known tonal interferer you can notch out (allows wider transition) |
| **IFIR** | General narrow transition, no specific tone to exploit |
| Single-stage FIR | Baseline (always works) |

**Decision rule:**
1. Analyze spectrum for dominant tones in/near transition band
2. If tone found: try Notch (at tone freq) + relaxed LP (wider Fstop)
3. Compare MPIS via `cost()` — pick the cheaper option
4. If no identifiable tone → use IFIR or single FIR

## Step 3 — feasibility check (order estimates)

### Default "MATLAB-native" flow (recommended)

Let `designfilt` pick the minimum order from `Rp/Rs`, then query `filtord(d)`.

```matlab
d_try = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="equiripple");

N = filtord(d_try);
```

### FIR planning estimates (useful for architecture decisions)

```matlab
dev_p = (10^(Rp/20)-1)/(10^(Rp/20)+1);  % passband deviation (linear)
dev_s = 10^(-Rs/20);                    % stopband deviation (linear)

[Nk,~,~,~] = kaiserord([Fpass Fstop],[1 0],[dev_p dev_s], Fs);
[Np,~,~,~] = firpmord([Fpass Fstop],[1 0],[dev_p dev_s], Fs);
```

Use these as "order smell tests," not absolute truth.

## Step 4 — compute MPIS with `cost()`

**MPIS = Multiplications Per Input Sample**, reported by `cost()` on DSP System objects.

### 80/20 rules

- Tap count alone lies (multirate runs parts at lower rate; IIR cost isn't "sections × taps").
- Prefer **System objects** + `cost()`:
  - FIR → `dsp.FIRFilter`
  - IIR → `dsp.SOSFilter` (often easiest via `designfilt(..., SystemObject=true)`)
  - Pipelines → `dsp.FilterCascade`

### FIR MPIS

```matlab
d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="equiripple");

firSys = dsp.FIRFilter("Numerator", d_fir.Numerator);
mpis_fir = cost(firSys).MultiplicationsPerInputSample;
```

### IIR MPIS (prefer SystemObject=true)

```matlab
% Returns dsp.SOSFilter directly (stable + stateful)
iirSys = designfilt("lowpassiir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="ellip", ...
    SystemObject=true);

mpis_iir = cost(iirSys).MultiplicationsPerInputSample;
```

### Pipeline MPIS

```matlab
pipe = dsp.FilterCascade(stage1, stage2, stage3);
mpis_pipe = cost(pipe).MultiplicationsPerInputSample;
```

For multirate decimate→filter→interpolate pipelines, `cost(pipe)` accounts for polyphase structure and internal rates.

### Offline `filtfilt()` note

- `filtfilt()` runs the filter **twice** → compute cost is roughly **2×** the single-pass cost.
- The effective magnitude response is **squared** (≈ doubles attenuation in dB).

## Step 5 — compare with Filter Analyzer

- Open Filter Analyzer and overlay candidates (see `references/INDEX.md` for the filter-analyzer quick-ref).

Minimum comparisons to show:
- Magnitude response (meet specs)
- Group delay (latency + phase behavior)
- MPIS (when compute matters)

---

## `resample()` note

`resample()` uses internal filters not exposed to `cost()`.
If you need performance numbers for an offline `resample()` pipeline, use `timeit()` on your machine.


----

Copyright 2026 The MathWorks, Inc.

----
