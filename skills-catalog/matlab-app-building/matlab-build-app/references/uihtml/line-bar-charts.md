# Line and Bar Charts

---

## Line Chart

Best for: time series trends, multi-series comparisons over an ordered axis.

```javascript
/**
 * @param {string} canvasId
 * @param {string[]} labels       - x-axis labels (strings or Date objects)
 * @param {Array<{label, data, fill?}>} datasets
 * @param {{ format?: 'number'|'currency'|'percent' }} [opts]
 */
function createLineChart(canvasId, labels, datasets, opts = {}) {
  const canvas = document.getElementById(canvasId);
  const existing = Chart.getChart(canvas);
  if (existing) existing.destroy();

  return new Chart(canvas, {
    type: 'line',
    data: {
      labels,
      datasets: datasets.map((ds, i) => ({
        label: ds.label,
        data: ds.data,
        borderColor: COLORS[i % COLORS.length],
        backgroundColor: COLORS[i % COLORS.length] + '20',
        borderWidth: 2,
        fill: ds.fill ?? false,
        tension: 0.3,
        pointRadius: labels.length > 50 ? 0 : 3,   // hide points on dense series
        pointHoverRadius: 6,
      }))
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',      // tooltip shows all series at the hovered x position
        intersect: false,
      },
      plugins: {
        legend: {
          position: 'top',
          labels: { usePointStyle: true, padding: 20 }
        },
        tooltip: {
          callbacks: {
            label: ctx => `${ctx.dataset.label}: ${formatValue(ctx.parsed.y, opts.format)}`
          }
        }
      },
      scales: {
        x: { grid: { display: false } },
        y: {
          beginAtZero: true,
          ticks: { callback: v => formatValue(v, opts.format) }
        }
      }
    }
  });
}
```

**Time scale axis** (requires `chartjs-adapter-date-fns`):

```javascript
scales: {
  x: {
    type: 'time',
    time: { unit: 'month', tooltipFormat: 'MMM yyyy' },
    grid: { display: false }
  }
}
```

Pass ISO date strings (`'2024-01-15'`) or `Date` objects as labels.

---

## Bar Chart

Best for: category comparisons. Auto-flips to horizontal when categories exceed 8.

```javascript
/**
 * @param {string} canvasId
 * @param {string[]} labels
 * @param {number[]} data
 * @param {{ label?, colors?, format?, horizontal? }} [opts]
 */
function createBarChart(canvasId, labels, data, opts = {}) {
  const canvas = document.getElementById(canvasId);
  const existing = Chart.getChart(canvas);
  if (existing) existing.destroy();

  const isHorizontal = opts.horizontal ?? labels.length > 8;

  return new Chart(canvas, {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: opts.label ?? 'Value',
        data,
        backgroundColor: opts.colors ?? COLORS.map(c => c + 'CC'),
        borderColor:     opts.colors ?? COLORS,
        borderWidth: 1,
        borderRadius: 4,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: isHorizontal ? 'y' : 'x',
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: ctx => formatValue(ctx.parsed[isHorizontal ? 'x' : 'y'], opts.format)
          }
        }
      },
      scales: {
        x: {
          beginAtZero: true,
          grid: { display: isHorizontal },
          ticks: isHorizontal ? { callback: v => formatValue(v, opts.format) } : {}
        },
        y: {
          beginAtZero: !isHorizontal,
          grid: { display: !isHorizontal },
          ticks: !isHorizontal ? { callback: v => formatValue(v, opts.format) } : {}
        }
      }
    }
  });
}
```

**Grouped bar** (multiple datasets on the same x-axis):

```javascript
data: {
  labels,
  datasets: [
    { label: 'Series A', data: dataA, backgroundColor: COLORS[0] + 'CC' },
    { label: 'Series B', data: dataB, backgroundColor: COLORS[1] + 'CC' },
  ]
}
// Chart.js renders grouped bars automatically when multiple datasets share the same labels
```

---

## Value Formatter

Shared formatter for axis ticks and tooltips. Define once, reuse across charts:

```javascript
function formatValue(value, format) {
  switch (format) {
    case 'currency':
      if (value >= 1e6) return `$${(value / 1e6).toFixed(1)}M`;
      if (value >= 1e3) return `$${(value / 1e3).toFixed(1)}K`;
      return `$${value.toFixed(0)}`;
    case 'percent':
      return `${value.toFixed(1)}%`;
    case 'number':
    default:
      if (value >= 1e6) return `${(value / 1e6).toFixed(1)}M`;
      if (value >= 1e3) return `${(value / 1e3).toFixed(1)}K`;
      return value.toLocaleString();
  }
}
```

---

## Common Options Reference

| Option | Value | Effect |
|---|---|---|
| `responsive: true` | — | Chart resizes with container |
| `maintainAspectRatio: false` | — | Container height controls chart height |
| `animation: false` | — | Disables all transitions (use for dashboards) |
| `interaction.mode: 'index'` | — | Tooltip shows all series at the x position |
| `interaction.intersect: false` | — | Tooltip triggers without hovering a point |
| `scales.x.grid.display: false` | — | Removes vertical grid lines |
| `scales.y.beginAtZero: true` | — | Y axis always starts at 0 |
| `plugins.legend.display: false` | — | Hides the legend (use for single-series charts) |

----

Copyright 2026 The MathWorks, Inc.

----
