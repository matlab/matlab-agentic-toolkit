function plot_pvalue_heatmap(pvalMatrix, modelNames, titleStr)
    figure;
    h = heatmap(modelNames, modelNames, pvalMatrix);
    h.Title = titleStr;
    h.ColorLimits = [0 1];
    % Two significant digits, not a fixed three decimals: Bonferroni
    % thresholds are often below 0.001, and '%.3f' prints 0.0009 and 0.0014
    % alike as 0.001 and every p under 0.0005 as 0.000.
    h.CellLabelFormat = '%.2g';
    h.Colormap = parula;
    h.MissingDataColor = [0.9 0.9 0.9];
    % heatmap picks black/white cell-label text per cell based on cell
    % luminance, so values remain readable across the whole colormap range.
end

% Copyright 2026 The MathWorks, Inc.
