# CAN / CAN FD Bus Length and Stub Constraints

Physical layer constraints for trunk length and stub length, organized for diagnostic reasoning. ISO 11898 does not define a bus-length table — all values are derived from bit timing, propagation delay, and transceiver characteristics.

## Normative Anchor Points (Spec-Grounded)

| Constraint | Value | Condition | Source |
|------------|-------|-----------|--------|
| Max bus length | ~40 m | 1 Mbit/s | ISO 11898-2 (propagation delay constraint) |
| Max stub length | ~0.3 m | 1 Mbit/s | ISO 11898-2 physical layer guidance |
| Scaling rule | Lower bit rate = longer cable | All speeds | ISO timing model (no fixed table) |
| Stub constraint | Stub length << trunk length | Always | Transmission line behavior (ISO-derived) |

## Assumptions

- ISO 11898-2 physical layer
- ~5 ns/m cable propagation delay
- Automotive-grade transceivers
- Sample point 80-87.5%
- Crystal-accurate clock source (direct or indirect)

## Unified Constraint Table (Trunk + Stub + Phase)

| Protocol / Phase | Bit Rate | Max Bus Length | Max Stub Length | Confidence |
|------------------|----------|---------------|-----------------|------------|
| CAN / FD Arb | 1 Mbit/s | ~40 m | ~0.3 m | High (ISO anchor) |
| CAN / FD Arb | 500 kbit/s | ~100 m | ~0.5-1 m | Medium (derived) |
| CAN / FD Arb | 250 kbit/s | ~250 m | ~1-2 m | Medium (derived) |
| CAN / FD Arb | 125 kbit/s | ~500 m | ~2-5 m | Medium (derived) |
| CAN FD Data | 8 Mbit/s | ~1-2 m | ~0.05-0.1 m | Low-medium (OEM/vendor) |
| CAN FD Data | 5 Mbit/s | ~2-5 m | ~0.1-0.2 m | Low-medium (OEM/vendor) |
| CAN FD Data | 2 Mbit/s | ~10-20 m | ~0.3-0.5 m | Medium (derived) |

## Core Constraints

**Trunk length:**
```
Round-trip propagation delay < sample point time
L_bus < (t_bit * 0.7) / (2 * 5 ns/m)
```

**Stub length:**
```
Reflection from stub must settle before sampling
L_stub << L_bus (typically 1-5% of trunk at high speed)
```

## Behavioral Rules

### Stub length is more restrictive than trunk length

Stubs create impedance discontinuities that reflect energy back onto the bus. In practice, networks fail due to stub reflections before trunk propagation delay becomes the limiting factor. This is especially true for automotive harnesses (SAE J1939) and distributed node topologies.

### CAN FD: arbitration vs data phase

- Arbitration phase follows Classical CAN rules (same constraints)
- Data phase is much stricter — shorter bit time, higher edge rate, stronger reflections
- CAN FD makes stub constraints an order of magnitude tighter than Classical CAN

### TDC does not fix stub or propagation problems

TDC (Transmitter Delay Compensation) is handled internally by transceiver hardware. It compensates the transceiver's internal loop delay only. It does not compensate cable propagation delay or reflections from stubs.

### Design margin

Stay well below theoretical maximums. Real installations have connectors, splices, temperature drift, and EMI that consume timing margin. Design for 50-70% of the theoretical maximum.

## Diagnostic Reasoning Priority

When diagnosing CAN FD data-phase errors:

1. Check stub length first (most common constraint violation)
2. Then check total propagation delay (bus length)
3. Verify data-phase sample point configuration
4. Confirm high-accuracy clock source on all nodes

## SAE J1939 Context

J1939 networks (typically 250 kbit/s) effectively enforce:
- Stub length: 1 m maximum
- Backbone: 40 m segment maximum

If J1939 context is identified, prioritize stub constraint over trunk length.

----

Copyright 2026 The MathWorks, Inc.

----
