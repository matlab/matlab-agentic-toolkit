# L1 Diagnostic Branches

Physical layer diagnostic question trees. Referenced from SKILL.md Phase 1 routing.

## Contents
- Branch: Termination (L1-TERM-1 through L1-TERM-3)
- Branch: Voltage (L1-VOLT-1 through L1-VOLT-2)
- Branch: Ground (L1-GND-1 through L1-GND-3)
- Branch: Waveform (L1-WAVE-1 through L1-WAVE-2)
- Branch: Bit Timing (L1-BIT-1 through L1-BIT-4)
- Branch: CAN FD (L1-FD-1 through L1-FD-2)

---

## Branch: Termination

### L1-TERM-1: Measure Bus Resistance

> Can you measure resistance between CAN_H and CAN_L with all power OFF?
>
> 1. ~60 ohms
> 2. ~120 ohms
> 3. Greater than 200 ohms (or open)
> 4. Less than 50 ohms
> 5. I don't have a multimeter available
> 6. Other value: ___

| Answer | Diagnosis | Next |
|--------|-----------|------|
| 1 (~60) | Correct — two 120-ohm terminators. | If new tool/node was added -> Branch: Bit Timing (verify bus speed match). Otherwise -> Branch: Voltage |
| 2 (~120) | Missing one termination resistor. | -> L1-TERM-2 |
| 3 (>200) | Both terminations missing or open wire. | -> L1-TERM-2 |
| 4 (<50) | Over-terminated — extra resistor. | -> L1-TERM-3 |
| 5 | Cannot verify. | -> L1-TERM-2, then L1-TERM-3. If new tool/node was added -> Branch: Bit Timing (verify bus speed match). Otherwise -> Branch: Voltage |
| 6 (other) | Unusual — ask for exact value. 60-80 = likely OK; 80-120 = one weak; interpret relative to 60 nominal. | -> Nearest matching row above |

### L1-TERM-1b: Connectivity Check

**Trigger:** L1-TERM-1 answer is 3 (open) or Step 0.5 diagnosed "open bus."

> Is there a powered CAN device connected at the other end of the cable?
>
> 1. Yes — device is connected and powered
> 2. No — cable is disconnected or no device at far end
> 3. Not sure — I'll check

**Routing:**
- 1 -> Both terminators missing. Add 120-ohm at both backbone ends. -> L1-TERM-2
- 2 -> **Two problems:** (a) no peer to provide ACK (CAN requires at least two nodes), AND (b) missing termination causes reflections. Fix both: connect a powered device AND add 120-ohm at both ends.
- 3 -> Ask them to verify physical connectivity, then re-assess.

### L1-TERM-2: Locate Terminators

> Where are your termination resistors physically located?
>
> 1. At both ends of the bus backbone
> 2. At one end only
> 3. On a stub/T-junction
> 4. Built into an ECU
> 5. Not sure

**Guidance:**
- 1 -> Correct placement. Resistor may be damaged.
- 2 -> Add 120-ohm at the OTHER end.
- 3 -> Move to backbone ends. Stubs cause reflections.
- 4 -> Acceptable only if that ECU is at a bus end.
- 5 -> Trace wiring to find them.

### L1-TERM-3: Identify Extra Termination

> Did you recently add a CAN tool or analyzer to the bus?
>
> 1. Yes — Vector/PEAK/Kvaser/NI interface
> 2. Yes — oscilloscope CAN decoder
> 3. Yes — another ECU/node
> 4. No — nothing new added

**Guidance:**
- 1, 2 -> Many tools have built-in 120-ohm termination. Check for additional termination added to the network (DB9 terminators on the interface or cable, vendor software settings, dip switches/jumpers).
- 3 -> Check if new ECU has internal termination.
- 4 -> A resistor may have gone low-impedance. Disconnect nodes one at a time to isolate.

---

## Branch: Voltage

### L1-VOLT-1: Idle Bus Voltage

> With the bus powered and idle, what voltage on CAN_H and CAN_L relative to ground?
>
> 1. Both at ~2.5V (within 0.5V)
> 2. CAN_H near 0V or supply (3.3V/5V)
> 3. CAN_L near 0V or supply (3.3V/5V)
> 4. Both same voltage but NOT 2.5V
> 5. Can't measure right now
> 6. Other: ___

| Answer | Diagnosis | Next |
|--------|-----------|------|
| 1 | Normal idle. | -> L1-VOLT-2 |
| 2 | Transceiver fault or shorted CAN_H. | -> Disconnect nodes one at a time to isolate |
| 3 | Transceiver fault or shorted CAN_L. | -> Disconnect nodes to isolate |
| 4 | Ground offset — common-mode shift. | -> Branch: Ground |
| 5 | Skip, note unverified. | -> Branch: Ground |

### L1-VOLT-2: Differential Amplitude

> During communication, does differential voltage (CAN_H - CAN_L) reach at least 1.5V?
>
> 1. Yes — 1.5V to 3.0V (normal)
> 2. Below 1.5V
> 3. Not sure / only have oscilloscope
> 4. Can't measure during communication

**Interpretation:**
- 1 -> Voltage OK. Continue to next relevant branch.
- 2 -> Weak drive. Causes: over-termination, too many nodes, failing transceiver.
- 3 -> Branch: Waveform
- 4 -> Note unverified, continue.

---

## Branch: Ground

### L1-GND-1: Ground Topology

> How is ground connected between your CAN nodes?
>
> 1. Dedicated ground wire in CAN cable (H, L, GND)
> 2. Shared chassis/frame ground
> 3. AC mains ground (wall outlets)
> 4. Mixed
> 5. Not sure

**Interpretation:**
- 1 -> Best practice. Unlikely issue unless wire broken. -> L1-GND-2
- 2 -> Vulnerable to ground shifts. -> L1-GND-2
- 3 -> Ground loops likely. Recommend: single power strip or galvanic isolators.
- 4 -> Inconsistent. Recommend: dedicated ground between all nodes.
- 5 -> L1-GND-2

### L1-GND-2: High-Current Interference

> High-current devices (motors, VFDs, heaters, solenoids) sharing ground with CAN nodes?
>
> 1. Yes — problems correlate with their activation
> 2. Yes — haven't checked correlation
> 3. No — CAN on isolated/clean power
> 4. Not sure

**Interpretation:**
- 1 -> Ground shift confirmed. -> L1-GND-3 for quantification.
- 2 -> Test: monitor errors while toggling loads. -> L1-GND-3
- 3 -> Ground likely clean. -> Branch: Waveform
- 4 -> Recommend testing.

### L1-GND-3: Measure Ground Shift

> Can you measure DC voltage between ground pins of two CAN nodes while system is under load?
>
> 1. Less than 0.5V
> 2. 0.5V to 2V
> 3. Greater than 2V
> 4. Can't measure right now
> 5. Other: ___

| Answer | Diagnosis | Recommendation |
|--------|-----------|----------------|
| 1 (<0.5V) | Ground is clean. Problem elsewhere. | -> Branch: Waveform |
| 2 (0.5-2V) | Borderline. May cause errors under worst-case. | Run dedicated ground wire. Monitor. |
| 3 (>2V) | **Root cause.** Ground shift exceeds transceiver tolerance. | Immediate: dedicated CAN ground wire. Long-term: galvanic isolator. |
| 4 | Unverified. | Recommend dedicated ground as preventive. |

**ISO 11898-2:** CAN transceivers tolerate common-mode -2V to +7V. Beyond this, communication fails.

---

## Branch: Waveform

### L1-WAVE-1: Oscilloscope Availability

> Do you have an oscilloscope available?
>
> 1. Yes — can probe CAN_H and CAN_L
> 2. Yes — single channel only
> 3. No oscilloscope
> 4. CAN-specific tool (Intrepid/Kvaser waveform)

**Routing:**
- 1, 2, 4 -> L1-WAVE-2
- 3 -> Skip waveform. -> Branch: Bit Timing

### L1-WAVE-2: Edge Quality

> What do you see on waveform edges?
>
> 1. Clean transitions, no ringing
> 2. Ringing/oscillation after edges
> 3. Slow, rounded edges
> 4. Asymmetric CAN_H vs CAN_L
> 5. Overshoot above 4V on CAN_H
> 6. Signal amplitude low (differential < 1.5V)
> 7. Other: ___

| Answer | Diagnosis | Recommendation |
|--------|-----------|----------------|
| 1 | Healthy | -> Branch: Bit Timing if errors persist |
| 2 | Missing/misplaced termination | Verify termination at both bus ends |
| 3 | Capacitive loading or stubs too long | Shorten stubs (500k: <1m, 1M: <0.3m) |
| 4 | Transceiver or imbalanced wiring | Check wiring symmetry |
| 5 | Termination issue at high baud | Verify 60 ohm; add series resistors |
| 6 | Over-termination or failing driver | Re-measure termination resistance |

**Stub length guidelines:**
- 1 Mbit/s: < 0.3m
- 500 kbit/s: < 1m
- 125 kbit/s: < 3m
- CAN FD data phase (2M+): ideally NO stubs

---

## Branch: Bit Timing

### L1-BIT-1: Baud Rate

> What baud rate is your CAN bus configured for?
>
> 1. 125 kbit/s
> 2. 250 kbit/s
> 3. 500 kbit/s
> 4. 1 Mbit/s
> 5. CAN FD — arb rate: ___ / data rate: ___
> 6. Other: ___

### L1-BIT-2: Sample Point

> Do you know the sample point percentage?
>
> 1. Yes: ___%
> 2. No — I can look it up
> 3. No — how do I calculate it?

**If 3:** `Sample Point % = (1 + TSEG1) / (1 + TSEG1 + TSEG2) x 100`

**Recommended sample points (CiA):**

| Baud Rate | Sample Point |
|-----------|-------------|
| 125-500 kbit/s | 87.5% |
| 1 Mbit/s | 75-80% |
| 2 Mbit/s (FD) | 70-80% |
| 5 Mbit/s (FD) | 62.5-70% |

### L1-BIT-3: Node Timing Agreement

> Are ALL nodes using the same bit timing?
>
> 1. Yes — all identical
> 2. No — some differ
> 3. Not sure — configured independently
> 4. I only control my MATLAB interface

**Interpretation:**
- 1 -> Mismatch unlikely. -> Branch: Waveform or Ground.
- 2 -> **Likely root cause.** All must match baud rate. Sample points within 5%.
- 3 -> Verify all nodes. Common root cause.
- 4 -> Ensure `canCh.BusSpeed` matches network. If user doesn't know the network rate -> run `canBaudRateScanPassive(vendor, device, chIndex)` to listen passively at standard rates. If passive returns NO_TRAFFIC_AT_ANY_RATE, escalate to `canBaudRateScanActive(vendor, device, chIndex)`.

### L1-BIT-4: Clock Source Quality

> Oscillator/clock source on your CAN nodes?
>
> 1. Crystal (+-0.01%)
> 2. Ceramic resonator (+-0.5%)
> 3. Internal RC (+-1-2%)
> 4. Not sure
> 5. Mix of types

**Red flags:**
- Ceramic/RC at 1 Mbit/s -> need larger SJW
- CAN FD data phase with non-crystal -> **will likely fail** (needs <0.1%)
- Mixed types -> SJW must accommodate worst node

**SJW check:** `Required SJW >= 2 x df x (TSEG1 + TSEG2 + 1)` where df = worst oscillator deviation

---

## Branch: CAN FD

Only if customer indicated CAN FD in L1-BIT-1 or mentions FD elsewhere, or selected Step 1.2 option 5.

### L1-FD-1: CAN FD Issue Type

> What CAN FD issue are you seeing?
>
> 1. Errors only during data phase (high-speed portion)
> 2. Classical CAN nodes generating error frames
> 3. CRC errors in longer payloads (>8 bytes)
> 4. Works at lower data rate but fails at higher
> 5. Other: ___

| Answer | Diagnosis | Recommendation |
|--------|-----------|----------------|
| 1 | Data phase timing issue | Shorten/eliminate stubs; verify data-phase sample point; reduce bus length |
| 2 | Classical nodes see FD as violation | Isolate FD segment with gateway |
| 3 | CRC errors on long payloads at high data rate | Verify stub length (no stubs at 2M+); check data-phase sample point; reduce bus length |
| 4 | Physical layer too long/lossy for data rate | Reduce bus length, eliminate stubs. See [bus-length-guidelines.md](bus-length-guidelines.md) for limits by data rate |

### L1-FD-2: Bus Topology

> What is your bus topology?
>
> 1. Point-to-point (two nodes, short cable)
> 2. Multi-node with stubs/T-junctions
> 3. Multi-node, all directly on backbone (no stubs)
> 4. Not sure

**Guidance:**
- 1 -> Stubs unlikely. Verify data-phase sample point.
- 2 -> **Likely root cause.** At 2M+ data rates, stubs must be eliminated entirely. Even short stubs (>5cm) cause reflections during the fast data phase. Also verify total bus length is within data-phase limits (stubs are the priority fix, but both contribute).
- 3 -> Check total bus length against [bus-length-guidelines.md](bus-length-guidelines.md). At 2M data rate, max is ~10-20 m theoretical — design for well below that.
- 4 -> Ask user to trace wiring. Any T-junction or tap is a stub.

**Note:** Modern CAN/CAN FD implementations assume a crystal-accurate time base (direct or indirect), as internal RC oscillators generally do not meet CAN FD timing and jitter requirements.

----

Copyright 2026 The MathWorks, Inc.

----
