function plan = buildfile
%BUILDFILE Build automation for the toolbox.

import matlab.buildtool.tasks.*

plan = buildplan(localfunctions);

% CleanTask (built-in) — deletes files declared in .Outputs of other tasks
% and clears the .buildtool/ incremental-build cache.
plan("clean") = CleanTask;

% CodeIssuesTask (built-in) — runs MATLAB Code Analyzer. Produces SARIF for
% CI integration (GitHub Code Scanning, VS Code). WarningThreshold=0 means
% the build fails on any warning — set to Inf to allow warnings through.
plan("check") = CodeIssuesTask("toolbox", ...
    WarningThreshold=0, ...
    Results="results/code-issues.sarif");

% MexTask (built-in) — compiles C/C++/Fortran source into MEX binaries.
% Output goes into the toolbox folder so MEX files ship with the package.
% Uses forEachFile to build one MEX per source file automatically.
% REMOVE THIS BLOCK if the project has no MEX source files.
plan("mex") = MexTask("mex/mymex.c", "toolbox");

% TestTask (built-in) — runs tests and produces coverage reports.
% The built-in task supports incremental builds: it skips when source and
% test files are unchanged since the last successful run.
% .addCodeCoverage produces both Cobertura XML (for CI tools) and .mat
% (for the coverage report task to inspect programmatically).
% To disable coverage reporting, remove the .addCodeCoverage() call.
plan("test") = TestTask("tests", ...
    SourceFiles="toolbox", ...
    Dependencies=["check" "mex"], ...
    TestResults="results/test-results.xml") ...
    .addCodeCoverage(["results/coverage.xml" "results/coverage.mat"]);

% coverageTask is CUSTOM because the built-in TestTask produces coverage
% reports but does not summarize or check them. This task loads the .mat
% results, logs per-file coverage, and warns if below the threshold.
% It does NOT fail the build — coverage is advisory. To make it a hard
% gate, replace context.log with context.assertTrue in the function below.
plan("coverage").Dependencies = "test";

% packageTask is CUSTOM because there is no built-in packaging task.
% It loads ToolboxOptions from toolboxPackaging.prj and produces the .mltbx.
plan("package").Dependencies = "coverage";

% Declaring .Outputs lets CleanTask know what to delete, and enables
% incremental build support (task skips if output already exists and
% inputs haven't changed).
plan("package").Outputs = "release/My_Toolbox.mltbx";

% DefaultTasks run on bare "buildtool" with no arguments.
% We default to quality checks + coverage report — packaging is an explicit
% action via "buildtool package".
plan.DefaultTasks = ["check" "test" "coverage"];
end

function coverageTask(context)
% Report code coverage and warn if below threshold (does not fail the build)
%
% Why custom instead of built-in:
%   - TestTask produces coverage reports but has no summary/threshold parameter
%   - This function loads the .mat coverage data from TestTask's output,
%     logs a per-file breakdown, and warns if below threshold
%   - Separating reporting from test execution means TestTask retains
%     incremental build support (skips when nothing changed)
%
% The context argument (TaskContext) provides:
%   - context.log()          — structured logging (respects buildtool verbosity)
%   - context.assertTrue()   — fails the task with a diagnostic message
%   - context.Plan.RootFolder — absolute path to project root
% Always use these instead of disp()/fprintf()/assert().

    coverageFile = fullfile("results", "coverage.mat");
    if ~isfile(coverageFile)
        context.log("Coverage data not found — skipping. Run the test task first.");
        return
    end

    data = load(coverageFile);
    covResult = data.Result;

    % coverageSummary (R2023b+) returns Nx2 matrix: [executed, total] per file.
    [summary, desc] = coverageSummary(covResult, "statement");
    lineRate = sum(summary(:,1)) / sum(summary(:,2));
    context.log(sprintf("Coverage: %.1f%%", lineRate * 100));

    % Per-file breakdown so the user can see where coverage is low.
    for i = 1:size(summary, 1)
        [~, name, ext] = fileparts(desc(i).statement(1).Filename);
        context.log(sprintf("  %s%s: %d/%d statements", ...
            name, ext, summary(i,1), summary(i,2)));
    end

    threshold = 0.80;
    if lineRate < threshold
        context.log(sprintf("WARNING: Coverage %.1f%% is below %.0f%% threshold", ...
            lineRate * 100, threshold * 100));
    end
end

function packageTask(context)
% Package toolbox into .mltbx
%
% Version is read from toolboxSpecification.m (single source of truth for the pipeline).
% If toolboxSpecification doesn't exist, falls back to the version in toolboxPackaging.prj.
%
% The UUID identifies the toolbox for update detection — it must remain
% stable across versions. Generate once with matlab.lang.internal.uuid.

    % Read version from toolboxSpecification if available (single source of truth)
    specFile = fullfile(context.Plan.RootFolder, "buildUtilities", "toolboxSpecification.m");
    if isfile(specFile)
        oldPath = addpath(fullfile(context.Plan.RootFolder, "buildUtilities"));
        raii = onCleanup(@()(path(oldPath)));
        spec = toolboxSpecification();
        version = spec.toolbox.version;
    else
        version = "";
    end

    opts = matlab.addons.toolbox.ToolboxOptions("toolboxPackaging.prj");

    % Apply version from spec (overrides PRJ value)
    if version ~= ""
        opts.ToolboxVersion = version;
    end

    % Output to release/ (not source-controlled). Spaces replaced with
    % underscores for cross-platform filename compatibility.
    releaseFolderName = "release";
    mltbxFileName = strrep(opts.ToolboxName, " ", "_") + ".mltbx";
    opts.OutputFile = fullfile(releaseFolderName, mltbxFileName);

    if ~isfolder(releaseFolderName), mkdir(releaseFolderName); end
    matlab.addons.toolbox.packageToolbox(opts);

    context.assertTrue(isfile(opts.OutputFile), "Package was not created");
    info = dir(opts.OutputFile);
    context.log(sprintf("Package: %s v%s (%.1f KB)", opts.OutputFile, opts.ToolboxVersion, info.bytes / 1024));
end

% Copyright 2026 The MathWorks, Inc.
