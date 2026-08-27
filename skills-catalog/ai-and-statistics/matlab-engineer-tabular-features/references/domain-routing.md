# Domain Routing — hand pool-building to a domain skill

Some data belongs to a specialized domain where purpose-built extraction yields
far better features than generic `gencfeatures` could — whether the data arrives
in a non-tabular modality or as a domain-specific table. When an installed skill
covers that domain, route the [feature-pool](feature-pool.md) phase to it and
keep everything downstream unchanged.

This file defines how that routing decision is made and executed.

---

## How discovery actually works

**Discovery is matching against the skill list already in context — not a
filesystem scan, not a registry file.**

The harness injects the installed-skills list (each skill's name + description)
into the conversation. That list is the source of truth. "Discovering" a domain
skill means **semantically matching the user's data against those description
lines** — nothing is read from disk, and no registry is maintained.

Do **not** walk `~/.claude`, glob for `SKILL.md` files, or hard-code a table of
known domain skills. Skills come and go with what the user has installed; the
injected list already reflects that. Hard-coding names would rot.

---

## The routing decision

Run this at the start of the feature-pool phase.

### 1. Decide whether a domain skill applies

**This skill is tabular-only.** Every phase — pool contract, selection,
assessment, delivery — operates on a table of predictors + response, and the pool
always arrives *as a table*. The only question this step answers is **who should
produce that table**: the generic `generateFeatures` (`gencfeatures`) path, or a
domain-specific extraction skill.

The deciding factor is **whether a domain skill's domain fits the data — not how
the data is stored.** Storage shape and domain applicability are independent:

- Data stored as a **table** does *not* rule out a domain skill. Raw domain
  measurements are often stored tabularly yet still call for domain-specific
  extraction — a domain skill will produce far better-justified features than
  generic `gencfeatures` would, even though the input was a `.csv` or `table`.
- Data in a **non-tabular modality** (a signal vector, a `timetable`, an ensemble
  datastore) always needs a domain skill to become a feature table, because
  `gencfeatures` cannot consume it at all.

So consider a domain skill **whenever the data's subject matter matches an
installed domain extractor**, regardless of its storage shape. Use the generic
`generateFeatures` path when no domain skill fits the domain — that is the
default for ordinary predictor tables with no specialized structure.

### 2. Match against the injected skill list

Read the user's **data modality + domain description** (collected at intake) and
compare it to the name+description of each installed skill. A skill is a
candidate when its description clearly covers this data's domain and modality —
that is, when the data's subject matter falls squarely inside what the skill
advertises it extracts features for.

Judge by the description text, not by a remembered list. If two skills plausibly
match, prefer the one whose *When to Use* / *When NOT to Use* boundaries fit the
data most precisely.

### 3. Confirm before invoking

**Never invoke a domain skill silently.** State the match, name the candidate
skill, give the reason, and present the choice as **two named paths** — the domain
skill (recommended default) *or* this skill's own generic feature generation — so
the user sees the alternative explicitly rather than only being able to decline.
Follow this template (fill the bracketed parts from the actual match):

> Your data looks like **[domain / modality]**. Two ways to build the feature
> pool:
> - **[`skill-name`]** (recommended) — purpose-built for this domain; it produces
>   the features, then I run consensus selection and assessment on them.
> - **Generic generation** — this skill's own `gencfeatures`-based path, no domain
>   skill.
>
> I'd suggest **[`skill-name`]**. Shall I use it, take the generic path, or point
> me at a different skill (or supply the features yourself)?

Proceed to the domain skill only on an affirmative. Choosing the generic path is a
first-class option, not a fallback-on-refusal — take it to §6's tabular default.
This is Open Item O1's confirm-before-invoke rule.

> **Presenting the choice ends your turn — stop and wait.** Building the pool is a
> *later* turn gated on the user's reply, never a formality you satisfy and then blow
> past. Until they answer, do not build the pool by any means — not the domain skill,
> not the generic path, and not an extractor of your own.

### 4. Invoke the domain skill — and resume on its output

On confirmation, run the chosen skill in the *same stateful MATLAB session* — that
is what makes the join back **data, not control flow**: the domain skill leaves its
output in the workspace, and you resume on it. There are **two paths** for *where*
that run happens, a main path and a fallback. They differ only in J1 (where the
skill runs); both leave the identical workspace artifacts and both converge on
`buildRecipe` (§5), so everything downstream is unchanged either way.

**Pre-condition — the split is already decided (non-negotiable, prevents leakage).**
Before the domain skill runs, intake's Collect step must be finished and the
train/test split established over the **raw observations** (problem type +
`splitStrategy` on the response, which needs no features). The split — which
observations are train vs. test — is then handed to the domain skill **as data**
so any extraction it *fits* trains on training observations only. Do **not** invoke
the domain extractor before this holds: extracting first and splitting later fits
the extraction on all rows and leaks test information into the pool (the failure
mode [intake.md](intake.md)'s ordering invariant guards against).

Whichever path runs, the domain skill's run must leave two post-conditions in the
workspace, and you own assembling them (§5):

1. **A feature table with the split already applied** — one row per observation,
   predictors + response, a named workspace variable, train/test membership
   carried through so the same rows stay train vs. test downstream. This is the
   pool. Any extraction that fits cross-row state (a normalization, a learned
   filter bank, an encoder, PCA) must have been **fit on the training observations
   only**; a purely stateless per-observation extractor is split-order indifferent,
   but declare which case applies rather than assuming.
2. **A replayable extraction transform** built via `buildRecipe` (§5) — so the
   delivered inference script can reproduce those features on new raw data, the
   same guarantee the SMLT path gives.

#### Main path — spawn the domain skill in a subagent

Spawn the domain skill via the Agent tool. An Agent-tool subagent **shares this
same stateful MATLAB MCP session** (verified: workspace state, and even a live
`Apply` handle with captured fitted state, cross the boundary both ways), so the
data-join is unchanged — the subagent leaves the pool and the recipe in the shared
workspace exactly as inline execution would. What the subagent adds is a **clean
contract boundary**: its deliberation (parameter questions, method choices,
reference reads) stays in its own context instead of the orchestrator's, and its
**final message is a structured return manifest** — the arguments `buildRecipe`
needs (the pool variable name, `Apply`, `Describe`, `Provider`) plus the
stateless-vs-fitted declaration from post-condition 1.

Give the subagent, in its prompt: the skill to run, the split **as data** (the
train row indices), a reserved workspace namespace for its outputs
(`domainHandoff_*`), and the required manifest schema. On return, assemble the
recipe with `buildRecipe` (§5); if the manifest is incomplete or malformed,
**re-request** the missing piece from the same subagent (resume it by its
`agentId` — its context is preserved) up to **twice** before treating the handoff
as failed.

#### Fallback path — inline, same conversation

Run the chosen skill **through the Skill tool in this same conversation**: the
*same* agent drives the extraction via MCP and assembles the recipe from the
commands it observed itself run. This is the original mechanism; it is fully
capable of the whole job, and is the path to take when the subagent path is
**mechanically** unavailable:

| Trigger | Response |
|---|---|
| Subagent will not spawn, or dies on a terminal error | clear the `domainHandoff_*` slots, run **inline** |
| Manifest still invalid after two re-requests | clear the `domainHandoff_*` slots, run **inline** |
| Round-trip verification fails (`Apply` won't replay) | **not** a path switch — handle via two-tier delivery (§5) |

The last row matters: a recipe that fails `buildRecipe`'s round-trip gate is a
*capture-fidelity* failure, and inline reconstruction is the **weaker** capture, so
falling back would not help — it is handled by the honest two-tier delivery in §5,
under either path. Clearing the reserved slots before an inline retry matters
because a half-finished subagent may have left partial artifacts in the shared
workspace.

**Skill unavailable or unlicensed — inline won't help, so don't try it.** The
inline fallback above assumes the skill *can* run and only the subagent mechanism
failed. Two failures break that assumption: the chosen skill **cannot be loaded at
all** (not installed, missing files), or it **loads but a required toolbox license
is unavailable**. Inline runs the same skill against the same license, so it can't
rescue either. Instead **report the specific issue to the user** (name the skill and
whether it was a load failure or a license one), then branch on data shape — the
same split §6 draws:

- **Data is already a usable predictor table** — offer the generic SMLT path
  (`generateFeatures`) as the fallback, framed as a genuine choice: *"[skill] is
  [unavailable / unlicensed], so I can't build domain features. Your data is already
  tabular, so I can run generic feature generation instead — want that, or would you
  rather fix the skill/license first?"* Proceed to §6's tabular default on an
  affirmative.
- **Data is a non-tabular modality** — generic generation cannot consume it and this
  skill does not tabularize raw modalities, so there is nothing to fall back to.
  **Halt cleanly**, stating the reason and what would unblock it (install/license the
  skill, or supply an already-extracted feature table and re-enter intake). Do not
  coerce the raw modality into `gencfeatures`.

**Resume waypoint (both paths).** Once both post-conditions hold, you do not re-run
intake and you do not wait for a return — the intake context (response, output dir,
model family, dataset name) **and the already-decided split** are still in hand.
Continue directly at the **[select](select.md)** phase, running selection on the
pool's **training rows**, passing the captured pool in place of what
`generateFeatures` would have produced. Everything downstream (select → assess →
deliver → report) is unchanged.

**One assess-time consequence — the baseline's "original" reference.** When the
domain input was a **non-tabular modality** (a signal, image, `timetable` the
extractor consumed), there are **no raw predictor columns** a model could fit on, so
the baseline cannot measure lift over "raw inputs." In that case the assess phase
takes the **full extracted pool** as the "original" reference and reports the **lift
of consensus selection over the whole pool** instead — see [assess.md](assess.md) §1
for the exact `OriginalData`/`OriginalPredVars` rule. A domain input that was
*already a table* of model-ready predictors keeps the ordinary raw-vs-selected
baseline.

### 5. Capture both artifacts — table *and* replayable transform

The feature table is only half of what the pipeline needs. The delivered artifact
is a self-contained inference script (`fe_transform_<dataset>.m` + `.mat`, see
[deliver.md](deliver.md)), and that can only be emitted if the extraction was
captured as something re-runnable. So capture **two** things from the domain
skill's run — you assemble both, from the commands it actually executed:

- **`FeatureTable`** — the feature table the skill produced (predictors +
  response). This is the pool that goes into [select.md](select.md).
- **`Recipe`** — a **domain Recipe struct** built with `buildRecipe`
  ([provider-protocol.md](provider-protocol.md)), carrying `Kind = "domain"`, an
  `Apply` handle that replays the **full** extraction, a `Describe` table
  (`Feature | Type | Definition`), and a `Provider` label. Downstream reads the
  pool only through this contract (see [feature-pool.md](feature-pool.md)), so it
  stays fully generator-agnostic — `transformFeatures`/`describeFeatures`/
  `selectFeatures` treat a domain Recipe exactly like an SMLT `FeatureTransformer`.

`Recipe.Apply` **is** the replayable pipeline `writeInferenceScript` packages —
the domain-path equivalent of the SMLT `FeatureTransformer`. Two rules govern its
capture, and both are non-negotiable because they are what make inference correct:

- **Prefer the skill's own exporter.** Many MathWorks skills can emit a
  self-contained extraction function of their own. If the chosen skill does, wrap
  *that* as `Apply` rather than reconstructing from a transcript — it is the
  faithful source. Otherwise assemble `Apply` from the captured commands.
- **Persist fitted state; fit it on the training rows only.** If the extraction
  *fits* anything on the data (a normalization, a learned filter bank, an
  encoder), those parameters must be baked into `Apply`/the `.mat` and **fit on the
  training rows only** — never recomputed at inference (that drifts) and never fit
  on the full table (that leaks). The SMLT path gets this for free because
  `generateFeatures` receives `TrainTbl`; on the domain path you must carry the
  train/test discipline into the domain skill's run explicitly.

**Build and verify the recipe in one call.** Hand the captured pieces to
`buildRecipe` — it assembles the struct and runs the round-trip gate inline, so a
recipe that is missing a field or cannot reproduce its pool fails here rather than
downstream:

```matlab
Recipe = buildRecipe(Apply, Describe, Provider, FeatureTable, RawInput, ...
    ResponseVar=ResponseVar, CheckIdx=TestIdx);
```

Pass `TestIdx` so response-based encodings don't false-alarm on training rows.
`buildRecipe` errors with `buildRecipe:invalidProvider` /
`validateRecipe:missingArtifact` / `:poolMismatch` / `:describeMismatch`.
`ApplySelected` is a deliver-time artifact, validated separately then (see
[deliver.md](deliver.md)); `buildRecipe` neither builds nor requires it.

> **Two-tier delivery when capture can't be verified.** Capture is best-effort. If
> `buildRecipe` cannot produce a verified recipe — an irreducibly interactive or
> human-judgment extraction step that isn't a pure function of a raw table, or a
> round-trip gate that keeps failing — **do not** switch routing paths (the inline
> fallback is the weaker capture, so it won't help) and **never** fabricate a
> clean-looking transform that doesn't replay. Instead deliver two tiers: always
> ship selection + assessment + the selected columns from the trustworthy feature
> table, and ship the full self-contained inference script *only* when the recipe
> verifies — otherwise state the honest fallback, "re-run extraction via
> `[skill-name]`, then apply the selected-column subset."

### 6. When routing doesn't happen

Routing to a domain skill can be declined or find no match. (A domain skill that
was *chosen* but whose subagent run failed mechanically does not land here — that
degrades to the inline path in §4, not to generic generation.) What to do when no
domain skill runs at all depends only on **whether the data is already a usable
predictor table**:

- **Data is already a usable predictor table** (one row per observation, feature
  columns + response) — use the generic `generateFeatures`
  (`gencfeatures`/`genrfeatures`) path. This is simply the default tabular path;
  it needs no confirmation. This covers ordinary tables that matched no domain
  skill, and domain-shaped tables where the user preferred the generic path.
- **Data is a non-tabular modality** (a signal vector, `timetable`, ensemble
  datastore, …) — `gencfeatures` cannot consume it, and this skill does not
  tabularize raw modalities itself. This is **not a refusal of the workflow**, it
  is a sequencing requirement: a tabularizing step must run first. **Pause and ask
  the user** to either supply an already-extracted feature table, or point to a
  skill/step that covers the domain — then **re-enter intake with the resulting
  table** and run the normal tabular path. This skill does not tabularize raw
  modalities by any means — neither by coercing the generic path nor by writing your
  own extractor; both fabricate a pool the user never sanctioned. Pausing **ends
  your turn**: wait for a table or a named skill/step before going on.

### 7. Record the route

Discovery is an LLM semantic match (§2) and cannot be made deterministic while it
is description-based — but the *decision* must be reproducible after the fact.
Record in the run manifest / report: the **domain-vs-generic** choice; if domain,
the chosen skill's **name and version** (the version as advertised in the injected
skill list — record "unversioned" if it carries none); **which path ran**
(subagent or inline fallback); and, if it fell back, **why**. This does not make
the first decision deterministic; it makes a re-run pinnable to the same route and
lets a reviewer see which extractor produced the pool.

---

## What this file deliberately does not do

- **No registry.** The injected skill list is the registry.
- **No filesystem discovery.** Nothing under `~/.claude` is read at run time.
- **No silent invocation.** Confirm-before-invoke, always.
- **No re-engineering domain features.** The domain skill's table is the pool as-
  is; `gencfeatures` is never layered on top of it.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
