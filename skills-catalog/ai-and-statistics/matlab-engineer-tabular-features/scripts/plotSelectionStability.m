function Fig = plotSelectionStability(VoteTable, NSelect, Stability, OutputDir, Options)
%plotSelectionStability Stability of the selection decision: per-feature re-selection frequency.
%
%   Fig = plotSelectionStability(VoteTable, NSelect, Stability, OutputDir) writes
%   fig_selection_stability.svg -- the candidate features in consensus-RANK order
%   (delivered set at the top) as horizontal bars whose length is how often each
%   feature was re-selected when the training rows were resampled. This audits the
%   decision drawn by the companion plotSelectionDecision (fig_selection_decision):
%   same features, same rank order, so the two figures line up.
%
%   A horizontal line marks the cut (NSelect); a vertical line marks the frequency
%   floor (reference only -- it gates nothing).
%
%   Two stability reads, two encodings:
%     * With the fixed-pool read alone (Stability), one bar series is drawn;
%       delivered features are blue, the rest grey.
%     * When a generation-stability read is also supplied
%       (Options.GenStabSelection), GROUPED bars are drawn -- fixed pool (blue)
%       beside generation (orange) -- so the per-feature gap is the generation
%       variance. A feature present in only some subsamples' pools DRIFTED: it has
%       no generation bar and its row is marked with a red band.
%
%   Reading the two reference lines together is the whole point:
%     * a SHORT bar left of the floor (shipped) is a FRAGILE pick -- the consensus
%       kept it, resampling rarely did;
%     * a LONG bar below the cut (not shipped) is a ROBUST NEAR-MISS -- resampling
%       liked it more than the consensus did.
%   Position encodes what shipped; length encodes how stable that was.
%
%   With no stability read (Stability = []), nothing is drawn and the function
%   returns [] -- the decision itself is always available from plotSelectionDecision.
%
%   Inputs:
%     VoteTable  - table(Feature, Score, Rank, Selected) from runConsensusSelection
%                  (consensus order); Rank orders the bars, Selected marks the
%                  delivered set
%     NSelect    - (1,1) double, the number of features the cut kept (the cut line)
%     Stability  - the fixed-pool read: a struct with SelectionFrequency (table
%                  Feature, Frequency), Nogueira (1,1), NSelectPerResample (1,:);
%                  or [] to draw nothing
%     OutputDir  - (1,1) string, destination folder for the SVG
%     Options.GenStabSelection - the generation-stability read
%                  (assessGenerationStability): a struct with SelectionFrequency
%                  (over the intersection universe) and, optionally, Drift. When
%                  present, adds the generation series and the drift band.
%                  Default [] (fixed pool only).
%     Options.FrequencyFloor - (1,1) double in [0,1], the resample-frequency
%                  reference line (default 0.5). DIAGNOSTIC only; it references the
%                  shipped fixed-pool read and changes nothing.
%
%   Output:
%     Fig - the figure handle (written to fig_selection_stability.svg), or [] when
%           no stability read was supplied

% Copyright 2026 The MathWorks, Inc.

    arguments
        VoteTable table
        NSelect (1,1) double {mustBePositive}
        Stability
        OutputDir (1,1) string
        Options.GenStabSelection = []
        Options.FrequencyFloor (1,1) double {mustBeGreaterThanOrEqual(Options.FrequencyFloor, 0), ...
            mustBeLessThanOrEqual(Options.FrequencyFloor, 1)} = 0.5
    end

    Floor = Options.FrequencyFloor;
    CutClr = [0.15 0.15 0.15];   % near-black: distinct from the orange generation bars
    BlueClr = [0.20 0.50 0.80];
    OrangeClr = [0.90 0.55 0.10];
    GreyClr = [0.72 0.72 0.72];

    HasStability = ~isempty(Stability) && isstruct(Stability) ...
        && isfield(Stability, "SelectionFrequency") && istable(Stability.SelectionFrequency);
    GS = Options.GenStabSelection;
    HasGenStab = ~isempty(GS) && isstruct(GS) ...
        && isfield(GS, "SelectionFrequency") && istable(GS.SelectionFrequency);

    if ~HasStability
        % No stability read -- the decision lives in plotSelectionDecision; nothing
        % to draw here.
        Fig = [];
        return;
    end

    % One full-width panel + a how-to-read caption strip along the bottom.
    Fig = figure(Name="Selection Stability", Units="centimeters", ...
        Position=[2 2 18 17], Visible="off", Color="w");
    Ax = axes(Fig, OuterPosition=[0 0.17 1 0.83]);   % leave room for the caption
    paintStability(Ax, VoteTable, NSelect, Stability, GS, HasGenStab, ...
        Floor, CutClr, BlueClr, OrangeClr, GreyClr);
    subtitle(Ax, stabilitySubtitle(HasGenStab));
    drawCaption(Fig, HasGenStab);

    exportgraphics(Fig, fullfile(OutputDir, "fig_selection_stability.svg"), ...
        ContentType="vector");
end


function paintStability(ax, VoteTable, NSelect, Stability, GS, HasGenStab, Floor, ...
        CutClr, BlueClr, OrangeClr, GreyClr)
%paintStability Per-feature selection frequency in consensus-rank order.
%   One bar series for the fixed-pool read; grouped fixed-pool/generation bars
%   when a generation read is supplied, with drifted features (absent from the
%   generation intersection universe) marked by a red band.
    VoteSorted = sortrows(VoteTable, "Rank", "ascend");
    Names = string(VoteSorted.Feature);
    FreqFixed = freqByName(Names, Stability.SelectionFrequency);

    % One labelled bar per feature does not scale, so cap the count -- but never
    % below the cut, so every delivered bar is always shown.
    MaxBars = max(25, NSelect);
    nShow = min(numel(Names), MaxBars);
    ShowNames = Names(1:nShow);
    ShowFixed = FreqFixed(1:nShow);
    IsDelivered = logical(VoteSorted.Selected(1:nShow));
    y = 1:nShow;

    if HasGenStab
        % Generation frequency is defined only over the intersection universe;
        % a feature absent from it (NaN here) DRIFTED across subsamples.
        FreqGS = freqByName(ShowNames, GS.SelectionFrequency);
        Drift = isnan(FreqGS);
        GSHeights = FreqGS;
        GSHeights(Drift) = 0;                    % keep the group slot; mark via band
        b = barh(ax, y, [ShowFixed GSHeights], 0.82, FaceColor="flat");
        b(1).FaceColor = BlueClr;
        b(2).FaceColor = OrangeClr;
        hold(ax, "on");
        for i = find(Drift(:))'
            patch(ax, [0 1 1 0], [y(i)-0.5 y(i)-0.5 y(i)+0.5 y(i)+0.5], [1 0.85 0.85], ...
                FaceAlpha=0.55, EdgeColor=[0.7 0 0], LineStyle="--");
        end
    else
        % Single series: colour encodes delivered (blue) vs not (grey).
        b = barh(ax, y, ShowFixed, FaceColor="flat");
        b.CData = repmat(GreyClr, nShow, 1);
        b.CData(IsDelivered, :) = repmat(BlueClr, nnz(IsDelivered), 1);
        hold(ax, "on");
    end

    if NSelect < nShow
        yline(ax, NSelect + 0.5, "--", sprintf("cut = %d", NSelect), Color=CutClr, ...
            LineWidth=1.3, LabelHorizontalAlignment="right", Interpreter="none");
    end
    xline(ax, Floor, ":", [sprintf("floor = %.2f", Floor); "(fixed pool)"], ...
        Color=[0.5 0 0.5], LineWidth=1.3, LabelVerticalAlignment="bottom", ...
        Interpreter="none");
    hold(ax, "off");

    set(ax, YDir="reverse", YTick=y, YTickLabel=ShowNames, TickLabelInterpreter="none");
    % Shrink the y-tick font when the bars are many or the names long, so long
    % engineered names stay legible instead of overrunning their neighbours.
    LongestName = max([strlength(ShowNames(:)); 1]);
    YFontSize = min(11, max(7, round(min(200 / nShow, 320 / LongestName))));
    ax.YAxis.FontSize = YFontSize;
    xlim(ax, [0 1]);
    xlabel(ax, "Selection frequency across resamples");
    NOmitted = numel(Names) - nShow;
    if NOmitted > 0
        title(ax, sprintf("Selection Stability (top %d; %d more omitted)", nShow, NOmitted));
    else
        title(ax, "Selection Stability");
    end
    if HasGenStab
        legend(ax, b, ["fixed pool", "generation"], Location="southoutside", ...
            Orientation="horizontal", Box="off");
    end
    grid(ax, "on");
end


function F = freqByName(Names, FreqTable)
%freqByName Selection frequency aligned to Names; NaN where a name is absent from
%   the table (used to detect drift on the generation read).
    [Present, Loc] = ismember(Names, string(FreqTable.Feature));
    F = nan(numel(Names), 1);
    F(Present) = FreqTable.Frequency(Loc(Present));
end


function S = stabilitySubtitle(HasGenStab)
%stabilitySubtitle One-line legend under the main title, per mode.
    if HasGenStab
        S = "blue = fixed pool   |   orange = generation   |   left of floor = fragile   |   red band = drift";
    else
        S = "blue = shipped   |   grey = not shipped   |   left of floor = fragile";
    end
end


function drawCaption(Fig, HasGenStab)
%drawCaption Baked-in how-to-read guide along the bottom strip. Static encoding
%   only -- run-specific reads (Nogueira value, named fragile picks, the
%   generation-variance gap) stay in the report prose.
    if HasGenStab
        Caption = [ ...
            "How to read — this audits the selection decision (the consensus-score elbow figure) under resampling; features are in the same consensus-rank order, shipped set at the top."; ...
            "Bar length is how often a feature was re-selected under resampling — a short bar left of the floor is a fragile pick, a long bar below the cut is a robust near-miss, and a red band marks a drifted feature present in only some subsamples' pools."; ...
            "The floor is a reference only and gates nothing."];
    else
        Caption = [ ...
            "How to read — this audits the selection decision (the consensus-score elbow figure) under resampling; features are in the same consensus-rank order, shipped set at the top."; ...
            "Bar length is how often a feature was re-selected under resampling — a short bar left of the floor is a fragile pick, and a long bar below the cut is a robust near-miss."; ...
            "The floor is a reference only and gates nothing."];
    end
    annotation(Fig, "textbox", [0.02 0.01 0.96 0.15], String=Caption, ...
        EdgeColor=[0.8 0.8 0.8], BackgroundColor=[0.97 0.97 0.97], ...
        FontSize=10, VerticalAlignment="middle", HorizontalAlignment="left", ...
        Interpreter="none");
end
