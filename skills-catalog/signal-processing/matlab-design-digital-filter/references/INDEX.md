# Reference Index

**Quick-ref files contain critical gotchas. You MUST read the relevant quick-ref before writing any code that uses the functions listed below. Skipping them causes errors.**

- **Quick-ref**: Short, task-focused. Read before calling specific functions. If sufficient, skip the guide.
- **Guides**: Deep reference. Read when the quick-ref isn't enough or you need full context.

---

## Function-Level Routing (read the quick-ref or you WILL hit errors)

| Function / Pattern | Quick-ref to read |
|--------------------|-------------------|
| `designfilt(...)` any response | `quick-ref/designfilt.md` |
| `iirnotch(...)`, `iircomb(...)` | `quick-ref/designfilt.md` |
| `ifir(...)`, `design(..., 'ifir')` | `quick-ref/multistage-ifir.md` |
| `filterAnalyzer(...)` | `quick-ref/filter-analyzer.md` |
| `dsp.FIRDecimator`, `dsp.FIRInterpolator` | `quick-ref/multirate-streaming.md` |
| `resample(...)` for filtering | `quick-ref/multirate-offline.md` |
| `filtfilt(...)` | `quick-ref/general-iir-fir.md` |
| High-order IIR (>8), long FIR (>100 taps), `freqz`/`grpdelay` | `quick-ref/general-iir-fir.md` |

---

## Task-Level Routing

| Trigger / task | Quick-ref to read | Guide (if needed) |
|----------------|-------------------|-------------------|
| `trans_pct < 2%` or "very sharp / tight transition" | `quick-ref/efficient-filtering.md` | `efficient-filtering.md` |
| Cost comparison / "fastest/cheapest" / MPIS | `quick-ref/efficient-filtering.md` | `efficient-filtering.md` |
| Using **Filter Analyzer** (`filterAnalyzer`, session mgmt, overlays) | `quick-ref/filter-analyzer.md` | `filter-analyzer.md` |
| **Multirate OFFLINE** (rate change + zero-phase) | `quick-ref/multirate-offline.md` | `multirate.md` |
| **Multirate STREAMING** (polyphase System objects) | `quick-ref/multirate-streaming.md` | `multirate.md` |
| **Constant-rate multistage FIR** (IFIR method) | `quick-ref/multistage-ifir.md` | `multistage-ifir.md` |

---

## Quick-Ref Summary

| Quick-ref | Purpose | ~Lines |
|-----------|---------|--------|
| `quick-ref/designfilt.md` | Response types, params, gotchas | ~190 |
| `quick-ref/general-iir-fir.md` | High-order IIR, long FIR, freqz, filtfilt | ~125 |
| `quick-ref/efficient-filtering.md` | Narrow transitions, MPIS comparison | ~130 |
| `quick-ref/filter-analyzer.md` | Filter Analyzer API | ~100 |
| `quick-ref/multirate-offline.md` | Offline zero-phase with rate change | ~60 |
| `quick-ref/multirate-streaming.md` | Streaming polyphase pipelines | ~75 |
| `quick-ref/multistage-ifir.md` | IFIR at constant rate | ~95 |

---

## Guides (deep reference, rarely needed full)

| Guide | Content | ~Lines |
|-------|---------|--------|
| `patterns.md` | Streaming wrappers, advanced patterns | ~400 |
| `best-practices.md` | Methodology, validation flow | ~375 |
| `filter-analyzer.md` | Full Filter Analyzer reference | ~515 |
| `multirate.md` | Complete multirate theory + examples | ~405 |
| `efficient-filtering.md` | Deep dive on narrow transitions | ~375 |
| `multistage-ifir.md` | IFIR theory and variants | ~290 |


----

Copyright 2026 The MathWorks, Inc.

----
