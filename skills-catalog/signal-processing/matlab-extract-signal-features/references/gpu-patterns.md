# GPU acceleration patterns

Generic guidance for running signal feature extraction on a GPU when one is available.

## Toolbox requirements

- `canUseGPU` — core MATLAB (no toolbox required). Always safe to call on any machine.
- `gather` — core MATLAB free-function; a no-op on non-GPU data types (no toolbox required).
- `gpuArray` — **requires Parallel Computing Toolbox**. Only call after `canUseGPU()` returns `true`.

## The guard pattern

Always check `canUseGPU()` before enabling the GPU path. Calling `gpuArray` on a machine without a usable GPU raises a hard error instead of a graceful fallback.

`canUseGPU()` returns `false` for two very different reasons:

- **No GPU is present.** Expected on CPU-only machines. The CPU fallback above is correct — nothing to fix.
- **A GPU is present but not usable.** Parallel Computing Toolbox is unlicensed, the NVIDIA driver is outdated, the device is in a prohibited/exclusive compute mode, or (in a container) device passthrough isn't configured. Here the CPU fallback silently hides a setup problem you may have wanted to fix.

If you *expected* GPU acceleration and it didn't happen, use the `matlab-setup-gpu` skill to diagnose availability (it covers unlicensed PCT, driver and compute-mode issues, device selection, and Windows TDR timeouts). That skill requires R2024b or later.

### Array input pattern

Use this when `extract` receives an in-memory signal array:

```matlab
if canUseGPU()
    x = gpuArray(x);
end
features = extract(sFE, x);
```

### Datastore input pattern

When the input is a `signalDatastore` or `audioDatastore`, enable GPU output on the datastore instead of wrapping data in `gpuArray`:

```matlab
if canUseGPU()
    ds.OutputEnvironment = "gpu";
end
features = extract(sFE, ds);
```

The feature table may contain `gpuArray` columns after `extract`. This is fine. Keep the output on GPU when downstream steps can use it there, especially AI/ML workflows that also support GPU acceleration. Do not `gather` by default. Call `gather` only when a specific downstream consumer requires CPU data, such as export to disk or a function that explicitly errors on `gpuArray` input.

```matlab
% Gather only for a CPU-only consumer such as file export
featuresForSave = gather(features);
save("results.mat", "featuresForSave");
```

## Why not call `gpuArray` unconditionally and catch?

Two reasons:

- **Fast path latency.** A failed `gpuArray` call on a CPU-only machine surfaces a GPU initialization error that's expensive and confusing. The `canUseGPU()` guard returns instantly.
- **Predictable error semantics.** `try`/`catch` around `gpuArray` swallows real GPU problems (driver issues, out-of-memory) along with the no-device case. The guard separates "no GPU here" from "GPU is here but failing."

## When the GPU path makes sense

Always profile with and without `gpuArray` on representative data before concluding whether GPU is faster. Do not assume speedup or slowdown based on signal length heuristics alone.

General indicators that suggest GPU *may* help:

- Long signals where per-frame computation dominates (large `FrameSize` with many frames, or large datasets being looped over a single extractor).
- Repeated calls with the same extractor configuration on different signals — the `gpuArray` conversion cost amortizes.

For short signals or one-shot calls, conversion overhead *can* outweigh the speedup — but the only way to know is to measure. Profile both paths on your actual data and hardware.

## Common errors

| Trigger | Identifier (typical) | Fix |
|---|---|---|
| `gpuArray(x)` with no GPU available | `parallel:gpu:device:DeviceNotAvailable` | Use the `canUseGPU()` guard. If you expected a GPU, use the `matlab-setup-gpu` skill to diagnose why it isn't usable. |
| Mixing `gpuArray` and CPU arrays in `extract` | depends on extractor | Keep all inputs on the same device. |
| `array2table(gpuResult)` errors | varies | `array2table` does not accept gpuArray. Use `table(gpuVar1, gpuVar2, ...)` to build tables containing gpuArray columns. |
| A specific function errors on gpuArray input | varies | Call `gather` on that variable only. Do not blanket-gather all outputs — many functions accept gpuArrays. If unsure whether a function supports gpuArray, try it and check for an error rather than preemptively gathering. |

## When each extractor gained `gpuArray` support

`gpuArray` input to `extract` requires Parallel Computing Toolbox and is only available from the release listed below. On an earlier release the extractor object may exist but passing a `gpuArray` errors — check the release before enabling the GPU path.

| Extractor | Object introduced | `gpuArray` support since |
|---|---|---|
| `signalTimeFeatureExtractor` | R2021a | R2023a |
| `signalFrequencyFeatureExtractor` | R2021b | R2023a |
| `signalTimeFrequencyFeatureExtractor` | R2024a | **R2024b** |

Note the one-release gap for `signalTimeFrequencyFeatureExtractor`: the object shipped in R2024a but did not accept `gpuArray` input until R2024b. Do not offer the GPU path for time-frequency extraction on R2024a.

## Per-extractor GPU support (verified R2025b, NVIDIA RTX A5000)

| Extractor | Transform | GPU supported | Speedup (30s @ 48 kHz) |
|---|---|---|---|
| `signalTimeFeatureExtractor` | n/a | ✅ | 0.10× (slower — transfer overhead dominates) |
| `signalFrequencyFeatureExtractor` | n/a | ✅ | 2.0× |
| `signalTimeFrequencyFeatureExtractor` | `spectrogram` | ✅ | 0.92× (negligible) |
| `signalTimeFrequencyFeatureExtractor` | `wavelet` | ✅ | **26.8×** |
| `signalTimeFrequencyFeatureExtractor` | `emd` | ❌ (R2025b) | n/a — hard error |
| `signalTimeFrequencyFeatureExtractor` | `vmd` | ❌ (R2025b) | Shares implementation with EMD |

**On R2026a**, the `extract` function supports GPU array input with the following limitations when `sFE` is a `signalTimeFrequencyFeatureExtractor`:

* Extracting features from the `"emd"` and `"vmd"` transforms of GPU array input is not supported.
* The `InstantaneousEnergy` property is supported only if you specify `Transform` as `"wavelet"` or `"waveletpacket"`.

For more information, see [Run MATLAB Functions on a GPU](https://www.mathworks.com/help/parallel-computing/run-matlab-functions-on-a-gpu.html) (Parallel Computing Toolbox).

**Profiling guidance:** The benchmarks above are from one hardware configuration (RTX A5000, 30 s signal @ 48 kHz). Your results will differ by signal length, GPU model, and MATLAB release. Profile before deciding — do not skip GPU based on these numbers alone.

----

Copyright 2026 The MathWorks, Inc.

----
