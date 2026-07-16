# Chart Type Selection

Choose the right library and chart type before writing any code.

---

## Library Selection

| Library | When to choose |
|---|---|
| **Chart.js** | Default choice. Category data, time series, compositions, dashboards. Simple API, small bundle (~200 KB), excellent tooltip/legend out of the box. |
| **D3.js** | Custom or non-standard layouts: force graphs, treemaps, chord diagrams, custom axes. Full control, but much steeper API surface — use only when Chart.js cannot produce the needed output. |
| **Plotly.js** | Scientific/engineering charts: contour, heatmap, 3D surface, statistical box/violin. Also good when the user wants Plotly's interactive toolbar (pan, zoom, download) without custom code. ~3 MB bundle. |

**Rule:** Default to Chart.js. Reach for D3 only when the chart shape is non-standard. Reach for Plotly when scientific chart types or built-in toolbar are required.

---

## Chart Type Decision

| Data shape | Recommended chart | Notes |
|---|---|---|
| Values over time / ordered sequence | **Line** | Use `chartjs-adapter-date-fns` for real time axes |
| Category comparisons (few categories) | **Vertical bar** | ≤8 categories; auto-flip to horizontal above 8 |
| Category comparisons (many categories) | **Horizontal bar** | Set `indexAxis: 'y'`; label text fits better |
| Part-to-whole composition | **Doughnut** | ≤6 segments; prefer over pie (center label space) |
| Part-to-whole over time | **Stacked bar** | Shows absolute AND relative change |
| Two continuous variables | **Scatter** | Use bubble (`type: 'bubble'`) when a third dimension matters |
| Volume + rate on same axes | **Mixed bar + line** | Bar for volume, line for rate (e.g. revenue + margin%) |
| Correlation matrix / density | **Plotly heatmap** | Chart.js has no native heatmap |
| Distribution / outliers | **Plotly box/violin** | Chart.js has no native box plot |
| Network / hierarchy | **D3** | Force-directed, tree, or pack layouts |
| Geographic / spatial | **D3** or Leaflet | Chart.js has no map support |

---

## Chart Type Anti-Patterns

| Situation | Avoid | Use instead |
|---|---|---|
| >6 doughnut segments | Doughnut | Horizontal bar; group small segments into "Other" |
| Continuous time data as bar | Bar with date labels | Line chart with time scale |
| 3D charts for 2D data | 3D bar/surface | 2D equivalent — 3D distorts perception |
| Pie chart | Pie | Doughnut (same data, better readability) |
| Too many series on one line chart | >6 lines | Facet into multiple smaller charts or use a table |

---

## D3 vs Chart.js Decision Heuristic

Answer these questions:

1. **Is the chart type in the table above?** → Chart.js is sufficient.
2. **Do you need custom interaction that goes beyond tooltips?** (brush selection, drag-to-zoom on arbitrary axes, linked views) → Consider D3.
3. **Do you need to animate data as a flow or transition between layouts?** → D3.
4. **Does the user's team know D3?** If not, the implementation cost is high — consider Plotly for scientific types instead.

For the typical MATLAB uihtml use case (show results from MATLAB computation as a chart), Chart.js handles 90% of needs.

----

Copyright 2026 The MathWorks, Inc.

----
