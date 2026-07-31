---
name: matlab-process-streaming-audio
description: >
  Design and implement real-time audio processing chains using Audio Toolbox
  streaming objects. Use when building frame-based audio processing loops,
  multiband filters, dynamic range control, parametric EQ, level metering,
  loudness metering, SPL metering, octave-band analysis, sample rate conversion,
  frequency-domain filtering (long impulse responses, custom filter banks),
  or audio chains in Simulink. Covers visualization (visualize method),
  interactive tuning (parameterTuner), MIDI control, and Audio Toolbox Simulink
  blocks. Use when the user says "real-time audio", "streaming audio",
  "audio filter", "compressor", "equalizer", "level meter", "loudness meter",
  "SPL meter", "octave bands", "crossover filter", "audio chain",
  "MIDI control", "convolution reverb", "impulse response streaming",
  "frequency-domain filter", or asks to process audio frame-by-frame.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Streaming Audio Processing

Design and run real-time audio processing in MATLAB and Simulink using Audio Toolbox streaming objects. These objects maintain internal state across frames, support tunable properties, and provide built-in visualization.

## When to Use

- Building frame-based audio processing loops
- Filtering audio in real time (crossover, EQ, shelving, octave)
- Applying dynamic range control (compressor, limiter, expander, noise gate)
- Measuring audio levels (peak, loudness, SPL, octave-band spectra)
- Resampling audio signals (sample rate conversion)
- Applying long impulse responses in real time (frequency-domain filtering)
- Tuning audio parameters interactively while streaming
- Visualizing filter responses or compressor characteristics
- Controlling audio parameters with MIDI devices
- Building audio processing chains in Simulink

## When NOT to Use

- Audio device I/O setup with `audiostreamer` — use the `matlab-play-record-audio` skill
- Audio plugin generation (VST/AU via `createAudioPluginClass`)
- Deep learning audio features or inference
- Offline batch processing of entire files without streaming

## Workflow

Every streaming audio task follows this pattern:

1. **Create source** — `dsp.AudioFileReader` (or `audiostreamer` for live I/O)
2. **Create processing objects** — Audio Toolbox System objects configured for your sample rate
3. **Visualize responses** — call `visualize(obj)` on filter/DRC objects
4. **Open tuning UI** — call `parameterTuner(obj)` for interactive control
5. **Process in a loop** — read frames, process, write output
6. **Clean up** — `release` all objects

```matlab
% Standard streaming audio processing pattern
reader = dsp.AudioFileReader("input.wav", SamplesPerFrame=256);
fs = reader.SampleRate;

crossFilt = crossoverFilter(2, [500 4000], SampleRate=fs);
comp = compressor(Threshold=-20, Ratio=4, SampleRate=fs);

visualize(crossFilt);
visualize(comp);
parameterTuner(crossFilt);
parameterTuner(comp);

while ~isDone(reader)
    audioIn = reader();
    [low, mid, high] = crossFilt(audioIn);
    low = comp(low);
    audioOut = low + mid + high;
    drawnow limitrate  % flush UI events so parameterTuner changes take effect
end

release(reader);
release(crossFilt);
release(comp);
```

## Key Functions

### Use These (Audio Toolbox objects)

| Object | Purpose | Use instead of |
|--------|---------|---------------|
| `crossoverFilter` | Split signal into frequency bands | `butter` + `filter` |
| `compressor` | Dynamic range compression | Custom envelope/gain code |
| `limiter` | Peak limiting | Custom clipping code |
| `expander` | Dynamic range expansion | Custom gate code |
| `noiseGate` | Gate signals below threshold | Manual threshold logic |
| `multibandParametricEQ` | N-band parametric EQ with shelves | Manual biquad coefficient math |
| `graphicEQ` | Graphic equalizer | Manual filter bank |
| `shelvingFilter` | Low/high shelf filter | Manual shelf design |
| `audioLevelMeter` | Digital peak level meter (sample-peak or true-peak, dBFS/dBTP) | Manual peak detection code |
| `loudnessMeter` | EBU R128 loudness (momentary, short-term, integrated, LU range) | Manual loudness computation |
| `octaveSpectrumEstimator` | Octave-band spectrum with weighting (R2024b) | `octaveFilterBank` + manual RMS/dB |
| `splMeter` | Sound pressure level measurement (time-weighted, per-band) | Manual SPL computation |
| `weightingFilter` | A/C/Z frequency weighting | Manual weighting curves |
| `octaveFilter` | Single octave-band filter | Manual bandpass design |
| `octaveFilterBank` | Multi-band octave filtering | Manual parallel filters |
| `audioresample` | Sample rate conversion (R2023b) | `resample` or manual interpolation |
| `designAudioResampler` | Design SRC for streaming (R2023b) | `dsp.SampleRateConverter` alone |
| `designParamEQ` | Design parametric EQ coefficients | Manual biquad formulas |
| `designShelvingEQ` | Design shelving filter coefficients — positional: `(gain, slope, Fc, type)` | Manual shelf formulas |
| `designVarSlopeFilter` | Design variable-slope LP/HP — positional: `(slope, Fc, type)` | Manual Butterworth cascades |
| `reverberator` | Artificial reverberation | Custom delay networks |
| `audioTimeScaler` | Real-time time stretching (frame-based, no `SampleRate` property) | Manual phase vocoder |
| `dsp.STFT` | Streaming short-time FFT with windowing + overlap (R2019a) | Manual buffer/window/FFT code |
| `dsp.ISTFT` | Streaming inverse STFT with perfect reconstruction (R2019a) | Manual IFFT/overlap-add code |
| `dsp.FrequencyDomainFIRFilter` | FFT-based FIR filtering for long IRs (fixed coefficients) | Manual overlap-add/save code |

### Universal Methods

| Method/Function | Purpose |
|-----------------|---------|
| `visualize(obj)` | Show response plot (frequency, static characteristic, spectrum). **Not supported** by `reverberator` or `splMeter`. |
| `parameterTuner(obj)` | Open interactive slider UI for all tunable properties |
| `obj(audioIn)` | Process one frame (call object like a function) |
| `release(obj)` | Free resources, allow property changes |
| `reset(obj)` | Reset internal states without releasing |

### MIDI Control Functions

| Function | Purpose |
|----------|---------|
| `mididevinfo` | List available MIDI devices |
| `mididevice` | Connect to a MIDI device |
| `midimsg` | Create MIDI messages |
| `midisend` | Send MIDI messages to device |
| `midireceive` | Receive MIDI messages from device |
| `midicallback` | Define callback for MIDI control changes |
| `midicontrols` | Open a group of MIDI controls for reading |
| `midiid` | Interactively identify a MIDI control |
| `midiread` | Read most recent MIDI control values |
| `midisync` | Send values to MIDI controls to synchronize |

## Patterns

### Visualization and Tuning

`parameterTuner` works on every Audio Toolbox streaming object. `visualize` works on most objects — exceptions: `reverberator` and `splMeter` (use `parameterTuner` instead). Always use these methods instead of building custom UIs.

```matlab
eq = multibandParametricEQ(NumEQBands=5, ...
    HasLowShelfFilter=true, HasHighShelfFilter=true, SampleRate=fs);

% One-line visualization — shows combined magnitude response
visualize(eq);

% One-line interactive tuning — sliders for all tunable properties
parameterTuner(eq);
```

Objects supporting `parameterTuner`: `compressor`, `expander`, `limiter`, `noiseGate`, `octaveFilter`, `crossoverFilter`, `multibandParametricEQ`, `graphicEQ`, `audioOscillator`, `wavetableSynthesizer`, `reverberator`, `shelvingFilter`, `octaveSpectrumEstimator`.

### Multiband Processing

Split → process per band → sum. Use `crossoverFilter` for the split.

```matlab
crossFilt = crossoverFilter(2, [500 4000], 48, fs);  % 2 crossovers, 48 dB/oct
compLow = compressor(Threshold=-20, Ratio=4, SampleRate=fs);
compMid = compressor(Threshold=-15, Ratio=3, SampleRate=fs);
compHigh = compressor(Threshold=-10, Ratio=2, SampleRate=fs);

% In the processing loop:
[low, mid, high] = crossFilt(audioIn);
audioOut = compLow(low) + compMid(mid) + compHigh(high);
```

### Parametric Equalization

Use `multibandParametricEQ` for streaming EQ. It supports N bands, optional low/high shelves, optional lowpass/highpass, and oversampling.

```matlab
eq = multibandParametricEQ( ...
    NumEQBands=5, ...
    EQOrder=4, ...
    Frequencies=[100 400 1000 4000 8000], ...
    QualityFactors=[0.7 1.5 2.0 1.8 0.7], ...
    PeakGains=[3 -2 4 -1.5 2], ...
    HasLowShelfFilter=true, LowShelfCutoff=80, LowShelfGain=2, ...
    HasHighShelfFilter=true, HighShelfCutoff=12000, HighShelfGain=-1, ...
    SampleRate=fs);

visualize(eq);
parameterTuner(eq);

% In the loop — all properties are tunable while streaming:
audioOut = eq(audioIn);
```

For coefficient-level control (e.g., feeding a `dsp.SOSFilter`), use design functions:

```matlab
% designParamEQ — name-value syntax
[B, A] = designParamEQ(CenterFrequency=1000/(fs/2), ...
    QualityFactor=2, Gain=6, FilterOrder=4);

% designShelvingEQ — positional syntax: (gain, slope, normalizedFc, type)
[B, A] = designShelvingEQ(3, 0.8, 200/(fs/2), "lo", Orientation="row");

% designVarSlopeFilter — positional syntax: (slope, normalizedFc, type)
[B, A] = designVarSlopeFilter(24, 5000/(fs/2), "lo", Orientation="row");
```

### Metering

Choose the metering object based on what you are measuring:

| Object | Measures | Standard | `visualize` support |
|--------|----------|----------|-------------------|
| `audioLevelMeter` | Sample-peak or true-peak (dBFS/dBTP) | IEC 60268-18 | Yes — peak meter bars with decay |
| `loudnessMeter` | Momentary, short-term, integrated loudness + range (LUFS/LU) | EBU R128 / ITU-R BS.1770 | Yes — full EBU Mode meter |
| `splMeter` | Sound pressure level per octave band | IEC 61672 | **No** — use `timescope` to plot outputs |
| `octaveSpectrumEstimator` | Octave-band spectrum with weighting (R2024b) | — | Yes — real-time bar chart |

```matlab
% Digital peak level meter (most common "give me a level meter" answer)
lvl = audioLevelMeter(Method="true-peak", SampleRate=fs);
visualize(lvl);
while ~isDone(reader)
    lvl(reader());
    drawnow limitrate
end

% Broadcast loudness meter (EBU R128)
loud = loudnessMeter(SampleRate=fs);
visualize(loud);
while ~isDone(reader)
    loud(reader());
    drawnow limitrate
end
```

```matlab
% octaveSpectrumEstimator — preferred for octave-band visualization
ose = octaveSpectrumEstimator(fs, ...
    Bandwidth="1/3 octave", ...
    FrequencyWeighting="A-weighting", ...
    TimeWeighting="fast");

visualize(ose);         % Built-in real-time bar chart
parameterTuner(ose);    % Tune bandwidth, weighting, etc. while streaming

while ~isDone(reader)
    audioIn = reader();
    [spectrum, centerFreqs] = ose(audioIn);
end
```

```matlab
% splMeter — when you need Lt, Leq, Lpeak, Lmax outputs
% NOTE: Initial frames return -Inf until the time-weighted filter
% accumulates sufficient energy (~10-50 frames). This is normal.
spl = splMeter( ...
    Bandwidth="1/3 octave", ...
    FrequencyWeighting="A-weighting", ...
    TimeWeighting="fast", ...
    SampleRate=fs);

[Lt, Leq, Lpeak, Lmax] = spl(audioIn);
```

### Streaming Spectral Processing (Per-Bin Manipulation)

Use `dsp.STFT` + `dsp.ISTFT` when you need to manipulate individual frequency bins in a streaming loop (spectral gating, spectral subtraction, phase vocoder effects). These objects handle windowing, overlap, buffering, and perfect reconstruction internally.

```matlab
% Streaming spectral noise gate using dsp.STFT / dsp.ISTFT
fftLen = 1024;
overlapLen = fftLen * 3/4;  % 75% overlap
win = hann(fftLen, 'periodic');

stf = dsp.STFT(win, overlapLen, fftLen);
istf = dsp.ISTFT(win, overlapLen);

reader = dsp.AudioFileReader("input.wav", SamplesPerFrame=fftLen-overlapLen);
writer = dsp.AudioFileWriter("output.wav", SampleRate=reader.SampleRate);

while ~isDone(reader)
    audioIn = reader();
    X = stf(audioIn);           % Windowed FFT with overlap handled
    X(abs(X) < threshold) = 0;  % Per-bin manipulation
    audioOut = istf(X);          % Perfect-reconstruction IFFT + OLA
    writer(audioOut);
end

release(reader); release(writer); release(stf); release(istf);
```

**Ranked by idiom quality for spectral tasks:**
1. `dsp.STFT` + `dsp.ISTFT` — handles all buffering, windowing, COLA internally
2. `dsp.AsyncBuffer` for manual buffering + `fft`/`ifft`
3. Fully hand-rolled buffer shifting (avoid — error-prone, no COLA guarantee)

**Important:** `dsp.FrequencyDomainFIRFilter` does NOT expose per-bin access. It applies a fixed FIR (impulse response) in the frequency domain. Use it for convolution reverb and long IR filtering, not for spectral manipulation.

### Frequency-Domain FIR Filtering (Long Impulse Responses)

Use `dsp.FrequencyDomainFIRFilter` when you need to convolve with a long, fixed impulse response in a streaming loop — room IRs, cabinet IRs, or any scenario where time-domain convolution would be too slow for real-time. The object implements overlap-add (or overlap-save) internally and maintains state across frames.

```matlab
% Stream audio through a long impulse response (e.g., room IR)
[ir, irFs] = audioread("impulse_response.wav");
ir = ir.';  % Numerator must be a row vector
reader = dsp.AudioFileReader("input.wav", SamplesPerFrame=1024);
fs = reader.SampleRate;
writer = audioDeviceWriter(SampleRate=fs);

fdFilt = dsp.FrequencyDomainFIRFilter(ir, ...
    PartitionForReducedLatency=true, ...
    PartitionLength=1024);

while ~isDone(reader)
    audioIn = reader();
    audioOut = fdFilt(audioIn);
    writer(audioOut);
end

release(reader);
release(fdFilt);
release(writer);
```

**When to use which frequency-domain approach:**

| Scenario | Approach |
|----------|----------|
| Per-bin spectral manipulation (gating, subtraction, modification) | `dsp.STFT` + `dsp.ISTFT` |
| Long impulse responses (room IRs, cabinet IRs) | `dsp.FrequencyDomainFIRFilter` |
| Convolution reverb in real time | `dsp.FrequencyDomainFIRFilter` with partitioned convolution |
| Short filters (< 256 taps) | `dsp.FIRFilter` or `dsp.SOSFilter` (time-domain is efficient) |

**Partitioned convolution:** Set `PartitionForReducedLatency=true` and `PartitionLength` to your frame size (e.g., 1024). This splits the IR into partitions, reducing latency to one partition instead of the full IR length — critical for real-time applications.

### Real-Time Pacing for File-Based Loops

When reading from a file with visualizations or metering, the loop runs at full CPU speed — frames fly past faster than the display can render. Add pacing so the visualization is meaningful:

```matlab
frameDuration = reader.SamplesPerFrame / fs;
while ~isDone(reader)
    audioIn = reader();
    % ... process ...
    loud(audioOut);
    drawnow limitrate
    pause(frameDuration);  % Pace to approximately real time
end
```

Alternatively, use `audioDeviceWriter` which inherently blocks to maintain real-time pacing (audio plays through speakers at the correct rate). If you only need file output without real-time playback, pacing is unnecessary.

### Vectorized Per-Frame Gain Smoothing

When applying exponential smoothing toward a constant target within a frame, avoid per-sample `for` loops. The gain trajectory is a geometric series with a closed-form solution:

```matlab
% Instead of per-sample loop:
n = (1:numSamples)';
gainVector = targetGain + (currentGain - targetGain) * smoothingCoeff.^n;
audioOut = audioIn .* gainVector;
currentGain = gainVector(end);
```

This is significantly faster than iterating sample-by-sample and produces identical results when the target gain is constant across the frame.

### Sample Rate Conversion

Use `audioresample` (R2023b) for one-shot conversion or `designAudioResampler` for streaming.

```matlab
% One-shot (entire signal)
audioOut = audioresample(audioIn, InputRate=96000, OutputRate=44100);

% Streaming — design once, use in loop
resampler = designAudioResampler(InputRate=44100, OutputRate=16000);
% resampler is a dsp.FIRRateConverter or dsp.FilterCascade — use in loop:
audioOut = resampler(audioFrame);
```

**SamplesPerFrame alignment:** When streaming with `designAudioResampler`, set `SamplesPerFrame` on the reader to a multiple of the resampler's `DecimationFactor`. This ensures every output frame has a consistent, fixed length. If the frame size is not aligned, output frames vary in length, which breaks downstream fixed-frame processing.

```matlab
% Example: 44100 Hz → 16000 Hz
resampler = designAudioResampler(InputRate=44100, OutputRate=16000);
% DecimationFactor is 441 — set SamplesPerFrame to a multiple of 441
reader = dsp.AudioFileReader("input.wav", SamplesPerFrame=441);
```

### MIDI Control

Use MIDI devices to tune parameters in real time during streaming.

```matlab
% Quick approach — midicontrols for reading control values
controls = midicontrols(1:3);  % 3 MIDI controls (auto-detect with midiid)
while ~isDone(reader)
    vals = midiread(controls);  % Returns values in [0, 1]
    comp.Threshold = -60 + vals(1) * 60;   % Map to [-60, 0] dB
    comp.Ratio = 1 + vals(2) * 19;         % Map to [1, 20]
    audioOut = comp(reader());
end

% Full approach — mididevice for send/receive
device = mididevice("Oxygen 49");
msgs = midireceive(device);
midisend(device, midimsg("ControlChange", 1, 64, 100));
```

### Simulink Audio Chain

See `references/simulink-audio-blocks.md` for the full block catalog. Key setup:

```matlab
% Solver: fixed-step discrete, auto step size
set_param(model, 'Solver', 'FixedStepDiscrete');
set_param(model, 'FixedStep', 'auto');

% Blocks are in these libraries:
%   audiosources  — From Multimedia File, Audio Device Reader, MIDI Controls
%   audiosinks    — Audio Device Writer, Spectrum Analyzer, To Multimedia File
%   audiofilters  — Crossover Filter, Multiband Parametric EQ, Graphic EQ,
%                   Octave Filter, Shelving Filter, Weighting Filter,
%                   Parametric EQ Design, Shelving EQ Design, Variable Slope Filter Design
%   audiodynamicrange — Compressor, Expander, Limiter, Noise Gate
%   audioeffects  — Reverberator
```

**Design blocks** (Parametric EQ Design, Shelving EQ Design, Variable Slope Filter Design) separate filter design from implementation — they output coefficients to feed a SOS/FOS filter block. Use them when:
- You need codegen-friendly architectures
- You want to specify bandwidth by octave or band-edge frequencies
- You need higher-order filters than the integrated blocks support

**"Visualize Response" button** — filter and DRC blocks have a built-in button on their dialog that shows the response while the model runs and updates as parameters change. No extra blocks needed.

**Spectrum Analyzer from `audiosinks`** — use this instead of the DSP library version. For audio-friendly settings, configure: one-sided spectrum, log frequency scale.

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Building slider UIs with `uifigure`/`uislider` for tuning | Wastes 50+ lines, bugs with layout, no MIDI support | `parameterTuner(obj)` — one line, works with all objects |
| Manual biquad coefficient math for EQ | Error-prone, not tunable, no visualization | `multibandParametricEQ` or `designParamEQ` |
| `octaveFilterBank` + manual RMS + manual dB for SPL | Reimplements what `octaveSpectrumEstimator` does internally | `octaveSpectrumEstimator` with `visualize` |
| `resample()` or `dsp.SampleRateConverter` for audio SRC | Older APIs, no quality presets | `audioresample` / `designAudioResampler` (R2023b) |
| `butter` + `filter`/`sosfilt` for band splitting | No state management, not streaming-safe | `crossoverFilter` (maintains state, tunable) |
| Custom `figure` + `plot` for response visualization | Doesn't update with parameter changes | `visualize(obj)` — updates live |
| Setting fixed-step size to a numeric value in Simulink | Breaks when source sample rate or frame size changes | Use `'auto'` — Simulink derives it from audio blocks |
| Variable-step solver for discrete audio models | Wrong solver type for frame-based audio | `FixedStepDiscrete` with auto step size |
| Using DSP library Spectrum Analyzer in Simulink | Missing audio-friendly defaults | Use `audiosinks/Spectrum Analyzer` |
| `sosfilt` for real-time filtering | Cannot maintain state across frames | `dsp.SOSFilter` (maintains state) |
| Hand-rolling OLA buffers for spectral processing | Error-prone, no COLA guarantee, misses `dsp.STFT`/`dsp.ISTFT` | `dsp.STFT` + `dsp.ISTFT` for per-bin manipulation; `dsp.FrequencyDomainFIRFilter` only for fixed FIR |
| File-based loop without pacing for visualization | Frames fly past at CPU speed — meters/plots are unreadable | Add `pause(frameDuration)` or use `audioDeviceWriter` for real-time pacing |
| Per-sample `for` loop for constant-target gain smoothing | Slow, unnecessary when target is constant within a frame | Vectorize as geometric series: `targetGain + (currentGain - targetGain) * coeff.^(1:N)'` |
| Omitting `drawnow limitrate` in the loop | `parameterTuner` changes never take effect (UI events not flushed) | Add `drawnow limitrate` inside every loop that uses interactive UIs |
| Using `PlayCount=1` (default) with interactive tuning | File ends before user can tune parameters | Set `PlayCount=Inf` for interactive sessions |
| Arbitrary `SamplesPerFrame` with `designAudioResampler` | Output frames vary in length, breaking downstream fixed-frame processing | Set `SamplesPerFrame` to a multiple of `resampler.DecimationFactor` |

## Conventions

- Always set `SampleRate` explicitly on Audio Toolbox objects — never rely on the 44100 default
- Always include `drawnow limitrate` inside the processing loop when using `parameterTuner` or any interactive UI — without it, MATLAB never processes UI events and tuning changes do not take effect
- Set `PlayCount=Inf` on `dsp.AudioFileReader` when the user needs time to interact with tuning UIs or visualizations — the default `PlayCount=1` terminates too quickly for interactive use
- Use `timescope` and `spectrumAnalyzer` for real-time signal viewing (one-sided spectrum, log frequency axis for audio)
- Prefer `crossoverFilter` slopes of 24 or 48 dB/octave (Linkwitz-Riley alignment)
- Use `isDone(reader)` to control streaming loops, not manual frame counting
- Call `release(obj)` on all objects after the loop completes
- For Simulink: always use `FixedStepDiscrete` solver with `FixedStep='auto'`

----

Copyright 2026 The MathWorks, Inc.

----
