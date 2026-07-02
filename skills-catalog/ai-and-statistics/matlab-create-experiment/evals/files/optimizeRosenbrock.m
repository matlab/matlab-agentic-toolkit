% optimizeRosenbrock.m — Minimize Rosenbrock function with different step sizes
% Located at: /projects/optim/optimizeRosenbrock.m

stepSize = 0.01;
maxIter = 1000;
x0 = [-1.5; 2.0];

x = x0;
for k = 1:maxIter
    grad = rosenbrockGradient(x);
    x = x - stepSize * grad;
end

finalValue = rosenbrock(x);
fprintf('Minimum at [%.4f, %.4f], f = %.6f\n', x(1), x(2), finalValue);

function f = rosenbrock(x)
    f = (1 - x(1))^2 + 100*(x(2) - x(1)^2)^2;
end

function g = rosenbrockGradient(x)
    g = [-2*(1 - x(1)) - 400*x(1)*(x(2) - x(1)^2);
         200*(x(2) - x(1)^2)];
end

% Copyright 2026 The MathWorks, Inc.
