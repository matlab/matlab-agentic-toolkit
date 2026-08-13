# Importing External Color Schemes

Apply an external color scheme (Material Design, Adobe Color, Tailwind, etc.) by replacing the color custom properties on `:root`. See `matlab-apply-theme` for the shared token vocabulary and cross-path alignment.

## Step 1: Extract the Palette

| Source | How to get colors |
|---|---|
| Adobe Color | Export hex values from your saved theme |
| Material Design | Pick a primary + secondary from the color system |
| Tailwind | Use the numbered scale (e.g. `indigo-600`, `rose-500`) |
| Coolors/Realtime Colors | Export hex palette |

Most palettes give you 3-6 colors. You need at minimum: **primary**, **secondary**, and optionally **error/success/warning**.

## Step 2: Map to CSS Custom Properties

```css
/* Example: Material Design Indigo + Pink */
:root {
    --accent: #3949AB;          /* Indigo 600 → primary */
    --accent-hover: #303F9F;    /* Indigo 700 → primary hover */
    --accent-light: rgba(57, 73, 171, 0.1);
    --error: #D32F2F;           /* Red 700 */
    --success: #388E3C;         /* Green 700 */
    --border: #E0E0E0;          /* Grey 300 */
    /* bg-*, text-* tokens stay the same for light/dark base */
}

:root.dark {
    --accent: #7986CB;          /* Indigo 300 (lighter for dark bg) */
    --accent-hover: #9FA8DA;    /* Indigo 200 */
    --accent-light: rgba(121, 134, 203, 0.15);
    --error: #EF5350;           /* Red 400 */
    --success: #66BB6A;         /* Green 400 */
    --border: #444444;
}
```

All components using `var(--accent)` etc. update automatically — no other changes needed.

## Token Alignment with MATLAB

If building a cross-path app (MATLAB + web), ensure your CSS tokens align with the MATLAB theme struct. The `matlab-apply-theme` skill maps between them:

| Semantic Token | CSS Variable | MATLAB Struct |
|---|---|---|
| primary | `--accent` | `theme.primary` |
| error | `--error` | `theme.error` |
| success | `--success` | `theme.success` |
| border | `--border` | `theme.border` |

For the MATLAB-side import workflow, see `matlab-apply-theme`.

## Using with Branded Tokens

When using the branded semantic token system, map your external palette to the raw palette layer (`--c-*`) and let the semantic tokens inherit:

```css
:root {
    /* Override raw palette values with your brand */
    --c-brand-3: #3949AB;       /* Your primary */
    --c-brand-2: #303F9F;       /* Your primary hover */
    --c-red-600: #D32F2F;       /* Your error */
    --c-green-600: #388E3C;     /* Your success */
}
/* All semantic tokens that reference these palette values update automatically */
```

----

Copyright 2026 The MathWorks, Inc.

----
