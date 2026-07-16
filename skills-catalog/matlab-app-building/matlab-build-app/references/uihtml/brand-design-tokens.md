# Brand Design Tokens

Full semantic token set for professional web interfaces. Use these when building polished UIs that match MATLAB's visual language.

## Token Architecture

Two layers — always keep them separate in your own code:

| Layer | Prefix | Purpose | When to reference |
|---|---|---|---|
| Raw palette | `--c-*` | A named color at a specific shade | Only when defining a new semantic token |
| Semantic | `--color-*`, `--bg-*`, `--border-*` | Color assigned to a UI role | In all component and layout styles |

Structural tokens (`--font-*`, `--text-*`, `--space-*`, `--radius-*`, `--shadow-*`) have no prefix and can be used directly.

## Key Semantic Tokens (light theme)

```css
/* Text */
--color-text-primary          /* #212121 — all body text */
--color-text-secondary        /* #616161 — labels, captions */
--color-text-hyperlink        /* #1171BE */
--color-text-disabled         /* #A6A6A6 */

/* Backgrounds */
--bg-primary     /* #F5F5F5 — canvas, panel background */
--bg-code        /* #FFFFFF — editor, code background */
--bg-secondary   /* #E6E6E6 — secondary surfaces */

/* Borders */
--border-primary         /* #7D7D7D — inputs, panel dividers */
--border-secondary       /* #BFBFBF — subtle separators */

/* Selection */
--color-selection-primary     /* #1656A7 — selected item highlight */
--color-selection-tertiary    /* #B4DEFF — selection background */

/* Alerts */
--color-alert-error           /* #B7312C */
--color-alert-warning         /* #B36205 */
--color-alert-success         /* #008013 */
--color-alert-error-bg        /* red-100   — alert background */
--color-alert-warning-bg      /* honey-100 — alert background */
--color-alert-success-bg      /* green-100 — alert background */
```

## Typography

```css
/* Font stacks (defined in colors_and_type.css) */
font-family: var(--font-sans);   /* Source Sans 3 → Helvetica Neue → system-ui */
font-family: var(--font-mono);   /* Source Code Pro → Consolas → monospace */

/* Scale — use token names, not raw px */
--text-xs:   11px   /* Tiny labels, status chips */
--text-sm:   12px   /* Secondary metadata */
--text-base: 13px   /* DEFAULT — standard UI text */
--text-md:   14px   /* Slightly prominent labels */
--text-lg:   16px   /* Subheadings */
--text-xl:   18px   /* Section headings */
--text-2xl:  20px   /* Page subheadings */
--text-3xl:  24px   /* Page headings */
--text-4xl:  28px   /* H1 page titles */
--text-5xl:  36px   /* Hero / display titles */

/* Weights */
--fw-normal: 400    /* Body text */
--fw-semi:   600    /* Labels, emphasis */
--fw-bold:   700    /* Headings */
```

Default is 13px (`--text-base`). MATLAB targets power users — the UI is intentionally compact. Don't increase the base size to "feel more modern."

## Spacing

4px base grid. Use numeric tokens — do not introduce alternative names (`--space-xs/sm/md`):

```
--space-1:  4px    --space-5:  20px   --space-10: 40px
--space-2:  8px    --space-6:  24px   --space-12: 48px
--space-3:  12px   --space-8:  32px   --space-16: 64px
--space-4:  16px
```

## Component Tokens

Ready-to-use metrics encoding dense-UI conventions. Use these for toolstrip-style chrome, sidebars, and form controls:

```css
/* Toolstrip */
--toolstrip-height:       36px
--toolstrip-bg:           var(--c-gray-50)
--toolstrip-border:       var(--c-gray-300)
--toolstrip-item-hover:   var(--c-gray-100)
--toolstrip-item-active:  var(--c-gray-200)

/* Sidebar */
--sidebar-width:          240px
--sidebar-bg:             var(--c-gray-50)
--sidebar-border:         var(--c-gray-300)

/* Inputs — height 28px, radius 2px */
--input-bg:               var(--c-white)
--input-border:           var(--c-gray-600)
--input-border-focus:     var(--c-blue-550)
--input-border-error:     var(--c-red-600)
--input-height:           28px
--input-radius:           var(--radius-sm)    /* 2px */

/* Buttons — height 28px, radius 2px */
--btn-height:             28px
--btn-radius:             var(--radius-sm)    /* 2px */
--btn-primary-bg:         var(--c-brand-3)    /* #004B87 */
--btn-primary-bg-hover:   var(--c-brand-2)
--btn-primary-text:       var(--c-white)
--btn-secondary-bg:       var(--c-white)
--btn-secondary-text:     var(--c-gray-900)
--btn-secondary-border:   var(--c-gray-600)
--btn-destructive-bg:     var(--c-red-600)
--btn-destructive-text:   var(--c-white)
```

**Radius note:** `--radius-sm` is 2px — intentionally tighter than generic web UI conventions (4px). Use for inputs, buttons, badges, tags. Use `--radius-md: 4px` for cards and dialogs only.

## Graphics / Chart Colors

Use `--c-graphics-*` for data series — these are the MATLAB default `colororder`, ensuring web charts stay consistent with MATLAB figures:

```css
--c-graphics-1:  #0072BD   /* Blue   */
--c-graphics-2:  #D95319   /* Orange */
--c-graphics-3:  #EDB120   /* Gold   */
--c-graphics-4:  #7E2F8E   /* Purple */
--c-graphics-5:  #77AC30   /* Green  */
--c-graphics-6:  #4DBEEE   /* Cyan   */
--c-graphics-7:  #A2142F   /* Dark red */
/* --c-graphics-8 through --c-graphics-12 extend the series */
```

## Voice & Tone

All copy in professional interfaces:

| Rule | Correct | Incorrect |
|---|---|---|
| Sentence case for UI labels | "Run section" | "Run Section" |
| Product names: Title Case | "MATLAB", "Live Editor" | "matlab", "live editor" |
| No emoji in product UI | — | Done |
| Numerals always | "3 errors" | "three errors" |
| No first person | "Save" | "Save My Work" |
| Error messages: specific + remedial | "File not found. Check the path." | "An error occurred." |
| Placeholders describe format | "e.g. 3.14" | "Enter value here" |

----

Copyright 2026 The MathWorks, Inc.

----
