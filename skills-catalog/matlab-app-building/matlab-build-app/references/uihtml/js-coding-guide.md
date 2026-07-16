# JavaScript Coding Patterns

Write clean, maintainable JavaScript for web frontends used in MATLAB uihtml apps or standalone web applications. This skill covers JS coding practices — modules, error handling, performance, testing, and debugging.

## Critical Rules

- MUST use build-free vanilla JavaScript — no bundlers, transpilers, or npm unless the user explicitly requires them
- MUST use ES modules (`import`/`export`) for multi-file projects; inline `<script>` for single-file apps
- MUST handle errors at async boundaries and bridge callbacks — unhandled errors break the communication chain silently
- NEVER use mutable global variables (`var` or top-level `let`) except `window.htmlComponent` (required by uihtml bridge). Top-level `const` declarations for configuration, DOM references, and utility functions are acceptable.
- NEVER rely on `this` binding in event callbacks — use arrow functions or explicit references
- ALWAYS use `const` by default; `let` only when reassignment is needed; never `var`

## Module Structure

### Single-File App (Inline Script)

For simple uihtml apps, keep JS inline in the HTML file:

```html
<script>
    // All code in a single script block
    function setup(htmlComponent) {
        window.htmlComponent = htmlComponent;
        // ... setup listeners
    }

    function handleUserAction() {
        // ... event handling
    }
</script>
```

Use this when: the app has fewer than ~200 lines of JS.

### Multi-File App (ES Modules)

For complex apps, split into modules:

```
web/
+-- index.html          % Entry point, imports app.js
+-- app.js              % Main module, setup() and orchestration
+-- models/
|   +-- data-model.js   % Data and business logic
+-- viewmodels/
|   +-- main-viewmodel.js
|   +-- observable.js   % Observable/Computed classes
+-- views/
|   +-- main-view.js    % DOM creation and binding
+-- utils/
    +-- formatting.js   % Shared utility functions
```

Entry point with ES modules:

```html
<script type="module">
    import { initApp } from './app.js';

    // setup() must be a global function for uihtml
    window.setup = function(htmlComponent) {
        initApp(htmlComponent);
    };
</script>
```

**Important:** The `setup()` function must be on `window` (global) for uihtml to call it. When using ES modules, explicitly assign it to `window.setup`.

## Error Handling

### Bridge Callback Errors

Always wrap code that runs in response to MATLAB events:

```javascript
htmlComponent.addEventListener("ResultReady", function(event) {
    try {
        const result = event.Data;
        updateDisplay(result);
    } catch (err) {
        console.error("Error handling ResultReady:", err);
        showUserError("Failed to display result");
    }
});
```

### User Input Validation

Validate before sending to MATLAB — catch errors early on the JS side:

```javascript
function onSubmit() {
    const frequency = parseFloat(document.getElementById("freq").value);
    const amplitude = parseFloat(document.getElementById("amp").value);

    if (isNaN(frequency) || frequency <= 0) {
        showUserError("Frequency must be a positive number");
        return;
    }

    if (isNaN(amplitude) || amplitude <= 0) {
        showUserError("Amplitude must be a positive number");
        return;
    }

    htmlComponent.sendEventToMATLAB("UpdatePlot", { frequency, amplitude });
}
```

### Displaying Errors to the User

Provide a consistent error display function used across the app:

```javascript
function showUserError(message) {
    const el = document.getElementById("status");
    el.textContent = message;
    el.className = "status-message error";

    // Auto-clear after 5 seconds
    setTimeout(() => {
        el.textContent = "";
        el.className = "status-message";
    }, 5000);
}

function showSuccess(message) {
    const el = document.getElementById("status");
    el.textContent = message;
    el.className = "status-message success";
}
```

## Performance

### Minimize Bridge Data Transfer

Send only what MATLAB needs — not entire objects or datasets:

```javascript
// Bad: sending unnecessary data
htmlComponent.sendEventToMATLAB("Process", { allFormFields, metadata, domState });

// Good: sending only the values MATLAB needs
htmlComponent.sendEventToMATLAB("Process", {
    frequency: parseFloat(freqInput.value),
    amplitude: parseFloat(ampInput.value),
    plotType: typeSelect.value
});
```

### Throttle Rapid Events

Sliders and mouse moves can fire dozens of events per second. Throttle before sending to MATLAB:

```javascript
function throttle(fn, delay) {
    let lastCall = 0;
    return function(...args) {
        const now = Date.now();
        if (now - lastCall >= delay) {
            lastCall = now;
            fn(...args);
        }
    };
}

// Throttle slider updates to max 10 per second
const throttledUpdate = throttle(function(value) {
    htmlComponent.sendEventToMATLAB("SliderChanged", { value });
}, 100);

slider.addEventListener("input", function() {
    throttledUpdate(parseFloat(this.value));
});
```

### Debounce Text Input

Wait for the user to stop typing before sending:

```javascript
function debounce(fn, delay) {
    let timer;
    return function(...args) {
        clearTimeout(timer);
        timer = setTimeout(() => fn(...args), delay);
    };
}

const debouncedSearch = debounce(function(query) {
    htmlComponent.sendEventToMATLAB("Search", { query });
}, 300);

searchInput.addEventListener("input", function() {
    debouncedSearch(this.value);
});
```

### Batch DOM Updates

When receiving data from MATLAB, minimize DOM operations:

```javascript
function updateTable(rows) {
    const tbody = document.getElementById("table-body");

    // Build all rows using safe DOM methods, then append once
    const fragment = document.createDocumentFragment();
    for (const row of rows) {
        const tr = document.createElement("tr");

        const tdName = document.createElement("td");
        tdName.textContent = row.name;
        tr.appendChild(tdName);

        const tdValue = document.createElement("td");
        tdValue.textContent = row.value.toFixed(2);
        tr.appendChild(tdValue);

        fragment.appendChild(tr);
    }

    tbody.replaceChildren(fragment);
}
```

For trusted data from MATLAB where performance is critical and the content is numeric/text only, template literals with `textContent` assignments are also acceptable. Avoid setting `innerHTML` with data that could contain user-generated strings.

### Loading Indicators

Show feedback during MATLAB computation — users should never wonder if the app is frozen:

```javascript
function showLoading(visible) {
    document.getElementById("loading").style.display = visible ? "flex" : "none";
}

// Usage: show before sending, hide when MATLAB responds
function requestComputation(data) {
    showLoading(true);
    htmlComponent.sendEventToMATLAB("Compute", data);
}

// In setup():
htmlComponent.addEventListener("Result", function(event) {
    showLoading(false);
    displayResult(event.Data);
});

htmlComponent.addEventListener("Error", function(event) {
    showLoading(false);
    showUserError(event.Data);
});
```

## Testing & Debugging

For testing and debugging patterns, see `js-testing-debugging.md`. Key approaches:
- Expose key objects on `window.app` for console debugging
- Simulate MATLAB events with `CustomEvent` + `dispatchEvent`
- Add debug logging that logs all bridge communication
- Test pure utility functions independently
- Use `fprintf` on MATLAB side + `console.log` on JS side to trace communication
- Follow the 5-step debugging checklist for communication failures

## Common App Patterns

### Calculator Pattern

JS builds input strings from button clicks; MATLAB evaluates safely:

```javascript
let expression = '';

function appendDigit(d) {
    expression += d;
    document.getElementById("display").value = expression;
}

function calculate() {
    showLoading(true);
    sendToMATLAB("Calculate", expression);
}

// In setup():
htmlComponent.addEventListener("Result", function(event) {
    showLoading(false);
    expression = String(event.Data);
    document.getElementById("display").value = expression;
});
```

### Form Collection Pattern

Gather form fields into a single structured event:

```javascript
function submitForm() {
    const data = {
        name: document.getElementById("name").value.trim(),
        email: document.getElementById("email").value.trim(),
        age: parseInt(document.getElementById("age").value, 10)
    };

    // Validate on JS side first
    if (!data.name) { showUserError("Name is required"); return; }
    if (!data.email.includes("@")) { showUserError("Invalid email"); return; }
    if (isNaN(data.age) || data.age < 0) { showUserError("Invalid age"); return; }

    showLoading(true);
    htmlComponent.sendEventToMATLAB("SubmitForm", data);
}
```

### Real-Time Monitoring Pattern

MATLAB pushes updates at intervals; JS renders efficiently:

```javascript
const chartBuffer = [];

// In setup():
htmlComponent.addEventListener("DataUpdate", function(event) {
    const data = event.Data;
    // Update only changed elements
    document.getElementById("value").textContent = data.value.toFixed(2);
    document.getElementById("timestamp").textContent = data.timestamp;

    // Append to chart buffer (keep last N points)
    chartBuffer.push(data.value);
    if (chartBuffer.length > 200) chartBuffer.shift();
    redrawChart(chartBuffer);
});

htmlComponent.addEventListener("MonitoringStopped", function(event) {
    document.getElementById("status").textContent = "Stopped";
});
```

## Implementation Checklist

- [ ] JS uses `const`/`let` only (no `var`)
- [ ] Single-file for simple apps; ES modules for complex apps
- [ ] `setup()` function is global (on `window` if using ES modules)
- [ ] All bridge event listeners wrapped in try-catch
- [ ] User input validated on JS side before sending to MATLAB
- [ ] Error display function implemented and used consistently
- [ ] Loading indicator shown during MATLAB computation
- [ ] Rapid events (sliders, typing) throttled or debounced
- [ ] DOM updates batched where possible
- [ ] Debug logging available (can be toggled off for production)
- [ ] Key objects exposed on `window` for console debugging during development

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `setup is not a function` | ES module scope | Assign `window.setup = function(htmlComponent) { ... }` |
| Event listener not firing | Registered outside `setup()` | Move all `addEventListener` calls inside `setup()` |
| `htmlComponent is undefined` | Accessed before `setup()` runs | Store in `window.htmlComponent` inside `setup()`, reference that |
| Slider sends too many events | No throttling | Wrap callback in `throttle(fn, 100)` |
| UI freezes during computation | No loading indicator | Show spinner before `sendEventToMATLAB`, hide on response |
| Data garbled across bridge | Wrong JS type | Check `typeof` — use `parseFloat()` for numbers, `.trim()` for strings |
| Can't debug in uihtml | No dev tools access | Add `console.log` statements; check MATLAB command window for `fprintf` |

## References

| Topic | File | Description |
|-------|------|-------------|
| Testing & debugging | `js-testing-debugging.md` | Console testing, event simulation, debug logging, MATLAB-side tracing |

----

Copyright 2026 The MathWorks, Inc.

----
