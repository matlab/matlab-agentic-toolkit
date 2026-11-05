function designReportReadback(appClass, specFile, sourceFile)
%designReportReadback  Emit a hmi-report/1 design report for a built HMI.
%
% Workflow step 11. Copy this file beside the built app VERBATIM, KEEPING THIS
% FILENAME (designReportReadback - a valid MATLAB identifier). Do NOT edit it,
% do NOT rename it, and do NOT re-author your own readback: a reshaped copy
% drifts from the schema and drops keys the evals grade (anti-pattern #33).
% Call it with the built app's class name and its reviewed spec file, e.g.
%
%     designReportReadback("BoilerHMI", "BoilerHMI-hmi-spec.md")
%
% It constructs the app, reads the real property values back off the live
% figure, extracts the live-data callback and the protocol write calls from the
% app source, writes design-report.json in the current folder, and deletes the app.
%
% Every number in the report comes from the constructed figure or from the app
% source. Do not hand-write values, do not edit the JSON afterwards, and do not
% print a draft report before running this - the grader reads the first match in
% the session, so a narrated draft is read instead of the file. Contract and key
% definitions: assets/design-report-schema.json. Anti-pattern: common-mistakes #33.

arguments
    appClass   (1,1) string             % class name of the built app
    specFile   (1,1) string             % the reviewed spec beside it
    sourceFile (1,1) string = ""        % "" resolves <appClass>.m on the path
end

%% Resolve the app source (a .mlapp is a binary - source-derived keys go to -1)
if strlength(sourceFile) == 0
    resolved = which(char(appClass));
    if isempty(resolved)
        resolved = fullfile(pwd, char(appClass) + ".m");
    end
    sourceFile = string(resolved);
end
if endsWith(sourceFile, ".m") && isfile(sourceFile)
    src = string(fileread(sourceFile));
else
    src = "";      % source-derived keys report -1 / "" rather than a guess
end

%% Construct the app - this is the launch the report is provenance for
app = feval(char(appClass));
drawnow
if isprop(app, 'UIFigure')
    fig = app.UIFigure;
else
    openFigures = findall(groot, 'Type', 'figure');
    fig = openFigures(1);
end

%% Provenance, figure and palette
report = struct();          % fresh - a stale struct would append keys out of order
report.reportFormat  = 'hmi-report/1';
report.appName       = char(appClass);
report.buildPath     = char(sourceFile);
report.specFile      = char(specFile);
report.matlabRelease = version('-release');
report.readbackTime  = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
report.figureColor   = fig.Color;
if isprop(fig, 'Theme') && ~isempty(fig.Theme)
    report.figureTheme = char(string(fig.Theme.BaseColorStyle));
else
    report.figureTheme = '';
end

%% Alarm banner - the full-width label on the lowest row it spans
labels = findall(fig, 'Type', 'uilabel');
report.bannerGridRow         = -1;
report.bannerSpansAllColumns = false;
report.bannerText            = '';
bestRow = Inf;
for k = 1:numel(labels)
    [row, spansAll] = layoutSpan(labels(k));
    if spansAll && row < bestRow
        bestRow                      = row;
        report.bannerGridRow         = row;
        report.bannerSpansAllColumns = true;
        report.bannerText            = char(string(labels(k).Text));
    end
end

%% Gauges and alarm bands
gauges = matlab.graphics.Graphics.empty;
for t = ["uilineargauge", "uigauge", "uisemicirculargauge", "uininetydegreegauge"]
    gauges = [gauges; findall(fig, 'Type', char(t))];   %#ok<AGROW>
end
report.gaugeCount                = numel(gauges);
report.bandedGaugeCount          = 0;
report.bandsOutsideLimitsGaugeCount = 0;
report.grayNormalBandGaugeCount  = 0;
report.greenBandGaugeCount       = 0;
for k = 1:numel(gauges)
    bands = bandRows(gauges(k));
    if isempty(bands)
        continue
    end
    report.bandedGaugeCount = report.bandedGaugeCount + 1;
    lims = gauges(k).ScaleColorLimits;
    if ~isempty(lims) && (min(lims(:)) < gauges(k).Limits(1) || max(lims(:)) > gauges(k).Limits(2))
        report.bandsOutsideLimitsGaugeCount = report.bandsOutsideLimitsGaugeCount + 1;
    end
    if any(all(abs(bands - [0.5 0.5 0.5]) <= 0.02, 2))
        report.grayNormalBandGaugeCount = report.grayNormalBandGaugeCount + 1;
    end
    if any(bands(:,2) > 0.4 & bands(:,1) < 0.4 & bands(:,3) < 0.4)
        report.greenBandGaugeCount = report.greenBandGaugeCount + 1;
    end
end

%% Command buttons - a saturated face is a violation unless it is the E-Stop
buttons = [findall(fig, 'Type', 'uibutton'); findall(fig, 'Type', 'uistatebutton')];
report.buttonCount                 = numel(buttons);
report.saturatedCommandButtonCount = 0;
for k = 1:numel(buttons)
    face    = buttons(k).BackgroundColor;
    isEStop = ~isempty(regexpi(string(buttons(k).Text), 'e-?stop|emergency', 'once'));
    if ~isEStop && (max(face) - min(face)) > 0.35
        report.saturatedCommandButtonCount = report.saturatedCommandButtonCount + 1;
    end
end

%% Readouts and trends
report.numericReadoutCount     = numel(findall(fig, 'Type', 'uinumericeditfield'));
axs = findall(fig, 'Type', 'axes');
report.trendAxisCount          = numel(axs);
report.autoscaleTrendAxisCount = 0;
report.trendsWithThresholdLines = 0;
report.trendsWithUnitLabel     = 0;
for k = 1:numel(axs)
    if strcmp(axs(k).YLimMode, 'auto')
        report.autoscaleTrendAxisCount = report.autoscaleTrendAxisCount + 1;
    end
    if ~isempty(findall(axs(k), '-isa', 'matlab.graphics.chart.decoration.ConstantLine'))
        report.trendsWithThresholdLines = report.trendsWithThresholdLines + 1;
    end
    if strlength(strtrim(strjoin(string(axs(k).YLabel.String)))) > 0
        report.trendsWithUnitLabel = report.trendsWithUnitLabel + 1;
    end
end
traces = findall(fig, '-isa', 'matlab.graphics.animation.AnimatedLine');
report.animatedLineCount = numel(traces);
if report.animatedLineCount == 0 && strlength(src) > 0
    % A trend's animatedline is often created lazily inside the data-change
    % callback, so a construction-time readback with no live data finds none
    % on the figure even though the app wires one correctly. Fall back to the
    % source and count animatedline() creations there.
    report.animatedLineCount = countMatches(src, '\<animatedline\s*\(');
end
report.trendMaxNumPoints = -1;                  % -1 = no animatedline at all
if ~isempty(traces)
    caps = arrayfun(@(h) h.MaximumNumPoints, traces);
    if any(isinf(caps))
        report.trendMaxNumPoints = 0;           % 0 = an unbounded trend buffer
    else
        report.trendMaxNumPoints = min(caps);
    end
end

%% Writable controls and their confirm dialogs
writables = matlab.graphics.Graphics.empty;
for t = ["uispinner", "uistatebutton", "uiswitch", "uitoggleswitch", ...
         "uirockerswitch", "uiknob", "uidiscreteknob", "uislider"]
    writables = [writables; findall(fig, 'Type', char(t))];   %#ok<AGROW>
end
report.writablesTotal     = numel(writables);
report.confirmDialogCount = countMatches(src, 'uiconfirm\s*\(');
[report.writePathsTotal, report.writePathsWithConfirm, ...
    report.writePathsWithoutConfirm] = writePaths(src);

%% Data wiring, read off the source rather than declared
report.dataWiringMechanism = wiringMechanism(src);
report.pollPeriodSeconds   = numberAfter(src, '[Pp]eriod''?\s*[,=]\s*');

%% Modal dialogs inside the live-data path (write-failure alerts are legitimate)
liveCallback = liveDataCallback(src);
if strlength(src) == 0
    report.modalAlarmDialogCount = -1;
else
    report.modalAlarmDialogCount = countMatches(liveCallback + " ", ...
        'uialert\s*\(|uiconfirm\s*\(|msgbox\s*\(|errordlg\s*\(|warndlg\s*\(');
end

%% Extracted source - always last, so every scalar lands before byte 10,000
report.writeCalls      = writeCallLines(src);
report.callbackExcerpt = char(capChars(liveCallback, 3000));

%% Emit - compact, top level of the working folder, never a subfolder
json = jsonencode(report);
reportPath = fullfile(pwd, 'design-report.json');
fid = fopen(reportPath, 'w');
fwrite(fid, json);
fclose(fid);
fprintf('wrote %s (%d bytes)\n', reportPath, numel(json));

%% Tear down and confirm nothing leaked
delete(app)
drawnow
fprintf('figures after delete: %d | timers in session: %d\n', ...
    numel(findall(groot, 'Type', 'figure')), numel(timerfindall));

end

%% ---- local functions ----

function [row, spansAll] = layoutSpan(h)
    % Grid row of h, and whether it spans every column of its parent grid.
    row = Inf;
    spansAll = false;
    if ~isprop(h, 'Layout') || ~isa(h.Parent, 'matlab.ui.container.GridLayout')
        return
    end
    row  = min(h.Layout.Row);
    cols = h.Layout.Column;
    spansAll = numel(h.Parent.ColumnWidth) > 1 && ...
        min(cols) == 1 && max(cols) == numel(h.Parent.ColumnWidth);
end

function bands = bandRows(g)
    % ScaleColors as an N-by-3 double, whatever form it was set in.
    bands = zeros(0, 3);
    if ~isprop(g, 'ScaleColors') || isempty(g.ScaleColors)
        return
    end
    sc = g.ScaleColors;
    if iscell(sc) || isstring(sc) || ischar(sc)
        bands = validatecolor(sc, 'multiple');
    else
        bands = sc;
    end
end

function n = countMatches(haystack, pattern)
    if strlength(haystack) == 0
        n = -1;                             % -1 = source unreadable (.mlapp)
        return
    end
    n = numel(regexp(haystack, pattern, 'start'));
end

function v = numberAfter(haystack, pattern)
    v = -1;
    if strlength(haystack) == 0
        return
    end
    tok = regexp(haystack, string(pattern) + "([\d.]+)", 'tokens', 'once');
    if ~isempty(tok)
        v = str2double(tok{1});
    end
end

function mech = wiringMechanism(src)
    if strlength(src) == 0
        mech = '';
        return
    end
    hasSub   = ~isempty(regexp(src, '\<subscribe\s*\(', 'once'));
    hasTimer = ~isempty(regexp(src, '\<timer\s*\(', 'once'));
    if hasSub && hasTimer
        mech = 'subscribe+timer';
    elseif hasSub
        mech = 'subscribe';
    elseif hasTimer
        mech = 'timer';
    else
        mech = 'none';
    end
end

function bodies = functionBodies(src)
    % Struct of function name -> body text, for every function in the file.
    bodies = struct();
    if strlength(src) == 0
        return
    end
    starts = regexp(src, '(?m)^[ \t]*function\>', 'start');
    for k = 1:numel(starts)
        if k < numel(starts)
            stop = starts(k+1) - 1;
        else
            stop = strlength(src);
        end
        block = extractBetween(src, starts(k), stop);
        name  = regexp(block(1), ...
            '^[ \t]*function\s+(?:\[[^\]]*\]\s*=\s*|[\w.]+\s*=\s*)?(\w+)', ...
            'tokens', 'once');
        if ~isempty(name)
            bodies.(name{1}) = block(1);
        end
    end
end

function body = liveDataCallback(src)
    % The function that appends to a trend is the live-data path by definition;
    % fall back to the one that throttles its redraw.
    body   = "";
    bodies = functionBodies(src);
    names  = fieldnames(bodies);
    for pattern = ["\<addpoints\s*\(", "drawnow\s+limitrate"]
        for k = 1:numel(names)
            if ~isempty(regexp(bodies.(names{k}), pattern, 'once'))
                body = bodies.(names{k});
                return
            end
        end
    end
end

function [total, withConfirm, withoutConfirm] = writePaths(src)
    % A write path is a function that calls the protocol write. Every one of
    % them must open a confirm dialog first, whichever widget triggered it -
    % so count them from the source rather than from a widget's callback.
    total = -1; withConfirm = -1; withoutConfirm = -1;
    if strlength(src) == 0
        return
    end
    total = 0; withConfirm = 0;
    bodies = functionBodies(src);
    names  = fieldnames(bodies);
    for k = 1:numel(names)
        body = bodies.(names{k});
        if isempty(regexp(body, '\<(?:writeValue|write|invoke)\s*\(', 'once'))
            continue
        end
        total = total + 1;
        if ~isempty(regexp(body, 'uiconfirm\s*\(', 'once'))
            withConfirm = withConfirm + 1;
        end
    end
    withoutConfirm = total - withConfirm;
end

function calls = writeCallLines(src)
    % Every protocol write / invoke call, verbatim - arg order is graded here.
    calls = {};
    if strlength(src) == 0
        return
    end
    lines = splitlines(src);
    isCall = ~cellfun(@isempty, regexp(lines, '\<(?:writeValue|write|invoke)\s*\(', 'once'));
    isComment = startsWith(strtrim(lines), "%");
    kept = strtrim(lines(isCall & ~isComment));
    calls = cellstr(kept(:)');
end

function out = capChars(haystack, maxChars)
    out = string(haystack);
    if strlength(out) > maxChars
        out = extractBefore(out, maxChars + 1);
    end
end

% Copyright 2026 The MathWorks, Inc.
