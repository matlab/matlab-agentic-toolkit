# Chart Updates

Updating an existing chart is always faster than destroying and recreating it. Recreate only when the chart type or dataset structure changes fundamentally.

---

## The Core Update Pattern

```javascript
/**
 * Update labels and data on an existing chart.
 * @param {Chart} chart         - stored Chart.js instance
 * @param {string[]} newLabels
 * @param {number[]|number[][]} newData  - single array for 1 dataset; nested for multiple
 */
function updateChart(chart, newLabels, newData) {
  chart.data.labels = newLabels;

  if (Array.isArray(newData[0])) {
    // Multiple datasets
    newData.forEach((data, i) => {
      chart.data.datasets[i].data = data;
    });
  } else {
    chart.data.datasets[0].data = newData;
  }

  chart.update('none');  // skip animation — instant update
}
```

**`chart.update('none')`** — the `'none'` mode disables animation for this update cycle only. Use it for all filter-driven or data-driven refreshes so the chart feels immediate. Use `chart.update()` (no arg) only for intentional animated transitions.

---

## Filter-Driven Update Pattern

The standard flow for dashboards with filter controls:

```javascript
// 1. Store chart references at module scope
let lineChart, barChart, donutChart;

function init(rawData) {
  lineChart  = createLineChart('line-canvas', /* ... */);
  barChart   = createBarChart('bar-canvas', /* ... */);
  donutChart = createDoughnutChart('donut-canvas', /* ... */);
}

// 2. Apply filters → derive new data → push to charts
function applyFilters(rawData) {
  const region   = document.getElementById('filter-region').value;
  const category = document.getElementById('filter-category').value;

  const filtered = rawData.filter(row => {
    if (region   !== 'all' && row.region   !== region)   return false;
    if (category !== 'all' && row.category !== category) return false;
    return true;
  });

  const { labels, values } = aggregateByMonth(filtered);
  updateChart(lineChart, labels, values);

  const { catLabels, catValues } = aggregateByCategory(filtered);
  updateChart(barChart, catLabels, catValues);

  // Doughnut: update dataset directly, no label change needed
  donutChart.data.datasets[0].data = computeShares(filtered);
  donutChart.update('none');
}
```

Wire to filter controls:

```html
<select id="filter-region" onchange="applyFilters(rawData)">
  <option value="all">All Regions</option>
</select>
```

---

## Adding or Removing Datasets

To add a new series to a chart at runtime:

```javascript
chart.data.datasets.push({
  label: 'New Series',
  data: newData,
  borderColor: COLORS[chart.data.datasets.length % COLORS.length],
  backgroundColor: 'transparent',
  borderWidth: 2,
});
chart.update('none');
```

To remove a dataset by index:

```javascript
chart.data.datasets.splice(indexToRemove, 1);
chart.update('none');
```

---

## Destroy and Recreate

Use when:
- Switching between chart types (line → bar)
- Changing from single-dataset to multi-dataset with different structure
- Resetting to a completely different data schema

```javascript
function switchChartType(canvasId, type, labels, datasets) {
  const canvas = document.getElementById(canvasId);
  const existing = Chart.getChart(canvas);
  if (existing) existing.destroy();

  return new Chart(canvas, {
    type,
    data: { labels, datasets },
    options: { responsive: true, maintainAspectRatio: false }
  });
}
```

**Avoid destroy/recreate for routine data updates** — it causes a visual flash and is slower.

---

## Coordinated Multi-Chart Updates

When multiple charts update together (e.g. after a filter), batch the data mutations before any `update()` call to keep the browser frame budget tight:

```javascript
function refreshAll(filtered) {
  // Mutate data on all chart instances first
  lineChart.data.labels = getLabels(filtered);
  lineChart.data.datasets[0].data = getValues(filtered);

  barChart.data.labels = getCategories(filtered);
  barChart.data.datasets[0].data = getCategoryValues(filtered);

  // Then flush all at once on next frame
  requestAnimationFrame(() => {
    lineChart.update('none');
    barChart.update('none');
  });
}
```

---

## Troubleshooting Update Issues

| Issue | Cause | Fix |
|---|---|---|
| Old data briefly visible after update | Animation enabled | Use `chart.update('none')` |
| Update throws "cannot read property" | Chart was destroyed | Check `Chart.getChart(canvas)` before updating |
| Labels updated but chart unchanged | Forgot to call `chart.update()` | Call after all mutations |
| Multi-dataset update only changes first | Nested `newData[0]` check fails | Ensure outer check: `Array.isArray(newData[0])` |
| Chart blank after filter change | All data filtered out | Handle empty array: show placeholder message |

----

Copyright 2026 The MathWorks, Inc.

----
