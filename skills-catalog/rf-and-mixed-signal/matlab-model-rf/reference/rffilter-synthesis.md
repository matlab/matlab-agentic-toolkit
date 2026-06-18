# rffilter -- Synthesized LC Filter Design

Reference material for the `rffilter` element's design options and parameter conventions.

## Basic Construction

```matlab
bpf = rffilter('ResponseType', 'Bandpass', 'FilterType', 'Butterworth', ...
    'FilterOrder', 5, 'PassbandFrequency', [2.3e9 2.5e9], 'Name', 'BPF');

lpf = rffilter('ResponseType', 'Lowpass', 'FilterType', 'Chebyshev', ...
    'FilterOrder', 7, 'PassbandFrequency', 1e9, 'Name', 'LPF');
```

## Response and Filter Types

| ResponseType | PassbandFrequency |
|-------------|-------------------|
| `'Lowpass'` | Scalar (cutoff) |
| `'Highpass'` | Scalar (cutoff) |
| `'Bandpass'` | 2-element vector [fLow fHigh] |
| `'Bandstop'` | 2-element vector [fLow fHigh] |

| FilterType | Description |
|-----------|-------------|
| `'Butterworth'` | Maximally flat passband |
| `'Chebyshev'` | Equiripple passband, sharper rolloff |
| `'InverseChebyshev'` | Equiripple stopband |

**Gotcha:** `FilterType` means the design algorithm (Butterworth/Chebyshev/InverseChebyshev). `ResponseType` means the frequency shape (Lowpass/Highpass/Bandpass/Bandstop). Using `rffilter('FilterType', 'Bandpass')` errors -- use `rffilter('ResponseType', 'Bandpass')` instead.

## Implementation

Controls the circuit topology used for LC synthesis:

```matlab
filt1 = rffilter('ResponseType','Lowpass','FilterOrder',5,'PassbandFrequency',1e9,'Implementation','LC Tee');
filt2 = rffilter('ResponseType','Lowpass','FilterOrder',5,'PassbandFrequency',1e9,'Implementation','LC Pi');
filt3 = rffilter('ResponseType','Lowpass','FilterOrder',5,'PassbandFrequency',1e9,'Implementation','Transfer Function');
```

## Extract S-Parameters

```matlab
freq = linspace(1e9, 4e9, 500);
s = sparameters(bpf, freq);
rfplot(s, 2, 1);     % Plot insertion loss
```

## Access Design Data

Retrieve the synthesized L and C values:

```matlab
dd = bpf.DesignData;
fprintf('Inductors: %s\n', mat2str(dd.Inductors, 3));
fprintf('Capacitors: %s\n', mat2str(dd.Capacitors, 3));
```

## Key Properties

| Property | Description |
|----------|-------------|
| `ResponseType` | Frequency response shape |
| `FilterType` | Design algorithm |
| `FilterOrder` | Filter order |
| `PassbandFrequency` | Passband edge(s) in Hz |
| `StopbandFrequency` | Stopband edge(s) in Hz (alternative to order) |
| `StopbandAttenuation` | Minimum stopband rejection (dB) |
| `Implementation` | `'LC Tee'`, `'LC Pi'`, or `'Transfer Function'` |
| `Zin`, `Zout` | Source/load impedance for synthesis |

## Gotchas

- **rffilter is ideal** -- Synthesized filters assume ideal components with no parasitic effects. For realistic filters, use measured S-parameter data via `nport`.
- **FilterType vs ResponseType confusion** -- FilterType is the algorithm, ResponseType is the shape.

----

Copyright 2026 The MathWorks, Inc.

----
