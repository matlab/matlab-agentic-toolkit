---
name: matlab-fit-tire-model
description: >
  Fit a tire model (Magic Formula 6.2/5.2/5.1, Dugoff, or Fiala) to measured tire
  force and moment data using the Vehicle Dynamics Blockset Extended Tire Features
  API (tireData.import, tireModel.new, tireModel.fit, tireModel.export). Use when
  fitting, parameterizing, or calibrating a tire model from tire measurement data
  (TYDEX, Calspan, MTS, or text/CSV from any test source), creating a .tir file, or
  building a Magic Formula tire model from test data. Also use for the individual
  steps: importing TYDEX, Calspan, MTS, or CSV tire data (file extensions `.tdx` for
  TYDEX; `.data`, `.tim`, `.rsp` for MTS; any other extension read as text) into a
  tireData object,
  exporting a tire model to .tir, inspecting, smoothing, cropping, or plotting tire
  measurement data or a model's response, or converting a fitted model to another type.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Fit a Tire Model from Tire Measurement Data

Fit a tire model from tire measurement data using the Vehicle Dynamics Blockset Extended
Tire Features API. The API supplies the fitter, so the work is three judgments it does not
enforce: query the valid fit types and their order rather than hardcoding them, route data
to each fit type by channel content, and report which fit types were left at defaults.

## When to Use

- You have tire measurement data (in TYDEX, Calspan, MTS, or text/CSV form, from any test
  source) and want a fitted tire model or a `.tir` file. This full fitting workflow is the
  primary use.
- You want a single step of that workflow against tire measurement data or a tire model:
  import to a `tireData` object; export a model to `.tir`; inspect, summarize, crop, or
  smooth measurement data; plot measurement data or a model's response; convert a fitted
  model to another type. See Partial invocation below.
- Target model type is Magic Formula 6.2 (the worked example), MF5.2, MF5.1, Dugoff, or
  Fiala.

## When NOT to Use

- Designing an FIR or IIR signal filter: use `matlab-design-digital-filter`. This skill's
  `filter()` is channel smoothing during fitting, not filter design.
- Cleaning generic (non-tire) signals, or building signal datastores and labels for ML: use
  `matlab-prepare-signal-data`. Smoothing, cropping, or downsampling a `tireData` object stays here.
- Specifying or planning a plant or tire-subsystem architecture for closed-loop simulation: use
  `specifying-plant-models` (Simulink Agentic Toolkit).
- Adding, wiring, or restructuring blocks in a model: use `building-simulink-models` (Simulink
  Agentic Toolkit). This skill only writes fitted parameters into an existing tire block via `set`.
- Simulating a model containing the tire block: use `simulating-simulink-models` (Simulink
  Agentic Toolkit). Inspecting a fit you just ran is in scope.
- Grabbing a reference or production tire to simulate against (`tireModel.builtin`); it is ruled
  out as a fitting seed.
- Deriving or hand-coding Magic Formula coefficients yourself; the API supplies the fitter.
- The Step 0 prerequisite gate fails (Extended Tire Features support package or Optimization
  Toolbox missing): the user runs `matlab-install-products` or `matlab-list-products`, not you.

## Workflow

The full fit is a step-ordered sequence. Steps 0 through 9 run in order. Load
`references/fit-type-data-requirements.md` when you
reach Step 2 (routing) or Step 5 (fitting): it holds the per-fit-type data-requirements
table, the channel-content routing table, and the `Dimensions` geometry-property details.

### 0. Recognize the path and check prerequisites

Gate on class availability, not `detect_matlab_toolboxes` (misses support packages) or
`matlabshared.supportpkg.getInstalled`. Confirm the methods
are present so a same-named custom class cannot pass:

```matlab
if exist('tireModel','class') ~= 8 || ...
        ~all(ismember(["new" "fit" "export"], ...
            string({meta.class.fromName('tireModel').MethodList.Name})))
    error("Extended Tire Features support package not found. Install it from Add-Ons.");
end
```

If either gate fails, report it, stop, and tell the user to install the missing product; never
install it yourself. Do not hand-roll Magic Formula. `fit` requires Optimization
Toolbox (`new` does not). Check install and license separately. Nothing overrides an empty
`ver("optim")`: `which('fmincon')` resolves either way, and a license check passes for a
licensed-but-absent product.

```matlab
if isempty(ver("optim"))
    error("Optimization Toolbox not installed.");
elseif ~license('test','optimization_toolbox')
    error("Optimization Toolbox unlicensed.");
end
```

### 1. Import to a `tireData` array

`obj = tireData.import(filepath, ...)` takes a `string` scalar or array and returns a
`tireData` array, one element per file. Recognized formats (TYDEX, MTS, Calspan) auto-convert
every channel to canonical SI units and import as ISO coordinates, which is what Magic Formula
expects. So after a recognized-format import, angles are in **radians, not degrees**, and no
coordinate fiddling or manual slip-angle negation is needed. Import options are
extension-gated (TYDEX honors only `DatetimeFormat`/`Locale`; MTS adds `VariableAlias`;
text/CSV passes all options through).

On the text/CSV path, or when hand-authoring a `tireData` property from another source, you
supply the units and coordinates: provide radians, N, Nm, and Pa, or designate the file's
units with `VariableUnits`, `VariableUnitsLine`, or `HeaderUnits`, and pass `CoordinateSystem=`
(or convert after import with `coordinateTransform(obj, "ISO")`).

### 2. Inspect content and classify each channel (routing foundation, C2)

The routing decision is made here and carried to Step 5. For each imported object, classify
`alpha`, `kappa`, `Fz` (and `gamma`/`V` where relevant) as constant, swept, or stepped, using
public methods only. `summaryTable` gives one per-object statistic per channel: `DataStat="range"`
for the swept-versus-held call (large span = swept, small = held), `DataStat="mean"` for each
channel's level. Read the two together: the mean is a meaningful level only for a channel the
range shows is held; for a swept channel the mean is just the sweep's center. Narrow
`VariableNames=` to `Filename`, the channels you route on, and any response channel whose
presence you test; it defaults to every `tireData` property, so an unnarrowed table is over
eighty columns wide with filepaths and comments in it.

```matlab
routeVars = ["Filename" "alpha" "kappa" "Fz" "gamma" "V"];
spans = summaryTable(td, VariableNames=routeVars, DataStat="range");
means = summaryTable(td, VariableNames=routeVars, DataStat="mean");
```

`split(obj, channel)` returns one element per discrete level: more than one means bundled
fixed-level cases; exactly one emits the expected warning `Unable to identify splits in data`
("one level," not an error). Splitting is optional: `fit` accepts a multi-condition object
directly, so split only when you need per-sweep processing (`filter` smoothing, `mean` hold),
never merely to fit. Never assume a channel's role: `Fz` swept is a load sweep (`RL`/`Re`), `Fz`
stepped is bundled load cases, `Fz` constant is a single-load test. Determine it per object. The
pure-versus-combined split is on **mean alpha, not alpha range** (a naive alpha-range threshold
misclassifies). Angles are radians (Step 1).

### 3. Choose or honor the model type (query the list, C1 philosophy)

Valid types come from `vdyntire.tiremodels.modelTypes()`. The set is version-dependent, so
query it and never embed a hardcoded list; `new` also accepts `"MF"` as an alias for `MF62`.
Honor the user's stated type: validate it against `modelTypes()` and use it, do not silently
substitute. The type drives the whole schedule (Fiala and Dugoff have no `Nominal`, no
combined, and no `Re`/relaxation/contact-patch fits), so never replay the MF62 schedule on
another type. If the user names no type, stop before Step 4: list the types from `modelTypes()`
and end your turn asking which to use. If the user named the intended simulation, you may say
which types suit it, but still ask. A file format or an intended use does not name a type;
every supported type exports to `.tir`. If the user names
an unsupported model (for example FTire, MF-Swift, CDTire, or another third-party
designation), use your own tire-model knowledge to propose the nearest supported alternative
under three guardrails: the final choice must be a member of `modelTypes()` (validate the
proposal live), name the gap honestly and never silently swap, and stop to confirm, as above.
For a fundamentally different model class (transient, thermal, high-frequency), it is fine to
answer that this workflow cannot produce that model.

### 4. Query the valid fit types and order (C1), never hardcode

Normal path: `vdyntire.tiremodels.fitTypes(ModelType=<type>)` returns the fittable types in a
valid schedule order, as a column string array, so loop by index. Iterate them in returned order
and fit each type the data supports;
`Nominal`-upstream falls out naturally because `fitTypes` lists it first for Magic Formula and
omits it for Fiala/Dugoff. `fitTypeDependency` is the
secondary, diagnostic tool: `[deps, params] = tm.fitTypeDependency(<type>)` returns the
transitive closure of upstream prerequisites, ordered dependencies-first, excluding the type
itself. Use it only to validate or repair a user-forced custom order, and to reason about what
becomes unfittable when a prerequisite is skipped for lack of data. Take dependencies from it
rather than from a documentation table. Do not try/catch-probe a type list;
`fitTypeDependency` errors on a type the model lacks, so enumerate
with `fitTypes` instead.

### 5. Route by content (C2); route it yourself, `fit` will not

The Tire Manager app auto-assigns data to fit types with an internal inspector; the
command-line `fit` API does not. `fit` checks only channel presence and warns on wrong-condition
data, then concatenates everything and fits. So handing every file to every fit type biases the
fits with wrong-condition data and emits only warnings. Route by selecting the objects whose
Step-2 classification matches each fit type's row in
`references/fit-type-data-requirements.md`, then pass that object or array to `fit`. Never route
by filename or subfolder. `Nominal`, `Limits`, and `Dimensions` consume ALL data, not a swept
subset. `crop` trims unusable rows within an object; `filter`, `mean`, and `downsample` are
per-object processing (smoothing, holding, decimation), never row selection.

### 6. Seed the model (`new` or `import`; `builtin` ruled out)

Fit from scratch with `tireModel.new(<type>)`: physically reasonable nonzero defaults, ready to
fit. Fit a variant or re-fit an existing tire with `tireModel.import(<parent>)` (a `.tir` or
`.mat` path, an extensionless TIR file, or a parameter struct): it starts the optimizer near the
answer, so fit only the types the variant changed. When seeding via `import`, the model type comes
from the file, so query `fitTypes` against the imported model's actual type and surface any
disagreement with the requested type. The C3 baseline also changes: untouched parameters retain the
imported parent's coefficients rather than `new` defaults, and Step 9 must name which.
`tireModel.builtin` is not a seed (`fit` errors on a builtin model); it is only for grabbing a named
reference tire to simulate against.

Prefer fitting `Nominal`, `Limits`, and `Dimensions` over hand-setting model coefficients: never
hand-set `FNOMIN`, dimensions, or limits as model properties. Legitimate manual setting is on the
`tireData` object (for example a dimension property the headers omit), never on the model
coefficients a fit should set. `Dimensions` fits from the `tireData` geometry properties, which
TYDEX import populates from the file header. If they are empty, you may ask the
user for the tire size and assign the five properties directly, minding the mixed canonical units in
the reference file; if the user cannot supply it, leave the parameters at the seed value and report
it (C3) rather than fabricating dimensions. `TireSize` is bookkeeping only and does not gate
`Dimensions`.

### 7. Fit in dependency order, inspect each result (C1 runtime + C2 safety net)

The signature is `[fitObj, diffTable, errorStat, optimOutput, H] = fit(obj, Data, FitType, options)`,
where `obj` is the seed model, `Data` is the routed subset from Step 5, and `FitType` is a single
type string. The normal path passes no options. `fit` returns a NEW model and does not mutate in
place, so reassign and thread the model through the schedule (`mdl = fit(mdl, subset, type)`, once
per supported fit type in `fitTypes` order, as in the worked example).
Discarding the return, or re-seeding from `new` each step, makes the dependency order meaningless
because nothing accumulates. `Nominal`, `Limits`, and `Dimensions` short-circuit the optimizer and
return early with empty `errorStat`/`optimOutput`/`H`, so inspect their `diffTable` only. Surface
every `dataChecks` and `checkLimits` warning rather than swallowing it: they signal sloppy Step-5
routing. `fit` errors only when a required channel is entirely absent, so check the routed subset
for that type's required channels first (`references/fit-type-data-requirements.md`) and record a
skipped type in the Step 9 report rather than calling `fit` to surface the error.

After each fit, read `diffTable.Status` when present (Optimized, Inert, or Collinear; report Inert
and Collinear parameters in Step 9, naming them from `diffTable.Parameter`, never from
`diffTable.Properties.RowNames`, which is empty) and `errorStat.Final`, the whole-fit in-sample RMSE (not validation).
Judge a fit by the size of the `.Initial`-to-`.Final` drop and the overlay plot, not by whether the
solver hit its own convergence flag: tire fits routinely stop on `MaxFunEvals` at a residual floor,
which is normal, so do not chase the flag by raising the limit, switching solvers, or re-seeding.
Verify from the numbers, not a figure; the MATLAB desktop is visible, so do not pop a plot unless
asked (offer it, and pass `PlotFit=true` to overlay each fit). Load `references/fit-diagnostics.md`
for the output-struct fields and these diagnostics in detail.

### 8. Deliver the model, by intent

Save to a portable standard file (recommended): `export(mdl, "path/fitted.tir")`. It has no
return value. A `.tir` is consumable by Vehicle Dynamics Blockset tire blocks and by
third-party Magic Formula compatible software. The format is chosen by extension. `export`
errors on an existing file, so pass `overwrite=true` deliberately or pick a fresh name. To use
the model immediately in a model, `set(mdl, blockPath, ...)` pushes the fitted parameters into
a supported Vehicle Dynamics Blockset tire block. Two consistency gates apply: the target must
be a supported tire block, and the block's configured model type must match `mdl.ModelType`.
`set` operates by side effect on an open model and returns nothing. Do not hardcode the
supported-block list.

### 9. Report scope completely, up front (C3)

Report at the fit-type level using public accessors only. Build the report from the supported
set `fitTypes(ModelType)` minus the types you fit, which gives the not-run set. State each
not-run type and that its parameters remain at the baseline. For the types you did run, use
`diffTable.Status` (when the column is present, per the Step 7 existence check) to disclose
Inert and Collinear parameters, frozen before the fit and left at the baseline; where absent, build
the report from the fit-type set alone. Name which baseline the untouched parameters carry: `new`
defaults, or the imported parent's coefficients (Step 6). Report the ENTIRE not-run set, not
just the one glaring omission. Do not over-claim: in-sample residuals are not validation plots,
`errorStat.Final` is in-sample RMSE, and the model is not "ready for use" or "validated."
Neither `export` nor `set` checks completeness, so this report is the only thing between a
silently partial `.tir` and the user.

### Inspect by plotting (supplementary)

Plotting is never required by the fit, but a human review often wants it. Offer it rather than
producing a figure unrequested, and use the shipped methods (`tireData.plot`, `tireModel.plot`)
rather than pulling channels off the object and calling generic `plot`, which discards the
metadata-derived labels and units and invites fabricated axis or coordinate-frame claims. Load
`references/inspect-by-plotting.md` for the options, arguments, and examples.

### Advanced: fine-tune the fit on user request

Never change the default fit on your own initiative to chase a lower in-sample residual. A
user may ask to steer the fit (`Weight`, `Parameters`, `FixedParameters`,
`LowerBounds`/`UpperBounds`, `Solver`, `optimoptions`); each is a supported way
to do so, applied only when asked, and a weighted or steered fit must be disclosed in the Step 9
report. Load `references/advanced-fit-tuning.md` for each option and its guardrails before using
any of them.

### Partial invocation

When the user asks for a single step (just import, just export, just plot, or convert), do
that step correctly, mention that the fuller fitting workflow and the Tire Manager app (a GUI
alternative that auto-routes data) exist, then stop. Do not force the end-to-end workflow onto
a narrow request. The Step 9 scope report applies only when the user actually fits.

### Adjacent operation: convert a fitted model to another type

Not a step in the linear schedule. Offer it when the user already has a fitted model and wants it
re-expressed as another type. `convert(mdl, TargetType)` **requires Optimization Toolbox** and is
approximate and lossy on downgrades (MF6.2 to Fiala drops combined, relaxation, and pressure
behavior), so disclose the lossiness as Step 9 discloses unfit types and never present a downgraded
conversion as equivalent to the source. Load `references/convert-operation.md` for the signature,
the MF51-to-MF52 fast path, the guardrails, and delivery via Steps 8 and 9.

## Key Functions

All ship with the Vehicle Dynamics Blockset Extended Tire Features support package. The
model-type and fit-type SETS are release-dependent, which is why the workflow queries them
(`modelTypes`, `fitTypes`) rather than asserting a fixed list. Available From flags the one
function newer than the R2025a support-package floor.

| Function | Purpose | Available From |
|----------|---------|----------------|
| `tireData.import` | Import measurement files to a `tireData` array, one element per file |  |
| `summaryTable` | Per-channel `range`/`mean` statistics, the classification foundation |  |
| `split` / `crop` | Separate into discrete levels / trim unusable rows within an object |  |
| `coordinateTransform` | Convert a `tireData` object to a coordinate system (for example `"ISO"`) |  |
| `tireData.plot` | Plot measured channels; `DataVariableNames` picks the axes, `ColorBy` groups by condition |  |
| `vdyntire.tiremodels.modelTypes` | Query the valid model types |  |
| `vdyntire.tiremodels.fitTypes` | Query the fittable types and their schedule order for a model type |  |
| `tireModel.new` / `tireModel.import` | Seed a model from defaults / from a parent file or struct |  |
| `tireModel.fitTypeDependency` | Upstream prerequisites for a fit type (diagnostic, not enumeration) | R2026a |
| `tireModel.fit` | Fit one fit type; returns a NEW model plus diagnostics |  |
| `tireModel.export` / `tireModel.set` | Write a `.tir` / push parameters onto a VDB tire block |  |
| `tireModel.convert` | Re-express a fitted model as another type (adjacent operation) |  |
| `tireModel.plot` | Plot a model's response, driven by a `tireData` or by specified conditions |  |

## Patterns

Load `references/worked-example.md` for concrete code putting the three judgments together end to
end: querying `fitTypes` and iterating in returned order, classifying channel content with
`summaryTable` to select each fit type's subset, threading `mdl = fit(mdl, ...)` through the
schedule, and building the not-run set with `setdiff` for the scope report.

## Conventions

**Always:** query `modelTypes`/`fitTypes` and iterate `fitTypes` in returned order (never embed a
list); route each fit type by channel content (Step 2 plus the reference table); reassign
`mdl = fit(mdl, ...)` every step so fits accumulate in dependency order; report the complete not-run
set up front, naming the baseline (Step 9); gate on class availability and Optimization Toolbox
install plus license before fitting (Step 0).

**Ask first:** when the user names no model type, stop and ask (Step 3); before
substituting a nearest supported type for an unsupported one (validate it against `modelTypes`);
before assigning `tireData` geometry properties from a user-supplied tire size the data lacks;
before overwriting an existing `.tir` (pass `overwrite=true` deliberately).

**Never:**
- Hand-roll Magic Formula or hand-write a `.tir` when the API is available.
- Call `vdyntire.internal.*` helpers directly; reach behavior through public methods.
- Seed a fit from `tireModel.builtin`.
- Use `filter`, `mean`, or `downsample` to select rows; they are per-object processing.
- Label in-sample residuals as validation, or call a partial model "ready" or "validated."

## Common Mistakes

Load `references/common-mistakes.md` for the failure-mode lookup table, each row giving a
mistake, why it is wrong, and the correct approach.

----

Copyright 2026 The MathWorks, Inc.

----
