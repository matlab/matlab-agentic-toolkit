# rf.Amplifier Nonlinear Model Details

## Finding P1dB Numerically (modified-rapp, saleh)

Only `poly`/`cubic` accept `OP1dB` directly. For `modified-rapp` and `saleh`, P1dB must be found by sweeping input power:

```matlab
% Find P1dB numerically for any model type
% rf.Amplifier uses 1-ohm normalized power: P(W) = |V|^2
Pin_dBm = (-40:0.1:30)';
Vin = sqrt(10.^((Pin_dBm-30)/10));          % 1-ohm: Vin = sqrt(Pin_W)
Vout = amp(Vin);
Pout_dBm = 10*log10(abs(Vout).^2) + 30;    % 1-ohm: Pout = |Vout|^2
gain_dB = Pout_dBm - Pin_dBm;
release(amp);
idx = find(gain_dB < gain_dB(1) - 1, 1);   % 1-dB compression point
OP1dB = Pout_dBm(idx);
```

## Comparing AM/AM Across Model Types at Matched P1dB

To compare polynomial, modified-rapp, and saleh at the same P1dB, create all three with the same small-signal gain, sweep once, then normalize to each model's P1dB:

```matlab
targetGain = 15;  targetP1dB = 25;  % dBm

% Poly: set OP1dB directly
ampPoly = rf.Amplifier(Gain=targetGain, OIP3=35, OP1dB=targetP1dB);

% Modified-Rapp: OPsat ≈ P1dB + 2 dB (for MagnitudeSmooth=3)
% OPsat(dBm) = 10*log10(Vsat^2)+30, so Vsat = sqrt(10^((OPsat-30)/10))
Vsat = sqrt(10^((targetP1dB + 2 - 30)/10));
ampRapp = rf.Amplifier(Model='modified-rapp', ...
    MagnitudeGainDB=targetGain, Vsat=Vsat, MagnitudeSmooth=3);

% Saleh: gain = 20*log10(alpha_a) + OutputScaleDB + InputScaleDB
% Default alpha_a=2.1587 -> 6.69 dB. Higher InputScaleDB = earlier P1dB.
salehGain0 = 20*log10(2.1587);  % intrinsic gain from AmAmParameters
IS = 9;  OS = targetGain - salehGain0 - IS;  % keep total gain = targetGain
ampSaleh = rf.Amplifier(Model='saleh', InputScaleDB=IS, OutputScaleDB=OS);

% Sweep all three (1-ohm normalized: P = |V|^2)
Pin_dBm = (-40:0.1:30)';
Vin = sqrt(10.^((Pin_dBm-30)/10));

VoutPoly = ampPoly(Vin);   release(ampPoly);
VoutRapp = ampRapp(Vin);   release(ampRapp);
VoutSaleh = ampSaleh(Vin); release(ampSaleh);

PoutPoly = 10*log10(abs(VoutPoly).^2) + 30;
PoutRapp = 10*log10(abs(VoutRapp).^2) + 30;
PoutSaleh = 10*log10(abs(VoutSaleh).^2) + 30;

% Find P1dB for each
gainPoly = PoutPoly - Pin_dBm;
gainRapp = PoutRapp - Pin_dBm;
gainSaleh = PoutSaleh - Pin_dBm;
p1dB_poly = PoutPoly(find(gainPoly < gainPoly(1)-1, 1));
p1dB_rapp = PoutRapp(find(gainRapp < gainRapp(1)-1, 1));
p1dB_saleh = PoutSaleh(find(gainSaleh < gainSaleh(1)-1, 1));
fprintf('P1dB: Poly=%.1f, Rapp=%.1f, Saleh=%.1f dBm\n', ...
    p1dB_poly, p1dB_rapp, p1dB_saleh);

% Plot AM/AM comparison
figure; hold on;
plot(Pin_dBm, PoutPoly, 'b', Pin_dBm, PoutRapp, 'r', Pin_dBm, PoutSaleh, 'g');
legend('Polynomial','Modified Rapp','Saleh');
xlabel('Pin (dBm)'); ylabel('Pout (dBm)'); title('AM/AM Comparison');
```

This single-sweep approach targets the same P1dB by construction: poly sets `OP1dB` directly, modified-rapp sets `Vsat` from `targetP1dB+3`, and saleh uses `OutputScaleDB` to shift the curve. Fine-tune by adjusting by the measured dB difference, then re-sweep once.

For cascaded system P1dB in an rfbudget chain, use `computeAMPMTable(b, pinRange)` instead (see `matlab-analyze-rf-budget`).

## `poly` vs `cubic` Model

- **`poly`** (default): Fits a higher-order polynomial using ALL compression parameters you provide (IP3, P1dB, Psat). The `Nonlinearity` property is irrelevant -- do not set it. Just set whichever compression params you have data for and the polynomial uses all of them to shape the AM/AM curve.
- **`cubic`**: Fits a 3rd-order (cubic) polynomial from a SINGLE compression parameter, selected by the `Nonlinearity` property. Extra params are stored but ignored in the model.

```matlab
% poly: uses ALL set compression params to shape the polynomial
amp = rf.Amplifier(Gain=15, Model='poly', OIP3=35, OP1dB=25, OPsat=30);

% cubic: uses ONLY the ONE param selected by Nonlinearity
amp = rf.Amplifier(Gain=15, Model='cubic', Nonlinearity='OIP3', OIP3=35);
```

## Compression Parameters -- Input vs Output

Each compression metric has an input-referred and output-referred form, related through the gain:

| Metric | Output-referred | Input-referred | Relationship |
|--------|----------------|----------------|--------------|
| IP3 | `OIP3` | `IIP3` | OIP3 = IIP3 + Gain (set either one) |
| P1dB | `OP1dB` | `IP1dB` | OP1dB = IP1dB + Gain - 1 (set either one) |
| Psat | `OPsat` | `IPsat` | Independent -- both can be set simultaneously |

For IP3 and P1dB, set whichever form your datasheet provides -- MATLAB converts internally via the gain. For Psat, `IPsat` and `OPsat` are truly independent parameters (input saturation and output saturation) and both can be specified together. Convention:
- **Amplifiers** typically specify output values: `OIP3`, `OP1dB`, `OPsat`
- **Mixers and modulators** typically specify input values: `IIP3`, `IP1dB`, `IPsat`

```matlab
% Amplifier -- use output-referred (datasheet convention)
amp = rf.Amplifier(Gain=15, OIP3=35, OP1dB=25);

% Mixer -- use input-referred (datasheet convention)
mix = rf.Mixer(Model='demod', Gain=-6, RF=2.4e9, LO=2.1e9, IIP3=10);
```

## Nonlinearity Property (cubic model only)

The `Nonlinearity` property selects which single compression parameter defines the 3rd-order nonlinearity for `Model='cubic'`. It is **not relevant** for `Model='poly'` (which uses all set params).

Options: `'IIP3'`, `'OIP3'` (default), `'IP1dB'`, `'OP1dB'`, `'IPsat'`, `'OPsat'`.

**Gotcha -- `Nonlinearity` is irrelevant for poly:** Setting `Nonlinearity` with `Model='poly'` emits "not relevant" warning. For poly, just set the compression params directly -- the model uses all of them.

**Gotcha -- constructor NV-pair processing order:** When setting `Nonlinearity` in the constructor (for cubic), MATLAB processes NV pairs in internal order, not your order. This causes "not relevant" warnings. The warnings are harmless -- values ARE applied and the object works correctly.

**Gotcha -- silent misuse with OPsat in cubic:** `rf.Amplifier(Gain=15, Model='cubic', OPsat=30)` accepts `OPsat` silently but `Nonlinearity` stays `'OIP3'` with `OIP3=Inf` -- meaning no compression is applied. Always set `Nonlinearity` to match your param when using cubic.

**Gotcha -- differs from rfbudget amplifier:** The rfbudget `amplifier` element uses `OIP3` directly without a `Nonlinearity` selector. Do not confuse the two APIs.

----

Copyright 2026 The MathWorks, Inc.

----
