# Cascade and De-embed S-Parameter Networks

Chain RF components in series (cascade) and remove fixture effects from measurements (de-embed) using `cascadesparams` and `deembedsparams`.

## Workflow

1. **Load networks** -- Load all S-parameter blocks
2. **Align frequencies** -- Interpolate all networks to a common frequency grid with `rfinterp1`
3. **Cascade or de-embed** -- Chain networks or remove fixtures
4. **Verify** -- Compare results against expectations; round-trip cascade+de-embed to check accuracy

## Prerequisite: Frequency Alignment

All networks must share the same frequency vector and reference impedance. This is the most common source of errors.

```matlab
% Find overlapping frequency range
fCommon = linspace(max(s1.Frequencies(1), s2.Frequencies(1)), ...
                   min(s1.Frequencies(end), s2.Frequencies(end)), 500);

% Interpolate all networks to the common grid
s1i = rfinterp1(s1, fCommon);
s2i = rfinterp1(s2, fCommon);
```

**Gotcha:** `cascadesparams` and `deembedsparams` require identical frequency vectors. If you skip `rfinterp1`, you get a dimension mismatch error or silently wrong results. Always interpolate first.

**Gotcha:** Networks must share the same reference impedance. If impedances differ, re-normalize with `newref` before cascading: `s2i = newref(s2i, s1i.Impedance)`.

**Gotcha:** `rfinterp1` interpolates the **real and imaginary parts** independently (like `interp1`), not magnitude and angle. This can produce artifacts near sharp resonances or rapid phase transitions.

## Cascading Networks

Connect networks in series -- output ports of one feed into input ports of the next.

```matlab
% Two networks
sTotal = cascadesparams(s1i, s2i);

% Three or more networks
sChain = cascadesparams(s1i, s2i, s3i);
```

**Gotcha:** `cascadesparams` assumes standard port ordering: ports 1:N are inputs, N+1:2N are outputs. If your ports follow a different convention, use `snp2smp` to reorder before cascading.

### Identifying Input vs Output Ports

To determine which ports are inputs and which are outputs, inspect the S-parameter matrix at the **lowest frequency**: off-diagonal elements with the largest magnitude are the through connections.

```matlab
s4 = sparameters('device.s4p');
S = s4.Parameters(:,:,1);          % S-matrix at lowest frequency
disp(abs(S));                       % Through paths have the largest off-diagonal magnitudes
% If S(2,1) and S(4,3) are the largest, then ports 1,3 are inputs and 2,4 are outputs
```

For typical 4-port differential pairs: through paths are S21 and S43, meaning ports 1,3 are near-end (input) and ports 2,4 are far-end (output). To use with `cascadesparams`, reorder so inputs are first:

```matlab
% Reorder from [1,2,3,4] to [1,3,2,4] so ports 1,2=input and 3,4=output
sReordered = snp2smp(s4, [1 3 2 4]);
sCascade = cascadesparams(sReordered, sReordered);
% Reorder result back to original convention
sCascade = snp2smp(sCascade, [1 3 2 4]);
```

### Multi-Port Cascading

`cascadesparams` supports networks of **different sizes** when you specify how many ports connect via the third argument:

```matlab
% Default (no 3rd arg): both must be 2N-port, connects last N to first N
sTotal = cascadesparams(s2a, s2b);      % Two 2-port -> 2-port result

% With connection count (3rd arg): works with different-sized networks
sTotal = cascadesparams(s4, s2, 1);     % 4-port + 2-port, connect 1 port
% Result: (4 + 2 - 2*1) = 4-port
```

The third argument specifies how many ports connect between the networks. The last M output ports of the first network connect to the first M input ports of the second. The result has `(N1 + N2 - 2*M)` ports.

For complex topologies where `cascadesparams` port ordering doesn't match your physical setup:
- Use `snp2smp` to reorder ports before cascading
- Or use the `circuit` object for full topology control

## De-embedding Fixtures

Remove fixture (test fixture, adapter, cable) effects from a measured DUT to recover the true device response.

**Gotcha:** `deembedsparams` **always requires 3 arguments**: `deembedsparams(sMeasured, s1, s3)` where `s1` is the port-1 fixture and `s3` is the port-2 fixture. Calling with only 2 arguments errors with "Not enough input arguments." For one-sided de-embedding, pass an ideal thru for the unused side.

### Two-Sided De-embedding

```matlab
% Measured: fixture1 + DUT + fixture2
% Goal: extract DUT S-parameters
sDUT = deembedsparams(sMeasured, sFixture1, sFixture2);
```

### One-Sided De-embedding

To de-embed only one side, construct an ideal thru for the other side:

```matlab
nf = numel(sMeasured.Frequencies);
thruData = zeros(2, 2, nf);
thruData(1,2,:) = 1;
thruData(2,1,:) = 1;
sThru = sparameters(thruData, sMeasured.Frequencies, 50);

% Remove only the left fixture
sDUT = deembedsparams(sMeasured, sFixture1, sThru);

% Remove only the right fixture
sDUT = deembedsparams(sMeasured, sThru, sFixture2);
```

### Half-Fixture Extraction from 2x-Through

When you only have a through measurement of two identical fixtures back-to-back (no separate fixture characterization), extract one fixture using T-parameter matrix square root:

```matlab
% Load 2x-through measurement (two identical fixtures cascaded)
s2xThru = sparameters('2x_through.s2p');

% Convert to T-parameters and take matrix square root at each frequency
T2x = s2t(s2xThru.Parameters);
nf = numel(s2xThru.Frequencies);
Tfixture = zeros(2, 2, nf);
for k = 1:nf
    Tfixture(:,:,k) = sqrtm(T2x(:,:,k));
end

% Convert back to S-parameters
sFixture = sparameters(t2s(Tfixture), s2xThru.Frequencies, s2xThru.Impedance);

% Now de-embed DUT using the extracted fixture
sDUT = deembedsparams(sMeasured, sFixture, sFixture);
```

**Note:** This assumes symmetric fixtures (identical left and right). For asymmetric fixtures, more advanced techniques are needed.

### Synthetic Fixture Data (for testing)

```matlab
freq = linspace(1e9, 20e9, 201);
loss = 10^(-0.5/20);  % 0.5 dB per fixture
phase = reshape(exp(-1j*2*pi*freq*15e-12), 1, 1, []);  % 15 ps delay
sData = [0.03 0; 0 0.03] + [0 loss; loss 0].*phase;  % 2x2xN via implicit expansion
sOneFixture = sparameters(sData, freq, 50);
s2xThru = cascadesparams(sOneFixture, sOneFixture);
```

### 4-Port De-embedding

`deembedsparams` works directly with 4-port (and N-port) networks -- same 3-argument syntax:

```matlab
% 4-port fixture and 4-port measurement
sFixture4p = sparameters('fixture_4port.s4p');
sMeasured4p = sparameters('measured_4port.s4p');

% De-embed both sides (symmetric fixtures)
sDUT4p = deembedsparams(sMeasured4p, sFixture4p, sFixture4p);

% Or asymmetric fixtures
sDUT4p = deembedsparams(sMeasured4p, sFixtureLeft4p, sFixtureRight4p);
```

All networks must have the same number of ports. Port ordering must be consistent across fixture and measurement.

### Verification Pattern

Cascade then de-embed to verify round-trip accuracy:

```matlab
% Build chain
sChain = cascadesparams(sFixture, sDUT, sFixture);

% Recover DUT
sRecovered = deembedsparams(sChain, sFixture, sFixture);

% Check error
origS21 = rfparam(sDUT, 2, 1);
recS21 = rfparam(sRecovered, 2, 1);
maxErr = max(abs(origS21 - recS21));
fprintf('Round-trip S21 max error: %.2e\n', maxErr);
```

### VNA Calibration Check (De-embed Through Standard)

Verify calibration by de-embedding fixtures from a known through measurement -- the result should be an ideal through (0 dB insertion loss, 0 phase):

```matlab
% Measure through standard with fixtures in place
sThruMeasured = sparameters('through_measured.s2p');

% De-embed fixtures
sThruDeembedded = deembedsparams(sThruMeasured, sFixtureL, sFixtureR);

% Check deviation from ideal (S21 = 1, S11 = 0)
s21 = rfparam(sThruDeembedded, 2, 1);
s11 = rfparam(sThruDeembedded, 1, 1);
fprintf('S21 mag error: %.4f dB\n', max(abs(20*log10(abs(s21)))));
fprintf('S21 phase error: %.4f deg\n', max(abs(angle(s21)*180/pi)));
fprintf('S11 max: %.1f dB\n', max(20*log10(abs(s11))));
```

## Gotchas

1. **Frequency alignment is required** -- `cascadesparams` and `deembedsparams` require identical frequency vectors. Always `rfinterp1` to a common grid first, or you get dimension mismatch errors or silently wrong results.
2. **`deembedsparams` always requires 3 arguments** -- `deembedsparams(sMeasured, s1, s3)` where s1 is the port-1 fixture and s3 is the port-2 fixture. Calling with only 2 arguments errors. For one-sided de-embedding, pass an ideal thru for the unused side.
3. **`rfinterp1` interpolates real/imag independently** -- (like `interp1`). Not magnitude and angle. Can produce artifacts near sharp resonances or rapid phase transitions.
4. **`cascadesparams` assumes standard port ordering** -- Ports 1:N are inputs, N+1:2N are outputs. If your ports follow a different convention, use `snp2smp` to reorder before cascading.

## Conventions

- Always interpolate to a common frequency grid before cascading or de-embedding
- Use `tiledlayout`/`nexttile` when comparing original vs. cascaded/de-embedded results
- Label plots clearly to distinguish standalone vs. cascaded responses
- Verify de-embedding accuracy by round-tripping when fixture data is available

----

Copyright 2026 The MathWorks, Inc.

----
