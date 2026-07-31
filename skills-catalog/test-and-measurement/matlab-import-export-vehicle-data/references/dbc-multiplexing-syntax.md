# DBC File Multiplexing Syntax

How to identify multiplexing type by reading a DBC file as text.

## Signal Definition Markers

In a `SG_` line, the multiplexing marker appears after the signal name:

| Marker | Meaning | Example |
|--------|---------|---------|
| `M` | Multiplexor signal (the selector) | `SG_ OBD2Mode M : 16\|7@1+ ...` |
| `m<N>` | Multiplexed signal (active when muxor == N) | `SG_ Vehicle_Speed m13 : 6\|8@1+ ...` |
| `m<N>M` | Signal is both multiplexed AND a multiplexor (nested) | `SG_ S1 m0M : 8\|8@1+ ...` |
| (none) | Regular signal, always present | `SG_ Temperature_regular : 24\|8@1+ ...` |

## Detecting Extended/Hierarchical Multiplexing

A message uses **extended multiplexing** if ANY of these conditions are true:

1. **`SG_MUL_VAL_` section exists** at the end of the file with entries referencing signals in that message:
   ```
   SG_MUL_VAL_ 16 S6 S0 2-2;
   SG_MUL_VAL_ 16 S1 S0 0-0, 1-1;
   ```
   The format is: `SG_MUL_VAL_ <msgID> <muxedSignal> <muxorSignal> <range1>[, <range2>...];`
   Value ranges (`N-M`) instead of scalar values indicate extended multiplexing. 
   
2. **A signal has the `m<N>M` marker** — it is both multiplexed by a parent AND acts as a multiplexor for children (nested hierarchy).

3. **Multiple `M`-marked signals exist** in the same message (multiple independent multiplexors at the same level).

## Detecting Simple Multiplexing

A message uses **simple multiplexing** if:
- Exactly one signal has the `M` marker (the multiplexor)
- One or more signals have `m<N>` markers (the multiplexed signals)
- NO signal has the `m<N>M` combined marker
- NO `SG_MUL_VAL_` entries reference that message's signals

## Example: Simple Multiplexing (OBD2_Message)

```
BO_ 55 OBD2_Message: 5 Vector__XXX
 SG_ Temperature_regular : 24|8@1- (1,0) [0|0] "" Vector__XXX
 SG_ Vehicle_Speed m13 : 6|8@1+ (1,0) [0|255] "km/h" Vector__XXX
 SG_ Accelerator m73 : 2|8@1+ (0.392156862745098,0) [0|100] "" Vector__XXX
 SG_ OBD2Mode M : 16|7@1+ (1,0) [0|127] "" Vector__XXX
 SG_ Engine_Torque m98 : 0|8@1+ (1,-125) [-125|130] "rpm" Vector__XXX
```

- `OBD2Mode` is the sole multiplexor (`M`)
- `Vehicle_Speed`, `Accelerator`, `Engine_Torque` are multiplexed (`m13`, `m73`, `m98`)
- `Temperature_regular` is a regular signal (no marker)

## Example: Extended/Hierarchical Multiplexing

```
BO_ 1718 PowerTrainTires: 4 Vector__XXX
 SG_ FailureFlagRear m2 : 18|1@1+ (1,0) [0|0] "" Vector__XXX
 SG_ FailureFlagFront m0 : 18|1@1+ (1,0) [0|0] "" Vector__XXX
 SG_ PressureRR m1 : 24|8@1+ (1,0) [0|0] "" Vector__XXX
 SG_ PressureRL m1 : 24|8@1+ (1,0) [0|0] "" Vector__XXX
 SG_ PressureFR m1 : 24|8@1+ (1,0) [0|0] "" Vector__XXX
 SG_ PressureFL m1 : 24|8@1+ (1,0) [0|0] "" Vector__XXX
 SG_ TemperatureRR m1 : 19|5@1+ (1,0) [0|0] "" Vector__XXX
 SG_ TemperatureRL m1 : 19|5@1+ (1,0) [0|0] "" Vector__XXX
 SG_ TemperatureFR m1 : 19|5@1+ (1,0) [0|0] "" Vector__XXX
 SG_ TemperatureFL m1 : 19|5@1+ (1,0) [0|0] "" Vector__XXX
 SG_ WheelSpeedRR m0 : 19|13@1- (1,0) [0|0] "" Vector__XXX
 SG_ WheelSpeedRL m0 : 19|13@1- (1,0) [0|0] "" Vector__XXX
 SG_ WheelSpeedFR m0 : 19|13@1- (1,0) [0|0] "" Vector__XXX
 SG_ WheelSpeedFL m0 : 19|13@1- (1,0) [0|0] "" Vector__XXX
 SG_ DataRR m3M : 16|2@1+ (1,0) [0|0] "" Vector__XXX
 SG_ DataRL m2M : 16|2@1+ (1,0) [0|0] "" Vector__XXX
 SG_ DataFR m1M : 16|2@1+ (1,0) [0|0] "" Vector__XXX
 SG_ DataFL m0M : 16|2@1+ (1,0) [0|0] "" Vector__XXX
 SG_ VehicleSpeed m13 : 8|8@1- (1,0) [0|0] "" Vector__XXX
 SG_ EngineTorque m48 : 8|8@1- (1,0) [0|0] "" Vector__XXX
 SG_ AcceleratorPedal m23 : 8|8@1+ (1,0) [0|0] "" Vector__XXX
 SG_ TireMux M : 6|2@1+ (1,0) [0|0] "" Vector__XXX
 SG_ PowerTrainMux M : 0|6@1+ (1,0) [0|0] "" Vector__XXX

SG_MUL_VAL_ 1718 FailureFlagRear TireMux 2-2, 3-3;
SG_MUL_VAL_ 1718 FailureFlagFront TireMux 0-0, 1-1;
SG_MUL_VAL_ 1718 PressureRR DataRR 1-1;
SG_MUL_VAL_ 1718 PressureRL DataRL 1-1;
SG_MUL_VAL_ 1718 PressureFR DataFR 1-1;
SG_MUL_VAL_ 1718 PressureFL DataFL 1-1;
SG_MUL_VAL_ 1718 TemperatureRR DataRR 1-1;
SG_MUL_VAL_ 1718 TemperatureRL DataRL 1-1;
SG_MUL_VAL_ 1718 TemperatureFR DataFR 1-1;
SG_MUL_VAL_ 1718 TemperatureFL DataFL 1-1;
SG_MUL_VAL_ 1718 WheelSpeedRR DataRR 0-0;
SG_MUL_VAL_ 1718 WheelSpeedRL DataRL 0-0;
SG_MUL_VAL_ 1718 WheelSpeedFR DataFR 0-0;
SG_MUL_VAL_ 1718 WheelSpeedFL DataFL 0-0;
SG_MUL_VAL_ 1718 DataRR TireMux 3-3;
SG_MUL_VAL_ 1718 DataRL TireMux 2-2;
SG_MUL_VAL_ 1718 DataFR TireMux 1-1;
SG_MUL_VAL_ 1718 DataFL TireMux 0-0;
SG_MUL_VAL_ 1718 VehicleSpeed PowerTrainMux 13-13;
SG_MUL_VAL_ 1718 EngineTorque PowerTrainMux 48-48;
SG_MUL_VAL_ 1718 AcceleratorPedal PowerTrainMux 23-23;
```

Extended indicators:
- `TireMux` and `PowerTrainMux` — both are multiplexors (`M`) at the same hierarchical level
- `SG_MUL_VAL_` section defines hierarchical parent-child relationships
- `TireMux 2-2, 3-3;` and `TireMux 0-0, 1-1;` define non-scalar ranges of multiplexor values
- `m0M`, `m1M`, `m2M`, `m3M` indicate that `DataFL`,  `DataFR`, `DataRL`,  `DataRR` are both multiplexors and multiplexed

----

Copyright 2026 The MathWorks, Inc.

----
