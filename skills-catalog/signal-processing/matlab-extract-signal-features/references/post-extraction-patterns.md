# Post-extraction patterns

Patterns that run *after* `extract(sFE, x)` produces a per-frame feature table. The per-frame table is the default output — do not aggregate or reshape unless the downstream task requires it.

## Variable-length signals

When signals in a dataset have different lengths, each produces a different number of frames. This is a common situation and there are multiple valid strategies — the choice depends on the downstream model, not on the extraction step itself. **Do not default to aggregation. Ask the user if unclear.**

| Strategy | When to use | How |
|---|---|---|
| **Keep per-frame (no aggregation)** | Downstream model consumes sequences: LSTM, 1-D CNN, transformer, or the user is exploring features visually. | Return the per-frame table directly. Each signal produces a variable-length sequence of rows — sequence models handle this natively via `sequenceInputLayer` or padding at training time. |
| **Aggregate to fixed-length** | Downstream model requires one fixed-size vector per signal: SVM, decision tree, ensemble (`fitcecoc`, `fitcsvm`, `fitcensemble`). | Use `varfun(@mean, ...)` / `varfun(@std, ...)` to collapse frames → one row per signal. See aggregation pattern below. |
| **Pad/truncate to uniform frame count** | Downstream model expects a fixed-size 2-D input but benefits from temporal structure (e.g., CNN on a feature image). | Set `FrameSize` and `FrameOverlapLength` identically across signals, then zero-pad shorter signals to a common length before extraction, or truncate all to the shortest. |

The fixed `FrameSize` ensures each frame is comparable across signals regardless of total duration. Aggregation (mean/std) then summarizes "typical behavior" and "variability" — but only when the model cannot use the full temporal sequence.

## Per-frame → per-signal aggregation

Aggregation collapses a multi-frame table into one row per signal. Only do this when the downstream model requires a fixed-length feature vector per example (e.g., `fitcecoc`, `fitcsvm`, tree ensembles). If the model can consume temporal sequences — such as an LSTM (`trainnet` with `sequenceInputLayer`) or a 1-D CNN — keep the per-frame table as-is and feed the frame sequence directly. Unnecessary aggregation discards temporal structure that sequence models exploit.

```matlab
function rowPerSignal = aggregatePerSignal(featureTable)
%aggregatePerSignal Collapse a per-frame feature table to one row per signal.
    arguments
        featureTable table
    end

    featureCols = featureTable;
    featureCols.FrameStartTime = [];
    featureCols.FrameEndTime   = [];

    rowPerSignal = varfun(@mean, featureCols);
    rowPerSignal = [rowPerSignal, varfun(@std, featureCols)];
end
```

`varfun(@mean, T)` produces columns named `mean_<feature>`. Combine with `varfun(@std, T)` (or `@median`, percentile anonymous functions) to get richer summaries. Concatenate the result columns side-by-side.

### Alternative: scalarize during extraction

If you only need scalar summaries of a vector-valued feature (`WelchPSD`, multi-peak `PeakAmplitude`), it is cheaper to add scalar summary columns at extraction time via `setScalarizationMethods` on the extractor before calling `extract`. See `scalarization-options.md`.

### Edge cases

- **Vector-valued columns.** `varfun(@mean, ...)` will fail on cell or matrix columns. Either drop them, or scalarize first via `setScalarizationMethods`.
- **Label column.** If the table includes a label column, hold it aside before `varfun` and re-attach the (constant) label to the resulting one-row table.

## Save the configured extractor and a data card

The minimum sidecar needed to reproduce the same extraction on new data — sample rate, frame parameters, extractor class, MATLAB release.

```matlab
dataCard = struct( ...
    SampleRate=sFE.SampleRate, ...
    FrameSize=sFE.FrameSize, ...
    FrameOverlapLength=sFE.FrameOverlapLength, ...
    ExtractorClass=class(sFE), ...
    MATLABRelease=version("-release"));
save("featureConfig.mat", "sFE", "dataCard")
```

Reload with `load("featureConfig.mat")` and call `extract(sFE, xNew)` to apply the same configuration to a new signal.

This is the minimum for reproducibility on new data — it is not a generic experiment tracker. For richer tracking (git SHA, hyperparameters, dataset hash), wrap the pattern in your own logger.

----

Copyright 2026 The MathWorks, Inc.

----
