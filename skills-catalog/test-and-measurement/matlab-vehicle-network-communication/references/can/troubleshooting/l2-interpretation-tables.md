# L2 Interpretation Tables

Thresholds and assessment criteria for interpreting L2 analysis script output.

---

## Cycle Time / Jitter Assessment

**Before flagging high jitter**, determine: is this message periodic or event-driven? Event-driven messages (transmit on change only) naturally have high jitter — that's expected, not a fault.

**Virtual channel note:** If data was captured on MathWorks Virtual channels, baseline jitter of 8-10% is normal OS scheduling overhead. Only flag jitter >15% as concerning for Virtual channels. Software-timed transmitters (MATLAB pause loops) can produce even higher jitter — this is a transmitter limitation, not a bus problem.

### Jitter Thresholds (Periodic Messages Only)

| Jitter | Assessment |
|--------|-----------|
| <10% | Healthy |
| 10-20% | Moderate — acceptable under load |
| >20% | Problem — overload, scheduling, or starvation |

### Cycle Time Symptoms

| Symptom | Meaning |
|---------|---------|
| Timeouts (>3x mean) | Source went offline or severe arbitration loss |
| Mean ~2x expected | Transmitter at half rate (task/scheduling issue) |
| Gradually drifting | Clock source issue on transmitter |

---

## Bus Load Assessment

**Note:** Module 3 uses classic CAN frame overhead. For CAN FD, the result is an approximation — still directionally useful for health assessment.

| Bus Load | Assessment |
|----------|-----------|
| <30% | Light |
| 30-50% | Normal |
| 50-70% | Heavy — low-priority jitter expected |
| 70-85% | Critical — starvation likely |
| >85% | Overloaded — bus segmentation needed |

---

## Arbitration Starvation Criteria

Starvation is detected when:
- Low-priority ID jitter > 3x high-priority ID jitter
- AND low-priority jitter > 20%

This means low-priority messages are consistently losing arbitration and being delayed.

----

Copyright 2026 The MathWorks, Inc.

----
