---
name: creating-live-scripts
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
- Section headers: `%%` on its own line, then `%[text] ## Title` on next line
- No blank lines anywhere in the file
- No `figure` command — implicit figure creation only
- No `close all` or `clear`
- Double all LaTeX backslashes: `\\sin`, `\\frac`, `\\sum`
- Last bulleted list item ends with `\`
- Every file ends with the required appendix
- Avoid `fprintf` — drop the semicolon or use `disp()` for output

## Required Appendix

Every Live Script must end with:

```matlab
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
```

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

## Pattern

```matlab
%[text] # Signal Quality Analysis
%[text] _Automated report from measurement data_
%%
%[text] ## Setup
fs = 1000;
t = (0:1/fs:1-1/fs)';
signal = sin(2*pi*50*t) + 0.3*randn(size(t));
numel(signal)
%%
%[text] ## Time Domain
plot(t, signal)
xlabel('Time (s)')
ylabel('Amplitude')
title('Raw Signal')
grid on
%%
%[text] ## Frequency Content
%[text] Dominant frequency should appear at $ f_0 = 50 $ Hz.
nfft = 256;
[pxx, f] = pwelch(signal, hann(nfft), nfft/2, nfft, fs);
plot(f, 10*log10(pxx))
xlabel('Frequency (Hz)')
ylabel('Power/Frequency (dB/Hz)')
title('Power Spectral Density')
grid on
[~, idx] = max(pxx);
f(idx)
%%
%[text] ## Summary
%[text] - **Signal:** 1 s at 1000 Hz
%[text] - **Dominant frequency:** from PSD peak \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
```

## Workflow

1. **Plan** — Title, setup, analysis sections, summary
2. **Write** — `%[text]` for text, `%%` for sections, appendix at end
3. **Verify** — Run via MCP to confirm code executes
