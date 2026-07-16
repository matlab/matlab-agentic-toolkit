# Communication Patterns

Four patterns for bridging MATLAB and JavaScript. Choose based on data flow direction and timing.

---

## Pattern 1: MATLAB to JS via Data Property

Set `h.Data` in MATLAB; listen for `DataChanged` in JavaScript. Best for initial state and MATLAB-side state changes.

**MATLAB:**
```matlab
% Send a simple value
h.Data = 42;

% Send structured data (auto-converted to JSON)
h.Data = struct('temperature', 98.6, 'unit', 'F', 'timestamp', char(datetime('now')));
```

**JavaScript:**
```javascript
// Inside setup()
htmlComponent.addEventListener('DataChanged', function(event) {
    const data = htmlComponent.Data;
    // data.temperature -> 98.6
    // data.unit -> "F"
    updateUI(data);
});
```

**Limitation:** Only one Data property exists per component. Each assignment overwrites the previous value. For multiple independent data channels, use Pattern 3.

---

## Pattern 2: JS to MATLAB via Events

Call `sendEventToMATLAB()` from JavaScript; handle in `HTMLEventReceivedFcn`. Best for user actions that trigger MATLAB computation.

**JavaScript:**
```javascript
htmlComponent.sendEventToMATLAB('updatePlot', {
    frequency: 2.5,
    amplitude: 1.0,
    plotType: 'sine'
});
```

**MATLAB:**
```matlab
function handleEvent(src, event)
    try
        switch event.HTMLEventName
            case 'updatePlot'
                freq = event.HTMLEventData.frequency;
                amp  = event.HTMLEventData.amplitude;
                type = char(event.HTMLEventData.plotType);
                generatePlot(freq, amp, type);
                sendEventToHTMLSource(src, 'plotUpdated', 'ok');
        end
    catch ME
        sendEventToHTMLSource(src, 'error', ME.message);
    end
end
```

---

## Pattern 3: MATLAB to JS via Custom Events

Call `sendEventToHTMLSource()` from MATLAB; listen with `addEventListener()` in JavaScript. Best for returning results, status updates, or multiple independent data channels.

**MATLAB:**
```matlab
sendEventToHTMLSource(h, 'resultReady', struct('value', 42, 'status', 'ok'));
sendEventToHTMLSource(h, 'progress',    struct('percent', 75, 'message', 'Processing...'));
sendEventToHTMLSource(h, 'error',       'Division by zero');
```

**JavaScript:**
```javascript
// Inside setup()
htmlComponent.addEventListener('resultReady', function(event) {
    document.getElementById('output').textContent = event.Data.value;
});

htmlComponent.addEventListener('progress', function(event) {
    updateProgressBar(event.Data.percent, event.Data.message);
});

htmlComponent.addEventListener('error', function(event) {
    showError(event.Data);
});
```

---

## Pattern 4: Request-Response Cycle (Default)

Combines Patterns 2 and 3 into a full round trip. Use this as the default for most uihtml apps.

```
User action → JS sends event → MATLAB processes → MATLAB sends result → JS updates UI
```

**JavaScript:**
```javascript
function onActionClick() {
    showLoading(true);
    window.htmlComponent.sendEventToMATLAB('calculate', {
        input: document.getElementById('inputField').value
    });
}

// Inside setup()
htmlComponent.addEventListener('result', function(event) {
    showLoading(false);
    document.getElementById('output').textContent = event.Data;
});

htmlComponent.addEventListener('error', function(event) {
    showLoading(false);
    showError(event.Data);
});
```

**MATLAB:**
```matlab
function handleEvent(src, event)
    try
        switch event.HTMLEventName
            case 'calculate'
                result = doComputation(event.HTMLEventData);
                sendEventToHTMLSource(src, 'result', result);
        end
    catch ME
        sendEventToHTMLSource(src, 'error', ME.message);
    end
end
```

---

## Pattern Summary

| Pattern | Direction | API | Best for |
|---|---|---|---|
| 1. Data property | MATLAB → JS | `h.Data` / `DataChanged` | Initial state, single data channel |
| 2. JS→MATLAB events | JS → MATLAB | `sendEventToMATLAB` / `HTMLEventReceivedFcn` | User actions, triggering MATLAB work |
| 3. Custom events | MATLAB → JS | `sendEventToHTMLSource` / `addEventListener` | Results, progress, multiple channels |
| 4. Request-response | JS → MATLAB → JS | Patterns 2 + 3 combined | Default for most apps |

----

Copyright 2026 The MathWorks, Inc.

----
