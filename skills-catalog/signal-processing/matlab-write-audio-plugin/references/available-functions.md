# Available Functions for Audio Plugins

Use these codegen-compatible objects/functions instead of reimplementing DSP from scratch. Construct objects in the constructor, configure in `reset`, call in `process` via `y = obj(x)`.

## Delays and Buffers

| Object | Purpose |
|--------|---------|
| `dsp.VariableFractionalDelay` | Fractional delay with interpolation — set `MaximumDelay` at construction |
| `dsp.VariableIntegerDelay` | Integer delay line (no interpolation) |
| `dsp.AsyncBuffer` | Asynchronous FIFO for variable-to-fixed frame conversion |
| `dsp.Delay` | Fixed integer delay |

## Filters

Key streaming filters (construct once, call per frame):

| Object | Purpose |
|--------|---------|
| `dsp.SOSFilter` | SOS IIR filter — tunable Nx3 `Numerator`/`Denominator` matrices |
| `dsp.FIRFilter` | FIR direct-form |
| `dsp.NotchPeakFilter` | Tunable notch/peak (frequency, bandwidth) |
| `dsp.VariableBandwidthFIRFilter` | FIR with tunable `CenterFrequency`, `Bandwidth`, `FilterType`, `SampleRate` |
| `dsp.VariableBandwidthIIRFilter` | IIR with tunable `CenterFrequency`, `Bandwidth`, `FilterType`, `SampleRate` |
| `dsp.DCBlocker` | DC offset removal |
| `dsp.AllpassFilter` | Phase manipulation (WDFAllpass or Lattice) |
| `octaveFilter` | Octave/fractional-octave band — tunable `CenterFrequency`, `Bandwidth`, `SampleRate` |
| `weightingFilter` | A/C/K-weighting — tunable `SampleRate` |
| `multibandParametricEQ` | Multi-band parametric EQ — tunable gains, frequencies, Q |
| `graphicEQ` | Graphic EQ — tunable `Gains` vector, `SampleRate` |
| `crossoverFilter` | Multi-band splitting — tunable `CrossoverFrequencies`, `CrossoverSlopes`, `SampleRate` |
| `shelvingFilter` | Shelving EQ — tunable `Gain`, `Slope`, `CutoffFrequency`. **`SampleRate` is non-tunable** — construct with max expected rate, or use `designShelvingEQ` + `filter()` |
| `gammatoneFilterBank` | Auditory filter bank — tunable `SampleRate` |
| `octaveFilterBank` | Multi-band octave filter bank — tunable `SampleRate` |
| `dsp.FilterCascade` | Cascade multiple filter objects into one |
| `dsp.LMSFilter` / `dsp.RLSFilter` | Adaptive filters (noise cancellation, system ID) |

Also available: `dsp.IIRFilter`, `dsp.AllpoleFilter`, `dsp.CoupledAllpassFilter`, `dsp.HighpassFilter`, `dsp.LowpassFilter`, `dsp.Differentiator`

Filter design (compute coefficients in set methods or `reset`):

- `designParamEQ` — NV syntax: `designParamEQ(Gain=G, QualityFactor=Q, CenterFrequency=Fc, Orientation="row")` where Fc is normalized (0–1). FilterOrder=2 returns 1×3 → use `filter(B, A, x, state)`. Higher orders → Nx3 → use `dsp.SOSFilter`
- `designShelvingEQ` — positional: `designShelvingEQ(gain, slope, Fc, type, Orientation="row")` → 1×3
- `designVarSlopeFilter` — positional: `designVarSlopeFilter(slope, Fc, type, Orientation="row")` → Nx3 → use `dsp.SOSFilter`
- `designVarSlopeFilter`, `designParamEQ`, `designShelvingEQ` — use `Orientation="row"` (default) R2024a+
- `butter`, `cheby1`, `ellip` — classic IIR design (use with `filter(b, a, x, state)`)

One-liner filter design + implementation (return filter objects, construct once): `designLowpassFIR`, `designHighpassFIR`, `designBandpassFIR`, `designBandstopFIR`, `designHalfbandFIR`, `designLowpassIIR`, `designHighpassIIR`, `designBandpassIIR`, `designBandstopIIR`, `designHalfbandIIR`, `designNotchPeakIIR`, `designFracDelayFIR`, `designMultirateFIR`

Low-level: `filter`, `sosfilt` (with state), `xcorr`, `levinson`, `lpc`

Codegen note for `lpc`: returns complex when the autocorrelation matrix is near-singular — always wrap with `real()`. Use a fixed order to keep the output size fixed: `a = real(lpc(frame, 12))` returns 1×13.

## Reverb and Spatial

| Object | Purpose |
|--------|---------|
| `reverberator` | Plate/room reverb — tunable PreDelay, WetDryMix, Diffusion, DecayFactor, HighCutFrequency, SampleRate |
| `dsp.FrequencyDomainFIRFilter` | Efficient long-FIR convolution (HRTF, room IRs) |
| `interpolateHRTF` | Interpolate HRTFs for dynamic source position |
| `ambisonicEncoderMatrix` / `ambisonicDecoderMatrix` | Ambisonics encoding/decoding matrices |

## Oscillators and Generators

| Object | Purpose |
|--------|---------|
| `audioOscillator` | Sine, square, sawtooth waveform generation |
| `dsp.NCO` | Numerically controlled oscillator (FM/PM synthesis) |
| `dsp.ColoredNoise` | White, pink, brown noise |
| `wavetableSynthesizer` | Wavetable oscillator — tunable `Frequency`, `Amplitude`, `SampleRate` |
| `shiftPitch` | Pitch shifting — function, call per frame |
| `stretchAudio` | Time stretching — codegen requires `Method='vocoder'`, `LockPhase=false` |

Also: `dsp.SineWave` (pure sine)

## Dynamics

`compressor`, `expander`, `limiter`, `noiseGate` — all tunable, all have tunable `SampleRate`

## Transforms

| Object | Purpose |
|--------|---------|
| `dsp.FFT` / `dsp.IFFT` | Streaming FFT/IFFT — fixed frame size, wrap with `dsp.AsyncBuffer` |
| `dsp.STFT` / `dsp.ISTFT` | Streaming STFT — fixed frame size, wrap with `dsp.AsyncBuffer` |
| `dsp.DCT` | Discrete Cosine Transform |
| `dsp.AnalyticSignal` | Hilbert transform — fixed frame size, wrap with `dsp.AsyncBuffer` |
| `goertzel` | Single-bin DFT (tuner/pitch detection at known frequency) |
| `mdct` / `imdct` | MDCT pair — call per frame with `PadInput=false` for streaming (`mdct(frame, win, 'PadInput', false)`), use with `kbdwin`. Output is `winLen/2` coefficients; overlap-add `imdct` outputs for reconstruction. |

Also: `dsp.ZoomFFT`, `dsp.SpectrumEstimator`, `dsp.PhaseExtractor`, `dsp.PhaseUnwrapper`

Standard window functions are codegen-compatible: `hann`, `hamming`, `blackman`, `kaiser`, `kbdwin`, etc.

## Interpolation and Rate Conversion

| Object | Purpose |
|--------|---------|
| `dsp.FIRDecimator` / `dsp.FIRInterpolator` | Integer-ratio decimation/interpolation |
| `dsp.FarrowRateConverter` | Arbitrary sample rate conversion |
| `dsp.SampleRateConverter` | Combined multi-stage rate conversion |

Also: `dsp.FIRRateConverter`, `dsp.FIRHalfbandDecimator`, `dsp.FIRHalfbandInterpolator`, `dsp.IIRHalfbandDecimator`, `dsp.IIRHalfbandInterpolator`, `dsp.Channelizer`, `dsp.ChannelSynthesizer`, `dsp.SubbandAnalysisFilter`, `dsp.SubbandSynthesisFilter`, `dsp.ComplexBandpassDecimator`

## Feature Extraction and Analysis

Streaming objects (set `SampleRate` in `reset`): `loudnessMeter`, `splMeter`, `voiceActivityDetector`, `detectspeechnn`, `acousticRoughness`, `octaveSpectrumEstimator`

Per-frame functions (pass sample rate as argument): `pitch`, `spectralCentroid`, `spectralCrest`, `spectralEntropy`, `spectralFlatness`, `spectralFlux`, `spectralKurtosis`, `spectralRolloffPoint`, `spectralSkewness`, `spectralSlope`, `spectralSpread`, `harmonicRatio`, `mfcc`, `gtcc`, `melSpectrogram`, `cepstralCoefficients`, `audioDelta`, `zerocrossrate`

## Deep Learning Inference

`coder.loadDeepLearningNetwork`, `predict`, `dlarray`/`extractdata`, `audioPluginConfig` — see `references/deep-learning.md` for the full pattern.

### Shipping Pretrained Networks

`audioPretrainedNetwork(name)` returns a `dlnetwork` ready for `coder.loadDeepLearningNetwork`. Available: `"yamnet"` (521-class sound classification), `"vggish"` (audio embeddings), `"openl3"` (embeddings), `"crepe"` (pitch), `"vadnet"` (voice activity). Save to `.mat` for codegen: `net = audioPretrainedNetwork("yamnet"); save('yamnet.mat','net')`.

Codegen-compatible preprocessing functions (handle resampling internally):
- `yamnetPreprocess(audio, fs)` — resamples to 16 kHz, computes [96x64x1xK] log-mel patches
- `vggishPreprocess(audio, fs)` — same pipeline, different log offset

These are marked `#codegen` and can be called directly inside `process` or inference helper functions.

## Utility

| Object | Purpose |
|--------|---------|
| `dsp.ParameterSmoother` | Exponential smoothing for click-free parameter transitions. Call once per frame with the scalar target value — returns one smoothed scalar. Passing a vector silently uses only the first element. Use `'Smoothing factor'` mode in plugins (`SampleTime` is non-tunable and SR-dependent). |
| `dsp.MovingRMS` | Running RMS level |
| `dsp.MedianFilter` | Running median filter |
| `dsp.Counter` | Sample/frame counter |
| `audioTimeScaler` | Phase-vocoder time stretching — tunable `SpeedFactor`, `SampleRate` |

Also: `dsp.MovingAverage`, `dsp.MovingStandardDeviation`, `dsp.MovingMaximum`, `dsp.MovingMinimum`, `dsp.PeakToRMS`, `dsp.ZeroCrossingDetector`, `dsp.HampelFilter`

## Usage Notes

- Do NOT call `release()` in generated code — the object may be unusable afterward
- Do NOT use `dsp.BiquadFilter` (deprecated) — use `dsp.SOSFilter` instead
- `coder.extrinsic` evaluates at compile time only — the result becomes a constant
- Objects with tunable `SampleRate` (set directly in `reset`): `reverberator`, `audioOscillator`, `wavetableSynthesizer`, `compressor`, `expander`, `limiter`, `noiseGate`, `octaveFilter`, `weightingFilter`, `multibandParametricEQ`, `graphicEQ`, `gammatoneFilterBank`, `octaveFilterBank`, `splMeter`, `audioTimeScaler`, `loudnessMeter`, `acousticRoughness`, `octaveSpectrumEstimator`

----

Copyright 2026 The MathWorks, Inc.
