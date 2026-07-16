# Chart Performance

Large datasets cause slow initial renders and sluggish filter responses. Apply the strategies below before building — retrofitting is harder.

---

## Data Size Limits

| Data size | Strategy |
|---|---|
| < 1,000 rows | Embed raw data. Full client-side filtering and aggregation. |
| 1,000 – 10,000 rows | Embed raw data. Pre-aggregate for charts; filter table server-side or paginate client-side. |
| 10,000 – 100,000 rows | Pre-aggregate in MATLAB before sending. Send only the aggregated view (e.g., 12 monthly totals, not 50,000 transactions). |
| > 100,000 rows | Do not embed. Request paginated summaries from MATLAB via events, or use a BI tool. |

Chart-specific limits regardless of row count:

| Chart type | Max recommended data points |
|---|---|
| Line (per series) | 500 points. Downsample or bin if more. |
| Bar | 50 categories. Group into "Other" beyond this. |
| Scatter | 1,000 points. Use hexbin or density map for more. |
| Doughnut / pie | 6 segments. Collapse remainder into "Other". |

---

## Pre-Aggregation in MATLAB

Aggregate before sending — never send raw rows when a chart only needs summaries:

```matlab
% DON'T: send 50,000 transactions and aggregate in JS
h.Data = struct('transactions', transactions);  % huge

% DO: aggregate in MATLAB, send compact result
monthly = groupsummary(T, 'month', {'sum', 'mean'}, {'revenue', 'units'});
h.Data = struct( ...
    'labels',   {{monthly.month}}, ...
    'revenue',  num2cell(monthly.sum_revenue), ...
    'units',    num2cell(monthly.sum_units), ...
    'avgRevenue', num2cell(monthly.mean_revenue) ...
);
```

The transfer overhead is proportional to data size. A 50,000-row table transferred as JSON can stall the UI for several seconds; 12 aggregated rows is invisible.

---

## Downsampling for Line Charts

For time series with more points than pixels, downsample before plotting:

```javascript
/**
 * Thin an array to at most maxPoints by evenly spaced sampling.
 * @param {any[]} arr
 * @param {number} maxPoints
 */
function downsample(arr, maxPoints) {
  if (arr.length <= maxPoints) return arr;
  const step = arr.length / maxPoints;
  return Array.from({ length: maxPoints }, (_, i) => arr[Math.round(i * step)]);
}

// Usage: thin labels and values together
const step = Math.max(1, Math.floor(rawLabels.length / 400));
const labels = rawLabels.filter((_, i) => i % step === 0);
const values = rawValues.filter((_, i) => i % step === 0);
```

A 5,000-point time series on a 500px-wide canvas has 10 data points per pixel — downsampling to 500 points loses no visible information.

---

## Animation Flags

Animation costs CPU on every update and makes charts feel slow in dashboards.

**Disable globally** (all charts, all updates):
```javascript
Chart.defaults.animation = false;
```

**Disable per chart:**
```javascript
options: {
  animation: false,
  // or: animations: { colors: false, x: false }
}
```

**Disable for updates only** (keep entrance animation, skip filter refreshes):
```javascript
chart.update('none');   // skips animation for this call only
```

---

## DOM Performance

**Tables:** Rendering a 10,000-row table blocks the main thread. Paginate:

```javascript
function renderTablePage(data, page, pageSize = 50) {
  const start = page * pageSize;
  const slice = data.slice(start, start + pageSize);
  // render only `slice`; show "Showing 1–50 of 2,340" footer
}
```

**Avoid full DOM rebuild on filter change.** Update only changed values:
- Chart data: mutate `chart.data.*` + `chart.update('none')`
- KPI cards: set `element.textContent = newValue` directly
- Tables: re-render only the visible page

**Batch coordinated updates** to one animation frame:

```javascript
function refreshAll(filtered) {
  // All data mutations first
  updateChartData(lineChart, filtered);
  updateChartData(barChart, filtered);
  updateKPIs(filtered);

  // Single paint
  requestAnimationFrame(() => {
    lineChart.update('none');
    barChart.update('none');
  });
}
```

---

## Lazy-Load Strategy for uihtml

For apps with multiple chart tabs, defer chart creation until the tab is visible to avoid rendering off-screen canvases:

```javascript
const chartInstances = {};

function showTab(tabId) {
  document.querySelectorAll('.tab-panel').forEach(p => p.hidden = true);
  document.getElementById(tabId).hidden = false;

  if (!chartInstances[tabId]) {
    chartInstances[tabId] = createChartForTab(tabId, currentData);
  } else {
    // If data may have changed while tab was hidden, refresh
    updateChartForTab(chartInstances[tabId], currentData);
  }
}
```

---

## Transfer Overhead Reference

| Payload | Approx. transfer size | Notes |
|---|---|---|
| 12 monthly aggregates | ~500 bytes | Instant |
| 1,000 rows × 5 fields | ~50 KB | Fast |
| 10,000 rows × 5 fields | ~500 KB | Noticeable on first load |
| 50,000 rows × 5 fields | ~2.5 MB | Blocks UI — pre-aggregate instead |

uihtml transfers data through MATLAB's internal IPC channel. The bottleneck is serialization, not network. Rule of thumb: stay under 200 KB per transfer for a responsive feel.

----

Copyright 2026 The MathWorks, Inc.

----
