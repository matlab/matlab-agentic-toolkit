# UIHTML Builder

Wire up bidirectional communication between a MATLAB backend and a JavaScript frontend using the `uihtml` component. This skill covers the bridge layer — how data and events flow between the two sides.

See the References section below for detailed patterns on each topic.

## Critical Rules

- MUST use the `setup(htmlComponent)` function pattern in JavaScript — this is how uihtml passes the component reference
- MUST wrap all MATLAB event handlers in try-catch blocks and send errors back to JS
- MUST validate all data received from JavaScript before processing in MATLAB
- NEVER use string-based code evaluation on JavaScript-provided input without strict character validation
- ALWAYS use `fullfile()` for HTML source paths — never hardcode path separators
- ALWAYS register JS event listeners inside `setup()` — the htmlComponent reference is not available before this call
- NEVER use `DOMContentLoaded` to bind event listeners — `setup()` is the only reliable initialization hook in uihtml
- NEVER link to CDN resources — uihtml cannot access external URLs; save all JS/CSS libraries locally
- ALL supporting files (JS, CSS, assets) MUST be in the same folder as the HTML file or a subfolder of it

## Core Architecture

```
+----------------------------------+     +-----------------------------------+
|         MATLAB Side              |     |        JavaScript Side            |
|                                  |     |                                   |
|  uifigure                        |     |  HTML document                    |
|   +-- uihtml component (h)      |<--->|   +-- setup(htmlComponent)        |
|        |-- h.HTMLSource          |     |        |-- htmlComponent.Data     |
|        |-- h.Data               -|---->|        |-- DataChanged listener   |
|        |-- h.HTMLEventReceivedFcn|<----|        |-- sendEventToMATLAB()   |
|        +-- sendEventToHTMLSource()---->|        +-- custom event listeners |
+----------------------------------+     +-----------------------------------+
```

## Quick Start

Use `assets/minimal-bridge.m` and `assets/minimal-bridge.html` as a copy-paste starting point. The pattern below is Pattern 4 (request-response) — the default for most apps.

**app.m:**
```matlab
function app()
    fig = uifigure('Name', 'My App');
    gl = uigridlayout(fig, [1 1]);
    gl.Padding = [0 0 0 0];

    h = uihtml(gl);
    h.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'app.html');
    h.HTMLEventReceivedFcn = @(src, event) handleEvent(src, event);
end

function handleEvent(src, event)
    try
        switch event.HTMLEventName
            case 'MyAction'
                result = process(event.HTMLEventData);
                sendEventToHTMLSource(src, 'Result', result);
        end
    catch ME
        sendEventToHTMLSource(src, 'Error', ME.message);
    end
end
```

**app.html (script block):**
```javascript
function setup(htmlComponent) {
    window.htmlComponent = htmlComponent;

    htmlComponent.addEventListener('Result', function(event) {
        displayResult(event.Data);
    });

    htmlComponent.addEventListener('Error', function(event) {
        console.error('MATLAB error:', event.Data);
    });
}

function sendAction(data) {
    window.htmlComponent.sendEventToMATLAB('MyAction', data);
}
```

## Implementation Checklist

- [ ] MATLAB: uifigure created with uihtml component
- [ ] MATLAB: `HTMLSource` set using `fullfile(fileparts(mfilename('fullpath')), ...)`
- [ ] MATLAB: `HTMLEventReceivedFcn` callback assigned
- [ ] MATLAB: All event handlers wrapped in try-catch
- [ ] MATLAB: Errors sent back to JS via `sendEventToHTMLSource`
- [ ] MATLAB: Input from JS validated before processing
- [ ] MATLAB: Unsupported types (table, datetime) converted before sending
- [ ] JS: `setup(htmlComponent)` function defined in global scope
- [ ] JS: htmlComponent reference stored on `window` for use in other functions
- [ ] JS: `DataChanged` listener registered if using Data property
- [ ] JS: Custom event listeners registered for all MATLAB-to-JS events
- [ ] JS: Error event listener registered to display MATLAB errors
- [ ] JS: Loading/feedback shown during MATLAB computation
- [ ] Files: HTML file exists at the path referenced by `HTMLSource`
- [ ] Files: All JS, CSS, fonts, and assets are local — no CDN or external URLs
- [ ] Files: All supporting files are in the HTML file's folder or a subfolder
- [ ] Files: Project follows standard file organization

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| HTML file not loading | Incorrect path | Use `fullfile(fileparts(mfilename('fullpath')), 'app.html')` |
| JS library not loading / blank UI | CDN URL blocked | Download library locally; reference with a relative path |
| Supporting file 404 | File outside HTML file's folder | Move all JS, CSS, and assets into the HTML file's folder or a subfolder |
| Events not reaching MATLAB | Callback not set | Ensure `HTMLEventReceivedFcn` is assigned before HTML loads |
| `setup()` not called | Function missing or misnamed | Must be global, named exactly `setup`, with one argument |
| Data property empty in JS | Listener registered too late | Register `DataChanged` listener inside `setup()` |
| MATLAB errors silent in UI | No error handling on JS side | Add `Error` event listener in `setup()` |
| Struct fields missing in JS | Field name casing | MATLAB field names are case-sensitive; match exactly in JS |
| Cell arrays garbled | Nested/heterogeneous cells | Use struct arrays instead; avoid nested cell arrays |
| Table data will not transfer | table type unsupported | Convert with `table2struct(T)` before sending |
| Slow with large data | Too much data per transfer | Paginate: send summary first, then pages on request |
| Multiple Data assignments collide | Single Data property shared | Use custom events for independent data channels |
| Code changes not taking effect | Webview caches external JS/CSS | Add a query string to file references: `app.js?v=2`; increment on each change |

## Development Tips

During iterative development, append a cache-busting query string to `<script>` and `<link>` tags (e.g., `app.js?v=1`, `styles.css?v=1`). Increment the version each time you modify the file. The uihtml webview aggressively caches external resources and `close all force` does not clear this cache.

## References

| Topic | File | Description |
|-------|------|-------------|
| Communication patterns | `communication-patterns.md` | All 4 patterns: Data property, JS→MATLAB, MATLAB→JS, request-response |
| Data types | `data-types.md` | Type conversion table, serialization rules, large data pagination |
| Platform limitations | `platform-limitations.md` | Hard constraints, file organization, local resource requirements |
| Setup guide | `setup.md` | MATLAB uihtml creation, JS setup() function, hybrid layouts |
| Error handling | `error-handling.md` | MATLAB try-catch, JS error listener, input validation at boundary |

----

Copyright 2026 The MathWorks, Inc.

----
