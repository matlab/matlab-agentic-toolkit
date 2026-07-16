# Semantic Conventions for MATLAB Tracing

OpenTelemetry semantic conventions provide standardized attribute names so telemetry data integrates cleanly with backends (Jaeger, Grafana Tempo, etc.) and is consistent across services.

## Attribute Naming Rules

- **Lowercase** with **dot-separated** namespaces: `service.name`, `http.request.method`
- **snake_case** within components: `http.response.status_code`
- **`{object}.{property}`** pattern: `file.path`, `db.system`
- Never use camelCase or UPPER_CASE for attribute keys
- Prefer established namespaces over inventing new ones

## General Code Attributes

Use for spans that wrap function calls:

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `code.function.name` | string | Function name | `"processData"` |
| `code.namespace` | string | Package or class | `"mypackage"` |
| `code.file.path` | string | Source file path | `"src/processData.m"` |

These are optional — span names already convey the function. Use when extra context helps (e.g., disambiguating overloaded names).

## File I/O Attributes

Use for spans wrapping file operations (`readtable`, `writetable`, `load`, `save`, `fopen`):

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `file.path` | string | Full file path | `"/data/input.csv"` |
| `file.name` | string | File name only | `"input.csv"` |
| `file.size` | int | File size in bytes | `1048576` |
| `file.extension` | string | File extension | `"csv"` |

```matlab
span = startSpan(tr, "loadData", SpanKind="internal");
scope = makeCurrent(span); %#ok<NASGU>
setAttributes(span, "file.path", filepath, "file.extension", "csv");

data = readtable(filepath);

setAttributes(span, "file.size", dir(filepath).bytes);
setStatus(span, "Ok");
```

## HTTP Client Attributes

Use for spans wrapping `webread`, `webwrite`, `websave`, or `weboptions`-based calls. Set `SpanKind="client"`.

### Span naming

Format: `{HTTP_METHOD}` (e.g., `"GET"`, `"POST"`). Append a route template if known: `"GET /api/sensors"`.

### Required attributes

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `http.request.method` | string | HTTP method | `"GET"`, `"POST"` |
| `url.full` | string | Full request URL (no credentials) | `"https://api.example.com/data"` |
| `server.address` | string | Server hostname or IP | `"api.example.com"` |
| `server.port` | int | Server port | `443` |

### Conditional attributes

| Attribute | When | Example |
|-----------|------|---------|
| `http.response.status_code` | After response received | `200`, `404`, `500` |
| `error.type` | On error | `"timeout"`, `"404"` |

### Example

```matlab
function data = fetchSensorData(baseUrl, sensorId)
    tr = opentelemetry.trace.getTracer("sensorService");
    url = baseUrl + "/sensors/" + sensorId + "/readings";
    span = startSpan(tr, "GET /sensors/{id}/readings", SpanKind="client");
    scope = makeCurrent(span); %#ok<NASGU>
    setAttributes(span, ...
        "http.request.method", "GET", ...
        "url.full", url, ...
        "server.address", extractHost(baseUrl), ...
        "server.port", 443);

    try
        data = webread(url);
        setAttributes(span, "http.response.status_code", 200);
    catch ME
        recordException(span, ME);
        setStatus(span, "Error", ME.message);
        rethrow(ME);
    end

    setStatus(span, "Ok");
end

function host = extractHost(url)
    parts = split(extractAfter(url, "://"), "/");
    host = parts(1);
end
```

## Database Attributes

Use for spans wrapping Database Toolbox calls (`fetch`, `sqlread`, `execute`). Set `SpanKind="client"`.

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `db.system` | string | Database system | `"mysql"`, `"postgresql"`, `"sqlite"` |
| `db.operation.name` | string | Operation type | `"SELECT"`, `"INSERT"` |
| `db.collection.name` | string | Table name | `"sensor_readings"` |
| `server.address` | string | Database host | `"db.example.com"` |
| `server.port` | int | Database port | `5432` |

## Domain-Specific Attributes

For MATLAB-specific computations where no standard convention exists, use a descriptive namespace:

| Pattern | Example namespace | Example attributes |
|---------|-------------------|-------------------|
| Signal processing | `signal.*` | `signal.sample_rate`, `signal.num_channels` |
| Simulation | `simulation.*` | `simulation.time_step`, `simulation.duration` |
| Optimization | `optimization.*` | `optimization.algorithm`, `optimization.iterations` |
| Data processing | `data.*` | `data.input_rows`, `data.output_rows` |

Rules for custom namespaces:
- Use a short, descriptive prefix relevant to the domain
- Keep attribute names general enough to be reusable
- Use the same namespace across all functions in a workflow
- Prefer plural nouns for counts: `data.rows_processed` not `data.row_processed`

### Example

```matlab
function result = filterSignal(data, fs, cutoff)
    tr = opentelemetry.trace.getTracer("signalPipeline");
    span = startSpan(tr, "filterSignal");
    scope = makeCurrent(span); %#ok<NASGU>
    setAttributes(span, ...
        "signal.sample_rate", fs, ...
        "signal.cutoff_frequency", cutoff, ...
        "signal.num_samples", height(data));

    result = lowpass(data, cutoff, fs);

    setAttributes(span, "signal.output_samples", height(result));
    setStatus(span, "Ok");
end
```

## Choosing Between Standard and Custom Conventions

1. If the operation maps to a recognized category (HTTP, file I/O, database), use the standard conventions
2. If the operation is domain-specific (signal processing, simulation, financial modeling), use a descriptive custom namespace
3. Never mix standard and custom for the same concept — pick one and be consistent within the workflow

----

Copyright 2026 The MathWorks, Inc.

----
