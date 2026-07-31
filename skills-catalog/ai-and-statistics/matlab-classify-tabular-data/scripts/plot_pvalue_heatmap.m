function plot_pvalue_heatmap(pvalMatrix, modelNames, titleStr)
    figure;
    h = heatmap(modelNames, modelNames, pvalMatrix);
    h.Title = titleStr;
    h.ColorLimits = [0 1];
    h.CellLabelFormat = '%.3f';
    h.Colormap = parula;
    h.MissingDataColor = [0.9 0.9 0.9];
    % heatmap picks black/white cell-label text per cell based on cell
    % luminance, so values remain readable across the whole colormap range.
end

% Copyright 2026 The MathWorks, Inc.
