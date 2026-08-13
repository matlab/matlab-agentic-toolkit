# Buildfile Variants

## Variant: No MEX (most projects)

If no C/C++/Fortran source files are detected, omit the `mex` task entirely and remove `"mex"` from the test task's dependencies:

```matlab
plan("test") = TestTask("tests", ...
    SourceFiles="toolbox", ...
    Dependencies="check", ...
    TestResults="results/test-results.xml") ...
    .addCodeCoverage(["results/coverage.xml" "results/coverage.mat"]);
```

## Variant: Multiple MEX Files

When the project has multiple MEX source files, use `MexTask.forEachFile` to build one MEX per source file:

```matlab
% Builds one MEX per .c file in mex/, outputs to toolbox/
plan("mex") = MexTask.forEachFile("mex/*.c", "toolbox");
```

With common helper files shared across all MEX builds:

```matlab
plan("mex") = MexTask.forEachFile("mex/*.c", "toolbox", ...
    CommonSourceFiles="mex/common/utils.c", ...
    Options="-O");
```

## Variant: Single MEX with Multiple Sources

When multiple source files compile into a single MEX binary:

```matlab
plan("mex") = MexTask(["mex/main.c" "mex/helper.c"], "toolbox", ...
    Filename="myMex", ...
    Options=["-O" "-DNDEBUG"]);
```

## Variant: MEX with Debug Build

Add a separate debug MEX task for development:

```matlab
plan("mex") = MexTask("mex/compute.c", "toolbox", ...
    Options="-O");

plan("mex-debug") = MexTask("mex/compute.c", "toolbox-debug", ...
    Options="-g", ...
    Description="Build MEX with debug symbols");
```

## Variant: No Coverage Task

If the user does not want coverage reporting at all (or the project has no meaningful coverage target yet), remove the `coverage` task and have `package` depend directly on `test`:

```matlab
plan("test") = TestTask("tests", ...
    SourceFiles="toolbox", ...
    Dependencies="check", ...
    TestResults="results/test-results.xml") ...
    .addCodeCoverage("results/coverage.xml");

plan("package").Dependencies = "test";
plan.DefaultTasks = ["check" "test"];
```

This still produces Cobertura XML coverage for CI visibility but skips the per-file summary and threshold warning. The `.mat` output can be omitted since nothing inspects it programmatically.

## Variant: No toolboxPackaging.prj

If no PRJ exists (early development, or user prefers fully programmatic packaging). **Never hardcode the version** — read it from `toolboxSpecification.m` so there's a single source of truth that Phase 8 (publish) updates:

```matlab
function packageTask(context)
% Package toolbox into .mltbx
% Version is read from toolboxSpecification.m — never hardcode it here.
    toolboxFolder = fullfile(context.Plan.RootFolder, "toolbox");
    uuid = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"; % Generated once, committed

    % Read version from spec (single source of truth)
    oldPath = addpath(fullfile(context.Plan.RootFolder, "buildUtilities"));
    raii = onCleanup(@()(path(oldPath)));
    spec = toolboxSpecification();

    opts = matlab.addons.toolbox.ToolboxOptions(toolboxFolder, uuid);
    opts.ToolboxName = spec.toolbox.name;
    opts.ToolboxVersion = spec.toolbox.version;
    opts.Summary = spec.toolbox.summary;
    opts.OutputFile = fullfile("release", strrep(spec.toolbox.name, " ", "_") + ".mltbx");

    if ~isfolder("release"), mkdir("release"); end
    matlab.addons.toolbox.packageToolbox(opts);

    context.assertTrue(isfile(opts.OutputFile), "Package was not created");
    context.log(sprintf("Package: %s v%s", opts.OutputFile, opts.ToolboxVersion));
end
```

Generate the UUID once with `matlab.lang.internal.uuid` and commit it — it must remain stable across builds (it identifies the toolbox for update detection).

## Variant: Coverage Report from Cobertura XML (existing test task)

When integrating with an existing buildfile whose test task produces Cobertura XML (not `.mat`), parse the `line-rate` attribute directly from the XML root element:

```matlab
function coverageTask(context)
% Report coverage from Cobertura XML produced by existing test task
    coverageFile = fullfile(context.Plan.RootFolder, "reports", "codecoverage.xml");
    if ~isfile(coverageFile)
        context.log("No coverage data found — skipping.");
        return
    end

    doc = xmlread(coverageFile);
    root = doc.getDocumentElement();
    lineRate = str2double(string(root.getAttribute("line-rate")));
    context.log(sprintf("Coverage: %.1f%%", lineRate * 100));

    threshold = 0.80;
    if lineRate < threshold
        context.log(sprintf("WARNING: Coverage %.1f%% is below %.0f%% threshold", ...
            lineRate * 100, threshold * 100));
    end
end
```

Use this variant when the test task writes Cobertura XML via `CoberturaFormat` but does NOT produce a `.mat` file. Adjust the path (`reports/codecoverage.xml`) to match whatever the existing test task actually writes.

## Variant: Coverage with Decision-Level Metrics

For projects that need deeper coverage analysis (requires MATLAB Test toolbox):

```matlab
plan("test") = TestTask("tests", ...
    SourceFiles="toolbox", ...
    Dependencies="check", ...
    TestResults="results/test-results.xml") ...
    .addCodeCoverage(["results/coverage.xml" "results/coverage.mat"], ...
        MetricLevel="decision");
```

Then in the `coverageTask`, use `"decision"` instead of `"statement"`:

```matlab
[summary, desc] = coverageSummary(covResult, "decision");
```

----

Copyright 2026 The MathWorks, Inc.

----
