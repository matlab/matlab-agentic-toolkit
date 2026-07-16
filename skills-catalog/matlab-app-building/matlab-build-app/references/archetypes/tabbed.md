# Tabbed View Layout

**Primary user task:** Navigate between independent sections of a larger app without leaving the page.

```
┌────────────────────────────────────────────────────────┐
│  App Title / Header (optional)                         │  ← header (optional, fixed height)
├──────────┬───────────┬───────────┬─────────────────────┤
│ Tab 1 ●  │  Tab 2    │  Tab 3    │                     │  ← tab bar (fixed height ~36px)
├──────────┴───────────┴───────────┴─────────────────────┤
│                                                        │
│   Active tab content                                   │  ← content area (fills space)
│   (only one tab visible at a time)                     │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**When to choose:** The app has 2–6 distinct sections that are navigated between, not scrolled through. Sections are largely independent — changing one tab doesn't update another. Examples: Overview / Details / Settings, Train / Evaluate / Export, Configure / Run / Results.

**Key rules:**
- 2–6 tabs; more than 6 → use a left-nav sidebar instead (Canvas archetype)
- Tab content is swapped, not stacked — only the active panel is visible (UIFigure app auto-handles this)
- Tabs at top is the default; tabs on the left side work for 4+ dense sections
- A header above the tab bar is optional — use it for app-level actions (save, export) that span all tabs

---

## UIFigure app — uitabgroup Skeleton

MATLAB's `uitabgroup` handles all the chrome automatically — tab bar rendering, switching, and content area sizing.

```matlab
fig = uifigure('Name', 'App');

% Simple: just tabs, no header above
tg = uitabgroup(fig);

tab1 = uitab(tg, 'Title', 'Overview');
tab1Grid = uigridlayout(tab1, [2 2]);
tab1Grid.RowHeight   = {'1x', 120};
tab1Grid.ColumnWidth = {'1x', '1x'};
% Add components to tab1Grid...

tab2 = uitab(tg, 'Title', 'Details');
tab2Grid = uigridlayout(tab2, [1 1]);
ax = uiaxes(tab2Grid);

tab3 = uitab(tg, 'Title', 'Settings');
tab3Grid = uigridlayout(tab3, [6 2]);
tab3Grid.RowHeight   = repmat({'fit'}, 1, 6);
tab3Grid.ColumnWidth = {'fit', '1x'};
% Add form controls...
```

### With app header above tabs

```matlab
fig = uifigure('Name', 'App');

rootGrid = uigridlayout(fig, [2 1]);
rootGrid.RowHeight  = {48, '1x'};
rootGrid.Padding    = [0 0 0 0];
rootGrid.RowSpacing = 0;

header = uipanel(rootGrid);
header.Layout.Row = 1;
headerGrid = uigridlayout(header, [1 3]);
headerGrid.ColumnWidth = {'1x', 'fit', 'fit'};
uilabel(headerGrid, 'Text', 'My App', 'FontSize', 16, 'FontWeight', 'bold');
uibutton(headerGrid, 'Text', 'Export');
uibutton(headerGrid, 'Text', 'Save');

tg = uitabgroup(rootGrid);
tg.Layout.Row = 2;

tab1 = uitab(tg, 'Title', 'Tab 1');
% ... add content as above
```

### Responding to tab changes

```matlab
tg.SelectionChangedFcn = @onTabChanged;

function onTabChanged(src, evt)
    % src.SelectedTab.Title gives the active tab name
    % Use to trigger lazy data loading when a tab is first opened
    if evt.NewValue == tab2 && ~isloaded
        loadTabData();
        isloaded = true;
    end
end
```

---

## UIHTML/web app — CSS + JS Skeleton

```html
<div class="app">
    <header class="app-header"><!-- optional --></header>
    <nav class="tab-bar" role="tablist">
        <button class="tab-btn active" data-tab="overview" role="tab">Overview</button>
        <button class="tab-btn" data-tab="details" role="tab">Details</button>
        <button class="tab-btn" data-tab="settings" role="tab">Settings</button>
    </nav>
    <main class="tab-content">
        <section class="tab-panel active" id="tab-overview">...</section>
        <section class="tab-panel" id="tab-details">...</section>
        <section class="tab-panel" id="tab-settings">...</section>
    </main>
</div>
```

```css
.app {
    display: grid;
    grid-template-rows: auto auto 1fr;  /* header (optional), tab bar, content */
    height: 100vh;
}

.tab-bar {
    display: flex;
    border-bottom: 2px solid var(--border);
    padding: 0 var(--space-4);
    gap: 0;
}

.tab-btn {
    padding: var(--space-2) var(--space-4);
    border: none;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    background: none;
    cursor: pointer;
    font-size: var(--text-base);
    color: var(--text-secondary);
    white-space: nowrap;
}

.tab-btn:hover { color: var(--text-primary); }
.tab-btn.active {
    color: var(--text-primary);
    border-bottom-color: var(--accent);
    font-weight: var(--fw-semi);
}

.tab-content {
    overflow: auto;
    padding: var(--space-4);
}

.tab-panel { display: none; }
.tab-panel.active { display: block; }
```

```javascript
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const tabId = btn.dataset.tab;

        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));

        btn.classList.add('active');
        document.getElementById('tab-' + tabId).classList.add('active');
    });
});
```

---

## Common Variations

| Variation | Change |
|---|---|
| Tabs on left side | Use `uitabgroup` `TabLocation = 'left'` (UIFigure app); CSS: sidebar-style nav + `grid-template-columns: auto 1fr` |
| Badge / count on tab | UIFigure app: `tab.Title = sprintf('Errors (%d)', n)`; UIHTML app: add `<span class="badge">` |
| Disabled tab | UIFigure app: `tab.Enable = 'off'`; UIHTML app: `aria-disabled="true"` + pointer-events: none |
| Lazy tab loading | UIFigure app: use `SelectionChangedFcn`; UIHTML app: check `if (!loaded)` in tab switch handler |
| Nested tabs | Avoid — creates spatial confusion. Use a sidebar nav (Canvas archetype) instead |

---

## Composition

- **UIFigure app:** `references/uifigure/guide.md` for content within each tab
- **UIHTML/web app:** `references/uihtml/styling-guide.md` for tab bar styling; `references/uihtml/js-coding-guide.md` for event delegation patterns
- **MVVM note:** Tab state (which tab is active) is view-only — it doesn't need to live in the ViewModel unless tab switches trigger data loads

----

Copyright 2026 The MathWorks, Inc.

----
