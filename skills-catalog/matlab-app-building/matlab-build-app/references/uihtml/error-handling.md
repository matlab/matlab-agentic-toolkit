# Error Handling Guide

Errors must be caught on both sides of the bridge. An unhandled error on either side breaks the communication chain silently.

## MATLAB Side: try-catch in Every Handler

Wrap the entire event handler body in try-catch and always send the error back to JS:

```matlab
function handleEvent(src, event)
    eventName = event.HTMLEventName;
    eventData = event.HTMLEventData;

    try
        switch eventName
            case 'processData'
                result = processData(eventData);
                sendEventToHTMLSource(src, 'Result', result);

            case 'exportFile'
                exportData(eventData);
                sendEventToHTMLSource(src, 'exportDone', 'ok');

            otherwise
                warning('uihtml:unknownEvent', 'Unknown event: %s', eventName);
        end

    catch ME
        fprintf('[uihtml] Error in %s: %s\n', eventName, ME.message);
        sendEventToHTMLSource(src, 'error', struct( ...
            'event',   eventName, ...
            'message', ME.message));
    end
end
```

Key points:
- Log to the MATLAB command window with `fprintf` — aids debugging without interrupting the app
- Send a structured error object so JS knows which event caused the failure
- The `otherwise` branch with `warning` prevents unknown events from silently doing nothing

## JavaScript Side: Error Event Listener

Always register an `Error` listener in `setup()`. Without it, MATLAB errors are invisible to the user:

```javascript
// Inside setup()
htmlComponent.addEventListener('error', function(event) {
    const err = event.Data;

    if (err && err.event) {
        console.error('[MATLAB] Error in ' + err.event + ': ' + err.message);
        showUserError('Error processing ' + err.event + ': ' + err.message);
    } else {
        console.error('[MATLAB] Error:', err);
        showUserError(String(err));
    }

    setLoading(false); // Always clear loading state on error
});
```

Wrap all MATLAB-event callbacks in try-catch on the JS side too:

```javascript
htmlComponent.addEventListener('resultReady', function(event) {
    try {
        const result = event.Data;
        updateDisplay(result);
    } catch (err) {
        console.error('Error handling result-ready:', err);
        showUserError('Failed to display result');
    } finally {
        setLoading(false);
    }
});
```

## Input Validation at the Bridge Boundary

Validate all data arriving from JavaScript before using it in MATLAB:

```matlab
function result = validateAndProcess(eventData)
    % Check required fields exist
    requiredFields = ["frequency", "amplitude", "plotType"];
    for f = requiredFields
        if ~isfield(eventData, f)
            error('uihtml:missingField', 'Missing required field: %s', f);
        end
    end

    % Cast and validate types
    freq     = double(eventData.frequency);
    amp      = double(eventData.amplitude);
    plotType = char(eventData.plotType);

    if ~isfinite(freq) || freq <= 0 || freq > 100
        error('uihtml:invalidValue', 'Frequency must be between 0 and 100; got %g', freq);
    end

    if ~ismember(plotType, {'sine', 'cosine', 'both'})
        error('uihtml:invalidValue', 'Invalid plot type: %s', plotType);
    end

    result = struct('frequency', freq, 'amplitude', amp, 'plotType', plotType);
end
```

**Validation rules:**
- Always cast JS values to the expected MATLAB type (`double()`, `char()`, `logical()`)
- Check `isfinite()` for numeric values — JS can send `NaN` or `Infinity`
- Validate string values against an allowed list with `ismember()`
- Use descriptive error IDs: `error('uihtml:tag', 'message %s', value)` — these propagate to the JS `Error` listener automatically via the try-catch wrapper

## JS-Side Input Validation

Validate on the JS side before sending — faster feedback, fewer MATLAB round trips:

```javascript
function onSubmit() {
    const freq = parseFloat(document.getElementById('freq').value);
    const amp  = parseFloat(document.getElementById('amp').value);
    const type = document.getElementById('plotType').value;

    if (!Number.isFinite(freq) || freq <= 0) {
        showUserError('Frequency must be a positive number');
        return;
    }

    if (!Number.isFinite(amp) || amp <= 0) {
        showUserError('Amplitude must be a positive number');
        return;
    }

    setLoading(true);
    window.htmlComponent.sendEventToMATLAB('updatePlot', {
        frequency: freq,
        amplitude: amp,
        plotType:  type
    });
}
```

**Both-sides validation is the correct pattern:** JS catches obvious user errors fast; MATLAB validates at the security and correctness boundary.

----

Copyright 2026 The MathWorks, Inc.

----
