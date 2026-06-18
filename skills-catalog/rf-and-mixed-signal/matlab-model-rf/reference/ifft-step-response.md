# iFFT Step Response from Frequency-Domain Data

Compute a time-domain step response from a frequency-domain transfer function H(f) using iFFT. Applies to any linear input-output relationship: impedance (current->voltage), admittance (voltage->current), S-parameters, voltage transfer functions, etc.

## When to use

You have a frequency-domain transfer function H(f) — complex-valued, on a uniform frequency grid — and you want to see the time-domain output when the input is a step-like excitation. Examples:

| H(f) | Input | Output | Application |
|-------|-------|--------|-------------|
| Z(f) impedance | Current step | Voltage waveform | PDN droop analysis |
| Y(f) admittance | Voltage step | Current waveform | Inrush current |
| S21(f) | Incident wave step | Transmitted wave | Channel step response |
| S11(f) | Incident wave step | Reflected wave | TDR |
| Voltage gain H(f) | Input voltage step | Output voltage | Filter/amplifier response |

## Quick recipe

```matlab
% Inputs: f_data (uniform freq vector, no DC), H_data (complex), riseTime (20-80%)
% Requirement: f_data(end) >= 0.6 / riseTime

df = f_data(2) - f_data(1);
M = length(f_data);
N = 2 * M;
dt = 1 / (2 * f_data(end));
t = (0:N-1)' * dt;

% DC extrapolation + one-sided spectrum
H_onesided = [real(H_data(1)); H_data(:)];
H_onesided(end) = real(H_onesided(end));     % Nyquist must be real

% Hermitian symmetry -> two-sided spectrum
H_full = [H_onesided; conj(H_onesided(end-1:-1:2))];

% Zero-mean raised cosine pulse (avoids wrap-around from slow modes)
x_pulse = raisedCosinePulse(t, riseTime, -0.5, +0.5);

% Multiply in frequency domain, recover time domain
y_raw = real(ifft(H_full .* fft(x_pulse)));
y_t = y_raw - y_raw(1);   % reference from pre-step condition
```

**Key rules:**
- Bandwidth needed: `f_max >= 0.6 / t_r` (raised cosine is below -80 dB beyond this)
- Observation window: `T_window = 1/df` — only first half is valid (pulse falls at midpoint)
- DC bin must be real; Nyquist bin must be real
- **Use zero-mean pulse** (`-A/2` to `+A/2`) + subtract initial value — avoids wrap-around from slow inductive/reactive modes
- Verify: `max(abs(imag(ifft(...)))) < 1e-10` and `y_t(1) == 0`
- Requires: `raisedCosinePulse.m`

**DC extrapolation notes:** The simple approach `H(0) = real(H_data(1))` works for most cases. H(0) must be real (Hermitian symmetry at f=0 requires H(0) = conj(H(0))). Physically, H(0) is the system's DC gain: resistance for Z(f), DC transmission for S21, etc. With the zero-mean pulse, the DC bin is less critical (zero-mean input has no DC spectral content), but setting it correctly still improves accuracy for very low-frequency behavior.

---

*Detailed explanations and pitfall descriptions follow below.*

## Background: why the naive approach fails

The textbook approach is straightforward: take iFFT of H(f) to get the impulse response, then integrate to get the step response. In practice, this produces garbage unless you handle several subtleties correctly. The approach below avoids the most common failure modes by reframing the problem.

## Key design choices (and why)

### Use a pulse, not a true step

**The problem:** A mathematical step function has a spectrum of `pi*delta(f) + 1/(j2*pi*f)`. That delta at DC means the final settled value of your output depends *entirely* on the accuracy of H(0). If your frequency data starts at some f_min > 0 (typical for simulation or measurement), you don't have H(0) — and even a small extrapolation error produces a DC offset that dominates the result.

**The solution:** Use a wide pulse instead. The pulse rises, holds for a long time, then falls back down at the midpoint of the time window. Its spectrum is smooth and finite everywhere — including at DC.

**Why this works:** If the pulse width is much longer than any feature you care about (rise times, reflections, ringing), the pulse response is indistinguishable from a step response over your observation window. You get the same information without needing perfect DC knowledge.

**The tradeoff:** The pulse eventually turns off, so there's a falling edge at the midpoint of your time window. As long as you're only looking at the first half of the time record, this doesn't matter.

### Use a raised cosine transition, not a linear ramp

**The problem:** A linear ramp has a discontinuous first derivative at its start and end points. This kink means the spectrum only rolls off as 1/f^2 — slowly. If your H(f) data is truncated at some maximum frequency (it always is), the abrupt spectral cutoff creates ringing in the time domain (Gibbs phenomenon). You'll see artificial oscillations that aren't in the physical system.

**The solution:** A raised cosine transition has zero derivative at both endpoints. Its spectrum rolls off extremely steeply — by `f = 0.6 / t_rise`, it's already below -80 dB. This means:

- H(f) data beyond `0.6 / t_rise` is irrelevant (it gets multiplied by essentially zero)
- There are no spectral truncation artifacts because the pulse has no energy at the truncation frequency
- You get a clean, artifact-free time-domain result

**The 20%-80% convention:** The rise time parameter specifies the 20%-to-80% transition time, matching how oscilloscopes report rise time in SI measurements.

### Implementation: `raisedCosinePulse.m`

```matlab
y = raisedCosinePulse(t, riseTime, lowVal, highVal)
```

Generates a pulse that rises from `lowVal` to `highVal` with a raised cosine transition, holds at `highVal`, then falls back to `lowVal` at the midpoint of the time vector using the same transition shape.

## Algorithm

### Step 1: Determine grid parameters from H(f) data

Given H(f) on a uniform grid `f = f1, 2*f1, ..., M*f1` (no DC point):

```matlab
df = f_data(2) - f_data(1);    % frequency spacing
f_max = f_data(end);            % maximum frequency
M = length(f_data);
N = 2 * M;                     % number of time points
dt = 1 / (2 * f_max);          % time step
T_window = N * dt;              % = 1/df, total time window
```

**What these control:**
- `df` determines the total observation window: `T_window = 1/df`. Finer frequency spacing = longer time record.
- `f_max` determines time resolution: `dt = 1/(2*f_max)`. Higher bandwidth = finer time steps.
- `N` falls out automatically from the other two.

**Check:** Verify `f_max >= 0.6 / riseTime`. If this fails, your H(f) data doesn't have enough bandwidth to faithfully represent the requested rise time. Either loosen the rise time requirement or obtain higher-frequency data.

### Step 2: Extrapolate the DC point

H(f) from simulation or measurement typically starts at some `f_min > 0`. You must supply H(0) to construct the full spectrum. (If your data already includes the DC point at f=0, skip this step and Step 3's prepend — just use the data directly.)

**Simple approach** (usually adequate when using the pulse method):
```matlab
H_dc = real(H_data(1));
```
This assumes the DC value equals the real part of the lowest available frequency point.

**Why it must be real:** We require H(-f) = conj(H(f)) for the output to be real-valued (Step 4). At f = 0, this gives H(0) = conj(H(0)), which is only satisfied if H(0) is real.

**Why accuracy matters less here than with a true step:** Because we're using a pulse (not a step), the DC point gets multiplied by a finite spectral value rather than a delta function. A small error in H(0) causes a small, bounded error in the output — not a catastrophic DC offset.

### Step 3: Construct one-sided spectrum

Prepend the DC value to form the complete positive-frequency spectrum:

```matlab
f_onesided = [0; f_data(:)];        % M+1 points: 0, df, ..., M*df (= f_nyquist)
H_onesided = [H_dc; H_data(:)];     % M+1 complex values
```

**Force the Nyquist bin to be real:**
```matlab
H_onesided(end) = real(H_onesided(end));
```

This is required for the next step. The Nyquist frequency simultaneously represents both +f_max and -f_max, so it must equal its own complex conjugate (i.e., be real). If your data has a significant imaginary part at Nyquist, it usually means the data there is noisy or unreliable — which is fine, since the raised cosine pulse has negligible energy at Nyquist anyway.

### Step 4: Build full two-sided H with Hermitian symmetry

For the iFFT to produce a real-valued time signal, the frequency-domain data must satisfy H(-f) = conj(H(f)). Construct the negative frequencies by mirroring:

```matlab
H_full = [H_onesided; conj(H_onesided(end-1:-1:2))];
```

This produces N points in MATLAB's FFT bin ordering:
```
bin:   1     2     3    ...  N/2+1       N/2+2        ...    N
freq:  0     df   2*df  ... f_nyquist   -(f_nyq-df)   ...   -df
```

**Why this ordering:** MATLAB's `fft`/`ifft` expect this layout. Bins 1 through N/2+1 are non-negative frequencies (DC through Nyquist). Bins N/2+2 through N are negative frequencies in descending magnitude order.

### Step 5: Generate input pulse and compute its FFT

```matlab
t = (0:N-1)' * dt;
x_pulse = raisedCosinePulse(t, riseTime, -0.5, +0.5);  % zero-mean pulse
X_fft = fft(x_pulse);
```

The zero-mean pulse goes from -A/2 to +A/2 (here A=1). This ensures zero average value over the window, eliminating DC drive on reactive elements and preventing wrap-around from slow settling modes. The pulse lives entirely in the time domain and is transformed to match H(f)'s frequency grid. Because both share the same N and dt, their frequency bins are automatically aligned.

### Step 6: Multiply and inverse FFT

```matlab
Y_fft = H_full .* X_fft;
y_raw = real(ifft(Y_fft));
y_t = y_raw - y_raw(1);   % reference from pre-step condition
```

This implements Y(f) = H(f) * X(f), the frequency-domain equivalent of convolution. The `real()` call discards residual imaginary components that arise from floating-point arithmetic (typically at 1e-16 level). Subtracting `y_raw(1)` references the output from the pre-step steady state, so y_t(1) = 0 and subsequent values represent the deviation caused by the step.

### Step 7: Sanity checks

```matlab
imag_residual = max(abs(imag(ifft(Y_fft))));
assert(imag_residual < 1e-10, 'Hermitian symmetry is broken — check DC and Nyquist bins');
```

If this assertion fires, something is wrong with the spectrum construction — most likely the DC or Nyquist bin has an imaginary component, or the mirroring in Step 4 is incorrect.

## Bandwidth rule of thumb

For a raised cosine pulse with 20-80% rise time `t_r`, the spectral energy is negligible beyond:

| Attenuation | f * t_r |
|-------------|---------|
| -20 dB      | 0.53    |
| -40 dB      | 0.60    |
| -60 dB      | 0.61    |
| -80 dB      | 0.61    |

**Practical rule: `f_max = 0.6 / t_r` is sufficient.** The raised cosine spectrum hits a sharp null at this point and stays below -80 dB beyond it.

Compare this to a linear ramp, which would need `f_max > 10 / t_r` for comparable attenuation. The raised cosine buys you an order of magnitude reduction in required bandwidth.

The full cosine transition duration relates to rise time by: `T_full = t_r * pi / (acos(-0.6) - acos(0.6)) ~ 2.44 * t_r`

## Quick-reference: from requirements to frequency grid

| You want | This determines |
|---|---|
| Rise time `t_r` (e.g., 1 ns) | Minimum bandwidth: `f_max >= 0.6 / t_r` (e.g., 600 MHz) |
| Observation window `T_obs` (e.g., 1 us) | Frequency spacing: `df = 1 / T_obs` (e.g., 1 MHz) |
| Both | Number of points: `N = 2 * f_max / df` (e.g., 1200) |

If you're generating the H(f) data (e.g., choosing simulation frequencies), use this table to pick your grid. If you're working with existing data, check that the data satisfies these constraints for your desired rise time.

## Common pitfalls

### 1. Missing or incorrect DC point
**Symptom:** Large DC offset in the output, or the signal never settles to a physically reasonable value.
**Fix:** Always extrapolate H(0) as described in Step 2. Never leave it out (which implicitly sets H(0)=0) or skip the DC bin.

### 2. Nyquist bin has imaginary component
**Symptom:** `imag(ifft(...))` is not negligible — the sanity check in Step 7 fires.
**Fix:** Force `H_onesided(end) = real(H_onesided(end))` before constructing the Hermitian mirror.

### 3. Non-uniform frequency grid
**Symptom:** The algorithm produces nonsensical results or crashes.
**Fix:** The iFFT requires uniform frequency spacing. If your H(f) data is on a non-uniform grid (e.g., log-spaced or adaptively sampled), interpolate it onto a uniform grid first. The main risk is under-sampling: if the original grid is too coarse near a resonance or sharp feature, no interpolation method will recover it faithfully. After interpolating, verify by overlaying the original and interpolated data — plot real and imaginary parts separately (not just magnitude), since magnitude can look smooth while real/imaginary parts oscillate rapidly through a resonance.

### 4. Insufficient bandwidth
**Symptom:** The rising edge looks sluggish or rounded compared to what you expect, even though you specified a fast rise time.
**Fix:** Ensure `f_max >= 0.6 / t_r`. If your data doesn't extend high enough, you must either accept a slower effective rise time or obtain additional high-frequency data.

### 5. Time aliasing (window too short) — use a zero-mean pulse
**Symptom:** Spurious features appear near the rising edge, or the response looks "contaminated" with activity that shouldn't be there. The output at t=0 is nonzero when it should start from the pre-step condition.
**Cause:** The iFFT is inherently circular — if the system's response hasn't settled by the time the pulse turns off (at T_window/2), the falling-edge response wraps around and contaminates the rising-edge observation window. This is catastrophic when the system has a slow mode (e.g., a VRM inductor with L/R = 20 us settling time vs. a 512 ns window).
**Fix — zero-mean pulse:** Instead of a pulse from 0 to A, use a pulse from -A/2 to +A/2. This makes the pulse's time-average zero, eliminating the DC current drive on inductive elements. Without DC flux, the inductor has no long exponential settling, and the response decays within the window. Then reference the result from the pre-step condition:

```matlab
x_pulse = raisedCosinePulse(t, riseTime, -Istep/2, +Istep/2);
Y_fft = H_full .* fft(x_pulse);
y_raw = real(ifft(Y_fft));
y_t = y_raw - y_raw(1);   % reference from pre-step condition
```

**Physical analogy (SPICE):** This is equivalent to initializing the inductor at its average current so the internal state variable starts at the correct steady-state value — the same trick required in SPICE transient simulations with reactive elements.

**When you need this:** Any time H(f) contains a pole with settling time > T_window/2. The telltale sign is a nonzero value at t=0 or visibly wrong DC offset even with the DC bin set correctly. For purely capacitive/resistive networks without slow inductive modes, the original 0-to-A pulse works fine.

**Alternative (less preferred):** Use finer df (longer time window) so that T_window/2 is much larger than the system's settling time. This can require impractically large N for systems with very long time constants.

### 6. Causality artifacts from circular convolution
**Symptom:** The output appears to respond slightly *before* the pulse starts (acausal pre-ringing near t=0).
**Cause:** If H(f) represents a system with significant delay (linear phase), the impulse response is shifted in time. Circular convolution wraps the tail of the response around to the beginning.
**Fix:** Shift the pulse start away from t=0 (add a quiet pre-trigger period), or zero-pad the spectrum to extend the time window.

## File dependencies

- `raisedCosinePulse.m` — generates the raised cosine pulse excitation waveform

## Example: PDN impedance

```matlab
% Load impedance data (complex Z on uniform frequency grid, no DC point)
data = load('ex1.mat');  % contains: freqUniform, Z_full_pdn
f_data = data.freqUniform;
H_data = data.Z_full_pdn;   % Z(f) is just one kind of H(f)

Istep = 1.0;        % 1 A load step
riseTime = 1e-9;    % 1 ns (20-80%)

% Step 1: Grid parameters
df = f_data(2) - f_data(1);
M = length(f_data);
N = 2 * M;
dt = 1 / (2 * f_data(end));
t = (0:N-1)' * dt;

% Step 2: DC extrapolation
H_dc = real(H_data(1));

% Step 3: One-sided spectrum
H_onesided = [H_dc; H_data(:)];
H_onesided(end) = real(H_onesided(end));

% Step 4: Hermitian symmetry
H_full = [H_onesided; conj(H_onesided(end-1:-1:2))];

% Step 5: Zero-mean input pulse (avoids VRM inductor wrap-around)
x_pulse = raisedCosinePulse(t, riseTime, -Istep/2, +Istep/2);

% Step 6: Frequency-domain multiply and iFFT
Y_fft = H_full .* fft(x_pulse);
y_raw = real(ifft(Y_fft));
y_t = y_raw - y_raw(1);   % reference from pre-step condition

% Step 7: Sanity checks
assert(max(abs(imag(ifft(Y_fft)))) < 1e-10, 'Hermitian symmetry broken');
assert(abs(y_t(1)) < 1e-15, 'Output should start at zero');

% Plot: voltage droop from 1A current step
plot(t*1e9, y_t*1e3);
xlabel('Time (ns)');
ylabel('Voltage Droop (mV)');
title('PDN Voltage Droop: 1A / 1ns Load Step');
grid on;
```

----

Copyright 2026 The MathWorks, Inc.

----
