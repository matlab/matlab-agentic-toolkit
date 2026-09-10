# Background Tasks (Background Execution in Apps)

Run work off the main thread so the UI stays responsive, using the `parfeval` +
`backgroundPool` pattern (with `DataQueue` for progress streaming and cancellation).
This hub covers the concepts and routing shared by both serialization paths; the
per-format API detail lives in the two docs linked below.

> ### STOP — pick your path before writing any code
>
> The two paths are NOT interchangeable. Applying the wrong one produces a broken
> or unmaintainable app.
>
> 1. **App Designer app** — a `.mlapp` or plain-text `.m` + `.xml` built through
>    `AppDesignerAgentInterface` (`create()` / `open()`)? **→ You MUST use the
>    `addBackgroundTask` verb.** Read `references/app-designer/background-tasks.md`.
>    Do NOT hand-wire the pattern.
> 2. **Standalone programmatic app** (plain `.m`, no App Designer)? **→ Wire the
>    templates in by hand** per `references/uifigure/mvvm-background-tasks.md` (requires
>    the MVVM structure).
>
> If you are unsure which you are building, you do not yet know enough to add a
> background task — resolve the serialization path first (see the main SKILL.md).

**Background execution requires a class-structured app.** A background task needs
durable per-task state (`Future`, `Queue`, `Running`, `StopRequested`), shared
methods reachable from multiple callbacks, and a `CloseRequestFcn` that cancels
in-flight work on close. A flat nested-function UIFigure app that grows a background
task is your signal to escalate: build it as an App Designer app (the verb does
everything) or, if staying standalone programmatic, structure it as MVVM.

**Editing an existing programmatic app?** Restructuring it to MVVM requires explicit
user consent first — see the gate in `references/editing-guide.md`.

---

## When to use

Best for a single long-running task that keeps the UI responsive while it runs. Use
when any of these are present:

- Long computation, training, export, download, processing, number crunching
- Progress indicators, streaming results, or partial updates
- A cancel button for in-progress work
- "Keep the app responsive" / "don't freeze the UI"
- Any callback body taking more than ~1 second

Do NOT use for:
- Work that completes in under a second (run it inline)
- Work that must block interaction (use a progress dialog)

---

## The shared infrastructure (single source of truth)

Both paths run identical background-execution code, maintained as template files under
`scripts/+module/+backgroundtask/templates/`:

| Method | Role |
|--------|------|
| `startBackground(app, taskName, varargin)` | Launches the named task (args after the name). Agent/user callable. |
| `cancelBackground(app, taskName)` | Sets StopRequested, cancels a running task (no-op if idle). Agent/user callable. |
| `handleBackgroundComplete(app, taskName, future)` | Routes completion to the task's CompleteFcn; try/catch surfaces user errors via uialert + stderr. Internal. |
| `safeProgress(app, taskName, msg)` | Dispatches DataQueue messages to the ProgressFcn with error protection; routes Finished to `handleBackgroundComplete`. All progress callbacks complete before completion fires. Internal. |
| `cleanupBackground(app)` | Cancels all task futures (called on close). Internal. |

These are written against a single host object named `app` that owns the figure
(`app.UIFigure`), the per-task state (`app.(taskName)`), and the other infra methods.
The App Designer verb inserts them verbatim; the programmatic path drops them into the
View verbatim. Because both consumers use the files unchanged, a fix lands in one place.

The one piece you always author is the **compute function** (`Fcn`) that runs on the
worker. Everything else is infrastructure.

---

## Callback signatures

| Callback | Signature | Notes |
|----------|-----------|-------|
| Compute (no progress) | `function [result] = fcn(data, ...)` | Any number of inputs. Output count auto-detected via `nargout`. |
| Compute (with progress) | `function [result] = fcn(data, ..., sendProgress)` | `sendProgress` injected as the **last** arg. Call `sendProgress(value)` to stream. |
| Completion | `function completeFcn(app, result, error, wasCancelled)` | `result` is `[]` when cancelled/errored; `error` is `[]` on success. |
| Progress | `function progressFcn(app, data)` | `data` is whatever was passed to `sendProgress`. |

**Output handling** (`nargout` of the compute function): 0 → `result` is `[]`;
1 → the value directly; >1 → a cell array.

---

## Limitations

- **Assume a single worker; don't depend on more.** Worker count depends on the MATLAB
  license, machine, and (for shared apps) where it runs. Some environments run tasks in
  parallel, but design as if there is only one. You cannot launch a parallel pool inside
  a `backgroundPool` worker (`parfor`, `UseParallel=true`, etc. are unavailable there).
- **Tasks do not yield.** A long-lived task occupies its worker for its whole duration.
  With one worker, a second task cannot start until the first finishes or is cancelled.
  Prefer breaking long work into shorter discrete tasks if other work must progress.
- **Thread-based workers.** Only thread-worker-compatible functions/classes run in the
  background. Unsupported calls error clearly through the CompleteFcn error path. If no
  thread-supported equivalent fits, the work is not a background-task candidate.
- **Timing is not guaranteed.** `startBackground` only *queues* the work. Do not write
  UI/logic that depends on the task having started or on how long it takes to begin.
  Reflect state changes in the CompleteFcn/ProgressFcn callbacks, not by assuming timing.
- **No bidirectional communication.** Args flow in at launch; progress streams back out.
  There is no supported way to send commands to a running worker. For interactive control,
  restructure as discrete short-lived tasks or wire `PollableDataQueue` manually.
- **Error handling is built in.** CompleteFcn errors surface via `uialert` + stderr;
  ProgressFcn errors log to stderr and disable further progress (task keeps running). Do
  NOT add try/catch to callback bodies — the infrastructure already protects them.
- **High-throughput progress:** `drawnow limitrate` is not auto-inserted. If streaming
  >30 updates/sec, add `drawnow limitrate` at the end of the progress callback.

---

## Multiple independent tasks

An app can have multiple tasks, each with its own Future and state. Add one per distinct
workflow (App Designer: one `addBackgroundTask` call each; programmatic: one struct
property + one `cleanupBackground` line each). Starting a task that is already running
errors: "Background work is already running. Cancel it first." See per-format docs.

## Implementation note

`AppBuilderModule.p` and `BackgroundTaskModule.p` are internal implementation
details and should never be called directly. Always go through the
`AppDesignerAgentInterface` API (`create`, `open`, `addBackgroundTask`, `finalize`).

Copyright 2026 The MathWorks, Inc.

----
