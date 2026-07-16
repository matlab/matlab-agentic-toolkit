# uihtml Bridge Integration

Wiring Chart.js charts to data from the MATLAB `uihtml` component. For the full bridge API (setup, events, serialization, error handling) see the `matlab-uihtml` skill. This guide covers only the chart side — how to receive data and drive chart updates.

---

## Key Constraint: No CDN in uihtml

uihtml cannot reach external URLs. Chart.js **must** be a local file in the same folder or a subfolder:

```
myApp/
├── app.m
├── app.html
└── lib/
    └── chart.umd.min.js    ← downloaded locally
```

Reference in HTML:
```html
<script src="./lib/chart.umd.min.js"></script>
```

Download once: `https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.min.js`

---

## Pattern 1: Data Property (Push on Load)

MATLAB pushes the full dataset into `h.Data` before or after the component loads. Best for data that changes infrequently — set it once and display it.

**MATLAB:**
```matlab
h.Data = struct( ...
    'labels', {{ 'Jan', 'Feb', 'Mar' }}, ...
    'values', [42, 67, 55] ...
);
```

**JavaScript** (inside `setup()`):

```javascript
function setup(htmlComponent) {
  window.htmlComponent = htmlComponent;

  // Handle initial data if already set when setup() fires
  if (htmlComponent.Data && htmlComponent.Data.labels) {
    renderChart(htmlComponent.Data);
  }

  // React to subsequent Data changes
  htmlComponent.addEventListener('DataChanged', () => {
    renderChart(htmlComponent.Data);
  });
}

let chart = null;

function renderChart(data) {
  const canvas = document.getElementById('myChart');
  const existing = Chart.getChart(canvas);
  if (existing) {
    // Update in place — no flash
    existing.data.labels = data.labels;
    existing.data.datasets[0].data = data.values;
    existing.update('none');
  } else {
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Value',
          data: data.values,
          backgroundColor: COLORS.map(c => c + 'CC'),
        }]
      },
      options: { responsive: true, maintainAspectRatio: false }
    });
  }
}
```

---

## Pattern 2: Event-Driven (Request-Response)

JS sends a user action to MATLAB; MATLAB computes and sends back chart data via a custom event. Best for apps where the user triggers computation (parameter sweep, filter, recalculate).

**JavaScript:**
```javascript
function setup(htmlComponent) {
  window.htmlComponent = htmlComponent;

  htmlComponent.addEventListener('chartData', event => {
    renderChart(event.Data);   // same renderChart from Pattern 1
  });

  htmlComponent.addEventListener('error', event => {
    showError(event.Data);
  });
}

function requestUpdate(params) {
  window.htmlComponent.sendEventToMATLAB('compute', params);
  showLoading(true);
}
```

**MATLAB:**
```matlab
function handleEvent(src, event)
  try
    switch event.HTMLEventName
      case 'compute'
        params = event.HTMLEventData;
        result = runComputation(params);
        payload = struct( ...
            'labels', {{ result.labels }}, ...
            'values', result.values ...
        );
        sendEventToHTMLSource(src, 'chartData', payload);
    end
  catch ME
    sendEventToHTMLSource(src, 'error', ME.message);
  end
end
```

---

## Serialization Cheat Sheet

Chart.js expects plain JS arrays and numbers. MATLAB sends structs and arrays. Notes on what arrives cleanly:

| MATLAB type | Arrives in JS as | Chart.js compatible? |
|---|---|---|
| `double` scalar | `number` | Yes |
| `double` vector (row or col) | `number[]` | Yes — use directly as `data` |
| `double` matrix | `number[][]` | Yes — index into rows |
| `char` / `string` scalar | `string` | Yes — use as label |
| `cellstr` | `string[]` | Yes — use as `labels` |
| `struct` | `object` | Yes — access fields by name |
| `struct` array | `object[]` | Yes — map to labels/data |
| `table` | not transferred | Convert: `table2struct(T)` before sending |
| `datetime` | not transferred | Convert: `datestr(dt, 'yyyy-mm-dd')` or use POSIX seconds |

For time axes, send POSIX timestamps (seconds since epoch) and convert in JS:

```matlab
% MATLAB
timestamps = posixtime(datetimeArray);   % seconds since epoch
```

```javascript
// JS — convert to milliseconds for Chart.js time scale
const labels = data.timestamps.map(t => new Date(t * 1000));
```

---

## Complete uihtml Chart App (Minimal)

**app.m:**
```matlab
function app()
  fig = uifigure('Name', 'Chart App', 'Position', [100 100 700 500]);
  gl  = uigridlayout(fig, [1 1]);
  gl.Padding = [0 0 0 0];

  h = uihtml(gl);
  h.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'app.html');
  h.HTMLEventReceivedFcn = @(src, ev) handleEvent(src, ev);

  % Push initial data
  t = linspace(0, 2*pi, 50);
  h.Data = struct( ...
      'labels', {{num2cell(round(t, 2))}}, ...
      'values', num2cell(sin(t)) ...
  );
end

function handleEvent(src, event)
  try
    switch event.HTMLEventName
      case 'updateFreq'
        freq = event.HTMLEventData.freq;
        t = linspace(0, 2*pi, 50);
        sendEventToHTMLSource(src, 'chartData', struct( ...
            'labels', {{num2cell(round(t, 2))}}, ...
            'values', num2cell(sin(freq * t)) ...
        ));
    end
  catch ME
    sendEventToHTMLSource(src, 'error', ME.message);
  end
end
```

**app.html:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <script src="./lib/chart.umd.min.js"></script>
  <style>
    *, *::before, *::after { box-sizing: border-box; }
    body { margin: 0; padding: 12px; font-family: system-ui, sans-serif; }
    .chart-wrap { height: calc(100vh - 60px); }
    .controls { display: flex; gap: 12px; align-items: center; margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="controls">
    <label>Frequency: <input type="range" id="freq" min="1" max="5" value="1" step="0.5"></label>
    <span id="freqLabel">1</span>
  </div>
  <div class="chart-wrap">
    <canvas id="myChart"></canvas>
  </div>

  <script>
    const COLORS = ['#0072BD','#D95319','#EDB120','#7E2F8E','#77AC30','#4DBEEE','#A2142F'];
    let chart = null;

    function setup(htmlComponent) {
      window.htmlComponent = htmlComponent;

      htmlComponent.addEventListener('DataChanged', () => {
        renderChart(htmlComponent.Data);
      });

      htmlComponent.addEventListener('chartData', event => {
        renderChart(event.Data);
      });

      if (htmlComponent.Data) renderChart(htmlComponent.Data);

      document.getElementById('freq').addEventListener('input', e => {
        document.getElementById('freqLabel').textContent = e.target.value;
        window.htmlComponent.sendEventToMATLAB('updateFreq', { freq: +e.target.value });
      });
    }

    function renderChart(data) {
      const canvas = document.getElementById('myChart');
      if (chart) {
        chart.data.labels = data.labels;
        chart.data.datasets[0].data = data.values;
        chart.update('none');
      } else {
        chart = new Chart(canvas, {
          type: 'line',
          data: {
            labels: data.labels,
            datasets: [{
              label: 'sin(f·t)',
              data: data.values,
              borderColor: COLORS[0],
              backgroundColor: COLORS[0] + '20',
              borderWidth: 2,
              tension: 0.3,
              pointRadius: 0,
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: false,
          }
        });
      }
    }
  </script>
</body>
</html>
```

----

Copyright 2026 The MathWorks, Inc.

----
