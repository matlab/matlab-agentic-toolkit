# Pruning (Structured Weight Removal)

Pruning removes the least important convolutional filters to reduce model size and
computation. Use `compressNetworkUsingTaylorPruning` — it handles the full iterative
workflow (score calculation, filter removal, fine-tuning) in a single call.

```matlab
% Define fine-tuning options for the pruning loop
options = trainingOptions("adam", ...
    MaxEpochs=10, ...
    MiniBatchSize=32, ...
    InitialLearnRate=1e-4, ...
    Verbose=false);

% Prune: remove 30% of learnable parameters
[prunedNet, info] = compressNetworkUsingTaylorPruning(net, XTrain, YTrain, ...
    "crossentropy", options, ...
    LearnablesReductionGoal=0.3, ...
    LearnablesReductionIncrement=0.05, ...
    Plots="pruning-progress");

% Inspect results
fprintf("Achieved reduction: %.1f%%\n", info.LearnablesReduction * 100);
fprintf("Pruned layers: %s\n", strjoin(info.PrunedLayerNames, ", "));
fprintf("Stop reason: %s\n", info.StopReason);
```

For the full list of name-value arguments, defaults, and behavior, consult the
function's help (`help compressNetworkUsingTaylorPruning`) or the
[reference page](https://www.mathworks.com/help/deeplearning/ref/compressnetworkusingtaylorpruning.html)
rather than relying on a list in this file. Two name-value arguments that are
worth flagging because they affect the recipe:

- `LearnablesReductionGoal` — target proportion of parameters to remove. Drives
  the trade-off between flash savings and accuracy.
- `ValidationThreshold` — stops the iterative pruning loop as soon as the
  validation metric drops below the threshold. Use this when accuracy is the
  primary constraint (see the "Maximize accuracy" recipe in [`compression-decision.md`](compression-decision.md)).

**Notes:**
- Requires the Deep Learning Toolbox Model Compression Library (support package).
  `compressNetworkUsingTaylorPruning` is the high-level R2026a API; older builds
  of the support package shipped only the lower-level `taylorPrunableNetwork`
  workflow (score → updateScore → updatePrunables → trainnet loop). If
  `which compressNetworkUsingTaylorPruning` returns "not found" on a system
  with the support package installed, the SPKG is on a stale build — ask the
  user to update the support package via Add-On Explorer.
- Operates on convolutional layers only; for FC/LSTM/GRU reduction (or for additional conv-layer reduction), use projection
- Output is a standard `dlnetwork` — no conversion step needed
- The function iteratively scores filters, removes lowest-scoring, and fine-tunes


Copyright 2026 The MathWorks, Inc.
