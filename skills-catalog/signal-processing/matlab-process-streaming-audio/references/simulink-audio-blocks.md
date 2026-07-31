# Audio Toolbox Simulink Blocks

## Block Libraries

### audiosources — Audio input and control signals

| Block | Purpose |
|-------|---------|
| From Multimedia File | Read audio from WAV, MP3, FLAC, etc. |
| Audio Device Reader | Capture from microphone/audio interface |
| Audio Oscillator | Generate sine, square, sawtooth waves |
| Colored Noise | Generate white, pink, brown noise |
| MIDI Controls | Read MIDI control values as signals |
| Wavetable Synthesizer | Generate arbitrary periodic waveforms |

### audiosinks — Audio output and visualization

| Block | Purpose |
|-------|---------|
| Audio Device Writer | Play audio through speakers/audio interface |
| Spectrum Analyzer | Real-time spectrum display (use for audio — one-sided, log freq) |
| To Multimedia File | Write audio to file |

### audiofilters — Filter and EQ blocks

| Block | Purpose | Has "Visualize Response" |
|-------|---------|------------------------|
| Crossover Filter | Split into N+1 frequency bands | Yes |
| Multiband Parametric EQ | N-band parametric equalizer | Yes |
| Single-Band Parametric EQ | One peaking/notch filter | Yes |
| Graphic EQ | Octave or 1/3-octave graphic EQ | Yes |
| Octave Filter | Single octave-band filter | Yes |
| Octave Filter Bank | Multi-band octave analysis | No |
| Shelving Filter | Low/high shelf filter | Yes |
| Weighting Filter | A/C/Z frequency weighting | Yes |
| Gammatone Filter Bank | Auditory filter bank | No |
| **Parametric EQ Design** | Outputs SOS/FOS coefficients | No |
| **Shelving EQ Design** | Outputs shelf coefficients | No |
| **Variable Slope Filter Design** | Outputs LP/HP coefficients | No |

### audiodynamicrange — Dynamic range control

| Block | Purpose | Has "Visualize Response" |
|-------|---------|------------------------|
| Compressor | Dynamic range compression | Yes (static characteristic) |
| Expander | Dynamic range expansion | Yes |
| Limiter | Peak limiting | Yes |
| Noise Gate | Gate below threshold | Yes |

### audioeffects — Effects processing

| Block | Purpose |
|-------|---------|
| Reverberator | Plate/room reverb |

## Design Blocks

Design blocks separate filter design from implementation. They output filter coefficients that feed a `dsp.SOSFilter` or `dsp.FOS Filter` block.

**When to use design blocks:**
- Code generation workflows (design block → coefficient output → efficient fixed-point filter)
- Need bandwidth specified by octave width or band-edge frequencies (not just center freq + Q)
- Need higher-order filters than integrated blocks support
- Want to share one set of coefficients across multiple filter instances

**Parametric EQ Design** — outputs SOS coefficients for peaking filters
- Specify by: center frequency + bandwidth, center frequency + quality factor, center frequency + octave bandwidth, or band-edge frequencies
- Supports arbitrary filter order

**Shelving EQ Design** — outputs SOS coefficients for shelf filters
- Low shelf or high shelf
- Specify cutoff frequency, gain, slope

**Variable Slope Filter Design** — outputs SOS coefficients for LP/HP filters
- Variable slope from 6 to 48 dB/octave
- Butterworth alignment

## Model Configuration

```matlab
% Required solver settings for audio models
set_param(model, 'Solver', 'FixedStepDiscrete');
set_param(model, 'FixedStep', 'auto');
set_param(model, 'StopTime', 'inf');  % For continuous streaming
```

**Why auto fixed-step:** Audio blocks declare their sample time based on the source sample rate and frame size. Setting `FixedStep='auto'` lets Simulink derive the correct step size. A hardcoded value breaks when you change the source.

**Why FixedStepDiscrete:** Audio processing is inherently discrete and frame-based. Variable-step solvers are for continuous-time systems and add unnecessary overhead.

## "Visualize Response" Button

Filter and DRC blocks have a **Visualize Response** button on their block dialog (mask). Clicking it opens a figure showing the current response — it updates live as parameters change during simulation.

- No extra blocks or code needed
- Works while the model is running
- Shows magnitude response (filters) or static characteristic (DRC)

## MIDI Controls Block

The MIDI Controls block in `audiosources` reads MIDI control change messages and outputs them as Simulink signals. Use it to drive block parameters from hardware controllers.

Connect MIDI Controls output ports to tunable input ports on filter/DRC blocks for real-time hardware control during simulation.

## Spectrum Analyzer Configuration for Audio

When using `audiosinks/Spectrum Analyzer`, configure for audio applications:

- **FrequencySpan:** Full (auto-adapts to signal Nyquist)
- **PlotType:** One-sided (audio signals are real-valued)
- **FrequencyScale:** Log (matches human perception)

----

Copyright 2026 The MathWorks, Inc.

----
