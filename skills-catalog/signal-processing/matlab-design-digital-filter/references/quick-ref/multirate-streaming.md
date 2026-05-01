# Multirate STREAMING Card (polyphase, causal)

Use this card when the user wants:
- **streaming / real-time / frame-based** filtering, and
- output stays at the **original sample rate**, but
- internal rate change is acceptable.

## 80/20 rules

- Streaming is **causal** → no `filtfilt()`. (Zero-phase requires the entire signal.)
- Use **System objects** (`SystemObject=true`) so state is handled correctly across frames.
- Frame length should be a multiple of the decimation factor `M`.

**Note**: If you need zero-phase, switch to offline mode with `resample()` (see INDEX.md → multirate-offline quick-ref).

## Canonical streaming pipeline (dec → sharp filter → interp)

```matlab
Fs = 44100;
M  = 4;
Fs_dec = Fs/M;

% Stage 1: decimator (polyphase)
dec = designMultirateFIR(DecimationFactor=M, ...
    StopbandAttenuation=60, ...
    SystemObject=true);

% Stage 2: sharp filter at low rate (System object for streaming)
sharp = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs_dec, DesignMethod="equiripple", ...
    SystemObject=true);

% Stage 3: interpolator (polyphase)
interp = designMultirateFIR(InterpolationFactor=M, ...
    StopbandAttenuation=60, ...
    SystemObject=true);

% Frame loop (example)
frameLen = 1024;              % choose so mod(frameLen,M)==0
y = zeros(size(x));
reset(dec); reset(sharp); reset(interp);

for k = 1:frameLen:(numel(x)-frameLen+1)
    frame = x(k:k+frameLen-1);

    frame_dec  = dec(frame);
    frame_filt = sharp(frame_dec);
    frame_out  = interp(frame_filt);

    y(k:k+frameLen-1) = frame_out;
end
```

## Efficiency note (common trap)

For narrow transitions, don’t try to “bake the sharp spec” into a multistage decimator/interpolator.  
Instead:
- decimate/interpolate with relaxed anti-alias / anti-image, and
- do the sharp filtering at the reduced rate.

See `../multirate.md` for the full decision guide.

## Filter Analyzer comparison (pipeline as one object)

Wrap the pipeline in `dsp.FilterCascade` (then open the Filter Analyzer card):

```matlab
pipe = dsp.FilterCascade(dec, sharp, interp);
filterAnalyzer(pipe, FilterNames="Multirate_Pipeline", SampleRates=Fs);
```

## Gotchas

### Interpolator gain (unity-gain normalization)

`designMultirateFIR` interpolators have built-in gain of **M** to compensate for zero-stuffing energy loss. In a dec→filter→interp pipeline, this causes +12 dB passband gain for M=4.

**Fix**: Normalize the interpolator coefficients:

```matlab
interp_sys = designMultirateFIR(InterpolationFactor=M, ...
    StopbandAttenuation=60, SystemObject=true);
interp_sys.Numerator = interp_sys.Numerator / M;  % Unity gain
```

### API confusion: designMultirateFIR vs dsp.FIRDecimator

`designMultirateFIR` is the recommended modern API. Don't confuse it with raw System object constructors:

```matlab
% Anti-pattern
% WRONG — invalid syntax (dsp.FIRDecimator doesn't take 'SystemObject')
decim = dsp.FIRDecimator(M, 'SystemObject', true);

% RIGHT — use designMultirateFIR
decim = designMultirateFIR(DecimationFactor=M, StopbandAttenuation=60, SystemObject=true);
```

`dsp.FIRDecimator(M)` creates a default decimator; `designMultirateFIR` gives you spec control.

### Querying filter order from System objects

`filtord()` works on `digitalFilter` objects but NOT on System objects:

```matlab
% Anti-pattern
% WRONG — filtord doesn't work on dsp.FIRDecimator
N = filtord(decim);  % ERROR

% RIGHT — use Numerator property
N = numel(decim.Numerator) - 1;
```


----

Copyright 2026 The MathWorks, Inc.

----
