# App Designer Gotchas

Two MATLAB-language bugs surface repeatedly when generating programmatic App Designer apps that wrap OPC UA monitoring scripts. Both produce confusing error messages that don't directly point at the cause. Both are fixable with a single line.

## Gotcha 1 — Typed `struct` property without default

**Symptom (runtime):**

```
A dot name structure assignment is illegal when the structure is empty.
Use a subscript on the structure.
```

**Reproduction:**

```matlab
classdef MyApp < matlab.apps.AppBase
    properties (Access = private)
        InfoNodes struct          % BUG: defaults to 0×0 struct
    end
    methods (Access = private)
        function startup(app)
            app.InfoNodes.Robot1 = 1;   % FAILS HERE
        end
    end
end
```

**Why it happens.** A typed property declaration without a default value initializes to the *empty* of that type. For `struct`, "empty" is `0×0 struct` (a struct array with zero elements), not a scalar struct with no fields. You cannot dot-name-assign into a 0-element struct array — there's no element to assign into.

**Fix A — Default to a scalar struct:**

```matlab
properties (Access = private)
    InfoNodes struct = struct()      % scalar struct, fields can be added
end
```

**Fix B — Build the struct locally, then whole-struct assign:**

```matlab
function startup(app)
    s = struct();
    s.Robot1 = 1;
    s.Robot2 = 2;
    app.InfoNodes = s;               % whole-struct assignment is fine
end
```

**Which to use.** Fix A is one line and works for all access patterns. Fix B is preferred when the struct has many fields known at build time — easier to read than chained dot-assignments. Avoid mixing: pick one per property.

## Gotcha 2 — `function` block before `classdef` in same file

**Symptom (parse error):**

```
Only one class definition is allowed per file, and it must come at the head
of the file.
```

**Reproduction:**

```matlab
% MyApp.m
function MyApp                 % BUG: wrapper function above classdef
    app = MyAppImpl;
    figure(app.UIFigure);
end

classdef MyAppImpl < matlab.apps.AppBase
    % ...
end
```

**Why it happens.** A common mistake when an agent tries to make the file "runnable as a script" by wrapping `classdef` in a `function`. MATLAB parses the whole file before executing anything — the parser sees `function` first and refuses to also parse a `classdef`.

**Fix.** Drop the wrapper. The file's first non-comment statement must be `classdef`, and the classdef name must match the filename:

```matlab
% MyApp.m
classdef MyApp < matlab.apps.AppBase
    % ...
end
```

To launch the app, the user (or a separate script) calls `MyApp()` — App Designer apps are constructible just by invoking the class name.

## Less-common gotchas worth knowing

### Cleaning up an OPC UA `Subscription`

`opc.ua.Subscription` does not expose a public `delete` method in R2026a. Calling it errors with *"Cannot access method 'delete' in class 'opc.ua.Subscription'"*. There's also no `unsubscribe()` API. The only supported cleanup is to drop your handle and let `disconnect(client)` close the underlying session, which releases all subscriptions attached to that client at once.

```matlab
delete(sub)        % FAILS: opc.ua.Subscription has no delete method
```

**Fix:**

```matlab
app.Subscription = opc.ua.Subscription.empty;   % drop the handle
disconnect(app.UAClient);                       % closes the underlying session
```

If your dashboard tracks per-widget subscriptions (recommended — see next gotcha), null each one out the same way:

```matlab
for i = 1:numel(app.Widgets)
    app.Widgets(i).Sub = [];
end
```

### Subscription handle must be stored on the app (or it gets GC'd)

**Symptom.** `subscribe()` returns without error, the lamp shows connected, but the data-change callback never fires. No warning, no error, no notification — silent failure.

**Reproduction:**

```matlab
function startupFcn(app)
    % BUG: 'sub' is a local variable. When startupFcn returns, MATLAB
    % releases the only reference to the subscription handle, the listener
    % detaches, and the callback stops being invoked.
    sub = subscribe(app.UAClient, node, @(s, e) onDataChange(app, s, e));
end
```

**Why it happens.** `opc.ua.Subscription` is a handle object whose listener registration lives on the underlying `opc.ua.Channel`. The listener stays attached only while at least one MATLAB reference to the handle is alive. A local variable in a method is GC-eligible the moment the method returns, so the handle is released and the listener detaches — even though the OPC UA session and client are still up.

**Fix — store the handle on a property:**

```matlab
classdef MyApp < matlab.apps.AppBase
    properties (Access = private)
        Subscription opc.ua.Subscription
    end
    methods (Access = private)
        function startupFcn(app)
            app.Subscription = subscribe(app.UAClient, node, ...
                @(s, e) onDataChange(app, s, e));
        end
    end
end
```

The property keeps the handle alive for the life of the app. Pair this with `disconnect(app.UAClient)` in the destructor (see "Cleaning up an OPC UA `Subscription`" above) for clean shutdown. For multi-widget apps where each widget owns its own subscription, store the handle on the widget struct entry — see "Repeated `subscribe()` calls leak channel listeners" below.

### Repeated `subscribe()` calls leak channel listeners

**Symptom (warnings on every notification, often after several "Add to Dashboard" clicks):**

```
Warning: Error occurred while executing the listener callback for event
DataChange defined for class opc.ua.Client:
Too many input arguments.
```
or
```
... Key not found in containers.Map.
```

**Reproduction.** A common pattern is "one subscription, rebuilt on every add":

```matlab
% BUG: every add re-subscribes the whole list, leaking listeners
app.Subscription = subscribe(app.UAClient, [app.AllNodes, newNode], @cb);
```

**Why it happens.** Each `subscribe(client, …)` call attaches a fresh listener to the client's `opc.ua.Channel`. There is no public API to release a single subscription before `disconnect(client)`, so prior listeners stay attached and fire on every notification — often with a stale callback signature. The warning text mentions `opc.ua.Client`, not your code, which is what makes it hard to attribute.

**Fix — subscribe per widget; never resubscribe an existing widget:**

```matlab
% Each newly added widget gets its own Subscription, stored on the widget.
idx = numel(app.Widgets);
app.Widgets(idx).Sub = subscribe(app.UAClient, opcNode, ...
    @(src, evt) onDataChange(app, src, evt), ...
    PublishInterval = 0.5);
```

The accumulated subscriptions all release on `disconnect(app.UAClient)`. This sidesteps the missing per-subscription cleanup API entirely.

### `AccessLevel` vs `AccessLevelCurrent`

When checking whether an OPC UA node is writable from the **client side**, use `AccessLevelCurrent`, not `AccessLevel`. `AccessLevel` reports the server's static capability; `AccessLevelCurrent` reports what the current session can actually do (after permission checks).

**Release-aware shape.** In R2026a `AccessLevelCurrent` is a *string* (`'read'`, `'read/write'`, `'write'`, `'none'`); older releases return a numeric OPC UA bitmask. A defensive check works on both:

```matlab
function tf = isWritable(node)
    a = node.AccessLevelCurrent;
    if ischar(a) || isstring(a)
        tf = contains(lower(char(a)), 'write');
    else
        tf = bitand(uint8(a), uint8(2)) > 0;   % bit 1 = CurrentWrite
    end
end

node = findNodeByName(uaClient.Namespace, 'OvenTemp', '-once');
if isWritable(node)
    writeValue(uaClient, node, newValue);
end
```

Treating `AccessLevelCurrent` as numeric in R2026a returns surprising results (string-to-numeric coercion of `'read/write'` ≠ a bitmask), so writable nodes silently fail the test and the UI never offers them setpoint widgets.

### Cleaning up timers in the destructor

App Designer apps must explicitly stop and delete timers in their `delete` method, or `CloseRequestFcn`. A leaked timer keeps firing after the figure closes — and the callback references invalid handles.

```matlab
methods (Access = public)
    function delete(app)
        if ~isempty(app.PollTimer) && isvalid(app.PollTimer)
            stop(app.PollTimer);
            delete(app.PollTimer);
        end
        if ~isempty(app.UAClient) && isvalid(app.UAClient)
            disconnect(app.UAClient);
        end
    end
end
```

The same applies to `CloseRequestFcn`:

```matlab
app.UIFigure.CloseRequestFcn = @(src, evt) closeApp(app);

function closeApp(app)
    delete(app);   % triggers the destructor above
end
```

----

Copyright 2026 The MathWorks, Inc.

----
