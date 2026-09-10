# Timers in Apps

A `timer` runs periodic work on the **main (UI) thread**. It does NOT run in the
background, so it cannot keep the UI responsive during heavy work — a slow tick
freezes the app exactly like inline code.

> ### STOP — is a timer actually the right tool?
>
> Use a timer only when **ALL** of these are true:
> 1. The work **recurs on a schedule** (not a one-shot computation).
> 2. **Each tick is cheap** — a quick poll/read plus a UI update, nothing that would
>    freeze the UI on its own.
> 3. It **must touch UI/graphics on the main thread** (e.g. `plot`, updating components live).
>
> If **ANY** of these is true, use a **background task** instead (`references/background-tasks.md`), not a timer:
> - A single tick does heavy or blocking work (long compute, large I/O, slow processing).
> - It is a one-shot long-running operation (train, export, download, crunch).
> - The goal is "keep the UI responsive during heavy work" — a timer runs on the UI
>   thread and cannot do this.

## How to wire one up

Create the timer in the app's startup, and **always stop and delete it on close**.

```matlab
% In startupFcn:
app.PollTimer = timer("ExecutionMode","fixedRate", "Period",5, ...
    "BusyMode","queue", "TimerFcn",@app.onTick);

% Start / stop from button callbacks:
start(app.PollTimer);
stop(app.PollTimer);

% Timer callback — keep it cheap; it runs on the UI thread:
function onTick(app, ~, ~)
    data = webread("https://example.com/latest.json");   % quick read
    plot(app.UIAxes, data.time, data.value, "ob");       % direct UI update
end

% In CloseRequestFcn — stop and delete before the figure is destroyed:
function onClose(app)
    stop(app.PollTimer); delete(app.PollTimer);
    delete(app);
end
```

Key points:
- `ExecutionMode="fixedRate"` with a `Period` fires on a fixed schedule; `BusyMode="queue"`
  defers a tick if the previous one is still running rather than dropping it.
- The `TimerFcn` receives `(src, event)` after the app handle: signature is `onTick(app, ~, ~)`.
- Never delete the timer without stopping it first, and never leave it running after the
  app closes.

Copyright 2026 The MathWorks, Inc.

----
