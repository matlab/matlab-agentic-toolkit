# App Lifecycle Guidance

Detailed patterns for managing the SimBiology Model Builder and Model
Analyzer desktop apps, including switching models, coordinating both
apps, and session cleanup.

---

## Builder and Analyzer Can Coexist

You do NOT need to close one to open the other. Use the Builder for
diagrams and the Analyzer for simulation/plotting.

---

## Switching Models in the Builder

When the Builder is already open and you need a DIFFERENT model:

1. **STOP and ask the user** if they want to save the current model as
   `.sbproj` before closing. Closing triggers a copy-back that can lose
   in-flight edits.
2. If yes: `saveViaBuilder('name.sbproj')` (preserves diagram styling)
3. Close the Builder:
   ```matlab
   try
       mb = SimBiology.web.desktophandler.getModelBuilder();
       if ~isempty(mb) && isfield(mb, 'webWindow') && isvalid(mb.webWindow)
           mb.webWindow.close();
       end
   catch, end
   pause(2);
   ```
4. Reopen: `simBiologyModelBuilder(newModel);`

---

## No-Argument Warning

`simBiologyModelBuilder()` with no arguments opens the UI but does NOT
associate a model with a diagram. All `simbio.diagram.setBlock()` calls
will fail with: `"SimBiology model does not have a diagram."` Always pass
the model explicitly the first time.

**Exception:** When the Analyzer is already open, you cannot pass a model
argument. In that case, call `simBiologyModelBuilder()` without arguments
and the Builder will connect to the model already on sbioroot.

---

## Closing the Builder

```matlab
try
    mb = SimBiology.web.desktophandler.getModelBuilder();
    if ~isempty(mb) && isfield(mb, 'webWindow') && isvalid(mb.webWindow)
        mb.webWindow.close();
    end
catch
end
```

---

## Opening and Closing the Analyzer

```matlab
% Open
if isAppOpen('builder')
    simBiologyModelAnalyzer();          % can't pass model when Builder is open
else
    simBiologyModelAnalyzer(model);
end

% Close
try
    ma = SimBiology.web.desktophandler.getModelAnalyzer();
    if ~isempty(ma) && isfield(ma, 'webWindow') && isvalid(ma.webWindow)
        ma.webWindow.close();
    end
catch
end
```

---

## Save/Load Diagram Preservation

| Save Method | Preserves Diagram? |
|-------------|:--:|
| `saveViaBuilder(path)` | Yes |
| `save(path, 'model')` (.mat) | No |
| Builder toolstrip Save (manual) | Yes |

| Load Method | Preserves Diagram? |
|-------------|:--:|
| `loadViaBuilder(path)` | Yes |
| `sbioloadproject` -> `simBiologyModelBuilder(model)` | No |
| Double-click `.sbproj` file | Yes |

`saveViaBuilder` uses two mechanisms:
- If the model was loaded from a file (via `loadViaBuilder`), it clicks
  the Builder's toolstrip save button.
- If the model was created programmatically (no file association), it
  uses `SimBiology.internal.Project` to save model + diagram directly.

---

## Full Session Cleanup

Close both apps before `sbioreset`:

```matlab
% Close Builder
try
    mb = SimBiology.web.desktophandler.getModelBuilder();
    if ~isempty(mb) && isfield(mb, 'webWindow') && isvalid(mb.webWindow)
        mb.webWindow.close();
    end
catch, end
% Close Analyzer
try
    ma = SimBiology.web.desktophandler.getModelAnalyzer();
    if ~isempty(ma) && isfield(ma, 'webWindow') && isvalid(ma.webWindow)
        ma.webWindow.close();
    end
catch, end
pause(1);
sbioreset;
```


----

Copyright 2026 The MathWorks, Inc.

----
