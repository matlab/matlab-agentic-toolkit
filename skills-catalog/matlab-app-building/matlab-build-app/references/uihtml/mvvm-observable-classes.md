# Observable Classes

Complete implementations of the Observable and Computed classes used for reactive state management in JavaScript MVVM apps.

Place both classes in `viewmodels/observable.js`.

## Observable

A reactive value wrapper. When the value changes, all subscribers are notified.

```javascript
export class Observable {
    constructor(initialValue) {
        this._value = initialValue;
        this._listeners = new Set();
    }

    get value() {
        return this._value;
    }

    set value(newValue) {
        if (this._value !== newValue) {
            this._value = newValue;
            this._notify();
        }
    }

    subscribe(callback) {
        this._listeners.add(callback);
        callback(this._value); // Immediate call with current value
        return () => this._listeners.delete(callback); // Unsubscribe function
    }

    _notify() {
        this._listeners.forEach(cb => cb(this._value));
    }
}
```

### Key behaviors

- `set value()` uses strict inequality (`!==`) to avoid redundant notifications
- `subscribe()` calls the callback immediately with the current value — no need for manual initial sync
- Returns an unsubscribe function — store it and call it in `destroy()` to prevent leaks

## Computed

A derived observable that recalculates when its dependencies change:

```javascript
export class Computed {
    constructor(computeFn, dependencies) {
        this._computeFn = computeFn;
        this._listeners = new Set();
        this._value = computeFn();

        // Re-compute when any dependency changes
        dependencies.forEach(dep => {
            dep.subscribe(() => {
                const newValue = this._computeFn();
                if (this._value !== newValue) {
                    this._value = newValue;
                    this._notify();
                }
            });
        });
    }

    get value() {
        return this._value;
    }

    subscribe(callback) {
        this._listeners.add(callback);
        callback(this._value);
        return () => this._listeners.delete(callback);
    }

    _notify() {
        this._listeners.forEach(cb => cb(this._value));
    }
}
```

### Key behaviors

- Read-only: no `set value()` — the value is always derived from the compute function
- Automatically re-evaluates when any dependency Observable changes
- Only notifies subscribers if the computed result actually changed
- Pass ALL source Observables in the `dependencies` array — missing one means stale values

### Usage example

```javascript
const firstName = new Observable('Jane');
const lastName = new Observable('Doe');

const fullName = new Computed(
    () => `${firstName.value} ${lastName.value}`,
    [firstName, lastName]
);

fullName.subscribe(name => console.log(name));
// Logs: "Jane Doe" immediately

firstName.value = 'John';
// Logs: "John Doe" (auto-recomputed)
```

----

Copyright 2026 The MathWorks, Inc.

----
