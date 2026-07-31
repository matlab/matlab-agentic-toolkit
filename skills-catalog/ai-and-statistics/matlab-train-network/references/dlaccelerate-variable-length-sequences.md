# Variable-Length Sequence Data and dlaccelerate

**Problem:** Sequence data with varying lengths produces different dlarray sizes each batch. Since dlaccelerate keys on size, EVERY batch triggers a new trace.

**Symptoms:** `accFcn.HitRate` reads 0% or very low; `accFcn.Occupancy` grows steadily toward 100% (cache filling with unique traces).

## Step 0: Check Sequence Length Distribution

Before choosing a padding strategy, inspect the actual lengths:

```matlab
lengths = cellfun(@(x) size(x,2), sequences);
fprintf('Min: %d, Max: %d, Median: %d\n', min(lengths), max(lengths), median(lengths));
```

If max/min ratio > 3× or max/median ratio > 2×, warn about excessive padding and recommend bucketing or percentile-based truncation instead of padding to max length. Excessive padding wastes computation and may degrade training quality.

## Primary Fix: Pre-Pad All Sequences Once Before Training

Pre-pad the entire dataset to a single fixed length **before** the training loop. Every mini-batch then has the same tensor shape — dlaccelerate needs only one trace and HitRate converges near 100%:

```matlab
[XPad, mask] = padsequences(sequences, 2, Length="longest");
% Or pad/truncate to a specific fixed length:
[XPad, mask] = padsequences(sequences, 2, Length=200);
```

Use the returned `mask` (1=real data, 0=padded) inside the loss function to exclude padding from gradient contributions.

If a few outlier sequences are much longer than the majority, set `Length` to a percentile of the distribution (e.g., 95th percentile) — `padsequences` truncates sequences longer than the specified length.

## Alternative: Bucketing (Memory-Constrained Cases)

If a few very long sequences would force wasteful padding for the whole dataset, group sequences into a small number of discrete length buckets and pad each bucket to its target length:

```matlab
% Sort sequences by length, group into buckets (e.g., 50, 100, 150, 200)
[XBucket, mask] = padsequences(bucket, 2, Length=bucketLen);
% Result: only 4 traces needed instead of hundreds
```

Bucketing is a memory/HitRate tradeoff. Use it only when global pre-padding is impractical.

## Note: Per-Batch Padding with minibatchqueue

Padding each mini-batch to its own `maxLen` inside a `MiniBatchFcn` **does not eliminate re-tracing**, every unique batch-max-length still creates a new trace. Use a fixed `Length` argument to avoid this:

```matlab
mbq = minibatchqueue(ds, 3, MiniBatchSize=32, MiniBatchFcn=@preprocessMiniBatch);

function [XPad, YPad, mask] = preprocessMiniBatch(X, Y)
    [XPad, mask] = padsequences(X, 2, Length=200);  % fixed length → one trace
    YPad = padsequences(Y, 2);
end
```

Without `Length=fixedVal`, per-batch padding is equivalent to the original problem.

## Impact on Validation

With variable-length data, more iterations are needed when validating acceleration with `CheckMode = "tolerance"`. The initial iterations will produce new traces (cache misses) rather than hits. Aim for enough iterations to see HitRate stabilize after the unique lengths have been cached.

----

Copyright 2026 The MathWorks, Inc.
