# UIHTML MVVM

Structure JavaScript web frontends using the Model-View-ViewModel pattern. This skill provides the architectural layer — observable state, ViewModels, View binding, and separation of concerns.

See `references/uifigure/mvvm-guide.md` for the MATLAB-side MVVM equivalent.

## Critical Rules

- MUST separate Model, ViewModel, and View into distinct modules or clearly separated code sections
- MUST use the Observable class for any ViewModel state that the View needs to react to
- MUST clean up subscriptions when Views are destroyed (prevent memory leaks)
- NEVER put DOM manipulation code in the ViewModel
- NEVER put business logic or data transformation in the View
- NEVER have the Model reference the ViewModel or View

## Architecture Overview

```
+------------------+     +-----------------------+     +------------------+
|      View        |     |      ViewModel        |     |      Model       |
|                  |     |                       |     |                  |
| DOM elements     |     | Observable properties |     | Data storage     |
| Event listeners -+---->| Commands (methods)    +---->| Business logic   |
| UI updates    <--+-----+ Presentation logic    |<----+ Validation       |
|                  |     |                       |     | Persistence      |
+------------------+     +-----------------------+     +------------------+
     subscribes to              updates
     ViewModel props            Model data
```

**Data flow:**
1. User interacts with View (click, type, slide)
2. View calls ViewModel command
3. ViewModel updates Model or its own state
4. Observable notifies subscribers
5. View updates DOM automatically

## Observable Classes

### Observable

A reactive value wrapper. When the value changes, all subscribers are notified. Supports `get value()`, `set value(newValue)`, and `subscribe(callback)` which returns an unsubscribe function.

### Computed

A derived observable that recalculates when its dependencies change. Created with `new Computed(computeFn, dependencies)`. Read-only value, subscribable.

See `mvvm-observable-classes.md` for the complete implementations of both classes.

Place both classes in `viewmodels/observable.js`.

## Model

The Model holds data and business logic. It has no knowledge of the UI.

```javascript
// models/data-model.js
export class DataModel {
    constructor() {
        this._data = {};
        this._listeners = new Set();
    }

    get data() {
        return this._data;
    }

    set data(value) {
        this._data = value;
        this._notifyListeners();
    }

    subscribe(callback) {
        this._listeners.add(callback);
        return () => this._listeners.delete(callback);
    }

    _notifyListeners() {
        this._listeners.forEach(cb => cb(this._data));
    }

    // Business logic methods
    processInput(input) {
        return { ...input, processed: true, timestamp: Date.now() };
    }

    // Persistence
    toJSON() {
        return structuredClone(this._data);
    }

    fromJSON(json) {
        this._data = json;
        this._notifyListeners();
    }
}
```

### Model Design Guidelines

- Keep Models pure — no DOM references, no ViewModel references
- Models can be tested independently of any UI
- For uihtml apps, the Model is often a thin wrapper around data received from MATLAB via the bridge
- Multiple ViewModels can share one Model (useful for split-pane UIs)

## ViewModel

The ViewModel exposes Model data as Observable properties and provides commands the View can invoke.

```javascript
// viewmodels/main-viewmodel.js
import { Observable, Computed } from './observable.js';

export class MainViewModel {
    constructor(model) {
        this.model = model;

        // Observable properties — View subscribes to these
        this.displayValue = new Observable('');
        this.isProcessing = new Observable(false);
        this.statusMessage = new Observable('Ready');
        this.errorMessage = new Observable('');

        // Computed property — derived from other observables
        this.canSubmit = new Computed(
            () => !this.isProcessing.value && this.displayValue.value !== '',
            [this.isProcessing, this.displayValue]
        );

        // React to Model changes
        model.subscribe(() => this._syncFromModel());
        this._syncFromModel();
    }

    // Commands — called by View in response to user actions

    processCommand(inputValue) {
        this.isProcessing.value = true;
        this.statusMessage.value = 'Processing...';
        this.errorMessage.value = '';

        try {
            const result = this.model.processInput(inputValue);
            this.model.data = result;
            this.statusMessage.value = 'Complete';
        } catch (error) {
            this.errorMessage.value = error.message;
            this.statusMessage.value = 'Error';
        }

        this.isProcessing.value = false;
    }

    resetCommand() {
        this.model.data = {};
        this.statusMessage.value = 'Reset';
        this.errorMessage.value = '';
    }

    // Private — sync ViewModel state from Model

    _syncFromModel() {
        const data = this.model.data;
        this.displayValue.value = data.processed
            ? JSON.stringify(data)
            : '';
    }
}
```

### ViewModel Design Guidelines

- Every piece of UI state should be an Observable on the ViewModel
- Commands are plain methods — the View calls them, the ViewModel does the work
- The ViewModel never references DOM elements or View methods
- Put presentation logic here (formatting, display strings, enabled/disabled state)
- For uihtml apps: the ViewModel typically sends events to MATLAB via the bridge and updates Observables when results come back

## View

The View creates DOM elements and binds them to ViewModel observables. See `mvvm-view-binding.md` for the complete MainView class pattern.

Key principles:
- All DOM creation and manipulation happens in the View only
- Use `subscribe()` to bind ViewModel observables to DOM updates
- Store unsubscribe functions and call them in `destroy()` to prevent leaks
- Wire user events (click, input) to ViewModel commands
- The View never talks to the Model directly

## Wiring It Together

### Entry Point (index.html)

```html
<script type="module">
    import { DataModel } from './models/data-model.js';
    import { MainViewModel } from './viewmodels/main-viewmodel.js';
    import { MainView } from './views/main-view.js';

    const model = new DataModel();
    const viewModel = new MainViewModel(model);
    const view = new MainView(viewModel, document.getElementById('app'));

    // Expose for console debugging
    window.app = { model, viewModel, view };
</script>

<div id="app"></div>
```

### With uihtml Bridge

When used in a uihtml app, the bridge feeds data into the Model and sends commands from the ViewModel:

```html
<script type="module">
    import { DataModel } from './models/data-model.js';
    import { MainViewModel } from './viewmodels/main-viewmodel.js';
    import { MainView } from './views/main-view.js';

    let model, viewModel, view;

    window.setup = function(htmlComponent) {
        window.htmlComponent = htmlComponent;

        model = new DataModel();
        viewModel = new MainViewModel(model);
        view = new MainView(viewModel, document.getElementById('app'));

        // MATLAB -> JS: update Model from bridge
        htmlComponent.addEventListener("DataChanged", function(event) {
            model.data = htmlComponent.Data;
        });

        htmlComponent.addEventListener("ResultReady", function(event) {
            model.data = event.Data;
            viewModel.statusMessage.value = 'Result received';
            viewModel.isProcessing.value = false;
        });

        htmlComponent.addEventListener("Error", function(event) {
            viewModel.errorMessage.value = event.Data;
            viewModel.isProcessing.value = false;
        });

        // Expose for debugging
        window.app = { model, viewModel, view };
    };
</script>
```

For the ViewModel to send data to MATLAB, add bridge-aware commands:

```javascript
// In MainViewModel
submitToMATLAB(data) {
    this.isProcessing.value = true;
    this.statusMessage.value = 'Sending to MATLAB...';
    window.htmlComponent.sendEventToMATLAB("ProcessData", data);
    // Response handled by bridge listeners that update Model
}
```

## When MVVM is Overkill

Skip MVVM and use direct event handlers when:
- The app has 2-3 controls with no shared state
- There is no two-way data flow (display-only or input-only)
- The app is ephemeral and maximum simplicity is preferred

In these cases, wire events directly in `setup()`:

```javascript
function setup(htmlComponent) {
    window.htmlComponent = htmlComponent;

    document.getElementById("btn").addEventListener("click", function() {
        htmlComponent.sendEventToMATLAB("DoThing", { value: 42 });
    });

    htmlComponent.addEventListener("Result", function(event) {
        document.getElementById("output").textContent = event.Data;
    });
}
```

## Directory Structure

```
my-app/
+-- index.html                  % Entry point
+-- models/
|   +-- data-model.js           % Data + business logic
+-- viewmodels/
|   +-- observable.js           % Observable + Computed classes
|   +-- main-viewmodel.js       % Bindable state + commands
+-- views/
|   +-- main-view.js            % DOM creation + binding
+-- utils/                      % Optional shared utilities
    +-- formatting.js
```

## Implementation Checklist

- [ ] Observable and Computed classes implemented in `viewmodels/observable.js`
- [ ] Model contains data and business logic only (no UI code)
- [ ] ViewModel exposes all UI state as Observables
- [ ] ViewModel commands handle user actions (no DOM references)
- [ ] View creates DOM and subscribes to ViewModel observables
- [ ] View stores unsubscribe functions and calls them in `destroy()`
- [ ] Entry point wires Model -> ViewModel -> View in dependency order
- [ ] For uihtml: bridge events feed into Model; ViewModel commands send to MATLAB
- [ ] Key objects exposed on `window.app` for console debugging

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| View not updating when data changes | Not using Observable | Wrap ViewModel state in `new Observable(value)` |
| Stale data displayed | Subscribe missed initial value | `subscribe()` calls callback immediately with current value |
| Memory leak on view switch | Subscriptions not cleaned up | Call `destroy()` which runs all unsubscribe functions |
| ViewModel has DOM references | Incorrect separation | Move all DOM code to View; ViewModel only has Observables and commands |
| Circular updates | Observable triggers itself | `set value()` checks `!==` before notifying |
| Computed not updating | Missing dependency | Pass all source Observables in the dependencies array |

## References

| Topic | File | Description |
|-------|------|-------------|
| Observable classes | `mvvm-observable-classes.md` | Complete Observable and Computed class implementations |
| View binding | `mvvm-view-binding.md` | Complete MainView class, DOM binding, View design guidelines |

----

Copyright 2026 The MathWorks, Inc.

----
