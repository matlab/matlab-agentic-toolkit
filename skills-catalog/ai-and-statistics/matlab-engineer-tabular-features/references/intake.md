# Intake — collect the run, assemble the table, screen it

Intake gathers everything the run needs, turns the user's data into **one plain
in-memory table** of predictors + response, and removes predictors that would be
dead weight for any producer. Everything after this phase — profiling, splitting,
generation, selection, assessment, delivery — operates on that screened table.

Intake does three things, in order:

1. **Collect** the run parameters — the full list, with rationale and asking order,
   is §1 below.
2. **Assemble & gate** — load the data into a plain table, halt on unsupported
   container types.
3. **Screen** — drop constant and mostly-missing predictors before anything
   downstream sees them.

> **Ordering invariant — the split precedes any fitted extraction.** The
> train/test split is a function of the **response and the observation set, never
> of the features**, so deciding it early introduces no leakage. On the ordinary
> tabular path this is automatic: assembly yields the full table, and the split
> (see *Handing off*) runs before `generateFeatures(TrainTbl, …)`. On the
> **domain-routed path, extraction happens during assembly**, so problem type and
> the split must be settled **first** — over the raw observations, from the
> response — and carried into the domain skill so any fitted extraction state is
> trained on the training observations only ([domain-routing.md](domain-routing.md)
> §4). Triggering a domain extractor before the split is decided is the leakage bug
> to avoid: it fits extraction on all rows.

---

## 1. Collect

Ask the user for these. Confirm each rather than guessing.

| Item | Why it's needed |
|---|---|
| **Data source** | a `.mat` path + variable, a workspace variable, or a predictor table + a separate response vector |
| **Response** | the target: a column name already in the table, **or** a separately-supplied vector of values (see the polymorphic response below) |
| **Dataset name** | names the deliverables (`fe_transform_<dataset>.m`, report files); sanitized to a valid identifier |
| **Output directory** | where deliverables are written — **hard-halt, always confirm** before writing anything |
| **Domain description** | **Always ask — required, not optional.** Free text describing what the data *is* and where it came from; it is the sole input to the domain-routing decision ([domain-routing.md](domain-routing.md)), which determines whether the pool is built by a purpose-built domain extractor or by generic generation. Do not infer the domain from column names and do not proceed to generation without an explicit answer. See the verbatim prompt below |
| **Separate test set?** | **Always ask.** If they have no separate test set, `reserveHoldoutForUser` sets aside a slice *untouched* for their own testing (default **20%**) and the rest becomes the **working data**; if they do, the whole dataset is working data. State the 20% default and let them override the fraction — captured as `ReserveFraction`, passed through as `HoldoutFraction`; don't ask for a number separately, just offer the default so they can accept or change it |
| **Model family** | `agnostic` (default) \| `tree_ensemble` \| `linear` \| `kernel_distance` — steers generation ordering, the selection ranker panel, and the baseline panel. `agnostic` trains all three families and runs the full 5-ranker panel; a declared family trains through that family alone and gates selection to its own probe + the model-agnostic rankers. A model name outside this taxonomy is handled gracefully — see below |
| **Primary lens** *(agnostic only)* | which of the three families headlines the baseline — `bag` (default, the bagged ensemble) \| `linear` \| `kernel`. Ask **only** when the family is `agnostic`; state the default and offer the override (see below). A declared family already fixes its own lens, so skip this |
| **Evaluation strategy** | how the working data is evaluated — **`holdout`** (one train/test split, point estimate) or **`cross_validated`** (k-fold, mean ± std). **Recommend by size, always confirm** (below) |
| **Report** | generate the written report at the end? **Default yes** — offer opt-out here so the cost is known up front ([report.md](report.md)). Captured as `GenerateReport`, this gates **both the report and every figure** (the `fig_*.svg` plots exist only to illustrate it, so an opt-out skips all `plotSelection*`/`plotValidation*` calls). The inference script + state `.mat` ship either way |
| **Row budget** *(optional)* | if the user volunteers a working-set size for speed (*"~1000 rows is fine"*), pass it to the stability gates as `MaxRows`; don't ask proactively. Unset → default 3000 |

The model family, domain description, evaluation strategy, report choice, and any
row budget feed later phases — capture them now even though they aren't used until
generation, assessment, and reporting.

**Gate before proceeding.** Collect is a required conversation, not a silent
default-fill. Before running *any* code past `screenPredictors`, get an explicit
answer to **every** item in the table above — missing any, ask; do not assume the
default and move on. The **output directory** and the **domain description** in
particular must have explicit user answers before generation.

**Ask one at a time — don't dump the list.** Every item below must be **asked and
answered** — offer a recommended default where one exists (so the user can just say
"sounds good"), but never silently assume it or skip a question because the opening
request seems to cover it. Where you inferred something from that request, **state
what you inferred and have the user confirm it** — a confirmation is an answer; an
assumption is not. Walk through it conversationally in this order: (1) data source,
response, dataset name; (2) output directory (the hard-halt); (3) domain description
(the routing input); (4) separate-test-set (with the reserve fraction, default 20%,
when they have none); (5) model family (+ primary lens if `agnostic`); (6)
evaluation strategy; (7) report opt-out. A short guided exchange, not a form.

**Asking about the domain.** State it plainly and wait for an answer — the routing
decision cannot be made without one: *"Before I build features, tell me what this
data is and where it comes from — the subject matter, how it was measured or
collected, any domain it belongs to (sensor signals, financial records, clinical
measurements, and so on). If a specialized extractor fits your domain I'll route to
it for far better features than generic generation; if it's ordinary tabular data,
say so and I'll use the generic path."* Do not infer the domain from column names,
and do not fall through to generic generation on silence.

**Recommending the strategy.** Favor `holdout` when a 20% slice of the working
data is a trustworthy test (rough guide: a few hundred+ rows, and for
classification ~30+ minority-class rows in the slice); favor `cross_validated`
when the data is too scarce for one split to be reliable. State the recommendation
with its one-line reason and let the user override. Either way the delivered
recipe is refit on all working data — see [deliver.md](deliver.md).

**Primary lens under `agnostic`.** The agnostic baseline panel trains all three
families but headlines on **one** of them — its metrics become the reported
top-line and drive cross-validation. Don't expect the user to raise this; state
the default and offer the choice: *"With an agnostic model I'll headline the
baseline on the bagged ensemble by default — tell me now if you'd rather headline
on linear or kernel."* Record their answer as the primary lens; leave it at the
bagged-ensemble default otherwise. This applies to `agnostic` only — a declared
family already fixes its own lens, so there's nothing to ask.

**Out-of-taxonomy model names.** Users name specific models ("discriminant", "QDA",
"kNN", "naive Bayes") that aren't one of the four families. Don't reject or silently
coerce: say you won't train *that* model (the skill stops at features), then map by
inductive bias to the closest family — linear surface → `linear`; distance/kernel or
quadratic → `kernel_distance`; trees → `tree_ensemble`; no clean proxy → `agnostic`
(trains all three lenses). Name the proxy and which baseline column to watch, and
record the mapping in the report's intake summary.

---

## 2. Assemble & gate

Load the data into a **plain in-memory `table`**. This skill *operates* on an
ordinary in-memory table — that is its input contract, not a restriction on where
the data may originate:

- A plain `table` (or a numeric/categorical matrix that reads cleanly into one)
  proceeds directly.
- A `timetable`, `tall`, `gpuArray`, `datastore`, or other non-plain container
  does **not** proceed as-is, but this is **not a dead end** — it means a
  tabularizing step must run *first*. Many such containers are the raw form of a
  domain modality that a domain skill (or a simple conversion) turns into a table:
  check [domain-routing.md](domain-routing.md), run that step, then **re-enter
  intake with the resulting table**. Only halt outright when no tabular path
  exists (e.g. genuinely out-of-memory `tall`/`datastore` data that can't be
  materialized). Never silently coerce — say what was received and confirm the
  tabularizing step with the user before running it.
  - **Finish Collect before any tabularizing step runs.** Response, problem type,
    and the split policy are decided *first* (they need only the raw observations
    and their labels, which exist pre-extraction), then handed to the domain skill
    so its extraction fits on training observations only. Do not trigger a domain
    extractor the moment a non-tabular container is detected — that runs extraction
    before the split exists and leaks. See the ordering invariant above and
    [domain-routing.md](domain-routing.md) §4.

**Confirm what was loaded.** Once the table is assembled, state back what you have
before generating anything: the observation count, the predictor count, the
resolved response column, and the detected problem type (classification vs.
regression, with the class balance for classification). One or two sentences — it
lets the user catch a wrong variable, a mis-detected problem type, or an unexpected
row count *before* the pipeline runs on it. If profiling has not run yet, state the
shape and response now and the problem type right after `profileForSplit`.

### Polymorphic response — one table either way

The response may already be a column of the loaded table, or it may arrive as its
own variable (the common "X table + y vector" shape). `screenPredictors` handles
both — its `Response` argument is polymorphic, so you pass through the same call
regardless:

- **Response is a NAME** (a scalar string): it identifies the response column
  already in the table (a Wilkinson formula like `"Y ~ x1 + x2"` is also accepted,
  its left-hand side naming the column to protect).
- **Response is DATA** (a column vector, a string array of labels, or a
  single-variable table): it is the separately-supplied response, and gets
  **concatenated** to the predictors before screening. A nameless vector is
  appended under `ResponseName` (default `"Response"`); a **single-variable table
  is self-naming** — its own variable name becomes the response column name.

This is why assembly and screening are a single step: `screenPredictors` does the
concatenation, so downstream always receives one predictors + response table.

---

## 3. Screen — `screenPredictors`

Run the light-weight structural screen **before** profiling, splitting, or
generation. It drops two kinds of useless predictor so no producer or ranker
wastes effort on them:

- **Constant** predictors — effectively one distinct non-missing value (zero
  variance; nothing to learn, and a source of degenerate transforms). Numeric
  columns use a scale-relative `ConstantTolerance` (default `1e-9`) so
  floating-point noise around a single value still counts as constant while a
  column with real, if small, variation is kept; non-numeric columns use an exact
  distinct-value count.
- **Mostly-missing** predictors — more than `MissingThreshold` (default 0.95) of
  rows missing (effectively empty). The cutoff is intentionally high: many
  learners and the generator's own imputation handle moderately-missing columns
  natively, so intake prunes only the near-empty ones and leaves the missingness
  call to the producer.

```matlab
% Response already a column of RawTbl:
[ScreenedTbl, ScreenInfo] = screenPredictors(RawTbl, Response);

% Response supplied separately as a vector -> concatenated as "Response":
[ScreenedTbl, ScreenInfo] = screenPredictors(X, y);

% ...or under a chosen name, with a stricter missing cutoff:
[ScreenedTbl, ScreenInfo] = screenPredictors(X, y, ...
    ResponseName="Target", MissingThreshold=0.3);
```

Key behavior (full rationale in the function header):

- **The response column is never screened** — it is always kept, whatever its
  contents.
- **Structural, not response-dependent.** The screen never inspects response
  values, so running it on the whole table *before* the train/test split
  introduces **no leakage** — constant-ness and missingness are properties of the
  predictor alone.
- **The missing cutoff is strictly greater-than.** At the default threshold a
  column is dropped only when *more* than 95% of its rows are missing; anything at
  or below 95% is kept.
- **Deliberately minimal.** Imputation, encoding, scaling, and richer feature
  construction are **not** intake's job — they belong to the generator
  (`gencfeatures`) or the domain skill. Intake only removes columns that are dead
  weight for any producer.
- **All-degenerate is an error.** If every predictor is dropped, it raises
  `screenPredictors:noPredictorsRemain` — a dataset with no usable predictor
  cannot proceed.
- **Too few rows is an error.** If the assembled table has fewer than 2
  observations, it raises `screenPredictors:tooFewObservations` — there is nothing
  to generate, split, or rank. The check runs on the assembled table, so it
  applies whether the response was a name or supplied separately.

`ScreenInfo` carries `.Kept`, `.Dropped`, `.DroppedReasons` (`"constant"` |
`"missing>NN%"`), `.NumDropped`, `.MissingThreshold`, `.ConstantTolerance`,
`.CombinedResponse`,
`.ResponseVar`, and `.Reasoning`. **Report what was dropped and why** — a silently
shrunk predictor set reads as data loss otherwise. Carry `ScreenInfo` into the
report's intake summary.

---

## Handing off

After intake the orchestrator holds a screened predictors + response table and
the resolved response name (`ScreenInfo.ResponseVar`). Profile, reserve, then
split:

```matlab
rng(0, "twister");                                       % seed the reserve+split draw once, here
Profile = profileForSplit(ScreenedTbl, ScreenInfo.ResponseVar);
[WorkingIdx, UserHeldOutIdx, ReserveInfo] = reserveHoldoutForUser( ...
    ScreenedTbl, Profile.ProblemType, ScreenInfo.ResponseVar, ReserveForUser = HasNoSeparateTest);
[Splits, SplitDecision] = splitStrategy(ScreenedTbl, Profile.ProblemType, ...
    ScreenInfo.ResponseVar, Subset = WorkingIdx, EvaluationStrategy = EvaluationStrategy);
```

`profileForSplit` fixes the problem type and class balance. `reserveHoldoutForUser`
returns the `WorkingIdx` all downstream phases operate on. The reserved slice is a
**random sample** drawn across the whole dataset (stratified by class for
classification), so data arriving sorted by response or time isn't handed one end of
itself. Seed `rng(0, "twister")` once before this call — the same place the
assessment partitions are seeded — so the carve repeats run to run. Pass the user's
chosen fraction as `HoldoutFraction = ReserveFraction`; omit for the 0.2 default.
`splitStrategy` then
sets `Splits.TrainIdx`/`.TestIdx` over those working rows — a train/test split
under `holdout`, or all working rows with an empty `TestIdx` under
`cross_validated`. Generation is fit on `TrainIdx` only — see
[feature-pool.md](feature-pool.md).

**Materialize the reserved slice as a named table** when a carve happened, so the user
has a real test set to feed the delivered inference script — from the *original loaded*
rows (their raw columns). Convention: whatever the table variable is called, the slice
is that name with a `_test` suffix — so for a table `RawTbl`:

```matlab
RawTbl_test = RawTbl(UserHeldOutIdx, :);   % only when UserHeldOutIdx is non-empty
```

**Then narrate it in plain words**, naming that variable, the actual fraction, and the
method actually used — e.g. *"I've set aside <pct>% of `RawTbl` as an untouched test
set (`RawTbl_test`, <N> rows, <method> sampling); the other <M> rows are the working
data."* Take `<pct>`/`<N>`/`<M>` and `<method>` from `ReserveInfo` — `Method` is
`stratified` for classification and `random` for regression, so say whichever ran; none
of it is a fixed number or word.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
