# designfilt Reference Card

Open this card **before** writing any `designfilt(...)` call.

## Response Type Quick Reference

| Filter type | Response string | Key parameters |
|-------------|-----------------|----------------|
| Lowpass FIR | `"lowpassfir"` | `PassbandFrequency`, `StopbandFrequency` |
| Lowpass IIR | `"lowpassiir"` | `PassbandFrequency`, `StopbandFrequency` |
| Highpass FIR | `"highpassfir"` | `StopbandFrequency`, `PassbandFrequency` |
| Highpass IIR | `"highpassiir"` | `StopbandFrequency`, `PassbandFrequency` |
| Bandpass FIR | `"bandpassfir"` | `PassbandFrequency=[f1 f2]` (vector OK) |
| Bandpass IIR | `"bandpassiir"` | `PassbandFrequency1`, `PassbandFrequency2` (scalar!) |
| Bandstop FIR | `"bandstopfir"` | `StopbandFrequency=[f1 f2]` (vector OK) |
| Bandstop IIR | `"bandstopiir"` | `StopbandFrequency1`, `StopbandFrequency2` (scalar!) |
| **Notch (single tone)** | `"notchiir"` | `CenterFrequency`, `QualityFactor` |
| Peak (boost) | `"peakiir"` | `CenterFrequency`, `QualityFactor`, `PassbandRipple` |

## Core Patterns

### FIR (linear phase by default)

```matlab
d = designfilt("lowpassfir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="equiripple");
```

### IIR (minimum order)

```matlab
d = designfilt("lowpassiir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    PassbandRipple=Rp, StopbandAttenuation=Rs, ...
    SampleRate=Fs, DesignMethod="ellip");
```

### Notch (single tone removal)

```matlab
d = designfilt("notchiir", ...
    FilterOrder=2, CenterFrequency=f0, QualityFactor=Q, ...
    SampleRate=Fs);
```

**`FilterOrder` is required** for notchiir — omitting it causes a runtime error. Order 2 (single biquad) is standard; use higher even orders for deeper notches.

**Q guidelines**: 10-50 typical. Higher Q = sharper notch but more ringing.

### Bandpass IIR (scalar edges required!)

```matlab
d = designfilt("bandpassiir", ...
    StopbandFrequency1=fs1, PassbandFrequency1=f1, ...
    PassbandFrequency2=f2,  StopbandFrequency2=fs2, ...
    PassbandRipple=Rp, ...
    StopbandAttenuation1=Rs, StopbandAttenuation2=Rs, ...
    SampleRate=Fs, DesignMethod="ellip");
```

### Bandstop IIR (scalar edges + numbered ripple!)

```matlab
d = designfilt("bandstopiir", ...
    PassbandFrequency1=fp1, StopbandFrequency1=fs1, ...
    StopbandFrequency2=fs2, PassbandFrequency2=fp2, ...
    PassbandRipple1=Rp, StopbandAttenuation=Rs, PassbandRipple2=Rp, ...
    SampleRate=Fs, DesignMethod="ellip");
```

Mirror of bandpassiir: two passbands need `PassbandRipple1`/`2`, one stopband uses singular `StopbandAttenuation`.

## Design Methods

| Method | Characteristics |
|--------|-----------------|
| `"ellip"` | Minimum order, equiripple in pass & stop |
| `"butter"` | Maximally flat, monotonic response |
| `"cheby1"` | Ripple in passband only |
| `"cheby2"` | Ripple in stopband only |
| `"equiripple"` | Parks-McClellan (FIR only) |

## SystemObject=true (streaming)

For streaming applications, get a System object directly:

```matlab
% Returns dsp.SOSFilter (IIR) or dsp.FIRFilter (FIR)
sosFilter = designfilt("lowpassiir", ...
    PassbandFrequency=Fpass, StopbandFrequency=Fstop, ...
    SampleRate=Fs, DesignMethod="ellip", ...
    SystemObject=true);

y = sosFilter(x);  % Stateful, ready for streaming
```

---

## Gotchas

### IIR bandpass/bandstop vector error

**Wrong**:
```matlab
% Anti-pattern
d = designfilt("bandpassiir", ...
    PassbandFrequency=[300 3400], ...);  % ERROR! Vector not allowed for IIR
```

**Correct**: Use scalar properties with `...1`/`...2` suffixes.

**Note**: FIR bandpass/bandstop CAN use vectors: `PassbandFrequency=[f1 f2]`

### IIR bandpass/bandstop ripple and attenuation naming

Suffix follows the number of bands in minimum-order designs:
- **bandpassiir** (1 passband, 2 stopbands): `PassbandRipple` + `StopbandAttenuation1`/`2`
- **bandstopiir** (2 passbands, 1 stopband): `PassbandRipple1`/`2` + `StopbandAttenuation`

Using the wrong form (e.g., `PassbandRipple` for minimum-order bandstopiir, or `StopbandAttenuation1`/`2` for bandstopiir) produces an invalid parameter set error.

### Deprecated Coefficients property

**Wrong**: `sos = d.Coefficients;` (removed in recent versions)

**Correct**:
```matlab
B = d.Numerator;      % Lx3 per-section
A = d.Denominator;    % Lx3 per-section
sos = [B A];          % Lx6 if needed
```

### Manual dsp.SOSFilter vs SystemObject=true

Don't manually extract coefficients to create a System object:
```matlab
% Template
% Inefficient
d = designfilt(...); B = d.Numerator; A = d.Denominator;
sosFilter = dsp.SOSFilter('Numerator', B, 'Denominator', A);

% Efficient - get System object directly
sosFilter = designfilt(..., SystemObject=true);
```

### Narrow bandpass FIR undershoot

Equiripple minimum-order designs for narrow bandpass filters can undershoot specs — the optimizer distributes error across bands and may exceed Rp or miss Rs.

**Fix**: Over-design by tightening specs (e.g., Rp×0.5, Rs+5 dB), then verify the actual measured response against the real spec.

```matlab
% Real spec: Rp=1 dB, Rs=50 dB
% Over-design to compensate for equiripple undershoot:
d = designfilt("bandpassfir", ...
    StopbandFrequency1=150, PassbandFrequency1=180, ...
    PassbandFrequency2=220, StopbandFrequency2=250, ...
    StopbandAttenuation1=55, PassbandRipple=0.5, StopbandAttenuation2=55, ...
    SampleRate=Fs, DesignMethod="equiripple");
% Then verify: freqz(d, [], Fs) and check measured Rp/Rs against REAL spec
```

### Boundary over-spec for minimum-order designs

`designfilt` minimum-order designs can land exactly on the spec boundary (e.g., measured Rs = 60.0 dB for Rs=60 spec). Over-specify Rs by 1 dB to ensure margin.

### Ultra-high-Q notch (excessive ringing)

**Problematic**: `QualityFactor=1000` causes long ringing

**Better**: Use moderate Q (10-50). For multiple tones, use several moderate notches instead of one ultra-sharp notch.

---

## iirnotch / iircomb (alternative to designfilt)

For simple notch filters, `iirnotch` is a quick alternative:

```matlab
wo = f0/(Fs/2);      % Normalized frequency
bw = bandwidth/(Fs/2);  % Normalized bandwidth
[b, a] = iirnotch(wo, bw);
y = filter(b, a, x);
```

**Note**: Returns `[b, a]` coefficients, not a digitalFilter object.


----

Copyright 2026 The MathWorks, Inc.

----
