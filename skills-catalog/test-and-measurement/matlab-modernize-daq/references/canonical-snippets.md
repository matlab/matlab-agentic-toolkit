# Canonical DAQ Snippets

Self-contained, runnable forms for the five patterns in SKILL.md. Each snippet has been verified against MATLAB R2026a with an NI USB-6211 attached as `Dev1`. Copy as-is and adapt the device name, channel IDs, rate, and duration.

## §1. External start trigger

```matlab
trg = addtrigger(d, "Digital", "StartTrigger", "External", "Dev1/PFI0");
trg.Condition           = "RisingEdge";
d.DigitalTriggerTimeout = 30;
```

**Argument order:** `(d, type, role, trigSrc, trigDest)`. Source is 4th, Destination is 5th. `"External"` means "from outside MATLAB" — when an external signal drives the trigger, `"External"` is the Source and the device PFI terminal is the Destination.

**Verify after:**

```matlab
disp(trg.Source);       % "External"
disp(trg.Destination);  % "Dev1/PFI0"
```

If those don't match intent, the call was wrong — fix before `start`.

## §2. ScansAvailableFcn body

```matlab
d.ScansAvailableFcnCount = round(d.Rate * 0.5);    % half a second per fire
d.ScansAvailableFcn = @(src, ~) onBlock(src);
d.ErrorOccurredFcn  = @(~, evt) fprintf("DAQ error: %s\n", evt.Error.message);

function onBlock(src)
    [data, t] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
    plot(t, data);
    drawnow limitrate;
end
```

**The `evt` argument has no `Data` and no `TimeStamps`.** It is `matlabshared.asyncio.buffer.ElementsAvailableInfo` and exposes only `NumElementsAvailable`, `Source`, `EventName`. Reaching for `evt.Data` or `evt.TimeStamps` throws — and without `ErrorOccurredFcn` wired, the listener silently swallows the throw and the run "succeeds" while every callback fails.

**Strongly recommend wiring `ErrorOccurredFcn`** when any other `*Fcn` is set. For strict ports of legacy scripts that did not have an `ErrorOccurred` listener, surface the silent-swallow trade-off to the user instead of silently inserting the handler — let them opt in.

## §3. Block until acquisition completes

There is no `wait(d)` method on the modern object. Two patterns work:

### §3a. Finite acquisition

```matlab
start(d, "Duration", seconds(10));
while d.Running
    pause(0.05);
end
```

### §3b. Continuous acquisition with stop-from-callback

```matlab
target = d.Rate * 10;
scansRead = 0;

d.ScansAvailableFcnCount = round(d.Rate * 0.5);
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
```

Note: `scansRead` and `target` must be in scope of `onBlock` for this form. In a script, use a nested function (wrap the whole thing in a `function` declaration) or move state to a handle class — see `callback-state-patterns.md`.

## §4. Continuous AO with auto-refill

```matlab
function continuousAOWithRefill()
    daqreset;

    d = daq("ni");
    d.Rate = 1000;
    addoutput(d, "Dev1", "ao0", "Voltage");

    blockSize = d.Rate;            % 1 second per refill block
    phase     = 0;                 % nested-function state for waveform continuity

    d.ScansRequiredFcnCount = blockSize;
    d.ScansRequiredFcn = @(src, ~) refill(src);
    d.ErrorOccurredFcn = @(~, evt) fprintf("DAQ error: %s\n", evt.Error.message);

    preload(d, nextBlock());
    preload(d, nextBlock());

    start(d, "Continuous");
    pause(5);
    stop(d);

    function block = nextBlock()
        n     = blockSize;
        t     = (0:n-1).' / d.Rate;
        block = sin(2*pi*50*t + phase);
        phase = mod(phase + 2*pi*50*n/d.Rate, 2*pi);
    end

    function refill(src)
        write(src, nextBlock());
    end
end
```

**`preload` is output-only.** Calling it on a DAQ with only input channels errors. Two preloaded blocks before `start` give the buffer enough headroom for the first `ScansRequiredFcn` to fire without underrun.

**Phase is held in a nested-function variable** so the waveform is continuous across block boundaries. If `phase` were captured by an anonymous-function snapshot, every block would start at phase 0 and produce a discontinuity.

## §5. Multi-channel AI streaming with start trigger

The "complex multi-feature" form that combines patterns §1–§3 plus channel configuration. This is exactly the kind of script where load-induced gaps appear:

```matlab
function multiChannelTriggeredStreaming()
    daqreset;

    d = daq("ni");
    d.Rate = 10000;

    chs = addinput(d, "Dev1", 0:3, "Voltage");
    for k = 1:numel(chs)
        chs(k).TerminalConfig = "Differential";
        chs(k).Range          = [-5 5];
        chs(k).Coupling       = "DC";
    end

    trg = addtrigger(d, "Digital", "StartTrigger", "External", "Dev1/PFI0");
    trg.Condition           = "RisingEdge";
    d.DigitalTriggerTimeout = 30;

    target    = d.Rate * 10;       % 10 s of data
    scansRead = 0;

    d.ScansAvailableFcnCount = round(d.Rate * 0.5);
    d.ScansAvailableFcn      = @(src, ~) onBlock(src);
    d.ErrorOccurredFcn       = @(~, evt) fprintf("DAQ error: %s\n", evt.Error.message);

    start(d, "Continuous");
    while d.Running
        pause(0.05);
    end

    function onBlock(src)
        [data, t] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
        plot(t, data);
        drawnow limitrate;
        scansRead = scansRead + size(data, 1);
        if scansRead >= target
            stop(src);
        end
    end
end
```

Reach for this snippet whenever you would otherwise compose a multi-feature script from scratch. Adapt the channel list, rate, trigger terminal, and `target` to the user's needs.

----

Copyright 2026 The MathWorks, Inc.

----
