# Accelerating Custom Loss Functions in trainnet (R2026a+)

Since R2026a, `trainnet` accepts an `AcceleratedFunction` object as the loss argument. This applies when the user passes a **function handle** (not a built-in loss string) to `trainnet`.

## When to Recommend

User calls `trainnet` with a custom loss like:
```matlab
lossFcn = @(Y1, Y2, T1, T2) crossentropy(Y1,T1) + mse(Y2,T2);
net = trainnet(ds, net, lossFcn, options);
```

## Fix

Wrap the loss with `dlaccelerate` and pass the accelerated object:
```matlab
lossFcn = @(Y1, Y2, T1, T2) crossentropy(Y1,T1) + mse(Y2,T2);
accLossFcn = dlaccelerate(lossFcn);
net = trainnet(ds, net, accLossFcn, options);
```

## Verification

trainnet only preserves the user's AcceleratedFunction object when `CheckMode` is set to `"tolerance"` before training. Use a short verification run to confirm acceleration works, then run full production training without the checking overhead.

Run a short verification by reducing `MaxEpochs` (1–2 epochs is sufficient — each epoch already processes the entire dataset) and optionally increasing `MiniBatchSize` to reduce the number of iterations further.

**Step 1: Short verification run**

```matlab
accLossFcn = dlaccelerate(lossFcn);
accLossFcn.CheckMode = "tolerance";
accLossFcn.CheckTolerance = 1e-4;

verifyOpts = trainingOptions('adam', MaxEpochs=2, MiniBatchSize=64, Verbose=false);
trainnet(ds, net, accLossFcn, verifyOpts);

fprintf('HitRate: %.1f%%\n', accLossFcn.HitRate);
fprintf('Occupancy: %.1f%%\n', accLossFcn.Occupancy);
```

If warnings appear ("Accelerated outputs differ from underlying function outputs"), the loss is NOT safe to accelerate — typically `extractdata` inside the function produces stale cached values. See Pattern 5 in [dlaccelerate-antipatterns.md](dlaccelerate-antipatterns.md).

**Step 2: Code ready to run the actual training**

```matlab
accLossFcn.CheckMode = "none";
clearCache(accLossFcn);

net = trainnet(ds, net, accLossFcn, options);
```

`CheckMode = "none"` removes the overhead of re-running the unaccelerated path each iteration. `clearCache` ensures any previous traces of the accelerated function are removed.

## When It Won't Help

If the loss function has variable-size inputs (e.g., variable-length sequences causing different input sizes each batch), the trace triggers every call. Check `HitRate`: if low, consider padding/bucketing inputs or accepting no acceleration benefit. See [dlaccelerate-variable-length-sequences.md](dlaccelerate-variable-length-sequences.md) for strategies.

## Pre-flight Checklist

Before wrapping, confirm the loss function is trace-compatible:
- No `extractdata` or `gather` inside the loss
- No data-dependent branches (`if`/`switch` on dlarray values)
- No side effects (`fprintf`, `disp`, file I/O, plotting)
- Fixed-size outputs (no logical indexing producing variable-length results)

If any of these apply, fix the loss function first. See [dlaccelerate-antipatterns.md](dlaccelerate-antipatterns.md) for the full catalog.

----

Copyright 2026 The MathWorks, Inc.
