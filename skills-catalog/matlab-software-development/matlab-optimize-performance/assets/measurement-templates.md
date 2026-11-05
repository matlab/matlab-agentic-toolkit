# Measurement Templates

MATLAB script templates for three measurements. To profile, compare and check correctness, follow Steps 2–6 in SKILL.md.

## Template 1: Baseline Measurement (timeit)

```matlab
% baseline_measure.m
% Measures baseline performance of a target function

% Setup — NOT timed
rng('default');
data = rand(1e6, 1);  % adjust to realistic input size

% Define function handle
f = @() targetFunction(data);

% Warmup is handled by timeit automatically
baseline = timeit(f);
fprintf('Baseline: %.6f s\n', baseline);

% Save for later comparison
save('baseline.mat', 'baseline');
```

## Template 2: GPU Timing

```matlab
% gpu_timing.m
% Properly time GPU operations

dev = gpuDevice;
gpuData = gpuArray(rand(1e6, 1));

% Use gputimeit (preferred — handles sync and warmup)
f = @() myGpuFunction(gpuData);
t = gputimeit(f);
fprintf('GPU time (gputimeit): %.6f s\n', t);

% Manual timing (when gputimeit isn't suitable)
% Warmup
for w = 1:5
    wait(dev);
    myGpuFunction(gpuData);
    wait(dev);
end

% Measure
nRuns = 20;
times = zeros(1, nRuns);
for i = 1:nRuns
    wait(dev);
    tic;
    myGpuFunction(gpuData);
    wait(dev);  % CRITICAL: sync before reading timer
    times(i) = toc;
end
fprintf('GPU time (manual): %.6f s (median of %d runs)\n', median(times), nRuns);
```

## Template 3: Scaling Test

```matlab
% scaling_test.m
% Test how performance scales with input size

sizes = [1e3, 1e4, 1e5, 1e6, 1e7];
times = zeros(size(sizes));

for k = 1:numel(sizes)
    data = rand(sizes(k), 1);
    f = @() targetFunction(data);
    times(k) = timeit(f);
end

% Plot scaling behavior
figure;
loglog(sizes, times, '-o', 'LineWidth', 2);
xlabel('Input size (N)');
ylabel('Time (s)');
title('Performance Scaling');
grid on;

% Check scaling order
slopes = diff(log(times)) ./ diff(log(sizes));
fprintf('Estimated scaling exponents: %s\n', mat2str(slopes, 2));
fprintf('(1.0 = linear, 2.0 = quadratic)\n');
```

Copyright 2026 The MathWorks, Inc.
