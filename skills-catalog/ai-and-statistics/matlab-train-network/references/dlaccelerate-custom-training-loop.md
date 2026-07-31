# Custom Training Loop Optimization

Optimize custom training loops that use `dlfeval`/`dlgradient`/`dlaccelerate` by combining operations inside a single accelerated boundary.

## Acceleration Levels: What to Include in the Boundary

For maximum performance, include as many operations as possible inside a single `dlaccelerate` call. Four levels of increasing scope:

**Level 1: Model function only (forward+loss+gradients):**
```matlab
accFcn = dlaccelerate(@modelFunc);
[grad, state] = dlfeval(accFcn, net, lossFunc, X, T);
grad = postProcess(grad, ...);  % separate
[net, ...] = adamupdate(net, grad, ...);  % separate `adamupdate` or `rmspropupdate` or `sgdmupdate`
net.State = state;
```

**Level 2: Model function + gradient postprocessing (forward+loss+gradients + L2Regularization+Clipping):**
```matlab
accFcn = dlaccelerate(@modelFuncAndPostProcessGradients);
[grad, state] = dlfeval(accFcn, net, lossFunc, X, T, regTable, gradThreshold);
[net, ...] = adamupdate(net, grad, ...);
net.State = state;
```

**Level 3: Model function + gradient postprocessing + state update (forward+loss+gradients + L2Regularization+Clipping + net.State):**
```matlab
accFcn = dlaccelerate(@modelFuncAndPostProcessGradientsAndStateUpdate);
[net, grad] = dlfeval(accFcn, net, lossFunc, X, T, regTable, gradThreshold);
[net, ...] = adamupdate(net, grad, ...);
```

**Level 4: Full iteration (forward+loss+gradients + L2Regularization+Clipping + adamupdate/rmspropupdate/sgdmupdate + net.State):**
```matlab
accFcn = dlaccelerate(@wholeLoopFused);
iteration = dlarray(0);            % MUST be dlarray because it changes every iteration
dlLearnRate = dlarray(learnRate);  % MUST be dlarray because it possibly changes every iteration

[net, avgGrad, avgSqGrad] = dlfeval(accFcn, net, lossFunc, X, T, "auto", ...
    regTable, gradThreshold, iteration, dlLearnRate, avgGrad, avgSqGrad, ...
    gradDecay, sqGradDecay, epsilon);
```

**Note 1:** Level 3 includes the state assignment (`net.State = state`) inside the boundary. This is beneficial in the case of **Note 2** only below.

**Note 2:** Level 4 includes the solver update (`adamupdate` or `sgdmupdate` or `rmspropupdate`) and state assignment (`net.State = state`) inside the boundary. **Always aim for Level 4 first.** Networks with large number of rows in net.Learnables table and smaller batch sizes may be slower — measure and compare, revert to Level 2 only if measured execution speed is worse.

**Critical for Level 4:** Inputs that change every iteration (iteration counter, learning rate) MUST be wrapped as `dlarray`. Non-dlarray inputs are matched by exact value and each unique value triggers a full retrace.

## Typical Model Function

```matlab
function [grad, state] = modelFunc(net, X, T)
[Y, state] = forward(net, X);
loss = lossFunc(Y, T);
grad = dlgradient(loss, net.Learnables);
end
```

- `lossFunc` can be a built-in function such as `crossentropy` or a custom (user) written function.
- The `modelFunc` may have more or less I/O.

## L2 Regularization (dlaccelerate compatible)

```matlab
function grad = l2Regularize(grad,weight,regFactor)
if regFactor
    grad = grad + regFactor.*weight;
end
end

% How to call: gradients = dlupdate(@l2Regularize,gradients,learnables,regFactorTable);
```

## Gradient Clipping Functions (dlaccelerate compatible)

```matlab
function gradients = thresholdL2Norm(gradients, gradientThreshold)
% "l2norm".
gradientNorm = sqrt(sum(gradients.^2,'all'));
scale = min(gradientThreshold / gradientNorm, 1);
gradients = gradients * scale;
end
```

```matlab
function gradients = thresholdAbsoluteValue(gradients, gradientThreshold)
% "absolute-value"
gradients = min(gradients, gradientThreshold);
gradients = max(gradients, -gradientThreshold);
end
```

```matlab
function gradients = thresholdGlobalL2Norm(gradients, gradientThreshold)
% "global-l2norm"
globalL2Norm = 0;
function x = accumulateL2Norm(x)
    globalL2Norm = globalL2Norm + sum(x.^2,'all');
end
dlupdate(@accumulateL2Norm, gradients);
globalL2Norm = sqrt(globalL2Norm);
normScale = min(gradientThreshold ./ globalL2Norm, 1);
gradients = dlupdate(@(g) g * normScale, gradients);
end
```

```matlab
% % How to call:
% gradients = dlupdate(@(g) thresholdL2Norm(g, gradientThreshold), gradients);
% gradients = thresholdGlobalL2Norm(gradients, gradientThreshold);
% gradients = dlupdate(@(g) thresholdAbsoluteValue(g, gradientThreshold), gradients);
```

**Important distinction of thresholdGlobalL2Norm from Pattern 6:** For operations that need to accumulate state across all gradients (e.g., global L2 norm for gradient clipping), use a nested function defined *inside* the function being traced. This works because accumulateL2Norm and globalL2Norm are defined inside the traced function. Variables from the enclosing workspace outside the accelerated function are captured as constants (Pattern 6). Variables within the traced boundary participate in tracing normally.

## Combined L2 Regularization and Clipping

```matlab
function gradients = postProcessGradients(gradients, learnables, regFactorTable, gradientClippingMethod, gradientThreshold)
gradients = l2Regularization(gradients, learnables, regFactorTable);
gradients = gradientClipping(gradientClippingMethod, gradients, gradientThreshold);
end
```

## Verification

After applying any acceleration level, verify using HitRate, Occupancy, and CheckMode. See [dlaccelerate-workflow.md](dlaccelerate-workflow.md) Step 3 for the full verification procedure.

----

Copyright 2026 The MathWorks, Inc.
