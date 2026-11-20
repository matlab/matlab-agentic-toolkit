# Optimize with Custom Constraints (Problem-Based)

Formulate portfolio problems the `Portfolio` object cannot express — integer
lots with fixed commissions, tax-aware rebalancing, class-varying cost caps,
custom efficient frontiers — directly in the problem-based framework
(`optimproblem`/`optimvar`/`solve`).

## When to Use

The constraint set includes **any** of these, alone or combined with
constraints the `Portfolio` object accepts:

- **Integer lots or whole shares.** Decision variables are integer, not
  continuous weights. `Portfolio` output space is continuous weights.
- **Fixed per-lot or per-trade commissions.** `setCosts` handles proportional
  costs only; fixed costs (`$5 per lot`, `$25 per trade regardless of size`)
  require binary indicators or integer aux variables.
- **Minimum trade size as disjunction on the trade magnitude.**
  `|w(i) - w0(i)| >= δ` OR `w(i) = w0(i)` — a disjunction on the *change*
  from the current position. `Portfolio`'s semi-continuous bounds impose the
  disjunction on the *level* (`w = 0` OR `L <= w <= U`), not on the change.
- **Semi-integer positions.** `w(i) = 0` OR `w(i) in {L, L+1, ..., U}` —
  semi-continuous plus integer. `Portfolio` accepts the semi-continuous shape
  but the output space is continuous weights.
- **Wash-sale rules.** Blocks on buying assets tied to recent losses; couples
  lot-level sell decisions with asset-level buy decisions.
- **Realized capital-gains constraints.** Cap on `sum` of realized gains at the
  lot level; requires per-lot decision variables.
- **Tax-loss harvesting.** Chooses which lots to sell to realize losses under
  wash-sale constraints.
- **Asymmetric, class-varying, or bucketed transaction-cost caps.** For
  example, "equity trading cost 0.005 per unit weight, fixed-income 0.002 per
  unit weight, total cost <= 0.01." `setCosts` cannot cap the sum.
- **Custom efficient frontier** whose feasibility set includes any of the
  constraints above.
- **Anti-pattern in visible code:** `round(V0*w./(100*prices))`,
  `floor(V0*w./prices)`, or `ceil(...)` applied to the output of `Portfolio` /
  `estimateFrontier` to obtain shares or lots. Reformulate the discrete
  problem directly.

## When NOT to Use

- Every constraint is one the `Portfolio` object accepts (bounds,
  semi-continuous bounds, budget, groups, linear constraints, turnover,
  tracking error, cardinality, proportional costs) — use the `Portfolio`
  object workflow instead. Do **not** reformulate with
  `optimproblem`/`optimvar`; that duplicates machinery `Portfolio` provides.
- General optimization workflow — solver selection tables, exitflag
  interpretation, `MultiStart`/`GlobalSearch` — use `matlab-solve-optimization`.

## Why Not Work Around `Portfolio`

Common temptations, and why each is wrong:

- **Continuous `Portfolio` + `round` on the output.** The rounded point is
  generally not on the efficient frontier of the discrete problem — it is
  typically Pareto-dominated by other integer allocations reachable by lot
  swaps between assets, and it can violate the constraints the continuous
  problem satisfied (return target, budget). Coincidental alignment with the
  discrete optimum is possible but rare, and there is no way to verify it
  without solving the discrete problem anyway.
- **Continuous `Portfolio` + `round` + greedy repair.** Same failure mode.
  Repair heuristics restore feasibility (budget, bounds, cardinality) but
  give no guarantee of optimality on the discrete problem.
- **Hand-rolled branch-and-bound over `quadprog`/`linprog`** using `Portfolio`
  outputs as a warm start. Redundant with `intlinprog` and `ga` (dispatched
  automatically by `solve` on integer variables). Error-prone at every
  layer (branching heuristic, pruning, tolerance handling, warm-start
  validity). `solve(prob)` handles the problem directly once
  `optimvar(..., "Type", "integer")` is used.

## Workflow

Follow three steps: **formulate → dispatch → validate**. Each step routes to
a reference file when the current problem hits the topic it covers.

### Step 1: Formulate in problem-based syntax

Default to `optimproblem` + `optimvar`, never solver-based matrix form
(`linprog(f,A,b,...)`, `intlinprog(f,intcon,...)`, `ga(fun,nvars,...)`).
Solver-based form is legitimate only when the user explicitly asks for it or
when problem-based has a documented gap for the shape at hand. See
`references/problem-based/problem-based-framework.md` for the framework-choice
rule and the `fcn2optimexpr` escape for genuinely nonlinear pieces.

Pick decompositions from the pattern files below. Read only the ones the
problem's constraints call for. Combine patterns when a problem needs more
than one: for example, a round-lot problem with a fixed commission and a
minimum-trade disjunction uses the buy/sell aux split (for the commission)
together with disjunctive big-M (for the min-trade).

- **MIP recognition and anti-patterns** —
  `references/problem-based/mip-recognition.md`. Decide whether the problem
  is a MIP; reject `abs()` on signed integers, continuous-plus-rounding, and
  hand-rolled branch-and-bound.
- **Trade magnitude via aux vars** and **buy/sell aux split** —
  `references/problem-based/trade-aux-variables.md`. Magnitude aux when only
  `|w-w0|` matters (symmetric transaction cost, turnover cap); buy/sell split
  when direction matters (asymmetric or fixed commissions, integer round lots,
  wash-sale blocks on buys, cap-gains on sells). Never put `abs()` on a signed
  decision variable in the objective — that self-inflicts a MINLP that forces
  `ga`.
- **Disjunctive big-M** — `references/problem-based/disjunctive-big-m.md`.
  Min-trade `|w-w0| >= δ OR w=w0`, semi-integer bounds; per-asset big-M
  derived from data.
- **Tax-aware constraints** —
  `references/problem-based/tax-aware-constraints.md`. Wash-sale is *two
  coupled rules* (historical asset-level + within-optimization lot-level);
  realized cap-gains depends on the decision-variable unit.

Before proceeding to dispatch, run the pre-formulation checks in
`references/problem-based/problem-data-hygiene.md`:

- Choose a **decision-variable unit** (dollars, shares, or weights) and drive
  it consistently through the objective and every constraint. Cap-gains,
  wash-sale, and self-financing constraints are the frequent failure points.
- **Rescale problem data** to unit range up front (divide `CV` in
  hundreds-of-millions by `1e6`, weights already unit). Do not wait for a
  HiGHS "excessively small costs" warning.

### Step 2: Dispatch to a solver

Read the problem structure off the formulation — objective form and variable
types together decide it:

| Objective | All continuous vars | Any integer vars |
|-----------|---------------------|------------------|
| Linear | LP | MILP |
| Quadratic | QP | MIQP |
| Nonlinear (via `fcn2optimexpr`) | NLP | MINLP |

Then call `[sol, fval, exitflag] = solve(prob)` and let `solve` pick the
solver from that structure:

| Problem structure | Dispatched solver | Deterministic? |
|-------------------|-------------------|----------------|
| LP  | `linprog`   | yes |
| QP  | `quadprog`  | yes |
| MILP | `intlinprog` | yes |
| MIQP | `ga`         | no (heuristic) |
| MINLP | `ga`        | no (heuristic) |

`intlinprog`, `quadprog`, and `linprog` are in Optimization Toolbox; `ga`
requires Global Optimization Toolbox. Dispatched automatically — do not call
directly.

If you must pass `optimoptions`, set them on the **dispatched** solver — not
on `intlinprog` when the problem is MIQP and dispatch is `ga`. `solve`
warns and drops every option the dispatched solver does not share (only
common options such as `MaxTime` carry over). See
`references/problem-based/problem-based-framework.md`.

### Step 3: Validate the result

- Check `exitflag > 0`. For `ga`-dispatched problems, call `solve` once with
  default `ga` options; do not provide any custom options unless specified by
  the user; do not add local search or relaxation bounds on top.
- Verify decision-variable units by dimensional analysis of each constraint:
  every additive term must resolve to the same unit.
- For custom frontiers, verify the *shape*: risk-on-x, return-on-y, concave.
  A parabola instead of a monotone-nondecreasing curve is the endpoint bug —
  see `references/problem-based/custom-frontier.md`.

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `optimproblem` | Create a problem-based optimization model | Optimization Toolbox |
| `optimvar` | Declare decision variables (with `'Type','integer'` for MIP) | Optimization Toolbox |
| `solve` | Dispatch and solve; picks solver from structure | Optimization Toolbox |
| `fcn2optimexpr` | Wrap a MATLAB function so `ga` works from an `optimproblem` | Optimization Toolbox |
| `Portfolio` | **Do not** use for problems on this path | Financial Toolbox |

## Patterns

Inline sketches. Each links to the reference file with the full pattern,
edge cases, and worked examples.

### Buy/sell aux split for integer lots + fixed commissions

Never put `abs()` on a signed lot variable in the objective. Split into
non-negative integer aux vars:

```matlab
buyLots  = optimvar("buyLots",  nAssets, Type="integer", LowerBound=0);
sellLots = optimvar("sellLots", nAssets, Type="integer", LowerBound=0);
shares     = h0 + 100*(buyLots - sellLots);       % net share position
commission = 5*sum(buyLots) + 8*sum(sellLots);    % linear
```

Full pattern in `references/problem-based/trade-aux-variables.md` (Buy/sell aux split).

### Minimum trade size as a big-M disjunction

The constraint is `|w(i)-w0(i)| >= δ` **OR** `w(i) = w0(i)` — not a
semi-continuous bound on `w(i)` (that's a different constraint), and not
the lower bounds `w(i) - w0(i) >= δ*buyH(i)` and `w0(i) - w(i) >= δ*sellH(i)`
alone (with no upper bounds, setting either binary to 1 is infeasible, so
`w = w0` is forced). Split direction into two binaries and couple *both* binaries
into *both* magnitude bounds, using the natural per-asset trade bounds from
`w`'s box `[wLB, wUB]` (three constraint families):

```matlab
w     = optimvar("w",     nAssets, LowerBound=wLB, UpperBound=wUB);
buyH  = optimvar("buyH",  nAssets, Type="integer", LowerBound=0, UpperBound=1);
sellH = optimvar("sellH", nAssets, Type="integer", LowerBound=0, UpperBound=1);
prob.Constraints.minBuy  = w - w0 >= minTrade*buyH  - (w0 - wLB).*sellH;
prob.Constraints.minSell = w - w0 <= (wUB - w0).*buyH - minTrade*sellH;
prob.Constraints.oneSide = buyH + sellH <= 1;
```

When `buyH=sellH=0`, `0 <= w - w0 <= 0` — so `w = w0`. When `buyH=1`,
`w - w0 ∈ [minTrade, wUB-w0]`. When `sellH=1`, `w - w0 ∈ [-(w0-wLB), -minTrade]`.
Do not use a global `M` with separate maxBuy/maxSell families — correct, but
it doubles the constraint count.

Full pattern (case analysis, constraint counts, cardinality coupling) in
`references/problem-based/disjunctive-big-m.md`.

### Custom-frontier endpoints and inequality sweep

Use **min-variance QP** for the lower endpoint and **max-return LP** for the
upper — not a min-return LP for the lower endpoint (that walks the
*inefficient* lower branch of the parabola). Sweep return targets as
`mu'*w >= target` (inequality), build `optimproblem` once outside the loop,
and reassign only the target-constraint RHS inside:

```matlab
prob = optimproblem(ObjectiveSense="minimize");
w = optimvar("w", nAssets, LowerBound=0, UpperBound=1);
prob.Objective = w'*Sigma*w;
prob.Constraints.budget = sum(w) == 1;
prob.Constraints.retTarget = mu'*w >= 0;               % RHS reassigned in loop
targets = linspace(retLo, retHi, nPoints);
for k = 1:nPoints
    prob.Constraints.retTarget = mu'*w >= targets(k);
    sol = solve(prob);
    % record sol.w, w'*Sigma*w, mu'*sol.w
end
```

Full pattern in `references/problem-based/custom-frontier.md`.

### Wash-sale (two coupled rules)

Historical asset-level:

```matlab
prob.Constraints.washSaleHistorical = buyAsset(lossAssets) == 0;
```

Within-optimization lot-level (couple sell-of-loss-lot with block-buy):

```matlab
prob.Constraints.lossLotSaleUB     = lossLotShareSold <= lossLotShares .* lossLotSold;
prob.Constraints.washSaleWithinOpt = buyAsset(lossLots2AssetsIdx) <= 1 - lossLotSold;
```

Full pattern (with mapping construction and cap-gains coupling) in
`references/problem-based/tax-aware-constraints.md`.

## Conventions

- **Always** default to problem-based (`optimproblem`/`optimvar`). Use
  `fcn2optimexpr` for genuinely nonlinear pieces so `ga` still dispatches
  from an `optimproblem`.
- **Prefer** rescaling problem data to unit range before formulating over
  reacting to a HiGHS "excessively small costs" warning after the fact.
- **Always** state and enforce a decision-variable unit (dollars, shares, or
  weights). Cap-gains and self-financing coefficients must match that unit.
- **Prefer** the tight formulation over the heaviest textbook form (single-aux
  reductions, fewer binaries) when correctness is unchanged.
- **Never** put `abs()` on a signed decision variable in the objective or
  a constraint — linearize with auxiliary variables (magnitude aux or
  buy/sell split; see the Patterns section).
- **Never** hand-roll branch-and-bound over `quadprog`/`linprog`. `intlinprog`
  and `ga` are dispatched automatically by `solve` and are
  correctness-hardened.
- **Never** solve a continuous `Portfolio` problem and `round`/`floor` the
  result to obtain lots. The rounded point is not the efficient frontier of
  the discrete problem.
- **Never** set `optimoptions` on a solver `solve` does not dispatch to
  (`optimoptions('intlinprog', ...)` on a MIQP dispatched to `ga`).
- **Always** plot efficient frontiers **risk-on-x, return-on-y** (concave
  curve).

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|----------------|------------------|
| Signed lot variable `k` with `abs(k)` in the objective for a round-lot problem with fixed commissions | Self-inflicts MINLP; forces every solve through non-deterministic `ga`, no optimality guarantee | Buy/sell aux split — see `references/problem-based/trade-aux-variables.md` |
| Continuous `Portfolio` + `estimateFrontier` + `round(V0*w./(100*prices))` for integer lots | Rounded point is not the efficient frontier of the discrete problem; dominated by lot swaps | Formulate the MIP directly with `optimvar(...,'Type','integer')` — see `references/problem-based/mip-recognition.md` |
| Hand-rolled branch-and-bound over `quadprog`/`linprog` for a MIQP | Redundant with `ga` dispatch from `solve`; error-prone at every layer | Formulate with `optimproblem`+`optimvar`; call `solve` — see `references/problem-based/mip-recognition.md` |
| Solver-based `linprog(f,A,b,...)` / `intlinprog(f,intcon,...)` / `ga(fun,nvars,...)` on a MIP | Loses readability and the `solve`-dispatch safety net; harder to change constraints | Stay in `optimproblem`/`optimvar`; use `fcn2optimexpr` for nonlinear pieces — see `references/problem-based/problem-based-framework.md` |
| `optimoptions('intlinprog', 'MaxNodes', 1e4)` passed to `solve` on a MIQP | `solve` dispatches to `ga`; `intlinprog`-specific options are dropped with a warning | Set options on the dispatched solver — see `references/problem-based/problem-based-framework.md` |
| Cap-gains: `sum(sell_dollars .* (price - basis)) <= 500` | Mixes dollar decision var with per-share coefficient (units `$² / share`); over-constrains by `price(i)` per asset | `sum(sell_dollars .* (1 - basis./price)) <= 500` (dollar var) or `sum(sell_shares .* (price - basis)) <= 500` (share var) — see `references/problem-based/problem-data-hygiene.md` |
| Min-trade interpreted as a semi-continuous bound on `w(i)` (`w(i)=0` or `w(i) >= δ`) | The constraint is on the *change* `w-w0`, not the level `w`. Semi-continuous blocks legitimate trades (e.g. trimming a `0.15` position to `0.03` — trade size `0.12 >= δ` — is forbidden) and forbids "no trade" when `w0` lies in `(0, δ)` | `abs(w(i)-w0(i)) >= δ` OR `w(i)=w0(i)` — big-M disjunction; see Patterns and `references/problem-based/disjunctive-big-m.md` |
| Min-trade coded as `w(i)-w0(i) >= δ*buyH(i)` (and mirror for sell) | The only feasible choice is `buyH=sellH=0`: with `buyH=1, sellH=0` the rows require `w-w0 >= δ > 0` and `w0-w >= 0` at the same time, which cannot hold (mirror argument for `sellH=1`). So `w = w0` is forced and no asset can be traded | Couple both binaries into both magnitude bounds: `w-w0 >= minTrade*buyH - (w0-wLB).*sellH`, `w-w0 <= (wUB-w0).*buyH - minTrade*sellH`, and `buyH+sellH <= 1` — see Patterns and `references/problem-based/disjunctive-big-m.md` |
| Waiting for a HiGHS "excessively small costs" warning, then scaling the objective up by `1e7` | Reactive; picks the second-best axis. Coefficient ranges are still spread if only the objective scales | Rescale problem data down to unit range before formulating — see `references/problem-based/problem-data-hygiene.md` |
| Min-return LP for the lower endpoint of a custom-QP efficient frontier | Walks the inefficient lower branch of the parabola; equality-target sweeps yield 4–9 dominated points | Min-variance QP for lower endpoint, max-return LP for upper, `mu'*w >= target` inequality sweep — see `references/problem-based/custom-frontier.md` |
| Rebuilding `optimproblem` inside the frontier loop | Re-parses symbolic expressions on every iteration | Build once outside, reassign only the target RHS inside — see `references/problem-based/custom-frontier.md` |
| Plotting frontier with return on x-axis, risk on y-axis | Convex-looking curve does not read as a frontier at a glance | Risk-on-x, return-on-y (concave) — see `references/problem-based/custom-frontier.md` |

## Reference Materials

- `references/problem-based/mip-recognition.md` — Recognizing MIP problems
  and the three anti-patterns to reject (`abs()` on signed integers forcing
  MINLP, continuous-plus-rounding, hand-rolled branch-and-bound). Consult
  when the problem has integer lots, binaries, or fixed costs.
- `references/problem-based/trade-aux-variables.md` — Trade-magnitude aux
  vars and the buy/sell aux split, with fixed- and per-lot commission
  examples. Consult when an objective or constraint depends on `w-w0`.
- `references/problem-based/disjunctive-big-m.md` — Min-trade and
  semi-integer disjunctions, the tight 3-family form, per-asset big-M from
  data. Consult for any either/or constraint.
- `references/problem-based/tax-aware-constraints.md` — Historical and
  within-optimization wash-sale rules, realized cap-gains via per-lot G&L.
  Consult for wash-sale, cap-gains, or tax-loss harvesting.
- `references/problem-based/problem-based-framework.md` — Problem-based
  default, `fcn2optimexpr` for nonlinear pieces, the `solve` dispatch table,
  the options-must-match-dispatched-solver rule. Consult when choosing between
  problem-based and solver-based, or when configuring solver options.
- `references/problem-based/problem-data-hygiene.md` — Unit-convention
  discipline (dollars / shares / weights), the silent dimensional-bug pattern
  with correct cap-gains forms, proactive rescaling to unit range,
  coefficient-range checks. Consult before writing the first constraint on
  any problem with dollar-denominated data.
- `references/problem-based/custom-frontier.md` — Endpoint problems
  (min-variance QP + max-return LP), inequality target sweep,
  build-once-loop-inner-reassign idiom, risk-on-x plot convention. Consult
  when tracing an efficient frontier over a custom constraint set.

----

Copyright 2026 The MathWorks, Inc.

----
