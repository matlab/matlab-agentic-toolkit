# Interpreting Fit Results

## Table of Contents

- [GOF Struct Overview](#gof-struct-overview)
- [Fit State and Metric Availability](#fit-state-and-metric-availability)
- [Metrics by Fit Category](#metrics-by-fit-category)
- [When Metrics Conflict](#when-metrics-conflict)
- [Presentation Guidance](#presentation-guidance)
- [Caveats](#caveats)
- [Coefficients and Confidence Intervals](#coefficients-and-confidence-intervals)
- [Fit Status Messages](#fit-status-messages)

## GOF Struct Overview

`getGoodnessOfFit()` returns a struct with fields: `sse`, `rsquare`, `dfe`, `adjrsquare`, `rmse`.

`getGoodnessOfValidation()` returns a struct with fields: `sse`, `rmse`. Only available when the user has selected validation data.

### What Each Metric Indicates

- **SSE** — closer to 0 indicates less residual error
- **R²** — closer to 1 indicates more variance explained; inflates with added coefficients
- **DFE** — n minus number of fitted coefficients; used in computing other statistics
- **Adjusted R²** — closer to 1; penalizes model complexity; best for comparing nested models
- **RMSE** — closer to 0 indicates a fit more useful for prediction

---

## Fit State and Metric Availability

Metrics are available when FitState is GOOD or WARNING. They are empty when INCOMPLETE or ERROR. See `references/api-reference.md` for full state definitions.

**Always report FitState using these translated labels to users:**

| Internal Value | Report As | Meaning |
|---|---|---|
| `GOOD` | **Complete** | The fit completed without throwing any warnings |
| `WARNING` | **Warning** | The fit completed but at least one warning was thrown (which may or may not need action depending on the warning and the user's goals) |
| `ERROR` | **Error** | An error was thrown somewhere during the fitting workflow and the fit could not be created |
| `INCOMPLETE` | **Incomplete** | The fit doesn't have enough information to complete, or needs to be run |

Never report FitState as "Good" — users will interpret this as a quality judgment. Metrics are interpreted the same way for Complete and Warning states.

When the state is Warning, the warning message may contain information relevant to interpreting the metrics. Report the warning alongside metrics so the user has full context.

---

## Metrics by Fit Category

Metric interpretation depends on the fit type category:

### Regression (linear and nonlinear models, custom equations)

All metrics are meaningful and comparable within the category. Adjusted R² accounts for differing parameter counts when comparing models of different complexity. Validation metrics indicate generalization to unseen data.

### Smoothing (smoothing spline, lowess/loess)

Metrics are computed but have different characteristics. A smoothing spline can approach R² = 1 because it is optimized for smoothness and closeness to the data points — a fundamentally different fitting approach from regression. RMSE is more informative than R² for comparing smoothing fits to regression fits.

**Agent reasoning (do not relay to users):** Do not recommend a smoothing spline just because it has high R². A high R² alone does not make it the right choice — consider all metrics and the user's goals. When comparing across categories, use metrics other than R² (RMSE, validation metrics, residual patterns) to inform your reasoning.

**If the user asks** why a smoothing spline has higher R² than a regression model: explain that smoothing fits are a different type of fit (optimized for smoothness and proximity to data points rather than fitting a parametric equation), but the metric computation is identical across all fit types.

### Interpolant (linear, nearest, pchip, spline)

SSE = 0 and R² = 1 by definition because interpolants pass exactly through data points.

---

## When Metrics Conflict

When comparing fits where metrics diverge (e.g., one has lower RMSE but another has higher adjusted R², or one has higher R² but lower adjusted R²), present the results objectively. Use factual, directional language ("lower", "higher") and do not declare a winner or recommend one fit over another.

Metrics can be compared across fit type categories, but know the limitations of each. A smoothing spline's R² may appear better than a regression model's R² for data with an unknown underlying model, but this does not mean the smoothing spline is the better choice. It is up to the user to decide what fit type they want to use and what criteria define "best" for their use case.

Present numbers only unless the user asks for further explanation.

---

## Presentation Guidance

### What to Do

- Consider all available metrics before deciding which to present.
- Present a relevant subset based on context — not every metric is equally informative for every question.
- Use factual, directional language: "Fit 2 has lower RMSE (0.12) compared to Fit 1 (0.34)."
- Include validation metrics when validation data is available.
- Note when metrics are uninformative for the fit category (e.g., interpolants).
- Graphical methods (residual plots, prediction bounds) are generally more informative than numeric metrics alone — suggest them when relevant.
- Factual, objective statements about statistical properties and tradeoffs are permitted and encouraged — these are distinct from subjective quality judgments. Statistical caveats, mathematical properties of fit types, and tradeoff dimensions (accuracy vs. simplicity, interpolation vs. extrapolation) help users make informed decisions.

### What NOT to Do

- **Never tell the user which fit is best, even if asked.** Even when all metrics favor one fit, the user may have domain reasons to prefer another. Present the metrics and let the user decide. If the user insists, ask them to define their criteria for "best" (e.g., "the one with the lowest RMSE"). Once they provide objective criteria, restate it and identify the fit that meets it — but the judgment remains theirs.
- Never say a fit is "good" or "bad". This can be based on metrics or visuals or any other criteria.
- Never use "better" or "worse" when comparing metrics — use "higher"/"lower" or "less than"/"greater than".
- Don't over-index on R². A high R² does not mean the fit is appropriate for the user's needs.
- Don't present every metric for every interaction — be selective.
- **Never use these terms** to describe fit quality: "good", "bad", "best", "worst", "better", "worse", "excellent", "poor", "performs well", "appropriate", "inappropriate", "acceptable", "unacceptable". Use directional language instead: "lower", "higher", "closer to 0", "closer to 1".
- **Never expose internal algorithm terminology** to the user: "optimizer", "local minimum", "converging to", "objective function", "cost function", "TolFun algorithm", "solver". Describe results using app-presented concepts only (fit state, coefficients, GOF metrics, status messages).
- **Never assume or state that data matches a model** ("looks Weibull-shaped", "appears exponential"). Ask the user about their data characteristics or goals instead.
- **Never suggest alternative fit types or approaches unprompted.** Follow the user's specific instructions. Only suggest alternatives when the user explicitly asks "what else could I try?" or similar.
- **When the user asks "is this fit good/acceptable?"**, do not answer with a judgment. Ask what criteria define acceptable for their use case (e.g., RMSE threshold, R² target, visual fit) or present the metrics in context and let them decide.

---

## Caveats

### R² Is Not a Reliable Basis for Comparison

Do not use R² as the primary basis for comparing fits, especially across categories. Smoothing splines and interpolants achieve high R² by design (flexibility or exact interpolation), not because they are more appropriate models.

Adjusted R² is the best indicator for comparing nested models (each adds coefficients to the previous). For non-nested models, no single metric resolves the comparison — present all relevant metrics.

### Residual Patterns Beyond Numeric Metrics

Numeric metrics can miss systematic patterns. A fit with low RMSE might still show clear patterns in the residuals (e.g., consistently under-predicting at extremes). When relevant, suggest the user inspect the residuals plot.

If the user asks about residual patterns: random scatter around zero indicates a well-fitting model; systematic patterns (e.g., consistently over- or under-predicting in regions) indicate the model may be inappropriate for the data.

### Prediction Bounds and Coefficient Confidence

Confidence bounds on coefficients and prediction bounds can reveal overfitting that residual plots and GOF statistics miss. Wide coefficient confidence bounds indicate the coefficients are not accurately determined. Wide prediction bounds indicate high uncertainty in predictions.

**Constraint point limitation:** When constraint points are active on a fit, confidence intervals on coefficients produce NaN and prediction bounds cannot be displayed. This is a mathematical property of constrained optimization.

---

## Coefficients and Confidence Intervals

Report coefficient values and confidence intervals when asked. No special interpretation guidance is needed — the agent does not need to explain what coefficients mean unless the user asks about geometrical or physical properties based on the formula.

If a confidence interval crosses zero, it may indicate overfitting or that the corresponding term is not contributing meaningfully to the fit. Present this observation to the user without declaring the fit invalid — interpretation is the user's responsibility.

---

## Fit Status Messages

The app produces info, warning, and error messages during fitting. Present these messages to the user as-is without rephrasing or interpreting them.

Do not take follow-up actions in response to warnings unless the user asks. Warnings are often informative and non-actionable. For example, if fitting data contains NaN or Inf values, they are automatically filtered and a persistent warning appears — the correct response is to note the warning, not to remove NaN/Inf from the workspace variables.

Convergence and stopping-criteria messages (e.g., "Fitting stopped because the change in residuals is less than the specified tolerance" or "Fitting computation exited because the number of iterations exceeded MaxIter") are distinct from warnings and errors. Present them factually. Do not rephrase them as warnings, do not explain the internal algorithm that produced them, and do not take follow-up action unless the user asks.

---

## Start Points and Determinism

### Start Point Behavior by Fit Type

| Fit Type | Start Points | Behavior |
|----------|-------------|----------|
| Polynomial, Logarithmic, Linear Fitting | N/A | Linear models — no start points needed |
| Exponential, Fourier, Gaussian, Power, Sum of Sine, Sigmoidal | Optimized | Calculated heuristically from the data — deterministic for the same data |
| Rational, Weibull, Custom Equation | Random | Randomly selected on [0, 1] — results may differ between runs |

Fits using random start points are non-deterministic — results may differ between runs of the same fit type on the same data. This is expected behavior, not necessarily a problem.

### Setting Explicit Start Points

Setting explicit start points is one option a user may consider if:
- A fit has convergence issues or produces a WARNING state
- A fit converges to a solution that doesn't match the user's expectations
- The user wants reproducible results from a fit type that uses random start points

Do not change start points without asking the user. Present it as an option alongside other approaches (different fit type, bounds, algorithm) and let the user decide.

To set start points via the controller:
```matlab
opts = controller.getFitOptions();
opts.StartPoint = [initialGuess1, initialGuess2, ...];
controller.setFitOptions(opts);
```

---

## Feature Availability by Fit Category

| Feature | Parametric (Regression) | Interpolant | Smoothing Spline | Lowess/Loess |
|---------|------------------------|-------------|------------------|--------------|
| Prediction/confidence bounds | Yes | No | No | No |
| Coefficient values & confidence intervals | Yes | No | No | No |
| Start points and bounds | Nonlinear only | No | No | No |
| Robust fitting | Yes | No | No | Yes |
| Residuals | Yes | Zero by definition | Yes | Yes |
| GOF metrics (SSE, R², RMSE) | Meaningful | SSE=0, R²=1 by definition | Interpret with care | Interpret with care |

----

Copyright 2026 The MathWorks, Inc.

----
