---
name: matlab-create-live-script
description: Create plain-text MATLAB Live Scripts (.m files) with rich text formatting, LaTeX equations, section breaks, and inline figures. Use when generating tutorials, analysis notebooks, reports, documentation, or educational content. Requires R2025a+.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Live Scripts

Plain-text `.m` files that render as rich documents in the MATLAB Live Editor. Version-control friendly — never use binary `.mlx`.

## When to Use

- Tutorials, reports, analysis notebooks, or documentation
- Interactive exploration with inline figures and equations
- Version-controlled content (plain-text `.m`, not binary `.mlx`)

## When NOT to Use

- Regular scripts without rich formatting
- Function files
- MATLAB older than R2025a

## Rules

- Text lines use `%[text]` — NOT bare `%`
- One paragraph = one `%[text]` line — do not hard-wrap; let the Live Editor handle line width
- No empty `%[text]` lines — they render as unwanted blank space
- Section headers: `%%` on its own line, then `%[text] ## Title` on next line
- No blank lines anywhere in the file
- No `figure` command — implicit figure creation only
- No more than one plot per section (unless using tiled layouts)
- No `close all` or `clear`
- Double all LaTeX backslashes: `\\sin`, `\\frac`, `\\sum`
- Last bulleted list item ends with `\`
- Every file ends with the required appendix
- Avoid `fprintf` — drop the semicolon or use `disp()` for output
- Outputs should serve the reader's understanding, not verify execution — run the script via MCP to confirm correctness

## Required Appendix

Every Live Script must end with:

```matlab
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
```

## Reading Live Scripts (Token Optimization)

When reading a Live Script file, ignore everything below the `%[appendix]` marker. The appendix contains embedded images and metadata that consume tokens without adding useful information. All code and text content appears before it.

## Format Reference

| Syntax | Renders as |
|--------|-----------|
| `%[text] # Title` | H1 heading |
| `%[text] ## Section` | H2 heading |
| `%[text] **bold**` | **Bold** |
| `%[text] _italic_` | _Italic_ |
| `%[text] |code|` | `Monospace` |
| `%[text] $ x^2 $` | Inline equation |
| `%[text] - item` | Bullet |
| `%[text] - last \` | Last bullet |
| `%%` | Section break |

### Tables

```matlab
%[text:table]
%[text] | Method | Result |
%[text] | --- | --- |
%[text] | Trapezoidal | 1.9998 |
%[text:table]
```

## Example

```matlab
%[text] # Sinusoidal Signals
%[text] Examples of sinusoidal signals in MATLAB.
%[text] - sine waves
%[text] - cosine waves \
x = linspace(0,8*pi);
%%
%[text] ## Sine Wave
plot(x,sin(x))
title('Sine Wave')
xlabel('x (radians)')
ylabel('sin(x)')
grid on
%%
%[text] ## Cosine Wave
plot(x,cos(x))
title('Cosine Wave')
xlabel('x (radians)')
ylabel('cos(x)')
grid on
%%
%[text] ## Summary
%[text] The sine and cosine functions are $ \\pi/2 $ radians out of phase.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
```

## Common Patterns

### Mathematical Explanations with Equations

```matlab
%[text] ## Theory
%[text] The discrete Fourier transform is defined as:
%[text] $ X(k) = \\sum_{n=0}^{N-1} x(n)e^{-j2\\pi kn/N} $
```

### Code with Inline Comments

```matlab
%%
%[text] ## Data Processing
%[text] Load and filter the data, then visualize the results.
data = load('measurements.mat');
filtered = lowpass(data, 0.5);  % Apply lowpass filter
plot(filtered)
title('Filtered Data')
```

### Tiled Layouts for Comparison

Use only when side-by-side comparison is important to the illustration:

```matlab
%%
%[text] ## Comparison of Methods
tiledlayout(1,2)
nexttile
plot(method1)
title('Method 1')
nexttile
plot(method2)
title('Method 2')
```

## Workflow

1. **Plan** — Title, setup, analysis sections, summary
2. **Write** — `%[text]` for text, `%%` for sections, appendix at end
3. **Verify** — Run via MCP to confirm code executes

## Checklist

Before finishing a Live Script, verify:
- [ ] File has .m extension
- [ ] Sections use `%%` followed by `%[text] ##`
- [ ] No blank lines or empty `%[text]` lines
- [ ] Each paragraph is a single `%[text]` line (no hard-wrapping)
- [ ] One plot per section (unless tiled layout)
- [ ] Bulleted lists end with backslash on last item
- [ ] LaTeX uses double backslashes
- [ ] No `figure` commands
- [ ] No `close all` or `clear` at start
- [ ] Appendix is present and correctly formatted
- [ ] Outputs serve the reader, not the developer

----

Copyright 2026 The MathWorks, Inc.

----

