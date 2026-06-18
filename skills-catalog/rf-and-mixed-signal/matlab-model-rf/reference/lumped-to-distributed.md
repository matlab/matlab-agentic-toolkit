# Lumped-to-Distributed Design (Richards, Kuroda, Realize)

Convert lumped L/C circuits to distributed transmission-line implementations.

## Richards Transformation

Convert inductors and capacitors to `txlineElectricalLength` stubs:

```matlab
% On an entire circuit
ckt = circuit('LPF');
add(ckt, [1 2], inductor(10e-9, 'L1'));
add(ckt, [2 0], capacitor(5e-12, 'C1'));
add(ckt, [2 3], inductor(15e-9, 'L2'));
setports(ckt, [1 0], [3 0]);
cktDist = richards(ckt, 2.4e9);     % All L/C -> stubs at 2.4 GHz

% On a single element
[txStub, nodes] = richards(inductor(10e-9, 'L1'), 2.4e9);
```

Also works on `lcladder`, `rffilter`, and `matchingnetwork` objects:
```matlab
cktDist = richards(rffilter('ResponseType','Lowpass','FilterOrder',3,'PassbandFrequency',1e9), 1e9);
```

Inductors become short-terminated stubs; capacitors become open-terminated stubs. Element names get a `_tx` suffix.

## Kuroda Transformation

Rearrange `txlineElectricalLength` elements using Kuroda identities to convert between series and shunt stubs:

```matlab
cktOut = kuroda(cktIn, 'TX1', 'TX2');        % 2-element Kuroda identity
cktOut = kuroda(cktIn, 'TX1', 'TX2', 'TX3'); % 3-element identity
```

Elements can be specified by name, handle, or index. Applies to `txlineElectricalLength` pairs only.

## Insert Unit Element

Insert a quarter-wave transmission line (unit element) at a specified port of an element:

```matlab
cktOut = insertUnitElement(cktIn, 'TL1', 1, 2.4e9, 50);
% Args: (circuit, element, port, opFreq, Z0)
```

## Realize as Physical Transmission Lines

Convert `txlineElectricalLength` stubs to physical microstrip (or other) lines:

```matlab
msTemplate = txlineMicrostrip;
msTemplate.Height = 0.8e-3;
msTemplate.EpsilonR = 4.4;
cktReal = realize(cktDist, msTemplate);
```

**Gotcha:** `realize` requires compatible physical dimensions -- the width/height ratio must be between 0.05 and 20. Adjust the template properties or the stub impedances if this constraint is violated.

## `txlineElectricalLength` -- Ideal Transmission Line

Used as the output of Richards transformation. Defined by electrical length rather than physical dimensions:

```matlab
tx = txlineElectricalLength('Name', 'Stub1', 'Z0', 75, ...
    'LineLength', pi/4, 'ReferenceFrequency', 2.4e9, ...
    'StubMode', 'Series', 'Termination', 'Short');
```

| Property | Description |
|----------|-------------|
| `Z0` | Characteristic impedance (Ohm) |
| `LineLength` | Electrical length (radians) |
| `ReferenceFrequency` | Frequency at which LineLength applies (Hz) |
| `StubMode` | `'NotAStub'`, `'Series'`, or `'Shunt'` |
| `Termination` | `'NotApplicable'`, `'Short'`, or `'Open'` |

----

Copyright 2026 The MathWorks, Inc.

----
