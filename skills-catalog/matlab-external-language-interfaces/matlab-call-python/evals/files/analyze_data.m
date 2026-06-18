% analyze_data.m — Requires numpy
% This script uses Python's numpy for array operations

data = [1.5, 2.3, 4.1, 3.7, 5.2, 2.8, 4.5, 3.1];

% Use numpy for statistical computations
np = py.importlib.import_module("numpy");
pyData = np.array(data);
meanVal = double(np.mean(pyData));
stdVal = double(np.std(pyData));

fprintf("Mean: %.2f\n", meanVal);
fprintf("Std:  %.2f\n", stdVal);

% Copyright 2026 The MathWorks, Inc.
