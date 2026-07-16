# Component Styles

CSS styles for common UI components in uihtml apps.

## Buttons

```css
.btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-xs);
    padding: var(--space-sm) var(--space-md);
    border: none;
    border-radius: var(--radius-sm);
    font-family: var(--font-family);
    font-size: var(--font-size-base);
    font-weight: 500;
    cursor: pointer;
    transition: background var(--transition-fast), opacity var(--transition-fast);
}

.btn-primary {
    background: var(--accent);
    color: #ffffff;
}

.btn-primary:hover:not(:disabled) {
    background: var(--accent-hover);
}

.btn-secondary {
    background: var(--bg-secondary);
    color: var(--text-primary);
    border: 1px solid var(--border);
}

.btn-secondary:hover:not(:disabled) {
    background: var(--border);
}

.btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}
```

## Form Inputs

```css
input[type="text"],
input[type="number"],
select,
textarea {
    width: 100%;
    padding: var(--space-sm);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    font-family: var(--font-family);
    font-size: var(--font-size-base);
    color: var(--text-primary);
    background: var(--bg-primary);
    transition: border-color var(--transition-fast);
}

input:focus,
select:focus,
textarea:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-light);
}
```

## Range Sliders

Common in uihtml control panels:

```css
input[type="range"] {
    width: 100%;
    height: 6px;
    -webkit-appearance: none;
    appearance: none;
    background: var(--border);
    border-radius: 3px;
    outline: none;
}

input[type="range"]::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--accent);
    cursor: pointer;
    transition: transform var(--transition-fast);
}

input[type="range"]::-webkit-slider-thumb:hover {
    transform: scale(1.2);
}
```

## Data Tables

```css
.data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: var(--font-size-base);
}

.data-table th,
.data-table td {
    padding: var(--space-sm) var(--space-md);
    text-align: left;
    border-bottom: 1px solid var(--border);
}

.data-table th {
    background: var(--bg-secondary);
    font-weight: 600;
    color: var(--text-secondary);
    font-size: var(--font-size-sm);
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.data-table tr:hover {
    background: var(--accent-light);
}
```

## Visual Feedback: Loading State

```css
.loading-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.8);
    z-index: 10;
}

.spinner {
    width: 32px;
    height: 32px;
    border: 3px solid var(--border);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
}

@keyframes spin {
    to { transform: rotate(360deg); }
}
```

Usage in HTML:

```html
<div style="position: relative;">
    <div id="loading" class="loading-overlay" style="display: none;">
        <div class="spinner"></div>
    </div>
    <!-- Content here -->
</div>
```

Toggle from JavaScript:

```javascript
function showLoading(visible) {
    document.getElementById("loading").style.display = visible ? "flex" : "none";
}
```

## Visual Feedback: Status Messages

```css
.status-message {
    padding: var(--space-sm) var(--space-md);
    border-radius: var(--radius-sm);
    font-size: var(--font-size-sm);
    margin-top: var(--space-sm);
}

.status-message.success {
    background: rgba(46, 125, 50, 0.1);
    color: var(--success);
    border: 1px solid rgba(46, 125, 50, 0.2);
}

.status-message.error {
    background: rgba(211, 47, 47, 0.1);
    color: var(--error);
    border: 1px solid rgba(211, 47, 47, 0.2);
}
```

## Transitions

Apply transitions to interactive elements for polish:

```css
/* Smooth color changes on hover */
.interactive {
    transition: background var(--transition-fast),
                color var(--transition-fast),
                border-color var(--transition-fast),
                box-shadow var(--transition-fast);
}

/* Scale effect for clickable items */
.clickable:active {
    transform: scale(0.97);
}
```

----

Copyright 2026 The MathWorks, Inc.

----
