# Testing & Debugging

Testing and debugging patterns for JavaScript in MATLAB uihtml apps.

## Console-Based Testing

Test JS functions directly from the browser console (F12 in the uihtml web view):

```javascript
// Expose key objects for console debugging
window.app = { model, viewModel, view };

// Then in console:
// app.viewModel.processCommand(42)
// app.model.data
```

## Simulating MATLAB Events

Test JS event handlers without MATLAB running by dispatching synthetic events:

```javascript
// In browser console: simulate a MATLAB ResultReady event
const fakeEvent = new CustomEvent("ResultReady");
fakeEvent.Data = { value: 42, status: "ok" };
htmlComponent.dispatchEvent(fakeEvent);
```

## Debug Logging Toggle

Add a debug mode that logs all bridge communication:

```javascript
const DEBUG = true;

function sendToMATLAB(eventName, data) {
    if (DEBUG) {
        console.log("[JS -> MATLAB] " + eventName + ":", JSON.stringify(data));
    }
    htmlComponent.sendEventToMATLAB(eventName, data);
}
```

## Unit Testing Pure Functions

For logic-heavy apps, test pure functions independently:

```javascript
// utils/formatting.js
export function formatTemperature(celsius, unit) {
    if (unit === 'F') return (celsius * 9/5 + 32).toFixed(1) + ' F';
    if (unit === 'K') return (celsius + 273.15).toFixed(1) + ' K';
    return celsius.toFixed(1) + ' C';
}

// Test in console or test file:
// formatTemperature(100, 'F') === '212.0 F'
// formatTemperature(0, 'K') === '273.1 K'
```

## MATLAB Side Logging

Add `fprintf` in MATLAB to see what JS is sending:

```matlab
function handleEvent(src, event)
    fprintf('[MATLAB] Received: %s\n', event.HTMLEventName);
    fprintf('[MATLAB] Data type: %s\n', class(event.HTMLEventData));
    disp(event.HTMLEventData);
    % ... handle event
end
```

## JavaScript Side Logging

Use `console.log` to trace communication flow:

```javascript
// Inside setup()
htmlComponent.addEventListener("DataChanged", function(event) {
    console.log("[JS] DataChanged:", JSON.stringify(htmlComponent.Data));
    updateUI(htmlComponent.Data);
});
```

## Debugging Steps for Communication Failures

1. **Test MATLAB to JS first** — set `h.Data = struct('test', 123)` and check if `DataChanged` fires
2. **Test JS to MATLAB next** — call `sendEventToMATLAB` with simple string data and check `fprintf` output
3. **Check data types** — `fprintf('class: %s\n', class(event.HTMLEventData))` in MATLAB; `console.log(typeof event.Data)` in JS
4. **Verify setup() is called** — add `console.log("setup called")` as the first line of `setup()`
5. **Check for silent errors** — ensure try-catch exists on both sides

## Browser Developer Tools

Access dev tools in the uihtml embedded browser:
- **Console tab** — see JS errors and `console.log` output
- **Elements tab** — inspect and modify DOM in real time
- **Network tab** — not typically needed (no HTTP in uihtml), but useful for standalone web apps

----

Copyright 2026 The MathWorks, Inc.

----
