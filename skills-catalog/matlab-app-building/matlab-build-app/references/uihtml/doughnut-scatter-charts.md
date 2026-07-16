# Doughnut, Scatter, and Composition Charts

---

## Doughnut Chart

Best for: part-to-whole composition with ≤6 segments. Prefer over pie — the center hole leaves room for a summary label.

```javascript
/**
 * @param {string} canvasId
 * @param {string[]} labels
 * @param {number[]} data
 * @param {{ centerLabel? }} [opts]   - optional text to display in the center hole
 */
function createDoughnutChart(canvasId, labels, data, opts = {}) {
  const canvas = document.getElementById(canvasId);
  const existing = Chart.getChart(canvas);
  if (existing) existing.destroy();

  const total = data.reduce((a, b) => a + b, 0);

  const centerLabelPlugin = opts.centerLabel ? {
    id: 'centerLabel',
    afterDraw(chart) {
      const { ctx, chartArea: { top, left, width, height } } = chart;
      ctx.save();
      ctx.font = 'bold 18px system-ui';
      ctx.fillStyle = '#1a1a1a';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(opts.centerLabel, left + width / 2, top + height / 2);
      ctx.restore();
    }
  } : null;

  return new Chart(canvas, {
    type: 'doughnut',
    data: {
      labels,
      datasets: [{
        data,
        backgroundColor: COLORS.map(c => c + 'CC'),
        borderColor: '#ffffff',
        borderWidth: 2,
        hoverOffset: 6,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: '62%',
      plugins: {
        legend: {
          position: 'right',
          labels: { usePointStyle: true, padding: 15 }
        },
        tooltip: {
          callbacks: {
            label: ctx => {
              const pct = ((ctx.parsed / total) * 100).toFixed(1);
              return `${ctx.label}: ${ctx.parsed.toLocaleString()} (${pct}%)`;
            }
          }
        }
      }
    },
    plugins: centerLabelPlugin ? [centerLabelPlugin] : []
  });
}
```

**When >6 segments:** group the smallest into an "Other" bucket:

```javascript
function collapseTail(labels, data, topN = 6) {
  const indexed = labels.map((l, i) => ({ label: l, value: data[i] }))
    .sort((a, b) => b.value - a.value);
  const top = indexed.slice(0, topN);
  const rest = indexed.slice(topN).reduce((sum, d) => sum + d.value, 0);
  if (rest > 0) top.push({ label: 'Other', value: rest });
  return { labels: top.map(d => d.label), data: top.map(d => d.value) };
}
```

---

## Scatter Chart

Best for: correlations between two continuous variables (x, y data pairs).

```javascript
/**
 * @param {string} canvasId
 * @param {Array<{x, y}>} points
 * @param {{ label?, xLabel?, yLabel?, format? }} [opts]
 */
function createScatterChart(canvasId, points, opts = {}) {
  const canvas = document.getElementById(canvasId);
  const existing = Chart.getChart(canvas);
  if (existing) existing.destroy();

  return new Chart(canvas, {
    type: 'scatter',
    data: {
      datasets: [{
        label: opts.label ?? 'Data',
        data: points,
        backgroundColor: COLORS[0] + '99',
        borderColor: COLORS[0],
        borderWidth: 1,
        pointRadius: 5,
        pointHoverRadius: 8,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: ctx => `(${formatValue(ctx.parsed.x, opts.format)}, ${formatValue(ctx.parsed.y, opts.format)})`
          }
        }
      },
      scales: {
        x: {
          title: { display: !!opts.xLabel, text: opts.xLabel ?? '' },
          ticks: { callback: v => formatValue(v, opts.format) }
        },
        y: {
          title: { display: !!opts.yLabel, text: opts.yLabel ?? '' },
          ticks: { callback: v => formatValue(v, opts.format) }
        }
      }
    }
  });
}
```

**Bubble chart** — add a `r` property to each point for radius:

```javascript
// Point format: { x, y, r }   where r is the bubble radius in pixels
datasets: [{ type: 'bubble', data: [{ x: 10, y: 20, r: 12 }, ...] }]
```

---

## Stacked Bar Chart

Best for: composition that also changes over time (absolute values + relative split visible simultaneously).

```javascript
/**
 * @param {string} canvasId
 * @param {string[]} labels
 * @param {Array<{label, data}>} datasets
 * @param {{ format?, percentage? }} [opts]  - percentage: true normalizes to 100%
 */
function createStackedBarChart(canvasId, labels, datasets, opts = {}) {
  const canvas = document.getElementById(canvasId);
  const existing = Chart.getChart(canvas);
  if (existing) existing.destroy();

  return new Chart(canvas, {
    type: 'bar',
    data: {
      labels,
      datasets: datasets.map((ds, i) => ({
        label: ds.label,
        data: ds.data,
        backgroundColor: COLORS[i % COLORS.length] + 'CC',
        borderColor: COLORS[i % COLORS.length],
        borderWidth: 1,
      }))
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        x: { stacked: true },
        y: {
          stacked: true,
          max: opts.percentage ? 100 : undefined,
          ticks: {
            callback: v => opts.percentage ? `${v}%` : formatValue(v, opts.format)
          }
        }
      },
      plugins: {
        tooltip: {
          callbacks: {
            label: ctx => `${ctx.dataset.label}: ${formatValue(ctx.parsed.y, opts.format)}`
          }
        }
      }
    }
  });
}
```

---

## Mixed Bar + Line Chart

Best for: overlaying a rate (line) on a volume (bar), e.g., revenue bars + margin% line.

```javascript
data: {
  labels,
  datasets: [
    { type: 'bar',  label: 'Revenue',  data: revenueData,
      backgroundColor: COLORS[0] + 'CC', yAxisID: 'y' },
    { type: 'line', label: 'Margin %', data: marginData,
      borderColor: COLORS[1], backgroundColor: 'transparent',
      borderWidth: 2, yAxisID: 'y2' }
  ]
},
options: {
  scales: {
    y:  { position: 'left',  ticks: { callback: v => formatValue(v, 'currency') } },
    y2: { position: 'right', grid: { drawOnChartArea: false },
          ticks: { callback: v => `${v}%` } }
  }
}
```

----

Copyright 2026 The MathWorks, Inc.

----
