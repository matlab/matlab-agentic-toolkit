# Operation: Duplicate Experiment

> Shared rules, setup, the Modification Flow, validation, and API are in
> [common.md](common.md). Read it first.

Copy an experiment under a custom name, then sync the tree and open the copy. The copy gets
its **own** function files so it is fully independent of the original — editing the copy's
functions never affects the source. Both the main experiment function **and** the
initialization function (if the experiment has one) are copied: the main function is named
after the new experiment, the init function is named `<newName>_init`, and both references
are repointed in the copy.

**Before cloning:** Check the name doesn't conflict. If it exists, ask about a suffix.

No confirmation needed.

```matlab
clear classes
dupResult = manageExperimentHelpers.duplicate('<projectPath>', '<sourceExperiment>', 'Copy_of_<sourceExperiment>'); disp(dupResult);
syncResult = experiments.internal.AppController.syncTree(); disp(syncResult);
result = experiments.internal.AppController.refreshOrOpenExperiment(dupResult.path); disp(result);
```

`duplicate` copies the source's function file(s) to the copy's names and repoints the copy's
references. It does this for the **main** experiment function and, if present, the
**initialization** function. Each copy carries its own result fields — main:
`functionFile` / `functionShared` / `manualFunctionRename`; init: `initFunctionFile` /
`initFunctionShared` / `initManualFunctionRename` (all init fields are empty when the
experiment has no initialization function). Handle each the same way:

- **`manualFunctionRename` (or `initManualFunctionRename`) is non-empty** — that source function
  was a live script (`.mlx`). The file was copied so the copy runs correctly, but the skill
  cannot rewrite the function name *inside* a `.mlx` (that would corrupt it). Relay this
  instruction to the user in plain language: open the copied live script in the Live Editor and
  change the internal `function` line to match the new name. It is optional — the copy runs
  either way (MATLAB dispatches by file name).
- **`functionShared` (or `initFunctionShared`) is `true`** — no function file named after that
  source function was found on disk (it is named independently or lives elsewhere), so nothing
  was copied and the copy shares the source's function. If the user needs an independent
  function, ask how to proceed (e.g. point the copy at a new function you write).
- **Otherwise** (`.m` source) — the copy has its own `<newName>.m` / `<newName>_init.m` with the
  signature already rewritten; nothing further is needed.

----

Copyright 2026 The MathWorks, Inc.

----
