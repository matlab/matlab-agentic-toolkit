# Curve Fitter App Layout (R2022a+)

This describes the modern Curve Fitter app opened via `curveFitter(...)`.

## Table of Contents

- [Version Convention](#version-convention)
- [Overview](#overview)
- [Toolstrip](#toolstrip)
  - [File Section](#file-section)
  - [Data Section](#data-section)
  - [Fit Type Section](#fit-type-section)
  - [Fit Section](#fit-section)
  - [Visualization Section](#visualization-section)
  - [Preferences Section](#preferences-section)
  - [Export Section](#export-section)
- [Fit Options Panel](#fit-options-panel)
  - [Regression Models](#regression-models)
  - [Interpolation](#interpolation)
  - [Smoothing](#smoothing)
  - [Custom](#custom)
  - [Saved Custom Equations](#saved-custom-equations-r2025a)
  - [Advanced Options](#advanced-options-collapsible-section)
- [Results Panel](#results-panel)
- [Table of Fits](#table-of-fits)
- [Fit Figure Area](#fit-figure-area)

---

## When to Use This Reference

Consult this reference when:
- The user asks how to perform an action in the app UI
- The user asks where to find a feature or what a control does
- The controller has no API for a requested action — guide the user through the app UI instead of inventing a workaround
- The user mentions a feature by name and you need to confirm its existence and location

This reference only covers the modern Curve Fitter app (R2022a+). It does not cover cftool (R2021b and earlier). For cftool, most of the same functionality exists but with a different layout — rely on general knowledge for cftool feature locations. Functionality introduced after R2022a (annotated with release tags below) is not available in cftool.

---

## Version Convention

All features described in this document are available in **R2022a and later** unless annotated. Annotations use:
- **Callout blocks** (`>`) for entire new sections or behavioral changes that need explanation
- **Bold inline tags** like **(R2024b+)** for individual new features within existing sections

**Per-fit scope:** Unless otherwise specified, all controls in the Curve Fitter app (toolstrip, Fit Options panel, Fit Figure) apply to the **currently selected fit only**. This includes data selection, validation data, fit type, fit options, exclusions, and visualization settings. To apply changes across multiple fits, select each fit tab individually.

---

## Overview

The app has four main regions:

| Region | Position | Contents |
|--------|----------|----------|
| Toolstrip | Top | Ribbon-style toolbar with sections: File, Data, Fit Type, Fit, Visualization, Preferences, Export |
| Fit Figure | Center | Plot area with tabs (one tab per fit) |
| Fit Options + Results | Right side | Stacked panels showing options and results for the selected fit |
| Table of Fits | Bottom | Spreadsheet-style table listing all fits and their metrics |

Each fit gets its own figure tab. Selecting a fit (via tab click or Table of Fits row click) updates the Fit Options and Results panels to show that fit's configuration and output.

---

## Toolstrip

The toolstrip has a single tab ("Curve Fitter") with the following sections from left to right:

### File Section

| Control | Type | Action |
|---------|------|--------|
| New | Split dropdown | **New Session** — discards current session and starts fresh; **New Fit** — adds a new fit to the current session |
| Open | Button | Opens a saved `.sfit` session file |
| Save | Split button | **Save** (top) — saves to current path; **Save Session As...** — saves to a new file |
| Duplicate | Button | Duplicates the currently selected fit |

**Session management:**
- Sessions are saved as `.sfit` files and preserves the exact state of the app when it was saved
- The title bar shows "Curve Fitter" when no session file is associated. Once saved, it changes to "Curve Fitter - <name>" (without the .sfit extension)
- Use `hasUnsavedChanges` via the controller to check for unsaved modifications
- Opening a session replaces the current session entirely
- If there are unsaved changes and the user closes the app, starts a new session, or loads a session, a confirmation dialog appears asking "Would you like to save your current session?" with buttons: Save, Don't Save, Cancel

### Data Section

| Control | Type | Action |
|---------|------|--------|
| Select Data | Button | Opens the "Select Fitting Data" dialog |
| Exclusion Rules | Button | Opens the "Exclusion Rules" dialog |
| Validation Data | Button | Opens the "Select Validation Data" dialog |

**Select Fitting Data dialog:** Contains an editable Fit name text field, and dropdowns for X data, Y data, Z data (surface only), and Weights. Each dropdown lists numeric vectors and table variables from the workspace. When a table variable is selected, a second dropdown appears to choose the column name. Info, warning, or error messages related to the selected data (e.g., size requirements, NaN/Inf values, dimension mismatches) appear at the bottom of the dialog and in the Results panel. Buttons: Help, Close.

**Select Validation Data dialog:** Shows the Fit name (read-only label), and dropdowns for X data, Y data, and Z data (surface only). Same workspace variable/table-column selection as fitting data. No Weights field. Buttons: Help, Close.

**Exclusion Rules dialog:** Shows the Fit name (read-only label). For each dimension (X, Y, Z for surfaces), provides two exclusion conditions side by side — each with an operator dropdown (`<`, `<=`, `>`, `>=`) and a value text field. This allows excluding data outside a range per dimension. Duplicate rules are prevented by the UI design. Buttons: Help, Close.

### Fit Type Section

| Control | Type | Action |
|---------|------|--------|
| Fit Type Gallery | Gallery with popup | Shows up to 4 fit types inline (fewer if the window is narrow); clicking the dropdown arrow opens the full gallery popup |

**Gallery popup structure:**

The popup has a search bar, list/grid view toggle, and category filter dropdown ("REGRESSION MODELS"). Categories can be reorganized with the up/down arrows:

| Category | Fit Types |
|----------|-----------|
| REGRESSION MODELS | Polynomial, Exponential, Logarithmic, Fourier, Gaussian, Power, Rational, Sum of Sine, Weibull, Sigmoidal |
| INTERPOLATION | Interpolant |
| SMOOTHING | Smoothing Spline, Lowess |
| CUSTOM | Custom Equation, Linear Fitting |

Fit types that don't apply to the current data dimension are grayed out (e.g., Lowess is surface-only; Smoothing Spline is curve-only). Surface fit types show 3D plot icons instead of 2D and the icon for fit types that support both curves and surfaces will toggle depending on what data is selected.

### Fit Section

| Control | Type | Action |
|---------|------|--------|
| Update Fit | Radio group | **Auto** — fit updates automatically when data or options change; **Manual** — requires clicking "Fit" |
| Fit / Stop | Button | Executes the fit; grayed out when Auto is selected. While fitting is in progress, changes to a **Stop** button that can be clicked to cancel the fit |

**Manual mode behavior:** When Manual is selected and any change is made (data, options, etc.), the fit state becomes INCOMPLETE and the Results panel displays a message instructing the user to click the Fit button. The Fit button icon changes depending on whether Auto or Manual is selected. Manual mode is recommended when making many small changes to avoid re-fitting after every individual change.

### Visualization Section

| Control | Type | Action |
|---------|------|--------|
| Fit Plot | Toggle button | Toggles the main fit plot; can be turned off if at least one other plot (Residuals or Contour) is visible |
| Residuals Plot | Toggle button | Toggles residuals stem plot |
| Contour Plot | Toggle button | Toggles 2D contour plot (surface fits only; disabled for curves) |
| Prediction Bounds | Dropdown | Options: **None**, **90%**, **95%**, **99%**, **Custom** (Custom opens a dialog to enter a confidence level percentage). Disabled when constraint points are active on the current fit; re-enabled when all constraint points are removed. |

At least one plot must be visible at all times — the toggle button for the last remaining visible plot is disabled. To switch from one plot to another (e.g., showing only Residuals instead of only Fit Plot), first enable the desired plot, then disable the one to remove.

**Set Prediction Bounds dialog (Custom):** Contains a Fit name (read-only label) and a Confidence level (%) editable numeric field (default: 95). Buttons: Help, OK, Cancel. If the entered value matches a predefined option (90%, 95%, or 99%), the dropdown switches to that option after OK. Otherwise (e.g., 92%), the dropdown stays on "Custom". The user can select Custom again to change the value, pick a predefined level, or select None to turn off prediction bounds.

> **R2023b+:** The Custom dialog was updated to show the fit name and include a Help button. In R2022a–R2023a, the dialog had only the confidence level field with OK/Cancel.

### Preferences Section

> **R2024b+:** This entire section is not present in earlier releases.

| Control | Type | Action |
|---------|------|--------|
| Colormap | Button | Opens the "Curve Fitting Toolbox Colormap Preferences" dialog |

**Colormap Preferences dialog:** Contains a colormap dropdown (default: "Default"), a Reset button, and a colormap preview bar. The default colormap is "sky" (light theme) or "abyss" (dark theme). Changing the selection affects surface plots both in the app and at the command line (e.g., `sfit/plot`). The setting persists across sessions.

### Export Section

| Control | Type | Action |
|---------|------|--------|
| Export | Dropdown button | Opens a dropdown menu |

**Export dropdown contents:**

- **Export to Figure** — exports a copy of the currently displayed fit's plot(s) to a standalone MATLAB figure window
- **Generate Code** — generates MATLAB code reproducing the fit
- **Export to Workspace** — opens the "Save Fit to MATLAB Workspace" dialog to export the fit object, goodness-of-fit struct, and/or output struct to workspace variables
- **Export to Simulink** **(R2022b+)** (requires Simulink) — submenu with two options:
  - **Create Lookup Table Block** — opens the "Create Lookup Table Block" dialog to create a Simulink lookup table block by specifying breakpoints for the fit
  - **Create Optimized Lookup Table** **(R2024a+)** — opens the Lookup Table Optimizer wizard (requires Fixed-Point Designer)

**Save Fit to MATLAB Workspace dialog:** Contains three checkboxes with editable variable name fields:

| Checkbox | Default Name | Description |
|----------|--------------|-------------|
| Save fit to MATLAB object named | `fittedmodel` | Exports the `cfit`/`sfit` fit object |
| Save goodness of fit to MATLAB struct named | `goodness` | Exports the goodness-of-fit struct |
| Save fit output to MATLAB struct named | `output` | Exports the fit output struct |

Buttons: OK, Cancel.

**Create Lookup Table Block dialog:** Creates a Simulink lookup table block by specifying breakpoints.
- **Fit name** — read-only, shows the source fit
- **Breakpoints specification** — dropdown: "Even spacing" or "Explicit values"
- *Even spacing mode:* Breakpoints 1 (X data): First point, Spacing, Number of points (spinner). For surface fits: Breakpoints 2 (Y data) with the same fields.
- *Explicit values mode:* Breakpoints 1 (X data): text field accepting MATLAB colon notation (e.g., `1800:20:2000`) or an explicit vector (e.g., `[1800 1850 1900 2000]`). For surface fits: Breakpoints 2 (Y data) with same format.
- **Lookup table preview** **(R2023a+)**: scrollable table of the evaluated fit values at the specified breakpoints. For surface fits, a dropdown selects which Breakpoints 2 slice to display, and the table shows a 2D grid (rows = BP1, columns = BP2). In R2022b, breakpoints are specified without a preview.
- Buttons: Help, Export Table to Simulink, Cancel.

**Lookup Table Optimizer wizard:** Requires Fixed-Point Designer. A multi-step wizard with tabs: Objective, Setup, Create, Results. The first page (Setup) includes Curve or Surface Fit Object name, Output Data Type, and a table of Input/Data Type/Minimum/Maximum. Upon completion, a Simulink model opens showing the optimized lookup table block. Creates a memory-efficient lookup table optimized for embedded targets.

---

## Fit Options Panel

Located in the upper-right side panel. Shows options specific to the selected fit type. Has a kebab menu (three dots) with Maximize and Collapse Panel.

### Regression Models

#### Polynomial
- Degree dropdown (1-9); for surfaces: X Degree (1-5) + Y Degree (1-5)
- Robust dropdown: Off, LAR, Bisquare
- Center and scale checkbox
- Advanced Options (linear)

#### Exponential
- Equation display (read-only)
- Number of terms dropdown
- Center and scale checkbox
- Advanced Options (nonlinear)

#### Logarithmic

> **R2023b+:** This fit type is not available in earlier releases.

- Equation display
- Logarithm Base dropdown: e (natural), 10, 2
- Robust dropdown: Off, LAR, Bisquare
- Advanced Options (linear)

#### Fourier
- Equation display (read-only)
- Number of terms dropdown
- Center and scale checkbox
- Advanced Options (nonlinear)

#### Gaussian
- Equation display (read-only)
- Number of terms dropdown
- Center and scale checkbox
- Advanced Options (nonlinear)

#### Power
- Equation display
- Number of terms dropdown (1, 2)
- Advanced Options (nonlinear)

#### Rational
- Numerator degree dropdown (0-5)
- Denominator degree dropdown (1-5)
- Center and scale checkbox
- Advanced Options (nonlinear)

#### Sum of Sine
- Equation display (read-only)
- Number of terms dropdown
- Center and scale checkbox
- Advanced Options (nonlinear)

#### Weibull
- Equation display (static)
- Advanced Options (nonlinear)

#### Sigmoidal

> **R2023b+:** This fit type is not available in earlier releases.

- Model dropdown: Logistic, 4-Parameter Logistic, Gompertz
- Equation display
- Center and scale checkbox (disabled for 4-Parameter Logistic)
- Advanced Options (nonlinear)

### Interpolation

#### Interpolant
- Interpolation method dropdown: Nearest, Linear, Shape-Preserving (PCHIP), Cubic; for surfaces: Nearest, Linear, Natural **(R2024a+)**, Cubic, Biharmonic (v4), Thin-plate
- Extrapolation method dropdown (options change based on interpolation method; for surface Biharmonic/Thin-plate: automatic, not selectable). Additional extrapolation options for some methods **(R2023b+)**.
  > **R2023a+:** The extrapolation method dropdown was added. In R2022a–R2022b, interpolants use their built-in extrapolation behavior with no user control.
- Center and scale checkbox (default ON)
- No Advanced Options

### Smoothing

#### Smoothing Spline (curves only)
- Smoothing Parameter: Default (radio) / Specify (radio) + value field
- Smoother / Rougher buttons (adjust on logarithmic scale)
- Center and scale checkbox
- No Advanced Options

#### Lowess (surfaces only)
- Polynomial dropdown: Linear, Quadratic
- Span (%) edit field (1-100)
- Robust dropdown: Off, LAR, Bisquare
- Center and scale checkbox (default ON)
- No Advanced Options

### Custom

#### Custom Equation
- Saved options controls **(R2025a+)**: "Select to apply" dropdown, Save button (disk icon), Manage button (see [Saved Custom Equations](#saved-custom-equations) below)
- Independent/Dependent variable fields
- Equation text area (multiline)
- Shortcuts dropdown
- Advanced Options (nonlinear)

#### Linear Fitting
- Saved options controls **(R2025a+)**: "Select to apply" dropdown, Save button (disk icon), Manage button (see [Saved Custom Equations](#saved-custom-equations) below)
- Independent/Dependent variable fields
- Coefficients/Terms table with editable coefficient names and term expressions, Add/Delete buttons
- Shortcuts dropdown
- Advanced Options (linear)

#### Saved Custom Equations (R2025a+)

All three custom fit type panels (Custom Equation for curves, Custom Equation for surfaces, Linear Fitting) share the same save/apply/manage workflow for reusing equations and fit options.

**"Select to apply" dropdown:** Lists previously saved equations for this panel type. This is an action dropdown — clicking an entry immediately applies the saved equation and options to the current fit, then resets back to "Select to apply". Modifying options after applying does not affect the saved entry.

**Save Equation and Fit Options dialog** (opened via the save button):
- Name — editable text field for naming the saved equation
- Equation — read-only display of the current equation
- Advanced Fit Options — collapsible section (collapsed by default) showing the current fit options and Coefficient Constraints table as configured in the fit options panel at the time of saving
- Buttons: Save, Cancel

**Manage Saved Equations and Options dialog** (opened via the manage button):
- Three tabs: Custom Equation (Curve), Custom Equation (Surface), Linear Fitting
- Each tab shows a table of saved equations with columns: checkbox, Name, Equation, Independent Variable(s), Dependent Variable
- Remove button (top-right, enabled when one or more rows are checked) — deletes selected entries
- Buttons: Close
- New equations cannot be added from this dialog — save from the fit options panel instead

### Advanced Options (collapsible section)

Present on regression and custom fit types. Two variants:

**Linear regression (Polynomial, Logarithmic, Custom Linear):**
- Method: LinearLeastSquares (read-only)
- TolCon (editable; has no effect without constraint points, which require Optimization Toolbox) **(R2025a+)**
- Coefficients table: Coefficient Name (read-only), Lower Bound, Upper Bound
- Constraint Points to Fit Through: table with Add/Delete buttons (2D for curves, 3D for surfaces) **(R2025a+)**

**Nonlinear regression (Exponential, Fourier, Gaussian, Power, Rational, Sum of Sine, Weibull, Sigmoidal, Custom Equation):**
- Method: NonlinearLeastSquares (read-only)
- Robust dropdown: Off, LAR, Bisquare
- Algorithm dropdown: Trust-Region, Levenberg-Marquardt, Interior-Point **(R2025a+, requires Optimization Toolbox)** (disabled when constraint points are set)
- DiffMinChange, DiffMaxChange (editable)
- MaxFunEvals, MaxIter (editable)
- TolFun, TolX, TolCon (editable; TolCon has no effect without constraint points, which require Optimization Toolbox) — TolCon **(R2025a+)**
- Coefficients table: Coefficient Name (read-only), Start Point, Lower Bound, Upper Bound
- Constraint Points to Fit Through: table with Add/Delete buttons (2D for curves, 3D for surfaces) **(R2025a+)**

Coefficient names in the Advanced Options table are always read-only — determined by the fit type. For Custom Equation, coefficients are automatically extracted from the equation text. For Custom Linear, coefficient names and term expressions are editable in the main panel's table above.

"Read about fit options" hyperlink at the bottom (opens Help browser).

---

## Results Panel

> **R2023a+:** The Results panel was redesigned and the copy button was added. In R2022a–R2022b, results were displayed in a large text area (selectable for manual copying, but not messages) with most of the same information, and messages appeared above it rather than inline.

Located in the lower-right side panel, below Fit Options. Contains a **copy button** that copies the results text to the clipboard.

### Contents (when a fit is computed)

1. **Fit Name** — displayed name of the selected fit
2. **Fit description** — e.g., "Polynomial Curve Fit (poly1)" or "Exponential Curve Fit (exp1)" or "Interpolating Surface Fit (linearinterp)"
3. **Formula** — e.g., `f(x) = p1*x + p2` or `f(x,y) = piecewise linear surface with no extrapolation`
4. **Normalization info** (if Center and scale is enabled) — shows mean and std for each variable
5. **Coefficients and 95% Confidence Bounds** — table with columns: Value, Lower, Upper; rows for each coefficient
6. **Goodness of Fit** — table with columns: Value; rows: SSE, R-square, DFE, Adj R-sq, RMSE
7. **Goodness of Validation** — same metrics computed against validation data (shown only when validation data is assigned)

When no fit is computed (e.g., no data assigned), only the Fit Name is shown.

The Results panel may also display info, warning, or error messages (e.g., data issues, instructions to click Fit in manual mode, fit convergence warnings).

---

## Table of Fits

Located at the bottom of the app. Shows one row per fit in the session.

### Columns

- **Fit State** — icon indicator (see below)
- **Fit Name** — display name of the fit (editable by double-clicking the cell)
- **Data** — e.g., "y vs. x" or "z vs. x, y"
- **Fit Type** — e.g., "poly1", "exp1", "linearinterp", or custom equation text
- **R-square**
- **SSE**
- **DFE**
- **Adj R-sq**
- **RMSE**
- **Num Coefficients**
- **Validation Data** — validation data description (if assigned)
- **Validation SSE**
- **Validation RMSE**

**Fit State icons:**
- Green checkmark — fit completed without any warnings or errors
- Yellow warning — fit completed, but at least one warning was thrown (may or may not require attention)
- Red error — an error was thrown somewhere in the workflow
- No icon — missing fitting data, or fit needs to be executed (manual mode)

### Interactions

- **Click a row** — selects that fit and switches the figure tab, Fit Options, and Results to show it
- **Right-click a row** — context menu with:
  - Duplicate "[fit name]"
  - Delete "[fit name]"
  - Save "[fit name]" to Workspace...

---

## Fit Figure Area

The center of the app shows the fit figures in a tabbed layout. Each fit has its own figure. The currently displayed/selected fit is the one that toolstrip controls, Fit Options, and Results apply to. All plots (Fit Plot, Residuals Plot, Contour Plot) are toggled via the Visualization section in the toolstrip.

### Tabs

- Each figure tab shows the fit name with a close (x) button
- Tab bar supports the **actions menu** (three dots button, left of tabs) with:
  - Maximize (Ctrl+Shift+M)
  - Close All Except [fit name]
  - Close All to the Right
  - Close All
  - Close Fits
  - Tile All
  - Sub-Tile Fits
  - Tab Position (submenu: Top, Left, Bottom, Right — controls where tabs are rendered)
- "Close All Except", "Close All to the Right", "Close All", "Close Fits", "Tile All", and "Sub-Tile Fits" only appear when more than one fit is present
- **Tile All** / **Sub-Tile Fits** arrange figures side-by-side for visual comparison
- Figures can also be tiled by clicking and dragging a tab to dock it beside another
- Closing a tab does not delete the fit — it remains in the Table of Fits. Reselect it in the Table of Fits to reopen the figure. If all figure tabs are closed, toolstrip controls and side panels will be empty/disabled until a fit is reselected.

### Fit Plot

- **Curve fits**: 2D scatter plot of data points with the fitted curve overlaid. Legend shows fitting data, validation data (if assigned), excluded points, and the fitted curve.
- **Surface fits**: 3D surface mesh plot with data points shown as markers. Legend shows fitting data, validation data (if assigned), and excluded points (not the surface mesh).

### Residuals Plot

- **Curve fits**: 2D stem plot of residuals (vertical lines from zero line to each residual value)
- **Surface fits**: 3D stem plot of residuals (vertical lines from a plane at z = 0 to each residual value)

### Contour Plot (surface fits only)

- Shows 2D contour map of the fitted surface
- Data points shown as markers on the contour

### Multi-Plot Layout

- **One plot visible**: fills the entire figure area
- **Two plots visible**: stacked vertically (top/bottom)
- **Three plots visible** (surface fits only): contour plot on the left half; fit plot and residuals plot stacked vertically on the right half

### Axes Toolbar

Hovering over a plot reveals a toolbar with custom actions (left to right):

| Tool | Action |
|------|--------|
| Legend | Show/hide the plot legend |
| Grid | Show/hide grid lines |
| Exclude outliers | Click individual points or drag a bounding box to toggle exclusion of data points |
| Data cursor | Click points to show coordinate values |
| Pan | Click and drag to pan the view |
| Zoom in | Click and drag to zoom in |
| Zoom | Click to zoom out |
| Restore view | Restore the original axis limits |

The "Exclude outliers" tool is the primary interactive method for manually excluding outliers and can also be referred to as manual/interactive exclusions.

----

Copyright 2026 The MathWorks, Inc.

----
