# UIHTML JS Charting

Add interactive charts to web frontends for UIHTML app and Standalone web app apps. This skill covers the charting layer — library selection, Chart.js setup, standard chart patterns, data updates, and MATLAB bridge integration.

For the MATLAB-JS data bridge see `bridge-guide.md`. For CSS layout and tokens see `styling-guide.md`. 

## Critical Rules

- NEVER link to a CDN inside a uihtml app — uihtml cannot reach external URLs. Download Chart.js locally and reference it with a relative path
- MUST set `responsive: true, maintainAspectRatio: false` on every chart in uihtml — the component resizes dynamically and the chart must follow
- MUST place `<canvas>` inside a container `<div>` with an explicit height — Chart.js inherits height from the container, not the canvas element
- MUST store every chart instance in a variable — you cannot update a chart you cannot reference
- ALWAYS call `chart.destroy()` before recreating a chart on the same canvas element
- ALWAYS use `chart.update('none')` for filter/data-driven updates — the `'none'` mode skips animation for instant response
- NEVER use `var` — use `const` and `let`
- Build-free only — vanilla JS with CDN or local file; no npm/webpack unless the user requests it

## Quick Start

Minimal Chart.js bar chart (standalone — CDN is fine):

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.min.js"></script>
  <style>
    body { margin: 0; font-family: system-ui, sans-serif; }
    .chart-wrap { height: 300px; padding: 16px; }
  </style>
</head>
<body>
  <div class="chart-wrap">
    <canvas id="myChart"></canvas>
  </div>
  <script>
    const COLORS = ['#0072BD','#D95319','#EDB120','#7E2F8E','#77AC30','#4DBEEE','#A2142F'];

    const chart = new Chart(document.getElementById('myChart'), {
      type: 'bar',
      data: {
        labels: ['Alpha', 'Beta', 'Gamma'],
        datasets: [{ label: 'Value', data: [42, 78, 55],
          backgroundColor: COLORS.map(c => c + 'CC') }]
      },
      options: { responsive: true, maintainAspectRatio: false }
    });
  </script>
</body>
</html>
```

For uihtml: replace the CDN `<script src>` with a local path (`./lib/chart.umd.min.js`). See `chartjs-setup.md`.

For receiving MATLAB data and updating the chart, see `chart-bridge-integration.md`.

## Implementation Checklist

- [ ] Chart library chosen for the use case (Chart.js, D3, or Plotly — see `chart-type-selection.md`)
- [ ] CDN used for standalone; local file used for uihtml
- [ ] `<canvas>` wrapped in a `<div>` with explicit height
- [ ] `responsive: true, maintainAspectRatio: false` set on every chart
- [ ] Chart instance stored in a variable (not created anonymously)
- [ ] `chart.destroy()` called before recreating on the same canvas
- [ ] `chart.update('none')` used for data-driven updates (not `chart.update()`)
- [ ] Colors sourced from MATLAB colororder (COLORS array)
- [ ] MATLAB bridge data wired: DataChanged or event listener triggers chart update
- [ ] Performance: data size assessed; pre-aggregation or sampling applied if needed

## References

| Topic | File | Description |
|-------|------|-------------|
| Library selection | `chart-type-selection.md` | Chart.js vs D3 vs Plotly decision guide; chart type for data shape |
| Chart.js setup | `chartjs-setup.md` | Script tags, canvas pattern, MATLAB colors, CDN vs local |
| Line & bar charts | `line-bar-charts.md` | createLineChart, createBarChart, tooltip/axis formatting |
| Doughnut & scatter | `doughnut-scatter-charts.md` | createDoughnutChart, createScatterChart, stacked bar, mixed |
| Chart updates | `chart-updates.md` | updateChart, chart.update('none'), destroy pattern |
| Bridge integration | `chart-bridge-integration.md` | DataChanged → chart, event-driven updates |
| Performance | `chart-performance.md` | Data size limits, pre-aggregation, sampling, animation flags |

----

Copyright 2026 The MathWorks, Inc.

----
