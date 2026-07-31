# Function: `labelSpectrogramOptions`

> Used in: wf-label-and-export.md, fn-signallabeldefinition.md
> Toolbox: Signal Processing Toolbox
> Since: R2025a

Store spectrogram options for time-frequency ROI label definitions. Controls
how the TF map is computed when labeling in the time-frequency domain (both
programmatically and in Signal Labeler).

## Signatures

```matlab
opts = labelSpectrogramOptions                              % defaults (leakage)
opts = labelSpectrogramOptions(resType)                     % "leakage" | "rbw" | "windowlength"
opts = labelSpectrogramOptions(resType, Name=Value)         % with NV-pairs
```

## Resolution types

| `resType` | Controls via | Typical use |
|---|---|---|
| `"leakage"` (default) | `Leakage`, `TimeResolutionMode`, `TimeResolution` | Quick pspectrum-style setup |
| `"rbw"` | `RBWMode`, `RBW` | Explicit resolution bandwidth |
| `"windowlength"` | `Window`, `WindowLengthMode`, `WindowLength`, `NFFTMode`, `NFFT` | Full STFT control |

## Properties (all resolution types)

| Property | Default | Notes |
|---|---|---|
| `ResolutionType` | `"leakage"` | Read-only after construction |
| `Overlap` | `50` | Percentage [0, 100) |
| `MinimumThresholdMode` | `"auto"` | `"auto"` \| `"specify"` |
| `MinimumThreshold` | `[]` | Positive scalar when mode is `"specify"` |
| `UseDecibels` | `true` | Express spectrogram in dB |

## Properties (leakage-specific)

| Property | Default | Notes |
|---|---|---|
| `Leakage` | `20` | Scalar in [0, 40]. Maps to Kaiser beta. |
| `TimeResolutionMode` | `"auto"` | `"auto"` \| `"specify"` |
| `TimeResolution` | `[]` | Positive scalar (seconds) when mode is `"specify"` |
| `Reassign` | `false` | Reassign spectrogram values for sharper localization |

## Properties (rbw-specific)

| Property | Default | Notes |
|---|---|---|
| `RBWMode` | `"auto"` | `"auto"` \| `"specify"` |
| `RBW` | `[]` | Resolution bandwidth (Hz) when mode is `"specify"` |

## Properties (windowlength-specific)

| Property | Default | Notes |
|---|---|---|
| `Window` | `"hamming"` | `"hamming"` \| `"hann"` \| `"blackmanharris"` \| `"flattop"` \| `"rectangular"` \| `"chebyshev"` \| `"kaiser"` |
| `WindowAttenuationChebyshev` | `[]` | >= 21 dB |
| `WindowAttenuationKaiser` | `[]` | >= 45 dB |
| `WindowLengthMode` | `"auto"` | `"auto"` \| `"specify"` |
| `WindowLength` | `[]` | Positive integer (samples) |
| `NFFTMode` | `"auto"` | `"auto"` \| `"specify"` |
| `NFFT` | `[]` | Positive integer |

## Object functions

| Function | Returns |
|---|---|
| `getTFMap(opts, signal, Fs)` | STFT matrix for TF labeling |
| `getTFMapSize(opts, signalLength, Fs)` | `[numFreqBins numTimeSteps]` — size without computing |

## Canonical pattern

```matlab
opts = labelSpectrogramOptions("leakage", ...
    Leakage=32, Overlap=90, ...
    TimeResolutionMode="specify", TimeResolution=0.05);

lblDef = signalLabelDefinition("Signal", ...
    LabelType="roiTimeFrequency", ...
    LabelDataType="categorical", ...
    Categories=["WLAN" "BT" "LTE"], ...
    TimeFrequencyOptions=opts);
```

## Matching pspectrum settings

`pspectrum` uses `Leakage` as a fraction [0, 1]; `labelSpectrogramOptions`
uses it as a value in [0, 40]. The conversion:

```matlab
pspectrumLeakage = 0.5;                    % fraction
optsLeakage = 40 * (1 - pspectrumLeakage); % = 20
```

The `[0, 40]` value is literally the **Kaiser window beta** (for the default
Kaiser path): `labelSpectrogramOptions` internally calls `pspectrum` with
`Leakage = 1 - optsLeakage/40`, and `pspectrum` maps that to `beta = 40*(1 -
leakage)`, so `optsLeakage == beta`. This equivalence is specific to the
default Kaiser window; it does not apply if you set `Window` to
`"blackmanharris"` / `"chebyshev"` / `"flattop"` etc., which use their own
attenuation properties.

## Gotchas

- **`Leakage` range differs from `pspectrum`.** `pspectrum` takes [0, 1]
  (fraction); `labelSpectrogramOptions` takes [0, 40] (Kaiser sidelobe
  attenuation scale). Use `40*(1 - pspectrumLeakage)` to convert.
- **`Overlap` is percentage, not sample count.** Unlike `spectrogram()`
  which takes `noverlap` in samples.
- **Options must match Signal Labeler view settings.** If you set
  spectrogram options programmatically and then open in Signal Labeler,
  the app uses those exact options. Mismatched settings mean labels
  appear at wrong TF locations.
- **`getTFMapSize` is useful for pre-allocating.** Call before
  `createDatastores` with `TimeFrequencyImageSize` to know the native
  TF grid size.

## See also

- `fn-signallabeldefinition.md` — uses `TimeFrequencyOptions` property.
- `wf-label-and-export.md` — end-to-end workflow.

----

Copyright 2026 The MathWorks, Inc.

----
