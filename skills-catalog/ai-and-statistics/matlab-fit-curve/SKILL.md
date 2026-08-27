---
name: matlab-fit-curve
description: Fit curves and surfaces interactively with the Curve Fitter app for a complete no-code fitting workflow. Invoke this skill when the Curve Fitter app, cftool, curveFitter, or "curve fitting tool/app" is mentioned in any way. Also use when exploring or comparing fit types (regression, interpolation, smoothing, splines, custom equations); excluding outliers interactively; iterating on a fitting workflow; help choosing a fit type; and exporting to a figure, generating MATLAB code, fits to the workspace, and to Simulink Lookup Tables.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# Interactive Curve and Surface Fitting

Guides interactive curve and surface fitting through the Curve Fitter app as part of the Curve Fitting Toolbox. Covers the full in-app workflow of selecting data, exploring fit types, modifying with fit options, inspecting fits visually and numerically, then exporting results.

## When to Use

**No-code fitting**
- Users who want to fit curves or surfaces without writing code
- Users who want to start interactively and generate code later to continue in the command line

**Interactive exploration**
- Exploring fit types when the best model is unknown
- Iterating on fits with visual feedback
- Maintaining and comparing multiple fits in a single session
- Discovering available fit types, options, and features

**App-specific features**
- Exporting fits to Simulink lookup tables (only available through the app)
- Excluding data points or regions iteratively with visual feedback
- Loading or continuing a saved session (`.sfit`) for convenience or collaboration

## When NOT to Use

**CLI workflows (no app involvement)**
- User is already writing code and does not want the app involved
- Using `fit()`, `fittype()`, `fitoptions()` directly in their own scripts/functions
- The desired fit type, data, and options are already known and the user wants code
- Many fits that would be difficult to manage in the app

**Spline workflows**
- Spline CLI functions (`csapi`, `csaps`, `fnbrk`, etc.)
- `splinetool` or `bspligui` apps

**Other tools and domains**
- Base MATLAB functions — `interp1`, `pchip`, `scatteredInterpolant`, `griddedInterpolant`, `spline`, `smoothdata`
- Basic Fitting tool — polynomials, spline interpolant, pchip interpolant; built into MATLAB figures
- Statistics and Machine Learning Toolbox — statistical modeling, cross-validation, dataset partitioning, separate test data (`fitlm`, `fitnlm`, `cvpartition`)
- Optimization Toolbox — any workflow using Optimization Toolbox functions (`lsqnonlin`, `fmincon`, `lsqcurvefit`, `lsqlin`)

If CLI is the better approach, do not suggest app workflows. If neither section clearly applies, use these signals to disambiguate:

| Signal | Recommendation | Why |
|--------|---------------|-----|
| User says "compare" fits | **Depends** | Visual curve comparison -> CLI (overlaid on same axes). Comparing goodness of fit metrics -> App (Table of Fits). Interactive adjustment -> App. |
| User just wants to visualize a single fit | **CLI** | CLI plotting handles this well |
| User wants to overlay multiple fits on same axes | **CLI** | App shows fits in separate figures only |
| User needs to exclude outliers by visual inspection | **App** | Point-and-click exclusion is easier than computing indices |
| User needs formal validation data | **App** | The app has explicit validation data support |

**User instructions always take precedence.** If the user explicitly asks for CLI code — even mid-app-workflow — write CLI code. The agent may also offer CLI as an alternative when the controller cannot fulfill a request.

Do not spontaneously switch between app and CLI mid-workflow. If the user's intent is still unclear after consulting the table above, ask whether they prefer working interactively in the app or with code.

If the user asks how to perform a workflow themselves, where to find a feature in the UI, or whether a capability is available in the app, see `references/curve-fitter-layout.md` for the full layout and feature locations.

## Must-Follow Rules

### Release Compatibility

1. **Use `cftool` for R2021b and earlier; `curveFitter` for R2022a+** — never instruct the user to use both in the same workflow. Users often say "cftool" out of habit on R2022a+ — still use `curveFitter` or the controller regardless of user terminology.
2. **`CurveFitterAppController` (`scripts/CurveFitterAppController`) requires R2022a+** — it will error on earlier releases. On R2021b and earlier, the agent CANNOT read or write app state programmatically. The only programmatic interaction is `cftool` input arguments (`cftool(x, y)`, `cftool(x, y, z)`, etc.). All other actions (changing fit types, excluding points, exporting) must be performed by the user through the app UI — guide them using general knowledge of cftool, don't promise action. `getFittypeTable()` still works independently for discovering fit types. On R2022a+, prefer the controller's `open*` methods to launch the app (they handle version checking internally). On pre-R2022a, set expectations upfront: everything besides launching the app or launching the app with data is unsupported for agentic workflows on this release — you can guide the user through the UI but cannot perform actions for them. Offer CLI fitting as an alternative path. Don't let users discover limitations one by one.

   **Critical for pre-R2022a:** On these releases, ALL of the following apply:
   - Refer to the app ONLY as "cftool" or "the Curve Fitting Tool" — never "Curve Fitter"
   - Do not mention ANY controller method names (setExclusionRule, setFittype, etc.) — they do not exist on this release
   - Do not imply you can perform actions inside the app — you cannot
   - If the user says "Curve Fitter" on R2021b or earlier, say "The Curve Fitter app isn't available in [release]. I'll use cftool instead."

### API Usage

3. **Drive the app workflow via the controller API — do not spontaneously switch to CLI** — once the app is open or the user is working in the app, fitting, comparison, and exclusion work goes through the controller. Do not spontaneously generate CLI `fit()` code as a substitute for app actions. Do not pause and instruct users to click UI elements. Exceptions:
   - The user explicitly requests CLI code (user instructions always take precedence)
   - The controller has no API for the requested action — guide the user through the app UI via `references/curve-fitter-layout.md` first. Only offer CLI as an alternative if the feature isn't available in the app or the workflow is trending toward the ambiguous signals in "When NOT to Use"
   - The user explicitly says they want to perform actions themselves in the UI
4. **Internal CLI execution is permitted for efficiency** — the agent can internally execute `fit()`, `fittype()`, `fitoptions()`, etc. for quick lookups (e.g., surveying multiple fit types, checking available fit options) without generating user-facing code or mentioning it in responses. This is distinct from generating code for the user.
5. **If a controller method errors, read the error and react** — the messages are informative and will guide you to fix the syntax or inform the user.
6. **Use `getFittypeTable()` (`scripts/getFittypeTable`) to discover available fit types** — do not guess or assume the availability of fit type names or prioritize custom equations when a built-in one exists. To inspect a specific fit type, create a `fittype` object and use its methods (`formula`, `coeffnames`, `islinear`, etc.) — `fittype` objects have no public properties. Never assume or state that data "looks like" or "is suitable for" a specific model — ask the user about their data characteristics or goals instead.
7. **Read the minimum relevant state before taking actions that depend on it** — do not blindly execute commands without checking prerequisites (e.g., check dimensionality before setting a curve-only fit type, check that a fit exists before exporting). Do not read the full app state for every action — only what the specific action requires.

### Reporting Results

8. **Never make subjective value judgments on fit quality — but factual interpretation is allowed** — report all relevant goodness-of-fit metrics (not just R²) and let the user interpret. Factual, objective statements about statistical properties and tradeoffs are permitted and encouraged — these are distinct from subjective quality judgments. Do not suggest alternative fit types or approaches unless the user explicitly asks. See `references/interpreting-fit-results.md` for the full list of prohibited terms, permitted factual statements, and guidance on how to handle direct quality questions.

### Agent Behavior

9. **Load references before acting (silently)** — these are mandatory, not optional. Load liberally — when in doubt about whether you need a reference, load it. Never narrate or mention loading references in user-facing text (see Rule 10):
   - Load `references/api-reference.md` before calling any controller method for the first time in a session
   - Load `references/interpreting-fit-results.md` before reporting, comparing, or explaining fit results
   - Load `references/curve-fitter-layout.md` before answering questions about app features, UI locations, or when the controller has no API for a requested action
   - **Scope:** `curve-fitter-layout.md` covers R2022a+ (Curve Fitter) ONLY. It can indicate what features exist in cftool, but NOT where they are located in the UI. For cftool UI locations: rely on general knowledge, and when unsure say so rather than guessing.
   - **Never describe UI elements not documented in references** — if you don't know what an icon looks like or where a button is, say "I'm not certain of the exact location" rather than inventing details.
10. **The controller is invisible to the user** — everything about the controller, API, and reference files is an internal implementation detail. In user-facing responses:
    - **CRITICAL — most common violations:** "let me add the controller scripts to the path", "using the controller", "the controller's X method", "programmatically". These MUST NOT appear in any user-facing text including narration, status updates, and thinking-aloud.
    - Never mention controller class names, method names, or API syntax (e.g., don't say "I'll use setExclusionRule" — say "I'll exclude those points")
    - Never narrate internal implementation steps — don't say "let me add the controller scripts to the path", "the controller is available", "I'll use the controller to set the fit type", or "using the controller's openAppWithData method." These are invisible mechanics. From the user's perspective, you are simply performing actions in the Curve Fitter app.
    - Never mention reference file names or loading (e.g., don't say "let me check the API reference")
    - The act of loading references is itself invisible — do not say "let me check", "let me read", or "let me look up" before loading a reference file. Just load it silently and proceed.
    - Never mention the concept of a "controller" or explain that one exists or doesn't exist for a given release
    - Never mention "programmatic" control of the app — just offer actions naturally (e.g., "Would you like me to change the fit type?" not "I can programmatically set the fit type")
    - Never explain internal release reasoning (e.g., don't say "since the controller isn't available on this release" — just guide the user appropriately)
    - When no controller API exists for a requested action, guide the user through the app UI using `references/curve-fitter-layout.md`
    - Do not invent programmatic workarounds
11. **Ask before acting on ambiguity** — when a user's request is vague or underspecified (e.g., "take care of that point", "fix this", "clean up the data"), ask the user to clarify what they want before acting. For example, if excluding points, ask which points or what criteria to use. Never apply an arbitrary exclusion criterion (2σ, `isoutlier`, etc.) without user confirmation. When the user asks generically about handling or dealing with outliers (not specifically asking to exclude), present the relevant options: exclusion (interactive or rule-based) removes points from fitting, while robust fitting down-weights outliers without removing them. When the user specifically asks to exclude points, only present exclusion methods — don't suggest robust fitting as an alternative. When app state changes unexpectedly (fits disappear, session resets), describe what you observe and ask how to proceed rather than taking corrective action autonomously.
12. **Use release-appropriate terminology in responses** — for R2022a+, always refer to the app as "Curve Fitter" (not "cftool"). If the user says "cftool" on R2022a+, acknowledge their term and clarify that cftool isn't available in this release and that you'll be using Curve Fitter. For R2021b and earlier, refer to the app as "cftool" or "the Curve Fitting Tool" — never "Curve Fitter" or "Curve Fitter app." If the user asks to open "Curve Fitter" or "curveFitter" on R2021b or earlier, clarify that it isn't available in this release and that you'll be using cftool.
13. **Use display names, not library model names, in user-facing text** — library model names (`exp1`, `poly2`, `rat11`, `lowess`, `loess`, `smoothingspline`) are for programmatic use only (controller calls, scripts). In user-facing responses, use the display names from the Fit Type Gallery: "Exponential (1 term)", "Polynomial (degree 2)", "Rational (1/1)", "Smoothing Spline", "Lowess (Linear)", etc.
14. **Trust live app state over conversation memory** — always trust getter call results over what was true earlier in the conversation. Read state before acting on it. If state conflicts with what the user described, report the actual state factually. Don't diagnose unexpected state changes as bugs — the user can change the app between turns.
15. **Report WARNING states and convergence messages** — after completing a fit action, if the fit has a WARNING state or convergence messages, report them to the user and ask if they want to address them. Don't silently ignore, and don't automatically "fix" them. Exception: if the user has already acknowledged or explicitly dismissed warnings.
16. **Confirm with the user before importing or exporting** — any action that moves data into or out of the app requires explicit user confirmation before execution. State what you plan to do (file name, variable names, breakpoint values, etc.) and why you're asking (what's ambiguous or what choices you made), then wait for approval. Specific scenarios:
    - **Saving a session** — state the session name and file path before saving (e.g., "I'll save the session as `myfit.sfit` at `C:\Users\...`. OK?")
    - **Loading a session** — if exactly one `.sfit` file is detected, it can be loaded directly. If multiple exist and the user's request is ambiguous, state what you found and propose your selection (e.g., "There are multiple session files — is `analysis.sfit` the correct one?"). Do not load until confirmed.
    - **Selecting fitting/validation data** — if the correct variables are unambiguous from the prompt or workspace, proceed. If multiple candidate variables exist (e.g., `x`, `x2`, `y`, `y2`), explain the ambiguity, propose your selection, and confirm before acting (e.g., "There are several numeric variables in the workspace — I'll use `x` and `y` as the fitting data. Is that correct?"). Do NOT launch the app or select data until confirmed.
    - **Exporting variables to workspace** — propose variable names and explain what will be exported before acting (e.g., "I'll export the fit object as `fitresult` and goodness of fit as `gof` to the workspace. OK?")
    - **Exporting to Simulink LUT** — state the breakpoint values/scheme you plan to use and confirm before executing. If the user didn't specify breakpoints, propose reasonable values and wait for approval.

    Rule 16 does NOT apply to: exporting to a figure, generating code from the app, or starting a new session — these are non-destructive or already have built-in app-level dialogs.

## Workflow

```
Fitting Workflow:
- [ ] Step 1: Select data
- [ ] Step 2: Choose a fit type
- [ ] Step 3: Choose fit options
- [ ] Step 4: Fit
- [ ] Step 5: Evaluate and visualize results
- [ ] Step 6: Iterate and compare
- [ ] Step 7: Export, save, or share results
```

This workflow applies per fit. Most sessions involve one or a few fits, but additional fits can be created at Step 6 to compare approaches.

### Entry Points

- Select Curve Fitter from the Apps gallery under the Apps tab in the MATLAB Toolstrip
- For R2021b and earlier releases: `cftool(...)` (do not use `curveFitter`)
- For R2022a and later releases: `curveFitter(...)` (do not use `cftool`)

Both commands share the same input argument syntax:
- `curveFitter()` — launch the app with no data, or bring an already-open app to focus
- `curveFitter(x, y, z, w)` — launch with data, or create a new fit in an already-open app. Provide `[]` to omit an argument (e.g., use `(x, y, [], w)` for weighted curve fitting)
- `curveFitter('file.sfit')` — load a saved session (must be a `.sfit` file)

> **Note:** In agentic workflows (R2022a+), use the controller's `openAppWithData()` and `openSession()` methods instead of calling `curveFitter(...)` directly. They automatically detect and dismiss startup alert dialogs and return the alert text for reporting to the user.

### Programmatic Control

Instantiate `CurveFitterAppController` (`scripts/CurveFitterAppController`) for read/write API access in agentic workflows. Only supported in R2022a and later. See `references/api-reference.md` for the full API — all controller methods referenced in the steps below are documented there.

**Launching the app:** Use `openAppWithData()` or `openSession()` to launch the app with data or a session file. These handle launch waiting, app handle management, and automatic dismissal of any alert dialogs. Always capture the returned `alertText` — if non-empty, report it to the user before proceeding.

**Relevant controller methods:**
- `openApp()`, `openAppWithData()`, `openSession()`, `closeApp()`

### Step 1: Select Data

Assign fitting data from workspace variables. Optionally add validation data for independent fit assessment, and define exclusion rules or exclude individual points.

**Relevant controller methods:**
- `selectFittingXData()`, `selectFittingYData()`, `selectFittingZData()`, `selectFittingWData()`
- `selectFittingXDataFromTable()`, `selectFittingYDataFromTable()`, `selectFittingZDataFromTable()`, `selectFittingWDataFromTable()`
- `getFittingDataVariableNames()`, `isSurfaceFit()`
- `selectValidationXData()`, `selectValidationYData()`, `selectValidationZData()`
- `selectValidationXDataFromTable()`, `selectValidationYDataFromTable()`, `selectValidationZDataFromTable()`
- `getValidationDataVariableNames()`
- `setExclusionRule()`, `getExclusionRules()`, `clearAllExclusionRules()`
- `toggleInteractiveExclusions()`, `getInteractiveExclusions()`, `clearAllInteractiveExclusions()`

### Step 2: Choose a Fit Type

Choose a fit type based on the selected data. Built-in library models include Regression (Polynomial, Exponential, Power, Fourier, Gaussian, etc.), Interpolants, and Smoothing fit types. Custom linear and nonlinear equations are also supported, including equations defined in separate files.

To discover all available built-in fit types for the current release, run `getFittypeTable()` (`scripts/getFittypeTable`). Pass `"curve"` or `"surface"` to filter by dimensionality if known. The returned table includes a `category` column — the category `"library"` specifically refers to regression fit types. To inspect a specific fit type, create a `fittype` object and use its methods (`formula`, `coeffnames`, `islinear`, etc.) — `fittype` objects have no public properties.

**Relevant controller methods:**
- `setFittype()`, `getFittype()`
- `getFittypeTable()` (utility script)

### Step 3: Choose Fit Options

Optional unless the user wants to adjust fit quality or behavior. To discover which options are available for a given fit type, call `fitoptions(fittypeString)` in MATLAB — this returns a `fitoptions` object showing all settable properties and their current/default values.

**Relevant controller methods:**
- `setFitOptions()`, `getFitOptions()`

### Step 4: Fit

If auto-fit is enabled (default), fitting occurs automatically when data or fit type changes. If manual mode is selected, explicitly execute the fit.

**Relevant controller methods:**
- `runFit()`
- `setAutoFit()`, `getAutoFit()`

### Step 5: Evaluate and Visualize Results

After fitting, check the fit status for errors, warnings, or convergence issues. Review goodness of fit metrics and inspect the fit visually — add residuals plots, contour plots, or prediction bounds if applicable and relevant.

**Relevant controller methods:**
- `getFitState()`, `getFitStatusMessages()`
- `getGoodnessOfFit()`, `getGoodnessOfValidation()`
- `getFormula()`, `getCoefficientNames()`, `getCoefficientValues()`, `getCoefficientConfidenceIntervals()`
- `getResultsPanelText()`
- `getFitInformation()`
- `setResidualsPlotVisibility()`, `getResidualsPlotVisibility()`
- `setContourPlotVisibility()`, `getContourPlotVisibility()`
- `setPredictionBoundConfidenceLevel()`, `getPredictionBoundConfidenceLevel()`, `clearPredictionBounds()`
- `setFitPlotVisibility()`, `getFitPlotVisibility()`
- `setLegendVisibility()`, `getLegendVisibility()`
- `setGridVisibility()`, `getGridVisibility()`

### Step 6: Iterate and Compare

If unsatisfied, iterate on the current fit by adjusting the fit type, options, or exclusions (repeat steps 2-5). To compare multiple approaches, create additional fits — each maintains its own data, fit type, options, and results independently.

**Relevant controller methods:**
- `createNewFit()`, `duplicateFit()`
- `selectFit()`, `renameFit()`, `deleteFit()`
- `getAllFitNames()`, `getFitName()`
- `getAllFitInformation()`

### Step 7: Export, Save, or Share Results

Export results to transition to other workflows (Simulink, CLI scripts), save the session for later use, or share it with others.

**Relevant controller methods:**
- `exportFitToWorkspace()`
- `exportToFigure()`
- `generateCode()`
- `exportToSimulinkLUT()`, `exportToSimulinkLUTEvenSpacing()`, `launchOptimizedLookupTableWizard()`
- `saveSession()`, `saveSessionAs()`
- `hasUnsavedChanges()`, `getSessionInfo()`
- `openSession()`, `startNewSession()`

## Efficiency Patterns

- **Prefer `duplicateFit()` over `createNewFit()` + re-selecting data** — when creating a comparison fit that uses the same data, duplicate preserves everything about the current fit: name (with "copy N" appended, incrementing), fitting data, validation data, fit type, fit options, exclusions, and visualization settings — not just the data
- **Read current state before making changes** — before switching fit types or modifying options, read the current metrics and settings so results can be compared to the previous state
- **Proactive state reads prevent error-recovery cycles** — check prerequisites (data dimensionality, fit existence, fit state) before attempting actions that will error without them

## Conventions

### Reporting Results
- Report all relevant goodness of fit metrics (SSE, R-square, Adjusted R-square, RMSE, DFE)
- Include validation metrics when validation data is present
- When reporting FitState, translate: GOOD → "Complete", WARNING → "Warning", ERROR → "Error", INCOMPLETE → "Incomplete". Never use "Good" as a fit state label — users will interpret it as a quality judgment.
- Never characterize fit quality subjectively — present numbers and context
- See `references/interpreting-fit-results.md` for how to present, compare, and explain metrics to users

### Workflow Approach
- For multi-step or complex actions, understand the current state first, identify the commands and inputs needed, then execute sequentially
- **Improving a fit is a multidimensional problem** — when the user wants to improve a fit or address issues, the main levers are: fit type selection (or trying multiple fit types), fit options (start points, bounds, algorithm, robust fitting), and exclusions. All should be considered, not just one. Typically: exclusions and data cleaning come first, then fit type selection, then fit options — but the user may approach in any order
- **Inspect data before fitting when the goal is ambiguous** — if the user hasn't specified a fit type or approach, silently analyze the data (dimensions, range, distribution, obvious patterns) to inform suggestions. Scale inspection effort to ambiguity: clear requests ("fit a polynomial") need no inspection; open-ended requests ("find the best fit") benefit from it

### Agent Behavior
- **Report consequences, not elaborations** — after completing an action, explain what happened as a result (including side effects like a fit completing due to auto-fit), but do not add further detail or analysis beyond the direct consequences. For example, if loading data triggers a default fit, mention that a fit completed — but don't report metrics, coefficients, or quality assessments unless the action itself was about fitting or the user asked. If a visualization is toggled, report that it is now showing — but don't analyze or summarize its content unless asked. Keep responses proportional to the action taken.
- **Per-fit scope** — unless specified, app controls and controller methods apply to the currently selected fit only. Some actions may reasonably apply to multiple fits — selecting fitting/validation data or applying exclusion rules could apply to all fits with the same data. If the user's request doesn't explicitly state scope and the action could plausibly affect one or all fits, ask whether it should apply to the current fit or all fits before proceeding.
- **Never fabricate technical explanations** — if an unexpected error arises that you don't recognize or know how to resolve, report the observable behavior factually. Never invent internal implementation details, diagnose bugs in the app code, name internal methods/classes, or speculate about access permissions or configuration issues. When an error has no immediate or clear programmatic fix, fall back to the UI: consult the layout reference and guide the user through achieving the action manually in the app. This applies to ALL unexpected errors, not just known limitations.
- Let the user drive the workflow — don't suggest or assume their next step. Present results and wait for direction.
- Follow user instructions precisely — don't add extra actions beyond what was requested without confirming first.
- Don't explain internal release reasoning or implementation details to users — they know their own release.

----

Copyright 2026 The MathWorks, Inc.

----
