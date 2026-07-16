# Layout Patterns

Complete CSS for common layout patterns in uihtml apps.

## Full-Page App Layout (CSS Grid)

The standard layout for a uihtml app that fills its container:

```css
.app-layout {
    display: grid;
    grid-template-rows: auto 1fr auto;  /* header, main, footer */
    height: 100vh;
    width: 100%;
}

.app-header {
    padding: var(--space-md);
    background: var(--bg-elevated);
    border-bottom: 1px solid var(--border);
}

.app-main {
    padding: var(--space-md);
    overflow-y: auto;
}

.app-footer {
    padding: var(--space-sm) var(--space-md);
    background: var(--bg-secondary);
    border-top: 1px solid var(--border);
    font-size: var(--font-size-sm);
    color: var(--text-secondary);
}
```

## Sidebar + Content Layout

```css
.sidebar-layout {
    display: grid;
    grid-template-columns: 250px 1fr;
    height: 100vh;
}

.sidebar {
    background: var(--bg-secondary);
    border-right: 1px solid var(--border);
    padding: var(--space-md);
    overflow-y: auto;
}

.content {
    padding: var(--space-lg);
    overflow-y: auto;
}
```

## Control Panel (Flexbox)

For groups of controls (sliders, dropdowns, buttons) typically seen in uihtml apps:

```css
.control-panel {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-md);
    padding: var(--space-md);
    background: var(--bg-secondary);
    border-radius: var(--radius-md);
}

.control-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-xs);
    min-width: 150px;
    flex: 1;
}

.control-group label {
    font-size: var(--font-size-sm);
    font-weight: 600;
    color: var(--text-secondary);
}
```

## Card Grid

For dashboard-style layouts with multiple panels:

```css
.card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: var(--space-md);
    padding: var(--space-md);
}

.card {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-md);
    box-shadow: var(--shadow-sm);
}
```

## Complete Example: Styled Control Panel

A complete control panel suitable for a uihtml data visualization app:

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        *, *::before, *::after { box-sizing: border-box; }

        :root {
            --bg-primary: #ffffff;
            --bg-secondary: #f5f5f5;
            --text-primary: #1a1a1a;
            --text-secondary: #666666;
            --accent: #0072BD;
            --accent-hover: #005a9e;
            --border: #e0e0e0;
            --radius-sm: 4px;
            --radius-md: 8px;
            --space-xs: 4px;
            --space-sm: 8px;
            --space-md: 16px;
            --transition-fast: 150ms ease;
        }

        body {
            margin: 0;
            padding: var(--space-md);
            font-family: system-ui, -apple-system, sans-serif;
            background: var(--bg-secondary);
            color: var(--text-primary);
        }

        .controls {
            display: flex;
            flex-wrap: wrap;
            gap: var(--space-md);
            align-items: end;
        }

        .control-group {
            display: flex;
            flex-direction: column;
            gap: var(--space-xs);
            flex: 1;
            min-width: 120px;
        }

        .control-group label {
            font-size: 0.8125rem;
            font-weight: 600;
            color: var(--text-secondary);
        }

        select, input[type="number"] {
            padding: var(--space-sm);
            border: 1px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 0.875rem;
            background: var(--bg-primary);
        }

        select:focus, input:focus {
            outline: none;
            border-color: var(--accent);
        }

        .btn {
            padding: var(--space-sm) var(--space-md);
            border: none;
            border-radius: var(--radius-sm);
            background: var(--accent);
            color: #fff;
            font-weight: 500;
            cursor: pointer;
            transition: background var(--transition-fast);
        }

        .btn:hover { background: var(--accent-hover); }
    </style>
</head>
<body>
    <div class="controls">
        <div class="control-group">
            <label>Plot Type</label>
            <select id="plotType">
                <option value="sine">Sine</option>
                <option value="cosine">Cosine</option>
                <option value="both">Both</option>
            </select>
        </div>
        <div class="control-group">
            <label>Frequency</label>
            <input type="number" id="frequency" value="1" min="0.1" max="10" step="0.1">
        </div>
        <div class="control-group">
            <label>Amplitude</label>
            <input type="number" id="amplitude" value="1" min="0.1" max="5" step="0.1">
        </div>
        <div class="control-group">
            <button class="btn" onclick="updatePlot()">Update Plot</button>
        </div>
    </div>
</body>
</html>
```

----

Copyright 2026 The MathWorks, Inc.

----
