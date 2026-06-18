---
name: matlab-create-live-script
description: Create plain-text MATLAB Live Scripts (.m files) with rich text formatting, LaTeX equations, section breaks, and inline figures. Use when generating tutorials, analysis notebooks, reports, documentation, or educational content. Requires R2025a+.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "2.1"
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

## Converting from `.mlx`

Binary `.mlx` files can be converted to plain-text `.m` by running the following at the MATLAB command window. The recipe is **not** part of the resulting `.m` file:

```matlab
editor = matlab.desktop.editor.openDocument(mlxPath, Visible=0);
editor.saveAs(newMPath);  % use .m extension
editor.closeNoPrompt;
```

## Rules

- Text lines use `%[text]` — NOT bare `%`
- One paragraph = one `%[text]` line — do not hard-wrap; let the Live Editor handle line width
- No empty `%[text]` lines — they render as unwanted blank space
- Section headers: `%%` on its own line, then `%[text] ## Title` on next line
- No blank lines in the file, except a single blank line directly before `%[appendix]`
- No `figure` command — implicit figure creation only
- No more than one plot per section (unless using tiled layouts)
- No `close all` or `clear`
- No `mfilename` — does not work as intended in Live Scripts. Hardcode filenames or use `pwd`.
- Escape these characters when used as **literal text** (not as markdown syntax): `*`, `_`, `[`, `]`, `` ` ``, `\`, including within LaTeX equations. Also escape `.` after a digit and `#` at line start.
- Double LaTeX command backslashes: `\\sin`, `\\frac`, `\\sum`
- Last list item (bulleted or numbered) ends with `\`
- Every file ends with the required appendix
- Avoid `fprintf` — drop the semicolon or use `disp()` for output. There is no way to send output to the command window when running as a Live Script.
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
| `%%` | Section break |
| `%[text] # Title` | H1 heading |
| `%[text] ## Section` | H2 heading |
| `%[text] **bold**` | **Bold** |
| `%[text] *italic*` | *Italic* |
| `` %[text] `code` `` | `Monospace` |
| `%[text] <u>text</u>` | Underlined text |
| `%[text] $ a = \\pi r^2 $` | Inline equation |
| `%[text]{"align":"center"} ...` | Center-aligned line |
| `%[text] - item` | Bullet |
| `%[text] - last \` | Last bullet |
| `%[text] 1. item` | Numbered list |
| `%[text] 2. last \` | Last numbered item |
| `%[text] [text](url)` | External hyperlink |
| `%[text] [text](internal:id)` | Internal link to an anchor |
| `%[text] %[text:anchor:id] ...` | Anchor (link target) |
| `%[text:tableOfContents]{"heading":"..."}` | Table of Contents |

**IDs (anchors, and any other id-bearing element):** letters, digits, and underscores only. No hyphens — `my-section` won't bind; use `my_section`. For anchors, place the marker immediately after `%[text]` at the start of the line.

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
%[text:tableOfContents]{"heading":"Contents"}
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
%[text] $ X(k) = \\sum\_{n=0}^{N-1} x(n)e^{-j2\\pi kn/N} $
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
- [ ] Sections use `%%` alone on its own line, followed by `%[text] ##`
- [ ] No blank lines or empty `%[text]` lines (except one blank line directly before `%[appendix]`)
- [ ] Each paragraph is a single `%[text]` line (no hard-wrapping)
- [ ] One plot per section (unless tiled layout)
- [ ] Bulleted and numbered lists end with backslash on last item
- [ ] LaTeX command backslashes are doubled in the saved file: `\\sin`, `\\frac`, `\\pi`
- [ ] No `figure` commands
- [ ] No `close all` or `clear` at start
- [ ] No `mfilename`
- [ ] Appendix is present and correctly formatted
- [ ] Outputs serve the reader, not the developer

## Not Yet Supported

Minor features planned for a future revision:

- Interactive controls (sliders, dropdowns, numeric inputs)
- Hide Code View (output view that hides the source code)

----

Copyright 2026 The MathWorks, Inc.

----

