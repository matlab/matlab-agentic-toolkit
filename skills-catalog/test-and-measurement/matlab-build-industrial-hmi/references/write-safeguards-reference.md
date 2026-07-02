# Write Safeguards Reference

Industrial HMIs control physical equipment. Every write path must have safeguards — bounded input, visible range, explicit confirm, visible feedback. Treat every `writeValue()` as if a typo could damage equipment.

## The five required safeguards

1. **No direct inline editing of live values.** A live readout and a setpoint are different widgets. The setpoint shows the *target*, not the current value.
2. **Confirm before write.** `uiconfirm` dialog showing node, old, new, units. The default option is **Cancel**, not Apply.
3. **Display min/max bounds.** A `uilabel` adjacent to the field showing the valid range, in addition to `Limits` enforcement.
4. **Visual feedback on success/failure.** Brief background flash (green on success, red on failure). Operator must never be uncertain whether the write took effect.
5. **Separate read and write areas.** Setpoint controls live in their own panel (right side or bottom row), distinguishable by background color or border. Never inline a setpoint inside a live-readout grid.

## Pattern A — Bounded numeric setpoint with confirm and feedback

```matlab
% --- Construction (in createComponents) ---
spnr = uispinner(panel, ...
    'Limits',             [0 250], ...
    'Step',               1, ...
    'Value',              app.CurrentSetpoint, ...
    'ValueDisplayFormat', '%d °C', ...
    'BackgroundColor',    [1 1 1]);

rangeLbl = uilabel(panel, ...
    'Text',     'range: 0 - 250 °C', ...
    'FontSize', 10, ...
    'FontColor', [0.3 0.3 0.3]);

sendBtn = uibutton(panel, ...
    'Text',           'Send', ...
    'ButtonPushedFcn', @(b,e) sendOvenSetpoint(app, spnr));
```

```matlab
% --- Callback ---
function sendOvenSetpoint(app, spnr)
    oldVal = app.CurrentOvenSetpoint;
    newVal = spnr.Value;

    if newVal == oldVal
        return  % nothing to do
    end

    msg = sprintf(['Write OvenTemp setpoint:\n\n' ...
                   '  node:  OvenTemp\n' ...
                   '  old:   %d °C\n' ...
                   '  new:   %d °C\n' ...
                   '  range: 0 - 250 °C'], oldVal, newVal);

    sel = uiconfirm(app.UIFigure, msg, 'Confirm setpoint', ...
        'Options',       {'Apply', 'Cancel'}, ...
        'DefaultOption', 'Cancel', ...
        'CancelOption',  'Cancel', ...
        'Icon',          'warning');

    if sel == "Apply"
        try
            writeValue(app.UAClient, app.OvenSetpointNode, newVal);
            app.CurrentOvenSetpoint = newVal;
            flashFeedback(spnr, [0.7 1 0.7]);   % green flash
        catch ME
            spnr.Value = oldVal;                % revert UI
            flashFeedback(spnr, [1 0.7 0.7]);   % red flash
            uialert(app.UIFigure, ME.message, 'Write failed');
        end
    else
        spnr.Value = oldVal;                    % cancel reverts UI
    end
end
```

## Pattern B — Visual feedback flash

```matlab
function flashFeedback(component, flashColor)
    originalColor          = component.BackgroundColor;
    component.BackgroundColor = flashColor;
    drawnow;
    pause(0.4);
    component.BackgroundColor = originalColor;
end
```

For a non-blocking variant, use a one-shot `timer`:

```matlab
function flashFeedbackAsync(component, flashColor)
    originalColor             = component.BackgroundColor;
    component.BackgroundColor = flashColor;
    t = timer('ExecutionMode','singleShot','StartDelay',0.4, ...
        'TimerFcn',  @(~,~) revert(component, originalColor), ...
        'StopFcn',   @(self,~) delete(self));
    start(t);
end
function revert(component, color)
    if isvalid(component)
        component.BackgroundColor = color;
    end
end
```

Prefer the async variant if the callback shouldn't block — under high-frequency setpoint writes the synchronous `pause` stalls the event loop.

## Pattern C — Apply-all with diff summary

When the operator changes multiple setpoints and presses one Apply button, the confirm dialog shows the **diff** of every changed value, not a single line.

```matlab
function applyAllSetpoints(app)
    pending = struct();
    pending.OvenTemp     = struct('Old', app.CurrentOvenSetpoint, ...
                                  'New', app.OvenSpinner.Value, ...
                                  'Units', '°C', ...
                                  'Node', app.OvenSetpointNode);
    pending.RobotSpeed   = struct('Old', app.CurrentRobotSpeed, ...
                                  'New', app.RobotSpeedSpinner.Value, ...
                                  'Units', '%', ...
                                  'Node', app.RobotSpeedNode);
    % ...etc

    fields  = fieldnames(pending);
    changed = fields(arrayfun(@(i) pending.(fields{i}).New ~= pending.(fields{i}).Old, ...
                              1:numel(fields)));

    if isempty(changed)
        return
    end

    lines = arrayfun(@(i) sprintf('  %s: %g → %g %s', changed{i}, ...
                                  pending.(changed{i}).Old, ...
                                  pending.(changed{i}).New, ...
                                  pending.(changed{i}).Units), ...
                     1:numel(changed), 'UniformOutput', false);
    msg = sprintf('Apply %d changes:\n\n%s', numel(changed), strjoin(lines, newline));

    sel = uiconfirm(app.UIFigure, msg, 'Apply setpoints', ...
        'Options', {'Apply All', 'Cancel'}, ...
        'DefaultOption', 'Cancel', 'CancelOption', 'Cancel', 'Icon', 'warning');

    if sel == "Apply All"
        for i = 1:numel(changed)
            p = pending.(changed{i});
            writeValue(app.UAClient, p.Node, p.New);
            app.(['Current' changed{i}]) = p.New;
        end
        flashFeedbackAsync(app.ApplyButton, [0.7 1 0.7]);
    end
end
```

## Pattern D — Safety-critical actuation (E-Stop, motor toggle)

E-Stop is the canonical example. **Confirmation is required even though it feels redundant** — accidental clicks on a touchscreen are the threat, not malice.

```matlab
estopBtn = uibutton(panel, 'state', ...
    'Text',                'EMERGENCY STOP', ...
    'BackgroundColor',     [0.85 0 0], ...
    'FontColor',           [1 1 1], ...
    'FontWeight',          'bold', ...
    'ValueChangedFcn',     @(b,e) onEStopToggle(app, b, e));

function onEStopToggle(app, btn, evt)
    if evt.Value   % pressed
        sel = uiconfirm(app.UIFigure, ...
            'Trigger EMERGENCY STOP? All actuators will halt.', ...
            'Confirm E-Stop', ...
            'Options',       {'STOP', 'Cancel'}, ...
            'DefaultOption', 'Cancel', ...
            'CancelOption',  'Cancel', ...
            'Icon',          'error');
        if sel == "STOP"
            writeValue(app.UAClient, app.EStopNode, true);
        else
            btn.Value = false;   % revert toggle
        end
    else           % released
        sel = uiconfirm(app.UIFigure, ...
            'Release E-Stop and resume?', 'Confirm release', ...
            'Options',       {'Resume', 'Cancel'}, ...
            'DefaultOption', 'Cancel', ...
            'CancelOption',  'Cancel', ...
            'Icon',          'warning');
        if sel == "Resume"
            writeValue(app.UAClient, app.EStopNode, false);
        else
            btn.Value = true;    % revert toggle (stay stopped)
        end
    end
end
```

## Disable writes when the system can't accept them

When E-Stop is active, the disconnected, or the alarm state forbids writes, **disable the controls** rather than letting them fail mid-write:

```matlab
function refreshWriteEnable(app)
    canWrite = app.IsConnected && ~app.EStopActive;
    app.OvenSpinner.Enable        = canWrite;
    app.RobotSpeedSpinner.Enable  = canWrite;
    app.ApplyButton.Enable        = canWrite;
end
```

Call this in the connection state-change handler and the E-Stop callback.

## Common mistakes specific to writes

| Mistake | Fix |
|---------|-----|
| Single Apply button writes all 4 setpoints with no confirm | One Apply button + confirm dialog showing the diff |
| `Limits` set on the spinner but no adjacent range label | Add `range: lo - hi units` `uilabel` next to every writable field |
| Write succeeds but operator can't tell — no UI feedback | Background flash green (or use a `Status: Sent` label) |
| Catch error, swallow it silently | `uialert` with the underlying message + revert UI to the old value |
| E-Stop toggles without confirm | Confirm both engage and release |
| Reading `Value` from the writable spinner to display the live node value | Live readouts and setpoints are separate widgets |

----

Copyright 2026 The MathWorks, Inc.

----
