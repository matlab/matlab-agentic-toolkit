function plot_training_time(modelNames, trainTime, acc, topTierIdx)
    [~, order] = sort(acc, 'descend');
    namesSorted = modelNames(order);
    timeSorted = trainTime(order);
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
        bar(m, timeSorted(m), 'FaceColor', barColor, 'EdgeColor', 'none');
    end
    set(gca, 'XTick', 1:nModels, 'XTickLabel', namesSorted, 'XTickLabelRotation', 30);
    ylabel('Training time (s)');
    title('Training time per model');
    grid on;
    hold off;
end

% Copyright 2026 The MathWorks, Inc.
