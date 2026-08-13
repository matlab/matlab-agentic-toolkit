---
name: matlab-apply-theme
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
description: >
  Style MATLAB charts and figures. colororder palettes for chart series colors,
  colormap selection, brand color organization, and the R2025a Theme API for uifigure
  apps (dark mode with fliplightness, ThemeChangedFcn, uistyle, component colors).
  Use when customizing chart colors, applying a color palette, organizing brand colors,
  implementing dark mode, or importing an external color scheme. Triggers: theme,
  dark mode, brand colors, colororder, colormap, palette, fliplightness, color scheme,
  styling, chart colors.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# MATLAB Theming

Style MATLAB charts with color palettes and — for uifigure apps — apply the R2025a Theme API for brand colors, dark mode, and component styling.

## When to Use This Skill

Use this skill when:
- Setting `colororder` for chart series colors (any context)
- Choosing or importing a color palette for plots
- Organizing brand colors into a reusable struct
- Applying a custom `colormap` for continuous data
- Implementing dark mode with `fliplightness()` (uifigure)
- Wiring `ThemeChangedFcn` to react to OS/user theme changes (uifigure)
- Using `uistyle` for conditional formatting in tables/trees (uifigure)
- Importing an external color scheme (Material Design, Adobe Color, Tailwind)

## When NOT to Use This Skill

- Choosing chart types or building charts from scratch (use `matlab-build-chart`)
- Building a full app layout (use `matlab-build-app` — it invokes this skill for theming sub-steps)
- Setting colors on individual plot elements as a one-off (just use the `Color` property directly)
- Non-MATLAB styling (CSS, HTML themes for web apps)

## Critical Rules

### Universal (all contexts)

- MUST centralize brand/palette colors in a struct — never scatter RGB values
- ALWAYS use `colororder()` for categorical chart series colors
- ALWAYS use `colormap()` for continuous scalar-mapped colors
- NEVER confuse `colororder` (categorical series) with `colormap` (continuous gradient)

### Additional rules for uifigure apps (R2025a Theme API)

- MUST use R2025a Theme API — do NOT manually set figure background or standard component colors
- MUST use `fliplightness()` to derive dark variants unless explicitly designing custom dark colors
- NEVER set a component's color explicitly unless branding requires it — breaks theme adaptation
- ALWAYS use the semantic token vocabulary defined below for cross-path consistency

## Semantic Token Vocabulary

Both MATLAB and web implementations map to these common tokens. When importing an external color scheme, map its colors to these tokens once.

| Token | Purpose | MATLAB (struct field) | Web (CSS variable) |
|---|---|---|---|
| `primary` | Brand/action color (buttons, links, active states) | `theme.primary` | `--accent` |
| `onPrimary` | Text/icon on primary background | `theme.onPrimary` | `--accent-text` |
| `secondary` | Secondary brand color (less prominent actions) | `theme.secondary` | `--secondary` |
| `error` | Error/destructive state | `theme.error` | `--error` |
| `success` | Success/confirmation state | `theme.success` | `--success` |
| `warning` | Warning/caution state | `theme.warning` | `--warning` |
| `border` | Custom borders and dividers | `theme.border` | `--border` |
| `plotColors` | Chart series colors (Nx3 RGB matrix) | `theme.plotColors` | N/A (use chart library config) |

**MATLAB note:** Surface/text colors (`--bg-primary`, `--text-primary` in CSS) are NOT in the MATLAB theme struct. The R2025a Theme API handles those automatically. Only define brand/custom colors.

## Quick Start

### Color palettes for any figure

```matlab
colors = [0 0.447 0.741; 0.85 0.33 0.10; 0.93 0.69 0.13; ...
          0.49 0.18 0.56; 0.47 0.67 0.19; 0.30 0.75 0.93];
colororder(ax, colors);
% All series in this axes now cycle through these colors
```

### Theme struct for uifigure apps (R2025a)

```matlab
function theme = createTheme(mode)
    arguments
        mode string {mustBeMember(mode, ["light", "dark"])} = "light"
    end
    theme.primary = [0 0.447 0.741];    % MATLAB blue
    theme.onPrimary = [1 1 1];
    theme.error = [0.83 0.18 0.18];
    theme.success = [0.22 0.56 0.24];
    theme.border = [0.88 0.88 0.88];
    theme.plotColors = [0 0.447 0.741; 0.85 0.33 0.10; 0.93 0.69 0.13; ...
                        0.49 0.18 0.56; 0.47 0.67 0.19; 0.30 0.75 0.93; 0.64 0.08 0.18];
    if mode == "dark"
        theme.primary = fliplightness(theme.primary);
        theme.plotColors = fliplightness(theme.plotColors);
    end
end
```

Wiring to a figure:

```matlab
fig.ThemeChangedFcn = @(src, ~) applyTheme(src, ax);

function applyTheme(fig, ax)
    theme = createTheme(fig.Theme.BaseColorStyle);
    colororder(ax, theme.plotColors);
end
```

## Light/Dark Strategy

1. **Don't set** figure background, standard component bg/text — Theme API handles it automatically
2. **Do set** brand colors (primary buttons, accent labels, status indicators) via theme struct
3. Use `ThemeChangedFcn` to swap brand colors when OS/user toggles dark mode
4. Use `fliplightness()` to auto-derive dark brand colors from light definitions
5. Leave `ColorMode = "auto"` on components wherever possible

What breaks automatic theming — setting any color explicitly switches `ColorMode` to `"manual"`:

```matlab
btn.BackgroundColor = [0.2 0.4 0.8];  % Now manual — won't adapt to theme
btn.BackgroundColorMode = "auto";       % Restore theme control
```

## Color Types in MATLAB

| Type | API | When to use |
|---|---|---|
| **Component colors** | `btn.BackgroundColor`, `lbl.FontColor` | UI element branding |
| **Series colors** | `colororder(colors)` or `colororder("palette")` | Multiple lines/bars/scatter in one axes |
| **Continuous colors** | `colormap(map)` | Heatmaps, surfaces, contours, images |
| **Cell/row styling** | `uistyle` + `addStyle` | Conditional formatting in tables/trees |

- `colororder` = categorical (series A, B, C get distinct colors)
- `colormap` = continuous (scalar values mapped to gradient)
- Don't confuse them — they serve different purposes

## Importing External Color Schemes

### Workflow

1. **Pick a scheme** from Material Design, Adobe Color, Tailwind, etc.
2. **Extract 5-7 key colors**: primary, secondary, error, success, warning, border + 5-7 chart series colors
3. **Convert hex to [R G B]** normalized 0-1: `rgb = sscanf(hex(2:end), '%2x', 3)' / 255`
4. **Map to theme struct fields**: `theme.primary`, `theme.secondary`, etc.
5. **Test both modes**: verify `fliplightness()` produces acceptable dark variants; override manually if not
6. **Apply via `applyBrandColors`**: the function reads the struct and sets tagged components

See `references/external-schemes.md` for complete Material Design, Adobe Color, and Tailwind import examples.

## Implementation Checklist

### Styling
- [ ] Brand colors centralized in `createTheme` struct
- [ ] `fliplightness()` used for dark variants
- [ ] Branded components tagged for `findall` lookup
- [ ] `ThemeChangedFcn` wired to re-apply brand colors
- [ ] `colororder` set from `theme.plotColors`
- [ ] No explicit colors on auto-themed components

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Component doesn't change with dark mode | Color set explicitly | Remove explicit color or set `BackgroundColorMode = "auto"` |
| `fliplightness` not found | MATLAB < R2025a | Upgrade or define manual dark colors |
| Chart colors don't update on theme switch | `colororder` not re-applied | Add `colororder(ax, theme.plotColors)` to theme handler |
| `findall` returns empty | Tag not set or misspelled | Verify `Tag` property matches exactly |

## References

| Topic | File | Description |
|-------|------|-------------|
| Theme API | `references/theme-api.md` | R2025a lock/detect/react, auto vs manual theming |
| Component colors | `references/component-colors.md` | Color properties table + uistyle for tables/trees |
| External schemes | `references/external-schemes.md` | Material Design, Adobe Color, Tailwind import workflows |

----

Copyright 2026 The MathWorks, Inc.

----
