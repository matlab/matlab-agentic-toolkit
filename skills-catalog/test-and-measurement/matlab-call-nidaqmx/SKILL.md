---
name: matlab-call-nidaqmx
description: >
  Translate NI-DAQmx C function signatures into correct calldaqlib MATLAB calls.
  Use when the user mentions calldaqlib, any DAQmx* C function name
  (DAQmxCfgSampClkTiming, DAQmxExportSignal, DAQmxSetStartTrigRetriggerable,
  DAQmxGetSampClkRate, etc.), or needs NI-DAQmx functionality not exposed by
  the daq object. Covers: projection rules (taskHandle implicit, output pointers
  become return values, buffer-size args, enum-as-string), multi-task semantics,
  start() clobber, device-level empty-daq workaround, dictionary returns, string
  getter placeholder, array getter placeholder.
  Trigger contexts: low-level DAQ, escape hatch, retriggerable acquisition,
  shared timebase, export signal, connect terminals, external sample clock,
  trigger configuration, NI driver, C function translation.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2026a"
metadata:
  author: MathWorks
  version: "1.0"
---

# matlab-call-nidaqmx

Translate NI-DAQmx C signatures into correct `calldaqlib` MATLAB calls on
Data Acquisition Toolbox R2026a+.

## When to Use

- User explicitly mentions `calldaqlib` or a specific `DAQmx*` C function
- User needs NI-DAQmx capability the daq object doesn't expose (retriggerable,
  export signal, reference triggers, enhanced alias rejection, digital filters)
- User is debugging at the driver level (reading back what the NI driver holds)
- User is translating existing C/LabVIEW code to MATLAB

## When NOT to Use

- User describes a capability achievable with the daq object alone (`dq.Rate`,
  `addtrigger`, `addclock`, `addinput`, `read`, `write`, `start`, `stop`)
- User asks about the Session-based (legacy) DAQ interface
- User needs `DAQmxCreateTask` or `DAQmxLoadTask` (these cannot work through
  calldaqlib — it owns task creation internally)

## Decision Tree

### Step 0 — Read the user's intent

Did the user explicitly mention `calldaqlib` or a specific DAQmx C function?

- **Yes** — Write the calldaqlib call they asked for. Do NOT redirect to the
  daq object. They have a reason (driver debugging, matching C code, capability
  gap, learning). Skip to Step 2.
- **No** — They described a capability without naming calldaqlib. Go to Step 1.

### Step 1 — Pick the right tool

Can the daq object property/method do this? (`dq.Rate`, `addtrigger`,
`addclock`, `addinput`, `dq.NumScansAvailable`, etc.)

- **Yes** — Recommend the daq object. Mention calldaqlib only if the user needs
  driver-level diagnostics or a capability outside daq object coverage.
- **No** — Proceed to Step 2.

### Step 2 — Device-level check

Does the C function lack a `taskHandle` parameter (device-level API)?

- Functions like `DAQmxGetDevIsSimulated`, `DAQmxGetDevAISupportedMeasTypes`:
  Use an **empty daq object** (no channels added). Pass the device name as an
  argument. Returns a plain scalar or array, not a dictionary.
- Functions like `DAQmxCreateTask`, `DAQmxLoadTask`: These **do not work**
  through calldaqlib at all (calldaqlib owns task creation internally).
- Functions like `DAQmxConnectTerms`, `DAQmxDisconnectTerms`: Use an **empty
  daq object** (same as device-level queries). These work on X-series devices.

### Step 3 — Multi-task check

Does the daq object have multiple internal task handles (e.g., AI + DIO)?

- **Getters with a channel arg**: The call runs on both tasks. The irrelevant
  task warns. Read the dictionary key you care about. Acceptable.
- **Setters targeting one measurement type**: No scoping mechanism. Split into
  separate daq objects (loses synchronized start/stop).

### Step 4 — Buffer placeholder check

Is this a getter returning a string or array?

- **String getter** (`char *data, uInt32 bufferSize` in C): Pass `""` then
  `bufferSize`. Example: `calldaqlib(dq, "DAQmxGetSampClkSrc", "", 256)`
- **Array getter** (`int32 data[], uInt32 arraySize` in C): Pass
  `zeros(1,N,'type')` then `N`. Example:
  `calldaqlib(dq, "DAQmxGetDevAISupportedMeasTypes", "Dev1", zeros(1,32,'int32'), 32)`

### Step 5 — Enum check

Does any argument correspond to a C `int32` enum slot?

- **Always use the string form**: `"DAQmx_Val_RisingSlope"` not `int32(10280)`.
  Both work, but strings are self-documenting and prevent silent wrong-enum bugs.
- See `references/enum-constants.md` for the 15 most-used enum names.

## Call Forms

Six distinct patterns cover all `calldaqlib` usage:

### 1. Config (DAQmxCfg*)

```matlab
dq = daq("ni");
addinput(dq, "Dev1", "ai0", "Voltage");
calldaqlib(dq, "DAQmxCfgSampClkTiming", "/Dev1/PFI0", 5000, ...
    "DAQmx_Val_Rising", "DAQmx_Val_FiniteSamps", uint64(1000));
```

### 2. Setter (DAQmxSet*)

```matlab
calldaqlib(dq, "DAQmxSetStartTrigRetriggerable", true);
```

### 3. Getter — scalar (DAQmxGet* returning numeric)

```matlab
result = calldaqlib(dq, "DAQmxGetSampClkRate");
rate = result("Dev1_ai0");
```

Returns a `dictionary` keyed by channel name — even on single-channel objects.

### 4. Getter — string (DAQmxGet* with char output)

```matlab
result = calldaqlib(dq, "DAQmxGetSampClkSrc", "", 256);
source = result("Dev1_ai0");
```

The `""` is required as a placeholder for the `char *data` output slot.
`bufferSize` follows immediately. Use 256 for short names, 1024 for long paths.

### 5. Getter — array (DAQmxGet* with typed array output)

```matlab
dEmpty = daq("ni");
result = calldaqlib(dEmpty, "DAQmxGetDevAISupportedMeasTypes", ...
    "Dev1", zeros(1, 32, "int32"), 32);
measTypes = result(result ~= 0);
```

Pre-allocate a typed buffer (`zeros(1,N,'int32')`) matching the C signature's
array type. Filter unused slots with `result(result ~= 0)`.

### 6. Device-level (no taskHandle in C signature)

```matlab
dEmpty = daq("ni");
isSim = calldaqlib(dEmpty, "DAQmxGetDevIsSimulated", "Dev1");
```
Use an empty daq (no channels added). Pass device name as argument.
Returns a plain scalar (not a dictionary).

Also works for terminal routing on X-series devices:

```matlab
dEmpty = daq("ni");
calldaqlib(dEmpty, "DAQmxConnectTerms", "/Dev1/PFI0", "/Dev1/PFI1", "DAQmx_Val_DoNotInvertPolarity");
calldaqlib(dEmpty, "DAQmxDisconnectTerms", "/Dev1/PFI0", "/Dev1/PFI1");
```

## C-to-calldaqlib Translation

| C argument | calldaqlib equivalent |
|---|---|
| `TaskHandle taskHandle` | **Omit** — daq object owns it |
| `const char source[]` | MATLAB string `"/Dev1/PFI0"` |
| `float64 rate` | MATLAB double |
| `int32 activeEdge` (enum) | Enum name string `"DAQmx_Val_Rising"` |
| `uInt64 sampsPerChan` | `uint64(1000)` |
| `bool32 data` (input) | `true` / `false` |
| `float64 *data` (output scalar) | Becomes return value (dictionary) |
| `int32 *data` (output scalar) | Becomes return value (dictionary) |
| `char *data, uInt32 bufferSize` (output pair) | Pass `""` + bufferSize |
| `int32 data[], uInt32 arraySize` (output array) | Pass `zeros(1,N,'int32')` + N |
| Any getter return | Always a `dictionary` keyed by `DevN_chanName` |

## Hard Rules

1. **taskHandle is implicit.** The daq object owns it. Never pass it.

2. **calldaqlib loops over every internal task.** A daq with AI + DIO has 2
   NI tasks; both get the call. For getters with a channel arg, ignore the
   warning from the irrelevant task and read the dictionary key you want.
   For setters targeting one measurement type, split into separate daq objects.

3. **Output-pointer args still need a placeholder + bufferSize.** String
   getters: pass `""` before bufferSize. Array getters: pass
   `zeros(1,N,'type')` before arraySize.

4. **start() clobbers calldaqlib-set rate and clock source.** `start()`
   reapplies `dq.Rate` to the driver. If you set rate via
   `DAQmxCfgSampClkTiming` then call `start()`, it snaps back to `dq.Rate`.
   Fix: set `dq.Rate` first, use calldaqlib only for parameters the daq
   object does not track. Alternative: use `DAQmxStartTask`/`DAQmxStopTask`
   via calldaqlib to bypass the daq object's commit pass entirely.

5. **Enum constants: use the string form.** `"DAQmx_Val_RisingSlope"` not
   `int32(10280)`. Strings are readable and prevent wrong-enum bugs. The
   error on a bad string is misleading ("Value must be of type int32") —
   it means the string wasn't recognized, not that you should pass an int.

6. **Device-level APIs need an empty daq.** Functions whose C signature has
   no `taskHandle` (like `DAQmxGetDevIsSimulated`,
   `DAQmxGetDevAISupportedMeasTypes`) work only when the daq object has no
   channels. Create `dEmpty = daq("ni")` and pass the device name as an arg.

7. **`DAQmxCreateTask` and `DAQmxLoadTask` cannot work through calldaqlib.**
   These functions create a new task — calldaqlib already owns task creation
   internally. `DAQmxConnectTerms`/`DAQmxDisconnectTerms` DO work via an
   empty daq object on X-series devices (same pattern as device-level queries).

8. **Property values are scalar.** Passing a vector where a scalar is
   expected errors. To set the same property on multiple channels, loop.

9. **Channel/device paths are not validated client-side.** A bad path
   produces no error until `start()`.

10. **Trigger support is per-device.** Not all devices support all trigger
    types. Error -200077 lists the supported enum values — read it.

11. **All task-level getter results return a `dictionary`.** Keyed by
    `DevN_chanName`. Never expect a bare scalar. Use `result("Dev1_ai0")`
    or iterate `keys(result)`.

12. **Buffer-size too small returns NI Error -200228.** The error message
    includes "Required Buffer Size in Bytes: N" — parse it and retry with N.
    Heuristic: 256 for short names, 1024 for long paths/channel lists.

13. **Array getters return a fixed-size buffer.** Filter unused trailing
    zeros with `result(result ~= 0)`.

## Conventions

- Always set `dq.Rate` before using calldaqlib for timing config
- Always use enum name strings, never raw integers
- Always expect a dictionary return from task-level getters
- Always pass `""` before bufferSize for string getters
- Always pre-allocate typed buffer for array getters
- Use empty daq (no channels) for device-level queries
- Warn about multi-task semantics in prose before the code block
- Configure trigger type before enabling retriggerable mode
- Retriggerable mode requires `DAQmx_Val_FiniteSamps` — it does not work with `ContSamps`
- Use specific getter function names (`DAQmxGetSampClkRate`) not generic attribute getters (`DAQmxGetTimingAttribute`)

## References

- `references/hot-signatures.md` — 20 most-used calldaqlib signatures by category
- `references/enum-constants.md` — 15 DAQmx_Val_* enum name strings
- `references/common-mistakes.md` — Mistakes from discovery trials and customer usage

----

Copyright 2026 The MathWorks, Inc.

----
