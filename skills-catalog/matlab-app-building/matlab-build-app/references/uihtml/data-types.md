# Data Types

Data crossing the bridge is automatically converted between MATLAB and JavaScript types.

## Type Conversion Table

| MATLAB Type | JavaScript Type | Notes |
|---|---|---|
| `double`, `single` | `number` | NaN and Inf transfer correctly |
| `char`, `string` | `string` | |
| `logical` | `boolean` | |
| `struct` | `object` | Field names become property names |
| `struct array` | `array of objects` | |
| `cell array` | `array` | Homogeneous cells only; avoid nested cells |
| `numeric array` | `array` | Transfers as flat array; reshape on JS side if needed |
| `table` | Not supported | Convert with `table2struct(T)` before sending |
| `datetime` | Not supported | Convert with `char(dt)` or `posixtime(dt)` |
| `categorical` | Not supported | Convert with `cellstr(c)` |

## Serialization Rules

- MUST convert unsupported types (table, datetime, categorical) before sending
- MUST use struct or struct arrays for complex data — these map cleanly to JSON objects
- NEVER send deeply nested cell arrays — flatten or convert to struct arrays
- Prefer sending the minimum data needed — do not send entire datasets when a summary suffices
- MATLAB field names are case-sensitive in JavaScript — match exactly

## Receiving Data from MATLAB in JS

Cast values explicitly on the JS side:

```javascript
htmlComponent.addEventListener('dataReady', function(event) {
    const d = event.Data;
    const arr = Array.from(d.values); // numeric array → JS Array
    const n   = Number(d.count);      // scalar → JS number
    const s   = String(d.label);      // string → JS string
});
```

## Large Data Transfer

For large datasets, paginate rather than sending everything at once.

**MATLAB — send summary first, then respond to page requests:**
```matlab
function handleEvent(src, event)
    T = evalin('base', 'T');
    switch event.HTMLEventData.type
        case 'init'
            summary = struct('totalRows', height(T), ...
                'columns', {T.Properties.VariableNames});
            sendEventToHTMLSource(src, 'dataSummary', summary);
        case 'requestPage'
            pageNum  = event.HTMLEventData.page;
            pageSize = 100;
            startRow = (pageNum - 1) * pageSize + 1;
            endRow   = min(pageNum * pageSize, height(T));
            sendEventToHTMLSource(src, 'pageData', ...
                table2struct(T(startRow:endRow, :)));
    end
end
```

**JavaScript — request pages on demand:**
```javascript
htmlComponent.addEventListener('dataSummary', function(event) {
    totalRows = event.Data.totalRows;
    requestPage(1);
});

function requestPage(n) {
    window.htmlComponent.sendEventToMATLAB('requestPage', { page: n });
}
```

----

Copyright 2026 The MathWorks, Inc.

----
