# Sampling Profiler Reference (R2026b+)

Deep-dive material for **Step 2** of the optimization workflow. The Sampling Profiler is a
statistical profiler that samples the single-threaded MATLAB execution stack at a fixed **100 Hz**,
giving per-line and per-function time attribution at low overhead (0–12% typical; deep recursion up
to ~60%). Use the MATLAB profiler (`profile`) instead on releases before R2026b.

> **Prerequisite — R2026b+.** The Sampling Profiler is available only in **MATLAB R2026b or newer**.
> This skill's `sampling_profiler` helper drives it — `addpath` this skill's `scripts/` folder, then
> probe availability with:
>
> ```matlab
> hasSP = sampling_profiler('available');   % true/false; never errors
> ```
>
> Fall back to the MATLAB profiler (`profile`) when `hasSP` is `false`. Don't probe with `exist` —
> the helper file is on the path on every release, so `exist` says yes even where the profiler can't
> run.

## When to use (and when not)

**Use it** to find hotspots, compare two implementations (A/B), or attribute time to source lines at
low overhead. **The code you profile must be called after `'on'`** — a function or script you call,
not code typed at the prompt or written inline next to `'on'` (see *Call the workload* below).

**Do NOT use it to:**
- count function invocations (there is no invocation count — use `profile`)
- time a single short call (<~10 ms gets 0–1 samples) — loop it, or use `timeit`
- profile parallel workers (`parfor`/`parfeval`/`spmd` run off the sampled thread)
- see *inside* builtins or MEX (their time lands on the calling line)

## The protocol: warm up, loop to enough samples, then clean up

Warm up first: one untimed call while the profiler is armed but paused pays the first-call cost
(JIT, first use of a class or file) without sampling it, and `'clear'` discards anything left over.
Looping alone does not do this — measured on R2026b, first-call cost was 16–23% of samples at
`nReps = 1` and still 2–4% at `nReps = 10`. If the code takes different paths for different
inputs, warm up on each kind of input the measured run will see; warming up after `'on'` leaves
slightly less first-call cost than warming up before it. Then raise the repetition count until the
profiled loop runs several seconds — **~10 s ≈ 1000 samples** is the sweet spot; ~1 s / ~100 samples
is the bare minimum and only resolves a single dominant hotspot.

```matlab
nReps = 1;   % raise until the loop below runs several seconds (~10 s ideal)
sampling_profiler('on');
sampling_profiler('pause');                        % armed, not sampling
myBenchmark(args);                                 % warm-up: first-call cost, not collected
sampling_profiler('clear');                        % discard anything from the warm-up
sampling_profiler('resume');                       % start collecting for real
tid = tic;
for r = 1:nReps, myBenchmark(args); end            % measured run — a CALLEE, see below
wallTime = toc(tid);                               % saved timer ID: inner tic/toc can't corrupt it
[~, stacks] = sampling_profiler('off');
sampling_profiler('destroy');                      % mandatory cleanup — skipping it corrupts later runs
```

If the workload can throw, make `'destroy'` run anyway (`onCleanup` or `catch`), as the helpers do.

**Call the workload, don't inline it.** Only frames entered *after* `'on'` are sampled. A loop body
written inline in the function that called `'on'` is already on the stack, so its ticks all land in
the idle count and you get **zero usable data**. `myBenchmark` above,
`quick_profile(@() myCode(args))` and `profile_script('myScript.m')` are all correct for this reason.

## Commands

All commands go through `sampling_profiler(command)`:

| Command | Description |
|---------|-------------|
| `'available'` | `true` if the Sampling Profiler can run on this release, else `false`; never errors |
| `'on'` | Start the profiler and begin collecting |
| `'off'` | Stop collecting and return data: `[~, stacks] = ...('off')` |
| `'pause'` | Stop the sample clock but keep the profiler active |
| `'resume'` | Resume collecting after pause |
| `'clear'` | Discard all collected samples (profiler stays active) |
| `'destroy'` | Tear down the profiler and release its resources (mandatory cleanup) |
| `'data'` | Non-destructive peek: `[~, stacks] = ...('data')` |
| `'status'` | Char string: `'on'` \| `'paused'` \| `'off'` (lightweight state check) |
| `'info'` | Struct: `State`, `Collecting`, `NumFiles`, `HasTimer`, `TimerRunning`, `TotalSamples`, `SnapshotsBuffered` |

Nothing is configurable — extra arguments are ignored. Fixed on R2026b: 100 Hz, at most **127
frames** per snapshot, and a rolling buffer of the last **~120,000 snapshots (~20 min)**.

## Results data model

The `stacks` struct returned by `'off'` or `'data'`:

- `stacks.TotalSamples` — total timer ticks (including idle).
- `stacks.Snapshots` — array of captured stack snapshots. Each has `Timestamp`, `Depth`, and
  `Frames(1:Depth)`:
  - `Frames(f)`: `FileName` (full path), `StartLine`/`EndLine`, `StartColumn`/`EndColumn`.
    **There is NO `FunctionName` field** — use `fileparts(FileName)`; distinguish local functions by
    line range.
  - `Frames(Depth)` = leaf frame (**self** time). Every distinct `file:line` in the snapshot, counted
    once, gets **inclusive** time.

**Implied time:** `stacks.TotalSamples / 100`. For a correctly measured run this ≈ `toc(tid)`,
independent of thread count. If it is far off, distrust the capture and re-run — unless you paused
around a wait, which makes implied < wall by design. It checks that the capture worked, not that the
code was warm: a cold run also reads ≈ wall.

**Idle samples:** `TotalSamples - numel(stacks.Snapshots)` = ticks attributed to no frame — usually
the inline-body trap above, or time at the prompt. A high idle fraction means "check frame
position", not "my code was blocked".

## Analyzing results

1. **Report** wall time (`toc(tid)`), implied time (`TotalSamples/100`), and total samples; verify
   implied ≈ wall.
2. **Rank functions by self time, then read the lines inside the top one** (SKILL.md Key Rule 13).
   `find_hotspots` ranks lines, so sum `hot.samples` per function first (`hot.file`; split local
   functions by line range).
3. **Before claiming a bottleneck**, check the hot line against the blind spots below — describe
   where the time really goes, not the frame label.
4. **State uncertainty** for any hotspot under ~20 samples — that is noise. Two sites whose counts
   are within noise of each other are a tie — report them as one, don't rank them.

## Blind spots and traps

- **Builtins, MEX and blocking waits** (`sort`, `eig`, MATLAB's `pause`) have no frame of their own:
  the time is real and lands on the **calling line as self-time**. To leave a known wait out, bracket
  it with the profiler's `'pause'`/`'resume'`.
- **Anonymous functions and `feval`/`arrayfun`/`cellfun`** — no frame of their own; the time lands on
  the calling line, and the call-graph shape through them is wrong.
- **P-coded files** (`ver`, `verLessThan`, first-use `datetime`/`readtable`/`figure`) — a `.p` with no
  `.m` reports a file-level total at **line 0** (measured: a `ver` call on a hot path put 95.7% of
  samples in the P-file). The time is real and unactionable: confirm it by removing the call and
  re-timing (Step 5), profile the pure-compute code in isolation, and don't profile plotting code.
- **A per-iteration allocation can read high** on a hot loop. The genuine hotspot still dominates a
  well-sampled run; confirm a suspicious per-line split with removal ablation (Step 5).
- **Local function shadows a file** — in-file calls resolve to the local function; map frames by the
  file's function line ranges.
- **Deep stacks (>127 frames)** keep the innermost 127 (leaf kept, root dropped): at `Depth == 127`,
  `Frames(1)` is a mid-stack frame, not the entry point.
- **Runs over ~20 min** overwrite the oldest snapshots; `TotalSamples > numel(Snapshots)` with no
  idle explanation means the buffer wrapped — split the region.
- **`@() run('script.m')` fails** ("Attempt to add variable to static workspace") — use
  `profile_script`.

## A/B comparison and tests

Profile each version with `profile_function` (saves a `.mat`), using **fixed work both sides**
(`for i=1:N`, never `while toc<T`), then diff with `compare_profiles`. That compares **where the
time went** — relative shares, never raw sample counts (overhead and totals differ per config); the
speedup itself comes from Step 5's interleaved timing. Never run two profiling sessions at once.
`make_ab_commands('implA(data)', 'implB(data)', 'Setup', 'data = …;')` prints the two fresh-session
`matlab -batch` commands plus the matching `compare_profiles` call.

For `matlab.unittest` / `matlab.perftest` tests, use `profile_test` (runs `withNoPlugins`), then
`filter_test_frames(stacks, 'tMyTest')` — or `compare_profiles(..., 'FilterTest', ...)` — to drop
framework-only samples.

## Script index — which script when

`addpath` this skill's `scripts/` folder first. Fastest start: `quick_profile(@() myCode(args))` —
it makes one measured call, so that call must already run several seconds; otherwise use
`profile_function(@() myCode(args), 'MinTime', 10)`, which loops to ~10 s.

| Call → output | Use it for |
|---|---|
| `sampling_profiler(cmd)`: `'available'` → logical; `[~, stacks] = sampling_profiler('off')`; `'status'` → `'on'`/`'paused'`/`'off'` | Driving the Sampling Profiler yourself (commands above) |
| `assertSamplingProfiler()` → errors with the `profile` fallback if the Sampling Profiler is missing | A guard before any helper below |
| `[stacks, hot] = quick_profile(@() f(x), topN)` → prints the top-N report | One measured call that already runs several seconds |
| `results = profile_function(@() f(x), 'MinTime', 10, 'Tag', 't')` → `.stacks`, `.baselineTime`, `.profileTime`, `.resultFile` (`sp_results/t.mat`) | Short workloads (loops to `MinTime` s), a baselined run, or a saved result |
| `[stacks, hot] = profile_script('myScript.m', topN)` → prints the report | A `.m` script file (can't use `@() run(...)`) |
| `results = profile_test('tMyTest.m', 'Tag', 't')` → same fields as `profile_function` | `matlab.unittest`/`perftest` files, run `withNoPlugins` |
| `hot = find_hotspots(stacks, topN)` → struct array `location`, `file`, `line`, `samples`, `selfPct` | Acting on the hotspots in code (prints nothing) |
| `print_hotspot_report(stacks, maxEntries)` → prints self %, counts and caller chains | A human-readable summary |
| `compare_profiles('a.mat', 'b.mat', 'Label0', 'A', 'Label1', 'B')` → prints, writes `comparison_report.md` next to `a.mat` | Diffing two saved results |
| `filtered = filter_test_frames(stacks, 'tMyTest')` → stacks without framework-only samples | Removing test-framework overhead |
| `annotate_source_lines(stacks)` → prints sampled lines with counts and 2 lines of context | Line-level annotation of hot files |
| `make_ab_commands('f(x)', 'g(x)', 'Setup', 'x = ...;')` → prints two `matlab -batch` commands and the `compare_profiles` call | A/B across two fresh sessions |

Copyright 2026 The MathWorks, Inc.
