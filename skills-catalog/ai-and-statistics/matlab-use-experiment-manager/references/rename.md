# Operation: Rename Experiment

> Shared rules, setup, the Modification Flow, validation, and API are in
> [common.md](common.md). Read it first.

Update an experiment's name, tree label, and tab title. **The experiment's function file is
left untouched.**

**Before renaming:** The new name must not be empty (after trimming whitespace) — reject an
empty or all-whitespace name and ask the user for a real name before doing anything. Then check
the target name doesn't already exist as a .mat file.

No confirmation needed.

**Rename the experiment only — do NOT rename the function file.** The experiment references its
function by name (`Process.FunctionSection`), and that reference is unaffected by the
experiment's name, so the function keeps working. Renaming the function too would force it to
the experiment's new name (`<oldName>.m` -> `<newName>.m`), which is wrong: it clobbers a
deliberately-named or shared function and, for a `.mlx`, needs a file move for no benefit. Leave
the function file, its signature, and `Process.FunctionSection` exactly as they are.

```matlab
clear classes
oldMat = fullfile('<projectPath>', '<oldName>.mat');
% Rename the experiment AND rebind its tab in one call. renameExperiment moves
% <oldName>.mat -> <newName>.mat on disk, updates the stored Name (tree label + tab title),
% and rebinds the OPEN tab to the new path in place — no teardown. Do NOT rename the .mat
% yourself and do NOT tear the view down: deleting the old .mat out from under a tab bound to
% it by experiment ID leaves a stale path (the tab later drops), and a hard view teardown
% orphans the JS frontend (assertion flood).
result = experiments.internal.AppController.renameExperiment(oldMat, '<newName>'); disp(result);
result = experiments.internal.AppController.syncTree(); disp(result);
```

**If `renameExperiment` returns `status: 'error'` or `status: 'timeout'`** (no live frontend —
see the graceful-degradation rule in [common.md](common.md)), it did NOT rename the `.mat` on
disk. Fall back to renaming it yourself, then tell the user to reopen the tab:

```matlab
newMat = fullfile('<projectPath>', '<newName>.mat');
S = load(oldMat, 'Experiment'); S.Experiment.Name = '<newName>';
save(newMat, '-struct', 'S'); delete(oldMat);
try, prj = currentProject; addFile(prj, newMat); catch, end
```

**After renaming:** the old `.mat` path is invalid — use `<newName>.mat` for subsequent
operations. The function file keeps its original name; if a later step needs it, refer to it by
the name in `Process.FunctionSection`, not the experiment name.

----

Copyright 2026 The MathWorks, Inc.

----
