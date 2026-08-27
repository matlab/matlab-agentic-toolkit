function plot_accuracy_bars(modelNames, acc, accCI, topTierIdx, titleStr)
    [accSorted, order] = sort(acc, 'descend');
    namesSorted = modelNames(order);
    ciSorted = accCI(order, :);
    nModels = numel(modelNames);

    isTop = false(1, nModels);
    isTop(topTierIdx) = true;
    isTopSorted = isTop(order);

    figure;
    hold on;
    for m = 1:nModels
        if isTopSorted(m)
            barColor = [0.20 0.55 0.85];
        else
            barColor = [0.70 0.70 0.70];
        end
        bar(m, accSorted(m) * 100, 'FaceColor', barColor, 'EdgeColor', 'none');
    end
    errLow  = (accSorted(:) - ciSorted(:,1)) * 100;
    errHigh = (ciSorted(:,2) - accSorted(:)) * 100;
    errorbar(1:nModels, accSorted * 100, errLow, errHigh, 'k', 'LineStyle', 'none', 'CapSize', 6);
    set(gca, 'XTick', 1:nModels, 'XTickLabel', namesSorted, 'XTickLabelRotation', 30);
    ylabel('Accuracy (%)');
    title(titleStr);
    grid on;
    hold off;
end

% Copyright 2026 The MathWorks, Inc.
