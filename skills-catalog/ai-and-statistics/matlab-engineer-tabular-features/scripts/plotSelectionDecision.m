function Fig = plotSelectionDecision(VoteTable, NSelect, OutputDir)
%plotSelectionDecision The consensus-score elbow: THE selection decision.
%
%   Fig = plotSelectionDecision(VoteTable, NSelect, OutputDir) writes
%   fig_selection_decision.svg -- the fused consensus score of every candidate in
%   rank order, with a vertical line at the cut (NSelect). This is ONE selection on
%   the full training set: the elbow shows how cleanly the kept set separates from
%   the rest (sharp drop = clean cut; shallow = soft cut).
%
%   This is the decision itself, so it is always drawn -- even when the "would the
%   selector re-pick the same features?" stability read was skipped. The companion
%   plotSelectionStability audits this decision under resampling.
%
%   Inputs:
%     VoteTable - table(Feature, Score, Rank, Selected) from runConsensusSelection;
%                 Score drives the curve (sorted descending here defensively)
%     NSelect   - (1,1) double, the number of features the cut kept (the cut line)
%     OutputDir - (1,1) string, destination folder for the SVG
%
%   Output:
%     Fig - the figure handle (written to fig_selection_decision.svg)

% Copyright 2026 The MathWorks, Inc.

    arguments
        VoteTable table
        NSelect (1,1) double {mustBePositive}
        OutputDir (1,1) string
    end

    CutClr = [0.15 0.15 0.15];
    BlueClr = [0.20 0.50 0.80];

    Fig = figure(Name="Selection Decision", Units="centimeters", ...
        Position=[2 2 17 12], Visible="off", Color="w");
    HasKnee = paintDecision(axes(Fig, OuterPosition=[0 0.14 1 0.86]), VoteTable, ...
        NSelect, CutClr, BlueClr);
    drawCaption(Fig, HasKnee);

    exportgraphics(Fig, fullfile(OutputDir, "fig_selection_decision.svg"), ...
        ContentType="vector");
end


function HasKnee = drawElbowConstruction(ax, Scores, n, ChordClr)
%drawElbowConstruction Illustrate HOW the elbow is found: the chord between the
%   two endpoints, and the vertical drop from that chord down to the score point
%   of greatest below-chord distance. The drop is both the quantity computeNSelect
%   maximizes and what is drawn here, so metric and picture are the same thing; a
%   vertical segment also reads correctly on axes whose x and y are not equally
%   scaled, whereas a data-space perpendicular would render slanted. Only drawn
%   when a genuine convex knee exists -- a flat or concave curve has no below-chord
%   point, so there is nothing to illustrate and the lines are skipped. Returns
%   whether the construction was drawn, so the caption describes only what is on
%   the plot.
    HasKnee = false;
    if n < 3
        return;
    end
    X1 = 1; Y1 = Scores(1);
    X2 = n; Y2 = Scores(end);
    DX = X2 - X1;  DY = Y2 - Y1;
    if DX < eps
        return;
    end
    % Signed below-chord vertical drop for every point (matches computeNSelect).
    Idx = (1:n)';
    ChordY = Y1 + (Idx - X1) / DX * DY;
    Dist = ChordY - Scores;
    [MaxDist, ElbowIdx] = max(Dist);
    if MaxDist < 1e-10
        return;   % no below-chord point: linear/concave, no knee to illustrate
    end
    HasKnee = true;

    % The chord between the two endpoints.
    Chord = plot(ax, [X1 X2], [Y1 Y2], "--", Color=ChordClr, LineWidth=0.9);
    Chord.Annotation.LegendInformation.IconDisplayStyle = "off";

    % Vertical drop from the elbow point up to the chord -- the below-chord
    % distance the cut maximizes.
    Ex = ElbowIdx;  Ey = Scores(ElbowIdx);
    Cy = ChordY(ElbowIdx);           % chord height directly above the elbow point
    Drop = plot(ax, [Ex Ex], [Ey Cy], ":", Color=ChordClr, LineWidth=1.2);
    Drop.Annotation.LegendInformation.IconDisplayStyle = "off";
    Mrk = plot(ax, Ex, Ey, "o", MarkerSize=6, MarkerEdgeColor=ChordClr, ...
        MarkerFaceColor="none", LineWidth=1.1);
    Mrk.Annotation.LegendInformation.IconDisplayStyle = "off";
end


function drawCaption(Fig, HasKnee)
%drawCaption Baked-in how-to-read guide along the bottom strip. Static only --
%   run-specific reads (the actual cut, named features) stay in the report.
    if HasKnee
        ConstructionClause = " Grey lines: endpoint chord and the greatest below-chord drop (the elbow).";
    else
        ConstructionClause = "";   % linear/concave score curve: no knee was drawn
    end
    Caption = "Features by consensus rank (best at left), height = fused score. " + ...
        """cut"" = delivered set, placed at the score elbow; a sharp drop at the cut " + ...
        "indicates a well-separated set." + ConstructionClause;
    annotation(Fig, "textbox", [0.02 0.02 0.96 0.10], String=Caption, ...
        EdgeColor=[0.8 0.8 0.8], BackgroundColor=[0.97 0.97 0.97], ...
        FontSize=8, VerticalAlignment="middle", HorizontalAlignment="left", ...
        FitBoxToText="off", Interpreter="none");
end


function HasKnee = paintDecision(ax, VoteTable, NSelect, CutClr, BlueClr)
%paintDecision The consensus-score elbow with the cut. Returns whether a convex
%   knee was drawn, so the caption describes only what is on the plot.
    Scores = sort(VoteTable.Score, "descend");   % rank order, in case caller unsorted
    n = numel(Scores);
    ChordClr = [0.55 0.55 0.55];   % grey: elbow-method construction lines

    hold(ax, "on");
    % Elbow-method construction: the chord joining the two endpoints, and the
    % vertical drop from the elbow point to it -- the distance the cut maximizes.
    HasKnee = drawElbowConstruction(ax, Scores, n, ChordClr);

    plot(ax, 1:n, Scores, "-o", MarkerSize=3, LineWidth=1.1, Color=BlueClr);

    % Draw the cut line only when the elbow actually trimmed the pool. A curve
    % with no knee keeps every feature (NSelect == n), so there is no cut to mark.
    DidCut = NSelect < n;
    if DidCut
        xline(ax, NSelect + 0.5, "--", sprintf("cut = %d", NSelect), Color=CutClr, ...
            LineWidth=1.3, LabelVerticalAlignment="top", LabelHorizontalAlignment="right", ...
            Interpreter="none");
    end
    hold(ax, "off");

    xlim(ax, [1 n]);                             % start at rank 1 (touch the y-axis)
    if n <= 15
        xticks(ax, 1:n);
    end
    xlabel(ax, "Feature (consensus rank)");
    ylabel(ax, "Consensus score");
    title(ax, "Consensus Selection Decision");
    if DidCut
        subtitle(ax, "Cut Placed at the Consensus-Score Elbow");
    else
        subtitle(ax, "No Elbow — Full Pool Kept");
    end
    grid(ax, "on");
end
