# Fit Diagnostics: Reading `fit` Outputs Correctly

Load this at Step 7 when inspecting the results of a `fit` call.

## The output structs and where each field lives

The full signature is:

```matlab
[fitObj, diffTable, errorStat, optimOutput, H] = fit(obj, Data, FitType, options);
```

- **`errorStat`** carries the whole-fit RMSE in scalar `.Initial` and `.Final` fields (before and
  after the fit). `.Final < .Initial` shows improvement, but this is in-sample RMSE, not
  validation. The scalar RMSE lives on `errorStat` alone. Do not look for it on `diffTable`:
  `diffTable` does have `Initial Value` and `Final Value` columns, but those are the per-parameter
  seed and fitted values, which is a different quantity from the whole-fit RMSE. Use `errorStat`
  to judge the fit and `diffTable` to see what happened to individual parameters.
- **`optimOutput`** is the chosen solver's native output struct (`iterations`, `funcCount`,
  `message`). It carries **no** exit flag, so do not index `.exitflag` on it.
- **`Nominal`, `Limits`, and `Dimensions`** short-circuit the optimizer and return early with
  empty `errorStat`/`optimOutput`/`H`, so inspect their `diffTable` only.

## The `diffTable` columns: most names contain a space

`diffTable` carries these variables, in this order:

| Column | Dot access |
| --- | --- |
| `Parameter` | `diffTable.Parameter` |
| `Initial Value` | `diffTable.("Initial Value")` |
| `Final Value` | `diffTable.("Final Value")` |
| `Difference` | `diffTable.Difference` |
| `% Difference` | `diffTable.("% Difference")` |
| `Lower Bounds` | `diffTable.("Lower Bounds")` |
| `Upper Bounds` | `diffTable.("Upper Bounds")` |
| `Parameter Description` | `diffTable.("Parameter Description")` |
| `Status` | `diffTable.Status` (may be absent, see below) |

The table above is the current shape. `Status` and the two bounds columns are recent additions and
are missing on older releases, so guard each one with `ismember` before reading it rather than
assuming the shape. `Parameter`, `Initial Value`, `Final Value`, `Difference`, `% Difference`, and
`Parameter Description` are the long-standing core. See the `Status` section below for the guard
pattern, which applies to the bounds columns equally.

Only `Parameter`, `Difference`, and `Status` are valid MATLAB identifiers. **Every other column
needs the `diffTable.("Column Name")` form.** Plain dot access on the rest raises
`Unrecognized table variable name`. Do not guess a space-free spelling such as `LowerBounds`,
and do not invent names such as `OldValue`/`NewValue`; the before-and-after pair is
`Initial Value` and `Final Value`.

Parameter names live in the `Parameter` variable, not in row names. `diffTable` has none, so
`diffTable.Properties.RowNames` is empty rather than an error, and any report keyed on it comes
back silently empty. That reads as "nothing to disclose" when the truth may be the opposite, so
it is worse than a crash: a scope report built this way looks complete and is vacuous.

Watch the asymmetry between input and output names. The `fit` **options** are `Parameters`,
`FixedParameters`, `LowerBounds`, `UpperBounds`, `Weight`, `Solver`, `optimoptions`, and
`PlotFit`, all without spaces. The **columns** that come back carry spaces. `LowerBounds=` is
correct going in and wrong coming out.

To count how many parameters the fit actually moved:

```matlab
initVals = diffTable.("Initial Value");
finalVals = diffTable.("Final Value");
nChanged = sum(initVals ~= finalVals);
```

When unsure on a given release, read `diffTable.Properties.VariableNames` rather than assuming.

## The `Status` column (recent addition, guard for it)

After each optimizer-driven fit, read `diffTable.Status`, which classifies each parameter as
**Optimized**, **Inert**, or **Collinear**. These are three distinct outcomes, not two grades of
failure, and the difference is worth reporting accurately:

- **Optimized** means the parameter was in the active set the optimizer worked on.
- **Inert** means the parameter has *zero* sensitivity to your data, because a condition variable
  is not just constant but sitting at its reference value: camber zero throughout, inflation
  pressure never leaving nominal, or vertical load never leaving nominal. A camber coefficient
  cannot influence the residual when every sample is at zero camber. The parameter is
  mathematically unreachable with this data.
- **Collinear** means the parameter *does* affect the residual, but its effect cannot be separated
  from other parameters', because a condition variable is constant while held *away* from its
  reference value: camber pinned at a non-zero angle, pressure held off nominal, load held off
  nominal, or speed effectively constant. The sensitivity is non-zero but degenerate, so the fit
  cannot attribute a change in residual to this parameter rather than another.

Both Inert and Collinear are frozen before the optimizer runs and are returned at their seed
values, so both belong in the C3 scope report. Neither is a solver failure or something to work
around: each is a statement about what your data can support. Do not widen bounds, switch solvers,
or re-seed to chase them. The remedy is data that varies the condition in question (a camber
sweep, a pressure sweep, a load sweep, or speed variation), and if that data does not exist, say
so plainly. When a parameter would qualify as both, Inert takes precedence.

Report which of the two applies rather than collapsing them into "the data could not identify
this parameter." Inert says the parameter is invisible to this data; Collinear says it is visible
but not separable. A tire modeler reads those differently.

If *every* parameter for a fit type ends up frozen, `fit` performs no optimization and warns
`All optimization parameters are structurally inert for the provided data. No optimization
performed. The model is returned unchanged.`, returning the seed model with empty `errorStat`,
`optimOutput`, and `H`. Surface that outcome; do not report it as a successful fit.

`Status` is a recent addition. Before reading it, confirm the column exists:

```matlab
if ismember("Status", diffTable.Properties.VariableNames)
    % read diffTable.Status
end
```

On releases that predate it, skip the Status-based disclosure rather than indexing a missing
variable, and never invent a `Status` column when it is absent. Fall back to building the C3
report from the fit-type set alone.

## The bounds columns (a distinct signal from `Status`)

`diffTable` also carries `Lower Bounds`/`Upper Bounds` columns, read as
`diffTable.("Lower Bounds")` and `diffTable.("Upper Bounds")`. Like `Status` these are a recent
addition, so confirm they exist with
`ismember("Lower Bounds", diffTable.Properties.VariableNames)` before reading, and skip the
pinned-parameter disclosure on releases that lack them. A fitted parameter whose final
value sits on a bound was constrained from going further, a distinct signal from `Status`. Surface
any such pinned parameter and the bound it hit, and do not widen a bound on your own initiative.

## Judge by residual drop, not the convergence flag

Judge a fit by the size of the `.Initial`-to-`.Final` drop and by the overlay plot, not by whether
the solver reached its own convergence flag. A tire fit routinely exhausts `MaxFunEvals` (the
solver reports it stopped on the evaluation limit, not on a converged gradient) after a large
residual reduction. Because the Magic Formula's functional form and the scatter in the measured
data set a floor the residual cannot drop below, that plateau is the normal, healthy terminal
state for these fits. It is not a defect, and not evidence the fit can be meaningfully improved.

Do not reflexively raise the evaluation limit, switch solvers, or re-seed to chase the convergence
flag; those cost time, yield diminishing-to-zero returns, and risk diverging the fit. Report the
plateau and the RMSE reached, and let the user decide whether to push further.

## Verify from numbers, not figures

Verify each fit from these numeric diagnostics, the `.Initial`-to-`.Final` drop and the `Status`
breakdown, rather than by generating a figure. A plot is a user-facing artifact (the MATLAB
desktop is visible), so do not pop one unless the user asked to see or inspect the fit; offer it
instead. When a plot is wanted, pass `PlotFit=true` to `fit` for a per-fit-type overlay as each fit
lands (returned as the `H` output), or overlay the model on the routed data afterward with
`mdl.plot(Data=subset, ...)` or `td.plot(..., Model=mdl)` (see `references/inspect-by-plotting.md`).

----

Copyright 2026 The MathWorks, Inc.

----
