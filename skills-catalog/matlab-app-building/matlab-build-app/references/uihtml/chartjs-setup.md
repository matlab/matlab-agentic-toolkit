# Chart.js Setup

---

## Script Tag: Standalone vs uihtml

**Standalone web app    — CDN is fine:**

```html
<!-- Chart.js UMD bundle — provides global `Chart` -->
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.min.js"
        integrity="sha384-jb8JQMbMoBUzgWatfe6COACi2ljcDdZQ2OxczGA3bGNeWe+6DChMTBJemed7ZnvJ"
        crossorigin="anonymous"></script>

<!-- Date adapter — add ONLY if using a time scale axis -->
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns@3.0.0/dist/chartjs-adapter-date-fns.bundle.min.js"
        crossorigin="anonymous"></script>
```

**uihtml app (UIHTML app) — CDN is blocked; use a local file:**

```html
<!-- Download chart.umd.min.js and place in the same folder or a lib/ subfolder -->
<script src="./lib/chart.umd.min.js"></script>
```

Download URL (for user to fetch manually or via curl):
`https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.min.js`

> The UMD bundle (`chart.umd.min.js`) exposes `Chart` as a global — no `import` required. Do NOT use the ESM build in a script-tag context.

---

## Canvas Pattern

Chart.js reads its height from the **container div**, not the canvas element. Always wrap:

```html
<!-- Container controls the size; canvas fills it -->
<div class="chart-wrap">
  <canvas id="myChart"></canvas>
</div>
```

```css
.chart-wrap {
  position: relative;   /* required by Chart.js for responsive sizing */
  height: 300px;        /* set height here, not on the canvas */
  width: 100%;
}
```

In uihtml, height is typically a percentage of the component: use `height: 100%` on the outermost layout element and let inner chart wraps use `flex: 1` or a fixed pixel height.

---

## Chart.js v4 Initialization

All charts share the same constructor signature:

```javascript
const chart = new Chart(canvasElement, {
  type: 'bar',          // 'line' | 'bar' | 'scatter' | 'doughnut' | 'bubble' | 'radar'
  data: { labels, datasets },
  options: {
    responsive: true,
    maintainAspectRatio: false,   // REQUIRED in uihtml; lets container control aspect ratio
    // ... plugin and scale options
  }
});
```

Pass `canvasElement` (not the 2D context). Chart.js v4 acquires the context internally.

---

## Colors

Use the MATLAB default colororder so charts feel native to MATLAB users:

```javascript
const COLORS = [
  '#0072BD',  // graphics-1 blue
  '#D95319',  // graphics-2 red-orange
  '#EDB120',  // graphics-3 yellow
  '#7E2F8E',  // graphics-4 purple
  '#77AC30',  // graphics-5 green
  '#4DBEEE',  // graphics-6 cyan
  '#A2142F',  // graphics-7 dark red
];

// Solid fill for line markers and borders:
const color = COLORS[i % COLORS.length];

// Semi-transparent fill for bar backgrounds:
const fillColor = COLORS[i % COLORS.length] + 'CC';  // CC = 80% opacity
```

If using CSS custom properties for chart colors (e.g., `--c-graphics-1` through `--c-graphics-7`), read them into JS:

```javascript
const style = getComputedStyle(document.documentElement);
const COLORS = Array.from({ length: 7 }, (_, i) =>
  style.getPropertyValue(`--c-graphics-${i + 1}`).trim()
);
```

---

## Global Defaults (Optional)

Set once before creating any charts to avoid repeating options on every instance:

```javascript
Chart.defaults.font.family = 'system-ui, -apple-system, sans-serif';
Chart.defaults.font.size = 13;
Chart.defaults.color = '#666666';           // axis label color
Chart.defaults.borderColor = '#e0e0e0';    // grid line color
Chart.defaults.animation = false;           // disable globally for dashboards
```

---

## Required: Destroy Before Recreate

If chart code runs on a canvas that may already have a chart (e.g. inside a function called multiple times), always destroy first:

```javascript
function renderChart(canvasId, data) {
  const canvas = document.getElementById(canvasId);
  const existing = Chart.getChart(canvas);
  if (existing) existing.destroy();

  return new Chart(canvas, { /* ... */ });
}
```

`Chart.getChart(element)` returns the existing instance or `undefined` — safer than keeping a manual reference.

----

Copyright 2026 The MathWorks, Inc.

----
