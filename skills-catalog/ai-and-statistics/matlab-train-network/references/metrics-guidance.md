# Metrics Guidance

How to choose the right metric format for `testnet` and `trainingOptions`.

## Decision Tree

1. **Single-output network, built-in metric?** → Use a string: `"accuracy"`,
   `"rmse"`, `"fscore"`.

2. **Multi-output network?** → See `references/multi-output-training.md` for the
   full recipe including metric objects with `NetworkOutput`.

3. **Need customization of a built-in metric?** → Use metric objects with
   name-value arguments (e.g., `AverageType="macro"/"micro"/"weighted"` for
   classification metrics):
   ```matlab
   metrics = precisionMetric(AverageType="micro");
   ```

4. **Custom metric where weighted average across minibatches is acceptable?** →
   Define a custom metric function:
   ```matlab
   options = trainingOptions("adam",Metrics=@myMetricFcn);
   ```
   The custom metric function receives all network outputs followed by all
   targets, in order: `metric = myMetricFcn(Y1,Y2,...,T1,T2,...)`.

5. **Custom metric requiring accumulation of intermediate values across
   minibatches** (e.g., accumulating true negatives/false positives to compute
   an exact metric over the full dataset)? → Subclass `deep.Metric`. Key aspects:
   - Expose `Name` and `NetworkOutput` as constructor arguments so users can configure them; set `Maximize` internally (`true` if higher is better, `false` if lower is better)
   - Implement `reset` to zero out accumulated state
   - Implement `update(metric,batchY,batchT)` to accumulate per-minibatch values
   - Implement `aggregate(metric,metric2)` to combine results across workers
   - Implement `evaluate` to return the final scalar metric value from accumulated state

## Using Metrics with trainnet

Metrics specified in `trainingOptions` are displayed during training:

```matlab
options = trainingOptions("adam",Metrics="accuracy");
```

For multi-output networks, see `references/multi-output-training.md`.

## Using Metrics with testnet

```matlab
accuracy = testnet(net,XTest,TTest,"accuracy");
rmse = testnet(net,XTest,TTest,"rmse");
```

For multi-output networks, see `references/multi-output-training.md`.

----

Copyright 2026 The MathWorks, Inc.

----
