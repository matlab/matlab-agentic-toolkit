% transform_data.m — Compute statistics on sensor data using Python
% BUG: passes negative value to math.sqrt (ValueError), not a missing package

sensorData = [4.2, -1.5, 9.8, 16.0, 25.3];

% Compute square roots using Python's math module
results = zeros(size(sensorData));
for i = 1:numel(sensorData)
    results(i) = double(py.math.sqrt(sensorData(i)));
end

fprintf("Square roots: %s\n", mat2str(results, 3));

% Copyright 2026 The MathWorks, Inc.
