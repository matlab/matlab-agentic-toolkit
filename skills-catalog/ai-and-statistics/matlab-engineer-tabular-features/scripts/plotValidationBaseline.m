function Fig = plotValidationBaseline(Panel, MetricName, OutputDir, Options)
%plotValidationBaseline Grouped bar chart of the naive/original/engineered baseline.
%
%   Fig = plotValidationBaseline(Panel, MetricName, OutputDir) draws one bar group
%   per model family, each group showing the naive, original, and engineered score.
%   A single-family panel is one group (the declared-model case); an agnostic panel
%   is three groups (bag/linear/kernel) so the families are compared at a glance.
%
%   Panel is a struct array, one element per family, with fields:
%     .Family      - (1,1) string display label for the group (e.g. "Random Forest")
%     .Naive       - naive score, either a scalar bar height OR a meanStd struct
%                    (.Mean is the height, .Std the error-bar half-width)
%     .Original    - original-feature score, same shape (NaN/NaN if no originals)
%     .Engineered  - engineered-feature score, same shape
%     .NaiveStd / .OriginalStd / .EngineeredStd - (1,1) double, OPTIONAL explicit
%                    error-bar half-widths, used only when the measure above is a
%                    plain scalar (a meanStd measure carries its own .Std).
%
%   This accepts both native panels with no adapter: baselineComparison's holdout
%   .Panel (scalar measures, no std) draws plain point estimates with no caps;
%   assessKFold's .Performance.Panel (meanStd measures) draws mean +/- std with
%   error caps. Error bars appear whenever any resolved std > 0 -- so holdout stays
%   cap-free, cross_validated gets caps (pair it with a "mean +/- std" Subtitle).
%   When every family's Original is NaN (no original features) the Original series
%   is dropped so the chart shows naive vs. engineered only.

% Copyright 2026 The MathWorks, Inc.

    arguments
        Panel (1,:) struct
        MetricName (1,1) string
        OutputDir (1,1) string
        Options.Subtitle (1,1) string = ""
    end

    NumFamilies = numel(Panel);
    Labels = arrayfun(@(p) string(p.Family), Panel);
    % Each measure may be a scalar (holdout) or a meanStd struct (cross_validated);
    % resolveMeasure returns the bar height and, when present, its own std.
    [Naive, NaiveOwnStd] = resolveMeasure(Panel, "Naive");
    [Original, OriginalOwnStd] = resolveMeasure(Panel, "Original");
    [Engineered, EngineeredOwnStd] = resolveMeasure(Panel, "Engineered");
    % A meanStd measure carries its own std; a scalar measure may instead pair with
    % an explicit .<Measure>Std sidecar field. Prefer the measure's own std.
    NaiveStd = coalesceStd(NaiveOwnStd, stdOrZero(Panel, "NaiveStd"));
    OriginalStd = coalesceStd(OriginalOwnStd, stdOrZero(Panel, "OriginalStd"));
    EngineeredStd = coalesceStd(EngineeredOwnStd, stdOrZero(Panel, "EngineeredStd"));

    HasOriginal = ~all(isnan(Original));

    % Assemble the grouped series: rows = families, columns = measures.
    if HasOriginal
        SeriesNames = ["Naive", "Original", "Engineered"];
        Heights = [Naive(:), Original(:), Engineered(:)];
        Errors = [NaiveStd(:), OriginalStd(:), EngineeredStd(:)];
        Colors = [0.7 0.7 0.7; 0.8 0.4 0.2; 0.2 0.5 0.8];
    else
        SeriesNames = ["Naive", "Engineered"];
        Heights = [Naive(:), Engineered(:)];
        Errors = [NaiveStd(:), EngineeredStd(:)];
        Colors = [0.7 0.7 0.7; 0.2 0.5 0.8];
    end

    Fig = figure(Name="Baseline Comparison", Units="centimeters", ...
        Position=[2 2 17 10], Visible="off");
    Cats = categorical(Labels, Labels);
    b = bar(Cats, Heights);
    for s = 1:numel(SeriesNames)
        b(s).FaceColor = Colors(s, :);
    end

    % Error caps, aligned to each series' bar centers, drawn only where std > 0.
    if any(Errors(:) > 0)
        hold on;
        for s = 1:numel(SeriesNames)
            XCenters = seriesXCenters(b(s), NumFamilies);
            errorbar(XCenters, Heights(:, s), Errors(:, s), ...
                'k.', LineWidth=1.1, CapSize=7);
        end
        hold off;
    end

    ylabel(MetricName);
    title(sprintf('Baseline Comparison — %s', MetricName));
    if strlength(Options.Subtitle) > 0
        subtitle(Options.Subtitle);
    end
    legend(SeriesNames, Location="southoutside", Orientation="horizontal");
    grid on;
    exportgraphics(Fig, fullfile(OutputDir, "fig_validation_baseline.svg"), ContentType="vector");
end


function [Heights, Stds] = resolveMeasure(Panel, FieldName)
%resolveMeasure Per-family bar height and own std for one measure field.
%   The field is either a plain scalar score (holdout) or a meanStd struct with
%   .Mean/.Std (cross_validated). Returns the height row and a std row (NaN where
%   the measure is a scalar, so a sidecar std can supply it instead).
    N = numel(Panel);
    Heights = zeros(1, N);
    Stds = nan(1, N);
    for i = 1:N
        M = Panel(i).(FieldName);
        if isstruct(M)
            Heights(i) = double(getMean(M));
            Stds(i) = double(getStd(M));
        else
            Heights(i) = double(M);
        end
    end
end


function Val = getMean(M)
    if isfield(M, "Mean"), Val = M.Mean; else, Val = NaN; end
end


function Val = getStd(M)
    if isfield(M, "Std"), Val = M.Std; else, Val = NaN; end
end


function Out = coalesceStd(OwnStd, SidecarStd)
%coalesceStd Prefer a measure's own std; fall back to the sidecar; 0 if neither.
    Out = OwnStd;
    Use = isnan(Out);
    Out(Use) = SidecarStd(Use);
    Out(isnan(Out)) = 0;
end


function V = stdOrZero(Panel, FieldName)
%stdOrZero Pull an optional per-family std field, defaulting missing/NaN to 0.
    V = zeros(1, numel(Panel));
    for i = 1:numel(Panel)
        if isfield(Panel, FieldName) && ~isempty(Panel(i).(FieldName)) ...
                && ~isnan(Panel(i).(FieldName))
            V(i) = double(Panel(i).(FieldName));
        end
    end
end


function XCenters = seriesXCenters(BarSeries, NumFamilies)
%seriesXCenters Bar-center x-coordinates for one grouped series.
%   XEndPoints gives the centers directly for a categorical grouped bar; fall back
%   to the group index for the degenerate single-family case where it is a scalar.
    XCenters = BarSeries.XEndPoints;
    if numel(XCenters) ~= NumFamilies
        XCenters = 1:NumFamilies;
    end
end
