# Operation: Delete Experiment

> Shared rules, setup, the Modification Flow, validation, and API are in
> [common.md](common.md). Read it first.

Remove an experiment: its tab, results, tree entry, and .mat file.

**Before deleting:** Check file exists. If not, list available experiments. Never batch a
delete with other operations.

## Confirm (Step 4)

Always confirm: "Are you sure you want to delete [name]? This will remove the experiment
and all its results."

**Always state the irreversibility warning in your reply — even when you proceed without
waiting.** If the request is explicit and you are proceeding directly (e.g. non-interactive),
you MUST still name the experiment and warn that the deletion is permanent before performing
it — e.g. "Deleting **trainNet** — this permanently removes the experiment, all its results,
and its file, and cannot be undone." Never delete silently or skip the warning just because
you are not pausing for a click.

## Execute (Step 5)

```matlab
clear classes
result = experiments.internal.AppController.deleteExperiment(fullfile('<projectPath>', '<experimentName>.mat')); disp(result);
% Force the tree/tabs to refresh so the deleted experiment disappears from the UI.
result = experiments.internal.AppController.syncTree(); disp(result);
```

This deletes results, closes tabs, removes from tree, and deletes the .mat file.

**Confirm the UI is clean before reporting success.** After the calls above, the tab, tree
entry, results, and `.mat` file must all be gone. If the tree still shows the experiment,
call `experiments.internal.AppController.syncTree()` again. When the calls succeed, report
the delete as complete only once the experiment is removed from the UI, not merely from disk —
do NOT tell the user to close and reopen the tab or reopen the project manually.

**If `deleteExperiment` returns `status: 'timeout'` or an error** (the frontend did not
respond), follow the timeout/fallback rule in [common.md](common.md) (General Principle 11):
delete the `.mat` file directly from disk so the experiment is gone, then in your reply state
plainly that the file and tree entry are removed but the experiment's **open tab may still be
showing**, and tell the user to close that tab. Do not claim the tab was closed when the UI
never confirmed it.

----

Copyright 2026 The MathWorks, Inc.

----
