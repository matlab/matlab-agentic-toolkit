# Dark Mode

Complete dark mode overrides for both generic and branded themes.

## Generic Dark Mode

Override the standard design tokens using a class on `body`. Do not use `:root.dark` — class changes on `<html>` do not trigger CSS repaints in MATLAB's embedded webview.

```css
/* Class-based toggle (controllable from JS) */
body.dark {
    --bg-primary: #1a1a1a;
    --bg-secondary: #2a2a2a;
    --bg-elevated: #333333;
    --text-primary: #e0e0e0;
    --text-secondary: #999999;
    --accent: #4dabf7;
    --accent-hover: #74c0fc;
    --accent-light: rgba(77, 171, 247, 0.15);
    --error: #ef5350;
    --success: #66bb6a;
    --border: #444444;
}
```

## Branded Dark Mode

When using `colors_and_type.css`, add this block in your own stylesheet after the asset link. Follows the rule: palette values <=500 are safe for text on dark backgrounds.

```css
body.dark {
  /* Text */
  --color-text-primary:            var(--c-gray-100);
  --color-text-secondary:          var(--c-gray-400);
  --color-text-disabled:           var(--c-gray-600);
  --color-text-hyperlink:          var(--c-blue-300);
  --color-text-hyperlink-hover:    var(--c-blue-200);

  /* Backgrounds */
  --bg-primary:       var(--c-gray-900);
  --bg-code:          var(--c-gray-850);
  --bg-secondary:     var(--c-gray-800);
  --bg-canvas:        var(--c-gray-900);

  /* Borders */
  --border-primary:           var(--c-gray-500);
  --border-secondary:         var(--c-gray-700);

  /* Selection */
  --color-selection-primary:       var(--c-blue-400);
  --color-selection-secondary:     var(--c-blue-300);
  --color-selection-tertiary:      var(--c-blue-800);

  /* Alerts */
  --color-alert-error:             var(--c-red-400);
  --color-alert-warning:           var(--c-honey-400);
  --color-alert-success:           var(--c-green-450);
  --color-alert-error-bg:          var(--c-red-900);
  --color-alert-warning-bg:        var(--c-honey-900);
  --color-alert-success-bg:        var(--c-green-900);

  /* Component overrides */
  --toolstrip-bg:           var(--c-gray-850);
  --toolstrip-border:       var(--c-gray-700);
  --toolstrip-item-hover:   var(--c-gray-800);
  --toolstrip-item-active:  var(--c-gray-750);
  --sidebar-bg:             var(--c-gray-850);
  --sidebar-border:         var(--c-gray-700);
  --input-bg:               var(--c-gray-850);
  --input-border:           var(--c-gray-500);
  --btn-secondary-bg:       var(--c-gray-800);
  --btn-secondary-bg-hover: var(--c-gray-750);
  --btn-secondary-text:     var(--c-gray-100);
  --btn-secondary-border:   var(--c-gray-500);
}
```

Disabled opacity in dark mode: 45% (vs 35% in light).

## JS Toggle

```javascript
function toggleDarkMode() {
    document.body.classList.toggle('dark');
}
```

## Media Query Alternative

To respect the user's OS preference instead of (or in addition to) a manual toggle:

```css
@media (prefers-color-scheme: dark) {
    :root {
        --bg-primary: #1a1a1a;
        --bg-secondary: #2a2a2a;
        --bg-elevated: #333333;
        --text-primary: #e0e0e0;
        --text-secondary: #999999;
        --accent: #4dabf7;
        --accent-hover: #74c0fc;
        --accent-light: rgba(77, 171, 247, 0.15);
        --error: #ef5350;
        --success: #66bb6a;
        --border: #444444;
    }
}
```

## Syncing Theme from MATLAB

For uihtml apps, sync the MATLAB figure's theme to the web side:

```matlab
% MATLAB side: detect theme and send to JS
fig = uifigure;
h = uihtml(fig, 'HTMLSource', 'index.html');
h.Data = struct('theme', fig.Theme);
```

```javascript
// JS side: apply theme class based on MATLAB data
htmlComponent.addEventListener("DataChanged", function() {
    var theme = htmlComponent.Data.theme;
    if (theme === 'dark') {
        document.body.classList.add('dark');
    } else {
        document.body.classList.remove('dark');
    }
});
```

----

Copyright 2026 The MathWorks, Inc.

----
