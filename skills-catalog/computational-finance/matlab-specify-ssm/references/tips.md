# Tip Text

Insert each applicable tip as MATLAB comments after the commented `% estMdl = estimate(...)` line. Which tips apply is listed in SKILL.md, Step 7.

## Univariate treatment

```matlab
% Tip: Add 'Univariate', true for a faster MEX-based Kalman filter.
% estMdl = estimate(mdl, y, params0, 'Univariate', true);
```

## Parameter bounds

Adapt the bounds to the model's parameters and their column-major order.

```matlab
% Tip: Constrain parameters during estimation if needed.
% For example, to keep params(1) (an AR coefficient) in (-1,1)
% and params(2) (a std dev) positive:
% estMdl = estimate(mdl, y, params0, ...
%     'lb', [-1; 0], 'ub', [1; Inf]);
% With bounds, estimate uses fmincon (Optimization Toolbox).
```

## exp() reparameterization (parameter-mapping function only)

```matlab
% Tip: For unconstrained optimization of std dev parameters, use
% exp() reparameterization in the ParamMap function:
%   sigma = exp(params(i));   % always positive
%   B(row, col) = sigma;
% Then pass log(sigma0) as the initial guess instead of sigma0.
% This avoids the need for 'lb' bounds on std dev parameters.
```

## Timing of smoothed disturbances

For a model written as x(t+1) = A x(t) + B u(t), the noise that drives x(t) is u(t-1), while `ssm` attributes it to period t.

```matlab
% Tip: Your model is written as x(t+1) = A*x(t) + B*u(t), so smoothed
% state disturbances from ssm are shifted by one period. To align them
% with your timing, add a "pending noise" state v(t) = u(t):
%   xtilde(t) = [x(t); v(t)],  Atilde = [A, B; 0, 0],  Btilde = [0; I]
% and read the smoothed v(t) as your u(t).
```

----
Copyright 2026 The MathWorks, Inc.
----
