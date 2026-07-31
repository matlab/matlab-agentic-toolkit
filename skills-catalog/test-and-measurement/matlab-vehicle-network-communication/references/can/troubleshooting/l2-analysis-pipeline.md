# L2 Data Link Analysis Pipeline

Traffic analysis orchestration for Phase 2. Run modules sequentially, then synthesize findings.

---

## Entry Conditions

- Phase 0 showed healthy bus but customer still has issues
- L1 checks passed but symptoms remain
- Customer already has a `rawMsgs` timetable in the workspace (from any source)

---

### L2-1: Acquire Traffic Data

**If the user states they have a `rawMsgs` timetable in the workspace** (or you confirmed it exists via Phase 0 capture):
→ Do NOT load, import, or re-read data. Skip directly to L2-2.

**If channel is already connected (from Phase 0) — capture live:**

> How long should I capture traffic?
>
> 1. Quick check (10 seconds)
> 2. Standard (30 seconds)
> 3. Extended — intermittent issue (60+ seconds)

```matlab
receive(canCh, Inf);  % flush buffer
fprintf("Capturing for %d seconds...\n", duration);
pause(duration);
rawMsgs = receive(canCh, Inf, "OutputFormat", "timetable");
fprintf("Captured %d messages\n", height(rawMsgs));
```

**If no channel and no timetable:** Ask the user to either connect hardware (back to Phase 0) or load their data using the data import/export skill.

### L2-2: Run Analysis Modules

Run functions in this order. All require `rawMsgs` in the MATLAB workspace.

| Order | Function Call | Condition |
|-------|-------------|-----------|
| 1 | `canTrafficOverview(rawMsgs)` | Always |
| 2 | `canCycleTimeAnalysis(rawMsgs)` | Always |
| 3 | `canBusLoadCalc(rawMsgs, busSpeedBps)` | Always |
| 4 | `canBurstDetection(rawMsgs, busSpeedBps)` | If starvation or timing violations detected |

**Bus speed:** If no live channel exists (pre-loaded data), ask the customer for bus speed:

> What bus speed was this capture taken at?
>
> 1. 125 kbit/s
> 2. 250 kbit/s
> 3. 500 kbit/s
> 4. 1 Mbit/s
> 5. Other: ___

Pass `busSpeedBps` as the second argument to Modules 3 and 4 (defaults to 500000 if omitted).

**Filter reset** (if FilterHistory = "Block All"):

```matlab
stop(canCh);
filterAllowAll(canCh, 'Standard');
filterAllowAll(canCh, 'Extended');
start(canCh);
```

**Extended capture** (spanning a fault event the customer can reproduce):

```matlab
receive(canCh, Inf);  % flush
fprintf("Monitoring... reproduce the fault now.\n");
pause(duration);  % set duration based on reproduction time + margin
rawMsgs = receive(canCh, Inf, "OutputFormat", "timetable");
fprintf("Captured %d messages over %.1f seconds\n", height(rawMsgs), ...
    seconds(rawMsgs.Time(end) - rawMsgs.Time(1)));
```

---

### L2-3: Synthesize and Route

After modules complete, match findings to this table:

| Pattern | Root Cause | Recommendation |
|---------|-----------|----------------|
| One ID high jitter + drops, others healthy, bus load normal | Transmitter-side fault (scheduling, buffer overflow, task priority) | Investigate that ECU's firmware — TX task, buffer depth, watchdog |
| All low-priority IDs high jitter, high-priority fine | Arbitration starvation from bus overload | Reduce bus load: lower rates, split bus, or prioritize critical messages |
| All IDs high jitter equally | Shared physical issue bleeding into timing | Re-check L1 (intermittent termination/ground) |
| Drops correlate with temporal bursts | Burst traffic source starving others | Identify burst source in Module 3b windows; throttle or schedule it |
| High bus load (>70%) + starvation | Bus capacity exceeded | Bus segmentation, gateway, or rate reduction required |
| Event-driven ID has high jitter but 0 drops | Normal behavior for on-change messages | Not a fault — document expected behavior |

---

## Combined Report Template

```
============================================
   CAN NETWORK DIAGNOSTIC REPORT
============================================

L1 Physical Layer:
  Bus Status: ___
  Error Counters: TEC=___ REC=___
  Termination: [OK / Issue]
  Ground: [OK / Issue]
  Bit Timing: [OK / Issue]
  Assessment: [GREEN / YELLOW / RED]

L2 Data Link:
  Duration: ___ seconds
  Messages: ___
  Bus Load: ___% [LIGHT / NORMAL / HEAVY / CRITICAL]

  Cycle Time Health:
    Worst ID: 0x___ (jitter: ___%)
    Timeouts: ___

  Arbitration: [HEALTHY / STARVATION on IDs: ___]

============================================
OVERALL: [GREEN / YELLOW / RED]
ROOT CAUSE: ___
RECOMMENDED ACTIONS:
  1. ___
  2. ___
============================================
```

---

## After the Report

> Would you like to:
>
> 1. Dig deeper into a specific finding
> 2. Re-run analysis after making changes (longer capture, different config)
> 3. That answers my question — I'll take action on the recommendations

----

Copyright 2026 The MathWorks, Inc.

----
