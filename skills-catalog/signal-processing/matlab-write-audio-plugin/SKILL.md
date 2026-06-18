---
name: matlab-write-audio-plugin
description: >
  Guide authoring of Audio Toolbox plugins (audioPlugin, audioPluginSource) that pass
  validateAudioPlugin and generate deployable VST/AU code. Use when creating audio effect
  or generator plugins, writing classdef files inheriting from audioPlugin, or troubleshooting
  validateAudioPlugin failures.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Writing Audio Plugins in MATLAB

## When To Use

- Creating audio effect or generator plugins (classdef inheriting from `audioPlugin` or `audioPluginSource`)
- Troubleshooting `validateAudioPlugin` or `generateAudioPlugin` failures
- Converting a MATLAB audio algorithm into a deployable VST/AU plugin
- Integrating deep learning inference into a real-time audio plugin

## When NOT To Use

- General MATLAB class authoring unrelated to audio plugins
- Audio file I/O, feature extraction, or analysis (no plugin involved)
- Simulink audio processing blocks
- Writing Audio Toolbox functions that are not plugins (e.g., `audioDatastore`, `audioFeatureExtractor`)

## Structure

Every audio plugin is a classdef with `%#codegen`, public tunable properties, a Constant `PluginInterface`, and methods `process` + `reset`.

```matlab
classdef MyPlugin < audioPlugin
%#codegen

    properties
        Gain = 0.5
        Cutoff = 1000
    end

    properties (Access = private)
        pSR = 44100
        pB = [1 0 0]
        pA = [1 0 0]
        pState = zeros(2, 2)  % (filterOrder, numChannels)
    end

    properties (Constant)
        PluginInterface = audioPluginInterface( ...
            audioPluginParameter('Gain', ...
                DisplayName='Gain', Label='dB', Mapping={'lin', 0, 1}), ...
            audioPluginParameter('Cutoff', ...
                DisplayName='Cutoff', Label='Hz', Mapping={'log', 20, 20000}), ...
            InputChannels=2, OutputChannels=2)
    end

    methods
        function y = process(plugin, x)
            [y, plugin.pState] = filter(plugin.pB, plugin.pA, x, plugin.pState);
            y = y * plugin.Gain;
        end

        function reset(plugin)
            plugin.pSR = getSampleRate(plugin);
            plugin.pState = zeros(2, 2);
            designFilter(plugin);
        end

        function set.Cutoff(plugin, val)
            plugin.Cutoff = val;
            designFilter(plugin); %#ok<MCSUP>
        end
    end

    methods (Access = private)
        function designFilter(plugin)
            wn = plugin.Cutoff / (plugin.pSR / 2);
            wn = max(eps, min(wn, 1 - eps));
            [plugin.pB, plugin.pA] = butter(2, wn);
        end
    end
end
```

**Source plugins** inherit `audioPluginSource`, omit `InputChannels`, and `process` takes no audio input — use `getSamplesPerFrame(plugin)` for output frame size.

**System Object hybrids** (`matlab.System & audioPlugin`) require `(StrictDefaults)`, `isInputSizeMutableImpl` returning `true`, and `stepImpl`/`resetImpl` instead of `process`/`reset`. Use only when user requests Simulink compatibility.

---

## Plugin Lifecycle

1. **Constructor** — Construct all sub-objects with literal arguments. `getSampleRate` returns 44100 here; use for initial buffer sizing only.
2. **`reset`** — Called when sample rate or frame size changes. Cache `getSampleRate(plugin)` in `pSR`. Recompute all SR-dependent values. Call `reset()` on every sub-object (after setting their sample rate).
3. **`process`** — Called per audio frame. Return `double` output sized `[N, numOutputChannels]`. Never assign to properties registered in `audioPluginParameter` — for output meters, keep properties public but unregistered.
4. **Set methods** — Recompute derived values (coefficients, buffer sizes) when parameters change. Add `%#ok<MCSUP>` only when the set method actually accesses another property through `obj.PropertyName` or calls a method that does (e.g., `designFilter(plugin)` from `set.Cutoff`). Do not add it preemptively — only suppress warnings that checkcode actually raises on that line.
5. **Save/load (optional, MATLAB-only)** — Only needed when the plugin has private state that `reset` cannot reconstruct from parameters and sample rate (e.g., loaded data, handle sub-objects with internal buffers). Not compiled into generated VSTs/standalones — DAW hosts persist parameters via the plugin interface and call `reset` on restore. See `references/advanced-patterns.md` for the pattern.

---

## Codegen Requirements

All code must be codegen-compatible. `validateAudioPlugin` sweeps 5 sample rates (8000–192000), frame sizes `2.^(1:13)+1` (max 8193), and all parameter extremes.

**Always use built-in functions over hand-implementations.** Prefer toolbox functions in this order: Audio Toolbox → DSP System Toolbox → Signal Processing Toolbox → base MATLAB. If unsure whether a codegen-compatible built-in exists for an operation, consult `references/available-functions.md` before implementing manually.

### Buffers and State

Pre-allocate all state to maximum needed size. Codegen locks property size from the constructor's last assignment — allocate at the **maximum** the parameter can reach, then index into the active region at runtime.

Shift with indexed assignment:

```matlab
buf(1:end-N) = buf(N+1:end);   % shift left by N
buf(end-N+1:end) = newData;     % fill tail
```

Never concatenate to shift — `[buf(N+1:end); zeros(N,ch)]` produces a variable-size result that codegen rejects on assignment to a fixed-size property.

Never use `:` on the column dimension when assigning to a fixed-size property — codegen treats `x(i,:)` as variable-size. Index columns explicitly: `[x(i,1), x(i,2)]`.

Initialize arrays that will hold complex values with `complex(zeros(...))` — not bare `zeros(...)`. Codegen locks the real/complex attribute from the first assignment. If the array starts real, assigning FFT output into it later fails with "left-hand side constrained to be non-complex."

`dsp.AsyncBuffer` capacity must exceed the largest single `write` the plugin will receive. `validateAudioPlugin` delivers frames up to 8193 samples; account for that plus any overlap when sizing the buffer.

When `filter()` input comes from a sub-object (e.g., `crossoverFilter`), codegen cannot propagate the column count — the returned state becomes variable-size. Process channels explicitly:

```matlab
[low(:,1), plugin.pState(:,1)] = filter(b, a, low(:,1), plugin.pState(:,1));
[low(:,2), plugin.pState(:,2)] = filter(b, a, low(:,2), plugin.pState(:,2));
```

### Enum Parameters (Different-Length Values)

Use `Style='dropdown'` for 3+ values, `'vrocker'`/`'vtoggle'` for exactly 2.

When enum values have different character lengths (`'On'`/`'Off'`, `'Short'`/`'VeryLong'`), prefer a separate `int32` enum class file. The framework can handle char padding internally, but an explicit enum class produces cleaner generated code with typed dispatch instead of string comparisons:

```matlab
% MyMode.m
classdef MyMode < int32
    enumeration
        Normal     (0)
        Aggressive (1)
        Subtle     (2)
    end
end
```

Plugin property: `Mode = MyMode.Normal` with `Mapping={'enum','Normal','Aggressive','Subtle'}`.

### Derived Values from Parameters

When computing normalized frequency or delay indices from parameters, clamp the result:

```matlab
wn = plugin.Cutoff / (plugin.pSR / 2);
wn = max(eps, min(wn, 1 - eps));   % keep in valid (0,1) range for butter/cheby
```

Clamp delay-line read indices to `[1, bufferLength]`. This prevents out-of-bounds at extreme sample rates or parameter settings that `validateAudioPlugin` will exercise.

### Switch Completeness

Every `switch` that assigns a variable must include `otherwise` with a safe default — codegen requires all branches to define the same outputs.

### Sub-Objects

Construct with **literal arguments** in the constructor. In `reset`, propagate sample rate then reset:

```matlab
function reset(plugin)
    fs = getSampleRate(plugin);
    setSampleRate(plugin.pEcho, fs);
    reset(plugin.pEcho);
    plugin.pCompressor.SampleRate = fs;
    reset(plugin.pCompressor);
end
```

Call sub-plugins as `process(plugin.pSub, x)`. Call System Objects as `plugin.pObj(x)`. Forward parameter changes in set methods.

### External Data and Runtime-Only Calls

- Load data files: `coder.load('data.mat')` in the constructor — baked into the binary
- Guard non-codegen calls: wrap `fprintf`/`disp`/`plot` in `if isempty(coder.target)`

---

## Validation

```matlab
validateAudioPlugin -nomex ClassName   % structural + testbench
validateAudioPlugin ClassName          % full MEX codegen
generateAudioPlugin ClassName          % produce VST/AU binary
```

After validation passes:

1. Run `checkcode` on all produced `.m` files — resolve every warning by renaming or restructuring, not by adding `%#ok` suppressions (except `%#ok<MCSUP>` in set methods). Re-run checkcode to confirm zero warnings remain.
2. Verify functional behavior: instantiate, `setSampleRate`, `reset`, process a test signal, confirm output matches intent.

## Generation

Default output is VST 2. Use flags to select other formats:

| Flag | Format | Platform |
|------|--------|----------|
| `-vst` | VST 2 (default) | Windows, macOS |
| `-vst3` | VST 3 | Windows, macOS |
| `-au` | Audio Unit v2 | macOS only |
| `-auv3` | Audio Unit v3 | macOS only |
| `-exe` | Standalone executable | Windows, macOS |
| `-juceproject` | JUCE project (source code) | All (including Linux) |

When the user requests an output format unavailable on the current platform (e.g., AU on Windows, or any compiled binary on Linux), explain the constraint and suggest the closest alternative (`-juceproject` on Linux, `-vst`/`-vst3` on Windows instead of AU).

---

## References

- `references/available-functions.md` — Built-in streaming DSP objects (prefer over manual implementations)
- `references/advanced-patterns.md` — AsyncBuffer, modulated delay, save/load, codegen edge cases
- `references/parameters.md` — Mapping laws, multi-bus I/O, grid layout constraints
- `references/grid-layout.md` — Grid layout syntax, row allocation with `DisplayNameLocation`
- `references/deep-learning.md` — Neural network inference with `coder.loadDeepLearningNetwork`

----

Copyright 2026 The MathWorks, Inc.
