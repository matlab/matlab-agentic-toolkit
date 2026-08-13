# UIHTML Styling

Apply professional styling and theming to web frontends used in MATLAB uihtml apps. Covers CSS layout, color, typography, spacing, responsive design, branding, and visual feedback.

## Critical Rules

- MUST use CSS custom properties (variables) for all theme values — never hardcode colors/fonts inline
- MUST use CSS Grid or Flexbox for layout — never use absolute positioning for app structure
- MUST provide visual feedback for all interactive elements (hover, active, disabled states)
- MUST include `box-sizing: border-box` globally
- MUST use `margin: 0` on `<body>` for uihtml apps — the uifigure controls outer spacing
- NEVER use fixed pixel widths for the main layout — the uihtml component may resize
- NEVER link to CDN resources for fonts — uihtml cannot access external URLs; use local font files
- Use semantic tokens (`--color-text-primary`, `--bg-primary`, etc.) in component styles — never reference raw palette values directly in UI code

## Foundation: CSS Reset

Every uihtml HTML file should start with this minimal reset:

```css
*, *::before, *::after {
    box-sizing: border-box;
}

body {
    margin: 0;
    padding: 0;
    font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
    line-height: 1.5;
    color: var(--text-primary);
    background: var(--bg-primary);
}
```

The `margin: 0` is critical for uihtml — the uifigure grid layout already controls spacing around the component.

## Design Tokens

Define all visual values as CSS custom properties on `:root`. This enables theming, consistency, and easy updates.

```css
:root {
    /* Colors */
    --bg-primary: #ffffff;
    --bg-secondary: #f5f5f5;
    --bg-elevated: #ffffff;
    --text-primary: #1a1a1a;
    --text-secondary: #666666;
    --accent: #0072BD;           /* MATLAB default blue */
    --accent-hover: #005a9e;
    --accent-light: rgba(0, 114, 189, 0.1);
    --error: #d32f2f;
    --success: #2e7d32;
    --border: #e0e0e0;

    /* Typography */
    --font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
    --font-mono: 'SF Mono', 'Consolas', 'Monaco', monospace;
    --font-size-sm: 0.8125rem;   /* 13px */
    --font-size-base: 0.875rem;  /* 14px */
    --font-size-lg: 1rem;        /* 16px */
    --font-size-xl: 1.25rem;     /* 20px */

    /* Spacing */
    --space-xs: 4px;
    --space-sm: 8px;
    --space-md: 16px;
    --space-lg: 24px;
    --space-xl: 32px;

    /* Shape */
    --radius-sm: 4px;
    --radius-md: 8px;
    --radius-lg: 12px;
    --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.1);
    --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.1);
    --shadow-lg: 0 10px 30px rgba(0, 0, 0, 0.15);

    /* Transitions */
    --transition-fast: 150ms ease;
    --transition-normal: 250ms ease;
}
```

## Dark Mode

Override token values using a class toggle on `body`. Do not use `:root.dark` — class changes on `<html>` do not trigger CSS repaints in MATLAB's embedded webview.

```css
body.dark {
    --bg-primary: #1a1a1a;
    --bg-secondary: #2a2a2a;
    --bg-elevated: #333333;
    --text-primary: #e0e0e0;
    --text-secondary: #999999;
    --accent: #4dabf7;
    --accent-hover: #74c0fc;
    --accent-light: rgba(77, 171, 247, 0.15);
    --border: #444444;
}
```

Toggle from JavaScript:

```javascript
document.body.classList.toggle('dark');
```

See `dark-mode.md` for complete dark mode token sets (generic and branded themes) and media query alternatives.

## Layout Patterns

### Full-Page App Layout (CSS Grid)

The standard layout for a uihtml app that fills its container:

```css
.app-layout {
    display: grid;
    grid-template-rows: auto 1fr auto;  /* header, main, footer */
    height: 100vh;
    width: 100%;
}

.app-header {
    padding: var(--space-md);
    background: var(--bg-elevated);
    border-bottom: 1px solid var(--border);
}

.app-main {
    padding: var(--space-md);
    overflow-y: auto;
}

.app-footer {
    padding: var(--space-sm) var(--space-md);
    background: var(--bg-secondary);
    border-top: 1px solid var(--border);
    font-size: var(--font-size-sm);
    color: var(--text-secondary);
}
```

### Additional Patterns

| Pattern | Use case |
|---------|----------|
| Full-page | Standard uihtml app filling container |
| Sidebar + content | Explorer-style control panel |
| Control panel (Flexbox) | Groups of sliders/dropdowns |
| Card grid | Dashboard panels |

See `css-layout-patterns.md` for complete CSS for all patterns.

## Professional Branding

For professionally branded UIs, use a two-layer token architecture:

1. **Raw palette** (`--c-*`) — named colors at specific shades (defined in the asset file)
2. **Semantic tokens** (`--color-*`, `--bg-*`, `--border-*`) — colors assigned to UI roles (used in component styles)

Copy `assets/colors_and_type.css` into your project and link it first:

```html
<link rel="stylesheet" href="colors_and_type.css">
```

**Typography:** Source Sans 3 (`--font-sans`) for UI text, Source Code Pro (`--font-mono`) for code. For uihtml: download font files locally since CDN access is blocked.

**Graphics/chart colors:** `--c-graphics-1` through `--c-graphics-7` match MATLAB's default `colororder`, ensuring web charts stay consistent with MATLAB figures.

For cross-path token alignment with MATLAB's theme struct, see `matlab-apply-theme`.

## Responsive Design

The uihtml component resizes with its parent uifigure or grid layout cell. Use relative units and media queries to adapt:

```css
/* Respond to narrow widths (small uihtml panel) */
@media (max-width: 500px) {
    .control-panel {
        flex-direction: column;
    }

    .sidebar-layout {
        grid-template-columns: 1fr;
    }
}

/* Use relative units instead of fixed pixels */
.container {
    padding: clamp(8px, 2vw, 24px);
    font-size: clamp(12px, 1.5vw, 16px);
}
```

## Implementation Checklist

- [ ] CSS custom properties defined for all theme values (colors, spacing, typography)
- [ ] `box-sizing: border-box` applied globally
- [ ] `body { margin: 0 }` set for uihtml apps
- [ ] Layout uses CSS Grid or Flexbox (no absolute positioning for structure)
- [ ] All interactive elements have hover, active, and disabled states
- [ ] Loading indicator implemented for MATLAB computation waits
- [ ] Error/success status messages styled
- [ ] Responsive behavior tested at different uihtml component sizes
- [ ] Consistent with MATLAB color palette where appropriate
- [ ] Dark mode supported via CSS custom property overrides (if required)
- [ ] For branded UIs: `colors_and_type.css` linked first, semantic tokens used throughout
- [ ] Text on light backgrounds uses palette values 600+ (AA contrast)
- [ ] Text on dark backgrounds uses palette values 500 or lighter (AA contrast)
- [ ] No emoji in product UI copy

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Content overflows uihtml bounds | Fixed pixel dimensions | Use `100%`, `100vh`, or relative units |
| Gap between uihtml and figure edge | Body margin | Set `body { margin: 0 }` |
| Fonts look different across platforms | No font stack | Use `system-ui, -apple-system, 'Segoe UI', sans-serif` |
| Colors inconsistent across components | Hardcoded hex values | Use CSS custom properties everywhere |
| Hover effects missing on touch | CSS `:hover` only | Add `:active` states as fallback |
| Layout breaks when panel resizes | Fixed widths | Use `flex: 1`, `minmax()`, or `clamp()` |
| Fonts not loading in uihtml | CDN blocked | Download font files locally, use `@font-face` |
| Brand tokens not applying | Missing asset link | Ensure `colors_and_type.css` is linked before other stylesheets |

## References

| Topic | File | Description |
|-------|------|-------------|
| Component styles | `component-styles.md` | Buttons, form inputs, range sliders, data tables CSS |
| Layout patterns | `css-layout-patterns.md` | Full-page, sidebar, control panel, card grid complete CSS |
| Brand design tokens | `brand-design-tokens.md` | Full semantic token set, typography scale, spacing, shadows, component tokens |
| Dark mode | `dark-mode.md` | Complete dark mode overrides for generic and branded themes |
| External color schemes | `external-color-schemes.md` | Importing Material Design, Adobe Color, Tailwind palettes into CSS tokens |

----

Copyright 2026 The MathWorks, Inc.

----
