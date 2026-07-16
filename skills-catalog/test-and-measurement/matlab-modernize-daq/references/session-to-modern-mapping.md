# Session-API → Modern DataAcquisition Mapping

The official MathWorks transition guide — [Transition Your Code from the Session-Based Interface to the DataAcquisition Interface](https://www.mathworks.com/help/daq/transition-your-code-from-session-to-dataacquisition-interface.html) — is the authoritative reference for the basic function and object renames. This table complements it: it covers those renames **plus** the silent-failure traps the doc does not call out — the trigger Source/Destination argument-order change, the removed `wait` method, the `evt.Data` callback gotcha, `UserData` field-mutation non-persistence, `preload` being output-only, enum-value renames (`BridgeMode`), and `NumScans` being silently ignored.

Each entry below is a substitution agents commonly get wrong when porting verbatim.

## Constructors and discovery

| Session API                       | Modern API                  | Notes                                                                 |
|-----------------------------------|-----------------------------|-----------------------------------------------------------------------|
| `daq.createSession('ni')`         | `daq("ni")`                 | Returns `daq.interfaces.DataAcquisition`                              |
| `daq.getDevices`                  | `daqlist`                   | Optionally pass vendor: `daqlist("ni")`                               |
| `daq.getVendors`                  | `daqvendorlist`             |                                                                       |
| `daq.reset`                       | `daqreset`                  | Modern form is one word, no dot                                       |
| `release(s)`                      | `clear d`                   | No `release` method on the modern object                              |

## Channel addition

| Session API                                                   | Modern API                                              | Notes                                                                      |
|---------------------------------------------------------------|---------------------------------------------------------|----------------------------------------------------------------------------|
| `addAnalogInputChannel(s, dev, ch, type)`                     | `addinput(d, dev, ch, type)`                            | `type` strings still apply: `"Voltage"`, `"Thermocouple"`, etc.            |
| `addAnalogOutputChannel(s, dev, ch, type)`                    | `addoutput(d, dev, ch, type)`                           |                                                                            |
| `addCounterInputChannel(s, dev, "ctr0", type)`                | `addinput(d, dev, "ctr0", type)`                        | `addinput` handles counters too                                            |
| `addCounterOutputChannel(s, dev, "ctr0", type)`               | `addoutput(d, dev, "ctr0", type)`                       |                                                                            |
| `addDigitalChannel(s, dev, "Port0/Line0", "OutputOnly")`      | `addoutput(d, dev, "Port0/Line0", "Digital")`           | Direction is implied by `addinput` vs `addoutput`; type is `"Digital"`     |
| `addDigitalChannel(s, dev, "Port0/Line0", "InputOnly")`       | `addinput(d, dev, "Port0/Line0", "Digital")`            |                                                                            |

## Triggers and clocks

| Session API                                                          | Modern API                                                                   | Notes                                                                                  |
|----------------------------------------------------------------------|------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| `addTriggerConnection(s, source, dest, role)`                        | `addtrigger(d, type, role, trigSrc, trigDest)`                               | **Argument order changes.** Modern: type, role, source, destination. See snippets §1.  |
| `s.Connections(1).TriggerCondition = 'RisingEdge'`                   | `trg.Condition = "RisingEdge"`                                               | Property is on the trigger object returned by `addtrigger`                             |
| `addClockConnection(s, source, dest, role)`                          | `addclock(d, type, role, clkSrc, clkDest)`                                   | Same Source/Destination ordering as `addtrigger`                                       |
| `s.ExternalTriggerTimeout = 30`                                      | `d.DigitalTriggerTimeout = 30`                                               | Renamed property                                                                       |

## Lifecycle and execution

| Session API                                  | Modern API                                                            | Notes                                                                              |
|----------------------------------------------|-----------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `s.startForeground()`                        | `[data, t] = read(d, seconds(N))` or `read(d, numScans, ...)`         | `read` returns data directly                                                       |
| `s.startBackground()`                        | `start(d)` or `start(d, "Continuous")` or `start(d, "Duration", ...)`  | `IsContinuous`/`DurationInSeconds` properties became `start` arguments              |
| `s.IsContinuous = true`                      | `start(d, "Continuous")`                                              | No `IsContinuous` property on modern object                                        |
| `s.DurationInSeconds = N`                    | `start(d, "Duration", seconds(N))` or `read(d, seconds(N))`           |                                                                                    |
| `s.NumberOfScans = N`                        | implicit from `preload` size or `read` count                          | `start(d, "NumScans", N)` is silently ignored — emits a warning                    |
| `s.wait()` / `s.wait(timeout)`               | `while d.Running, pause(0.05); end`                                   | **No `wait` method exists on the modern object.** Most-frequent verbatim port-error. |
| `s.prepare()`                                | (none — `start` handles preparation)                                  | Don't translate                                                                    |
| `s.stop()`                                   | `stop(d)` or `stop(src)` from inside a callback                       | Functional form, not method                                                        |
| `s.IsRunning`                                | `d.Running`                                                           |                                                                                    |
| `s.IsWaitingForExternalTrigger`              | (no direct equivalent — design assumes trigger or timeout)            | Drop the polling pattern                                                           |
| `s.TriggersPerRun`                           | `d.NumDigitalTriggersPerRun`                                          |                                                                                    |
| `s.ScansOutputByHardware`                    | `d.NumScansOutputByHardware`                                          |                                                                                    |

## Output queueing

| Session API                              | Modern API                                                  | Notes                                                                       |
|------------------------------------------|-------------------------------------------------------------|-----------------------------------------------------------------------------|
| `s.queueOutputData(block)` (initial)     | `preload(d, block)`                                         | Before `start(d, "Continuous")`                                             |
| `s.queueOutputData(block)` (refill)      | `write(d, block)` (or `write(src, block)` from callback)    | Same function used outside and inside `ScansRequiredFcn`                    |
| `s.NotifyWhenScansQueuedBelow = N`       | `d.ScansRequiredFcnCount = N`                               | Triggers `ScansRequiredFcn` when remaining queued scans falls below `N`    |

## Callbacks (formerly listener events)

| Session API (listener event)                                    | Modern API (object property)            | Notes                                                                                      |
|------------------------------------------------------------------|-----------------------------------------|--------------------------------------------------------------------------------------------|
| `addlistener(s, 'DataAvailable', @cb)`                           | `d.ScansAvailableFcn = @cb`             | Function-handle property, not a listener                                                   |
| `s.NotifyWhenDataAvailableExceeds = N`                           | `d.ScansAvailableFcnCount = N`          |                                                                                            |
| `addlistener(s, 'DataRequired', @cb)`                            | `d.ScansRequiredFcn = @cb`              |                                                                                            |
| `addlistener(s, 'ErrorOccurred', @cb)`                           | `d.ErrorOccurredFcn = @cb`              | **Always wire this** — exceptions in the other `*Fcn`s are silently swallowed otherwise.   |
| Inside callback: `evt.Data`                                      | `read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix")` | Modern `evt` is `matlabshared.asyncio.buffer.ElementsAvailableInfo` — no `Data` field |
| Inside callback: `evt.TimeStamps`                                | second return of `read(src, ...)`       |                                                                                            |
| Inside callback: `src.outputSingleScan(value)`                   | `write(src, value)`                     |                                                                                            |
| `s.UserData = struct(...)` for cross-callback state              | (allowed, but use whole-struct rewrites only — see `callback-state-patterns.md`) | Field mutation `src.UserData.X = src.UserData.X + ...` does **not** persist                |

## Channel-property renames

| Session-API property                       | Modern equivalent                          | Notes                                                                                |
|--------------------------------------------|--------------------------------------------|--------------------------------------------------------------------------------------|
| `ch.BridgeMode = "FullBridge"`             | `ch.BridgeMode = "Full"`                   | Enum dropped the `Bridge` suffix. Other values: `"Half"`, `"Quarter"`, `"Unknown"`. |
| `ch.CJCSource` (on NI 9214 thermocouples)  | (not exposed in modern API)                | Module handles CJC internally; remove the line                                       |
| `s.AutoSyncDSA = true`                     | `d.AutoSyncDSA = true`                     | Same name, just on the modern object                                                 |
| `s.RateLimit`                              | `d.RateLimit`                              | Note: some modules return fractional Hz (e.g. NI 9219 = 0.1 Hz)                      |
| `chPos.EncoderType / ZResetEnable / ZResetValue` (counter Position) | unchanged                          | Property names port verbatim                                                         |

## Channel-type strings

| Session API string             | Modern API string             | Notes                                                                |
|--------------------------------|-------------------------------|----------------------------------------------------------------------|
| `'Voltage'`                    | `"Voltage"`                   | String type works in both; double-quoted preferred in modern code    |
| `'Thermocouple'`               | `"Thermocouple"`              |                                                                      |
| `'Accelerometer'`              | `"Accelerometer"`             |                                                                      |
| `'Bridge'`                     | `"Bridge"`                    | But `BridgeMode` enum changes — see channel-property table           |
| `'Frequency'` (counter input)  | `"Frequency"`                 |                                                                      |
| `'Position'` (counter input)   | `"Position"`                  |                                                                      |
| `'PulseGeneration'` (counter output) | `"PulseGeneration"`     |                                                                      |
| `'OutputOnly'` / `'InputOnly'` (digital) | `"Digital"` (direction implied by addinput/addoutput) | Single type string in modern API     |

----

Copyright 2026 The MathWorks, Inc.

----
