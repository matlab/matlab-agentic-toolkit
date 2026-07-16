---
name: matlab-modernize-daq
description: >
  Port MATLAB Data Acquisition Toolbox code from the discouraged (legacy) session-based interface
  (daq.createSession, addAnalogInputChannel, startBackground, DataAvailable listeners,
  queueOutputData, wait) to the recommended DataAcquisition interface (daq("ni"), addinput,
  start, ScansAvailableFcn, write, preload). Use when migrating legacy DAQ scripts,
  converting session-API calls, working with DataAcquisition objects, writing multi-feature
  DAQ scripts that combine triggers, callbacks, continuous acquisition, or analog output.
  Also use when a user says their DAQ script "used to work" or "errors on R20XX",
  since modernizing legacy session-API code is a frequent fix for those failures.
  Trigger keywords: daq, DAQ, NI, session interface, addtrigger, addclock, ScansAvailableFcn,
  ScansRequiredFcn, daq.createSession, addAnalogInputChannel, startBackground,
  queueOutputData, DataAvailable, evt.Data, evt.TimeStamps, wait(d), preload,
  discouraged, legacy, modernize, R2020a.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Port DAQ Code to the Modern DataAcquisition Interface

Translate legacy session-based Data Acquisition Toolbox code (`daq.createSession`, `addAnalogInputChannel`, `DataAvailable` listeners, `startBackground`, `queueOutputData`, `wait`) to the modern `DataAcquisition` interface introduced in R2020a (`daq("ni")`, `addinput`, `ScansAvailableFcn`, `start`, `write`, `preload`). Also covers writing new multi-feature DAQ scripts where the modern API patterns are easy to get wrong under cognitive load.

## When to Use

- Porting an existing script that calls `daq.createSession`, `addAnalogInputChannel`, `addAnalogOutputChannel`, `addCounterInputChannel`, `addCounterOutputChannel`, or `addDigitalChannel`.
- Replacing `DataAvailable` / `DataRequired` / `ErrorOccurred` listeners with `ScansAvailableFcn` / `ScansRequiredFcn` / `ErrorOccurredFcn`.
- Replacing `startBackground` / `startForeground` / `s.wait()` lifecycle calls.
- Replacing `queueOutputData` with `preload` + `write`.
- Writing a **new** DAQ script that combines two or more of: external triggers, continuous acquisition, callback-driven streaming, analog output with refill, or cross-callback state.
- Debugging errors like `Undefined function 'wait' for input arguments of type 'daq.interfaces.DataAcquisition'` or `Unrecognized method, property, or field 'Data' for class 'matlabshared.asyncio.buffer.ElementsAvailableInfo'`.

## When NOT to Use

- Single-channel foreground acquisition with no trigger and no callbacks (e.g. "acquire 1 s of voltage from ai0 at 10 kHz and plot"). The modern API is straightforward at this scale and this skill would be unnecessary overhead.
- Picking a DAQ vendor or evaluating non-NI hardware. This skill's evidence base is NI.
- Signal processing or analysis of already-acquired data (filtering, spectral analysis, etc.). This skill only covers acquiring and generating data through the DataAcquisition interface, not post-processing it.
- Simulink, App Designer, or real-time-target DAQ workflows.
- Modernizing `matlab.unittest` test suites or framework-style test classes (parameterized fixtures, `assumeTrue` gating, arity-contract tests, helper-class hierarchies). The API substitutions in this skill apply, but the test-harness scaffolding (parent-class stripping, fixture redesign, retiring tests that target removed contracts) is out of scope. Use this skill to translate the API calls inside test bodies, then make the harness-level judgment calls separately.

## Workflow

When porting a session-based script or composing a new multi-feature DAQ script, follow this order. Verify after every step — most failure modes in this domain are silent.

1. **Inventory the legacy script (porting only).** Identify: device(s), channel types, rate, continuous vs finite, trigger/clock connections, callbacks (`DataAvailable`/`DataRequired`/`ErrorOccurred`), state shared across callbacks, output queueing.

2. **Translate vocabulary.** Map every session-API token to its modern counterpart. Consult [`references/session-to-modern-mapping.md`](references/session-to-modern-mapping.md) — load it whenever a session-API token appears in the legacy script. Common silent-rename traps: `NotifyWhenDataAvailableExceeds` → `ScansAvailableFcnCount`, `NumberOfScans`/`NumScans` → implicit (no equivalent argument), `ExternalTriggerTimeout` → `DigitalTriggerTimeout`, `IsContinuous=true` → `start(d, "Continuous")` argument.

3. **Build the DataAcquisition object.** `d = daq("ni")`, set `d.Rate`, add channels with `addinput`/`addoutput`. Apply per-channel properties via the channel handle returned by `addinput`/`addoutput`.

4. **Wire triggers and clocks.** Use [`references/canonical-snippets.md`](references/canonical-snippets.md) §1 — load it when the script involves `addtrigger` or `addclock`. Argument order is `(d, type, role, trigSrc, trigDest)` — Source is 4th, Destination is 5th. **Verify:** the returned trigger object's `Source` and `Destination` fields show what you intended.

5. **Wire callbacks.** Use canonical snippets §2 — load it when the script needs `ScansAvailableFcn` or `ScansRequiredFcn`. Inside the callback, **always** pull data via `read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix")` — the `evt` argument is `matlabshared.asyncio.buffer.ElementsAvailableInfo` and exposes only `NumElementsAvailable`, no `Data`, no `TimeStamps`. **Strongly recommend** wiring `d.ErrorOccurredFcn = @(~,evt) fprintf("DAQ error: %s\n", evt.Error.message)` — without it, exceptions inside other callbacks are silently swallowed and the run "succeeds" while every fire throws. For strict ports where the legacy script had no `ErrorOccurred` listener, surface this trade-off to the user instead of silently adding the handler — let them opt in.

6. **Pick a state-sharing pattern (callbacks only).** If a callback needs to maintain state across fires (running counters, phase accumulator, latch flags), see [`references/callback-state-patterns.md`](references/callback-state-patterns.md) — load it any time a callback maintains state. Default: handle-class wrapper or nested function. Avoid `src.UserData.X = src.UserData.X + ...` field-mutation; it does not persist.

7. **Wire the lifecycle.** Use canonical snippets §3 — load it when blocking on completion. There is no `wait(d)` method on the modern object. For finite acquisitions, prefer `start(d, "Duration", seconds(N))` then `read` or a `Running` poll. For continuous, set a stop condition inside the callback (`if scansRead >= target; stop(src); end`) and poll `d.Running` from the caller.

8. **Run `verifyDataAcquisition` before live execution.** Script: [`scripts/verifyDataAcquisition.m`](scripts/verifyDataAcquisition.m). Catches the four highest-frequency silent gaps (missing `ErrorOccurredFcn`, `evt.Data` in callback source, `wait(d)` token, `UserData.X = UserData.X + ...` field mutation) by inspecting the live object and grepping the source file. Run via `mcp__matlab__run_matlab_file` if available, or copy into the user's project.

9. **Live verification.** Run a short version (e.g. 1–2 s instead of the user's full duration). Check that the script reaches `start` cleanly, that the callback fires at least once, and that no errors print from `ErrorOccurredFcn`. **Use `mcp__matlab__run_matlab_file` against a saved `.m` file**, not `mcp__matlab__evaluate_matlab_code` — the eval-string buffer runs in script mode and rejects local/nested function definitions, which Pattern 5 and most callback bodies require.

## Key Functions

| Function | Purpose | Toolbox | Available From |
|----------|---------|---------|----------------|
| `daq` | Create a `DataAcquisition` object (`d = daq("ni")`) | Data Acquisition Toolbox | R2020a |
| `addinput` | Add input channel (analog, counter, or digital) | Data Acquisition Toolbox | R2020a |
| `addoutput` | Add output channel | Data Acquisition Toolbox | R2020a |
| `addtrigger` | Add trigger connection: `addtrigger(d, type, role, trigSrc, trigDest)` | Data Acquisition Toolbox | R2020a |
| `addclock` | Add clock connection (similar signature) | Data Acquisition Toolbox | R2020a |
| `read` | Foreground acquire OR pull data inside `ScansAvailableFcn` | Data Acquisition Toolbox | R2020a |
| `write` | Write output samples (also from inside `ScansRequiredFcn`) | Data Acquisition Toolbox | R2020a |
| `preload` | Load initial output buffer before `start(d, "Continuous")`. **Output channels only.** | Data Acquisition Toolbox | R2020a |
| `start` | Begin background acquisition: `start(d)`, `start(d, "Continuous")`, `start(d, "Duration", seconds(N))` | Data Acquisition Toolbox | R2020a |
| `stop` | Stop a running acquisition | Data Acquisition Toolbox | R2020a |
| `flush` | Discard buffered scans before reading | Data Acquisition Toolbox | R2020a |
| `daqlist` | Enumerate available devices (replaces `daq.getDevices`) | Data Acquisition Toolbox | R2020a |
| `daqreset` | Reset DAQ subsystem (replaces `daq.reset`) | Data Acquisition Toolbox | R2020a |

Properties on `DataAcquisition`: `Rate`, `Running`, `NumScansAcquired`, `NumScansOutputByHardware`, `ScansAvailableFcn`, `ScansAvailableFcnCount`, `ScansRequiredFcn`, `ScansRequiredFcnCount`, `ErrorOccurredFcn`, `DigitalTriggerTimeout`, `UserData`.

## Patterns

The five canonical patterns below appear in full, with verified code, in [`references/canonical-snippets.md`](references/canonical-snippets.md). Inline below is the minimal recall snippet for each — enough to anchor the agent's memory under load. Load the reference for the full, runnable forms.

### Pattern 1: Add an external start trigger

```matlab
trg = addtrigger(d, "Digital", "StartTrigger", "External", "Dev1/PFI0");
trg.Condition = "RisingEdge";
d.DigitalTriggerTimeout = 30;
```

The 4th argument is the **Source** (`"External"` for an external signal). The 5th is the **Destination** (the device terminal). Reversing them is the most-frequent error in this domain. The trigger condition (`"RisingEdge"`, `"FallingEdge"`) is set on the **trigger object returned by `addtrigger`** (`trg.Condition`), **not** on the DataAcquisition object. There is no `d.DigitalTriggerCondition` property — inventing one passes static lint but errors at runtime.

### Pattern 2: ScansAvailableFcn body — pull data via `read`, never `evt.Data`

```matlab
d.ScansAvailableFcnCount = round(d.Rate * 0.5);
d.ScansAvailableFcn = @(src, ~) onBlock(src);
d.ErrorOccurredFcn  = @(~, evt) fprintf("DAQ error: %s\n", evt.Error.message);

function onBlock(src)
    [data, t] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
    plot(t, data); drawnow limitrate;
end
```

The `evt` argument carries only `NumElementsAvailable`; it has no `Data` or `TimeStamps`. Wiring `ErrorOccurredFcn` is strongly recommended — without it, callback exceptions are silently swallowed and the run "succeeds" while every fire throws. For strict ports of legacy scripts that did not have an `ErrorOccurred` listener, ask the user before adding one rather than inserting it silently.

### Pattern 3: Block until acquisition completes — there is no `wait(d)`

```matlab
start(d, "Duration", seconds(10));
while d.Running
    pause(0.05);
end
```

`wait(d)` does not exist on `daq.interfaces.DataAcquisition`. Poll `d.Running`, or rely on `start(d, "Duration", ...)` + a stop condition inside the callback.

### Pattern 4: Continuous AO playback with auto-refill

```matlab
d = daq("ni");
d.Rate = 1000;
addoutput(d, "Dev1", "ao0", "Voltage");
d.ScansRequiredFcnCount = d.Rate;
d.ScansRequiredFcn = @(src, ~) write(src, generateNextBlock());
preload(d, generateNextBlock());
preload(d, generateNextBlock());
start(d, "Continuous");
```

`preload` is **output-only** — calling it on input-only setups errors. Two preloaded blocks before `start` give the buffer headroom for the first `ScansRequiredFcn` to fire.

### Pattern 5: Cross-callback state via nested function or handle class

```matlab
function runStreamingAcquisition()
    d = daq("ni");
    addinput(d, "Dev1", "ai0", "Voltage");
    d.Rate = 1000;
    d.ScansAvailableFcnCount = 200;

    scansRead = 0;
    target    = d.Rate * 5;
    d.ScansAvailableFcn = @(src, ~) onBlock(src);
    d.ErrorOccurredFcn  = @(~, evt) fprintf("DAQ error: %s\n", evt.Error.message);

    start(d, "Continuous");
    while d.Running
        pause(0.05);
    end

    function onBlock(src)
        data = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
        scansRead = scansRead + size(data, 1);
        if scansRead >= target
            stop(src);
        end
    end
end
```

Nested function captures `scansRead` by reference, so updates persist across fires. **Do not** use `src.UserData.X = src.UserData.X + ...` — that pattern does not persist; counters reset every fire and closed-loop control silently outputs zero forever. Full alternatives (handle class, full UserData rewrite) and their tradeoffs are in [`references/callback-state-patterns.md`](references/callback-state-patterns.md).

## Conventions

- **Strongly recommend** wiring `d.ErrorOccurredFcn` whenever any other `*Fcn` callback is set, since the listener swallows callback exceptions otherwise. For strict ports of legacy scripts that lacked an `ErrorOccurred` listener, surface the trade-off to the user rather than silently adding the handler — adding it is a defensible default but fidelity to the source is also defensible.
- **Always** pull data via `read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix")` inside `ScansAvailableFcn`. Never reach for `evt.Data` or `evt.TimeStamps`.
- **Always** verify the returned trigger object after `addtrigger` — confirm `Source` and `Destination` reflect intent.
- **Never** use `wait(d)`. Poll `d.Running` or use `start(d, "Duration", ...)`.
- **Never** mutate fields of `d.UserData` from inside a callback (`src.UserData.X = src.UserData.X + ...`). State must live in a closure-captured variable, a handle-class wrapper, or a whole-struct rewrite of `UserData`.
- **Never** call `preload` on an input-only `DataAcquisition`. It is output-only.
- **Prefer** `start(d, "Duration", seconds(N))` over `start(d, "NumScans", N)` for finite acquisition. `NumScans` is silently coerced or ignored.
- **Prefer** the modern function names: `daqlist` over `daq.getDevices`, `daqreset` over `daq.reset`, `daq("ni")` over `daq.createSession('ni')`.

## Common Mistakes

| Mistake                                                        | Why It's Wrong                                                                  | Correct Approach                                                                |
|----------------------------------------------------------------|---------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `addtrigger(d, "Digital", "StartTrigger", "Dev1/PFI0", "External")` | Source/Destination reversed. 4th arg is Source, 5th is Destination.        | `addtrigger(d, "Digital", "StartTrigger", "External", "Dev1/PFI0")`             |
| `plot(evt.TimeStamps, evt.Data)` inside `ScansAvailableFcn`    | `evt` is `ElementsAvailableInfo`; only `NumElementsAvailable`. Throws silently. | `[data, t] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix")`   |
| `wait(d)`                                                      | No such method on `daq.interfaces.DataAcquisition`. Throws.                    | `while d.Running, pause(0.05); end`                                             |
| `src.UserData.Counter = src.UserData.Counter + n`              | Field mutation through `src.UserData` does not persist across callback fires. | Closure variable in nested function, or handle-class wrapper. See `callback-state-patterns.md`. |
| `preload(d, ...)` on a DAQ with only input channels            | `preload` is output-only.                                                       | For inputs, just call `start(d, ...)`. No prepare/preload step needed.          |
| `start(d, "NumScans", 1000)`                                   | `NumScans` is ignored — emits warning. Buffer size determined by `preload` or `read`. | `start(d, "Duration", seconds(N))`, or rely on `preload` size.            |
| `s.IsContinuous = true; s.startBackground();`                  | Both are session-API. Modern API has no `IsContinuous` property.                | `start(d, "Continuous")`                                                        |
| `addlistener(d, 'DataAvailable', @cb)`                         | Listener events were renamed to `*Fcn` properties on the object.                | `d.ScansAvailableFcn = @cb`                                                     |
| `s.queueOutputData(block)`                                     | Session-API. Modern API uses `preload` (initial) and `write` (refill).          | `preload(d, block)` before `start`; `write(d, block)` from `ScansRequiredFcn`. |

## References

- [`references/session-to-modern-mapping.md`](references/session-to-modern-mapping.md) — full rename table for every function and property that is commonly ported verbatim by mistake. Load whenever a session-API token appears in the legacy script.
- [`references/canonical-snippets.md`](references/canonical-snippets.md) — minimal, self-contained, runnable forms of the five patterns above. Load when composing a multi-feature script and you want a verified anchor.
- [`references/callback-state-patterns.md`](references/callback-state-patterns.md) — four state-sharing options (UserData / closure / handle-class / nested function), when to pick which, and the silent failure modes of the wrong choice. Load when any callback needs cross-fire state.
- [`scripts/verifyDataAcquisition.m`](scripts/verifyDataAcquisition.m) — static-checks a `DataAcquisition` object and its source script before live execution. Returns a structured report flagging the four highest-frequency silent gaps.

----

Copyright 2026 The MathWorks, Inc.

----
