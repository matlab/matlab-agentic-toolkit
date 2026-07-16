# Callback State Patterns

When a `ScansAvailableFcn` or `ScansRequiredFcn` needs to maintain state across fires (running counters, phase accumulators, latch flags, file handles), four mechanisms are available. Three work, one fails silently. This file is the decision guide.

## Quick decision

| Need                                                                 | Use                                       |
|----------------------------------------------------------------------|-------------------------------------------|
| Simple scalar counter or flag, in a function-form script             | **Nested function** (Pattern A)            |
| Complex state shared across multiple callbacks and external code     | **Handle class wrapper** (Pattern B)       |
| Quick prototype, single callback, can re-create state each fire      | **Anonymous-function closure** (Pattern C, with caveats) |
| Code already passes `d` everywhere and you don't want extra files    | **Whole-struct UserData rewrite** (Pattern D, advanced) |

**Never use:** `src.UserData.X = src.UserData.X + ...` field mutation (see anti-pattern below).

## Pattern A — Nested function (recommended default)

The callback is a nested function inside the entry function. Local variables in the entry function are captured by **reference** in nested functions, so updates persist.

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
        data      = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
        scansRead = scansRead + size(data, 1);
        if scansRead >= target
            stop(src);
        end
    end
end
```

**When to use:** the simplest correct form. Prefer this when the whole acquisition fits in one entry function.

**When NOT to use:** when state needs to be inspected from outside the entry function, or shared between multiple unrelated functions.

## Pattern B — Handle class wrapper

A `handle` class instance is passed by reference. Mutations to its properties persist across all references.

```matlab
classdef AcquisitionState < handle
    properties
        ScansRead (1,1) double = 0
        Target    (1,1) double
    end
    methods
        function obj = AcquisitionState(target)
            obj.Target = target;
        end
    end
end

% Usage:
state = AcquisitionState(d.Rate * 5);
d.ScansAvailableFcn = @(src, ~) onBlock(src, state);
d.ErrorOccurredFcn  = @(~, evt) fprintf("DAQ error: %s\n", evt.Error.message);
start(d, "Continuous");
while d.Running
    pause(0.05);
end

function onBlock(src, state)
    data           = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
    state.ScansRead = state.ScansRead + size(data, 1);
    if state.ScansRead >= state.Target
        stop(src);
    end
end
```

**When to use:** state is complex (multiple fields, methods like `reset()`, `summary()`), or callers outside the entry function need to read or modify it.

**Cost:** one additional class file. Worth it for nontrivial state.

## Pattern C — Anonymous-function closure (caveats)

Anonymous functions snapshot variables **by value** at creation time. They cannot mutate them.

```matlab
% This works:
gain = 0.5;
d.ScansAvailableFcn = @(src, ~) processBlock(src, gain);
% gain is captured by value; processBlock can read but not change it for next time.

% This DOES NOT work the way you might expect:
counter = 0;
d.ScansAvailableFcn = @(src, ~) (counter = counter + 1);  % Not even valid MATLAB syntax
```

**When to use:** read-only state (constants, configuration values that don't change across fires).

**When NOT to use:** any state that needs to update across fires. Pattern A or B instead.

## Pattern D — Whole-struct UserData rewrite (advanced)

`d.UserData` is a property; assigning `d.UserData = newStruct` calls the property setter and persists. **Field mutation** through `d.UserData.X = ...` from inside a callback does **not** persist reliably — see anti-pattern.

```matlab
d.UserData = struct('ScansRead', 0, 'Target', d.Rate * 5);
d.ScansAvailableFcn = @(src, ~) onBlock(src);
d.ErrorOccurredFcn  = @(~, evt) fprintf("DAQ error: %s\n", evt.Error.message);
start(d, "Continuous");

function onBlock(src)
    data = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
    s    = src.UserData;                  % copy whole struct out
    s.ScansRead = s.ScansRead + size(data, 1);
    src.UserData = s;                     % whole-struct assignment back
    if s.ScansRead >= s.Target
        stop(src);
    end
end
```

**When to use:** state belongs conceptually with the device and you don't want a separate class file. The whole-struct rewrite (`s = src.UserData; ... ; src.UserData = s`) is the only safe `UserData` mutation form.

**Verify after:** read `d.UserData.<field>` after a few callback fires and confirm the value advanced. Don't trust scan-count totals as a proxy — `NumScansAcquired` advances independent of your callback state.

## Anti-pattern — `src.UserData.X = src.UserData.X + …` field mutation

```matlab
% DO NOT DO THIS — field mutation inside the callback does not persist.
function onBlock(src)
    data = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
    src.UserData.ScansRead = src.UserData.ScansRead + size(data, 1);  % SILENTLY FAILS
    if src.UserData.ScansRead >= src.UserData.Target
        stop(src);
    end
end
```

This pattern reads `src.UserData` (a copy), mutates a field on the copy, and the assignment back through `src.UserData.ScansRead = …` does not propagate. The counter resets every fire; closed-loop control laws output zero forever; running totals stay at the increment of a single block.

**Why it's silent:** the syntax is legal MATLAB and produces no error. The field appears to update *within* the same callback fire, but the next fire sees the original value. Listener exception handling never sees a problem because there is no exception.

**Test for it:** insert `fprintf("UserData.X = %d\n", src.UserData.X);` at the top of the callback. If the value never advances across fires, this anti-pattern is in play.

## Summary table

| Pattern                              | Persists across fires? | When to use                                | Notes                                                |
|--------------------------------------|------------------------|--------------------------------------------|------------------------------------------------------|
| A. Nested function                   | Yes (by reference)     | Default for in-script callbacks            | Captures everything in scope                         |
| B. Handle class                      | Yes (by reference)     | Complex state, external access, methods    | Extra class file                                     |
| C. Anonymous closure (read-only)     | N/A — read only        | Configuration constants                    | Cannot mutate                                        |
| D. Whole-struct UserData rewrite     | Yes (whole-property)   | Lightweight, self-contained on `d`         | Only safe form: `s = src.UserData; …; src.UserData = s` |
| **Anti: field mutation on UserData** | **No — silent failure**| Never                                      | The most-common silent bug in DAQ callbacks          |

----

Copyright 2026 The MathWorks, Inc.

----
