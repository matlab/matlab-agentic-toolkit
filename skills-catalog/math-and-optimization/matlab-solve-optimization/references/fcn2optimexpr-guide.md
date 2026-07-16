# fcn2optimexpr Guide

`fcn2optimexpr` converts a MATLAB function into an optimization expression that can be used with the problem-based framework. It can enable automatic differentiation (AD) through function calls when it can statically analyze or trace the function. Otherwise, it treats the function as a black-box.

## When to Use fcn2optimexpr

Use `fcn2optimexpr` when:
- The objective or constraint logic lives in a separate MATLAB function
- The logic involves loops, conditionals, or complex operations that are hard to write as inline `optimexpr`
- You want to pass additional data alongside `optimvar` arguments
- You have a pre-coded function (including black-box simulations or MEX-files) that you want to use in the problem-based framework

Do NOT use `fcn2optimexpr` when:
- The expression can be written directly as a simple operation on `optimvar` (e.g., `sum(x.^2)`)

## Basic Usage

```matlab
% Function with a loop that builds the objective term-by-term
function f = myObjective(x, data)
    f = zeros(1, 1, "like", x);
    for i = 1:numel(x)
        f = f + data.weights(i) * (x(i) - data.target(i))^2;
    end
end

% Convert to optimization expression
obj = fcn2optimexpr(@myObjective, x, data);
prob.Objective = obj;
```

**Key point:** `fcn2optimexpr` can accept both `optimvar` arguments and arbitrary MATLAB data (structs, arrays, scalars). Only the `optimvar` arguments are traced by AD; data passes through unchanged.

## Black-Box Functions

`fcn2optimexpr` can wrap functions that contain operations unsupported by AD (e.g., `ode45`, MEX-files, complex simulations). In this case, it does not attempt AD but simply wraps the function as a black-box. The solver will use finite differences for gradients.

```matlab
% Black-box simulation function — AD cannot trace through ode45
function cost = simulationObjective(params, simData)
    [~, y] = ode45(@(t,y) myODE(t, y, params), simData.tspan, simData.y0);
    cost = sum((y(end,:) - simData.target).^2);
end

obj = fcn2optimexpr(@simulationObjective, params, simData);
```

This allows pre-coded functions with complex simulations or MEX-files to be used in the problem-based framework without rewriting them.

## Analysis and OutputSize

When the underlying function is time-consuming to evaluate and the size and shape of the outputs is known a priori, set `Analysis` to `"off"` and specify `OutputSize` to avoid fruitless attempts to evaluate, trace, and analyze the function:

```matlab
e = fcn2optimexpr(@expensiveFcn, x, Analysis="off", OutputSize=[2 3]);
```

- `Analysis="off"` skips the initial function evaluation used for tracing
- `OutputSize` tells the framework the shape of each output without evaluating

## ReuseEvaluation

If the output `optimexpr` from `fcn2optimexpr` is used in both the objective and constraints, or in multiple constraints, set `ReuseEvaluation` to `true` to avoid redundant function evaluations:

```matlab
[obj, con1, con2] = fcn2optimexpr(@myFcn, x, ReuseEvaluation=true);
prob.Objective = obj;
prob.Constraints.c1 = con1 <= 0;
prob.Constraints.c2 = con2 <= 0;
```

Without `ReuseEvaluation=true`, the function would be called separately for each output used in different parts of the problem.

## Multiple Outputs

When the function returns multiple outputs (e.g., objective and constraint):

```matlab
function [f, c] = myFcn(x, params)
    f = sum(x.^2);
    c = norm(x) - params.maxNorm;
end

[objExpr, conExpr] = fcn2optimexpr(@myFcn, x, params);
prob.Objective = objExpr;
prob.Constraints.norm = conExpr <= 0;
```

## Wrapping Loops Efficiently

**BAD — calling fcn2optimexpr inside a loop:**
```matlab
% This creates N separate AD graphs — slow!
for i = 1:N
    cons(i) = fcn2optimexpr(@singleConstraint, x, i) <= 0;
end
```

**GOOD — wrapping the entire loop in one function:**
```matlab
function c = allConstraints(x, data)
    c = zeros(N, 1, "like", x);  % "like" preserves AD type
    for i = 1:N
        c(i) = computeConstraint(x, data, i);
    end
end

cExpr = fcn2optimexpr(@allConstraints, x, data);
prob.Constraints.all = cExpr <= 0;
```

This builds one AD graph for all constraints, which is much more efficient.

## Common Gotchas

1. **Do NOT set `SpecifyObjectiveGradient` or `SpecifyConstraintGradient`** in options when using problem-based. AD manages gradients internally (see SKILL.md Gotcha #2).

2. **Use `"like"` for preallocation inside traced functions** to preserve the AD computation type:
   ```matlab
   y = zeros(n, 1, "like", x);  % correct
   y = zeros(n, 1);              % breaks AD tracing
   ```

3. **Call `fcn2optimexpr` ONCE per function**, not once per element. If you need element-wise constraints, return a vector from one function call.

4. **Data arguments are not differentiated.** Only `optimvar` arguments participate in AD. Pass constants, parameters, and indices as additional arguments freely.

5. **Use `ReuseEvaluation=true`** whenever the same function output is used in multiple places (objective + constraints, or multiple constraints).

---
Copyright 2026 The MathWorks, Inc.
