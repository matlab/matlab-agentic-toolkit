# Verified Measurement Protocol

A profiler tells you where time is *attributed*. It does not tell you what your change will *save*. This protocol closes that gap and produces a machine-checkable record of the result.

## When to use it

| Situation | What to do |
|---|---|
| Exploring, iterating, "is this faster?" | Quick check: `timeit` before/after, report the ratio. Stop here. |
| The user asks for a number to **report, commit, share, or put in a PR** | Full protocol below, all five steps, and write `perf_report.json`. |
| The user gives you a **hypothesis** about what's slow | Full protocol. Step 1 either confirms or refutes it; say which. |
| You are asked to profile with **both** profilers, or the two disagree | Full protocol. Step 1 adjudicates. |

The quick check is fine for your own navigation. It is not fine as a claim. A ratio from two `timeit` calls has no correctness gate, no drift control, and no evidence that the optimized code still does the work.

## Step 1 — Measure the ceiling before you optimize

Before writing the optimized version, measure the ceiling: **delete or hoist the suspected work and re-time end to end.** Confirm the target code is a significant fraction of total time before you spend any effort on it.

This removal-and-re-time step is called **ablation** (the term comes from ablation studies in experimental design). It is recorded in `perf_report.json` as `adjudication_method: "removal_ablation"`, and the rest of this document uses the short name.

```matlab
tFull       = timeit(@() pipeline(data));              % everything
tNoSuspect  = timeit(@() pipelineNoSuspect(data));     % user's suspect removed
tNoDominant = timeit(@() pipelineNoDominant(data));    % dominant stage removed
userSuspectedStageSharePct = 100 * (tFull - tNoSuspect)  / tFull;
dominantStageSharePct      = 100 * (tFull - tNoDominant) / tFull;
```

Each share is the **hard upper bound** on any speedup you can get from that stage. If it is 8%, no rewrite of that stage will produce a 3x end-to-end win, whatever the profiler's `%` column says.

Do this *before* optimizing, not after. Afterwards you are motivated to believe the number.

**Why this step exists.** Profiler attribution is not causation, and the error can be an order of magnitude — a per-iteration allocation on a hot loop was attributed ~9.6% of self-time against a true ~0.7% share (measured), and at a low sample count the same line inverted to 60% while the real hotspot read 0%. Ablation gives you the ceiling: a line attributed 60% but worth 0.7% cannot return more than 1.007x however well you rewrite it.

When the two profilers disagree, or when a single profiler's attribution looks too good, ablation is the tiebreaker. Record:

- `adjudication_method`: `"removal_ablation"`
- `user_suspected_stage_share_pct`: the measured share of the stage the user suspected, from removal ablation
- `dominant_stage_share_pct`: the measured share of the stage that actually dominates, from removal ablation
- `profiler_time_inflation_x`: `sum(ExecutedLines(:,3)) / timeit(@() pipeline(data))` — how far the instrumented run's own accounting exceeds the true unprofiled time. Report it whenever you dispute a `%` column: a large value is evidence that the column's denominator is not the wall clock, so shares read off it do not mean what they appear to. Read it for what it is — `ExecutedLines(:,3)` is *inclusive of callees*, so nesting counts the same seconds once per stack level; it is **not** a measure of instrumentation overhead (for that, use profiled wall ÷ unprofiled wall) and **not** a profiler-selection gate.
- `profiler_attribution_overstatement_x`: a stage's profiler-attributed share ÷ that same stage's measured ablation share. `1.0` means the profiler attributed that stage correctly; `2.0` means it overstated the stage twofold. State which stage it refers to. Optional diagnostic — `profiler_time_inflation_x` is the one to report first.

Do not use one name for both. They answer different questions: inflation is about the *total*, overstatement is about *one stage's slice of it*, and for an honest profiler the first is large while the second is near `1.0`.

## Step 2 — Correctness gate, against the original, in the same session

```matlab
original = originalFunction(input1, input2);
fast     = optimizedFunction(input1, input2);

maxAbsErr = max(abs(original(:) - fast(:)));
optimizedMinValue = min(fast(:));     % independent witness — see below
```

Set `correctness_check` to `"elementwise_vs_original_same_session"` (or `"isequal_vs_original_same_session"` for non-numeric output). Both functions must be called by a run of the current code — a remembered number from an earlier session is not a check.

### Choose the tolerance from the data, not from habit

A fixed `1e-10` is wrong in both directions. The floor on honest floating-point reordering error is set by the magnitude of the output:

```matlab
tol = 100 * eps(max(abs(original(:))));
```

- Error **at or below** `eps(max(abs(original(:))))` is reordering noise. Accept it.
- Error **orders of magnitude above** it is a bug, however elegant the algebra looked.

### Record an independent witness

`max_abs_err` alone is unfalsifiable: a report claiming `0` looks identical whether the check ran or not. So also record a **scalar statistic of the optimized output itself**:

```matlab
optimizedMinValue = min(fast(:));
```

`optimized_min_value` is a value only MATLAB can tell you, and it is not derived from the error. When an algebraically-equivalent shortcut cancels catastrophically, the error and the witness break *together* — a numerically dead output collapses to exactly `0`, while every correct route reports the same nonzero minimum. Two numbers that must agree are much harder to invent than one.

**Catastrophic cancellation is the canonical trap here.** The textbook running-sums variance shortcut, `sqrt((S2 - S1^2/w)/(w-1))`, is algebraically exact and dramatically faster, but on data with a large mean offset it is wrong — measured error orders of magnitude above the true spread, with some outputs collapsing to exactly zero (which is where the witness statistic catches it). Subtract the mean first, then check the result against the tolerance again.

## Step 3 — Mutation test

Confirm the optimized function still *depends on its input*:

```matlab
perturbed = input1;
perturbed(1) = perturbed(1) + 1;
mutationTestPass = ~isequal(optimizedFunction(perturbed, input2), fast);
```

This catches the failure mode a correctness check cannot: code that is fast because it stopped doing the work. A cached return value, a short-circuit that skips the loop, or an accidentally hoisted computation all match the original on the one input you tested and are all caught here. Record `mutation_test_pass`.

## Step 4 — Interleaved paired timing, same session, N ≥ 5

Never compare a baseline timed in one session against an optimized version timed in another. Machine state drifts: thermal throttling, other load, JIT and memory-pool warmth. Sequential blocks (all baselines, then all optimized) hand the entire drift to one arm.

Alternate them inside one loop, in one MATLAB session:

```matlab
n = 7;
tb = zeros(n,1);
to = zeros(n,1);

originalFunction(input1, input2);    % warm both paths first
optimizedFunction(input1, input2);

for k = 1:n
    tb(k) = timeit(@() originalFunction(input1, input2));
    to(k) = timeit(@() optimizedFunction(input1, input2));
end

speedupMedian = median(tb ./ to);    % median of per-rep RATIOS
```

Take the **median of the per-rep ratios**, not the ratio of the means. One slow rep from an unrelated process skews a mean; the median absorbs it. Report `n_reps` so the reader knows how much averaging is behind the number.

**Each timed call must span ≥ 1.0 s.** If the target runs shorter, wrap a repetition loop, and record `profiled_duration_s` — the wall-clock span you actually measured. A speedup quoted from a 2 ms measurement is not a result.

One second, not less, for two independent reasons: it puts the measurement well clear of the timer's own resolution, and if you profile the same region with the Sampling Profiler (100 Hz) it is what buys you ≥ 100 samples. Below ~20 samples a hotspot is indistinguishable from noise.

Derive the repetition count from a pilot measurement rather than picking one — a hand-chosen `nRep` on a fast function silently leaves you back at the noise floor. **Then verify the span you actually achieved**, because `nRep * pilot` overpredicts it: `timeit` strips its own per-call overhead, so inside a loop each call costs *less* than the pilot suggested (measured: ~18% short of the prediction). Trust the measured span, not the prediction.

```matlab
function [nRep, span] = repsForSpan(f, targetS)
    pilot = timeit(f);
    nRep  = max(1, ceil(targetS / pilot));
    span  = timeit(@() repeatN(f, nRep));
    while span < targetS                       % trust the measurement, not the prediction
        nRep = ceil(nRep * 1.2 * targetS / span);
        span = timeit(@() repeatN(f, nRep));
    end
end

function repeatN(f, n)
    for k = 1:n
        f();
    end
end
```

**Size each arm separately, and divide each timing by its own `nRep`.** A shared `nRep` is not merely wasteful — sized for the fast arm it is unrunnable on the slow one. In the worked case the optimized arm needed `nRep` in the thousands; applying that to a 0.23 s baseline would be **hundreds of seconds per timed call**, and there are `2n` of them.

```matlab
[nRepB, spanB] = repsForSpan(@() originalFunction(input1, input2),  1.0);
[nRepO, spanO] = repsForSpan(@() optimizedFunction(input1, input2), 1.0);

for k = 1:n
    tb(k) = timeit(@() repeatN(@() originalFunction(input1, input2),  nRepB)) / nRepB;
    to(k) = timeit(@() repeatN(@() optimizedFunction(input1, input2), nRepO)) / nRepO;
end

speedupMedian     = median(tb ./ to);
profiledDurationS = min(spanB, spanO);   % the weaker of the two spans is what you can defend
```

Report `profiled_duration_s` as the *smaller* achieved span. It is the arm with the least averaging behind it, so it bounds the confidence of the whole comparison.

## Step 5 — Write `perf_report.json`

Every number in this file must come from a variable computed by a run of the current code. Never type a measurement as a literal. `save` each step's results to a `.mat` as it finishes, so a fix to the report re-writes it from those files instead of re-running the steps.

### Always required

| Key | Type | Meaning |
|---|---|---|
| `target` | string | What was optimized |
| `pattern_applied` | string | Which optimization pattern |
| `measurement_mode` | string | `"interleaved_paired_same_session"` |
| `n_reps` | int | Reps in the paired loop, ≥ 5 |
| `baseline_median_s` | double | `median(tb)` |
| `optimized_median_s` | double | `median(to)` |
| `speedup_median` | double | `median(tb ./ to)` |
| `headline_scope` | string | `"end_to_end"` — see below |
| `correctness_check` | string | `"elementwise_vs_original_same_session"` |
| `max_abs_err` | double | From Step 2 |
| `optimized_min_value` | double | The witness, from Step 2 |
| `mutation_test_pass` | logical | From Step 3 |

### Required when applicable

| Key | Type | When |
|---|---|---|
| `adjudication_method` | string | `"removal_ablation"` when you resolved a disputed hotspot |
| `profiler_time_inflation_x` | double | Whenever you dispute a profiler `%` column |
| `profiler_attribution_overstatement_x` | double | Optional; when you compared one stage's profiler attribution against its ablation share |
| `prediction_gap_pct` | double | `100*(predicted - achieved)/achieved`. Always report it if you predicted anything. |
| `profiled_duration_s` | double | Always when a repetition loop was needed; the smaller achieved span, ≥ 1.0 s |
| `kernel_speedup` | double | When you also quote a sub-kernel number |
| `user_hypothesis_supported` | logical | Whenever the user proposed a cause |
| `user_suspected_stage_share_pct` | double | Always when Step 1 ran and the user named a suspect |
| `dominant_stage_share_pct` | double | Always when Step 1 ran |
| `call_count_source` | string | `"builtin_profile_numcalls"` when invocation counts are needed |
| `invocation_count_source` | string | Same — never `"sampling"` |
| `sampling_can_count_invocations` | logical | `false`. The Sampling Profiler cannot count calls. |
| `sampling_profiler_samples` | int | `TotalSamples`. Below ~20 samples a hotspot is noise. |

### The headline number is end-to-end

`headline_scope` must be `"end_to_end"`, and `speedup_median` must be the end-to-end figure. If you made an inner kernel 8x faster and the kernel is a fifth of runtime, the honest headline is about 1.2x. Put the 8x in `kernel_speedup`, where it is informative rather than misleading.

### Report a refuted hypothesis as a result

If the user's suspected bottleneck turns out to be 2% of runtime, that is a successful investigation, not a failure. Set `user_hypothesis_supported` to `false`, record both shares, and report the honest `speedup_median` — including `1.0` when there was nothing to win. Do not manufacture a speedup to have something to show.

### Writing the JSON

```matlab
report = struct();
report.target = 'targetFunction';
report.measurement_mode = 'interleaved_paired_same_session';
report.n_reps = n;
report.speedup_median = speedupMedian;
report.headline_scope = 'end_to_end';
report.correctness_check = 'elementwise_vs_original_same_session';
report.max_abs_err = maxAbsErr;
report.optimized_min_value = optimizedMinValue;
report.mutation_test_pass = mutationTestPass;   % must be logical, not 1

fid = fopen('perf_report.json', 'w');
fprintf(fid, '%s', jsonencode(report, 'PrettyPrint', true));
fclose(fid);
```

Two encoding gotchas that silently produce an unreadable report:

- **Booleans must be `logical`.** `report.mutation_test_pass = 1` encodes as `1`, not `true`, because `jsonencode` maps the double `1`. Use `true`/`false` or `logical(...)`.
- **Use `'PrettyPrint', true`.** Compact `jsonencode` emits `"key":value` with no space after the colon. Both spellings are valid JSON, but pretty-printed output is what a reader — and most simple text checks — expects.

Also note MATLAB's exponent format: `1.318e-09` is emitted as `1.318E-9` — uppercase `E`, no `+`, no zero padding.

## Checklist

Before quoting a performance number as a result:

- [ ] Measured the ceiling **before** optimizing — removed and re-timed the suspected and dominant stages (ablation)
- [ ] Elementwise correctness against the original, same session, tolerance justified from the data
- [ ] Recorded an independent witness statistic of the output
- [ ] Mutation test passes
- [ ] Paired, interleaved, one session, N ≥ 5, median of ratios
- [ ] Each timed call spans ≥ 1.0 s (repetition loop if needed)
- [ ] Headline number is end-to-end
- [ ] `perf_report.json` written, every field from a computed variable

Copyright 2026 The MathWorks, Inc.
