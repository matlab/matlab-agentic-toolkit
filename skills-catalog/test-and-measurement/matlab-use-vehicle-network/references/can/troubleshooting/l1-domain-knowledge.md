# L1 Domain Knowledge

Physical layer theory for CAN/CAN FD networks. Read this when you need to explain WHY a problem occurs or interpret unusual measurements.

---

## Termination

**Nominal:** Two 120-ohm resistors at each end of the bus backbone = 60 ohms measured end-to-end.

**Why termination matters:** CAN uses differential signaling at speeds where the bus behaves as a transmission line. Without matched termination at both ends, signal reflections corrupt bit edges. The ISO 11898-2 standard specifies 120 ohms at each end.

**Reflection physics:** A signal reaching an unterminated end reflects back with the same polarity. At high baud rates (500k+), the reflected wave arrives during the same bit period and distorts the voltage level. This causes bit errors, especially for nodes in the middle of the bus.

**Stub effects:** A stub (T-junction tap off the backbone) creates an impedance discontinuity. The stub acts as an antenna that reflects energy back onto the bus. Longer stubs = worse reflections. At CAN FD data rates (2M+), even short stubs (>5cm) can cause errors.

**Over-termination (< 50 ohms):** Extra terminators (common when tools have built-in 120-ohm resistors) reduce differential voltage below receiver threshold. Symptoms: weak signal, intermittent reception failures, especially at bus extremities.

**Under-termination (> 120 ohms):** Missing or damaged terminator causes ringing. Symptoms: errors at higher baud rates, CRC failures on longer messages, errors correlating with specific bit patterns (more transitions = more reflections).

---

## Ground

**ISO 11898-2 common-mode range:** CAN transceivers tolerate -2V to +7V common-mode voltage between local ground and bus signal. Beyond this range, the differential receiver cannot distinguish dominant from recessive.

**Ground loops:** When nodes share ground through multiple paths (chassis + dedicated wire + AC mains), circulating currents create voltage differences between node grounds. These shift the common-mode voltage and can exceed transceiver tolerance.

**Ground shift from high-current loads:** Motors, VFDs, heaters, and solenoids draw large currents that cause voltage drops across shared ground paths. A 10A motor on a 0.1-ohm ground path creates a 1V shift — within tolerance but eating margin. Multiple loads can exceed the -2V/+7V window.

**Galvanic isolation:** Optically or magnetically isolated CAN transceivers (e.g., ISO1050) break ground loops entirely. The transceiver has its own isolated power domain. Use when ground shifts exceed 2V or cannot be eliminated.

**Dedicated CAN ground wire:** Running a separate ground conductor in the CAN cable (H, L, GND) provides a low-impedance reference between all nodes. This is the primary mitigation for ground shift problems.

---

## Bit Timing

**Sample point:** The position within each bit period where the receiver samples the bus state. Expressed as percentage of total bit time. Earlier sample points give more margin for late edges; later sample points give more margin for early edges.

**Formula:** `Sample Point % = (1 + TSEG1) / (1 + TSEG1 + TSEG2) x 100`

Where:
- Sync segment = 1 TQ (always)
- TSEG1 = propagation + phase buffer 1 (determines sample point)
- TSEG2 = phase buffer 2 (after sample point)

**SJW (Synchronization Jump Width):** How many time quanta the sample point can shift per bit to resynchronize. Larger SJW compensates for worse oscillators but reduces noise margin.

**Oscillator tolerance requirements:**
- 500 kbit/s with SJW=1: needs +-0.5% oscillator (crystal or good ceramic)
- 1 Mbit/s with SJW=1: needs +-0.1% (crystal only)
- CAN FD data phase: needs +-0.05% (high-quality crystal)

**Baud rate mismatch:** The #1 cause of immediate BusOff on a new setup. Even 1 kbit/s difference means bits drift and corrupt frames. All nodes MUST use the same baud rate.

---

## CAN FD

**Dual bit rates:** CAN FD uses a slower arbitration phase (backward-compatible with CAN 2.0) and a faster data phase. The BRS (Bit Rate Switch) flag toggles between them within a single frame. 

**TDC (Transmitter Delay Compensation):** At high data rates (2M+), the transceiver's internal loop delay (TX -> bus -> RX path) is a significant fraction of one bit. TDC compensates for this delay internally within the transceiver hardware — it is not a user-configurable setting in VNT. TDC compensates local loop delay only; it does not fix cable propagation or stub reflection problems.

**Clock accuracy:** Modern CAN/CAN FD implementations assume a crystal-accurate time base (direct or indirect), as internal RC oscillators generally do not meet CAN FD timing and jitter requirements.

**Classical node coexistence:** A CAN 2.0 node sees CAN FD frames as protocol violations (reserved bit used) and generates error frames. Solution: isolate FD-capable segments with a gateway/bridge that translates between CAN 2.0 and CAN FD.

**Interoperabilty:** A CAN FD transceiver may received classic CAN frames, but most CAN transceivers will error when seeing CAN FD data. Best practice not to mix networks types, but this may be seen as systems are upgraded. Some CAN transcievers are FD-tolerant and will ignore frames using the FD bit and not throw and error frame. In this special case the frame will not be ACK'ed by a the classic CAN device either. 

---

## Waveform

**What clean edges look like:** Sharp transitions (rise/fall < 1/10 of bit time), flat dominant/recessive levels, no ringing, differential amplitude 1.5-3.0V during dominant.

**Ringing after edges:** Caused by impedance mismatches (missing termination, stubs, connector discontinuities). The ringing frequency and amplitude indicate the distance to the mismatch.

**Slow/rounded edges:** Capacitive loading from too many nodes, long stubs, or cable capacitance exceeding spec. The signal takes too long to cross the receiver threshold, reducing timing margin.

**Asymmetry (CAN_H vs CAN_L):** Indicates a wiring imbalance (one line has more resistance or inductance than the other) or a failing transceiver with asymmetric drive strength.

**Overshoot above 4V:** At high baud rates with incorrect termination, inductive ringing can push CAN_H above the transceiver's absolute maximum rating. This can damage transceivers over time.

**Stub and bus length constraints:** See [bus-length-guidelines.md](bus-length-guidelines.md) for the full constraint table. Key point: stub reflections typically dominate before trunk propagation delay becomes the limiting factor, especially at CAN FD data rates. However, total bus length is also constrained at high data rates (~10-20 m max at 2 Mbit/s) and should always be verified as a secondary factor alongside stubs. Reducing either stub length or total bus length gives more margin for reflections and propagation delay to settle, which in turn relaxes sample point selection and bit timing constraints.

----

Copyright 2026 The MathWorks, Inc.

----
