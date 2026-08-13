# CAN Network Diagnostic Workflow

Diagnoses CAN/CAN FD network health across physical (L1) and data link (L2) layers. Automates what MATLAB can observe, then guides manual investigation for what it cannot.

**Announce at start:** "Using CAN Diagnostics — I'll check your hardware and network health."

## Interaction Rules

- **Route on what's given.** If the user already provided diagnostic data, skip to the relevant phase — don't re-ask what they told you. See Entry-Point Routing below.
- **Automation first.** Use MCP (`mcp__matlab__evaluate_matlab_code`) to run diagnostics directly. Only provide code snippets if MCP is unavailable or customer declines.
- **One question at a time.** Don't ask multiple branching questions in a single response. Present ONE question with numbered options (1, 2, 3...) and a final "Other" option. But DO provide the diagnosis and recommended action path alongside the question.
- **Don't ask what you can measure.** If the channel is live, read BusStatus/TEC/REC directly.
- **Stop when the root cause is found.** If L1 explains the problem, don't proceed to L2.
- **L2 only if symptoms remain** after L1 checks pass or the customer confirms their issue isn't resolved.
- **Run functions, don't read them.** Execute via `mcp__matlab__evaluate_matlab_code` with `project_path` set to the skill's `scripts/can/troubleshooting/` directory — only the output enters context. See [script-interfaces.md](script-interfaces.md) for all function signatures.

## Entry-Point Routing

Before starting Phase 0, assess what the user has already told you and route accordingly:

**User gave specific diagnostic data** (BusStatus, TEC/REC values, FilterHistory, error symptoms with measurements):
→ Acknowledge what they reported, state your interpretation in one sentence, then jump directly to the relevant phase/step.

**Agent self-detects unhealthy bus state** (TEC/REC > 0, BusStatus not "ErrorActive" observed during transmit/receive — not reported by the user):
→ Stop further operations. Report the observed state and a one-sentence interpretation from Step 0.5 (e.g., "TEC=128, REC=0 indicates no other node is acknowledging"). Then present a brief plan (2-3 steps) and ask ONE targeted question to move forward. All Interaction Rules apply — do NOT list multiple possible causes or ask multiple questions.

**User mentions hardware not showing up** (canChannelList empty, device not found, hardware missing):
→ Acknowledge, then go straight to Step 0.2 (run canSupportSummary).

**User already has a traffic timetable** (from live capture, BLF import, or any source):
→ Acknowledge, then go straight to Phase 2 (traffic analysis).

**User is vague** ("CAN isn't working", "not receiving messages", "having communication problems" — no specifics):
→ Respond with:
1. A one-sentence acknowledgment of the symptom
2. A brief plan (2-3 steps, one line each): "Here's what I'll check: ..."
3. ONE question to get the first piece of info you need (hardware present? live bus? log file?)

Do NOT dump a multi-paragraph troubleshooting guide. Do NOT ask multiple questions. The plan shows you have a structured approach; the single question moves things forward.

---

## Phase 0: Automated Hardware Check

Always attempt this first. MCP tool permissions handle user consent for code execution — do not add redundant "should I check?" prompts. Proceed directly.

### Step 0.1: Discover Hardware

**Purpose:** Find what CAN hardware is connected to this machine.

**Action:** Run `canHardwareDiscovery()` — do not read the source, execute it.

**Routing:**

| Condition | Next |
|-----------|------|
| One physical device found | Auto-select it, proceed to Step 0.4 |
| Multiple physical devices found | Ask which one, then Step 0.4 |
| User selects Virtual | Treat as Virtual-only (Step 0.3, option 4) |
| No physical hardware (Virtual only) | Step 0.2 |
| ERROR | Step 0.2 |

### Step 0.2: Driver Baseline

**Purpose:** Establish what drivers and plugins are installed so we can identify what's missing.

**Action:** Run `canSupportSummary()` — do not run raw `canSupport` followed by `type('cansupport.txt')`. The function runs canSupport internally and extracts only what matters: version info, available hardware, vendor driver status, and channel creation results.

If canSupportSummary was already run (e.g., arriving from Step 0.6 loopback pass), use those results — no need to re-run unless the user has made changes.

**The summary output tells you:**
- Which vendor plugins are installed (PEAK, Vector, Kvaser, NI, Intrepid)
- Whether vendor OS-level drivers are detected (driver version present vs missing)
- Channel creation success/failure per vendor
- MATLAB and VNT version info

**Routing:** Use these results to inform Step 0.3. Do not dig into DLLs, System32 paths, or non-user-facing internals — the script already checks all of that.

### Step 0.3: Resolve Missing Hardware

**Purpose:** Determine why physical hardware isn't appearing and guide the user to fix it.

**Action:** Present the canSupportSummary findings alongside the question. The most common cause is the device is not plugged in (or not passed through — VM USB passthrough, remote desktop). After confirming connectivity, check vendor drivers.

> I ran diagnostics and here's what I found: [summarize key findings from report].
> No physical CAN hardware detected. Most common cause is the device isn't connected to this machine yet.
>
> 1. The device is plugged in via USB — I expected it to appear
> 2. Let me plug it in / check the USB connection, then retry
> 3. I'm using a VM or remote machine — USB passthrough may be the issue
> 4. I only have Virtual channels and that's intentional (simulation / software testing)
> 5. Other: ___

- If **1** -> Use canSupportSummary results to identify the specific missing driver. If it shows the vendor plugin exists but the OS driver is missing, tell the user exactly which driver to install (e.g., "PEAK Device Driver package including PCANBasic API", "Vector Driver Setup", "Kvaser CANlib"). If it shows no plugin for their vendor, the VNT support package may need installing.
- If **2** -> Wait, then re-run `canHardwareDiscovery()`. If still missing -> same as 1.
- If **3** -> Advise checking VM USB passthrough settings. Re-run after they confirm.
- If **4** -> Virtual-only is valid. Skip L1 entirely. Offer loopback self-test (Step 0.6) to verify VNT is healthy, then proceed to Phase 2 if they have traffic to analyze.
- If **5** -> Re-examine canSupportSummary output for clues.

### Step 0.4: Health Snapshot

**Purpose:** Connect to the selected hardware and get a baseline reading of bus health.

**Action:** Run `canChannelHealthCheck(vendor, device, chIndex, useFD)` — do not write custom inline code for this. Example:

```matlab
canChannelHealthCheck("Vector", "VN1610 1", 1, false)
```

It handles channel creation, bus speed display, start, 5-second listen, traffic sample, and before/after counter comparison.

**Routing:**

| Condition | Next |
|-----------|------|
| Channel creation FAILS | Step 0.6 (loopback self-test) |
| Start FAILS | Note BusOff/hardware issue, proceed to Step 0.5 |
| Success | Step 0.5 (interpret results) |

### Step 0.5: Interpret and Route

**Purpose:** Classify the health check results and route to the correct next phase.

**Action:** Match results against this table:

| Result | Meaning | Action |
|--------|---------|--------|
| BusStatus = "ErrorActive", traffic flowing | Channel healthy | If issues remain -> Phase 2. If errors on specific frame types -> Phase 1, Step 1.2. |
| BusStatus = "ErrorActive", 0 messages | Local interface OK, no traffic arriving | Check FilterHistory. If "Block All" -> fix filters. If "Allow All" -> Step 0.7. |
| BusStatus = "N/A", 0 messages, TEC=0, REC=0 | Receive-only with no traffic | If Virtual -> confirm paired endpoint transmitting. If physical -> Step 0.8. |
| BusStatus = "ErrorActive", REC <= 20, stable | Normal or residual errors | Ask: "Can you reproduce the fault while I monitor?" If yes -> longer capture. If no -> Phase 1, Step 1.2. |
| BusStatus = "N/A" | Channel idle, Virtual, or hardware doesn't expose state | Rely on traffic presence and counters. If traffic -> healthy. If 0 msgs + Virtual -> confirm paired endpoint. If 0 msgs + physical -> Step 0.8. |
| BusStatus = "ErrorPassive" | TEC or REC >= 128, physical stress or no ACK | -> Phase 1 Automated L1 Triage |
| BusStatus = "BusOff" | Severe physical or configuration problem | -> Phase 1 Automated L1 Triage |
| ErrorPassive + flood of garbage frames | Baud mismatch | -> Phase 1 Automated L1 Triage (will run baud scan) |
| TEC=128, REC=0 (transmitting) | No ACK — no other node listening | Check other nodes online at same baud. -> Branch: Bit Timing |
| TEC=0, REC=128 (transmitting) | No termination or open bus | -> Branch: Termination |
| TEC=0, REC maxed (not transmitting) | Monitor overwhelmed — over-terminated or baud-mismatched | -> Phase 1, Step 1.2 |
| TEC climbing, REC stable | This node's TX path is broken | -> Phase 1, Voltage branch |
| REC increasing, TEC stable | Receiving corrupted data | -> Phase 1, Ground branch |
| BusSpeed unexpected | Baud rate mismatch | Report mismatch. Ask what network expects. If unknown -> run `canBaudRateScanPassive(vendor, device, chIndex)`. |
| Filter = "Block All" | Vendor default or leftover config | Fix filters, then re-listen. |

### Step 0.6: Loopback Self-Test

**Purpose:** Confirm VNT itself works independently of the user's hardware.

**Action:** Run `canLoopbackSelfTest()`.

**Routing:**

| Result | Meaning | Next |
|--------|---------|------|
| PASS | VNT is healthy. Hardware/driver is the problem. | -> Step 0.2 (re-run if not already done) |
| FAIL | VNT itself is broken. | -> Recommend: check license (`ver`), restart MATLAB, reinstall VNT |

### Step 0.7: Connectivity Check

**Purpose:** Determine why no messages are arriving when filters are open.

**Action:** First, automate the channel sweep (passive — no user input needed).

If the adapter has multiple channels, listen briefly on each available channel before asking the user anything:

```matlab
% TEMPLATE — not executable
chList = canChannelList;
% Filter to same vendor/device, try each channel index
% Listen 2s per channel, report if any receives traffic
```

Report results: "I checked channels 1 and 2 — channel 2 is receiving traffic at 500 kbit/s."

**If channel sweep finds traffic:** Inform user they were on the wrong channel. Done.

**If no channel receives traffic:** Ask about remote devices:

> I checked all available channels — none are receiving traffic. This means either:
>
> 1. The other ECUs/nodes aren't powered on or transmitting
> 2. There's a baud rate mismatch (I can scan for the correct rate — CAN Classic only; for CAN FD I'll ask directly)
> 3. Both are confirmed on and at the right rate — try a transmit probe
> 4. Not sure

**Routing:**
- If **1** -> Ask them to verify power and cable connections, then retry.
- If **2** -> Run `canBaudRateScanPassive(vendor, device, chIndex)` (passive, no permission needed). **If passive scan returns NO_TRAFFIC_AT_ANY_RATE:** the remote device may be respond-only (ACKs but doesn't broadcast). Ask permission to transmit, then run `canBaudRateScanActive(vendor, device, chIndex)` which transmits at each rate and checks for ACK. Do NOT re-run the passive scan or speculate — go straight to active.
- If **3** -> Step 0.8 (diagnostic probe — requires permission to transmit).
- If **4** -> Run passive baud scan first, then escalate to active if no traffic found (same as option 2).

### Step 0.8: Diagnostic Transmit Probe

**Purpose:** Test bus connectivity by sending a single frame (requires explicit user consent).

**Action:** Ask the customer first:

> No traffic detected. I can send a single diagnostic frame to check bus connectivity. This will briefly transmit on the bus — is that OK?
>
> 1. Yes — send a test frame
> 2. No — this is a listen-only setup, don't transmit
> 3. I'm not sure if transmitting is safe

**If 1:** Run `canDiagnosticProbe(canCh)` (requires `canCh` to be a started channel in workspace).

| Result | Meaning | Action |
|--------|---------|--------|
| TEC=0 after probe | Got ACK — bus connected, other nodes present but not transmitting to us | Ask what IDs they expect. Check if other nodes need triggering. |
| TEC=128, REC=0 | No ACK — no other node acknowledged | Confirm other nodes powered and online at same baud. -> Branch: Bit Timing |
| TEC=0, REC=128 | No termination — cable disconnected or unterminated | -> Branch: Termination |

**If 2 or 3:** Cannot probe. -> Phase 1, Step 1.2 (manual investigation path).

---

## Phase 1: L1 Physical Layer Diagnosis

Enter when Phase 0 shows bus problems, error counters climbing, or customer describes physical-layer symptoms.

**For detailed branch question trees:** Read [l1-branches.md](l1-branches.md)
**For domain theory (explaining WHY):** Read [l1-domain-knowledge.md](l1-domain-knowledge.md)
**For rapid pattern matching:** Read [l1-failure-scenarios.md](l1-failure-scenarios.md)

### Step 1.1: Automated L1 Triage

**Purpose:** Run passive automated checks before asking the user any questions.

**Action:** Listen/read = do it automatically. Transmit = ask first. Run checks based on what Phase 0 already revealed:

| Phase 0 Result | Automated Action | Ask user? |
|----------------|-----------------|-----------|
| TEC=128 + REC>0 (mismatch signature) | Run `canBaudRateScanPassive(vendor, device, chIndex)` (passive). If NO_TRAFFIC_AT_ANY_RATE → ask permission, then run `canBaudRateScanActive(vendor, device, chIndex)` | Passive: No. Active: Yes (transmits) |
| 0 messages + multi-channel adapter | Try other channel indexes via health check | No — passive |
| ErrorPassive or BusOff | Re-read TEC/REC after 2s pause to determine trend | No — read-only |
| ErrorActive + 0 msgs + filters open | Already handled by Step 0.7 | — |

**CAN FD gate:** Do NOT run `canBaudRateScanPassive` for CAN FD channels AND do NOT build a custom FD rate-scanning script. Automated scanning is not viable for CAN FD because dual-rate timing requires vendor-specific multi-argument configuration that cannot be iterated generically. Instead, ask the user directly: "What arbitration and data rates does your network use? Common combinations: 500k/2M, 500k/4M, 1M/2M, 1M/5M."

Report findings from automated checks, THEN ask Step 1.2 only if the root cause isn't already clear. If automated triage identifies the problem (e.g., baud scan found the correct rate), skip the question tree and present the fix directly.

### Step 1.2: Situation

**Purpose:** Classify the failure mode to route to the correct branch.

**Action:** Ask:
>
> 1. New setup — never communicated successfully
> 2. Was working before — now failing completely
> 3. Was working before — now failing intermittently
> 4. Error counters climbing but still communicating
> 5. Errors specific to CAN FD (long frames, data phase only)
> 6. Other: ___

**Routing:**
- 1 -> Step 1.3 (new setup)
- 2 -> Step 1.4 (complete failure)
- 3 -> Step 1.5 (intermittent)
- 4 -> Step 1.6 (error counters)
- 5 -> Branch: CAN FD (L1-FD-1 directly)
- 6 -> Step 1.3

### Step 1.3: Scope (New Setup)

**Purpose:** Understand the network scale and current state to narrow the fault domain.

**Action:** Ask:
>
> 1. Two nodes (point-to-point)
> 2. Three to five nodes
> 3. More than five nodes
> 4. Not sure

Then:

> Are any nodes communicating, or is everything silent?
>
> 1. Complete silence — no traffic at all
> 2. Some nodes talk, but one or more can't
> 3. Traffic exists but full of errors
> 4. Other: ___

**Routing:**
- Silence -> Branch: Termination
- Some failing -> Branch: Bit Timing
- Errors -> Branch: Bit Timing

### Step 1.4: Complete Failure (Was Working)

**Purpose:** Identify what changed to cause the regression.

**Action:** Ask:
>
> 1. Added a new node or tool to the bus
> 2. Changed wiring or connectors
> 3. Updated firmware/configuration on a node
> 4. Moved the system to a different location
> 5. Nothing changed — it just stopped
> 6. Other: ___

**Routing:**
- 1 -> Branch: Termination
- 2 -> Branch: Voltage
- 3 -> Branch: Bit Timing
- 4 -> Branch: Ground
- 5, 6 -> Branch: Termination

### Step 1.5: Intermittent Failure

**Purpose:** Find the environmental or temporal correlation to narrow root cause.

**Action:** Ask:
>
> 1. Happens when motors/fans/heaters/VFDs activate
> 2. Happens under heavy CAN bus traffic
> 3. Worse when hot (temperature-related)
> 4. Happens at random — no pattern I can see
> 5. Happens with specific messages only
> 6. Other: ___

**Routing:**
- 1 -> Branch: Ground
- 2 -> Branch: Bit Timing
- 3 -> Branch: Waveform
- 4 -> Branch: Ground
- 5 -> Branch: Bit Timing
- 6 -> Branch: Ground

### Step 1.6: Rising Error Counters

**Purpose:** Interpret error counter patterns and route to the appropriate physical branch.

**Action:** If no physical changes since Phase 0, you already have TEC/REC — use the Error Counter Interpretation Guide below to route directly.

**If the user made physical changes** (reconnected cables, added termination, swapped nodes) or the skill previously suggested physical debugging: **re-read counters** before routing — the values may have shifted.

**Routing:**
- 1 -> Branch: Voltage
- 2 -> Branch: Ground
- 3 -> Branch: Termination
- 4 -> Branch: Voltage

---

## Error Counter Interpretation Guide

| Pattern | Likely Cause |
|---------|-------------|
| Single node TEC climbing, others fine | That node's TX path (transceiver, wiring, stub) |
| Single node REC climbing, TEC normal | Receiver seeing corruption (ground issue at that node) |
| All nodes REC climbing together | Shared physical problem (termination, backbone) |
| Counters spike then recover | Intermittent (connector, thermal, EMI burst) |
| Node goes Bus Off repeatedly | Severe local issue — check entire physical interface |
| Errors only with specific message ID | Not physical — bit timing mismatch or data-dependent stuff pattern |

## L1 Assessment

After completing relevant branches:

```
=== L1 Physical Layer Assessment ===

Termination: [OK / Issue: ___]
DC Voltages: [OK / Not checked / Issue: ___]
Ground:      [OK / Suspect / Issue: ___]
Waveforms:   [OK / Not checked / Issue: ___]
Bit Timing:  [OK / Mismatch / Issue: ___]
CAN FD:      [N/A / OK / Issue: ___]

Root Cause: ___
Recommended Actions:
1. ___
2. ___
```

**After L1 report, ask:**

> Does this explain the issue you're seeing, or do you still have symptoms?
>
> 1. That explains it — I'll fix the physical layer issue
> 2. I still have problems even though physical looks OK
> 3. Not sure — let me fix this first and come back

- If **1** -> Done.
- If **2** -> Phase 2.
- If **3** -> Done for now.

---

## Phase 2: Traffic Analysis

**Entry conditions (either path):**
- **Live capture:** Phase 0 showed healthy bus but customer still has issues, or L1 checks passed but symptoms remain. Capture traffic into `rawMsgs` timetable via `receive(canCh)`.
- **Pre-loaded timetable:** Customer already has a `rawMsgs` timetable in the workspace (from any source — live capture, BLF import via the data import/export skill, or MDF/MAT load).

**Requirement:** A `rawMsgs` timetable must exist in the workspace before running scripts. If not present, either capture live or ask the user to load their data first.

**Full analysis pipeline:** Read [l2-analysis-pipeline.md](l2-analysis-pipeline.md)
**Interpretation thresholds:** Read [l2-interpretation-tables.md](l2-interpretation-tables.md)

**L2 Functions (run, don't read):**
- `canTrafficOverview(rawMsgs)` — per-ID breakdown, dropout detection
- `canCycleTimeAnalysis(rawMsgs)` — jitter stats per ID
- `canBusLoadCalc(rawMsgs, busSpeedBps)` — bus load estimation + starvation check
- `canBurstDetection(rawMsgs, busSpeedBps)` — temporal burst profiling (conditional)

---

## Common Mistakes

- **Asking multiple questions at once** — confuses users. ONE question per response.
- **Filters blocking everything** — some vendors default to "Block All". Always check FilterHistory and call `filterAllowAll` explicitly.
- **Mismatched bus speed** — #1 cause of immediate BusOff. Verify speed matches the network.
- **Interpreting Virtual channel jitter as a problem** — Virtual has ~8% OS jitter. Real hardware is much tighter.
- **Jumping to driver installation first** — check physical connection before suggesting drivers. But vendor drivers (PEAK, Vector, Kvaser, etc.) ARE required for the OS to see the device. Diagnostic order: physical connection -> `canChannelList` -> `canSupportSummary` -> verify vendor drivers installed.
- **Routing Virtual channel users into L1** — Virtual has no physical layer. Skip L1 entirely.
- **Saying "ErrorActive rules out cabling"** — ErrorActive with 0 messages only means local transceiver is OK. Far end could be disconnected.
- **"lacks initialization access"** — another application (e.g., Vector CANoe, PEAK PCAN-View, Kvaser CANKing, NI MAX) holds init access. `configBusSpeed` will fail. Close the other tool or configure bus speed there.
- **Fabricating specific driver package names** — say "vendor drivers" or "Vector drivers", not "XL Driver Library" or other specific package names the user might search for incorrectly. Let `canSupportSummary` output identify exactly what's missing.
- **40 ohm termination** — almost always means three terminators. Ask about tools.
- **"Works on bench, fails in vehicle"** — always a ground problem until proven otherwise.
- **Analyzing too short a capture** — need at least 3x the longest cycle time.
- **Not accounting for event-driven messages** — some transmit on change only. High jitter is expected.

----

Copyright 2026 The MathWorks, Inc.

----
