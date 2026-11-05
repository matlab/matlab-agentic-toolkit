# Common Mistakes

Load this as a reinforcement lookup when reviewing a fitting workflow for the failure modes this
skill guards against.

| Mistake | Why it is wrong | Correct approach |
|---------|-----------------|------------------|
| Hardcoding or try/catch-probing the fit-type list | Types and order are per-model-type and release-dependent | Query `fitTypes(ModelType=...)` and iterate in returned order; use `fitTypeDependency` only to diagnose |
| Routing data by filename, subfolder, or TESTMETH | `fit` ignores metadata; wrong-condition data biases the fit and only warns | Classify channel content (Step 2) and select objects per the reference table |
| Passing every file to every fit type | `fit` tolerates it and only warns, producing a silently biased fit | Route the matching subset to each fit type |
| Hand-setting `FNOMIN`, limits, or dimensions as model properties | These are data-driven fit types; hand-setting skips the fit and misscales downstream force fits | Fit `Nominal`, `Limits`, `Dimensions` as types, in order |
| Discarding the fit return or re-seeding each step | `fit` does not mutate; nothing accumulates and dependency order becomes meaningless | Reassign `mdl = fit(mdl, ...)` every step |
| Seeding from `tireModel.builtin` | `fit` errors on a builtin model | Seed with `tireModel.new`, or `tireModel.import` for a variant |
| Reporting only the glaring omission, or calling the model validated | Silent partial coverage hides fitness; in-sample RMSE is not validation | Report the complete not-run set and baseline; never over-claim |
| Assuming imported angles are degrees | Recognized-format import converts angles to radians | Treat angles as radians after a recognized-format import; supply units yourself on the CSV path |
| Hand-rolling plots with generic `plot(x,y)` and invented labels | Reinvents the API's automatic labels, units, and legend, and risks fabricated axis or coordinate-frame text | Plot with `tireData.plot`/`tireModel.plot`; pass `DataVariableNames` and `ColorBy` |

----

Copyright 2026 The MathWorks, Inc.

----
