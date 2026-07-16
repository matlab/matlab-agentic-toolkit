# Platform Limitations

Hard constraints of the uihtml component on MATLAB Desktop.

## Limitations Table

| Limitation | Detail | Workaround |
|---|---|---|
| No CDN access | External URLs for JS/CSS/fonts are blocked | Download libraries locally; reference by relative path |
| Supporting files must be local | JS, CSS, images must be in the HTML file's folder or a subfolder | Copy all assets into the app folder before deployment |
| No content overflow | Dynamic content (pop-ups, dropdowns) cannot extend beyond the uihtml bounds | Size the uihtml component large enough to contain open widgets |
| Limited file type support | Common types (JS, CSS, PNG, SVG) work; other types may not | Use standard web file formats |
| No web plugins | Webcam, microphone, browser plugins not supported on MATLAB Desktop | — |
| No `HTMLSource` query params | Cannot append `?key=value` to the HTML file path | Pass parameters via `htmlComponent.Data` instead |
| No `matlab:` hyperlinks | `<a href="matlab:...">` is not supported | Use `sendEventToMATLAB` from a button click handler |
| Figure callbacks blocked | `WindowButtonDownFcn`, `WindowKeyPressFcn` do not fire when uihtml has focus | Handle keyboard/mouse events in the JS layer |

## File Organization

```
my-app/
+-- app.m               % MATLAB entry point: creates uifigure + uihtml
+-- app.html            % HTML/JS/CSS frontend (single-file for simple apps)
+-- helpers/            % Optional: MATLAB helper functions
|   +-- processData.m
+-- web/                % Optional: separate JS/CSS for complex apps
    +-- app.js
    +-- app.css
    +-- libs/           % Third-party JS/CSS libraries (local copies only — no CDN)
        +-- library.min.js
        +-- library.css
```

For simple apps, keep everything in a single HTML file (inline `<style>` and `<script>`). Split into separate files only when complexity warrants it.

## Using External Libraries

All external resources must be local. This applies to JavaScript libraries, CSS frameworks, fonts, images, and any other asset referenced from the HTML file.

**Download a library locally:**
```bash
# Example: download any minified JS library
curl -sL "https://example.com/library/dist/library.min.js" -o "libs/library.min.js"
```

**Reference it with a relative path:**
```html
<script src="libs/library.min.js"></script>
```

Never use CDN URLs:
```html
<!-- This will NOT work in uihtml -->
<script src="https://cdn.example.com/library.min.js"></script>
```

----

Copyright 2026 The MathWorks, Inc.

----
