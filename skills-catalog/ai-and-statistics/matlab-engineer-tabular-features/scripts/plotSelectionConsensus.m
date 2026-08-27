function Fig = plotSelectionConsensus(RankMatrix, FeatureNames, MethodNames, OutputDir, Options)
%plotSelectionConsensus Heatmap showing ranking agreement across selection methods.
%   Rows are ordered best-consensus-first and capped (default 35 features); when the
%   pool is larger the subtitle names how many were omitted. Pass the full rank matrix
%   (features x methods) -- the function does the ordering and the cut. Pass
%   Options.NSelect (the delivered count) so the cap never hides a shipped feature:
%   it is raised to max(35, NSelect) exactly as the companion stability plot does.

% Copyright 2026 The MathWorks, Inc.

    arguments
        RankMatrix (:,:) {mustBeNumeric}
        FeatureNames (:,1) string
        MethodNames (1,:) string
        OutputDir (1,1) string
        Options.NSelect (1,1) double {mustBePositive} = 35
    end

    % Order rows best-consensus-first (lowest rank across methods heads the map),
    % then cap the count -- one labelled row per feature does not scale to a wide
    % pool, and an unreadable 200-row heatmap helps no one. Never cap below the
    % delivered count, so every shipped feature is always shown.
    [~, Order] = sort(min(RankMatrix, [], 2));
    RankMatrix = RankMatrix(Order, :);
    FeatureNames = FeatureNames(Order);

    MaxRows = max(35, Options.NSelect);
    NAll = numel(FeatureNames);
    NShow = min(NAll, MaxRows);
    RankMatrix = RankMatrix(1:NShow, :);
    FeatureNames = FeatureNames(1:NShow);
    NOmitted = NAll - NShow;

    Fig = figure(Name="Selection Consensus", Units="centimeters", ...
        Position=[2 2 19 12], Visible="off");
    imagesc(RankMatrix); colorbar; colormap(flip(turbo));
    yticks(1:NShow); yticklabels(FeatureNames);
    xticks(1:numel(MethodNames)); xticklabels(MethodNames);
    set(gca, TickLabelInterpreter="none");

    % Shrink the y-tick font when feature names are many or long, so long
    % engineered names stay legible instead of overrunning their neighbours.
    LongestName = max([strlength(FeatureNames); 1]);
    YFontSize = min(11, max(7, round(min(200 / NShow, 320 / LongestName))));
    ax = gca; ax.YAxis.FontSize = YFontSize;
    xlabel('Selection Method'); ylabel('Feature (sorted by consensus)');
    title('Feature Ranking Agreement Across Methods');
    % Name the truncation in the subtitle whenever the pool overflows the cap.
    if NOmitted > 0
        subtitle(sprintf('Top %d of %d by consensus — %d omitted · %d methods · rank 1 = most important', ...
            NShow, NAll, NOmitted, numel(MethodNames)));
    else
        subtitle(sprintf('%d features · %d methods · rank 1 = most important', ...
            NShow, numel(MethodNames)));
    end
    exportgraphics(Fig, fullfile(OutputDir, "fig_selection_consensus.svg"), ContentType="vector");
end
