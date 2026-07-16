---
name: matlab-build-chart
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
description: >
  Create and customize MATLAB charts and plots. Plot types (line, scatter,
  bar, histogram, heatmap, surface), axes configuration, annotations, data tips,
  interactive plots, animation, multiple axes with tiledlayout, colororder, and
  performance optimization. Works for standalone figures, Live Scripts, and uifigure
  apps. Use when plotting data, customizing axes, adding annotations or interactivity,
  animating charts, or arranging multiple axes. Triggers: plot, chart, graph, axes,
  uiaxes, annotation, data tips, animation, tiledlayout, colororder, heatmap, scatter,
  figure, visualization, export.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# MATLAB Chart Builder

Create, customize, and interact with MATLAB charts and plots — in standalone figures, Live Scripts, or uifigure apps.

## When to Use This Skill

Use this skill when:
- Plotting data (line, scatter, bar, histogram, heatmap, surface, polar, geo, volume) in any context
- Configuring axes (labels, limits, ticks, legend, font, export)
- Adding annotations (xline, yline, xregion, text)
- Adding or customizing data tips
- Creating interactive plots (click, hover, drag callbacks)
- Animating or streaming data to a chart
- Arranging multiple axes with tiledlayout/nexttile
- Optimizing chart rendering performance
- Exporting figures for publication or reports
- User says "help me visualize this" without a specific chart type

## When NOT to Use This Skill

- Building a full app (use `matlab-build-app` — it invokes this skill for chart sub-steps)
- Applying dark mode, brand colors, or custom color themes (use `matlab-theming`)
- Working with Simulink scopes or Simscape plots
- Creating App Designer charts via the drag-and-drop GUI

## Workflow

```
User request arrives
        |
        +-- FAST PATH (most requests)
        |   Chart type named OR unambiguous single-axes plot
        |   AND no interactivity / animation / multi-panel / performance concern
        |       |
        |       v
        |   Infer rendering context (default: standalone figure)
        |   Read relevant references --> Build directly
        |
        +-- PLAN PATH (complex or ambiguous)
                |
                +-- Ambiguous intent (no chart type named, unclear data question)
                |       --> Identify visualization intent (see Intent Taxonomy)
                |
                +-- Rendering context unclear AND it matters
                |       --> Ask: standalone figure, Live Script, or uifigure app?
                |
                v
            Present inline plan for approval
                |
                v
            User confirms --> Read references --> Build
```

### Fast-Path Triggers (build directly, no plan)

ALL of these must hold:
- Chart type is named OR intent maps unambiguously to one type
- Single axes (no tiled/multi-panel layout)
- No custom interactivity (no user-specified callbacks)
- No animation or streaming
- No explicit performance constraints
- Rendering context is clear or defaults to standalone figure

### Plan-Path Triggers (present plan first)

ANY of these fires the plan path:
- Multi-panel / tiled figure
- Custom interactivity (click, hover, drag callbacks)
- Animation or streaming data
- Performance-sensitive (large dataset, real-time update)
- Branded / designed figure requiring palette/theme coordination
- Ambiguous "help me visualize this" — unclear type or intent
- Multiple visualization intents in one figure

## Rendering Context

Three contexts gate which constraint set applies:

| Context | Constraints | How inferred |
|---------|-------------|--------------|
| **Standalone figure** | Universal rules only | Default; `figure`/`axes` in request |
| **Live Script** | Universal rules only | User mentions Live Script, `.mlx`, plain-text Live Code |
| **uifigure app** | Universal + uifigure rules | User mentions uifigure; arrives as sub-step of app-builder |

If context is unstated and cannot be inferred, assume standalone figure. Ask only when the distinction matters (e.g., heatmap parent differs between contexts).

## Visualization Intent Taxonomy

Engages ONLY when the user has NOT named a specific chart type or function. If they say "scatter" or "heatmap," skip intent selection and build directly.

### Communicative Intents

| Intent | Data question | Encouraged functions |
|--------|--------------|---------------------|
| **Comparison** | How do values compare across items? | `bar`, `barh`, `bar3`, `bar3h`, `pareto`, `stem`, `stairs`, `loglog`, `semilogx`, `semilogy` |
| **Trend / time series** | How does a value change over time? | `plot`, `area`, `stackedplot`, `stairs`, `stem`, `fplot`, `fplot3` |
| **Distribution** | How is data spread? | `histogram`, `histogram2`, `boxchart`, `violinplot`, `raincloudplot`, `swarmchart`, `swarmchart3`, `scatterhistogram`, `binscatter`, `polarhistogram` |
| **Relationship** | How do variables relate? | `scatter`, `scatter3`, `bubblechart`, `bubblechart3`, `plotmatrix`, `parallelplot`, `binscatter`, `spy`, `fimplicit` |
| **Composition** | Parts of a whole? | `piechart`, `donutchart`, stacked `bar`, stacked `area`, `wordcloud`, `bubblecloud` |

### Data-Domain Intents

| Intent | When it fires | Encouraged functions |
|--------|--------------|---------------------|
| **Geospatial** | Geographic coordinates | `geoplot`, `geoscatter`, `geobubble`, `geodensityplot` |
| **Directional / polar** | Angular, cyclical, compass data | `polarplot`, `polarscatter`, `polarhistogram`, `polarbubblechart`, `compassplot`, `fpolarplot` |
| **Surfaces & scalar fields** | z = f(x,y), meshes, contours | `surf`, `surfc`, `surfl`, `mesh`, `meshc`, `meshz`, `ribbon`, `pcolor`, `contour`, `contourf`, `contour3`, `fcontour`, `fsurf`, `fmesh`, `fimplicit3`, `waterfall` |
| **Vector fields & flow** | Directional vector data | `quiver`, `quiver3`, `feather`, `streamline`, `streamslice`, `streamribbon`, `streamtube`, `streamparticles`, `coneplot` |
| **Volume visualization** | 3D gridded volume data | `slice`, `contourslice`, `coneplot`, `streamslice`, isosurface/isocap workflows |
| **Images & matrices** | Display a matrix/grid | `image`, `imagesc`, `heatmap`, `pcolor` (flat), `spy` |

### Classification Rules

- **The `waterfall` trap:** MATLAB's `waterfall` is a 3D surface plot, NOT the financial accumulation chart. For "accumulation to total," build from `bar` with a hidden base series.
- **`f*` variants** follow their data counterpart's intent: `fplot` -> Trend, `fsurf`/`fmesh`/`fcontour` -> Surfaces, `fimplicit` -> Relationship, `fpolarplot` -> Directional.
- **Animation is cross-cutting**, not an intent. `animatedline`, `comet`, `comet3` layer motion onto any chart type. See `references/animation.md`.
- **Multi-intent functions:** Classify by the user's data question, not gallery grouping. E.g., heatmap of a correlation matrix -> Relationship; heatmap of counts -> Comparison.
- **Classify by communicative intent**, not MATLAB docs grouping. `piechart`/`donutchart` are Composition regardless of where docs file them.

## Inline Plan Template

When the plan path engages, present for approval:

```
**Chart Plan: [description]**

**Context:** [Standalone figure / Live Script / uifigure app]
**Intent:** [name] -> [chosen function(s)]

**Structure:**
- [Layout description]
- [Key visual elements, annotations, interactions]

**Key decisions:**
- [Performance strategy, if applicable]  [src: references/performance.md SS]
- [Interaction model, if applicable]  [src: references/interactive-plots.md SS]
- [uifigure constraints that apply, if context = uifigure]

**References to use:**
| Reference | Role | Provenance |
|-----------|------|------------|
| `references/file.md` | [what it provides] | [src: references/file.md SS] |

Shall I proceed?
```

Do NOT write the plan to a file unless (a) the user explicitly asks for a spec to keep, or (b) chart-builder is running as a sub-step of an app build with an existing plan artifact.

## Critical Rules

### Universal (all contexts)

- MUST pass axes as first argument to all plotting functions: `plot(ax, x, y)` not `plot(x, y)`
- MUST update data in place (`p.XData = newX`) — never replot in a loop
- MUST use `drawnow limitrate` for animations — never bare `drawnow` in tight loops
- PREFER `tiledlayout`/`nexttile` over `subplot()` for multiple axes
- PREFER `exportgraphics()` for publication-quality export

### Additional constraints in uifigure apps

- MUST use `uiaxes` — never plain `axes`
- MUST use `exportgraphics()` or `exportapp()` — `saveas`/`print` not supported
- NEVER use `subplot()` — not supported in uifigure
- NEVER use `annotation()` — use `text()`, `xline()`, `yline()`, `xregion()`, `yregion()`
- NEVER use `ginput()` — use `ButtonDownFcn` on plot objects
- NEVER rely on `gcf`/`gca` — uiaxes has `HandleVisibility = 'off'` by default

## Quick Start

### Standalone figure

```matlab
fig = figure;
ax = axes(fig);

t = 0:0.01:2*pi;
plot(ax, t, sin(t), 'LineWidth', 1.5);
hold(ax, 'on');
plot(ax, t, cos(t), '--', 'LineWidth', 1.5);
hold(ax, 'off');

title(ax, 'Sine and Cosine');
xlabel(ax, 'Time (s)');
ylabel(ax, 'Amplitude');
legend(ax, 'sin', 'cos');
grid(ax, 'on');
exportgraphics(ax, 'plot.png', 'Resolution', 300);
```

### In a uifigure app

```matlab
fig = uifigure('Name', 'Chart Demo');
gl = uigridlayout(fig, [1 1]);
ax = uiaxes(gl);

plot(ax, t, sin(t), 'LineWidth', 1.5);
% Same API from here — only axes creation differs
```

Once you have `ax`, all plotting calls (`plot`, `scatter`, `bar`, `xline`, `hold`, `legend`, `colororder`, etc.) are identical regardless of context.

## Implementation Checklist

### Graphics
- [ ] All plot calls pass `ax` as first argument
- [ ] `hold(ax, 'on')` used before adding multiple series
- [ ] Axes labels, title, and grid configured
- [ ] Annotations use `xline`/`yline`/`text` (not `annotation()` — uifigure requirement)
- [ ] Interactive callbacks use `ButtonDownFcn` on plot objects (not axes — uifigure requirement)
- [ ] Animations use `drawnow limitrate` and pre-set axis limits
- [ ] Export uses `exportgraphics()` (required in uifigure; preferred everywhere)
- [ ] Multiple axes use `tiledlayout`/`nexttile` (required in uifigure; preferred everywhere)

## Troubleshooting

Issues marked *(uifigure only)* apply only when plotting in uifigure apps.

| Problem | Cause | Fix |
|---|---|---|
| Animation is slow/jerky | Using `plot()` in loop or bare `drawnow` | Update data in place + `drawnow limitrate` |
| Plot disappears after replot | Default `NextPlot = 'replacechildren'` | Use `hold(ax, 'on')` or update data in place |
| `gcf`/`gca` return wrong handle *(uifigure only)* | uiaxes `HandleVisibility = 'off'` | Always pass `ax` explicitly |
| `annotation()` error *(uifigure only)* | Not supported in uifigure | Use `text()`, `xline()`, `yline()` |
| `ginput()` error *(uifigure only)* | Not supported in uifigure | Use `ButtonDownFcn` on plot objects |
| Click callback doesn't fire on axes *(uifigure only)* | `ButtonDownFcn` unreliable on uiaxes | Put `ButtonDownFcn` on plot objects |
| Heatmap fails in uiaxes *(uifigure only)* | Heatmap needs figure/panel parent | Use `heatmap(fig, ...)` or `heatmap(panel, ...)` |
| `saveas` fails *(uifigure only)* | Not supported for uifigure | Use `exportgraphics(ax, file)` |
| `subplot()` errors *(uifigure only)* | Not supported in uifigure | Use `tiledlayout`/`nexttile` or `uigridlayout` |
| Zoom stops working after scroll callback *(uifigure only)* | `WindowScrollWheelFcn` disables zoom | Call `disableDefaultInteractivity(ax)` |

## References

| Topic | File | Coverage | Intent served |
|-------|------|----------|---------------|
| Plot types | `references/plot-types.md` | Line, scatter, bar, histogram, heatmap, surface | Comparison, Trend, Distribution, Relationship, Surfaces (partial) |
| Axes configuration | `references/axes-config.md` | uiaxes setup, labels, limits, ticks, font, legend, export | All intents |
| Annotations | `references/annotations.md` | xline, yline, xregion, text, patch | All intents (overlay) |
| Data tips | `references/data-tips.md` | DataTipTemplate, custom rows, programmatic tips | All intents (overlay) |
| Interactive plots | `references/interactive-plots.md` | ButtonDownFcn, mouse callbacks, drag, HitTest, toolbar | Plan-path: interactivity |
| Chart palettes | `references/chart-palettes.md` | colororder, named palettes, SeriesIndex, vs colormap | All intents (styling) |
| Animation | `references/animation.md` | Update in place, animatedline, streaming, performance | Plan-path: animation |
| Multiple axes | `references/multiple-axes.md` | tiledlayout, nexttile, linkaxes, peripheral tiles | Plan-path: multi-panel |
| Performance | `references/performance.md` | Lazy-load, batch updates, throttle, parfeval, startup | Plan-path: performance |

### Reference Gaps (follow-up authoring needed)

These intents have no dedicated reference file. Use built-in MATLAB API knowledge:
- **Composition** — `piechart`, `donutchart`, stacked bar/area, `wordcloud`, `bubblecloud`
- **Geospatial** — `geoplot`, `geoscatter`, `geobubble`, `geodensityplot`
- **Directional / polar** — `polarplot`, `polarscatter`, `polarhistogram`, `polarbubblechart`, `compassplot`, `fpolarplot`
- **Vector fields & flow** — `quiver`, `quiver3`, `feather`, `streamline`, `streamslice`, `streamribbon`, `streamtube`, `streamparticles`, `coneplot`
- **Volume visualization** — `slice`, `contourslice`, `coneplot`, isosurface/isocap workflows
- **Images & matrices** (partial) — `image`, `imagesc` not covered; `heatmap` in plot-types
- **Surfaces** (partial) — only `surf` covered; `mesh`, `contour`, `ribbon`, `pcolor` pending

### External Skills (invoked, not read)

- `matlab-theming` — when the chart needs dark mode, brand colors, or custom palettes

----

Copyright 2026 The MathWorks, Inc.

----
