# Custom Bends and Traces (R2025a)

## pcbBendCustom

Creates a custom PCB bend structure for bend discontinuity analysis.

```matlab
b = pcbBendCustom;
b.BendShape = bendRightAngle;    % Default bend shape
b.Height = 1.6e-3;
b.GroundPlaneWidth = 20e-3;
b.Conductor = metal("Copper");
b.Substrate = dielectric("FR4");
show(b);
```

**Key Properties:** `BendShape` (default: `bendRightAngle`), `Height`, `GroundPlaneWidth`, `GroundPlaneLength`, `Conductor`, `Substrate`

## pcbTraceCustom

Creates a custom PCB trace structure for trace discontinuity analysis (e.g., step impedance transitions).

```matlab
t = pcbTraceCustom;
t.TraceShape = traceStep;        % Default trace shape
t.Height = 1.6e-3;
t.GroundPlaneWidth = 20e-3;
t.Conductor = metal("Copper");
t.Substrate = dielectric("FR4");
show(t);
```

**Key Properties:** `TraceShape` (default: `traceStep`), `Height`, `GroundPlaneWidth`, `Conductor`, `Substrate`

----

Copyright 2026 The MathWorks, Inc.
