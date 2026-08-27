# Reproduce the pool — an on-request generation recipe

> **Read this only on explicit user request.** A normal run — delivery, reporting,
> everything — completes without it. Open it solely when the user asks for the recipe
> that *generated* the pool (to re-run generation themselves), not the inference
> script that replays it.

The standard deliverable is the self-contained *inference* script
([deliver.md](deliver.md) §3): it replays the **frozen** recipe to reproduce the exact
shipped columns, and stays the source of truth for feature *values*. This page answers
a different ask — *"give me the recipe that built the pool, so I can re-run generation
myself"* — which is a from-scratch regeneration, not a replay. There is no file-writer
for it (that would duplicate `writeInferenceScript` while promising less); assemble it
inline from the run's own captured pieces.

> **Generation is not seeded.** Some engineered features are fit
> non-deterministically, so a re-run is **not** guaranteed bit-identical to the shipped
> pool. This recipe is a readable account of *how* the pool was built, verified by
> comparison (below) — not a promise of identical values. For exact values, the
> inference script.

---

## SMLT path — emit the underlying generator call

Don't call `generateFeatures` (or anything under `scripts/`, off the user's path — the
self-containment rule the inference script follows, [deliver.md](deliver.md) §3). It is
a thin wrapper over one `gencfeatures`/`genrfeatures` call — base SMLT, available to the
user — so emit *that call* with the run's arguments baked in as literals.

**Full pool is the product; filtering is an optional tail.** Emit the function so it
returns the whole pool by default and applies the `SelectedNames` filter only when the
caller passes them — one file serves both "give me the delivered set" and "give me the
whole pool to re-select/explore."

Three run values to bake in:

- `GenInfo.TargetLearner` and `GenInfo.Standardization` — the *resolved* concrete
  values (never `"auto"`), not the pre-resolution knobs.
- `q` — the `NumFeatures` the run **requested**, from the run's `OptArgs`
  ([deliver.md](deliver.md) §2). **Not** `GenInfo.PoolSize` (that's the capped output
  count, which is smaller). Usually `intmax('uint64')` (full pool); a wide-input run
  carries its explicit bound. When `q` exceeds the true max — always for the `intmax`
  default — the generator warns `...FeauresRequestedGreaterThanMax`; that's expected,
  so suppress it by id with a comment saying why, exactly as the run does.

```matlab
function Pool = reproducePool(RawTbl, SelectedNames)
%reproducePool Regenerate the SMLT feature pool this run built, optionally filtered.
%   Pool = reproducePool(RawTbl) returns the FULL generation pool.
%   Pool = reproducePool(RawTbl, SelectedNames) filters to the delivered set.
%   Literals below are frozen from the original run.
    arguments
        RawTbl table
        SelectedNames (1,:) string = string.empty(1, 0)   % optional; empty => full pool
    end

    WorkingIdx = <WorkingIdx literal>;           % the rows the run generated on
    q = intmax("uint64");                        % the NumFeatures the run requested

    % A full-pool request (q = intmax) asks for more features than exist, so the
    % generator warns it capped the count. Expected -- suppress it by id.
    WarnId = "stats:featlearn:genfeatures:FeauresRequestedGreaterThanMax";
    Prev = warning("off", WarnId);
    RestoreWarn = onCleanup(@() warning(Prev));

    WorkingTbl = RawTbl(WorkingIdx, :);
    [Transformer, ~] = gencfeatures(WorkingTbl, "<Response>", q, ...
        TargetLearner = "<GenInfo.TargetLearner>", ...
        IncludeInputVariables = "include", ...
        TransformedDataStandardization = "<GenInfo.Standardization>");
    Pool = transform(Transformer, RawTbl);       % full pool, over all rows

    if ~isempty(SelectedNames)                   % optional filter to the delivered set
        Missing = setdiff(SelectedNames, string(Pool.Properties.VariableNames), "stable");
        assert(isempty(Missing), "Regenerated pool is missing: %s", strjoin(Missing, ", "));
        Pool = Pool(:, cellstr(SelectedNames));
    end
end
```

**Regression** is identical — swap `gencfeatures` for `genrfeatures` (same arguments).
It has no multi-class restriction, so the WoE branch below never applies to it.

**WoE (response-dependent) columns.** If the caller passes `SelectedNames`, they're
already dropped for free (WoE is never selected). Only when returning the *full* pool
and the run used a dummy binarization (`GenInfo.UsedDummyResponse` true — a binary-only
learner on a multi-class target) do you drop them explicitly; add before returning `Pool`:

```matlab
D = describe(Transformer);
IsWoE = contains(string(D.Transformations), "Weight of Evidence", IgnoreCase = true);
Pool = Pool(:, ~ismember(string(Pool.Properties.VariableNames), string(D.Properties.RowNames(IsWoE))));
```

That same dummy run also needs its binarization reproduced on `WorkingTbl.(Response)`
before the `gencfeatures` call (most-frequent class vs rest) — inline the few lines
rather than calling the skill's helper.

---

## Domain path — `Recipe.Fit` or `Recipe.Apply`

The recipe already carries the generator, so there's nothing to reconstruct — reuse the
`reproducePool` shape above, replacing the `gencfeatures`/`transform` body with one line:

- **`Recipe.Fit`** (when the domain skill supplied it) — the *re-runnable* producer
  `[EngTrain, Apply, ...] = Fit(RawRows, Response, ProblemType, TargetModel)`, verified
  at capture to regenerate the pool's feature names ([buildRecipe](../scripts/buildRecipe.m)).
  The true "regenerate the pool" handle.
- **`Recipe.Apply`** — the frozen extraction: a deterministic replay, not a refit. All
  there is when `Fit` is absent; reproduces the pool exactly but can't refit on new rows.

So `Pool = <Recipe.Fit(...) or Recipe.Apply(RawInput)>;` then the same optional filter.
If neither handle covers the ask (e.g. regenerating from upstream raw signals), hand
back to the originating domain skill ([domain-routing.md](domain-routing.md)); its pool
flows through the same filter.

---

## Verify against the shipped pool

Because generation is unseeded, **prove** the regeneration against what the run
delivered (the frozen-recipe truth):

```matlab
Regenerated = reproducePool(RawTbl, SelectedNames);
Shipped = selectFeatures(Recipe, RawTbl, SelectedNames);
assert(isequal(string(Shipped.Properties.VariableNames), ...
               string(Regenerated.Properties.VariableNames)));   % same names, same order
Dev = max(abs(Shipped{:, :} - Regenerated{:, :}), [], "all");
fprintf("Max deviation from shipped pool: %.3g\n", Dev);
```

Matching names in order is the hard contract; near-zero values confirm fidelity. A
non-trivial deviation is expected only on the non-deterministically-fit columns —
surface it to the user (it's the cost of regenerating rather than replaying), don't
hard-fail on it.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
