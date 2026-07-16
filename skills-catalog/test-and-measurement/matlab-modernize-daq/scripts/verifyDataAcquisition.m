function report = verifyDataAcquisition(d, sourceFile, options)
%verifyDataAcquisition Static checks for a DataAcquisition object before live execution.
%   Catches the four highest-frequency silent gaps in session->modern
%   DAQ ports: missing ErrorOccurredFcn, evt.Data/evt.TimeStamps in callback
%   source, wait(d) tokens, and src.UserData.X = src.UserData.X + ...
%   field-mutation. Optionally also flags discouraged session-API tokens.
%
%   report = verifyDataAcquisition(d) checks the object only.
%   report = verifyDataAcquisition(d, sourceFile) also greps the source.
%   report = verifyDataAcquisition(d, sourceFile, "Strict", true) treats
%   warnings as failures (returns Pass = false on any warning).
%
%   The returned report is a struct with fields:
%     Pass            (logical) overall pass/fail
%     ObjectChecks    (struct) results of object-state checks
%     SourceChecks    (struct) results of source-file string checks
%     Warnings        (string array) all warning messages
%     Errors          (string array) all error messages
%
%   Example:
%     d = daq("ni");
%     addinput(d, "Dev1", "ai0", "Voltage");
%     d.Rate = 1000;
%     d.ScansAvailableFcn = @(src, ~) read(src, 100, "OutputFormat", "Matrix");
%     report = verifyDataAcquisition(d, "myAcquireScript.m");
%     if ~report.Pass
%         disp(report.Errors);
%     end

    arguments
        d                       (1, 1) daq.interfaces.DataAcquisition
        sourceFile              (1, 1) string                                 = ""
        options.Strict          (1, 1) logical                                = false
    end

    warnings = string.empty(0, 1);
    errors   = string.empty(0, 1);

    % ------------- Object checks -------------
    objChecks = struct();

    % Check 1: ErrorOccurredFcn must be wired if any other *Fcn is set.
    hasScansAvailable = ~isempty(d.ScansAvailableFcn);
    hasScansRequired  = ~isempty(d.ScansRequiredFcn);
    hasErrorOccurred  = ~isempty(d.ErrorOccurredFcn);

    objChecks.ErrorOccurredFcnWired = hasErrorOccurred;
    if (hasScansAvailable || hasScansRequired) && ~hasErrorOccurred
        errors(end+1, 1) = ...
            "ErrorOccurredFcn is not wired but ScansAvailableFcn or " + ...
            "ScansRequiredFcn is set. Callback exceptions will be silently " + ...
            "swallowed. Set d.ErrorOccurredFcn = @(~, evt) " + ...
            "fprintf(""DAQ error: %s\n"", evt.Error.message);";
    end

    % Check 2: ScansAvailableFcnCount must be > 0 if ScansAvailableFcn is set.
    if hasScansAvailable && d.ScansAvailableFcnCount <= 0
        warnings(end+1, 1) = ...
            "ScansAvailableFcn is set but ScansAvailableFcnCount is " + ...
            string(d.ScansAvailableFcnCount) + ". Callback may never fire.";
    end
    objChecks.ScansAvailableFcnCount = d.ScansAvailableFcnCount;

    % Check 3: Trigger objects -- if any, confirm Source/Destination are set.
    objChecks.Triggers = "(none)";
    if isprop(d, "DigitalTriggers") && ~isempty(d.DigitalTriggers)
        for k = 1:numel(d.DigitalTriggers)
            t = d.DigitalTriggers(k);
            if t.Source == "" || t.Destination == ""
                errors(end+1, 1) = ...
                    "DigitalTriggers(" + k + ") has empty Source or Destination."; %#ok<AGROW>
            end
        end
        objChecks.Triggers = "Source=" + string({d.DigitalTriggers.Source}) + ...
                             " Destination=" + string({d.DigitalTriggers.Destination});
    end

    % Check 4: Channel inventory.
    if isempty(d.Channels)
        errors(end+1, 1) = "DataAcquisition has no channels. Call addinput or addoutput first.";
    end
    objChecks.NumChannels = numel(d.Channels);

    % ------------- Source-file string checks -------------
    srcChecks = struct();
    srcChecks.Performed = false;

    if sourceFile ~= "" && isfile(sourceFile)
        srcChecks.Performed = true;
        srcChecks.File      = sourceFile;
        src = string(fileread(sourceFile));

        % Check S1: wait(d) or wait(<varname>) where the var is a DataAcquisition.
        % Conservatively flag any wait(<single-token>) call.
        if contains(src, regexpPattern("wait\s*\(\s*\w+\s*\)"))
            errors(end+1, 1) = ...
                "Source contains wait(<obj>) call. wait() does not exist on " + ...
                "daq.interfaces.DataAcquisition. Use 'while d.Running, pause(0.05); end' instead.";
        end

        % Check S2: evt.Data or evt.TimeStamps inside callbacks.
        if contains(src, "evt.Data") || contains(src, "evt.TimeStamps")
            errors(end+1, 1) = ...
                "Source contains 'evt.Data' or 'evt.TimeStamps'. The modern " + ...
                "callback evt is matlabshared.asyncio.buffer.ElementsAvailableInfo " + ...
                "and exposes only NumElementsAvailable. Use " + ...
                "read(src, src.ScansAvailableFcnCount, 'OutputFormat', 'Matrix') instead.";
        end

        % Check S3: src.UserData field mutation pattern.
        % Match: src.UserData.<word> = src.UserData.<word>  (the field re-references)
        if ~isempty(regexp(src, "\w+\.UserData\.\w+\s*=\s*\w+\.UserData\.\w+", "once"))
            errors(end+1, 1) = ...
                "Source contains 'src.UserData.X = src.UserData.X + ...' " + ...
                "field-mutation pattern. This does not persist across callback fires. " + ...
                "Use a nested function, handle class, or whole-struct rewrite. " + ...
                "See callback-state-patterns.md.";
        end

        % Check S4: discouraged (legacy) session-API tokens.
        legacyTokens = ["daq.createSession", "addAnalogInputChannel", ...
            "addAnalogOutputChannel", "addCounterInputChannel", ...
            "addCounterOutputChannel", "addDigitalChannel", ...
            "addTriggerConnection", "addClockConnection", ...
            "queueOutputData", "outputSingleScan", "startBackground", ...
            "startForeground", "NotifyWhenDataAvailableExceeds", ...
            "NotifyWhenScansQueuedBelow", "IsContinuous", ...
            "ExternalTriggerTimeout", "DurationInSeconds", ...
            "daq.getDevices", "daq.getVendors", "daq.reset"];
        found = string.empty;
        for tok = legacyTokens
            if contains(src, tok)
                found(end+1) = tok; %#ok<AGROW>
            end
        end
        srcChecks.LegacySessionTokens = found;
        if ~isempty(found)
            warnings(end+1, 1) = ...
                "Source contains discouraged (legacy) session-API tokens: " + ...
                strjoin(found, ", ") + ". See session-to-modern-mapping.md.";
        end
    elseif sourceFile ~= ""
        warnings(end+1, 1) = "Source file '" + sourceFile + "' not found; skipped string checks.";
    end

    % ------------- Compose report -------------
    report = struct();
    report.ObjectChecks = objChecks;
    report.SourceChecks = srcChecks;
    report.Warnings     = warnings;
    report.Errors       = errors;
    report.Pass         = isempty(errors) && (~options.Strict || isempty(warnings));

    if ~report.Pass
        fprintf("verifyDataAcquisition: FAIL\n");
        for k = 1:numel(errors)
            fprintf("  ERROR: %s\n", errors(k));
        end
        for k = 1:numel(warnings)
            fprintf("  WARN:  %s\n", warnings(k));
        end
    else
        fprintf("verifyDataAcquisition: PASS\n");
        for k = 1:numel(warnings)
            fprintf("  WARN:  %s\n", warnings(k));
        end
    end
end

% Copyright 2026 The MathWorks, Inc.
