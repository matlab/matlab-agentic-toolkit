function plot_boosting_curve(boostModel, boostModelName, hasHoldout, XTest, YTest)
    if hasHoldout
        cumulativeLoss = loss(boostModel, XTest, YTest, 'Mode', 'cumulative');
        yLabelStr = 'Holdout Accuracy (%)';
    else
        cumulativeLoss = kfoldLoss(boostModel, 'Mode', 'cumulative');
        yLabelStr = 'CV Accuracy (%)';
    end
    figure;
    plot(1:numel(cumulativeLoss), (1 - cumulativeLoss) * 100, ...
         '-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'auto');
    xlabel('Number of Trees');
    ylabel(yLabelStr);
    title(sprintf('Learning Curve: %s', boostModelName));
    grid on;

    if numel(cumulativeLoss) <= 1
        text(0.5, 0.5, ...
             sprintf(['Boosting terminated early: %d cumulative point(s).\n' ...
                      'Weak learners reached zero pseudo-loss immediately\n' ...
                      '(dataset too easy for the configured base learner).'], ...
                     numel(cumulativeLoss)), ...
             'Units','normalized', 'HorizontalAlignment','center', ...
             'VerticalAlignment','middle', 'FontSize', 10, ...
             'BackgroundColor', [1 1 0.85], 'EdgeColor', [0.6 0.6 0.6]);
    end
end

% Copyright 2026 The MathWorks, Inc.
