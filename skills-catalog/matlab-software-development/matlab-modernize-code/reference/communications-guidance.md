
# Communications Modernization

## Quick Reference: Function Mappings

| Deprecated System Object | Recommended Replacement | Since | Status |
|--------------------------|------------------------|-------|--------|
| comm.BPSKModulator | pskmod(data, 2) | R2024a | To be removed |
| comm.BPSKDemodulator | pskdemod(data, 2) | R2024a | To be removed |
| comm.QPSKModulator | pskmod(data, 4) | R2024a | To be removed |
| comm.QPSKDemodulator | pskdemod(data, 4) | R2024a | To be removed |
| comm.PSKModulator | pskmod | R2024a | To be removed |
| comm.PSKDemodulator | pskdemod | R2024a | To be removed |
| comm.RectangularQAMModulator | qammod | R2024a | To be removed |
| comm.RectangularQAMDemodulator | qamdemod | R2024a | To be removed |

## PSK Modulation Modernization

### comm.BPSKModulator → pskmod

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.BPSKModulator will be removed
bpskMod = comm.BPSKModulator;
modData = bpskMod(data);

% With phase offset
bpskMod = comm.BPSKModulator('PhaseOffset', pi/4);
modData = bpskMod(data);
```

**Modern Pattern (Use This):**
```matlab
% Direct function call - simpler and faster
modData = pskmod(data, 2);

% With phase offset
modData = pskmod(data, 2, pi/4);

% With Gray coding (default)
modData = pskmod(data, 2, pi/4, 'gray');
```

**Why Modern is Better:**
- Simpler one-line function calls
- No object creation overhead
- Clearer, more readable code
- Better performance for batch processing

**Migration Notes:**
- `pskmod(data, 2)` is equivalent to BPSK modulation
- Phase offset is the third argument
- Symbol ordering ('gray' or 'bin') is the fourth argument

---

### comm.QPSKModulator → pskmod

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.QPSKModulator will be removed
qpskMod = comm.QPSKModulator;
modData = qpskMod(data);

% With symbol mapping
qpskMod = comm.QPSKModulator('PhaseOffset', pi/4, 'SymbolMapping', 'Gray');
modData = qpskMod(data);
```

**Modern Pattern (Use This):**
```matlab
% QPSK is PSK with M=4
modData = pskmod(data, 4);

% With phase offset and Gray coding
modData = pskmod(data, 4, pi/4, 'gray');

% Input can be integers [0, M-1] or bits
modData = pskmod(bitData, 4, pi/4, 'gray', InputType='bit');
```

**Why Modern is Better:**
- Unified interface for all PSK orders
- Supports both integer and bit input
- Name-value arguments for clarity

---

### comm.PSKModulator → pskmod (General M-PSK)

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.PSKModulator will be removed
pskMod = comm.PSKModulator('ModulationOrder', 8, 'PhaseOffset', 0);
modData = pskMod(data);
```

**Modern Pattern (Use This):**
```matlab
% 8-PSK modulation
modData = pskmod(data, 8);

% With phase offset
modData = pskmod(data, 8, 0, 'gray');

% 16-PSK with custom phase offset
modData = pskmod(data, 16, pi/16, 'gray');
```

**Key Difference:** The modulation order M is directly specified as the second argument.

---

## PSK Demodulation Modernization

### comm.BPSKDemodulator → pskdemod

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.BPSKDemodulator will be removed
bpskDemod = comm.BPSKDemodulator;
demodData = bpskDemod(rxSignal);
```

**Modern Pattern (Use This):**
```matlab
% Direct demodulation
demodData = pskdemod(rxSignal, 2);

% With phase offset matching modulator
demodData = pskdemod(rxSignal, 2, pi/4);

% Output as bits
demodData = pskdemod(rxSignal, 2, pi/4, 'gray', OutputType='bit');
```

---

### comm.QPSKDemodulator → pskdemod

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.QPSKDemodulator will be removed
qpskDemod = comm.QPSKDemodulator;
demodData = qpskDemod(rxSignal);
```

**Modern Pattern (Use This):**
```matlab
% QPSK demodulation (M=4)
demodData = pskdemod(rxSignal, 4);

% With phase offset and Gray coding
demodData = pskdemod(rxSignal, 4, pi/4, 'gray');
```

---

### comm.PSKDemodulator → pskdemod (General M-PSK)

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.PSKDemodulator will be removed
pskDemod = comm.PSKDemodulator('ModulationOrder', 8);
demodData = pskDemod(rxSignal);
```

**Modern Pattern (Use This):**
```matlab
% 8-PSK demodulation
demodData = pskdemod(rxSignal, 8);

% With soft decision output (for LDPC/turbo decoding)
softBits = pskdemod(rxSignal, 8, 0, 'gray', ...
    OutputType='llr', ...
    NoiseVariance=noiseVar);
```

**Why Modern is Better:**
- Direct support for soft-decision output (LLR)
- Simpler integration with channel coding

---

## QAM Modulation Modernization

### comm.RectangularQAMModulator → qammod

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.RectangularQAMModulator will be removed
qamMod = comm.RectangularQAMModulator('ModulationOrder', 16);
modData = qamMod(data);

% With normalization
qamMod = comm.RectangularQAMModulator('ModulationOrder', 64, ...
    'NormalizationMethod', 'Average power');
modData = qamMod(data);
```

**Modern Pattern (Use This):**
```matlab
% 16-QAM modulation
modData = qammod(data, 16);

% 64-QAM with unit average power
modData = qammod(data, 64, UnitAveragePower=true);

% With Gray coding (default) and bit input
modData = qammod(bitData, 16, InputType='bit');
```

**Why Modern is Better:**
- Single function for all rectangular QAM orders
- Clear normalization control
- Supports both integer and bit input

---

### comm.RectangularQAMDemodulator → qamdemod

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% DEPRECATED: comm.RectangularQAMDemodulator will be removed
qamDemod = comm.RectangularQAMDemodulator('ModulationOrder', 16);
demodData = qamDemod(rxSignal);
```

**Modern Pattern (Use This):**
```matlab
% 16-QAM demodulation
demodData = qamdemod(rxSignal, 16);

% With unit average power normalization
demodData = qamdemod(rxSignal, 64, UnitAveragePower=true);

% Soft decision output for channel decoding
softBits = qamdemod(rxSignal, 16, ...
    OutputType='llr', ...
    UnitAveragePower=true, ...
    NoiseVariance=noiseVar);
```

---

## Complete Migration Examples

### Example 1: QPSK Communication System

**Old Pattern (Avoid):**
```matlab
% DEPRECATED System object approach
qpskMod = comm.QPSKModulator('PhaseOffset', pi/4);
qpskDemod = comm.QPSKDemodulator('PhaseOffset', pi/4);

% Modulate
txSignal = qpskMod(data);

% Add noise
rxSignal = awgn(txSignal, snr, 'measured');

% Demodulate
rxData = qpskDemod(rxSignal);
```

**Modern Pattern (Use This):**
```matlab
% Function-based approach - cleaner and faster
% Modulate
txSignal = pskmod(data, 4, pi/4, 'gray');

% Add noise
rxSignal = awgn(txSignal, snr, 'measured');

% Demodulate
rxData = pskdemod(rxSignal, 4, pi/4, 'gray');
```

---

### Example 2: 64-QAM with Soft Decoding

**Old Pattern (Avoid):**
```matlab
% DEPRECATED System object approach
qamMod = comm.RectangularQAMModulator('ModulationOrder', 64, ...
    'NormalizationMethod', 'Average power');
qamDemod = comm.RectangularQAMDemodulator('ModulationOrder', 64, ...
    'NormalizationMethod', 'Average power', ...
    'DecisionMethod', 'Approximate log-likelihood ratio', ...
    'Variance', noiseVar);

txSignal = qamMod(data);
rxSignal = awgn(txSignal, snr);
softBits = qamDemod(rxSignal);
```

**Modern Pattern (Use This):**
```matlab
% Function-based approach
txSignal = qammod(data, 64, UnitAveragePower=true);
rxSignal = awgn(txSignal, snr);
softBits = qamdemod(rxSignal, 64, ...
    UnitAveragePower=true, ...
    OutputType='llr', ...
    NoiseVariance=noiseVar);
```

---

## When to Use System Objects

While the modulation/demodulation System objects are deprecated, other Communications Toolbox System objects remain recommended for streaming/real-time scenarios:

**Still Recommended System Objects:**
```matlab
% Channel models (streaming)
chan = comm.AWGNChannel('NoiseMethod', 'Signal to noise ratio (SNR)');
chan = comm.RayleighChannel('SampleRate', fs);

% Synchronization
carrierSync = comm.CarrierSynchronizer;
symbolSync = comm.SymbolSynchronizer;

% Equalizers
lmsEq = comm.LinearEqualizer;

% Error rate calculation
errorRate = comm.ErrorRate;
```

**Use Functions For:**
- Batch processing of entire signals
- Simple modulation/demodulation operations
- Code clarity and maintainability

---

## Version Compatibility Notes

- **R2024a+:** PSK/QAM System objects deprecated, function-based API preferred
- **R2021a+:** Name-value argument syntax available for modulation functions
- **R2019b+:** `OutputType='llr'` for soft-decision demodulation

---

## Summary: Functions to Avoid

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `comm.BPSKModulator` | `pskmod(data, 2)` | To be removed |
| `comm.BPSKDemodulator` | `pskdemod(data, 2)` | To be removed |
| `comm.QPSKModulator` | `pskmod(data, 4)` | To be removed |
| `comm.QPSKDemodulator` | `pskdemod(data, 4)` | To be removed |
| `comm.PSKModulator` | `pskmod` | To be removed |
| `comm.PSKDemodulator` | `pskdemod` | To be removed |
| `comm.RectangularQAMModulator` | `qammod` | To be removed |
| `comm.RectangularQAMDemodulator` | `qamdemod` | To be removed |


----

Copyright 2026 The MathWorks, Inc.

----

