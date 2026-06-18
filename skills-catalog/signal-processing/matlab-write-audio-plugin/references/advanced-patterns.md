# Advanced Patterns

## Real-Valued FFT Magnitude Processing

When modifying the magnitude spectrum of a real signal, process only the positive-frequency half (bins `1:N/2+1`), then mirror to reconstruct negative frequencies. This preserves conjugate symmetry so `ifft` returns a real result.

```matlab
X = fft(frame);
numBins = length(frame)/2 + 1;       % positive frequencies including DC and Nyquist
mag = abs(X(1:numBins));
phase = angle(X(1:numBins));

% --- modify mag here (masking, sharpening, etc.) ---

% Reconstruct full spectrum with conjugate symmetry
X(1:numBins) = mag .* exp(1j * phase);
X(numBins+1:end) = conj(X(numBins-1:-1:2));
frame = real(ifft(X));
```

Processing all N bins directly (including negative frequencies) breaks conjugate symmetry when magnitude modifications are applied, causing complex-valued `ifft` output or spectral artifacts.

**Codegen:** If you build the full-spectrum array before `ifft`, initialize it with `complex(zeros(N, 1))` — not `zeros(N, 1)`. Codegen locks real/complex from the first assignment; a real-initialized array rejects complex data on the right-hand side.

## Fixed-Size Processing with dsp.AsyncBuffer

Use when a sub-algorithm requires a fixed frame size (e.g., FFT, neural network). Audio hosts deliver variable sizes (2–8192).

```matlab
properties (Access = private)
    pInputBuffer
    pOutputBuffer
    pFixedSize = 256
end

methods
    function plugin = MyPlugin
        plugin.pInputBuffer = dsp.AsyncBuffer(65536);
        plugin.pOutputBuffer = dsp.AsyncBuffer(65536);
        setup(plugin.pInputBuffer, zeros(plugin.pFixedSize, 1));
        setup(plugin.pOutputBuffer, zeros(plugin.pFixedSize, 1));
    end

    function y = process(plugin, x)
        N = size(x, 1);
        write(plugin.pInputBuffer, x);
        y = zeros(N, 2);

        while plugin.pInputBuffer.NumUnreadSamples >= plugin.pFixedSize
            frame = read(plugin.pInputBuffer, plugin.pFixedSize);
            processed = myFixedSizeProcessing(plugin, frame);
            write(plugin.pOutputBuffer, processed);
        end

        if plugin.pOutputBuffer.NumUnreadSamples >= N
            y = read(plugin.pOutputBuffer, N);
        end
    end

    function reset(plugin)
        reset(plugin.pInputBuffer);
        reset(plugin.pOutputBuffer);
        setLatencyInSamples(plugin, plugin.pFixedSize);
    end
end
```

- **Must** call `setup` in the constructor — locks data type and column count so codegen can resolve sizes at compile time
- Buffer capacity (65536) must exceed max frame size (8192)
- In `reset`: call `reset()` only — never `setup()` or reconstruct

## Streaming STFT/ISTFT

`dsp.STFT` rejects input frames longer than its hop size (`FFTLength - OverlapLength`). Since hosts deliver frames up to 8193 samples, wrap with `dsp.AsyncBuffer`:

```matlab
properties (Access = private)
    pInputBuffer
    pOutputBuffer
    pSTFT
    pISTFT
end

methods
    function plugin = MySpectralPlugin
        win = sqrt(hann(512, 'periodic'));
        plugin.pSTFT = dsp.STFT('Window', win, 'OverlapLength', 384, ...
            'FFTLength', 512, 'FrequencyRange', 'onesided');
        plugin.pISTFT = dsp.ISTFT('Window', win, 'OverlapLength', 384, ...
            'FrequencyRange', 'onesided');
        plugin.pInputBuffer = dsp.AsyncBuffer(65536);
        plugin.pOutputBuffer = dsp.AsyncBuffer(65536);
        setup(plugin.pInputBuffer, zeros(128, 1));
        setup(plugin.pOutputBuffer, zeros(128, 1));
        setup(plugin.pSTFT, zeros(128, 1));
        setup(plugin.pISTFT, complex(zeros(257, 1)));
    end

    function y = process(plugin, x)
        N = size(x, 1);
        write(plugin.pInputBuffer, x);
        while plugin.pInputBuffer.NumUnreadSamples >= 128
            frame = read(plugin.pInputBuffer, 128);
            Xfull = plugin.pSTFT(frame);
            X = Xfull(:,1);              % codegen fix: force column vector
            % --- spectral processing on X here ---
            out_frame = plugin.pISTFT(X);
            write(plugin.pOutputBuffer, out_frame);
        end
        if plugin.pOutputBuffer.NumUnreadSamples >= N
            y = read(plugin.pOutputBuffer, N);
        else
            y = zeros(N, 1);
        end
    end
end
```

**Codegen constraint:** `dsp.STFT` output is variable-size on dimension 2 (`[N x :?]`) because codegen cannot prove the internal buffer is full. Always index `Xfull(:,1)` immediately after the call — this gives codegen a fixed `[N x 1]` column.

Use `'onesided'` for real signals (returns `N/2+1` bins instead of `N`). The `FrequencyRange` must match between STFT and ISTFT.

## Streaming Sub-Objects

Construct with literals, set `SampleRate` in `reset`, call as `obj(x)`:

```matlab
function plugin = MyEQ
    plugin.pFilter = octaveFilter('FilterOrder', 2, ...
        'CenterFrequency', 1000, 'Bandwidth', '1 octave', 'SampleRate', 44100);
end

function y = process(plugin, x)
    y = plugin.pFilter(x);
end

function reset(plugin)
    plugin.pFilter.SampleRate = getSampleRate(plugin);
    reset(plugin.pFilter);
end

function set.CenterFreq(plugin, val)
    plugin.CenterFreq = val;
    plugin.pFilter.CenterFrequency = val; %#ok<MCSUP>
end
```

## Modulated Delay Lines

Use `dsp.VariableFractionalDelay` for interpolated delay. Set `MaximumDelay` at construction.

For custom delay lines: clamp index to `[1, bufLen-1]`. Ensure `baseDelay + depth*sin(phase)` stays positive — constrain parameter Mapping ranges so `maxDepth <= minBaseDelay`.

## Loading External Data

Use `coder.load('data.mat')` in the constructor — data is baked into the binary at compile time. The `.mat` file must be on the MATLAB path at codegen time.

## Save/Load for MATLAB Workspace Persistence

These methods enable `save()`/`load()` of plugin objects in the MATLAB workspace and Audio Test Bench session recall. They are **not compiled into generated VSTs or standalones** — DAW hosts persist parameters through the VST/AU parameter interface and call `reset` on session restore.

Add save/load only when the plugin has private state that cannot be reconstructed from public parameters and sample rate alone (e.g., handle sub-objects like `dsp.VariableFractionalDelay` with internal buffers, loaded data, accumulated statistics). If all internal state is recomputed in `reset`, save/load is unnecessary.

For pure `audioPlugin` classes (System Object hybrids use `saveObjectImpl`/`loadObjectImpl`):

```matlab
methods
    function s = saveobj(obj)
        s = saveobj@audioPlugin(obj);
        s.Gain = obj.Gain;
        s.pCoeffs = obj.pCoeffs;
        s.pDelay = matlab.System.saveObject(obj.pDelay);  % handle sub-objects
    end
end
methods (Static)
    function obj = loadobj(s)
        if isstruct(s)
            obj = MyPlugin;
            obj.Gain = s.Gain;
            obj.pCoeffs = s.pCoeffs;
            obj.pDelay = matlab.System.loadObject(s.pDelay);
        end
    end
end
```

----

Copyright 2026 The MathWorks, Inc.
