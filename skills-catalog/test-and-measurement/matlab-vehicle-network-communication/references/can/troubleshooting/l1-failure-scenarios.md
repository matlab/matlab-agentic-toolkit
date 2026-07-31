# L1 Failure Scenarios

Pattern-matching table for rapid diagnosis. Use when Phase 1 routing is ambiguous or to confirm a suspected root cause.

---

## Symptom -> Domain Mapping

| Observed Symptom | Primary Domain | Secondary | Key Question |
|-----------------|---------------|-----------|--------------|
| 40-ohm termination (measured) | Termination | — | "Did you add a tool recently?" (built-in 120-ohm) |
| Works on bench, fails in vehicle | Ground | Waveform | "How are grounds connected?" (chassis ground shift) |
| Errors when motor/VFD/heater starts | Ground | — | "Measure ground potential between nodes under load" |
| One node can't join, all others fine | Bit Timing | Termination | "Does that node use the same baud rate?" |
| Added analyzer, now failing | Termination | — | "Does analyzer have built-in termination? (DIP switch)" |
| Intermittent CRC, temperature-correlated | Waveform | Bit Timing | "Crystal or ceramic resonator?" (thermal drift) |
| TEC climbs on one node only | Voltage | Waveform | "Check that node's TX path: transceiver, stub, connector" |
| REC climbs on ALL nodes | Termination | Ground | "Shared physical issue — backbone termination or ground" |
| BusOff immediately on start | Bit Timing | Termination | "Verify baud matches network; check for open bus" |
| Errors only at high bus load | Bit Timing | Ground | "Sample point mismatch visible under arbitration stress" |
| Works at 250k, fails at 500k | Waveform | Termination | "Stubs too long for higher rate; check cable quality" |
| Errors after moving system | Ground | Waveform | "New ground path; check cable integrity" |
| Garbage frames (high count, corrupted) | Bit Timing | — | "Baud mismatch — receiver decoding noise as frames" |
| FD errors only | CAN FD | — | "Does the nodes on the network support CAN FD or just classic CAN?" |
| FD data-phase errors only | CAN FD | — | "Stubs eliminated? Bus length within data-phase limits? Sample point configured?" |
| Errors correlate with specific message IDs | Bit Timing | — | "Not physical — data-dependent stuff patterns" |

---

## Scenario Playbooks

### New Setup: Complete Silence
**Check order:** Termination -> Bit Timing -> Voltage
1. Measure 60 ohms between H and L (power off)
2. Confirm all nodes configured to same baud
3. Verify CAN_H and CAN_L idle at ~2.5V

### Was Working: Sudden Complete Failure
**Check order:** Termination -> Bit Timing -> Voltage
1. "What changed?" — any new device, cable, or firmware update
2. If device added: check for extra termination
3. If firmware updated: verify baud rate wasn't altered
4. If nothing changed: check for broken wire or connector (resistance test)

### Intermittent: Correlates with Environment
**Check order:** Ground -> Waveform -> Bit Timing
1. Identify correlation (load activation, temperature, time of day)
2. Measure ground potential under worst-case conditions
3. If ground clean: oscilloscope waveform during fault event
4. If waveform clean: check SJW vs oscillator quality

### Rising Error Counters: Gradual Degradation
**Check order:** Varies by pattern (see Error Counter Interpretation in SKILL.md)
- TEC on one node -> that node's TX path
- REC on one node -> that node's RX (ground at that node)
- REC on all -> shared backbone issue
- Both climbing -> severe local fault

### CAN FD Specific
**Check order:** CAN FD -> Bit Timing -> Waveform
1. Stubs eliminated for data-phase rate? (See bus-length-guidelines.md)
2. Bus length within data-phase limits?
3. Any classical nodes on the same segment?
4. Data-phase sample point configured correctly?

----

Copyright 2026 The MathWorks, Inc.

----
