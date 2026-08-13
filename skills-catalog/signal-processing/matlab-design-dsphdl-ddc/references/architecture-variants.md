# DDC Architecture Variants

## Three-Stage Decimation (CIC + FIR + FIR)

For high decimation ratios (64+) where two FIR stages give better control:

```matlab
compCoeffs = coeffs(dsp.CICCompensationDecimator(2, 'CICRateChangeFactor', 16, 'CICNumSections', 5)).Numerator;
chanCoeffs = designMultirateFIR(1, 2);

cicDec = dsphdl.CICDecimator('DecimationFactor', 16, 'NumSections', 5, ...
    'OutputDataType', 'Same word length as input');

firDec1 = dsphdl.FIRDecimator('DecimationFactor', 2, 'Numerator', compCoeffs, 'NumCycles', 16, ...
    'OutputDataType', 'Same word length as input');

firDec2 = dsphdl.FIRDecimator('DecimationFactor', 2, 'Numerator', chanCoeffs, 'NumCycles', 32, ...
    'OutputDataType', 'Same word length as input');
% Total: 16 * 2 * 2 = 64x decimation
```

## Choosing Between Farrow and FIR Rate Converter

| Criterion | `dsphdl.FarrowRateConverter` | `dsphdl.FIRRateConverter` |
|---|---|---|
| **Best for** | Fine rate adjustment (rate close to 1) | Moderate L/M ratios with wide transition band |
| **Hardware cost** | ~4 multipliers (3rd-order) | L polyphase branches, each with ceil(N/L) taps |
| **Filter design** | No filter design needed (Lagrange coefficients) | Requires prototype lowpass filter design |
| **Rate flexibility** | Arbitrary (even irrational) rate changes | Rational L/M only |
| **Runtime tuning** | `RateChangeSource = 'Input port'` | Not tunable — L and M are compile-time |
| **Quality** | Excellent when rate ~1; degrades for large rate changes | Excellent for any L/M if filter is well-designed |
| **Impractical when** | Rate far from 1 (e.g., 1/8) — use CIC/FIR instead | L and M both large and close (e.g., 40/41) — transition band too narrow |
| **Typical DDC use** | Final stage fine adjustment after integer CIC+FIR | Moderate rate change in 1-2 stage designs |

## Real Input with Quadrature Mixing

When the input is real-valued (not already complex):

```matlab
% NCO outputs both sine and cosine for I/Q generation
nco = dsphdl.NCO( ...
    'PhaseIncrementSource', 'Property', ...
    'PhaseIncrement', round((-25e6 * 2^32) / 100e6), ...
    'Waveform', 'Sine and cosine', ...
    'AccumulatorWL', 32, ...
    'OutputWL', 16, 'OutputFL', 14);

% In the processing loop:
[sinOut, cosOut, ncoValid] = nco(validIn);
I_mixed = fi((dataIn) * (cosOut), 1, 16, 14);
Q_mixed = fi((dataIn) * (-sinOut), 1, 16, 14);
% Then feed I and Q through separate (or complex) decimation chains
```

## Design Guidelines

### CIC Parameter Tradeoffs

| Parameter | Tradeoff |
|---|---|
| `DecimationFactor` | Higher = more decimation in one stage, but more bit growth and passband droop |
| `NumSections` | More sections = sharper alias rejection, but more bit growth |
| `DifferentialDelay` | 1 (standard) vs 2 (sharper nulls at multiples of Fs/R) |

### CIC Bit Growth

Output word length at full precision = InputWL + N * ceil(log2(R * M))

Where N = NumSections, R = DecimationFactor, M = DifferentialDelay.

Example: 16-bit input, R=8, N=4, M=1 → 16 + 4*3 = 28 bits

### NCO Spurious Performance

- SFDR improves ~6 dB per output bit
- Phase dithering reduces near-carrier spurs
- `LUTCompress` reduces LUT by ~4x with minimal SFDR loss

----

Copyright 2026 The MathWorks, Inc.
