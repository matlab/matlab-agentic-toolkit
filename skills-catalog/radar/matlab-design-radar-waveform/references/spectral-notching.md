# Spectral Notching Reference

## What "Zero Energy in a Notch" Means

Distinguish carefully:
- **Zero energy in native DFT bins:** Exact for finite discrete signals when notch
  edges align with DFT bin centers. Choose pulse length so `notchBW * pulseWidth`
  is an integer for clean bin alignment.
- **Low energy over a continuous frequency interval:** Approximate — spectral
  leakage from adjacent bins fills narrow notches in zero-padded displays.
- **Compliance with an analog spectral mask:** Depends on DAC/RF filtering after
  the digital waveform. Report measured suppression, not assumed zero.

Do not claim exact zero energy in a continuous notch unless the discrete-time
and finite-duration assumptions support that claim.

## Architecture: Bandstop-on-Tx / Full-Band-Rx

When the waveform must avoid a frequency band (e.g., to protect an incumbent
system in shared spectrum), use this architecture:

1. **Transmit:** Generate the waveform normally, then apply a frequency-domain
   bandstop filter to zero out the protected band.
2. **Receive:** Use a matched filter designed for the ORIGINAL (un-notched)
   waveform with time-domain coefficient windowing for sidelobe control.

This ensures the receive filter has no spectral gap — sidelobes remain
controlled by the window, not by the notch.

```matlab
% Transmit: apply bandstop notch
sig = wav();
txPulse = sig(1:nPulse);
txSpec = fftshift(fft(txPulse));
fAxis = linspace(-fs/2, fs/2, nPulse)';

% Raised-cosine notch mask
notchFilter = ones(nPulse, 1);
for k = 1:nPulse
    f = fAxis(k);
    if abs(f) < notchBW/2 - notchTransBW
        notchFilter(k) = 0;
    elseif abs(f) < notchBW/2 + notchTransBW
        x = (abs(f) - (notchBW/2 - notchTransBW)) / (2*notchTransBW);
        notchFilter(k) = 0.5*(1 + cos(pi*(1-x)));
    end
end
txPulseNotched = ifft(ifftshift(txSpec .* notchFilter));

% Receive: full-band matched filter with time-domain windowing
mfCoeffs = getMatchedFilter(wav);
tWin = taylorwin(numel(mfCoeffs), 4, -40);
mf = phased.MatchedFilter('Coefficients', mfCoeffs .* tWin);
mfOutput = mf(rxSignal);
```

## Key Constraints

- **PSL floor from notch:** The received echo is missing energy in the notched
  band (never transmitted). This creates paired-echo sidelobes at delay
  ~1/notchBW. Floor scales as ~20*log10(notchBW/totalBW). No linear receive
  filter can eliminate it.
- **Notch width trade-off:** Keep notchBW/totalBW <= 2% to maintain PSL < -35 dB
  with windowed MF. Wider notches (>10% of BW) limit PSL to ~-15 to -25 dB.
- **SNR loss:** Negligible for narrow notches: -10*log10(1 - notchBW/totalBW).
  E.g., 2% notch -> 0.09 dB loss.

## Waveform Choice for Notched Designs

- **Frank / P3 phase codes** are preferred over LFM when a spectral notch is
  present. Their LFM-like phase structure allows windowed MF to be effective,
  and they tolerate narrow notches better than plain LFM.
- Use `SweepInterval='Symmetric'` for LFM to center the sweep around DC (the
  default `'Positive'` sweeps from 0 to BW).

## Method Selection: Bandstop Filter vs shapespectrum

**Use amplitude-only bandstop filter when:**
- The waveform has structured phase (Frank, LFM, P3/P4, NLFM)
- You have a full-band matched filter reference on receive
- The notch is narrow relative to total bandwidth (<=10%)
- PSL target is below -25 dB
- Constant time-domain envelope is NOT required

**Use `shapespectrum` when:**
- Synthesizing a new waveform from scratch (PRO-FM / noise-like)
- Constant time-domain envelope IS required (saturated PA)
- The desired spectrum shape is non-trivial (Gaussian, multi-band, shaped roll-offs)
- The shaped waveform will be used as its own matched filter reference
- PSL requirement is <= -25 dB (achievable with Gaussian spectral taper)
- Multiple notches or complex mask shapes are needed

**Why `shapespectrum` fails for structured waveforms:** The POCS algorithm
alternates between enforcing spectral bounds and a time-domain magnitude
constraint. To satisfy the spectral mask, it modifies phase globally across
the entire band — not just in the notch. This destroys the autocorrelation
properties of structured codes (Frank, LFM). The result has ~-13 dB PSL
regardless of the receive window used.

## shapespectrum Design Recipe (for PRO-FM)

1. Set sample rate = bandwidth (fs = BW). This makes N = fs × pw = BW × pw
   = TBP samples. Do NOT oversample — shapespectrum operates on baseband
   samples and oversampling wastes iterations on out-of-band bins.
2. Use **single-column (exact target)** format: `pow2db(gausswin(N, alpha))`
   with notch bins set to a low value (e.g., -60 dB). This produces smoother
   instantaneous frequency than bounds format, giving 3-8 dB better PSL.
3. Use smooth transitions at notch edges (raised-cosine ramp over ~2% of N)
   to avoid Gibbs ringing
4. Use a random-phase constant-envelope seed: `exp(1j*2*pi*rand(N,1))`
5. Set `'Magnitude', ones(N,1)` for constant envelope
6. Match against the shaped waveform itself (no receive window)
7. Keep gap fraction below 5% for PSL ~ -25 dB
8. Use `alpha` = 2.5-3.0 in `gausswin` for the spectral taper (higher alpha
   = stronger taper = better PSL but narrower effective bandwidth)
9. For PSL measurement after pulse compression, use `ambgfun` with `'Cut','Doppler'`
   or direct correlation — do NOT upsample first (breaks constant envelope)

**shapespectrum PSL tradeoff (Gaussian spectrum, constant envelope):**

| Gap fraction | Achievable PSL (no MF window) |
|---|---|
| <= 3% | -27 to -30 dB |
| 4-5% | -25 to -27 dB |
| 6-10% | -20 to -24 dB |
| > 15% | worse than -18 dB |

## shapespectrum API Reference

```matlab
[y, info] = shapespectrum(desiredSpectrum, x)
[y, info] = shapespectrum(desiredSpectrum, x, Name=Value)
```

**desiredSpectrum formats:**
- **N-by-1 (exact target):** Output spectrum matches this shape in dB. The
  algorithm modifies both amplitude and phase to converge. This format
  produces smoother instantaneous frequency and better PSL because the
  optimizer has a single target per bin — no room for abrupt spectral jumps.
  **Prefer this format when PSL is critical.**
- **N-by-2 (bounds [lower, upper]):** Each bin has independent lower and upper
  bounds in dB. Use `-Inf` for no lower bound, `Inf` for no upper bound.
  More flexible but the optimizer may produce non-smooth spectra within the
  bounds, degrading PSL by 3-8 dB compared to exact-target format.
  Use bounds format only when the exact spectral shape is unknown or when
  convergence fails with the single-column format.

**Key Name-Value parameters:**

| Parameter | Default | Description |
|---|---|---|
| `DesiredSpectrumRange` | `'twosided'` | `'twosided'`: DC at index 1. `'centered'`: DC at center (like `fftshift`). |
| `Magnitude` | (none) | Enforces time-domain magnitude profile (e.g., `ones(N,1)` for constant envelope). |
| `MaxIterations` | 500 | Maximum POCS iterations. |
| `SpectrumRMSEThreshold` | 0 | Stop early if RMSE drops below this value. |

**Output info struct fields:**

| Field | Description |
|---|---|
| `NumIterations` | Number of iterations performed |
| `SpectrumRMSEFinal` | Final spectrum RMSE at convergence |
| `ExitFlag` | 0 = max iterations reached, 1 = RMSE threshold met |

**Common pitfalls:**
- **Energy collapse with bounds:** If `upper = Inf` in passband and `lower = -Inf`
  everywhere, the algorithm may concentrate energy near notch edges. Fix: add a
  finite lower bound in the passband (e.g., `fPeak - 3` dB).
- **Flat single-column spectrum:** Using a single-column spectrum with 0 dB
  flat passband and -80 dB notch over-constrains the problem (forces exact
  0 dB everywhere). Fix: use a Gaussian taper (`pow2db(gausswin(N, alpha))`)
  as the single-column target — this gives the algorithm a smooth shape to
  track and produces excellent PSL.
- **RMSE = 0 but bad PSL:** Convergence on the spectral mask does NOT guarantee
  good autocorrelation. The algorithm optimizes spectrum compliance, not PSL.
- **Passband ripple from Magnitude constraint:** Constant envelope + deep notch
  forces ~2 dB passband ripple. This limits PSL to ~-25 dB even with
  self-referencing MF.

## Displaying Narrow Spectral Notches

When notchBW x pulseWidth <= ~10 (fewer than 10 DFT bins in the notch):

- **Do NOT use zero-padded FFT** for notch visualization. Zero-padding
  interpolates via sinc convolution, filling the notch with leakage.
- **Do NOT use windowed FFT** (Blackman-Harris, Hamming, etc.). The window
  broadens each spectral line, smearing energy into the notch.
- **DO use native DFT bins** (no zero-padding, no window) plotted directly.

```matlab
S = fftshift(fft(txPulseNotched));  % native bins only
S_dB = mag2db(abs(S) / max(abs(S)));
fBins = linspace(-fs/2, fs/2, numel(S))' / 1e6;
plot(fBins, S_dB);

% Quantitative metric
inNotch = abs(fBins*1e6) < notchBW/2 - notchTransBW;
inPass = abs(fBins*1e6) > notchBW/2 + notchTransBW & abs(fBins*1e6) < bwTotal/2;
suppression_dB = 10*log10(mean(abs(S(inPass)).^2)) - 10*log10(mean(abs(S(inNotch)).^2));
```

----

Copyright 2026 The MathWorks, Inc.

----
