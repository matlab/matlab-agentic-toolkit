# View Binding Pattern

Complete MainView class demonstrating how to bind a JavaScript View to a ViewModel using Observable subscriptions.

## MainView Class

```javascript
// views/main-view.js
export class MainView {
    constructor(viewModel, containerElement) {
        this.viewModel = viewModel;
        this.container = containerElement;
        this.unsubscribers = [];

        this._createUI();
        this._bindToViewModel();
    }

    destroy() {
        // Clean up all subscriptions to prevent memory leaks
        this.unsubscribers.forEach(unsub => unsub());
        this.unsubscribers = [];
        this.container.replaceChildren();
    }

    _createUI() {
        // Create DOM structure
        const app = document.createElement('div');
        app.className = 'app';

        const inputRow = document.createElement('div');
        inputRow.className = 'form-row';

        this.inputField = document.createElement('input');
        this.inputField.type = 'number';
        this.inputField.placeholder = 'Enter value';
        inputRow.appendChild(this.inputField);

        this.resultLabel = document.createElement('span');
        this.resultLabel.className = 'result';

        this.processBtn = document.createElement('button');
        this.processBtn.className = 'btn btn-primary';
        this.processBtn.textContent = 'Process';

        this.resetBtn = document.createElement('button');
        this.resetBtn.className = 'btn btn-secondary';
        this.resetBtn.textContent = 'Reset';

        const buttonRow = document.createElement('div');
        buttonRow.className = 'button-row';
        buttonRow.appendChild(this.processBtn);
        buttonRow.appendChild(this.resetBtn);

        this.statusLabel = document.createElement('div');
        this.statusLabel.className = 'status';

        this.errorLabel = document.createElement('div');
        this.errorLabel.className = 'status-message error';

        app.appendChild(inputRow);
        app.appendChild(this.resultLabel);
        app.appendChild(buttonRow);
        app.appendChild(this.statusLabel);
        app.appendChild(this.errorLabel);

        this.container.appendChild(app);

        // Wire UI events to ViewModel commands
        this.processBtn.addEventListener('click', () => {
            const value = parseFloat(this.inputField.value) || 0;
            this.viewModel.processCommand(value);
        });

        this.resetBtn.addEventListener('click', () => {
            this.viewModel.resetCommand();
            this.inputField.value = '';
        });
    }

    _bindToViewModel() {
        const vm = this.viewModel;

        // Subscribe to each Observable — View updates automatically
        this.unsubscribers.push(
            vm.displayValue.subscribe(value => {
                this.resultLabel.textContent = value;
            })
        );

        this.unsubscribers.push(
            vm.isProcessing.subscribe(busy => {
                this.processBtn.disabled = busy;
                this.resetBtn.disabled = busy;
                this.inputField.disabled = busy;
            })
        );

        this.unsubscribers.push(
            vm.statusMessage.subscribe(msg => {
                this.statusLabel.textContent = msg;
            })
        );

        this.unsubscribers.push(
            vm.errorMessage.subscribe(msg => {
                this.errorLabel.textContent = msg;
                this.errorLabel.style.display = msg ? 'block' : 'none';
            })
        );

        this.unsubscribers.push(
            vm.canSubmit.subscribe(canSubmit => {
                this.processBtn.disabled = !canSubmit;
            })
        );
    }
}
```

## View Design Guidelines

- All DOM creation and manipulation happens in the View only
- Use `subscribe()` to bind ViewModel observables to DOM updates
- Store unsubscribe functions and call them in `destroy()` to prevent leaks
- Wire user events (click, input) to ViewModel commands
- The View never talks to the Model directly

## Binding Patterns

### Simple binding (one observable → one DOM update)

```javascript
this.unsubscribers.push(
    vm.statusMessage.subscribe(msg => {
        this.statusLabel.textContent = msg;
    })
);
```

### Conditional display

```javascript
this.unsubscribers.push(
    vm.errorMessage.subscribe(msg => {
        this.errorLabel.textContent = msg;
        this.errorLabel.style.display = msg ? 'block' : 'none';
    })
);
```

### Multi-property binding (subscribe to each independently)

```javascript
// Both isProcessing and canSubmit affect the button
this.unsubscribers.push(
    vm.isProcessing.subscribe(busy => {
        this.processBtn.disabled = busy;
    })
);
this.unsubscribers.push(
    vm.canSubmit.subscribe(can => {
        this.processBtn.disabled = !can;
    })
);
```

### List rendering

```javascript
vm.items.subscribe(items => {
    const fragment = document.createDocumentFragment();
    for (const item of items) {
        const li = document.createElement('li');
        li.textContent = item.name;
        fragment.appendChild(li);
    }
    this.list.replaceChildren(fragment);
});
```

## Cleanup

Always call `destroy()` when switching views or removing the app:

```javascript
// Example: switching between views
function showDetailView() {
    currentView.destroy();
    currentView = new DetailView(viewModel, container);
}
```

----

Copyright 2026 The MathWorks, Inc.

----
