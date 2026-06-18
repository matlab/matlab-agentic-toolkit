# Network Parameter Conversions

Convert between S, Z, Y, ABCD, T, H, and G parameter representations. Compute mixed-mode (differential/common) S-parameters and reduce or reorder ports.

## Object-Based Conversions (Preferred)

Object constructors automatically handle impedance bookkeeping. This is the modern approach.

```matlab
z = zparameters(s);                    % S -> Z
y = yparameters(s);                    % S -> Y
a = abcdparameters(s);                 % S -> ABCD
t = tparameters(s);                    % S -> T (transfer/chain scattering)
h = hparameters(s);                    % S -> H (2-port only)
g = gparameters(s);                    % S -> G (2-port only)

% Convert back
sRoundTrip = sparameters(z);           % Z -> S (uses z.Impedance)
sCustomZ0 = sparameters(y, 75);        % Y -> S with 75 Ohm reference
```

All parameter objects share the same interface: `.Parameters`, `.Frequencies`, `.Impedance`, `.NumPorts`.

### Port Count Limitations

| Parameter type | Port requirement |
|---------------|-----------------|
| S, Y, Z | N-port (any size) |
| ABCD, T | 2N-port only |
| H, G | 2-port only |

## Array-Based Conversions

Use when you need raw numeric arrays without object overhead.

```matlab
yData = s2y(s.Parameters, s.Impedance);
zData = s2z(s.Parameters, s.Impedance);
abcdData = s2abcd(s.Parameters, s.Impedance);
tData = s2t(s.Parameters);             % No Z0 needed for T-parameters
```

## Mixed-Mode (Differential/Common) S-Parameters

Convert 2N-port single-ended to N-port differential or common mode. Critical for high-speed serial link analysis.

```matlab
s4 = sparameters('connector.s4p');

% Differential mode (Sdd)
sdd = s2sdd(s4.Parameters);            % Default: option 1 port pairing

% Common mode (Scc)
scc = s2scc(s4.Parameters);

% Cross-mode (differential-to-common and vice versa)
sdc = s2sdc(s4.Parameters);
scd = s2scd(s4.Parameters);
```

### Port Ordering Options -- The #1 Source of Mixed-Mode Errors

For a 4-port network, the option selects which physical ports form each differential pair:

| Option | Differential Pairs (4-port) | Description |
|--------|---------------------------|-------------|
| 1 (default) | (1+,3-) and (2+,4-) | First half = positive terminals, second half = negative |
| 2 | (1+,2-) and (3+,4-) | Adjacent ports form each pair |
| 3 | (1+,2-) and (4+,3-) | Pair 1 ascending, pair 2 descending |

```matlab
sdd_opt2 = s2sdd(s4.Parameters, 2);   % Option 2 port ordering
```

**Gotcha:** Option 1 (default) treats ports 1,2 as positive terminals and 3,4 as negative -- NOT adjacent pairing. Verify which option matches your VNA port numbering before converting. Wrong port ordering produces subtly incorrect results that look plausible but are wrong.

**Gotcha:** Differential impedance = 2 x single-ended impedance. When wrapping `s2sdd` output in a `sparameters` object, double the reference impedance:
```matlab
sdd = s2sdd(s4.Parameters);
sDiff = sparameters(sdd, s4.Frequencies, 2*s4.Impedance);  % 100 Ohm for 50 Ohm single-ended
```

## Port Reduction and Reordering: `snp2smp`

Reduce N-port to M-port by selecting ports and terminating the rest.

**Gotcha:** Argument order is `snp2smp(s, portList, Z0)` -- the port list comes **before** the termination impedance. Swapping them (e.g., `snp2smp(s, 50, [1 3])`) treats the scalar as a port index and errors.

```matlab
% Extract ports 1 and 3 from a 4-port, terminate ports 2 and 4 with 50 Ohm
s2 = snp2smp(s4, [1 3], 50);

% Swap ports of a 2-port
sSwapped = snp2smp(s, [2 1]);

% Terminate with different impedances per port
s2 = snp2smp(s4, [1 3], {50, 75, 50, 75});
```

## Transfer Function

```matlab
tf = s2tf(s);                          % Voltage transfer function (option 1, default)
tf = s2tf(s, 60, 75, 2);              % Zs=60, Zl=75, option 2: Vl/Vs
```

Options: 1 = Vl/Va (default), 2 = Vl/Vs, 3 = power-wave gain.

## Common Applications of ABCD Parameters

### Propagation Constant from Transmission Line S-Parameters

For a matched transmission line of length L, the ABCD A-parameter relates to propagation constant:

```matlab
s = sparameters('line.s2p');
abcd = abcdparameters(s);
A = rfparam(abcd, 1, 1);              % A-parameter vs frequency
L = 0.1;                               % Line length in meters
gamma = acosh(A) / L;                   % Complex propagation constant
alpha = real(gamma);                    % Attenuation (Np/m)
beta = unwrap(imag(gamma));             % Phase constant (rad/m), unwrapped
```

### Loss Tangent Extraction

Extract dielectric loss tangent from the attenuation constant:

```matlab
% After computing alpha from ABCD (above):
c = 3e8;
epsR = 4.4;                            % Known substrate permittivity
freq = abcd.Frequencies;
tanDelta = (alpha * c) ./ (pi * freq * sqrt(epsR));
```

Note: This formula assumes dielectric loss dominates. For conductor+dielectric loss separation, fit alpha = a1*sqrt(f) + a2*f and extract tanDelta from the a2*f (dielectric) term.

### PI-Model Extraction from ABCD

Extract lumped PI-equivalent (shunt-series-shunt) from connector/short-line ABCD:

```matlab
abcd = abcdparameters(s);
A = rfparam(abcd, 1, 1);
B = rfparam(abcd, 1, 2);
D = rfparam(abcd, 2, 2);

% PI-model elements at each frequency:
Zseries = B;                           % Series impedance
Y1 = (A - 1) ./ B;                    % Input shunt admittance
Y2 = (D - 1) ./ B;                    % Output shunt admittance

% Convert to lumped values at a single frequency:
f0 = freq(idx);  w0 = 2*pi*f0;
Lseries = imag(Zseries(idx)) / w0;    % Series inductance
Rseries = real(Zseries(idx));          % Series resistance
C1 = imag(Y1(idx)) / w0;              % Input shunt capacitance
C2 = imag(Y2(idx)) / w0;              % Output shunt capacitance
```

## Synthetic Data Recipes

Use these one-shot patterns to create test data for conversion demos. Avoids iteration on data construction.

### 2-Port Channel (for S->Z, S->Y, S->ABCD demos)

```matlab
freq = linspace(1e9, 10e9, 101).';
loss = 10.^(-0.3*freq/10e9/20);       % 0.3 dB loss at 10 GHz
phase = exp(-1j*2*pi*freq*0.5e-9);    % 0.5 ns delay
S21 = loss .* phase;
S11 = 0.05 * ones(size(freq));
sData = reshape([S11, S21, S21, S11].', 2, 2, []);
s = sparameters(sData, freq, 50);
```

### Z-Parameter Data (for Z->S conversion demos)

```matlab
freq = linspace(1e9, 5e9, 51).';
w = 2*pi*freq;
Z11 = 50 + 1j*w*2e-9;                 % 50 Ohm + 2 nH
Z22 = 75 + 1j*w*1.5e-9;              % 75 Ohm + 1.5 nH
Z12 = 1j*w*0.5e-9;                    % 0.5 nH mutual
zData = reshape([Z11, Z12, Z12, Z22].', 2, 2, []);
z = zparameters(zData, freq);          % Ready for sparameters(z, Z0)
```

### 4-Port Balanced Structure (for mixed-mode demos)

Builds a symmetric reciprocal 4-port with prescribed Sdd21 and Scc21 (option 1 pairing):

```matlab
freq = linspace(1e9, 10e9, 51).';
dd21 = 0.9*exp(-1j*2*pi*freq*1e-9);   % Strong differential transmission
cc21 = 0.05*ones(size(freq));           % -26 dB common-mode transmission
dd11 = 0.1*ones(size(freq));            % Low differential reflection
cc11 = 0.1*ones(size(freq));            % Low common-mode reflection
% Compose single-ended S from modal targets (option 1: pairs 1+3-, 2+4-)
S11 = reshape((dd11+cc11)/2, 1, 1, []);
S13 = reshape((cc11-dd11)/2, 1, 1, []);
S21 = reshape((dd21+cc21)/2, 1, 1, []);
S23 = reshape((cc21-dd21)/2, 1, 1, []);
sData = [S11, S21, S13, S23;
         S21, S11, S23, S13;
         S13, S23, S11, S21;
         S23, S13, S21, S11];
s4 = sparameters(sData, freq, 50);
```

### Quick Circuit S-Parameters (for conversion demos needing a DUT)

```matlab
% L-section matching network (series L + shunt C)
ckt = circuit('LMatch');
add(ckt, [1 2], inductor(10e-9));
add(ckt, [2 3], capacitor(2e-12));
setports(ckt, [1 3], [2 3]);
freq = linspace(1e9, 3e9, 101).';
s = sparameters(ckt, freq);

% Bandpass filter (alternative one-liner)
filt = rffilter(ResponseType='Bandpass', FilterOrder=5, ...
    PassbandFrequency=[1.8e9 2.2e9]);
s = sparameters(filt, freq);
```

### Visualizing Impedance on Smith Chart

```matlab
s = sparameters(...);                  % Your S-parameter data
z = zparameters(s);
Z11 = rfparam(z, 1, 1);
gamma11 = (Z11 - s.Impedance) ./ (Z11 + s.Impedance);
smithplot();                           % Empty chart with grid
hold on;
plot(real(gamma11), imag(gamma11), 'b-', 'LineWidth', 2);
plot(real(gamma11(1)), imag(gamma11(1)), 'go', 'MarkerSize', 10);
plot(real(gamma11(end)), imag(gamma11(end)), 'rx', 'MarkerSize', 10);
title('Input Impedance Trajectory');
```

## Round-Trip Validation

Always verify round-trip accuracy when conversion fidelity matters:

```matlab
z = zparameters(s);
sBack = sparameters(z);
err = max(abs(s.Parameters(:) - sBack.Parameters(:)));
assert(err < 1e-12, 'Round-trip error: %.2e', err);
```

## Gotchas

1. **H and G parameters are 2-port only** -- `hparameters(s)` and `gparameters(s)` error for networks with more than 2 ports. ABCD and T require 2N-port (even number).
2. **Mixed-mode port ordering is the #1 error source** -- `s2sdd`, `s2scc`, `s2sdc`, `s2scd` accept an option argument (1, 2, or 3) for port pairing. Verify which option matches your VNA port numbering before converting -- wrong ordering produces subtly incorrect results that look plausible.
3. **Differential impedance = 2x single-ended** -- If single-ended Z0 is 50 Ohm, differential Z0 is 100 Ohm.
4. **`snp2smp` argument order: ports before impedance** -- `snp2smp(s, portList, Z0)`, not `snp2smp(s, Z0, portList)`. Swapping them treats the scalar as a port index and errors.

## Conventions

- Prefer object-based conversions over array-based -- they track impedance automatically
- Always verify round-trip accuracy (S->Z->S) when conversion fidelity matters
- Use `rfparam` to extract individual parameters from any network parameter object

----

Copyright 2026 The MathWorks, Inc.

----
