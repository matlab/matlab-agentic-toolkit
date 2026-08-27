# Select — consensus ranking of the feature pool

Selection is this skill's distinctive value. Rather than trusting one selector
(which is what `gencfeatures`/`genrfeatures` do internally, tied to a single
learner), it runs a **panel of complementary rankers**, fuses their verdicts by a
data-driven **consensus voter**, and cuts at the score elbow. One call does all of
it: `runConsensusSelection`.

Selection **evaluates** the pool; it does not necessarily shrink it. A broad
`gencfeatures` pool is almost always cut substantially; a compact domain-extracted
pool may pass through largely intact. Report the outcome, never assume a
reduction (see [feature-pool.md](feature-pool.md)).

Selection runs on the **training rows only** — the pool table fit on the split
from [`splitStrategy`](intake.md). The held-out test rows never enter ranking.

---

## The call

```matlab
[SelectedNames, VoteTable, PanelInfo] = runConsensusSelection( ...
    FullEng(TrainIdx, :), Response, ProblemType, ...
    ExcludeFeatures = GenInfo.BinaryReliant, ...   % [] unless a dummy binarization ran
    TargetModel = TargetModel);                    % gates the ranker panel
```

- **`FullEng(TrainIdx,:)`** — the engineered pool + response, **train slice only**
  (the canonical `FullEng` spans all rows; ranking sees only the training rows).
  The full mixed pool is ranked; numeric and categorical engineered features share
  one column universe, so the fused vote is well defined.
- **`Response`, `ProblemType`** — carried from profiling.
- **`ExcludeFeatures`** — names to drop *before* ranking. Pass
  `GenInfo.BinaryReliant`: the Weight-of-Evidence columns from a multi-class
  dummy binarization are meaningless once the real response is restored, so they
  must never be ranked or selected. Empty otherwise.
- **`TargetModel`** — the declared model family, carried from intake. It gates
  which embedded ranker probes run (see step 1). `agnostic` (the default) keeps the
  full panel; a declared family narrows the panel to that family's probe plus the
  two model-agnostic rankers.

---

## What it does, in order

1. **Rank with a diverse panel** (`scoreFeaturePanel`) — up to five rankers: the
   four `genfeatures`-utility forks (MRMR, OOB permutation, NCA, LASSO) plus
   chi-square / F-test. Every ranker is aligned to the shared feature universe and
   is skipped on error rather than aborting the panel (skips are reported in
   `PanelInfo.Skipped`). **The `TargetModel` family gates which of the three
   embedded probes run**, mirroring how `gencfeatures`/`genrfeatures` tie their own
   embedded selector to the target learner: `linear`→LASSO, `tree_ensemble`→OOB,
   `kernel_distance`→NCA. A declared family runs *only* its probe plus the two
   model-agnostic rankers (MRMR + the univariate filter) — three methods, still a
   real consensus vote. `agnostic` (the default) keeps all five, since no single
   learner is targeted and ranker diversity is the whole point. **One exception:**
   LASSO ranks binary classification and regression only, so a `linear` family on a
   *multiclass* response has no usable probe and reverts to the full five-method
   panel. `PanelInfo.PanelMode` records the choice (`"full"` or `"family:<name>"`).
2. **Pick the voter by agreement** — by default (`VoterMethod="auto"`) mean
   pairwise Spearman ρ across the panel's rankings chooses the fusion rule:
   **ρ ≥ 0.7 → Borda** (positional, rewards consistent placement); **ρ < 0.7 →
   Reciprocal Rank Fusion** (robust when rankers disagree, emphasizes each
   method's top picks). Override with `VoterMethod="borda"`/`"rrf"`/`"majority"`
   to force a rule. Reach for **`"majority"`** (order-blind top-K vote) only when
   you trust *which* features each ranker picked but not the *order* — e.g. a
   tie-heavy significance filter whose ranking is noise near a p-value floor. The
   agreement gate measures whether orderings correlate, not whether they are
   meaningful, so it can never select majority for you; it is an expert opt-in and
   the report labels it as a user override.
3. **Cut at the score elbow** (`computeNSelect`) — the elbow is the point of
   maximum **below-chord** distance on the sorted consensus scores; a convex curve
   cuts at its knee, a linear or concave decline has none so all candidates are
   kept. The elbow alone sets the count: there is no per-N wrapper search — cutting
   the fused score vector *is* the elbow.

---

## Outputs

| Output | What it is |
|---|---|
| `SelectedNames` | `(1,:) string` — the delivered feature names, consensus order |
| `VoteTable` | `table(Feature, Score, Rank, Selected)` in consensus order — the per-feature record for the report's vote-table chapter |
| `PanelInfo` | struct: `.Rankers`, `.Skipped`, `.PanelMode` (`"full"`/`"family:<name>"`), `.VoterMethod` (`"borda"`/`"rrf"`/`"majority"`), `.VoterSelectedBy` (`"auto"`/`"user"`), `.MeanAgreement`, `.NSelect`, `.PoolSize`, `.Excluded`, `.PredVars`, `.RankMatrix`, `.Reasoning` |

Announce the outcome from `PanelInfo.Reasoning` (it states the ranker set, voter,
mean ρ, and `NSelect of p`), and state the selected count and names in the
user-facing message.

The consensus heatmap reads its per-method ranks straight off `PanelInfo` — no
re-ranking. Draw it **only when the report is on** (`GenerateReport`); a report
opt-out skips it (the consensus decision is still reported in words either way):

```matlab
if GenerateReport
    % Pass the FULL matrix; plotSelectionConsensus orders rows best-consensus-first,
    % caps at max(35, NSelect) so no shipped feature is hidden, and names any omitted
    % count in its subtitle. RankMatrix rows align to PanelInfo.PredVars.
    plotSelectionConsensus( ...
        PanelInfo.RankMatrix, ...       % (features x methods) ranks
        PanelInfo.PredVars(:), ...      % (features x 1) row labels
        PanelInfo.Rankers, ...          % (1 x methods) column labels
        OutputDir, NSelect = PanelInfo.NSelect);
end
```

---

## Errors and edge cases

- **`runConsensusSelection:responseNotFound`** — `Response` is not a column of
  the passed pool table.
- **`runConsensusSelection:tooFewFeatures`** — fewer than 2 candidate features
  remain after exclusions. A pool that small cannot be ranked; if it came from a
  "skip" generation (originals passed through, no engineered features), there is
  nothing for consensus to do — deliver the originals and say so.
- **Selection keeps everything** — a legitimate outcome for a compact pool. The
  bound clamps to `p` and the elbow may sit at the end. Do not describe this as a
  failure to select.

---

## Handing off

After selection the orchestrator holds `SelectedNames` (the delivered set),
`VoteTable`, and `PanelInfo`, alongside the pool `Recipe`. Assessment
([assess.md](assess.md)) grades both the pipeline and this selection decision;
delivery ([deliver.md](deliver.md)) reproduces `SelectedNames` on new data via the
recipe.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
