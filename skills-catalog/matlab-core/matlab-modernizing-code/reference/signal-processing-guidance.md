
# Signal Processing Modernization

## Quick Reference: Function Mappings

| Deprecated Function | Recommended Replacement | Since | Status |
|---------------------|------------------------|-------|--------|
| pkurtosis | spectralKurtosis | R2024b | Not recommended |
| poctave | poctave (new syntax) | R2021a | Syntax change |
| sgolay | sgolay (arguments block) | R2021a | Syntax modernization |

## Spectral Analysis Modernization

### pkurtosis → spectralKurtosis

**Status:** Not recommended as of R2024b. Will be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: pkurtosis will be removed
[K, F] = pkurtosis(x, fs);
[K, F] = pkurtosis(x, fs, 'FrequencyLimits', [20 2000]);

% Spectrogram-based analysis (deprecated)
[S, F, T] = spectrogram(x, window, noverlap, nfft, fs);
K = pkurtosis(S);
```

**Modern Pattern (Use This):**
```matlab
% Time-domain signal input
[K, F] = spectralKurtosis(x, fs);
[K, F] = spectralKurtosis(x, fs, FrequencyLimits=[20 2000]);

% Spectrogram input
[S, F, T] = spectrogram(x, window, noverlap, nfft, fs);
K = spectralKurtosis(S);
```

**Why Modern is Better:**
- `spectralKurtosis` uses modern name-value argument syntax
- Better integration with Audio Toolbox workflows
- Consistent naming convention with other spectral functions
- Enhanced performance and reliability

**Migration Notes:**
- Direct replacement for most use cases
- Parameter names remain the same
- Output format is identical

**Key Difference:** Function naming follows modern spectral analysis conventions (camelCase with "spectral" prefix).

---

### poctave → poctave (with modern syntax)

**Status:** Legacy syntax deprecated. Use modern name-value pairs.

**Old Pattern (Avoid):**
```matlab
% Legacy positional argument syntax
[p, cf] = poctave(x, fs, 'BandsPerOctave', 3, 'FrequencyLimits', [20 20000]);
```

**Modern Pattern (Use This):**
```matlab
% Modern name-value syntax (R2021a+)
[p, cf] = poctave(x, fs, BandsPerOctave=3, FrequencyLimits=[20 20000]);
```

**Why Modern is Better:**
- Clearer, more readable syntax
- Consistent with modern MATLAB conventions
- Better IDE support and code completion

---

## Filter Design Modernization

### Filter Design with Recommended Patterns

**Status:** Various legacy filter design patterns should be updated.

**Old Pattern (Less Preferred):**
```matlab
% Using filter object (older approach)
Hd = dfilt.df2sos(sos, g);
y = filter(Hd, x);
```

**Modern Pattern (Use This):**
```matlab
% Direct filtering with sos
y = sosfilt(sos, x);

% Or use designfilt for complete workflow
d = designfilt('lowpassiir', ...
    'FilterOrder', 8, ...
    'HalfPowerFrequency', 0.2, ...
    'DesignMethod', 'butter');
y = filtfilt(d, x);
```

**Why Modern is Better:**
- `sosfilt` is more memory efficient
- `designfilt` provides a unified design interface
- Better numerical stability with SOS form

---

## Spectral Estimation Best Practices

### Use Modern Spectral Functions

**Recommended Spectral Analysis Functions:**

```matlab
% Power spectral density
[pxx, f] = pwelch(x, window, noverlap, nfft, fs);
[pxx, f] = pspectrum(x, fs);

% Spectrogram analysis
[s, f, t] = spectrogram(x, window, noverlap, nfft, fs);
[p, f, t] = pspectrum(x, fs, 'spectrogram');

% Spectral features (modern approach)
K = spectralKurtosis(x, fs);       % Use this, NOT pkurtosis
S = spectralSkewness(x, fs);
C = spectralCentroid(x, fs);
F = spectralFlatness(x, fs);
R = spectralRolloffPoint(x, fs);
```

---

## Windowing and Preprocessing

### Modern Window Functions

**All standard windows are available:**

```matlab
% Modern approach - specify window type by name
win = hann(256);           % Hann window
win = hamming(256);        % Hamming window
win = blackmanharris(256); % Blackman-Harris window
win = kaiser(256, 5);      % Kaiser window with beta=5

% Or use window function for flexibility
win = window(@hamming, 256);
```

---

## Signal Generation

### Modern Signal Generation Patterns

**Recommendation:** Use signal generation functions with modern syntax.

```matlab
% Chirp signal generation
t = 0:1/fs:1;
y = chirp(t, f0, 1, f1, 'Method', 'linear');

% Modern approach with name-value arguments (R2021a+)
y = chirp(t, f0, 1, f1, Method="linear");

% Noise generation
noise = randn(size(signal));  % White Gaussian noise
pinkNoise = dsp.ColoredNoise('Color', 'pink', 'SamplesPerFrame', length(signal));
```

---

## Real-Time Processing Patterns

### System Objects for Streaming

**Modern Pattern for Real-Time Signal Processing:**

```matlab
% Create System objects for streaming
lowpassFilter = dsp.LowpassFilter('SampleRate', fs, 'PassbandFrequency', 1000);
specAnalyzer = spectrumAnalyzer('SampleRate', fs);

% Process in a loop
while ~isDone(audioIn)
    frame = audioIn();
    filtered = lowpassFilter(frame);
    specAnalyzer(filtered);
end

% Release resources
release(lowpassFilter);
release(specAnalyzer);
```

**Why This Matters:**
- System objects maintain state between calls
- Optimized for streaming/real-time processing
- Consistent interface across DSP System Toolbox

---

## Version Compatibility Notes

- **R2024b:** `pkurtosis` deprecated → use `spectralKurtosis`
- **R2021a+:** Name-value argument syntax preferred throughout toolbox
- **R2019b+:** `designfilt` enhanced with additional filter types

---

## Summary: Functions to Avoid

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `pkurtosis` | `spectralKurtosis` | Deprecated R2024b |
| Legacy positional args | Name-value syntax | Modern convention |
| `dfilt` objects for simple filtering | `sosfilt`, `filtfilt` | Simpler, more efficient |

