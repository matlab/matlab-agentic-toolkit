# Prepare Problem Data

Run these checks before writing the first constraint. Unit errors are
silent: MATLAB accepts the constraint, `solve` runs, and the answer is wrong.

## Choose a decision-variable unit and drive it through everything

Every portfolio problem uses one of three unit conventions for the decision
variable. Pick one at the start, state it in a comment, and check that every
term in every constraint expression resolves to a consistent unit.

| Unit convention             | Decision variable         | Typical bounds        |
|-----------------------------|---------------------------|-----------------------|
| Weights                     | fractions of portfolio    | `0 <= w <= 1`         |
| Dollars                     | dollar amounts per asset  | `0 <= x <= budget`    |
| Shares                      | share counts per asset    | integer, `>= 0`       |

Budget / full-investment sums become:

- **Weights:** `sum(w) == 1` (full investment; textbook convention). Use
  `sum(w) <= 1` when a cash position is permitted (partial investment).
- **Dollars:** `sum(x) == portfolioValue` (full investment) or
  `sum(x) <= portfolioValue` (cash allowed).
- **Shares:** `sum(price .* h) == portfolioValue` or `<= portfolioValue`
  under the same distinction.

**Rule:** every additive term in a constraint expression must resolve to the
same unit as the constraint's right-hand side.

## The silent dimensional bug (cap-gains)

A common trap. The cap-gains constraint is a $ cap on realized gains,
right-hand side `500`. If the decision variable is dollar-denominated
`sell_dollars` with per-share coefficient `(price - basis)`:

```matlab
% Anti-pattern — dimensionally wrong:
prob.Constraints.capGains = sum(sell_dollars .* (price - basis)) <= 500;
% units: $ * ($/share) = $^2 / share  -- NOT $
```

MATLAB accepts. `solve` runs. The constraint over-constrains the sell by a
factor of `price(i)` per asset, blocking legitimate sales.

Two correct forms — pick one based on the decision-variable unit:

```matlab
% Correct if sell is dollar-denominated:
prob.Constraints.capGains = sum(sell_dollars .* (1 - basis ./ price)) <= 500;
% units: $ * (dimensionless) = $  ✓

% Correct if sell is share-denominated:
prob.Constraints.capGains = sum(sell_shares .* (price - basis)) <= 500;
% units: shares * $/share = $  ✓
```

The same pattern recurs elsewhere. Any time a constraint mixes a decision
variable with a market-data coefficient (price, dividend, book value), run
dimensional analysis on paper before accepting the expression.

### Where else this bug shows up

- **Self-financing constraint with commissions.** If the commission is quoted
  as `$5 per lot` (e.g., 100 shares per lot), then `commission` in dollars is
  `5 * sum(buyLots)` — the coefficient `5` has units `$/lot` and multiplies a
  lot-count variable. Writing `5 * sum(buyShares)` treats `5` as `$/share`
  and inflates the fee by `lotSize`. The rule: match the commission
  coefficient's units (`$/lot`, `$/share`, `$/trade`) to the aux variable it
  multiplies.
- **Wash-sale via lot-level realized gains.** Cap-gains checks on
  `sum(lotShares .* (price - basis))` require share-denominated lot
  variables. If the outer model is dollar-denominated, convert first.

## Proactive rescaling of problem data

Raw dollar values (portfolio value in 100M-600M range, per-asset costs
`1e-8` to `1e-6`) trigger a HiGHS "excessively small costs" warning.
Reactive fix: scale the objective up by `1e7`. Correct fix: rescale problem
data down to unit range **before** formulating.

### Rescale data, not just the objective

Scaling the objective alone is the second-best axis. The coefficient range
across constraints is still spread by orders of magnitude. Rescale each
constraint independently to unit scale, then formulate.

**Example — soft-constrained bond selection.** Targets: `$10M` carry value,
`4.5%` book yield, `2y` duration. Data ranges by target: `carryValue`
O(1e5–1e7), `bookYield` O(0.01–0.10), `bondDuration` O(1–10). Writing the three
slack residuals in raw units puts a `~1e8` coefficient range in the
objective, and the dollar-scale slack dominates while yield and duration
slacks never bind. Fix — rescale each target and its coefficient vector to
O(1) *before* forming the objective:

```matlab
carryValueScaled   = carryValue / 1e7;   targetCVScaled = targetCV / 1e7;   % $ scale
bookYieldScaled    = bookYield  / 0.01;  targetBYScaled = targetBY / 0.01;  % % scale
bondDurationScaled = bondDuration;       targetDScaled  = targetD;          % already O(1)
% Formulate slacks against the scaled targets; all three residuals now O(1).
```

Comparable-scale slacks mean the penalty weights read as relative
importances rather than as unit-conversion factors.

**Rule of thumb — coefficient-range check.** Before calling `solve`, list the
magnitude range of every coefficient in the objective and constraints. If
the ratio of the largest to the smallest exceeds `1e6`, rescale before
solving. Do not wait for HiGHS to warn.

### Reporting after rescaling

If you rescale data by `scale`, then:

- Portfolio value, dollar allocations, dollar costs → multiply by `scale`
  before printing.
- Weights and fractions → unchanged (dimensionless).
- Returns and rates → unchanged when the rescale was a dimensionless
  division (e.g., bps → decimal). When the rescale was a time-basis change
  (daily → annual via `* 252`, monthly → annual via `* 12`), convert back
  before reporting if the user expects the original frequency.
- Variance of dollar allocations → multiply by `scale^2`; standard deviation
  by `scale`. For time-rescaled variance, apply the same time factor
  (`Sigma_annual = Sigma_daily * 252`); std. dev. scales by `sqrt(factor)`.

## Pre-formulation checklist

Before writing the first `optimvar`:

1. **Pick a decision-variable unit.** Weights, dollars, or shares. State it
   in a comment.
2. **List each constraint** and check units of every additive term against
   the right-hand side.
3. **List coefficient magnitudes** across the objective and all constraints.
   Ratio > `1e6` → rescale.
4. **Rescale problem data** (not just the objective).
5. **Formulate, solve, scale results back for reporting.**

## Common mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|----------------|------------------|
| Cap-gains: `sum(sell_dollars .* (price - basis)) <= 500` | Units `$² / share`; over-constrains by `price(i)` | `sum(sell_dollars .* (1 - basis./price))` (dollar var) or `sum(sell_shares .* (price - basis))` (share var) |
| Scaling the objective up by `1e7` after a HiGHS warning | Fixes symptom on one axis; coefficient range across constraints still spread | Rescale problem data down to unit range before formulating |
| Mixing dollar decision vars with per-lot commission coefficients | `5 * sum(sellLots)` in dollars is correct; `5 * sum(sell_dollars)` is $²; `5 * sum(sell_shares)` is `$*share` | Introduce integer lot aux; `commission = 5*sum(buyLots) + 8*sum(sellLots)` |
| Comparing a dollar-denominated LHS to a weight-denominated RHS | Silent — The constraint is accepted as-is, so the solver treats both sides as pure numbers and the answer is nonsense | Convert one side before writing the constraint (`/ portfolioValue` or `* portfolioValue`) |
| Deferring the dimensional check until after the first bad solve | `solve` runs; the answer is wrong but not obviously so — verifying by inspection is slow | Dimensional analysis on paper before writing the constraint |

----

Copyright 2026 The MathWorks, Inc.

----
