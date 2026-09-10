# Justification Filter Rules (XML)

Create a filter rule XML file to justify uncovered coverage outcomes. The file is reusable across runs and can be version-controlled alongside the project.

## XML Schema

```xml
<?xml version="1.0" encoding="utf-8"?>
<filter>
    <rule type="DECISION" fileName="myFile.m" functionName="myFunction"
          expr="if (x > 0)" index="3" mode="JUSTIFIED"
          rationale="Reason this outcome is unreachable"/>
    <!-- Add more rules as needed -->
</filter>
```

## Attribute Reference

| Attribute | Required | Description |
|-----------|----------|-------------|
| `type` | Yes | Coverage metric type. **Must be uppercase.** |
| `fileName` | Yes | Source file name (not full path, just the filename) |
| `functionName` | Yes | Function containing the decision |
| `expr` | Yes | The decision/condition expression text as it appears in source |
| `index` | Yes | 1-based index of this decision within the function |
| `mode` | Yes | Always `"JUSTIFIED"` |
| `rationale` | Yes | Free text explaining why this outcome is unreachable |

## Valid `type` Values

Justifications can only be applied up to **decision level**. Condition and MC/DC outcomes cannot be justified.

| Value | When to use |
|-------|-------------|
| `DECISION` | Justifying a decision outcome (true/false branch) |

These **must** be uppercase. Lowercase will not match.

## Usage

### Supply at collection time

Justifications are applied during the test run — justified outcomes appear as covered in the result:

```matlab
filterFile = fullfile(projectRoot, "resources", "CodeCoverageFilter.xml");

plugin = CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, ...
    Metrics="decision", Filter=filterFile);
```

### Apply after collection

Apply to an existing coverage result:

```matlab
filteredResult = coverageResult.applyFilter(filterFile);
generateHTMLReport(filteredResult, "coverage-report");
```

### Both `forFolder` and `forFile` support `Filter`

```matlab
% forFolder
CodeCoveragePlugin.forFolder("src", IncludingSubfolders=true, ...
    Producing=format, Metrics="mcdc", Filter="filters/mcdc_justifications.xml")

% forFile
CodeCoveragePlugin.forFile("src/myAlgorithm.m", ...
    Producing=format, Metrics="decision", Filter="filters/justifications.xml")
```

## Finding the `index` Value

Count decisions from the top of the function, starting at 1. Every `if`, `elseif`, `for`, `while`, `switch` case, and short-circuit operator (`&&`/`||`) in a compound expression counts as a decision point.

Use gap analysis output to correlate — the order matches what `coverageSummary` reports in its description struct.

## Complete Workflow Example

```matlab
% 1. Collect coverage and identify gaps
format = CoverageResult;
plugin = CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, Metrics="decision");
runner = TestRunner.withTextOutput;
runner.addPlugin(plugin);
results = runner.run(TestSuite.fromFolder("tests"));
coverageResult = format.Result;

% 2. Analyze gaps
[s, d] = coverageSummary(coverageResult, "decision");
fprintf('Decision coverage: %d/%d (%.1f%%)\n', s(1), s(2), 100*s(1)/s(2));

% 3. Create filter file for structurally unreachable outcomes
filterXml = fullfile(pwd, "resources", "CodeCoverageFilter.xml");
xmlContent = [ ...
    '<?xml version="1.0" encoding="utf-8"?>', newline, ...
    '<filter>', newline, ...
    '    <rule type="DECISION" fileName="shortest_path.m" ', ...
    'functionName="shortest_path" ', ...
    'expr="for iterStep = 1:nodeCnt" index="8" ', ...
    'mode="JUSTIFIED" ', ...
    'rationale="Loop always terminates early via return before all iterations complete"/>', newline, ...
    '    <rule type="DECISION" fileName="shortest_path.m" ', ...
    'functionName="shortest_path" ', ...
    'expr="if (pathLength==realmax)" index="13" ', ...
    'mode="JUSTIFIED" ', ...
    'rationale="If distance were realmax, min==max triggers early return before this check"/>', newline, ...
    '</filter>'];
writelines(string(xmlContent), filterXml);

% 4. Apply and verify
filteredResult = coverageResult.applyFilter(filterXml);
[s2, d2] = coverageSummary(filteredResult, "decision");
fprintf('After justification: %d/%d (%.1f%%)\n', s2(1), s2(2), 100*s2(1)/s2(2));
```

## Best Practices

- Store filter XML in `resources/` folder within the project (version-controllable)
- Use descriptive rationale — safety auditors will read these
- One filter file per project is typical; add rules as justifications are confirmed
- The same filter file can be reused across test runs and CI builds via `Filter=` parameter
- Review justifications when source code changes — index values may shift

----

Copyright 2026 The MathWorks, Inc.

----
