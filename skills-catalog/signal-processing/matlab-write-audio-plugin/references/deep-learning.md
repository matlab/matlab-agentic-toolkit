# Deep Learning Inference in Plugins

Use a pretrained network for real-time inference (e.g., denoising, source separation). Requires Deep Learning Toolbox and Audio Toolbox.

## Requirements

| Requirement | How |
|-------------|-----|
| Load network at codegen time | `coder.loadDeepLearningNetwork('model.mat')` in a `persistent` variable |
| Fixed input size to network | Use `dsp.AsyncBuffer` for fixed-size frames (see `advanced-patterns.md`) |
| Input type | `single` — cast with `single(frame)` before `predict` |
| Output type | `double(extractdata(output))` — cast back immediately |
| Declare DL codegen config | Separate `Constant` property (not inside `audioPluginInterface`): `PluginConfig = audioPluginConfig(...)` |
| When to include PluginConfig | Omit for `validateAudioPlugin -nomex`; add for `generateAudioPlugin` deployment |
| Sample rate mismatch | Use `dsp.FIRDecimator`/`dsp.FIRInterpolator`, `dsp.FIRRateConverter`, or `resample()` — never hand-code sample-by-sample interpolation loops. If using `yamnetPreprocess`/`vggishPreprocess`, resampling is handled internally. |
| Normalization | Bake training-time mean/std as constants in the inference function |

## audioPluginConfig — Valid Arguments (EXHAUSTIVE)

| Argument | Value | When to use |
|----------|-------|-------------|
| `DeepLearningConfig` | `coder.DeepLearningConfig('none')` (preferred) | Plugin uses `predict`. Library-free — portable, no runtime dependencies. |
| `CodeReplacementLibrary` | `'ARM Cortex-A (CMSIS)'` or other CRL name | Targeting embedded hardware |
| `LargeConstantGeneration` | `'WriteDNNConstantsToDataFiles'` | Large networks |

Use `'none'` for DeepLearningConfig. The `'mkldnn'` option exists but is being deemphasized — library-free codegen (`'none'`) is the recommended path going forward (see `audiopluginexample.Denoiser`).

Invalid arguments (cause "Invalid argument name"): `InputPort`, `OutputPort`, `DefaultSampleRate`, `FrameSize`. Do not pass `audioPluginConfig(...)` as an argument to `audioPluginInterface(...)`.

## Latency Considerations

Classification/detection plugins have relaxed latency budgets compared to audio effects. A network that needs ~1s of context (e.g., YAMNet needs 0.975s) is acceptable for classification — the result drives gating, control signals, or display, not sample-accurate audio processing. For audio effects (denoising, separation), target <50ms latency to avoid audible delay.

## Sample Rate Conversion for Networks

Networks trained at a fixed rate (e.g., 16 kHz) need decimation/interpolation when the host runs at 44100/48000 Hz. If using `yamnetPreprocess` or `vggishPreprocess`, resampling is handled internally. Otherwise, use `dsp.FIRDecimator`, `dsp.FIRRateConverter`, or `resample()` — never hand-code sample-by-sample interpolation loops.

**`DecimationFactor` and `InterpolationFactor` are non-tunable in codegen** — they cannot be changed after construction. Choose one of these patterns:

### Pattern A: Fixed factor (single host rate)

Use when you know the deployment host rate (e.g., always 48 kHz). Passes `validateAudioPlugin` — at non-matching SRs the decimator still runs but produces incorrect rate conversion. Guard with a factor check if correctness at all SRs matters.

```matlab
% Constructor — factor fixed at construction
plugin.pDecimator = dsp.FIRDecimator(3);       % 48000/16000 = 3
plugin.pInterpolator = dsp.FIRInterpolator(3);

% Reset — reset objects only (do NOT change DecimationFactor)
function reset(plugin)
    plugin.pSR = getSampleRate(plugin);
    reset(plugin.pDecimator);
    reset(plugin.pInterpolator);
end

% Process — decimate before network, interpolate after
downsampled = plugin.pDecimator(x);        % host rate → 16 kHz
output = plugin.pInterpolator(processed);  % 16 kHz → host rate
```

### Pattern B: Multiple objects (all host rates)

Use when `validateAudioPlugin` correctness at all 5 swept SRs matters, or for production deployment. Construct one decimator/interpolator per supported rate and switch in process. Reference: `audiopluginexample.Denoiser`.

```matlab
% Constructor — one pair per supported host rate, setup to lock dimensions
plugin.pDec48 = dsp.FIRDecimator(3);           % 48000/16000
plugin.pDec96 = dsp.FIRDecimator(6);           % 96000/16000
plugin.pDec192 = dsp.FIRDecimator(12);         % 192000/16000
plugin.pSRC441 = dsp.FIRRateConverter(80, 441); % 44100/16000 (non-integer)
setup(plugin.pDec48, zeros(1536, 1));
setup(plugin.pDec96, zeros(1536, 1));
setup(plugin.pDec192, zeros(1536, 1));
setup(plugin.pSRC441, zeros(1536, 1));

% Process — switch on cached SR
switch plugin.pSR
    case 48000
        xDown = plugin.pDec48(x);
    case 96000
        xDown = plugin.pDec96(x);
    case 192000
        xDown = plugin.pDec192(x);
    case 44100
        xDown = plugin.pSRC441(x);
    otherwise
        xDown = x;  % 16000 or unsupported — pass through
end
```

For non-integer ratios (e.g., 44100/16000), use `dsp.FIRRateConverter(L, M)` where `L/M = targetRate/hostRate` in lowest terms.

### Codegen constraint: System Object channel count must be locked

Codegen needs to know a System Object's output channel count at compile time. If the first call to a System Object occurs inside a conditional branch, codegen cannot prove the channel count, producing: "Unable to calculate a constant value for nontunable property 'CompiledNumChannels'."

Fix: call `setup` in the constructor to lock the channel count before any conditional usage.

```matlab
% Constructor — lock channel count
plugin.pDecimator = dsp.FIRDecimator(3);
setup(plugin.pDecimator, zeros(1536, 1));  % locks output to [512, 1]

% Process — now safe inside conditional branches
if plugin.pInputBuffer.NumUnreadSamples >= 1536
    chunk = read(plugin.pInputBuffer, 1536);
    xDown = plugin.pDecimator(chunk);     % codegen knows size
    write(plugin.pOutputBuffer, xDown);   % works
end
```

## dlarray Format

| Input Layer | dlarray Format | Example |
|-------------|---------------|---------|
| `ImageInputLayer` (e.g., [1024 1 1]) | `'SSCB'` | Spectrogram, raw waveform as 2-D |
| `FeatureInputLayer` (e.g., 512) | `'CB'` | Feature vector |

Check `net.Layers(1)` to determine which. Wrong format gives: "Invalid number of spatial dimensions."

## Inference Pattern

Call from a local function — `persistent` keeps the network loaded across calls. Use `coder.nullcopy` + indexed assignment to give codegen a fixed-size container:

```matlab
function y = applyNetwork(frame)
    persistent net;
    if isempty(net)
        net = coder.loadDeepLearningNetwork('model.mat');
    end
    fixedFrame = coder.nullcopy(zeros(1024, 1, 'single'));
    fixedFrame(:) = single(frame);
    out = predict(net, dlarray(fixedFrame, 'SSCB'));
    y = double(extractdata(out));
end
```

For deployment, add a separate Constant property:
```matlab
PluginConfig = audioPluginConfig( ...
    DeepLearningConfig=coder.DeepLearningConfig('none'))
```

`'none'` = library-free codegen (preferred — portable, no runtime dependencies). `'mkldnn'` = Intel MKL-DNN (legacy, being deemphasized).

Reference implementation: `audiopluginexample.Denoiser`.

## Classification / Detection Plugins

Audio plugin `process` must return an audio frame the same size as its input. If the network produces a non-audio result (classification, detection, control signal), options for using it:

1. **Drive internal processing** — use the result to control gain, gating, filtering, or other DSP within `process` (e.g., pitch-gate, noise-adaptive EQ).
2. **Map to a numeric output** — convert the result to a control signal or numeric value for downstream consumption by the host or other plugins.
3. **Store in a private property** — expose as a read-only parameter or meter in the DAW UI.
4. **Send externally via UDP** — use `dsp.UDPSender` to transmit results to MATLAB or another application for display. See the "Communicate Between a DAW and MATLAB Using UDP" example.

In all cases, `process` still returns an audio frame (passthrough `y = x` if no audio modification is needed).

----

Copyright 2026 The MathWorks, Inc.
