# CurveFitterAppController — API Reference

Complete API for reading and writing the Curve Fitter app state.

**Controller location:** `scripts/CurveFitterAppController.m`

**Creating the controller:**
```matlab
controller = CurveFitterAppController();
```

The controller requires R2022a or later. Methods that access functionality only available in newer releases will throw an error with a clear message indicating what went wrong and suggesting corrective action.

## Version Convention

All methods documented here are available in **R2022a and later** unless an "Available" column indicates otherwise in the method table.

## Quick Start

```matlab
controller = CurveFitterAppController();
controller.openApp();
controller.selectFittingXData('xdata');
controller.selectFittingYData('ydata');
controller.setFittype('poly2');
% Auto-fit fires automatically — check results:
gof = controller.getGoodnessOfFit();
controller.exportFitToWorkspace(FitVariable="myFit")
```

**Per-fit scope:** Unless otherwise specified, all controller methods that read or write app state operate on the **currently selected fit only**. This includes fitting data, validation data, fit type, fit options, exclusions, and visualization settings. To apply changes across multiple fits, select each fit individually and call the methods on each.

---

## App Lifecycle

| Method | Signature | Description |
|--------|-----------|-------------|
| `openApp` | `controller.openApp()` | Opens the app if not already running; brings the app into focus if already open |
| `openAppWithData` | `alertText = controller.openAppWithData(x, y)` or `alertText = controller.openAppWithData(x, y, z)` or `alertText = controller.openAppWithData(x, y, z, w)` | Opens app and sets fitting data. `z` and `w` are optional — omit them for curve data. If the app is already open, creates a new fit with the provided data. Dismisses any alert dialog and returns its text (empty char if none). |
| `closeApp` | `controller.closeApp()` | Closes the app. If unsaved changes exist, a save dialog appears that requires user interaction. |

**Always use the controller's open methods** to launch the app rather than calling `curveFitter(...)` directly. Always capture the returned `alertText` from `openAppWithData` and `openSession` — if non-empty, report it to the user before proceeding.

---

## Session Overview (Read)

| Method | Signature | Returns |
|--------|-----------|---------|
| `getAllFitInformation` | `fitInfo = controller.getAllFitInformation()` | Struct array with full information for every fit in the session |
| `getFitInformation` | `fitInfo = controller.getFitInformation()` | Struct with full information for the currently selected fit (same fields as one element of `getAllFitInformation`) |
| `getAllFitNames` | `names = controller.getAllFitNames()` | String array of all fit names |
| `getFitName` | `fitName = controller.getFitName()` | Name of the currently selected fit |
| `getFitState` | `state = controller.getFitState()` | Fit state: `"INCOMPLETE"`, `"GOOD"`, `"WARNING"`, or `"ERROR"` |
| `hasUnsavedChanges` | `tf = controller.hasUnsavedChanges()` | `true` if session has unsaved modifications |
| `getSessionInfo` | `[name, path] = controller.getSessionInfo()` | Session name and file path (path empty if never saved) |

### FitState Values

| State | Report to User As | Meaning |
|---|---|---|
| `INCOMPLETE` | Incomplete | Insufficient data to fit (e.g., missing Y data for curves, mismatched X/Y sizes without Z data) or auto-fit is disabled and `runFit()` has not been called |
| `GOOD` | **Complete** | Fit completed without errors or warnings. Does not indicate fit quality — only that no warnings were thrown. A convergence message may still be present. Never report as "Good". |
| `WARNING` | Warning | Fit completed but warnings were thrown during fitting |
| `ERROR` | Error | Fit failed with an error (e.g., incompatible data, Inf/NaN computed during fitting) |

### `fitInfo` Struct Fields

Each element returned by `getAllFitInformation` (or the single struct from `getFitInformation`) contains:

| Field | Type | Description |
|-------|------|-------------|
| `FitName` | char | Display name (e.g., `'fit 1'`) |
| `XDataName` | char | X data variable name (empty if unset) |
| `YDataName` | char | Y data variable name (empty if unset) |
| `ZDataName` | char | Z data variable name (empty if unset) |
| `WDataName` | char | W (weights) variable name (empty if unset) |
| `Fittype` | char | Fit type string (e.g., `'poly1'`, `'exp2'`) |
| `ExclusionRules` | cell | Active exclusion rule descriptions |
| `ResidualsPlotVisible` | logical | Whether residuals plot is shown |
| `CoefficientBounds` | table | Table with `Lower`/`Upper` columns, indexed by coefficient name |
| `CoefficientValues` | double vector | Coefficient values, or `[]` if not computed |
| `CoefficientNames` | cell | Coefficient names, or `{}` if not computed |
| `Goodness` | struct | Goodness-of-fit struct (`sse`, `rsquare`, `dfe`, `adjrsquare`, `rmse`) |
| `FitState` | enum | `INCOMPLETE`, `GOOD`, `WARNING`, or `ERROR` |
| `ErrorString` | char | Error message (empty if none) |
| `WarningString` | char | Warning message (empty if none) |
| `ConvergenceString` | char | Convergence info (empty if none) |
| `AutoFitEnabled` | logical | Whether auto-fit is enabled for this fit |
| `Formula` | char | Formula string for the fit type |
| `ValidationGoodness` | struct | Goodness-of-fit struct (`sse`, `rmse`) against validation data (empty if no validation data) |
| `InteractiveExclusions` | logical vector | Points excluded interactively; `true` = excluded (empty if none) |
| `FitOptions` | fitoptions | The `fitoptions` object for this fit |
| `ContourPlotVisible` | logical | Whether contour plot is shown |
| `PredictionBoundConfidenceLevel` | double | Confidence level for prediction bounds (0 if off) |
| `FitPlotVisible` | logical | Whether fit plot is shown |

---

## Session Management (Write)

| Method | Signature | Description |
|--------|-----------|-------------|
| `openSession` | `alertText = controller.openSession(filepath)` | Opens a saved session. `filepath` must end in `.sfit`. If omitted, opens a file browser for the user to select. Clears the existing session; if unsaved changes exist, a save dialog appears that requires user interaction. Dismisses any alert dialog and returns its text (empty char if none). |
| `startNewSession` | `controller.startNewSession()` | Discards current session and starts fresh. If unsaved changes exist, a save dialog appears that requires user interaction. |
| `saveSession` | `controller.saveSession()` | Saves to the existing session file path. Errors if no path exists (use `saveSessionAs` instead). |
| `saveSessionAs` | `controller.saveSessionAs(filepath)` | Saves to specified `.sfit` file. If `filepath` omitted/empty, opens a file browser for the user to select. |

**Confirm before saving or loading:** Before calling `saveSessionAs`, confirm the file path and name with the user. Before calling `openSession` with a specific file, confirm which session file to load if multiple `.sfit` files exist or the user's request is ambiguous (see SKILL.md Rule 16).

---

## Fit Management

| Method | Signature | Description |
|--------|-----------|-------------|
| `createNewFit` | `fitName = controller.createNewFit()` | Creates a new blank fit. **Always capture the returned name.** |
| `duplicateFit` | `newFitName = controller.duplicateFit()` | Duplicates the currently selected fit. **Always capture the returned name.** |
| `selectFit` | `controller.selectFit(fitName)` | Selects (displays) the named fit |
| `renameFit` | `controller.renameFit(fitName, newName)` | Renames a fit |
| `deleteFit` | `controller.deleteFit(fitName)` | Permanently deletes the named fit. A confirmation dialog appears that requires user interaction. |

**`createNewFit` behavior:** Creates a completely blank fit — no data, no fit type, auto-fit enabled. It inherits nothing from the current fit. Use `duplicateFit()` when you want a copy that preserves data, fit type, and options.

**What `duplicateFit` copies:** Duplicating a fit copies everything — name (with "copy N" appended, incrementing), fitting data, validation data, fit type, fit options, exclusions, and visualization settings.

**Default naming:** Newly created fits are named `"untitled fit N"` (e.g., `"untitled fit 1"`, `"untitled fit 2"`). Do not assume shortened names like `"fit 1"`. Always capture the return value of `createNewFit()` or `duplicateFit()` to get the actual name.

**`openAppWithData` when app is already open:** Creates a new fit with the provided data — it does not replace the session or modify existing fits.

### Multi-Fit Workflow Pattern

When operating across multiple fits, work sequentially per fit: select → modify → verify → move to next. Do not batch modifications across all fits and verify after — this leads to stale state, redundant selection, and missed errors.

---

## Data Selection — Fitting Data

### Read

| Method | Signature | Returns |
|--------|-----------|---------|
| `getFittingDataVariableNames` | `[xName, yName, zName, wName] = controller.getFittingDataVariableNames()` | Variable name strings; empty `''` if unset |
| `isSurfaceFit` | `tf = controller.isSurfaceFit()` | `true` if Z data is assigned (surface fit) |

### Write — From workspace arrays

The `variableName` argument is the name of a numeric variable in the workspace.

| Method | Signature | Description |
|--------|-----------|-------------|
| `selectFittingXData` | `controller.selectFittingXData(variableName)` | Sets X fitting data |
| `selectFittingYData` | `controller.selectFittingYData(variableName)` | Sets Y fitting data |
| `selectFittingZData` | `controller.selectFittingZData(variableName)` | Sets Z fitting data (surface fits) |
| `selectFittingWData` | `controller.selectFittingWData(variableName)` | Sets W (weights) fitting data |

**Confirm when ambiguous:** If multiple candidate variables exist in the workspace and the user's request doesn't clearly identify which to use, propose variable assignments and confirm before calling these methods (see SKILL.md Rule 16).

### Write — From table columns

The `tableName` argument is the name of a table variable in the workspace. The `columnName` argument is the name of a numeric column in that table.

| Method | Signature | Description |
|--------|-----------|-------------|
| `selectFittingXDataFromTable` | `controller.selectFittingXDataFromTable(tableName, columnName)` | Sets X fitting data from table column |
| `selectFittingYDataFromTable` | `controller.selectFittingYDataFromTable(tableName, columnName)` | Sets Y fitting data from table column |
| `selectFittingZDataFromTable` | `controller.selectFittingZDataFromTable(tableName, columnName)` | Sets Z fitting data from table column (surface fits) |
| `selectFittingWDataFromTable` | `controller.selectFittingWDataFromTable(tableName, columnName)` | Sets W (weights) fitting data from table column |

### Write — Clearing

| Method | Signature | Description |
|--------|-----------|-------------|
| `clearFittingXData` | `controller.clearFittingXData()` | Clears X |
| `clearFittingYData` | `controller.clearFittingYData()` | Clears Y |
| `clearFittingZData` | `controller.clearFittingZData()` | Clears Z |
| `clearFittingWData` | `controller.clearFittingWData()` | Clears W |
| `clearAllFittingData` | `controller.clearAllFittingData()` | Clears all (X, Y, Z, W) |

---

## Data Selection — Validation Data

### Read

| Method | Signature | Returns |
|--------|-----------|---------|
| `getValidationDataVariableNames` | `[xName, yName, zName] = controller.getValidationDataVariableNames()` | Variable name strings; empty `''` if unset |

### Write — From workspace arrays

The `variableName` argument is the name of a numeric variable in the workspace.

| Method | Signature | Description |
|--------|-----------|-------------|
| `selectValidationXData` | `controller.selectValidationXData(variableName)` | Sets X validation data |
| `selectValidationYData` | `controller.selectValidationYData(variableName)` | Sets Y validation data |
| `selectValidationZData` | `controller.selectValidationZData(variableName)` | Sets Z validation data (surface fits) |

**Confirm when ambiguous:** If multiple candidate variables exist in the workspace and the user's request doesn't clearly identify which to use, propose variable assignments and confirm before calling these methods (see SKILL.md Rule 16).

### Write — From table columns

The `tableName` argument is the name of a table variable in the workspace. The `columnName` argument is the name of a numeric column in that table.

| Method | Signature | Description |
|--------|-----------|-------------|
| `selectValidationXDataFromTable` | `controller.selectValidationXDataFromTable(tableName, columnName)` | Sets X validation data from table column |
| `selectValidationYDataFromTable` | `controller.selectValidationYDataFromTable(tableName, columnName)` | Sets Y validation data from table column |
| `selectValidationZDataFromTable` | `controller.selectValidationZDataFromTable(tableName, columnName)` | Sets Z validation data from table column (surface fits) |

### Write — Clearing

| Method | Signature | Description |
|--------|-----------|-------------|
| `clearValidationXData` | `controller.clearValidationXData()` | Clears X |
| `clearValidationYData` | `controller.clearValidationYData()` | Clears Y |
| `clearValidationZData` | `controller.clearValidationZData()` | Clears Z |
| `clearAllValidationData` | `controller.clearAllValidationData()` | Clears all validation data |

---

## Exclusion Rules

| Method | Signature | Description |
|--------|-----------|-------------|
| `getExclusionRules` | `exclusionRules = controller.getExclusionRules()` | Returns cell array of active rule descriptions |
| `setExclusionRule` | `controller.setExclusionRule(variable, operator, value)` | Adds a rule. Replaces conflicting rule on same variable+direction. |
| `clearAllExclusionRules` | `controller.clearAllExclusionRules()` | Removes all rules |

**Scope:** `clearAllExclusionRules()` only affects the currently selected fit. To clear rules across multiple fits, select each fit individually and call it on each.

**Parameters for `setExclusionRule`:**
- `variable`: `'X'`, `'Y'`, `'Z'`, or `'W'`
- `operator`: `'<'`, `'<='`, `'>'`, `'>='`
- `value`: numeric scalar threshold

Each variable supports at most one upper-bound rule (`<` or `<=`) and one lower-bound rule (`>` or `>=`). Setting a new rule replaces any existing rule in the same direction for that variable.

---

## Interactive Point Exclusions

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInteractiveExclusions` | `excluded = controller.getInteractiveExclusions()` | Returns logical vector; `true` = excluded point |
| `toggleInteractiveExclusions` | `controller.toggleInteractiveExclusions(indices)` | Toggles exclusion for points at given indices |
| `clearAllInteractiveExclusions` | `controller.clearAllInteractiveExclusions()` | Re-includes all excluded points |

---

## Fit Type

| Method | Signature | Description |
|--------|-----------|-------------|
| `getFittype` | `fittypeString = controller.getFittype()` | Returns current fit type string |
| `setFittype` | `controller.setFittype(fittypeInput)` | Sets fit type (see syntax below) |
| `setFittype` | `controller.setFittype(fittypeInput, Independent=..., Dependent=...)` | Sets fit type with custom variable names |

### `setFittype` Syntax

**Library model names:**
```matlab
controller.setFittype('poly2')
controller.setFittype('exp1')
```

**Custom nonlinear equations:**
```matlab
controller.setFittype('a*exp(b*x)+c')
```

**Custom linear equations** (cell array of terms):
```matlab
controller.setFittype({'1', 'x', 'x^2'})
```

**File-based equations** (M-file name, must include all function inputs):
```matlab
controller.setFittype('myFitFunction(a, b, x)')
```

**Custom variable names** (optional name-value arguments):
- `Independent` — string or cell array of strings; defaults to `"x"` for curves or `{"x", "y"}` for surfaces
- `Dependent` — string; defaults to `"y"` for curves or `"z"` for surfaces

```matlab
controller.setFittype('a*exp(b*t)+c', Independent="t", Dependent="voltage")
controller.setFittype('a*x+b*y+c', Independent={"x", "y"})
```

---

## Fitting

| Method | Signature | Description |
|--------|-----------|-------------|
| `getAutoFit` | `tf = controller.getAutoFit()` | Returns `true` if auto-fit is enabled |
| `setAutoFit` | `controller.setAutoFit(tf)` | Enable/disable auto-fit |
| `runFit` | `controller.runFit()` | Manually trigger fit. Errors if auto-fit is enabled. |

**Auto-fit on new fits:** New fits (from `createNewFit()` or `openAppWithData()` on an already-open app) start with auto-fit enabled. If you need manual mode, call `setAutoFit(false)` after creation.

**When to use manual mode:** `setAutoFit(false)` is useful when batching multiple changes (fit type, options, exclusions, data) before fitting, or when fitting is slow and the user doesn't want to wait between each change. Once in manual mode, call `runFit()` when ready. Do not automatically re-enable auto-fit after calling `runFit()` — the user chose manual mode for a reason.

---

## Fit Options

| Method | Signature | Description |
|--------|-----------|-------------|
| `getFitOptions` | `options = controller.getFitOptions()` | Returns the `fitoptions` object for the current fit |
| `setFitOptions` | `controller.setFitOptions(options)` | Sets the `fitoptions` object for the current fit |

Use the standard `fitoptions` API to inspect and modify the options object. Inspect the output of `getFitOptions()` to discover which properties are available and their current values.

**Example:**
```matlab
opts = controller.getFitOptions();
opts.Robust = 'Bisquare';
opts.StartPoint = [1 0.5 0];
controller.setFitOptions(opts);
```

> **Note:** Some `fitoptions` properties are release-gated and do not exist in earlier MATLAB releases (e.g., `ExtrapolationMethod` in R2023a+, `ConstraintPoints` and `Algorithm='Interior-Point'` in R2025a+). `ConstraintPoints` and `Algorithm='Interior-Point'` require Optimization Toolbox.

---

## Results

| Method | Signature | Returns |
|--------|-----------|---------|
| `getFitStatusMessages` | `messages = controller.getFitStatusMessages()` | Struct with fields: `Error`, `Warning`, `Convergence` (each a char; empty if no issues) |
| `getFormula` | `formulaStr = controller.getFormula()` | Formula string (e.g., `'p1*x+p2'`); empty if no fit type set |
| `getCoefficientNames` | `coeffNames = controller.getCoefficientNames()` | Cell array of coefficient names; `{}` if no fit result |
| `getCoefficientValues` | `coeffValues = controller.getCoefficientValues()` | Numeric vector of coefficient values; `[]` if no fit result |
| `getCoefficientConfidenceIntervals` | `ci = controller.getCoefficientConfidenceIntervals()` | 2-by-N matrix `[lower; upper]` for each coefficient; errors if no fit result |
| `getGoodnessOfFit` | `gof = controller.getGoodnessOfFit()` | Struct: `sse`, `rsquare`, `dfe`, `adjrsquare`, `rmse`; empty if no fit |
| `getGoodnessOfValidation` | `gov = controller.getGoodnessOfValidation()` | Struct: `sse`, `rmse`; empty if no fit or no validation data |
| `getResultsPanelText` | `text = controller.getResultsPanelText()` | Formatted results text matching the Results panel display; includes fit type, formula, coefficients with confidence bounds, GOF, validation GOF |

---

## Visualization

| Method | Signature | Description |
|--------|-----------|-------------|
| `getFitPlotVisibility` | `tf = controller.getFitPlotVisibility()` | Returns fit plot visibility |
| `setFitPlotVisibility` | `controller.setFitPlotVisibility(tf)` | Show/hide fit plot |
| `getResidualsPlotVisibility` | `tf = controller.getResidualsPlotVisibility()` | Returns residuals visibility |
| `setResidualsPlotVisibility` | `controller.setResidualsPlotVisibility(tf)` | Show/hide residuals |
| `getContourPlotVisibility` | `tf = controller.getContourPlotVisibility()` | Returns contour plot visibility (`false` for curve fits) |
| `setContourPlotVisibility` | `controller.setContourPlotVisibility(tf)` | Show/hide contour plot |
| `getPredictionBoundConfidenceLevel` | `level = controller.getPredictionBoundConfidenceLevel()` | Returns confidence level as a percentage on (0, 100) exclusive, or 0 if bounds are off |
| `setPredictionBoundConfidenceLevel` | `controller.setPredictionBoundConfidenceLevel(level)` | Set level as a percentage on (0, 100) exclusive (e.g., `95` for 95%). Use `clearPredictionBounds()` to hide. |
| `clearPredictionBounds` | `controller.clearPredictionBounds()` | Hide prediction bounds |
| `getLegendVisibility` | `tf = controller.getLegendVisibility()` | Returns legend visibility |
| `setLegendVisibility` | `controller.setLegendVisibility(tf)` | Show/hide legend |
| `getGridVisibility` | `tf = controller.getGridVisibility()` | Returns grid visibility |
| `setGridVisibility` | `controller.setGridVisibility(tf)` | Show/hide grid |
| `getResiduals` | `residuals = controller.getResiduals()` | Returns the residual vector (observed minus fitted) for the current fit |

**Prediction bounds:** Only supported for parametric (regression) fit types — not interpolant or smoothing fit types.

**Constraint point incompatibility:** `setPredictionBoundConfidenceLevel` will error if constraint points are active on the current fit. Remove constraint points before setting prediction bounds.

---

## Export

| Method | Signature | Description | Available |
|--------|-----------|-------------|-----------|
| `exportFitToWorkspace` | `controller.exportFitToWorkspace(FitVariable=..., GoodnessVariable=..., OutputVariable=...)` | Exports fit object, GOF struct, and/or output struct to workspace variables | R2022a+ |
| `exportToFigure` | `controller.exportToFigure()` | Creates a standalone MATLAB figure from current fit figure | R2022a+ |
| `generateCode` | `controller.generateCode()` | Generates a MATLAB function reproducing the session; opens in Editor | R2022a+ |

**`generateCode` behavior:** Opens the generated code in the MATLAB Editor. Has no return value — do not assign output.

**Default name derivation:** When exporting with `true` (default names), the variable name is derived from the fit name using `matlab.lang.makeValidName`. For example, a fit named `"untitled fit 1"` exports as `untitledFit1`. The export happens directly — no dialog appears. Consider renaming fits to meaningful names before exporting so that workspace variables are easy to identify.

**Confirm before exporting:** Before calling `exportFitToWorkspace`, confirm the variable names with the user (e.g., "I'll export as `fitresult` and `gof` — OK?"). Before calling `exportToSimulinkLUT` or `exportToSimulinkLUTEvenSpacing`, confirm the breakpoint values/scheme. After exporting, report what was exported. See SKILL.md Rule 16.

| `exportToSimulinkLUT` | `modelName = controller.exportToSimulinkLUT(xBreakpoints)` | Exports curve fit as Simulink LUT with explicit X breakpoints (requires Simulink) | R2022b+ |
| `exportToSimulinkLUT` | `modelName = controller.exportToSimulinkLUT(xBreakpoints, yBreakpoints)` | Exports surface fit as Simulink LUT with explicit X and Y breakpoints (requires Simulink) | R2022b+ |
| `exportToSimulinkLUTEvenSpacing` | `modelName = controller.exportToSimulinkLUTEvenSpacing(xFirst, xSpacing, xNum)` | Exports curve fit as Simulink LUT with even-spacing specification (requires Simulink) | R2022b+ |
| `exportToSimulinkLUTEvenSpacing` | `modelName = controller.exportToSimulinkLUTEvenSpacing(xFirst, xSpacing, xNum, yFirst, ySpacing, yNum)` | Exports surface fit as Simulink LUT with X and Y even-spacing specifications (requires Simulink) | R2022b+ |
| `launchOptimizedLookupTableWizard` | `controller.launchOptimizedLookupTableWizard()` | Launches the Lookup Table Optimizer wizard (requires Simulink and Fixed-Point Designer) | R2024a+ |

### `exportFitToWorkspace` Details

Exports the fit result objects for the currently selected fit to the MATLAB base workspace. Each parameter controls one object:

| Parameter | Controls | Default when `true` |
|-----------|----------|---------------------|
| `FitVariable` | `cfit`/`sfit` fit object | `<fitName>` (e.g., `fit1`) |
| `GoodnessVariable` | Goodness-of-fit struct | `<fitName>_gof` |
| `OutputVariable` | Output struct | `<fitName>_output` |

The UI convention uses `"fittedmodel"`, `"goodness"`, and `"output"` as default names.

**Parameter values:**
- `true` (default) — export using the auto-generated default name derived from the fit name
- `"customName"` — export using the specified name
- `false` — do not export this object

**Examples:**
```matlab
% Export all three with default names
controller.exportFitToWorkspace()

% Export only the fit object with a custom name
controller.exportFitToWorkspace(FitVariable="myModel", GoodnessVariable=false, OutputVariable=false)

% Export all with custom names
controller.exportFitToWorkspace(FitVariable="expFit", GoodnessVariable="expGof", OutputVariable="expOut")
```

### `exportToSimulinkLUT` / `exportToSimulinkLUTEvenSpacing` Details

Both methods accept no arguments to use default breakpoints (11 evenly-spaced points from data range). Provide explicit breakpoints or spacing parameters for custom control.

---

---

## Utility Scripts

These are standalone functions shipped alongside the controller (in `scripts/`), not controller methods.

| Function | Signature | Description |
|----------|-----------|-------------|
| `getFittypeTable` | `t = getFittypeTable()` | Returns a table of all built-in fit types with columns: `fittype`, `category`, `displayName`, `dimension` |
| `getFittypeTable` | `t = getFittypeTable("curve")` | Filters to curve-only and both-dimension types |
| `getFittypeTable` | `t = getFittypeTable("surface")` | Filters to surface-only and both-dimension types |

Use this to discover valid `fittypeString` values for `setFittype()`. Custom equations (e.g., `'a*exp(b*x)+c'`) are not listed — pass them directly as strings.

---

## Error Handling

Controller error messages are informative and include guidance on corrective action. If a method throws an error:
- Read the error message — it will indicate what went wrong and suggest a fix
- If the corrective action is clear, take it (e.g., call `openApp()` first, set data before fit type)
- If the error is unclear, report it to the user for guidance

----

Copyright 2026 The MathWorks, Inc.

----
